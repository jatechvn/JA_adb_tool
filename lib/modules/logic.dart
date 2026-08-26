// lib/modules/logic.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'logger_config.dart';
import 'utils.dart';
import 'services/adb_service.dart';
import 'services/device_workspace_store.dart';
import 'services/diagnostics_service.dart';
import 'services/scrcpy_profile_store.dart';
import 'services/settings_backup_service.dart';

const int _maxXapkArchiveBytes = 1024 * 1024 * 1024;
const int _maxXapkEntries = 512;
const int _maxXapkUncompressedBytes = 2 * 1024 * 1024 * 1024;

@visibleForTesting
bool isSafeXapkEntryPath(String entryPath) {
  final normalized = p.posix.normalize(entryPath.replaceAll('\\', '/'));
  return normalized.isNotEmpty &&
      !p.posix.isAbsolute(normalized) &&
      normalized != '..' &&
      !normalized.startsWith('../') &&
      !RegExp(r'^[a-zA-Z]:').hasMatch(normalized);
}

Archive _openValidatedXapk(String xapkPath) {
  final archiveFile = File(xapkPath);
  final archiveBytes = archiveFile.lengthSync();
  if (archiveBytes > _maxXapkArchiveBytes) {
    throw FormatException('XAPK is larger than the 1 GB safety limit.');
  }

  final archive = ZipDecoder().decodeBuffer(InputFileStream(xapkPath));
  if (archive.files.length > _maxXapkEntries) {
    archive.clearSync();
    throw FormatException(
      'XAPK has too many entries (${archive.files.length}).',
    );
  }

  var uncompressedBytes = 0;
  for (final entry in archive.files) {
    if (!isSafeXapkEntryPath(entry.name) || entry.isSymbolicLink) {
      archive.clearSync();
      throw FormatException(
        'XAPK contains an unsafe archive entry: ${entry.name}',
      );
    }
    uncompressedBytes += entry.size;
    if (uncompressedBytes > _maxXapkUncompressedBytes) {
      archive.clearSync();
      throw FormatException('XAPK expands beyond the 2 GB safety limit.');
    }
  }
  return archive;
}

Map<String, String> _inspectXapkPackage(String xapkPath) {
  final archive = _openValidatedXapk(xapkPath);
  try {
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null || !manifestFile.isFile) {
      throw FormatException('manifest.json not found in XAPK package.');
    }
    final manifestContent = utf8.decode(manifestFile.content as List<int>);
    final manifest = jsonDecode(manifestContent);
    if (manifest is! Map) {
      throw FormatException('manifest.json must contain an object.');
    }
    return {
      'name': manifest['name']?.toString() ?? p.basename(xapkPath),
      'packageName': manifest['package_name']?.toString() ?? 'Unknown',
      'version': manifest['version_name']?.toString() ?? 'Unknown',
    };
  } finally {
    archive.clearSync();
  }
}

Map<String, Object?> _extractValidatedXapk(Map<String, String> arguments) {
  final xapkPath = arguments['xapkPath']!;
  final tempDirectory = arguments['tempDirectory']!;
  final archive = _openValidatedXapk(xapkPath);
  try {
    final apkPaths = <String>[];
    String? obbFilePath;
    String? obbFileName;

    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final lowerName = entry.name.toLowerCase();
      if (!lowerName.endsWith('.apk') && !lowerName.endsWith('.obb')) continue;

      final normalizedName = p.posix.normalize(
        entry.name.replaceAll('\\', '/'),
      );
      final outputPath = p.joinAll([
        tempDirectory,
        ...normalizedName.split('/'),
      ]);
      if (!p.isWithin(tempDirectory, outputPath)) {
        throw FormatException('XAPK entry escapes the temporary directory.');
      }

      File(outputPath).parent.createSync(recursive: true);
      final output = OutputFileStream(outputPath);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }

      if (lowerName.endsWith('.apk')) {
        apkPaths.add(outputPath);
      } else {
        obbFilePath = outputPath;
        obbFileName = p.basename(normalizedName);
      }
    }

    if (apkPaths.isEmpty) {
      throw FormatException('No APK files found in XAPK package.');
    }
    return {
      'apkPaths': apkPaths,
      'obbFilePath': obbFilePath,
      'obbFileName': obbFileName,
    };
  } finally {
    archive.clearSync();
  }
}

class AndroidFileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final String dateModified;

  AndroidFileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.dateModified,
  });
}

class AndroidMediaItem {
  final String path;
  final int dateAdded;
  final String name;
  final bool isVideo;

  AndroidMediaItem({
    required this.path,
    required this.dateAdded,
    required this.name,
    required this.isVideo,
  });
}

class AndroidApp {
  final String packageName;
  final String appName;
  final bool isSystem;
  final bool isFrozen;
  final DateTime? installTime;

  AndroidApp({
    required this.packageName,
    required this.appName,
    required this.isSystem,
    required this.isFrozen,
    this.installTime,
  });
}

class BatchAppActionResult {
  final String action;
  final List<String> succeeded;
  final List<String> failed;

  const BatchAppActionResult({
    required this.action,
    required this.succeeded,
    required this.failed,
  });

  bool get isSuccess => failed.isEmpty;
}

enum AppSortOption { name, newest, oldest }

class AppLogic extends ChangeNotifier {
  static const _mirrorChannel = MethodChannel('ja_route/mirror');
  final AdbService _adbService = const AdbService();
  final DeviceWorkspaceStore _workspaceStore = DeviceWorkspaceStore();
  final DiagnosticsService _diagnosticsService = const DiagnosticsService();
  final ScrcpyProfileStore _scrcpyProfileStore = ScrcpyProfileStore();
  final SettingsBackupService _settingsBackupService =
      const SettingsBackupService();

  static const double defaultBgBlur = 10.0;
  static const double defaultBgOpacity = 0.6;
  static const double defaultDialogBlur = 12.0;
  static const double defaultDialogOpacity = 0.75;

  // App freezing / packages state
  List<AndroidApp> _apps = [];
  bool _loadingApps = false;
  String _appsError = '';
  AppSortOption _appSortOption = AppSortOption.name;

  List<AndroidApp> get apps => _apps;
  bool get loadingApps => _loadingApps;
  String get appsError => _appsError;
  AppSortOption get appSortOption => _appSortOption;

  void setAppSortOption(AppSortOption option) {
    _appSortOption = option;
    _sortApps();
    notifyListeners();
  }

  void _sortApps() {
    switch (_appSortOption) {
      case AppSortOption.name:
        _apps.sort(
          (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
        );
        break;
      case AppSortOption.newest:
        _apps.sort((a, b) {
          final ta = a.installTime;
          final tb = b.installTime;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta); // Newest first
        });
        break;
      case AppSortOption.oldest:
        _apps.sort((a, b) {
          final ta = a.installTime;
          final tb = b.installTime;
          if (ta == null && tb == null) return 0;
          if (ta == null) return 1;
          if (tb == null) return -1;
          return ta.compareTo(tb); // Oldest first
        });
        break;
    }
  }

  // Config & Executables
  String _adbPath = '';
  String _scrcpyPath = '';
  String _gnirehtetPath = '';
  String _screenshotDir = '';
  String _mediaDownloadDir = '';
  List<Map<String, String>> _predefinedInputs = [];
  String get adbPath => _adbPath;
  String get scrcpyPath => _scrcpyPath;
  String get gnirehtetPath => _gnirehtetPath;
  String get screenshotDir => _screenshotDir;
  String get mediaDownloadDir => _mediaDownloadDir;
  List<Map<String, String>> get predefinedInputs => _predefinedInputs;

  // Glassmorphism preferences. These are intentionally kept in AppLogic so
  // the Settings preview can be discarded until the user presses Save.
  double _bgBlur = defaultBgBlur;
  double _bgOpacity = defaultBgOpacity;
  double _dialogBlur = defaultDialogBlur;
  double _dialogOpacity = defaultDialogOpacity;

  double get bgBlur => _bgBlur;
  double get bgOpacity => _bgOpacity;
  double get dialogBlur => _dialogBlur;
  double get dialogOpacity => _dialogOpacity;

  // Connected Devices
  List<String> _connectedDevices = [];
  Map<String, Map<String, String>> _devicesDetails = {};
  String? _selectedDevice;
  bool _isSearchingDevices = false;

  // Wireless ADB state
  List<String> _wirelessEndpoints = [];
  bool _isWirelessConnecting = false;
  String _wirelessStatus = '';

  // Device workspace state
  List<DeviceWorkspaceProfile> _workspaceProfiles = [];
  DiagnosticsReport? _diagnosticsReport;
  List<ScrcpyProfile> _scrcpyProfiles = [];

  // Gnirehtet Reverse Tethering
  bool _isGnirehtetRunning = false;
  Process? _gnirehtetProcess;
  String _gnirehtetLogs = '';

  bool get isGnirehtetRunning => _isGnirehtetRunning;
  String get gnirehtetLogs => _gnirehtetLogs;

  List<String> get connectedDevices => _connectedDevices;
  String? get selectedDevice => _selectedDevice;
  bool get isSearchingDevices => _isSearchingDevices;
  Map<String, Map<String, String>> get devicesDetails => _devicesDetails;
  Map<String, String>? get selectedDeviceDetails =>
      _selectedDevice != null ? _devicesDetails[_selectedDevice] : null;
  List<String> get wirelessEndpoints => List.unmodifiable(_wirelessEndpoints);
  bool get isWirelessConnecting => _isWirelessConnecting;
  String get wirelessStatus => _wirelessStatus;
  List<DeviceWorkspaceProfile> get workspaceProfiles =>
      List.unmodifiable(_workspaceProfiles);
  DiagnosticsReport? get diagnosticsReport => _diagnosticsReport;
  List<ScrcpyProfile> get scrcpyProfiles => List.unmodifiable(_scrcpyProfiles);

  // Sync Folder Settings
  String _lastSyncPcPath = '';
  String _lastSyncAndroidPath = '';
  String _lastSyncDirection = 'pcToAndroid';
  bool _lastSyncDeleteExtra = false;
  bool _lastSyncAutoSync = false;
  List<String> _syncHistory = [];

  String get lastSyncPcPath => _lastSyncPcPath;
  String get lastSyncAndroidPath => _lastSyncAndroidPath;
  String get lastSyncDirection => _lastSyncDirection;
  bool get lastSyncDeleteExtra => _lastSyncDeleteExtra;
  bool get lastSyncAutoSync => _lastSyncAutoSync;
  List<String> get syncHistory => _syncHistory;

  // Global Sync State
  bool _isSyncing = false;
  bool _isSyncPaused = false;
  Completer<void>? _syncResumeCompleter;
  double _syncProgress = 0.0;
  String _syncStatusText = '';
  String _syncLog = '';
  String _lastSyncSpeedText = '';
  StreamSubscription<AdbSyncProgressEvent>? _activeSyncSub;

  bool get isSyncing => _isSyncing;
  bool get isSyncPaused => _isSyncPaused;
  double get syncProgress => _syncProgress;
  String get syncStatusText => _syncStatusText;
  String get syncLog => _syncLog;

  // Screen Mirroring Process
  Process? _scrcpyProcess;
  bool get isMirroring => _scrcpyProcess != null;

  // File Explorer State
  String _androidCurrentPath = '/sdcard';
  List<AndroidFileItem> _androidFiles = [];
  bool _isAndroidLoading = false;
  String _androidExplorerError = '';

  String get androidCurrentPath => _androidCurrentPath;
  List<AndroidFileItem> get androidFiles => _androidFiles;
  bool get isAndroidLoading => _isAndroidLoading;
  String get androidExplorerError => _androidExplorerError;

  // Latest Media State
  List<AndroidMediaItem> _latestMedia = [];
  bool _isMediaLoading = false;
  Set<String> _selectedMediaPaths = {};
  final Map<String, List<AndroidMediaItem>> _latestMediaByDevice = {};
  final Map<String, Future<List<AndroidMediaItem>>> _mediaFetchesByDevice = {};

  List<AndroidMediaItem> get latestMedia => _latestMedia;
  bool get isMediaLoading => _isMediaLoading;
  Set<String> get selectedMediaPaths => _selectedMediaPaths;

  // Installer State
  String? _installerFilePath;
  final List<String> _installerFilePaths = [];
  String _installerStatus =
      'idle'; // idle, parsing, parsed, installing, success, error
  String _installerLog = '';
  bool _isInstalling = false;
  Map<String, String> _installerAppDetails = {};
  final Map<String, Map<String, String>> _installerPackageDetails = {};
  int _installerOperationId = 0;

  String? get installerFilePath => _installerFilePath;
  List<String> get installerFilePaths => List.unmodifiable(_installerFilePaths);
  String get installerStatus => _installerStatus;
  String get installerLog => _installerLog;
  bool get isInstalling => _isInstalling;
  Map<String, String> get installerAppDetails => _installerAppDetails;
  Map<String, Map<String, String>> get installerPackageDetails =>
      Map.unmodifiable(_installerPackageDetails);

  // Timer for Auto refresh devices
  Timer? _deviceScanTimer;

  AppLogic() {
    _init();
  }

  double _parseDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _init() async {
    await loadPaths();
    await loadConfigJson();
    _workspaceProfiles = await _workspaceStore.load();
    _scrcpyProfiles = await _scrcpyProfileStore.load();
    await loadAdbCommandHistory();
    await loadTextInputHistory();
    // Validate if the loaded paths actually exist. If not, trigger auto-detection.
    if (_adbPath.isNotEmpty && !File(_adbPath).existsSync()) {
      _adbPath = '';
    }
    if (_scrcpyPath.isNotEmpty && !File(_scrcpyPath).existsSync()) {
      _scrcpyPath = '';
    }
    if (_gnirehtetPath.isNotEmpty && !File(_gnirehtetPath).existsSync()) {
      _gnirehtetPath = '';
    }

    if (_adbPath.isEmpty || _scrcpyPath.isEmpty || _gnirehtetPath.isEmpty) {
      await autoDetectPaths();
    }
    // Start initial scan
    await scanDevices();
    // Setup scan timer every 5 seconds
    _deviceScanTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => scanDevices(),
    );
  }

  @override
  void dispose() {
    _deviceScanTimer?.cancel();
    stopMirroring();
    stopReverseTethering();
    super.dispose();
  }

  // ==========================================
  // PATH CONFIGURATION & PERSISTENCE
  // ==========================================

  File _getConfigFile() {
    final exeDir = p.dirname(Platform.resolvedExecutable);
    // First priority: config.json next to the .exe
    final exeConfig = File(p.join(exeDir, 'config.json'));
    if (exeConfig.existsSync()) return exeConfig;
    // Second: current working directory
    final cwdConfig = File(p.join(Directory.current.path, 'config.json'));
    if (cwdConfig.existsSync()) return cwdConfig;
    // Default: create next to the exe
    return exeConfig;
  }

  Future<void> _writeConfigValues(Map<String, dynamic> updates) async {
    try {
      final file = _getConfigFile();
      logger.info('[config] Writing to: ${file.path}');
      Map<String, dynamic> data = {};
      if (file.existsSync()) {
        try {
          final content = file.readAsStringSync();
          if (content.trim().isNotEmpty) {
            final decoded = jsonDecode(content);
            if (decoded is Map) {
              data = Map<String, dynamic>.from(decoded);
            }
          }
        } catch (parseErr) {
          logger.warning(
            '[config] Could not parse existing config.json: $parseErr',
          );
        }
      }
      // Deep merge: for nested maps (e.g. device_sync_settings), merge instead of replace
      for (final entry in updates.entries) {
        if (entry.value is Map && data[entry.key] is Map) {
          final merged = Map<String, dynamic>.from(data[entry.key] as Map);
          merged.addAll(Map<String, dynamic>.from(entry.value as Map));
          data[entry.key] = merged;
        } else {
          data[entry.key] = entry.value;
        }
      }
      const encoder = JsonEncoder.withIndent('  ');
      file.writeAsStringSync(encoder.convert(data), flush: true);
      logger.info(
        '[config] Successfully wrote config.json (${file.lengthSync()} bytes)',
      );
    } catch (e) {
      logger.severe('[config] Failed to write config values to json: $e');
    }
  }

  Future<void> loadPaths() async {
    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        _adbPath = prefs.getString('adb_path') ?? '';
        _scrcpyPath = prefs.getString('scrcpy_path') ?? '';
        _screenshotDir = prefs.getString('screenshot_dir') ?? '';
        _mediaDownloadDir = prefs.getString('media_download_dir') ?? '';
        _gnirehtetPath = prefs.getString('gnirehtet_path') ?? '';
        _bgBlur = prefs.getDouble('bg_blur') ?? defaultBgBlur;
        _bgOpacity = prefs.getDouble('bg_opacity') ?? defaultBgOpacity;
        _dialogBlur = prefs.getDouble('dialog_blur') ?? defaultDialogBlur;
        _dialogOpacity =
            prefs.getDouble('dialog_opacity') ?? defaultDialogOpacity;

        _lastSyncPcPath = prefs.getString('last_sync_pc_path') ?? '';
        _lastSyncAndroidPath = prefs.getString('last_sync_android_path') ?? '';
        _lastSyncDirection =
            prefs.getString('last_sync_direction') ?? 'pcToAndroid';
        _lastSyncDeleteExtra = prefs.getBool('last_sync_delete_extra') ?? false;
        _lastSyncAutoSync = prefs.getBool('last_sync_auto_sync') ?? false;
        _syncHistory = prefs.getStringList('sync_history') ?? [];
      } catch (e) {
        logger.warning('SharedPreferences load failed: $e');
      }

      final file = _getConfigFile();
      if (file.existsSync()) {
        try {
          final content = file.readAsStringSync();
          if (content.isNotEmpty) {
            final data = jsonDecode(content);
            if (data is Map) {
              if (data.containsKey('adb_path'))
                _adbPath = data['adb_path']?.toString() ?? _adbPath;
              if (data.containsKey('scrcpy_path'))
                _scrcpyPath = data['scrcpy_path']?.toString() ?? _scrcpyPath;
              if (data.containsKey('screenshot_dir'))
                _screenshotDir =
                    data['screenshot_dir']?.toString() ?? _screenshotDir;
              if (data.containsKey('media_download_dir'))
                _mediaDownloadDir =
                    data['media_download_dir']?.toString() ?? _mediaDownloadDir;
              if (data.containsKey('gnirehtet_path'))
                _gnirehtetPath =
                    data['gnirehtet_path']?.toString() ?? _gnirehtetPath;
              if (data.containsKey('bg_blur')) {
                _bgBlur = _parseDouble(data['bg_blur'], defaultBgBlur);
              }
              if (data.containsKey('bg_opacity')) {
                _bgOpacity = _parseDouble(data['bg_opacity'], defaultBgOpacity);
              }
              if (data.containsKey('dialog_blur')) {
                _dialogBlur = _parseDouble(
                  data['dialog_blur'],
                  defaultDialogBlur,
                );
              }
              if (data.containsKey('dialog_opacity')) {
                _dialogOpacity = _parseDouble(
                  data['dialog_opacity'],
                  defaultDialogOpacity,
                );
              }

              if (data.containsKey('last_sync_pc_path'))
                _lastSyncPcPath =
                    data['last_sync_pc_path']?.toString() ?? _lastSyncPcPath;
              if (data.containsKey('last_sync_android_path'))
                _lastSyncAndroidPath =
                    data['last_sync_android_path']?.toString() ??
                    _lastSyncAndroidPath;
              if (data.containsKey('last_sync_direction'))
                _lastSyncDirection =
                    data['last_sync_direction']?.toString() ??
                    _lastSyncDirection;
              if (data.containsKey('last_sync_delete_extra'))
                _lastSyncDeleteExtra = data['last_sync_delete_extra'] == true;
              if (data.containsKey('last_sync_auto_sync'))
                _lastSyncAutoSync = data['last_sync_auto_sync'] == true;

              if (data.containsKey('sync_history')) {
                final sh = data['sync_history'];
                if (sh is List) {
                  _syncHistory = sh.map((e) => e.toString()).toList();
                }
              }
              if (data['wireless_endpoints'] is List) {
                _wirelessEndpoints = (data['wireless_endpoints'] as List)
                    .map((endpoint) => endpoint.toString())
                    .where((endpoint) => endpoint.isNotEmpty)
                    .toSet()
                    .toList();
              }
            }
          }
        } catch (_) {}
      }

      notifyListeners();
    } catch (e) {
      logger.severe('Failed to load settings: $e');
    }
  }

  Future<void> saveSyncSettings({
    required String pcPath,
    required String androidPath,
    required String direction,
    required bool deleteExtra,
    required bool autoSync,
  }) async {
    _lastSyncPcPath = pcPath;
    _lastSyncAndroidPath = androidPath;
    _lastSyncDirection = direction;
    _lastSyncDeleteExtra = deleteExtra;
    _lastSyncAutoSync = autoSync;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_pc_path', pcPath);
      await prefs.setString('last_sync_android_path', androidPath);
      await prefs.setString('last_sync_direction', direction);
      await prefs.setBool('last_sync_delete_extra', deleteExtra);
      await prefs.setBool('last_sync_auto_sync', autoSync);

      final dev = _selectedDevice;
      if (dev != null && dev.isNotEmpty) {
        await prefs.setString('last_sync_pc_path_$dev', pcPath);
        await prefs.setString('last_sync_android_path_$dev', androidPath);
        await prefs.setString('last_sync_direction_$dev', direction);
        await prefs.setBool('last_sync_delete_extra_$dev', deleteExtra);
        await prefs.setBool('last_sync_auto_sync_$dev', autoSync);
      }
    } catch (e) {
      logger.warning('SharedPreferences saveSyncSettings failed: $e');
    }

    try {
      final Map<String, dynamic> updates = {
        'last_sync_pc_path': pcPath,
        'last_sync_android_path': androidPath,
        'last_sync_direction': direction,
        'last_sync_delete_extra': deleteExtra,
        'last_sync_auto_sync': autoSync,
      };

      final dev = _selectedDevice;
      if (dev != null && dev.isNotEmpty) {
        final file = _getConfigFile();
        Map<String, dynamic> data = {};
        if (file.existsSync()) {
          try {
            final content = file.readAsStringSync();
            if (content.isNotEmpty) {
              final decoded = jsonDecode(content);
              if (decoded is Map) {
                data = Map<String, dynamic>.from(decoded);
              }
            }
          } catch (_) {}
        }
        final rawDeviceSettings = data['device_sync_settings'];
        final Map<String, dynamic> deviceSettings = rawDeviceSettings is Map
            ? Map<String, dynamic>.from(rawDeviceSettings)
            : {};
        deviceSettings[dev] = {
          'pc_path': pcPath,
          'android_path': androidPath,
          'direction': direction,
          'delete_extra': deleteExtra,
          'auto_sync': autoSync,
        };
        updates['device_sync_settings'] = deviceSettings;
      }

      await _writeConfigValues(updates);
    } catch (e) {
      logger.severe('Failed to save sync settings to json: $e');
    }
  }

  Future<void> loadDeviceSyncSettings(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastSyncPcPath =
          prefs.getString('last_sync_pc_path_$deviceId') ??
          prefs.getString('last_sync_pc_path') ??
          '';
      _lastSyncAndroidPath =
          prefs.getString('last_sync_android_path_$deviceId') ??
          prefs.getString('last_sync_android_path') ??
          '/sdcard';
      _lastSyncDirection =
          prefs.getString('last_sync_direction_$deviceId') ??
          prefs.getString('last_sync_direction') ??
          'pcToAndroid';
      _lastSyncDeleteExtra =
          prefs.getBool('last_sync_delete_extra_$deviceId') ??
          prefs.getBool('last_sync_delete_extra') ??
          false;
      _lastSyncAutoSync =
          prefs.getBool('last_sync_auto_sync_$deviceId') ??
          prefs.getBool('last_sync_auto_sync') ??
          false;
    } catch (e) {
      logger.warning('SharedPreferences loadDeviceSyncSettings failed: $e');
    }

    try {
      final file = _getConfigFile();
      if (file.existsSync()) {
        try {
          final content = file.readAsStringSync();
          if (content.isNotEmpty) {
            final data = jsonDecode(content);
            if (data is Map && data.containsKey('device_sync_settings')) {
              final deviceSettings = data['device_sync_settings'];
              if (deviceSettings is Map &&
                  deviceSettings.containsKey(deviceId)) {
                final devSettings = deviceSettings[deviceId];
                if (devSettings is Map) {
                  _lastSyncPcPath =
                      devSettings['pc_path']?.toString() ?? _lastSyncPcPath;
                  _lastSyncAndroidPath =
                      devSettings['android_path']?.toString() ??
                      _lastSyncAndroidPath;
                  _lastSyncDirection =
                      devSettings['direction']?.toString() ??
                      _lastSyncDirection;
                  _lastSyncDeleteExtra = devSettings['delete_extra'] == true;
                  _lastSyncAutoSync = devSettings['auto_sync'] == true;
                }
              }
            }
          }
        } catch (_) {}
      }

      notifyListeners();
    } catch (e) {
      logger.severe('Failed to load device sync settings: $e');
    }
  }

  Future<void> addSyncHistory(
    String pc,
    String android,
    String dir,
    bool delExtra,
  ) async {
    final item = '$pc|$android|$dir|${delExtra ? "1" : "0"}';
    final newList = List<String>.from(_syncHistory);
    newList.remove(item);
    newList.insert(0, item);
    if (newList.length > 5) {
      _syncHistory = newList.sublist(0, 5);
    } else {
      _syncHistory = newList;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('sync_history', _syncHistory);
    } catch (e) {
      logger.warning('SharedPreferences addSyncHistory failed: $e');
    }
    try {
      await _writeConfigValues({'sync_history': _syncHistory});
    } catch (e) {
      logger.severe('Failed to save sync history to json: $e');
    }
  }

  Future<void> clearSyncHistory() async {
    _syncHistory = [];
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sync_history');
    } catch (e) {
      logger.warning('SharedPreferences clearSyncHistory failed: $e');
    }
    try {
      await _writeConfigValues({'sync_history': <String>[]});
    } catch (e) {
      logger.severe('Failed to clear sync history in json: $e');
    }
  }

  Future<void> saveScreenshotDir(String path) async {
    _screenshotDir = path;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('screenshot_dir', path);
    } catch (e) {
      logger.warning('SharedPreferences saveScreenshotDir failed: $e');
    }
    try {
      await _writeConfigValues({'screenshot_dir': path});
      logger.info('Screenshot directory saved: $path');
    } catch (e) {
      logger.severe('Failed to save screenshot directory to json: $e');
    }
  }

  Future<void> saveMediaDownloadDir(String path) async {
    _mediaDownloadDir = path;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('media_download_dir', path);
    } catch (e) {
      logger.warning('SharedPreferences saveMediaDownloadDir failed: $e');
    }
    try {
      await _writeConfigValues({'media_download_dir': path});
      logger.info('Media download directory saved: $path');
    } catch (e) {
      logger.severe('Failed to save media download directory to json: $e');
    }
  }

  Future<void> loadConfigJson() async {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);

      // Look for config.json in exeDir, and fall back to Directory.current if not found
      var configFile = File(p.join(exeDir, 'config.json'));
      if (!configFile.existsSync()) {
        configFile = File(p.join(Directory.current.path, 'config.json'));
      }

      // If still doesn't exist, create a default one in exeDir (or current dir if exeDir is system/temp)
      if (!configFile.existsSync()) {
        final defaultContent = {
          "predefined_inputs": [
            {
              "label": "Open Settings",
              "value": "am start -a android.settings.SETTINGS",
            },
            {
              "label": "List 3rd Party Packages",
              "value": "pm list packages -3",
            },
            {"label": "Check Battery Status", "value": "dumpsys battery"},
            {"label": "Simulate Back Key", "value": "input keyevent 4"},
            {"label": "Show Device Info", "value": "getprop ro.product.model"},
          ],
        };
        try {
          const encoder = JsonEncoder.withIndent('  ');
          configFile.writeAsStringSync(
            encoder.convert(defaultContent),
            flush: true,
          );
          logger.info('Default config.json created at ${configFile.path}');
        } catch (e) {
          logger.warning('Failed to write default config.json: $e');
        }
      }

      if (configFile.existsSync()) {
        final content = configFile.readAsStringSync();
        final data = jsonDecode(content);
        if (data is Map && data.containsKey('predefined_inputs')) {
          final list = data['predefined_inputs'];
          if (list is List) {
            _predefinedInputs = list.map((item) {
              if (item is Map) {
                return {
                  'label': item['label']?.toString() ?? '',
                  'value': item['value']?.toString() ?? '',
                };
              } else {
                return {'label': item.toString(), 'value': item.toString()};
              }
            }).toList();
            logger.info(
              'Loaded ${_predefinedInputs.length} predefined inputs from ${configFile.path}',
            );
          }
        }
      }
      notifyListeners();
    } catch (e) {
      logger.severe('Failed to load config.json: $e');
    }
  }

  Future<void> savePaths(String adb, String scrcpy, String gnirehtet) async {
    _adbPath = adb;
    _scrcpyPath = scrcpy;
    _gnirehtetPath = gnirehtet;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('adb_path', adb);
      await prefs.setString('scrcpy_path', scrcpy);
      await prefs.setString('gnirehtet_path', gnirehtet);
      await _writeConfigValues({
        'adb_path': adb,
        'scrcpy_path': scrcpy,
        'gnirehtet_path': gnirehtet,
      });
      logger.info(
        'Paths saved successfully: adb=$adb, scrcpy=$scrcpy, gnirehtet=$gnirehtet',
      );
    } catch (e) {
      logger.severe('Failed to save settings: $e');
    }
  }

  Future<void> saveGlassSettings({
    required double bgBlur,
    required double bgOpacity,
    required double dialogBlur,
    required double dialogOpacity,
  }) async {
    _bgBlur = bgBlur.clamp(0.0, 30.0).toDouble();
    _bgOpacity = bgOpacity.clamp(0.1, 1.0).toDouble();
    _dialogBlur = dialogBlur.clamp(0.0, 30.0).toDouble();
    _dialogOpacity = dialogOpacity.clamp(0.3, 1.0).toDouble();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('bg_blur', _bgBlur);
      await prefs.setDouble('bg_opacity', _bgOpacity);
      await prefs.setDouble('dialog_blur', _dialogBlur);
      await prefs.setDouble('dialog_opacity', _dialogOpacity);
    } catch (e) {
      logger.warning('SharedPreferences saveGlassSettings failed: $e');
    }

    await _writeConfigValues({
      'bg_blur': _bgBlur,
      'bg_opacity': _bgOpacity,
      'dialog_blur': _dialogBlur,
      'dialog_opacity': _dialogOpacity,
    });
  }

  Future<void> autoDetectPaths() async {
    // 1. Resolve relative executable directory and current directory
    final exeFile = File(Platform.resolvedExecutable);
    final exeDir = exeFile.parent.path;

    final localPathsAdb = [
      '$exeDir\\bin\\adb.exe',
      '${Directory.current.path}\\bin\\adb.exe',
    ];

    final localPathsScrcpy = [
      '$exeDir\\bin\\scrcpy.exe',
      '${Directory.current.path}\\bin\\scrcpy.exe',
    ];

    final localPathsGnirehtet = [
      '$exeDir\\bin\\gnirehtet.exe',
      '${Directory.current.path}\\bin\\gnirehtet.exe',
      '$exeDir\\bin\\gnirehtet-rust-win64\\gnirehtet.exe',
      '${Directory.current.path}\\bin\\gnirehtet-rust-win64\\gnirehtet.exe',
    ];

    String detectedAdb = '';
    for (final path in localPathsAdb) {
      if (File(path).existsSync()) {
        detectedAdb = path;
        break;
      }
    }

    String detectedScrcpy = '';
    for (final path in localPathsScrcpy) {
      if (File(path).existsSync()) {
        detectedScrcpy = path;
        break;
      }
    }

    String detectedGnirehtet = '';
    for (final path in localPathsGnirehtet) {
      if (File(path).existsSync()) {
        detectedGnirehtet = path;
        break;
      }
    }

    // 2. Fallbacks for ADB if not found locally
    if (detectedAdb.isEmpty) {
      final adbSearchPaths = [
        'C:\\adb\\adb.exe',
        '${Platform.environment['USERPROFILE']}\\AppData\\Local\\Android\\Sdk\\platform-tools\\adb.exe',
        '${Platform.environment['USERPROFILE']}\\Downloads\\platform-tools\\adb.exe',
        'adb.exe', // system PATH
      ];

      for (final path in adbSearchPaths) {
        if (path == 'adb.exe') {
          final res = await Utils.runLocalCommand('where', ['adb']);
          if (res.exitCode == 0) {
            detectedAdb = res.stdout.toString().split('\n').first.trim();
            break;
          }
        } else if (File(path).existsSync()) {
          detectedAdb = path;
          break;
        }
      }
    }

    // 3. Fallbacks for Scrcpy if not found locally
    if (detectedScrcpy.isEmpty) {
      final scrcpySearchPaths = [
        'C:\\scrcpy\\scrcpy.exe',
        '${Platform.environment['USERPROFILE']}\\Downloads\\scrcpy-win64\\scrcpy.exe',
        'scrcpy.exe', // system PATH
      ];

      for (final path in scrcpySearchPaths) {
        if (path == 'scrcpy.exe') {
          final res = await Utils.runLocalCommand('where', ['scrcpy']);
          if (res.exitCode == 0) {
            detectedScrcpy = res.stdout.toString().split('\n').first.trim();
            break;
          }
        } else if (File(path).existsSync()) {
          detectedScrcpy = path;
          break;
        }
      }
    }

    // 4. Fallbacks for Gnirehtet if not found locally
    if (detectedGnirehtet.isEmpty) {
      final gnirehtetSearchPaths = [
        'C:\\gnirehtet\\gnirehtet.exe',
        '${Platform.environment['USERPROFILE']}\\Downloads\\gnirehtet-rust-win64\\gnirehtet.exe',
        'gnirehtet.exe', // system PATH
      ];

      for (final path in gnirehtetSearchPaths) {
        if (path == 'gnirehtet.exe') {
          final res = await Utils.runLocalCommand('where', ['gnirehtet']);
          if (res.exitCode == 0) {
            detectedGnirehtet = res.stdout.toString().split('\n').first.trim();
            break;
          }
        } else if (File(path).existsSync()) {
          detectedGnirehtet = path;
          break;
        }
      }
    }

    if (detectedAdb.isNotEmpty ||
        detectedScrcpy.isNotEmpty ||
        detectedGnirehtet.isNotEmpty) {
      await savePaths(
        detectedAdb.isNotEmpty ? detectedAdb : _adbPath,
        detectedScrcpy.isNotEmpty ? detectedScrcpy : _scrcpyPath,
        detectedGnirehtet.isNotEmpty ? detectedGnirehtet : _gnirehtetPath,
      );
    }
  }

  // ==========================================
  // DEVICE CONNECTION & MONITORS
  // ==========================================

  Future<void> scanDevices() async {
    if (_isSearchingDevices || _adbPath.isEmpty) return;
    _isSearchingDevices = true;
    notifyListeners();

    try {
      final res = await Process.run(
        _adbPath,
        ['devices'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        final lines = res.stdout.toString().split('\n');
        final List<String> devices = [];
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('List of devices attached'))
            continue;
          final parts = trimmed.split(RegExp(r'\s+'));
          if (parts.length >= 2 && parts[1] == 'device') {
            devices.add(parts[0]);
          }
        }

        _connectedDevices = devices;
        // Start media queries as soon as device discovery completes. The
        // results are cached per device so selecting a device later is local.
        _preloadLatestMedia(devices);

        // Fetch details for new devices
        for (final dev in devices) {
          if (!_devicesDetails.containsKey(dev)) {
            final modelRes = await Process.run(
              _adbPath,
              ['-s', dev, 'shell', 'getprop', 'ro.product.model'],
              stdoutEncoding: utf8,
              stderrEncoding: utf8,
            );
            final verRes = await Process.run(
              _adbPath,
              ['-s', dev, 'shell', 'getprop', 'ro.build.version.release'],
              stdoutEncoding: utf8,
              stderrEncoding: utf8,
            );

            _devicesDetails[dev] = {
              'model': modelRes.exitCode == 0
                  ? modelRes.stdout.toString().trim()
                  : 'Android Device',
              'version': verRes.exitCode == 0
                  ? verRes.stdout.toString().trim()
                  : 'Unknown',
            };
          }
        }

        // Clean details for disconnected devices
        _devicesDetails.removeWhere((key, _) => !devices.contains(key));

        // Auto select if only one device is connected
        if (_selectedDevice == null && devices.isNotEmpty) {
          final dev = devices.first;
          _selectedDevice = dev;
          _apps.clear();
          _appsError = '';
          _latestMedia = List<AndroidMediaItem>.of(
            _latestMediaByDevice[dev] ?? const [],
          );
          _isMediaLoading = !_latestMediaByDevice.containsKey(dev);
          unawaited(() async {
            await loadDeviceSyncSettings(dev);
            if (_selectedDevice == dev) {
              unawaited(loadAndroidDirectory(_androidCurrentPath));
              unawaited(fetchLatestMedia());
              if (_lastSyncAutoSync &&
                  _lastSyncPcPath.isNotEmpty &&
                  _lastSyncAndroidPath.isNotEmpty) {
                startSyncFolder(
                  pcPath: _lastSyncPcPath,
                  androidPath: _lastSyncAndroidPath,
                  direction: _lastSyncDirection,
                  deleteExtra: _lastSyncDeleteExtra,
                );
              }
            }
          }());
        } else if (_selectedDevice != null &&
            !devices.contains(_selectedDevice)) {
          unawaited(stopReverseTethering());
          _selectedDevice = null;
          _androidFiles.clear();
          _latestMedia.clear();
          _isMediaLoading = false;
          _apps.clear();
          _appsError = '';
        }
      }
    } catch (e) {
      logger.severe('Failed to scan devices: $e');
    } finally {
      _isSearchingDevices = false;
      notifyListeners();
    }
  }

  Future<bool> connectWirelessDevice(String host, int port) async {
    final normalizedHost = host.trim();
    if (normalizedHost.isEmpty || port < 1 || port > 65535) {
      _wirelessStatus = 'Enter a valid host and port.';
      notifyListeners();
      return false;
    }

    final endpoint = '$normalizedHost:$port';
    _isWirelessConnecting = true;
    _wirelessStatus = 'Connecting to $endpoint...';
    notifyListeners();

    try {
      final result = await _adbService.connect(_adbPath, endpoint);
      if (!result.isSuccess ||
          !result.combinedOutput.toLowerCase().contains('connected')) {
        _wirelessStatus = result.combinedOutput.isEmpty
            ? 'Unable to connect to $endpoint.'
            : result.combinedOutput;
        return false;
      }

      if (!_wirelessEndpoints.contains(endpoint)) {
        _wirelessEndpoints = [..._wirelessEndpoints, endpoint];
        await _writeConfigValues({'wireless_endpoints': _wirelessEndpoints});
      }
      _wirelessStatus = 'Connected to $endpoint';
      await scanDevices();
      return true;
    } on Object catch (error) {
      _wirelessStatus = error.toString();
      return false;
    } finally {
      _isWirelessConnecting = false;
      notifyListeners();
    }
  }

  Future<bool> disconnectWirelessDevice(String endpoint) async {
    final result = await _adbService.disconnect(_adbPath, endpoint);
    if (!result.isSuccess) {
      _wirelessStatus = result.combinedOutput;
      notifyListeners();
      return false;
    }

    _wirelessEndpoints = _wirelessEndpoints
        .where((item) => item != endpoint)
        .toList(growable: false);
    _wirelessStatus = 'Disconnected from $endpoint';
    await _writeConfigValues({'wireless_endpoints': _wirelessEndpoints});
    await scanDevices();
    notifyListeners();
    return true;
  }

  Future<DiagnosticsReport> runDiagnostics() async {
    final report = await _diagnosticsService.run(
      adbPath: _adbPath,
      scrcpyPath: _scrcpyPath,
      gnirehtetPath: _gnirehtetPath,
      selectedDevice: _selectedDevice,
    );
    _diagnosticsReport = report;
    notifyListeners();
    return report;
  }

  Future<DeviceWorkspaceProfile?> saveCurrentWorkspace(String name) async {
    final deviceId = _selectedDevice;
    if (deviceId == null || deviceId.isEmpty || name.trim().isEmpty) {
      return null;
    }

    final now = DateTime.now();
    final endpoint = _wirelessEndpoints.firstWhere(
      (item) => item.startsWith('$deviceId:'),
      orElse: () => '',
    );
    final profile = DeviceWorkspaceProfile(
      id: '${deviceId}_${now.microsecondsSinceEpoch}',
      name: name.trim(),
      deviceId: deviceId,
      wirelessEndpoint: endpoint,
      adbPath: _adbPath,
      scrcpyPath: _scrcpyPath,
      gnirehtetPath: _gnirehtetPath,
      syncPcPath: _lastSyncPcPath,
      syncAndroidPath: _lastSyncAndroidPath,
      createdAt: now,
      lastUsedAt: now,
    );
    _workspaceProfiles = await _workspaceStore.upsert(profile);
    notifyListeners();
    return profile;
  }

  Future<void> deleteWorkspace(String id) async {
    _workspaceProfiles = await _workspaceStore.remove(id);
    notifyListeners();
  }

  Future<bool> applyWorkspace(DeviceWorkspaceProfile profile) async {
    final hasPaths =
        profile.adbPath.isNotEmpty &&
        profile.scrcpyPath.isNotEmpty &&
        profile.gnirehtetPath.isNotEmpty;
    if (hasPaths) {
      await savePaths(
        profile.adbPath,
        profile.scrcpyPath,
        profile.gnirehtetPath,
      );
    }

    if (profile.wirelessEndpoint.isNotEmpty &&
        !_connectedDevices.contains(profile.deviceId)) {
      final separator = profile.wirelessEndpoint.lastIndexOf(':');
      final host = separator > 0
          ? profile.wirelessEndpoint.substring(0, separator)
          : profile.wirelessEndpoint;
      final port = separator > 0
          ? int.tryParse(profile.wirelessEndpoint.substring(separator + 1)) ??
                5555
          : 5555;
      await connectWirelessDevice(host, port);
    }

    await scanDevices();
    if (!_connectedDevices.contains(profile.deviceId)) return false;
    await selectDevice(profile.deviceId);
    _workspaceProfiles = await _workspaceStore.upsert(
      profile.copyWith(lastUsedAt: DateTime.now()),
    );
    notifyListeners();
    return true;
  }

  Future<void> saveScrcpyProfile(ScrcpyProfile profile) async {
    final normalized = profile.name.trim();
    if (normalized.isEmpty) return;
    final updated = _scrcpyProfiles
        .where((item) => item.name.toLowerCase() != normalized.toLowerCase())
        .toList();
    updated.add(
      ScrcpyProfile(
        name: normalized,
        stayOnTop: profile.stayOnTop,
        fullscreen: profile.fullscreen,
        noControl: profile.noControl,
        keepAwake: profile.keepAwake,
        borderless: profile.borderless,
        noAudio: profile.noAudio,
      ),
    );
    _scrcpyProfiles = updated;
    await _scrcpyProfileStore.save(_scrcpyProfiles);
    notifyListeners();
  }

  Future<void> deleteScrcpyProfile(String name) async {
    _scrcpyProfiles = _scrcpyProfiles
        .where((profile) => profile.name != name)
        .toList(growable: false);
    await _scrcpyProfileStore.save(_scrcpyProfiles);
    notifyListeners();
  }

  Map<String, dynamic> exportSettingsSnapshot() {
    return {
      'adb_path': _adbPath,
      'scrcpy_path': _scrcpyPath,
      'gnirehtet_path': _gnirehtetPath,
      'screenshot_dir': _screenshotDir,
      'media_download_dir': _mediaDownloadDir,
      'bg_blur': _bgBlur,
      'bg_opacity': _bgOpacity,
      'dialog_blur': _dialogBlur,
      'dialog_opacity': _dialogOpacity,
      'last_sync_pc_path': _lastSyncPcPath,
      'last_sync_android_path': _lastSyncAndroidPath,
      'last_sync_direction': _lastSyncDirection,
      'last_sync_delete_extra': _lastSyncDeleteExtra,
      'last_sync_auto_sync': _lastSyncAutoSync,
      'wireless_endpoints': _wirelessEndpoints,
      'scrcpy_profiles': _scrcpyProfiles
          .map((profile) => profile.toJson())
          .toList(growable: false),
      'device_workspaces': _workspaceProfiles
          .map((profile) => profile.toJson())
          .toList(growable: false),
    };
  }

  Future<void> exportSettingsBackup(String path) async {
    await _settingsBackupService.exportToFile(
      path: path,
      settings: exportSettingsSnapshot(),
    );
  }

  Future<bool> importSettingsBackup(String path) async {
    try {
      final data = await _settingsBackupService.importFromFile(path);
      await savePaths(
        data['adb_path']?.toString() ?? _adbPath,
        data['scrcpy_path']?.toString() ?? _scrcpyPath,
        data['gnirehtet_path']?.toString() ?? _gnirehtetPath,
      );
      await saveGlassSettings(
        bgBlur: _parseDouble(data['bg_blur'], _bgBlur),
        bgOpacity: _parseDouble(data['bg_opacity'], _bgOpacity),
        dialogBlur: _parseDouble(data['dialog_blur'], _dialogBlur),
        dialogOpacity: _parseDouble(data['dialog_opacity'], _dialogOpacity),
      );
      await saveSyncSettings(
        pcPath: data['last_sync_pc_path']?.toString() ?? _lastSyncPcPath,
        androidPath:
            data['last_sync_android_path']?.toString() ?? _lastSyncAndroidPath,
        direction:
            data['last_sync_direction']?.toString() ?? _lastSyncDirection,
        deleteExtra: data['last_sync_delete_extra'] == true,
        autoSync: data['last_sync_auto_sync'] == true,
      );

      final endpoints = data['wireless_endpoints'];
      if (endpoints is List) {
        _wirelessEndpoints = endpoints
            .map((endpoint) => endpoint.toString().trim())
            .where((endpoint) => endpoint.isNotEmpty)
            .toSet()
            .toList(growable: false);
        await _writeConfigValues({'wireless_endpoints': _wirelessEndpoints});
      }

      final profiles = data['scrcpy_profiles'];
      if (profiles is List) {
        _scrcpyProfiles = profiles
            .whereType<Map<Object?, Object?>>()
            .map(
              (entry) =>
                  ScrcpyProfile.fromJson(Map<String, dynamic>.from(entry)),
            )
            .where((profile) => profile.name.trim().isNotEmpty)
            .toList(growable: false);
        await _scrcpyProfileStore.save(_scrcpyProfiles);
      }

      final workspaces = data['device_workspaces'];
      if (workspaces is List) {
        _workspaceProfiles = workspaces
            .whereType<Map<Object?, Object?>>()
            .map(
              (entry) => DeviceWorkspaceProfile.fromJson(
                Map<String, dynamic>.from(entry),
              ),
            )
            .where((profile) => profile.id.trim().isNotEmpty)
            .toList(growable: false);
        await _workspaceStore.save(_workspaceProfiles);
      }
      notifyListeners();
      return true;
    } catch (error) {
      logger.warning('Settings backup import failed: $error');
      return false;
    }
  }

  Future<void> selectDevice(String? dev) async {
    if (_selectedDevice == dev) return;
    if (_scrcpyProcess != null) {
      stopMirroring();
    }
    if (_gnirehtetProcess != null) {
      unawaited(stopReverseTethering());
    }
    if (dev != null) {
      await loadDeviceSyncSettings(dev);
    }
    _selectedDevice = dev;
    _androidCurrentPath = '/sdcard';
    _androidFiles.clear();
    _latestMedia = dev == null
        ? <AndroidMediaItem>[]
        : List<AndroidMediaItem>.of(_latestMediaByDevice[dev] ?? const []);
    _isMediaLoading = dev != null && !_latestMediaByDevice.containsKey(dev);
    _selectedMediaPaths.clear();
    _apps.clear();
    _appsError = '';
    notifyListeners();
    if (dev != null) {
      unawaited(loadAndroidDirectory(_androidCurrentPath));
      unawaited(fetchLatestMedia());
      if (_lastSyncAutoSync &&
          _lastSyncPcPath.isNotEmpty &&
          _lastSyncAndroidPath.isNotEmpty) {
        startSyncFolder(
          pcPath: _lastSyncPcPath,
          androidPath: _lastSyncAndroidPath,
          direction: _lastSyncDirection,
          deleteExtra: _lastSyncDeleteExtra,
        );
      }
    }
  }

  // ==========================================
  // SCREEN MIRRORING (SCRCPY)
  // ==========================================

  Future<bool> launchMirroring({
    bool stayOnTop = false,
    bool fullscreen = false,
    bool noControl = false,
    bool keepAwake = false,
    bool borderless = false,
    bool noAudio = false,

    /// Optional callback: returns physical-pixel rect {x,y,width,height} of the
    /// target placeholder so C++ can position the window before showing it.
    Map<String, double> Function()? getTargetRect,
  }) async {
    if (_selectedDevice == null || _scrcpyPath.isEmpty) return false;
    if (_scrcpyProcess != null) return false; // Already mirroring

    // Force unique window title so we can find it via Win32 FindWindow
    final args = [
      '-s',
      _selectedDevice!,
      '--window-title',
      'JA_ADB_Tool_Mirror',
    ];
    if (stayOnTop) args.add('--always-on-top');
    if (fullscreen) args.add('--fullscreen');
    if (noControl) args.add('--no-control');
    if (keepAwake) args.add('--stay-awake');
    if (noAudio) args.add('--no-audio');

    try {
      logger.info('Launching scrcpy: $_scrcpyPath ${args.join(' ')}');

      final proc = await Process.start(_scrcpyPath, args);
      _scrcpyProcess = proc;
      notifyListeners();

      // Polling to find and embed the Scrcpy window as soon as it gets registered by Windows
      // Delay 2000ms first: gives SDL2 + DirectX time to fully initialize its renderer
      // before Win32 SetParent is called (calling SetParent too early crashes scrcpy)
      Future.delayed(const Duration(milliseconds: 2000), () async {
        for (int i = 0; i < 30; i++) {
          if (_scrcpyProcess == null) break; // process stopped
          try {
            // Build args — include target rect if available so C++ can
            // position the window BEFORE showing it (prevents the corner flash)
            final Map<String, dynamic> embedArgs = {
              'title': 'JA_ADB_Tool_Mirror',
              'pid': proc.pid,
            };
            if (getTargetRect != null) {
              final rect = getTargetRect();
              embedArgs.addAll(rect);
            }
            final bool embedded =
                await _mirrorChannel.invokeMethod<bool>(
                  'embedMirror',
                  embedArgs,
                ) ??
                false;
            if (embedded) {
              logger.info(
                'Scrcpy window embedded successfully after ${500 + i * 200}ms',
              );
              break;
            }
          } catch (e) {
            logger.warning('Failed to invoke embedMirror: $e');
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
      });

      // Monitor exit — auto-retry once on startup failure (exit code 1 within 3s)
      final launchTime = DateTime.now();
      unawaited(
        proc.exitCode.then((code) async {
          logger.info('Scrcpy process exited with code: $code');
          if (_scrcpyProcess == proc) {
            _scrcpyProcess = null;
            unawaited(
              _mirrorChannel
                  .invokeMethod('unembedMirror')
                  .catchError((_) => null),
            );
            notifyListeners();

            // Auto-retry once if startup failure (any non-zero code) within first 5 seconds
            final elapsed = DateTime.now()
                .difference(launchTime)
                .inMilliseconds;
            if (code != 0 && elapsed < 5000) {
              logger.info(
                'Scrcpy startup failed quickly (${elapsed}ms). Auto-retrying...',
              );
              await Future<void>.delayed(const Duration(milliseconds: 1000));
              if (_scrcpyProcess == null && _selectedDevice != null) {
                await launchMirroring(
                  stayOnTop: stayOnTop,
                  fullscreen: fullscreen,
                  noControl: noControl,
                  keepAwake: keepAwake,
                  borderless: borderless,
                  noAudio: noAudio,
                  getTargetRect: getTargetRect,
                );
              }
            }
          }
        }),
      );

      // Read output logs silently
      proc.stdout.transform(utf8.decoder).listen((data) {
        logger.info('[SCRCPY] ${data.trim()}');
      });
      proc.stderr.transform(utf8.decoder).listen((data) {
        logger.warning('[SCRCPY ERR] ${data.trim()}');
      });

      return true;
    } catch (e) {
      logger.severe('Failed to launch scrcpy: $e');
      _scrcpyProcess = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> launchStandaloneMirroring({
    bool stayOnTop = false,
    bool fullscreen = false,
    bool noControl = false,
    bool keepAwake = false,
    bool borderless = false,
    bool noAudio = false,
  }) async {
    if (_selectedDevice == null || _scrcpyPath.isEmpty) return false;

    final args = [
      '-s',
      _selectedDevice!,
      '--window-title',
      'JA Mirror - $_selectedDevice',
    ];
    if (stayOnTop) args.add('--always-on-top');
    if (fullscreen) args.add('--fullscreen');
    if (noControl) args.add('--no-control');
    if (keepAwake) args.add('--stay-awake');
    if (noAudio) args.add('--no-audio');

    try {
      logger.info(
        'Launching standalone scrcpy for $_selectedDevice: $_scrcpyPath ${args.join(' ')}',
      );
      await Process.start(_scrcpyPath, args);
      return true;
    } catch (e) {
      logger.severe('Failed to launch standalone scrcpy: $e');
      return false;
    }
  }

  void stopMirroring() {
    if (_scrcpyProcess != null) {
      logger.info('Stopping scrcpy process...');
      _scrcpyProcess!.kill();
      _scrcpyProcess = null;
      _mirrorChannel.invokeMethod('unembedMirror').catchError((_) => null);
      notifyListeners();
    }
  }

  Future<String?> takeScreenshot({String? targetFolder}) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return null;
    try {
      String? pcDir = targetFolder ?? _screenshotDir;
      if (pcDir.isEmpty) {
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          pcDir = downloadsDir.path;
        } else {
          pcDir = Directory.current.path;
        }
      }

      final now = DateTime.now();
      final timestamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final pcFileName = 'screenshot_$timestamp.png';
      final pcPath = '$pcDir\\$pcFileName';

      logger.info('Taking screenshot via exec-out stream to $pcPath');
      final res = await Process.run(_adbPath, [
        '-s',
        _selectedDevice!,
        'exec-out',
        'screencap',
        '-p',
      ], stdoutEncoding: null);

      if (res.exitCode == 0) {
        final List<int> bytes = res.stdout as List<int>;
        if (bytes.isNotEmpty) {
          await File(pcPath).writeAsBytes(bytes);
          logger.info('Screenshot saved to $pcPath');
          return pcPath;
        }
      }
      logger.severe('screencap exec-out failed: ${res.stderr}');
      return null;
    } catch (e) {
      logger.severe('Failed to take screenshot: $e');
      return null;
    }
  }

  // ==========================================
  // DUAL-WAY FILE EXPLORER (ANDROID LS/PUSH/PULL)
  // ==========================================

  Future<void> loadAndroidDirectory(String path) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return;
    _isAndroidLoading = true;
    _androidExplorerError = '';
    _androidCurrentPath = path;
    notifyListeners();

    try {
      // Run ls -la. For symlinks like /sdcard, appending a trailing slash forces
      // ls to list the target directory's contents rather than the symlink itself.
      final String listPath = (path == '/' || path.endsWith('/'))
          ? path
          : '$path/';
      final res = await Process.run(
        _adbPath,
        ['-s', _selectedDevice!, 'shell', 'ls', '-la', listPath],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode != 0) {
        throw Exception(res.stderr.toString().trim());
      }

      final lines = res.stdout.toString().split('\n');
      final List<AndroidFileItem> items = [];

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('total')) continue;

        final parts = trimmed.split(RegExp(r'\s+'));
        if (parts.length < 4) continue;

        final permissions = parts[0];
        final isDir =
            permissions.startsWith('d') ||
            permissions.startsWith('l'); // symlinks as directories

        // Robust date-time, size, and name extraction
        int dateIndex = -1;
        bool isYearMonthDay = false;
        for (int i = 0; i < parts.length; i++) {
          if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(parts[i])) {
            dateIndex = i;
            isYearMonthDay = true;
            break;
          } else if (RegExp(
            r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$',
            caseSensitive: false,
          ).hasMatch(parts[i])) {
            dateIndex = i;
            isYearMonthDay = false;
            break;
          }
        }

        String name = '';
        int size = 0;
        String dateModified = '';

        if (dateIndex != -1) {
          final int dateEndIndex = isYearMonthDay
              ? dateIndex + 1
              : dateIndex + 2;
          if (dateEndIndex < parts.length - 1) {
            name = parts.sublist(dateEndIndex + 1).join(' ');
            dateModified = parts.sublist(dateIndex, dateEndIndex + 1).join(' ');
            size = int.tryParse(parts[dateIndex - 1]) ?? 0;
          } else {
            name = parts.last;
            dateModified = 'Unknown';
          }
        } else {
          name = parts.last;
          dateModified = 'Unknown';
        }

        if (name == '.' || name == '..') continue;

        items.add(
          AndroidFileItem(
            name: name,
            path: path == '/' ? '/$name' : '$path/$name',
            isDirectory: isDir,
            size: size,
            dateModified: dateModified,
          ),
        );
      }

      // Sort: Directories first, then alphabetically
      items.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      _androidFiles = items;
    } catch (e) {
      _androidExplorerError = e.toString();
      logger.severe('Failed to load Android folder: $e');
    } finally {
      _isAndroidLoading = false;
      notifyListeners();
    }
  }

  Process? _activeTransferProcess;
  bool _isTransferring = false;
  double _transferProgress = -1.0;
  String _transferStatus = '';

  bool get isTransferring => _isTransferring;
  double get transferProgress => _transferProgress;
  String get transferStatus => _transferStatus;

  void cancelTransfer() {
    if (_activeTransferProcess != null) {
      _activeTransferProcess!.kill();
      _activeTransferProcess = null;
    }
  }

  Future<bool> pullAndroidFile(
    String androidPath,
    String pcDirectory, {
    int? fileSize,
  }) async {
    if (_selectedDevice == null || _adbPath.isEmpty || _isTransferring)
      return false;

    _isTransferring = true;
    _transferProgress = -1.0;
    _transferStatus = 'Preparing download...';
    notifyListeners();

    Timer? progressTimer;

    try {
      final fileName = androidPath.split('/').last;
      final targetPath = '$pcDirectory\\$fileName';
      logger.info('Pulling $androidPath to $targetPath');

      // Determine total size
      int totalSize = fileSize ?? 0;
      if (totalSize <= 0) {
        final statRes = await Process.run(
          _adbPath,
          ['-s', _selectedDevice!, 'shell', 'stat', '-c', '%s', androidPath],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        totalSize = int.tryParse(statRes.stdout.toString().trim()) ?? 0;
      }

      // If target file exists, delete it first to start tracking from 0
      final localFile = File(targetPath);
      if (localFile.existsSync()) {
        try {
          localFile.deleteSync();
        } catch (_) {}
      }

      final process = await Process.start(_adbPath, [
        '-s',
        _selectedDevice!,
        'pull',
        androidPath,
        targetPath,
      ]);
      _activeTransferProcess = process;

      if (totalSize > 0) {
        DateTime lastTime = DateTime.now();
        int lastSize = 0;

        progressTimer = Timer.periodic(const Duration(milliseconds: 500), (
          timer,
        ) {
          if (!_isTransferring) {
            timer.cancel();
            return;
          }
          try {
            final f = File(targetPath);
            if (f.existsSync()) {
              final currentSize = f.lengthSync();
              final now = DateTime.now();
              final timeDeltaSeconds =
                  now.difference(lastTime).inMilliseconds / 1000.0;
              if (timeDeltaSeconds > 0) {
                final sizeDelta = currentSize - lastSize;
                final speedBytesPerSec = sizeDelta / timeDeltaSeconds;

                _transferProgress = (currentSize / totalSize).clamp(0.0, 1.0);
                final pct = (_transferProgress * 100).toInt();
                final speedStr =
                    Utils.formatBytes(speedBytesPerSec.toInt()) + '/s';
                _transferStatus = 'Downloading: $pct% • $speedStr';
                notifyListeners();

                lastSize = currentSize;
                lastTime = now;
              }
            }
          } catch (e) {
            logger.warning(
              'Error reading file length during pull progress: $e',
            );
          }
        });
      }

      final exitCode = await process.exitCode;
      progressTimer?.cancel();
      _activeTransferProcess = null;
      _isTransferring = false;
      notifyListeners();

      return exitCode == 0;
    } catch (e) {
      logger.severe('Failed to pull file: $e');
      progressTimer?.cancel();
      _activeTransferProcess = null;
      _isTransferring = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> pushFileToAndroid(String pcPath, String androidDirectory) async {
    if (_selectedDevice == null || _adbPath.isEmpty || _isTransferring)
      return false;

    _isTransferring = true;
    _transferProgress = -1.0;
    _transferStatus = 'Preparing upload...';
    notifyListeners();

    Timer? progressTimer;

    try {
      logger.info('Pushing $pcPath to $androidDirectory');

      final f = File(pcPath);
      final totalSize = f.existsSync() ? f.lengthSync() : 0;

      final fileName = pcPath.split(RegExp(r'[\\/]')).last;
      final targetPath = androidDirectory.endsWith('/')
          ? '$androidDirectory$fileName'
          : '$androidDirectory/$fileName';

      // NOTE: We intentionally do NOT delete the target file before pushing.
      // On some devices (e.g. NLS-MT95 with Android 13 FUSE bug), the FUSE daemon
      // blocks new file creation (FUSE_CREATE opcode → EFAULT) but allows
      // overwriting existing files.  Deleting first prevents the overwrite path
      // and makes every push fail on such devices.

      final process = await Process.start(_adbPath, [
        '-s',
        _selectedDevice!,
        'push',
        pcPath,
        androidDirectory,
      ]);
      _activeTransferProcess = process;

      // Collect stderr to detect device-level errors (e.g. FUSE "Bad address")
      final stderrBuf = StringBuffer();
      process.stderr.transform(utf8.decoder).listen((d) => stderrBuf.write(d));

      if (totalSize > 0) {
        DateTime lastTime = DateTime.now();
        int lastSize = 0;

        progressTimer = Timer.periodic(const Duration(milliseconds: 500), (
          timer,
        ) async {
          if (!_isTransferring) {
            timer.cancel();
            return;
          }
          try {
            final statRes = await Process.run(
              _adbPath,
              ['-s', _selectedDevice!, 'shell', 'stat', '-c', '%s', targetPath],
              stdoutEncoding: utf8,
              stderrEncoding: utf8,
            );
            final stdoutStr = statRes.stdout.toString().trim();
            if (stdoutStr.isNotEmpty && !stdoutStr.contains('No such file')) {
              final currentSize = int.tryParse(stdoutStr) ?? 0;
              final now = DateTime.now();
              final timeDeltaSeconds =
                  now.difference(lastTime).inMilliseconds / 1000.0;
              if (timeDeltaSeconds > 0) {
                final sizeDelta = currentSize - lastSize;
                final speedBytesPerSec = sizeDelta / timeDeltaSeconds;

                _transferProgress = (currentSize / totalSize).clamp(0.0, 1.0);
                final pct = (_transferProgress * 100).toInt();
                final speedStr =
                    Utils.formatBytes(speedBytesPerSec.toInt()) + '/s';
                _transferStatus = 'Uploading: $pct% • $speedStr';
                notifyListeners();

                lastSize = currentSize;
                lastTime = now;
              }
            }
          } catch (e) {
            logger.warning(
              'Error reading Android file length during push progress: $e',
            );
          }
        });
      }

      final exitCode = await process.exitCode;
      progressTimer?.cancel();
      _activeTransferProcess = null;

      final stderrStr = stderrBuf.toString();

      if (exitCode == 0) {
        logger.info('Push successful: $fileName → $androidDirectory');
        _isTransferring = false;
        notifyListeners();
        unawaited(triggerAndroidMediaScan(androidDirectory));
        await loadAndroidDirectory(_androidCurrentPath);
        return true;
      }

      // ── FUSE "Bad address" workaround ─────────────────────────────────────
      // On some Android 13 devices the FUSE daemon returns EFAULT for
      // FUSE_CREATE (new file), but allows FUSE_WRITE (overwrite existing file).
      // Push via f2fs-mounted /sdcard/Android/data/ always succeeds.
      // We push there first, then attempt to move the file to the real target.
      if (stderrStr.contains('Bad address') ||
          stderrStr.contains('remote couldn\'t create file')) {
        logger.warning(
          'Push failed (FUSE Bad address) for $fileName → $androidDirectory',
        );
        logger.info(
          'Attempting FUSE workaround: staging via /sdcard/Android/data/com.android.browser/',
        );

        _transferStatus = 'Retrying via staging path...';
        notifyListeners();

        // Step 1: push to f2fs staging area
        const stagingDir = '/sdcard/Android/data/com.android.browser';
        final stagingPath = '$stagingDir/$fileName';
        final stageRes = await Process.run(
          _adbPath,
          ['-s', _selectedDevice!, 'push', pcPath, stagingDir],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        if (stageRes.exitCode == 0) {
          logger.info('Stage push succeeded: $fileName → $stagingDir');

          // Step 2: move from staging to real target using shell mv
          final mvRes = await Process.run(
            _adbPath,
            ['-s', _selectedDevice!, 'shell', 'mv', stagingPath, targetPath],
            stdoutEncoding: utf8,
            stderrEncoding: utf8,
          );

          if (mvRes.exitCode == 0) {
            logger.info('Staging mv succeeded: $stagingPath → $targetPath');
            _isTransferring = false;
            notifyListeners();
            unawaited(triggerAndroidMediaScan(androidDirectory));
            await loadAndroidDirectory(_androidCurrentPath);
            return true;
          }

          // mv failed (FUSE still blocks rename-to-FUSE) — file is in staging
          logger.warning(
            'Push via staging: mv failed (${mvRes.stderr.toString().trim()}). '
            'File left at $stagingPath (device FUSE restriction).',
          );
          _isTransferring = false;
          notifyListeners();
          // Return false so caller knows the file is NOT at the expected path
          return false;
        }
      }

      logger.severe(
        'Push failed (exit code $exitCode) for $fileName → $androidDirectory',
      );
      logger.warning('Push stdout: ${stderrStr.trim()}');
      _isTransferring = false;
      notifyListeners();
      return false;
    } catch (e) {
      logger.severe('Failed to push file: $e');
      _activeTransferProcess = null;
      _isTransferring = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAndroidFile(String path, bool isDir) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return false;
    try {
      logger.info('Deleting $path (isDirectory=$isDir)');
      final res = await Process.run(
        _adbPath,
        ['-s', _selectedDevice!, 'shell', 'rm', isDir ? '-rf' : '-f', path],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        await loadAndroidDirectory(_androidCurrentPath);
        return true;
      }
      return false;
    } catch (e) {
      logger.severe('Failed to delete file: $e');
      return false;
    }
  }

  Future<bool> createAndroidFolder(String folderName) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return false;
    try {
      final newPath = _androidCurrentPath == '/'
          ? '/$folderName'
          : '$_androidCurrentPath/$folderName';
      logger.info('Creating folder: $newPath');
      final res = await Process.run(
        _adbPath,
        ['-s', _selectedDevice!, 'shell', 'mkdir', '-p', newPath],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        await loadAndroidDirectory(_androidCurrentPath);
        return true;
      }
      return false;
    } catch (e) {
      logger.severe('Failed to create folder: $e');
      return false;
    }
  }

  // ==========================================
  // LATEST MEDIA DATABASE QUERY & COPY
  // ==========================================

  void _preloadLatestMedia(Iterable<String> devices) {
    for (final device in devices) {
      unawaited(
        _ensureLatestMedia(device).then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            logger.warning('Preloading media for $device failed: $error');
          },
        ),
      );
    }
  }

  Future<List<AndroidMediaItem>> _ensureLatestMedia(
    String device, {
    bool force = false,
  }) async {
    if (!force) {
      final cached = _latestMediaByDevice[device];
      if (cached != null) return cached;
    }

    final inFlight = _mediaFetchesByDevice[device];
    if (inFlight != null) return inFlight;

    late final Future<List<AndroidMediaItem>> fetch;
    fetch = _queryLatestMedia(device);
    _mediaFetchesByDevice[device] = fetch;
    try {
      final items = await fetch;
      final cached = List<AndroidMediaItem>.unmodifiable(items);
      _latestMediaByDevice[device] = cached;
      return cached;
    } finally {
      if (identical(_mediaFetchesByDevice[device], fetch)) {
        unawaited(_mediaFetchesByDevice.remove(device));
      }
    }
  }

  Future<void> fetchLatestMedia({bool force = false}) async {
    final device = _selectedDevice;
    if (device == null || _adbPath.isEmpty) return;

    if (!force && _latestMediaByDevice.containsKey(device)) {
      _latestMedia = List<AndroidMediaItem>.of(_latestMediaByDevice[device]!);
      _isMediaLoading = false;
      notifyListeners();
      return;
    }

    _isMediaLoading = true;
    _selectedMediaPaths.clear();
    notifyListeners();

    try {
      final items = await _ensureLatestMedia(device, force: force);
      if (_selectedDevice == device) {
        _latestMedia = List<AndroidMediaItem>.of(items);
      }
    } catch (e) {
      logger.severe('Failed to fetch latest media: $e');
    } finally {
      if (_selectedDevice == device) {
        _isMediaLoading = false;
        notifyListeners();
      }
    }
  }

  Future<List<AndroidMediaItem>> _queryLatestMedia(String deviceId) async {
    final List<AndroidMediaItem> items = [];

    try {
      // 1. Query Images
      final imgRes = await Process.run(
        _adbPath,
        [
          '-s',
          deviceId,
          'shell',
          'content',
          'query',
          '--uri',
          'content://media/external/images/media',
          '--projection',
          '_data:date_added',
          '--sort',
          "'date_added DESC'",
          '--limit',
          '50',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      if (imgRes.exitCode == 0) {
        items.addAll(_parseMediaRow(imgRes.stdout.toString(), isVideo: false));
      }

      // 2. Query Videos
      final vidRes = await Process.run(
        _adbPath,
        [
          '-s',
          deviceId,
          'shell',
          'content',
          'query',
          '--uri',
          'content://media/external/video/media',
          '--projection',
          '_data:date_added',
          '--sort',
          "'date_added DESC'",
          '--limit',
          '30',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      if (vidRes.exitCode == 0) {
        items.addAll(_parseMediaRow(vidRes.stdout.toString(), isVideo: true));
      }

      // If both content queries returned empty, perform fallback find scan
      if (items.isEmpty) {
        logger.info(
          'Content query returned empty, falling back to manual disk scan...',
        );

        bool parsedWithStat = false;
        final findRes = await Process.run(
          _adbPath,
          [
            '-s',
            deviceId,
            'shell',
            'find',
            '/sdcard/DCIM',
            '/sdcard/Pictures',
            '-type',
            'f',
            '\\(',
            '-name',
            '*.jpg',
            '-o',
            '-name',
            '*.jpeg',
            '-o',
            '-name',
            '*.png',
            '-o',
            '-name',
            '*.mp4',
            '-o',
            '-name',
            '*.mkv',
            '\\)',
            '-exec',
            'stat',
            '-c',
            '%Y:::%n',
            '{}',
            '+',
          ],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        if (findRes.exitCode == 0) {
          final lines = findRes.stdout.toString().split('\n');
          for (final line in lines) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) continue;

            final parts = trimmed.split(':::');
            if (parts.length < 2) continue;

            final timeStr = parts[0];
            final path = parts.sublist(1).join(':::').trim();
            if (path.isEmpty) continue;

            final dateSecs = int.tryParse(timeStr);
            if (dateSecs == null) continue;

            // Skip hidden files/folders
            if (path.split('/').any((part) => part.startsWith('.'))) continue;

            final name = path.split('/').last;
            final isVid = path.endsWith('.mp4') || path.endsWith('.mkv');

            items.add(
              AndroidMediaItem(
                path: path,
                dateAdded: dateSecs,
                name: name,
                isVideo: isVid,
              ),
            );
            parsedWithStat = true;
          }
        }

        if (!parsedWithStat) {
          logger.info(
            'Stat-based scan failed or empty, falling back to simple find...',
          );
          final simpleFindRes = await Process.run(
            _adbPath,
            [
              '-s',
              deviceId,
              'shell',
              'find',
              '/sdcard/DCIM',
              '/sdcard/Pictures',
              '-type',
              'f',
              '\\(',
              '-name',
              '*.jpg',
              '-o',
              '-name',
              '*.jpeg',
              '-o',
              '-name',
              '*.png',
              '-o',
              '-name',
              '*.mp4',
              '-o',
              '-name',
              '*.mkv',
              '\\)',
            ],
            stdoutEncoding: utf8,
            stderrEncoding: utf8,
          );

          if (simpleFindRes.exitCode == 0) {
            final paths = simpleFindRes.stdout.toString().split('\n');
            for (final path in paths) {
              final trimmedPath = path.trim();
              if (trimmedPath.isEmpty) continue;
              if (trimmedPath.split('/').any((part) => part.startsWith('.')))
                continue;
              final name = trimmedPath.split('/').last;
              final isVid =
                  trimmedPath.endsWith('.mp4') || trimmedPath.endsWith('.mkv');

              int dateSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              final datePattern = RegExp(r'(\d{8})_(\d{6})');
              final dashPattern = RegExp(
                r'(\d{4})-(\d{2})-(\d{2})-(\d{2})-(\d{2})-(\d{2})',
              );
              final match = datePattern.firstMatch(name);
              final dashMatch = dashPattern.firstMatch(name);

              if (match != null) {
                try {
                  final dateStr = match.group(1)!;
                  final timeStr = match.group(2)!;
                  final year = int.parse(dateStr.substring(0, 4));
                  final month = int.parse(dateStr.substring(4, 6));
                  final day = int.parse(dateStr.substring(6, 8));
                  final hour = int.parse(timeStr.substring(0, 2));
                  final minute = int.parse(timeStr.substring(2, 4));
                  final second = int.parse(timeStr.substring(4, 6));
                  dateSecs =
                      DateTime(
                        year,
                        month,
                        day,
                        hour,
                        minute,
                        second,
                      ).millisecondsSinceEpoch ~/
                      1000;
                } catch (_) {}
              } else if (dashMatch != null) {
                try {
                  final year = int.parse(dashMatch.group(1)!);
                  final month = int.parse(dashMatch.group(2)!);
                  final day = int.parse(dashMatch.group(3)!);
                  final hour = int.parse(dashMatch.group(4)!);
                  final minute = int.parse(dashMatch.group(5)!);
                  final second = int.parse(dashMatch.group(6)!);
                  dateSecs =
                      DateTime(
                        year,
                        month,
                        day,
                        hour,
                        minute,
                        second,
                      ).millisecondsSinceEpoch ~/
                      1000;
                } catch (_) {}
              } else {
                final msPattern = RegExp(r'^(\d{13})\.');
                final msMatch = msPattern.firstMatch(name);
                if (msMatch != null) {
                  final ms = int.tryParse(msMatch.group(1)!);
                  if (ms != null) {
                    dateSecs = ms ~/ 1000;
                  }
                } else {
                  final longNumPattern = RegExp(r'(\d{14})');
                  final longMatch = longNumPattern.firstMatch(name);
                  if (longMatch != null) {
                    try {
                      final str = longMatch.group(1)!;
                      final year = int.parse(str.substring(0, 4));
                      final month = int.parse(str.substring(4, 6));
                      final day = int.parse(str.substring(6, 8));
                      final hour = int.parse(str.substring(8, 10));
                      final minute = int.parse(str.substring(10, 12));
                      final second = int.parse(str.substring(12, 14));
                      dateSecs =
                          DateTime(
                            year,
                            month,
                            day,
                            hour,
                            minute,
                            second,
                          ).millisecondsSinceEpoch ~/
                          1000;
                    } catch (_) {}
                  }
                }
              }

              items.add(
                AndroidMediaItem(
                  path: trimmedPath,
                  dateAdded: dateSecs,
                  name: name,
                  isVideo: isVid,
                ),
              );
            }
          }
        }
      }

      // Sort all media by date added descending
      items.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      return items.take(100).toList(); // limit to latest 100
    } catch (e) {
      logger.severe('Failed to fetch latest media: $e');
      rethrow;
    }
  }

  List<AndroidMediaItem> _parseMediaRow(
    String output, {
    required bool isVideo,
  }) {
    final List<AndroidMediaItem> list = [];
    final lines = output.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      try {
        // Example: Row: 0 _data=/sdcard/DCIM/Camera/IMG.jpg, date_added=17182749
        final dataMatch = RegExp(r'_data=(.+?),').firstMatch(trimmed);
        final dateMatch = RegExp(r'date_added=(\d+)').firstMatch(trimmed);

        if (dataMatch != null && dateMatch != null) {
          final path = dataMatch.group(1)!.trim();
          // Skip if any component in the path starts with a dot (hidden files/folders like .thumbnails)
          if (path.split('/').any((part) => part.startsWith('.'))) continue;
          final name = path.split('/').last;
          final dateSecs = int.tryParse(dateMatch.group(1)!) ?? 0;
          list.add(
            AndroidMediaItem(
              path: path,
              dateAdded: dateSecs,
              name: name,
              isVideo: isVideo,
            ),
          );
        }
      } catch (_) {}
    }
    return list;
  }

  void toggleMediaSelection(String path) {
    if (_selectedMediaPaths.contains(path)) {
      _selectedMediaPaths.remove(path);
    } else {
      _selectedMediaPaths.add(path);
    }
    notifyListeners();
  }

  void selectAllMedia(bool select) {
    if (select) {
      _selectedMediaPaths = _latestMedia.map((e) => e.path).toSet();
    } else {
      _selectedMediaPaths.clear();
    }
    notifyListeners();
  }

  void selectLatestNMedia(int count) {
    _selectedMediaPaths.clear();
    final limit = count.clamp(0, _latestMedia.length);
    for (int i = 0; i < limit; i++) {
      _selectedMediaPaths.add(_latestMedia[i].path);
    }
    notifyListeners();
  }

  Future<bool> pullSelectedMedia(String pcDirectory) async {
    if (_selectedDevice == null ||
        _adbPath.isEmpty ||
        _selectedMediaPaths.isEmpty)
      return false;

    bool allSuccess = true;
    for (final path in _selectedMediaPaths) {
      final success = await pullAndroidFile(path, pcDirectory);
      if (!success) allSuccess = false;
    }
    return allSuccess;
  }

  // ==========================================
  // APK / XAPK INSTALLER (ZIP PARSING)
  // ==========================================

  void selectInstallerFile(String filePath) {
    selectInstallerFiles([filePath]);
  }

  void selectInstallerFiles(List<String> filePaths) {
    final selected = <String>[];
    for (final filePath in filePaths) {
      final extension = p.extension(filePath).toLowerCase();
      if ((extension == '.apk' || extension == '.xapk') &&
          !selected.contains(filePath)) {
        selected.add(filePath);
      }
    }

    final operationId = ++_installerOperationId;
    _installerFilePaths
      ..clear()
      ..addAll(selected);
    _installerFilePath = selected.isEmpty ? null : selected.first;
    _installerStatus = selected.isEmpty ? 'idle' : 'parsing';
    _installerLog = selected.isEmpty
        ? ''
        : 'Parsing ${selected.length} installation package${selected.length == 1 ? '' : 's'}...\n';
    _installerAppDetails.clear();
    _installerPackageDetails.clear();
    notifyListeners();

    if (selected.isNotEmpty) {
      unawaited(_parseInstallerPackages(operationId, selected));
    }
  }

  void removeInstallerFile(String filePath) {
    if (_isInstalling) return;
    _installerFilePaths.remove(filePath);
    _installerPackageDetails.remove(filePath);
    _installerFilePath = _installerFilePaths.isEmpty
        ? null
        : _installerFilePaths.first;
    _installerAppDetails = _installerFilePath == null
        ? {}
        : Map<String, String>.from(
            _installerPackageDetails[_installerFilePath!] ?? {},
          );
    _installerStatus = _installerFilePaths.isEmpty ? 'idle' : 'parsed';
    notifyListeners();
  }

  Future<void> _parseInstallerPackages(
    int operationId,
    List<String> filePaths,
  ) async {
    for (final filePath in filePaths) {
      if (operationId != _installerOperationId) return;
      final file = File(filePath);
      if (!file.existsSync()) {
        _installerLog += 'Error: File does not exist: $filePath\n';
        continue;
      }

      final ext = p.extension(filePath).toLowerCase();
      try {
        Map<String, String> details;
        if (ext == '.apk') {
          details = {
            'name': p.basename(filePath),
            'type': 'APK',
            'packageName': 'Will determine during install',
          };
          _installerLog += 'Parsed APK: ${p.basename(filePath)}\n';
        } else {
          _installerLog += 'Opening XAPK: ${p.basename(filePath)}...\n';
          details = await compute(_inspectXapkPackage, file.path);
          details = {...details, 'type': 'XAPK'};
          _installerLog +=
              'Parsed XAPK: ${details['name'] ?? p.basename(filePath)}\n';
        }
        if (operationId != _installerOperationId) return;
        _installerPackageDetails[filePath] = details;
        _installerAppDetails = Map<String, String>.from(details);
        notifyListeners();
      } catch (e) {
        if (operationId != _installerOperationId) return;
        _installerLog += 'Error parsing ${p.basename(filePath)}: $e\n';
        logger.severe('Failed to parse installer package: $e');
      }
    }
    if (operationId == _installerOperationId) {
      _installerStatus = _installerPackageDetails.isEmpty ? 'error' : 'parsed';
      notifyListeners();
    }
  }

  Future<bool> installPackage() => installPackages();

  Future<bool> installPackages() async {
    if (_isInstalling ||
        _selectedDevice == null ||
        _adbPath.isEmpty ||
        _installerFilePaths.isEmpty) {
      _installerLog += 'Error: Device not connected or package not selected.\n';
      notifyListeners();
      return false;
    }

    _isInstalling = true;
    _installerStatus = 'installing';
    _installerLog +=
        'Starting installation of ${_installerFilePaths.length} package${_installerFilePaths.length == 1 ? '' : 's'} on device $_selectedDevice...\n';
    notifyListeners();

    var allSuccess = true;
    final packages = List<String>.from(_installerFilePaths);
    for (var index = 0; index < packages.length; index++) {
      final filePath = packages[index];
      _installerLog +=
          '\n[${index + 1}/${packages.length}] ${p.basename(filePath)}\n';
      notifyListeners();
      final details = _installerPackageDetails[filePath] ?? const {};
      final success = await _installSinglePackage(filePath, details);
      if (!success) allSuccess = false;
      notifyListeners();
    }

    _installerStatus = allSuccess ? 'success' : 'error';
    _installerLog += allSuccess
        ? '\nAll selected packages installed successfully.\n'
        : '\nInstallation completed with one or more failures.\n';
    _isInstalling = false;
    notifyListeners();
    return allSuccess;
  }

  Future<bool> _installSinglePackage(
    String filePath,
    Map<String, String> details,
  ) async {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.apk') {
      try {
        final res = await Process.run(
          _adbPath,
          ['-s', _selectedDevice!, 'install', '-r', filePath],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        _installerLog += res.stdout.toString();
        _installerLog += res.stderr.toString();
        final success = res.exitCode == 0;
        _installerLog += success
            ? 'APK installed successfully.\n'
            : 'APK installation failed.\n';
        return success;
      } catch (e) {
        _installerLog += 'Error installing APK: $e\n';
        return false;
      }
    }

    if (ext != '.xapk') return false;
    Directory? tempDir;
    try {
      final systemTemp = Directory.systemTemp;
      tempDir = Directory(
        '${systemTemp.path}\\ja_xapk_${DateTime.now().millisecondsSinceEpoch}',
      );
      await tempDir.create();

      _installerLog += 'Extracting split APK files...\n';
      notifyListeners();
      final extracted = await compute(_extractValidatedXapk, {
        'xapkPath': filePath,
        'tempDirectory': tempDir.path,
      });
      final apkPaths = List<String>.from(extracted['apkPaths']! as List);
      final obbFilePath = extracted['obbFilePath'] as String?;
      final obbFileName = extracted['obbFileName'] as String?;
      for (final apkPath in apkPaths) {
        _installerLog += '  Extracted: ${p.basename(apkPath)}\n';
      }
      if (obbFileName != null) {
        _installerLog += '  Extracted OBB: $obbFileName\n';
      }

      _installerLog += 'Running install-multiple on device...\n';
      notifyListeners();
      final installArgs = [
        '-s',
        _selectedDevice!,
        'install-multiple',
        '-r',
        ...apkPaths,
      ];
      final res = await Process.run(
        _adbPath,
        installArgs,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      _installerLog += res.stdout.toString();
      _installerLog += res.stderr.toString();
      if (res.exitCode != 0) {
        throw Exception(
          'install-multiple failed: ${res.stdout}\n${res.stderr}',
        );
      }

      if (obbFilePath != null &&
          obbFileName != null &&
          details['packageName'] != null &&
          details['packageName']!.isNotEmpty &&
          details['packageName'] != 'Unknown') {
        final pkgName = details['packageName']!;
        final obbDestDir = '/sdcard/Android/obb/$pkgName';
        _installerLog += 'Setting up OBB directory...\n';
        await Process.run(
          _adbPath,
          ['-s', _selectedDevice!, 'shell', 'mkdir', '-p', obbDestDir],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        final obbRes = await Process.run(
          _adbPath,
          [
            '-s',
            _selectedDevice!,
            'push',
            obbFilePath,
            '$obbDestDir/$obbFileName',
          ],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        _installerLog += obbRes.stdout.toString();
        _installerLog += obbRes.stderr.toString();
        if (obbRes.exitCode != 0) {
          _installerLog +=
              'Warning: Failed to copy OBB file. App might crash on startup.\n';
        }
      }
      _installerLog += 'XAPK installed successfully.\n';
      return true;
    } catch (e) {
      _installerLog += 'Error installing XAPK: $e\n';
      return false;
    } finally {
      if (tempDir != null && tempDir.existsSync()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  void clearInstaller() {
    _installerFilePath = null;
    _installerFilePaths.clear();
    _installerStatus = 'idle';
    _installerLog = '';
    _installerAppDetails.clear();
    _installerPackageDetails.clear();
    _isInstalling = false;
    notifyListeners();
  }

  Future<bool> runAdbShellCommand(List<String> shellArgs) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return false;
    try {
      final res = await Process.run(
        _adbPath,
        ['-s', _selectedDevice!, 'shell', ...shellArgs],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> runAdbRebootCommand(String rebootType) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return false;
    try {
      final args = rebootType.isEmpty
          ? ['-s', _selectedDevice!, 'reboot']
          : ['-s', _selectedDevice!, 'reboot', rebootType];
      final res = await Process.run(
        _adbPath,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> runAdbPowerOff() async {
    if (_selectedDevice == null || _adbPath.isEmpty) return false;
    try {
      final res = await Process.run(
        _adbPath,
        ['-s', _selectedDevice!, 'shell', 'reboot', '-p'],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getAdbShellOutput(List<String> shellArgs) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return null;
    try {
      final res = await Process.run(
        _adbPath,
        ['-s', _selectedDevice!, 'shell', ...shellArgs],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        return res.stdout.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadApps() async {
    if (_selectedDevice == null || _adbPath.isEmpty) return;
    _loadingApps = true;
    _appsError = '';
    notifyListeners();

    try {
      final List<String?> results = await Future.wait([
        getAdbShellOutput(['pm', 'list', 'packages', '-3']),
        getAdbShellOutput(['pm', 'list', 'packages', '-s']),
        getAdbShellOutput(['pm', 'list', 'packages', '-d']),
      ]);

      final userResult = results[0];
      final systemResult = results[1];
      final disabledResult = results[2];

      final Set<String> userPackages = _parsePackages(userResult);
      final Set<String> systemPackages = _parsePackages(systemResult);
      final Set<String> disabledPackages = _parsePackages(disabledResult);

      final List<AndroidApp> tempApps = [];
      final Set<String> allPackageNames = {...userPackages, ...systemPackages};

      for (final pkg in allPackageNames) {
        // Initial appName is a fallback capitalized last segment
        String appName = '';
        final parts = pkg.split('.');
        if (parts.isNotEmpty) {
          final last = parts.last;
          appName = last.isNotEmpty
              ? '${last[0].toUpperCase()}${last.substring(1)}'
              : pkg;
        } else {
          appName = pkg;
        }

        tempApps.add(
          AndroidApp(
            packageName: pkg,
            appName: appName,
            isSystem: systemPackages.contains(pkg),
            isFrozen: disabledPackages.contains(pkg),
          ),
        );
      }

      _apps = tempApps;
      _sortApps();
      _loadingApps = false;
      notifyListeners(); // Instantly show list with Package IDs!

      // Start background task to fetch actual application names
      unawaited(_loadLabelsInBackground());
    } catch (e) {
      _appsError = e.toString();
      _loadingApps = false;
      logger.severe('Failed to load packages: $e');
      notifyListeners();
    }
  }

  Future<void> _loadLabelsInBackground() async {
    if (_selectedDevice == null || _adbPath.isEmpty) return;
    try {
      final dumpsysResult = await getAdbShellOutput([
        'sh',
        '-c',
        'dumpsys package | grep -E "Package \\[|application-label:|firstInstallTime="',
      ]);
      if (dumpsysResult == null || dumpsysResult.isEmpty) return;

      final Map<String, String> packageLabels = {};
      final Map<String, DateTime> packageInstallTimes = {};
      final dumpsysLines = dumpsysResult.split('\n');
      String? currentPackage;
      for (var line in dumpsysLines) {
        line = line.trim();
        if (line.startsWith('Package [')) {
          final start = line.indexOf('[') + 1;
          final end = line.indexOf(']');
          if (start > 0 && end > start) {
            currentPackage = line.substring(start, end);
          }
        } else if (line.startsWith('application-label:')) {
          if (currentPackage != null) {
            var label = line.substring('application-label:'.length).trim();
            if ((label.startsWith("'") && label.endsWith("'")) ||
                (label.startsWith('"') && label.endsWith('"'))) {
              if (label.length > 1) {
                label = label.substring(1, label.length - 1);
              }
            }
            packageLabels[currentPackage] = label;
          }
        } else if (line.startsWith('firstInstallTime=')) {
          if (currentPackage != null) {
            final timeStr = line.substring('firstInstallTime='.length).trim();
            final parsedTime = DateTime.tryParse(timeStr);
            if (parsedTime != null) {
              packageInstallTimes[currentPackage] = parsedTime;
            }
          }
        }
      }

      if (packageLabels.isEmpty && packageInstallTimes.isEmpty) return;

      bool updated = false;
      for (int i = 0; i < _apps.length; i++) {
        final pkg = _apps[i].packageName;
        final label = packageLabels[pkg] ?? _apps[i].appName;
        final time = packageInstallTimes[pkg];
        if (label != _apps[i].appName || time != _apps[i].installTime) {
          _apps[i] = AndroidApp(
            packageName: pkg,
            appName: label,
            isSystem: _apps[i].isSystem,
            isFrozen: _apps[i].isFrozen,
            installTime: time ?? _apps[i].installTime,
          );
          updated = true;
        }
      }

      if (updated) {
        _sortApps();
        notifyListeners();
      }
    } catch (e) {
      logger.warning('Failed to load package labels in background: $e');
    }
  }

  Set<String> _parsePackages(String? output) {
    if (output == null || output.isEmpty) return {};
    final Set<String> packages = {};
    final lines = output.split('\n');
    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('package:')) {
        final pkg = line.substring('package:'.length).trim();
        if (pkg.isNotEmpty) {
          packages.add(pkg);
        }
      }
    }
    return packages;
  }

  Future<bool> freezeApp(String packageName) async {
    final success = await runAdbShellCommand([
      'pm',
      'disable-user',
      '--user',
      '0',
      packageName,
    ]);
    if (success) {
      final index = _apps.indexWhere((app) => app.packageName == packageName);
      if (index != -1) {
        _apps[index] = AndroidApp(
          packageName: packageName,
          appName: _apps[index].appName,
          isSystem: _apps[index].isSystem,
          isFrozen: true,
          installTime: _apps[index].installTime,
        );
        notifyListeners();
      }
    }
    return success;
  }

  Future<bool> unfreezeApp(String packageName) async {
    final success = await runAdbShellCommand(['pm', 'enable', packageName]);
    if (success) {
      final index = _apps.indexWhere((app) => app.packageName == packageName);
      if (index != -1) {
        _apps[index] = AndroidApp(
          packageName: packageName,
          appName: _apps[index].appName,
          isSystem: _apps[index].isSystem,
          isFrozen: false,
          installTime: _apps[index].installTime,
        );
        notifyListeners();
      }
    }
    return success;
  }

  Future<bool> uninstallApp(String packageName) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return false;
    try {
      final res = await Process.run(
        _adbPath,
        ['-s', _selectedDevice!, 'uninstall', packageName],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res.exitCode == 0) {
        await loadApps();
        return true;
      }
      final res2 = await Process.run(
        _adbPath,
        [
          '-s',
          _selectedDevice!,
          'shell',
          'pm',
          'uninstall',
          '--user',
          '0',
          packageName,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (res2.exitCode == 0) {
        await loadApps();
        return true;
      }
      return false;
    } catch (e) {
      logger.severe('Failed to uninstall app: $e');
      return false;
    }
  }

  Future<BatchAppActionResult> runBatchAppAction({
    required List<String> packageNames,
    required String action,
  }) async {
    final succeeded = <String>[];
    final failed = <String>[];

    for (final packageName in packageNames) {
      final ok = switch (action) {
        'freeze' => await freezeApp(packageName),
        'unfreeze' => await unfreezeApp(packageName),
        'force_stop' => await forceStopApp(packageName),
        'uninstall' => await uninstallApp(packageName),
        _ => false,
      };
      (ok ? succeeded : failed).add(packageName);
    }

    if (succeeded.isNotEmpty && action != 'uninstall') {
      _sortApps();
      notifyListeners();
    }

    return BatchAppActionResult(
      action: action,
      succeeded: succeeded,
      failed: failed,
    );
  }

  Future<bool> forceStopApp(String packageName) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return false;
    try {
      final res = await Process.run(
        _adbPath,
        ['-s', _selectedDevice!, 'shell', 'am', 'force-stop', packageName],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return res.exitCode == 0;
    } catch (e) {
      logger.severe('Failed to force stop app: $e');
      return false;
    }
  }

  Future<bool> clearAppData(String packageName) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return false;
    try {
      final res = await Process.run(
        _adbPath,
        ['-s', _selectedDevice!, 'shell', 'pm', 'clear', packageName],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return res.exitCode == 0;
    } catch (e) {
      logger.severe('Failed to clear app data: $e');
      return false;
    }
  }

  Future<bool> launchApp(String packageName) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return false;
    try {
      final res = await Process.run(
        _adbPath,
        [
          '-s',
          _selectedDevice!,
          'shell',
          'monkey',
          '-p',
          packageName,
          '-c',
          'android.intent.category.LAUNCHER',
          '1',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return res.exitCode == 0;
    } catch (e) {
      logger.severe('Failed to launch app: $e');
      return false;
    }
  }

  Future<bool> startReverseTethering() async {
    if (_selectedDevice == null || _gnirehtetPath.isEmpty) return false;
    if (_isGnirehtetRunning) return false;

    _gnirehtetLogs = 'Starting Gnirehtet Reverse Tethering...\n';
    notifyListeners();

    try {
      _gnirehtetProcess = await Process.start(_gnirehtetPath, [
        'run',
        _selectedDevice!,
      ]);

      _isGnirehtetRunning = true;
      notifyListeners();

      _gnirehtetProcess!.stdout.transform(utf8.decoder).listen((data) {
        _gnirehtetLogs += data;
        if (_gnirehtetLogs.length > 50000) {
          _gnirehtetLogs = _gnirehtetLogs.substring(
            _gnirehtetLogs.length - 20000,
          );
        }
        notifyListeners();
      });

      _gnirehtetProcess!.stderr.transform(utf8.decoder).listen((data) {
        _gnirehtetLogs += data;
        if (_gnirehtetLogs.length > 50000) {
          _gnirehtetLogs = _gnirehtetLogs.substring(
            _gnirehtetLogs.length - 20000,
          );
        }
        notifyListeners();
      });

      unawaited(
        _gnirehtetProcess!.exitCode.then((code) {
          _gnirehtetLogs += '\nGnirehtet process exited with code $code\n';
          _isGnirehtetRunning = false;
          _gnirehtetProcess = null;
          notifyListeners();
        }),
      );

      return true;
    } catch (e) {
      _gnirehtetLogs += 'Error launching Gnirehtet: $e\n';
      _isGnirehtetRunning = false;
      _gnirehtetProcess = null;
      notifyListeners();
      logger.severe('Failed to start Gnirehtet: $e');
      return false;
    }
  }

  Future<void> stopReverseTethering() async {
    if (_selectedDevice != null && _gnirehtetPath.isNotEmpty) {
      try {
        await Process.run(
          _gnirehtetPath,
          ['stop', _selectedDevice!],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        ).timeout(const Duration(seconds: 1));
      } catch (e) {
        logger.warning('Failed to run gnirehtet stop: $e');
      }
    }
    if (_gnirehtetProcess != null) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _gnirehtetProcess?.kill();
      _gnirehtetProcess = null;
    }
    _isGnirehtetRunning = false;
    notifyListeners();
  }

  List<String> _adbCommandHistory = [];
  List<String> get adbCommandHistory => _adbCommandHistory;

  Future<void> loadAdbCommandHistory() async {
    try {
      final file = _getConfigFile();
      if (file.existsSync()) {
        try {
          final content = file.readAsStringSync();
          if (content.isNotEmpty) {
            final data = jsonDecode(content);
            if (data is Map && data.containsKey('adb_command_history')) {
              final list = data['adb_command_history'];
              if (list is List) {
                _adbCommandHistory = list.map((e) => e.toString()).toList();
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('adb_command_history');
      if (list != null && _adbCommandHistory.isEmpty) {
        _adbCommandHistory = list;
      }
    } catch (_) {}

    notifyListeners();
  }

  Future<void> addAdbCommandToHistory(String cmd) async {
    final trimmed = cmd.trim();
    if (trimmed.isEmpty) return;
    _adbCommandHistory.remove(trimmed);
    _adbCommandHistory.insert(0, trimmed);
    if (_adbCommandHistory.length > 20) {
      _adbCommandHistory = _adbCommandHistory.sublist(0, 20);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('adb_command_history', _adbCommandHistory);
    } catch (_) {}
    try {
      await _writeConfigValues({'adb_command_history': _adbCommandHistory});
    } catch (_) {}
  }

  Future<void> clearAdbCommandHistory() async {
    _adbCommandHistory.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('adb_command_history');
    } catch (_) {}
    try {
      await _writeConfigValues({'adb_command_history': <String>[]});
    } catch (_) {}
  }

  List<String> _textInputHistory = [];
  List<String> get textInputHistory => _textInputHistory;

  Future<void> loadTextInputHistory() async {
    try {
      final file = _getConfigFile();
      if (file.existsSync()) {
        try {
          final content = file.readAsStringSync();
          if (content.isNotEmpty) {
            final data = jsonDecode(content);
            if (data is Map && data.containsKey('text_input_history')) {
              final list = data['text_input_history'];
              if (list is List) {
                _textInputHistory = list.map((e) => e.toString()).toList();
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('text_input_history');
      if (list != null && _textInputHistory.isEmpty) {
        _textInputHistory = list;
      }
    } catch (_) {}

    notifyListeners();
  }

  Future<void> addTextInputToHistory(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _textInputHistory.remove(trimmed);
    _textInputHistory.insert(0, trimmed);
    if (_textInputHistory.length > 20) {
      _textInputHistory = _textInputHistory.sublist(0, 20);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('text_input_history', _textInputHistory);
    } catch (_) {}
    try {
      await _writeConfigValues({'text_input_history': _textInputHistory});
    } catch (_) {}
  }

  Future<void> clearTextInputHistory() async {
    _textInputHistory.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('text_input_history');
    } catch (_) {}
    try {
      await _writeConfigValues({'text_input_history': <String>[]});
    } catch (_) {}
  }

  Future<AdbCommandResult> runCustomAdbCommand(String cmd) async {
    if (_adbPath.isEmpty) {
      return AdbCommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Error: ADB path is empty. Please set it in Path Settings.',
      );
    }

    final rawParts = _parseCommandArguments(cmd);
    if (rawParts.isEmpty) {
      return AdbCommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Error: Empty command',
      );
    }

    List<String> args = [...rawParts];
    if (args.first.toLowerCase() == 'adb' ||
        args.first.toLowerCase() == 'adb.exe') {
      args.removeAt(0);
    }

    if (args.isEmpty) {
      return AdbCommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Error: Empty command',
      );
    }

    // List of standard adb client commands. If the command does not start with one of these,
    // we automatically prepend 'shell' to execute it as an Android shell command.
    const standardAdbCommands = {
      'devices',
      'help',
      'version',
      'connect',
      'disconnect',
      'push',
      'pull',
      'sync',
      'shell',
      'emu',
      'logcat',
      'bugreport',
      'jdwp',
      'install',
      'install-multiple',
      'uninstall',
      'reboot',
      'usb',
      'tcpip',
      'forward',
      'reverse',
      'sideload',
      'remount',
      'keygen',
      'wait-for-device',
      'start-server',
      'kill-server',
    };

    final firstArg = args.first.toLowerCase();
    if (!standardAdbCommands.contains(firstArg)) {
      args.insert(0, 'shell');
    }

    bool needsDeviceTarget = _selectedDevice != null;
    if (needsDeviceTarget) {
      for (int i = 0; i < args.length; i++) {
        if (args[i] == '-s' || args[i] == '--serial') {
          needsDeviceTarget = false;
          break;
        }
      }
      if (args.isNotEmpty) {
        final checkArg = args.first.toLowerCase();
        if (const [
          'devices',
          'version',
          'start-server',
          'kill-server',
          'help',
          'connect',
          'disconnect',
        ].contains(checkArg)) {
          needsDeviceTarget = false;
        }
      }
    }

    final List<String> finalArgs = [];
    if (needsDeviceTarget) {
      finalArgs.addAll(['-s', _selectedDevice!]);
    }
    finalArgs.addAll(args);

    try {
      final res = await Process.run(
        _adbPath,
        finalArgs,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      await addAdbCommandToHistory(cmd);
      return AdbCommandResult(
        exitCode: res.exitCode,
        stdout: res.stdout.toString(),
        stderr: res.stderr.toString(),
      );
    } catch (e) {
      return AdbCommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'Execution error: $e',
      );
    }
  }

  List<String> _parseCommandArguments(String command) {
    final List<String> args = [];
    final RegExp regex = RegExp(r'"([^"]*)"|' + r"'([^']*)'|" + r'([^\s]+)');
    final Iterable<Match> matches = regex.allMatches(command);
    for (final Match match in matches) {
      if (match.group(1) != null) {
        args.add(match.group(1)!);
      } else if (match.group(2) != null) {
        args.add(match.group(2)!);
      } else if (match.group(3) != null) {
        args.add(match.group(3)!);
      }
    }
    return args;
  }

  AdbSyncScanResult getPcFilesRecursive(String pcPath) {
    try {
      final dir = Directory(pcPath);
      if (!dir.existsSync()) {
        return const AdbSyncScanResult.failure(
          'PC folder does not exist or is not accessible.',
        );
      }

      final List<AdbSyncFileItem> items = [];
      final cleanPath = pcPath.replaceAll('\\', '/');

      final files = dir.listSync(recursive: true);
      for (final entity in files) {
        if (entity is File) {
          final absPath = entity.path.replaceAll('\\', '/');
          String relPath = absPath;
          if (absPath.startsWith(cleanPath)) {
            relPath = absPath.substring(cleanPath.length);
            if (relPath.startsWith('/')) relPath = relPath.substring(1);
          }

          items.add(
            AdbSyncFileItem(
              relativePath: relPath,
              absolutePath: entity.path,
              size: entity.lengthSync(),
              lastModified: entity.lastModifiedSync().millisecondsSinceEpoch,
            ),
          );
        }
      }
      return AdbSyncScanResult.success(items);
    } catch (e) {
      logger.severe('Failed to list local files recursively: $e');
      return AdbSyncScanResult.failure('Failed to scan PC folder: $e');
    }
  }

  Future<AdbSyncScanResult> getAndroidFilesRecursive(String androidPath) async {
    if (_selectedDevice == null || _adbPath.isEmpty) {
      return const AdbSyncScanResult.failure(
        'Device is not connected or ADB is not configured.',
      );
    }

    final cleanPath = androidPath.endsWith('/') && androidPath != '/'
        ? androidPath.substring(0, androidPath.length - 1)
        : androidPath;

    try {
      final res = await Process.run(
        _adbPath,
        [
          '-s',
          _selectedDevice!,
          'shell',
          'find',
          cleanPath,
          '-type',
          'f',
          '-exec',
          'stat',
          '-c',
          '%n|%s|%Y',
          '{}',
          '+',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

      if (res.exitCode != 0) {
        final fallbackRes = await Process.run(
          _adbPath,
          ['-s', _selectedDevice!, 'shell', 'find', cleanPath, '-type', 'f'],
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        if (fallbackRes.exitCode != 0) {
          throw Exception(fallbackRes.stderr.toString().trim());
        }

        final lines = fallbackRes.stdout.toString().split('\n');
        final List<AdbSyncFileItem> items = [];
        for (final line in lines) {
          final fileAbsPath = line.trim();
          if (fileAbsPath.isEmpty) continue;

          String relPath = fileAbsPath;
          if (fileAbsPath.startsWith(cleanPath)) {
            relPath = fileAbsPath.substring(cleanPath.length);
            if (relPath.startsWith('/')) relPath = relPath.substring(1);
          }

          items.add(
            AdbSyncFileItem(
              relativePath: relPath,
              absolutePath: fileAbsPath,
              size: 0,
              lastModified: 0,
            ),
          );
        }
        return AdbSyncScanResult.success(items);
      }

      final lines = res.stdout.toString().split('\n');
      final List<AdbSyncFileItem> items = [];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final parts = trimmed.split('|');
        if (parts.length < 2) continue;

        final fileAbsPath = parts[0];
        final size = int.tryParse(parts[1]) ?? 0;
        final lastModSeconds = parts.length >= 3
            ? (int.tryParse(parts[2]) ?? 0)
            : 0;
        final lastModified = lastModSeconds * 1000;

        String relPath = fileAbsPath;
        if (fileAbsPath.startsWith(cleanPath)) {
          relPath = fileAbsPath.substring(cleanPath.length);
          if (relPath.startsWith('/')) relPath = relPath.substring(1);
        }

        items.add(
          AdbSyncFileItem(
            relativePath: relPath,
            absolutePath: fileAbsPath,
            size: size,
            lastModified: lastModified,
          ),
        );
      }
      return AdbSyncScanResult.success(items);
    } catch (e) {
      logger.severe('Failed to list android files recursively: $e');
      return AdbSyncScanResult.failure('Failed to scan Android folder: $e');
    }
  }

  Future<AdbSyncPreview> previewFolderSync({
    required String pcPath,
    required String androidPath,
    required String direction,
    required bool deleteExtra,
  }) async {
    if (_selectedDevice == null || _adbPath.isEmpty) {
      return const AdbSyncPreview.failure(
        'Device is not connected or ADB is not configured.',
      );
    }

    final pcScan = getPcFilesRecursive(pcPath);
    if (!pcScan.isSuccess) return AdbSyncPreview.failure(pcScan.error!);

    final androidScan = await getAndroidFilesRecursive(androidPath);
    if (!androidScan.isSuccess) {
      return AdbSyncPreview.failure(androidScan.error!);
    }

    return AdbSyncPreview.success(
      pcFileCount: pcScan.files.length,
      androidFileCount: androidScan.files.length,
      actions: _planSyncActions(
        pcFiles: pcScan.files,
        androidFiles: androidScan.files,
        direction: direction,
        deleteExtra: deleteExtra,
      ),
    );
  }

  List<AdbSyncAction> _planSyncActions({
    required List<AdbSyncFileItem> pcFiles,
    required List<AdbSyncFileItem> androidFiles,
    required String direction,
    required bool deleteExtra,
  }) {
    final pcMap = {for (final file in pcFiles) file.relativePath: file};
    final androidMap = {
      for (final file in androidFiles) file.relativePath: file,
    };
    final actions = <AdbSyncAction>[];

    bool hasChanged(AdbSyncFileItem source, AdbSyncFileItem? target) {
      return target == null ||
          target.size != source.size ||
          (source.lastModified - target.lastModified).abs() > 2000;
    }

    if (direction == 'pcToAndroid') {
      for (final pcFile in pcFiles) {
        if (hasChanged(pcFile, androidMap[pcFile.relativePath])) {
          actions.add(
            AdbSyncAction(type: 'copy', direction: direction, file: pcFile),
          );
        }
      }
      if (deleteExtra) {
        for (final androidFile in androidFiles) {
          if (!pcMap.containsKey(androidFile.relativePath)) {
            actions.add(
              AdbSyncAction(
                type: 'delete',
                direction: direction,
                file: androidFile,
              ),
            );
          }
        }
      }
    } else if (direction == 'androidToPc') {
      for (final androidFile in androidFiles) {
        if (hasChanged(androidFile, pcMap[androidFile.relativePath])) {
          actions.add(
            AdbSyncAction(
              type: 'copy',
              direction: direction,
              file: androidFile,
            ),
          );
        }
      }
      if (deleteExtra) {
        for (final pcFile in pcFiles) {
          if (!androidMap.containsKey(pcFile.relativePath)) {
            actions.add(
              AdbSyncAction(type: 'delete', direction: direction, file: pcFile),
            );
          }
        }
      }
    } else if (direction == 'syncNewest') {
      for (final pcFile in pcFiles) {
        final androidFile = androidMap[pcFile.relativePath];
        if (androidFile == null) {
          actions.add(
            AdbSyncAction(type: 'copy', direction: 'pcToAndroid', file: pcFile),
          );
        } else {
          final diff = pcFile.lastModified - androidFile.lastModified;
          if (diff.abs() > 2000) {
            actions.add(
              AdbSyncAction(
                type: 'copy',
                direction: diff > 0 ? 'pcToAndroid' : 'androidToPc',
                file: diff > 0 ? pcFile : androidFile,
              ),
            );
          }
        }
      }
      for (final androidFile in androidFiles) {
        if (!pcMap.containsKey(androidFile.relativePath)) {
          actions.add(
            AdbSyncAction(
              type: 'copy',
              direction: 'androidToPc',
              file: androidFile,
            ),
          );
        }
      }
    }
    return actions;
  }

  Future<void> _waitForSyncResume() async {
    while (_isSyncPaused && _isSyncing) {
      _syncResumeCompleter ??= Completer<void>();
      await _syncResumeCompleter!.future;
      _syncResumeCompleter = null;
    }
  }

  Stream<AdbSyncProgressEvent> syncFolders({
    required String pcPath,
    required String androidPath,
    required String direction, // 'pcToAndroid', 'androidToPc', or 'syncNewest'
    required bool deleteExtra,
    bool confirmedDestructive = false,
    Set<String>? expectedDeletePaths,
  }) async* {
    if (_selectedDevice == null || _adbPath.isEmpty) {
      yield AdbSyncProgressEvent(
        status: 'error',
        logMessage: 'Error: Device not connected or ADB path not configured.',
      );
      return;
    }

    final verifiedDeletePaths = expectedDeletePaths;
    if (deleteExtra && (!confirmedDestructive || verifiedDeletePaths == null)) {
      yield AdbSyncProgressEvent(
        status: 'error',
        logMessage: 'Error: Delete extra files requires preview confirmation.',
      );
      return;
    }

    yield AdbSyncProgressEvent(
      status: 'scanning',
      logMessage: 'Scanning local files...\n',
    );
    final preview = await previewFolderSync(
      pcPath: pcPath,
      androidPath: androidPath,
      direction: direction,
      deleteExtra: deleteExtra,
    );
    if (!preview.isSuccess) {
      yield AdbSyncProgressEvent(
        status: 'error',
        logMessage: 'Error: ${preview.error}\n',
      );
      return;
    }
    if (deleteExtra) {
      final actualDeletePaths = preview.deleteActions
          .map((action) => action.file.absolutePath)
          .toSet();
      if (actualDeletePaths.length != verifiedDeletePaths!.length ||
          !actualDeletePaths.containsAll(verifiedDeletePaths)) {
        yield AdbSyncProgressEvent(
          status: 'error',
          logMessage:
              'Error: Folder contents changed after preview. Review the new diff before retrying.',
        );
        return;
      }
    }
    final actions = preview.actions;

    final totalActions = actions.length;
    if (totalActions == 0) {
      yield AdbSyncProgressEvent(
        status: 'completed',
        logMessage:
            'Sync completed! Both directories are already identical. (0 actions needed)\n',
      );
      return;
    }

    yield AdbSyncProgressEvent(
      status: 'syncing',
      totalFiles: totalActions,
      processedFiles: 0,
      percentage: 0.0,
      logMessage: 'Found $totalActions action(s) to execute.\n\n',
    );

    int processed = 0;
    int failedActions = 0;
    final cleanAndroidPath = androidPath.endsWith('/') && androidPath != '/'
        ? androidPath.substring(0, androidPath.length - 1)
        : androidPath;

    for (final action in actions) {
      await _waitForSyncResume();
      if (!_isSyncing) return;
      final file = action.file;

      if (action.type == 'delete') {
        yield AdbSyncProgressEvent(
          status: 'syncing',
          currentFile: file.relativePath,
          totalFiles: totalActions,
          processedFiles: processed,
          percentage: processed / totalActions,
          logMessage: 'Deleting: ${file.relativePath}...\n',
        );

        bool ok = false;
        if (action.direction == 'pcToAndroid') {
          final res = await Process.run(
            _adbPath,
            ['-s', _selectedDevice!, 'shell', 'rm', '-f', file.absolutePath],
            stdoutEncoding: utf8,
            stderrEncoding: utf8,
          );
          ok = res.exitCode == 0;
        } else {
          try {
            final f = File(file.absolutePath);
            if (f.existsSync()) {
              f.deleteSync();
            }
            ok = true;
          } catch (_) {}
        }

        processed++;
        if (!ok) failedActions++;
        yield AdbSyncProgressEvent(
          status: 'syncing',
          totalFiles: totalActions,
          processedFiles: processed,
          percentage: processed / totalActions,
          logMessage: ok ? 'Deleted successfully.\n' : 'Failed to delete.\n',
        );
      } else if (action.type == 'copy') {
        yield AdbSyncProgressEvent(
          status: 'syncing',
          currentFile: file.relativePath,
          totalFiles: totalActions,
          processedFiles: processed,
          percentage: processed / totalActions,
          logMessage:
              'Copying: ${file.relativePath} (${action.direction == "pcToAndroid" ? "PC -> Android" : "Android -> PC"})...\n',
        );

        bool ok = false;
        String speedStr = '';
        String speedLog = '';
        final speedRegex = RegExp(
          r'(\d+(?:\.\d+)?\s*(?:[KMGT]?B/s|B/s))',
          caseSensitive: false,
        );

        if (action.direction == 'pcToAndroid') {
          final targetAbsPath = '$cleanAndroidPath/${file.relativePath}';
          final parentDir = targetAbsPath.substring(
            0,
            targetAbsPath.lastIndexOf('/'),
          );
          await Process.run(
            _adbPath,
            ['-s', _selectedDevice!, 'shell', 'mkdir', '-p', parentDir],
            stdoutEncoding: utf8,
            stderrEncoding: utf8,
          );

          final res = await Process.run(
            _adbPath,
            ['-s', _selectedDevice!, 'push', file.absolutePath, targetAbsPath],
            stdoutEncoding: utf8,
            stderrEncoding: utf8,
          );
          ok = res.exitCode == 0;

          final match = speedRegex.firstMatch(
            res.stdout.toString() + res.stderr.toString(),
          );
          if (match != null) {
            speedStr = match.group(1) ?? '';
            speedLog = ' ($speedStr)';
          }
        } else {
          final targetAbsPath =
              '${pcPath.replaceAll('\\', '/')}/${file.relativePath}';
          final parentDir = Directory(
            targetAbsPath.substring(0, targetAbsPath.lastIndexOf('/')),
          );
          if (!parentDir.existsSync()) {
            parentDir.createSync(recursive: true);
          }

          final res = await Process.run(
            _adbPath,
            ['-s', _selectedDevice!, 'pull', file.absolutePath, targetAbsPath],
            stdoutEncoding: utf8,
            stderrEncoding: utf8,
          );
          ok = res.exitCode == 0;

          final match = speedRegex.firstMatch(
            res.stdout.toString() + res.stderr.toString(),
          );
          if (match != null) {
            speedStr = match.group(1) ?? '';
            speedLog = ' ($speedStr)';
          }
        }

        processed++;
        if (!ok) failedActions++;
        yield AdbSyncProgressEvent(
          status: 'syncing',
          totalFiles: totalActions,
          processedFiles: processed,
          percentage: processed / totalActions,
          logMessage: ok
              ? 'Copied successfully.$speedLog\n'
              : 'Failed to copy.\n',
          speed: speedStr,
        );
      }
    }

    if (failedActions > 0) {
      yield AdbSyncProgressEvent(
        status: 'error',
        totalFiles: totalActions,
        processedFiles: totalActions,
        percentage: processed / totalActions,
        logMessage:
            '\nSync finished with $failedActions failed action(s). Review the log before retrying.\n',
      );
      return;
    }

    yield AdbSyncProgressEvent(
      status: 'completed',
      totalFiles: totalActions,
      processedFiles: totalActions,
      percentage: 1.0,
      logMessage:
          '\nSync successfully completed! Synced $totalActions action(s).\n',
    );
  }

  Future<void> triggerAndroidMediaScan(String androidPath) async {
    if (_selectedDevice == null || _adbPath.isEmpty) return;
    try {
      logger.info(
        'Triggering Android Media Scan on $_selectedDevice for path: $androidPath',
      );
      // 1. Try modern cmd media_provider
      await Process.run(
        _adbPath,
        [
          '-s',
          _selectedDevice!,
          'shell',
          'cmd',
          'media_provider',
          'scan-volume',
          'external',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      // 2. Try content provider method call (Android 10+)
      await Process.run(
        _adbPath,
        [
          '-s',
          _selectedDevice!,
          'shell',
          'content',
          'call',
          '--uri',
          'content://media',
          '--method',
          'scan_volume',
          '--arg',
          'external',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      // 3. Send media scanner broadcast for the path specifically
      await Process.run(
        _adbPath,
        [
          '-s',
          _selectedDevice!,
          'shell',
          'am',
          'broadcast',
          '-a',
          'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
          '-d',
          'file://$androidPath',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
    } catch (e) {
      logger.warning('Failed to trigger Android media scan: $e');
    }
  }

  void startSyncFolder({
    required String pcPath,
    required String androidPath,
    required String direction,
    required bool deleteExtra,
    bool confirmedDestructive = false,
    Set<String>? expectedDeletePaths,
  }) {
    if (_isSyncing) return;

    _isSyncing = true;
    _isSyncPaused = false;
    _syncResumeCompleter = null;
    _syncProgress = 0.0;
    _syncStatusText = 'Starting...';
    _syncLog = 'Initializing sync between PC and Android device...\n';
    _lastSyncSpeedText = '';
    notifyListeners();

    _activeSyncSub =
        syncFolders(
          pcPath: pcPath,
          androidPath: androidPath,
          direction: direction,
          deleteExtra: deleteExtra,
          confirmedDestructive: confirmedDestructive,
          expectedDeletePaths: expectedDeletePaths,
        ).listen(
          (event) {
            _syncLog += event.logMessage;
            if (event.status == 'scanning') {
              _syncStatusText = 'Scanning...';
            } else if (event.status == 'comparing') {
              _syncStatusText = 'Comparing...';
            } else if (event.status == 'syncing') {
              if (event.speed.isNotEmpty) {
                _lastSyncSpeedText = event.speed;
              }
              final speedSuffix = _lastSyncSpeedText.isNotEmpty
                  ? ' • $_lastSyncSpeedText'
                  : '';
              _syncStatusText = 'Syncing...$speedSuffix';
              _syncProgress = event.percentage;
            } else if (event.status == 'completed') {
              _syncStatusText = 'Completed';
              _syncProgress = 1.0;
              _isSyncing = false;
              _isSyncPaused = false;
              addSyncHistory(pcPath, androidPath, direction, deleteExtra);
              if (direction == 'pcToAndroid' || direction == 'syncNewest') {
                _syncLog +=
                    '\nTriggering Android media scan to refresh gallery...\n';
                notifyListeners();
                triggerAndroidMediaScan(androidPath).then((_) {
                  _syncLog += 'Android media scan completed successfully.\n';
                  notifyListeners();
                });
              }
            } else if (event.status == 'error') {
              _syncStatusText = 'Error';
              _isSyncing = false;
              _isSyncPaused = false;
            }
            notifyListeners();
          },
          onError: (Object e) {
            _isSyncing = false;
            _isSyncPaused = false;
            _syncStatusText = 'Error';
            _syncLog += '\nError occurred: $e\n';
            notifyListeners();
          },
        );
  }

  void cancelSyncFolder() {
    _activeSyncSub?.cancel();
    _isSyncing = false;
    _isSyncPaused = false;
    _syncResumeCompleter?.complete();
    _syncResumeCompleter = null;
    _syncStatusText = 'Cancelled';
    _syncLog += '\nSync cancelled by user.\n';
    notifyListeners();
  }

  void pauseSyncFolder() {
    if (!_isSyncing || _isSyncPaused) return;
    _isSyncPaused = true;
    _syncStatusText = 'Paused';
    notifyListeners();
  }

  void resumeSyncFolder() {
    if (!_isSyncing || !_isSyncPaused) return;
    _isSyncPaused = false;
    _syncResumeCompleter?.complete();
    _syncResumeCompleter = null;
    _syncStatusText = 'Syncing...';
    notifyListeners();
  }

  void clearSyncLog() {
    _syncLog = '';
    notifyListeners();
  }
}

class AdbCommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  AdbCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}

class AdbSyncFileItem {
  final String relativePath;
  final String absolutePath;
  final int size;
  final int lastModified; // milliseconds since epoch

  AdbSyncFileItem({
    required this.relativePath,
    required this.absolutePath,
    required this.size,
    this.lastModified = 0,
  });
}

class AdbSyncScanResult {
  final List<AdbSyncFileItem> files;
  final String? error;

  const AdbSyncScanResult._({required this.files, this.error});

  const AdbSyncScanResult.failure(String error)
    : this._(files: const [], error: error);

  AdbSyncScanResult.success(List<AdbSyncFileItem> files) : this._(files: files);

  bool get isSuccess => error == null;
}

class AdbSyncPreview {
  final int pcFileCount;
  final int androidFileCount;
  final List<AdbSyncAction> actions;
  final String? error;

  const AdbSyncPreview._({
    required this.pcFileCount,
    required this.androidFileCount,
    required this.actions,
    this.error,
  });

  const AdbSyncPreview.failure(String error)
    : this._(
        pcFileCount: 0,
        androidFileCount: 0,
        actions: const [],
        error: error,
      );

  AdbSyncPreview.success({
    required int pcFileCount,
    required int androidFileCount,
    required List<AdbSyncAction> actions,
  }) : this._(
         pcFileCount: pcFileCount,
         androidFileCount: androidFileCount,
         actions: actions,
       );

  bool get isSuccess => error == null;
  int get copyCount => actions.where((action) => action.type == 'copy').length;
  int get deleteCount =>
      actions.where((action) => action.type == 'delete').length;
  List<AdbSyncAction> get deleteActions => actions
      .where((action) => action.type == 'delete')
      .toList(growable: false);
}

class AdbSyncAction {
  final String type; // 'copy' or 'delete'
  final String direction; // 'pcToAndroid' or 'androidToPc'
  final AdbSyncFileItem file;

  AdbSyncAction({
    required this.type,
    required this.direction,
    required this.file,
  });
}

class AdbSyncProgressEvent {
  final String status;
  final String currentFile;
  final int totalFiles;
  final int processedFiles;
  final double percentage;
  final String logMessage;
  final String speed;

  AdbSyncProgressEvent({
    required this.status,
    this.currentFile = '',
    this.totalFiles = 0,
    this.processedFiles = 0,
    this.percentage = 0.0,
    this.logMessage = '',
    this.speed = '',
  });
}
