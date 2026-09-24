// lib/modules/ui/main_window.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'styles.dart';
import 'app_colors.dart';
import 'glass_widgets.dart';
import 'app_toast.dart';
import 'dialogs.dart';
import 'glass_dialog.dart';
import 'command_palette_dialog.dart';
import 'device_workspace_dialog.dart';
import 'diagnostics_dialog.dart';
import 'localization.dart';
import 'wireless_adb_dialog.dart';
import 'ntp_time_sync_dialog.dart';
import 'settings_backup_dialog.dart';
import 'update_dialog.dart';
import 'glass_update_dialog.dart';
import 'plugin_dialog.dart';
import 'app_cloner_dialog.dart';
import '../services/ota_update_service.dart';
import '../logic.dart';
import '../utils.dart';
import '../constants.dart';
import '../build_info.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _AdbSetupIllustration extends StatelessWidget {
  final ThemeProvider theme;

  const _AdbSetupIllustration({required this.theme});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00ADB5);
    final panelColor = theme.cardBg.withValues(
      alpha: theme.isDark ? 0.72 : 0.9,
    );

    return Container(
      height: 142,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: theme.isDark ? 0.17 : 0.1),
            panelColor,
            const Color(
              0xFF7C5CFC,
            ).withValues(alpha: theme.isDark ? 0.13 : 0.08),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -35,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF7C5CFC).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -34,
            bottom: -54,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.08),
              ),
            ),
          ),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AdbIllustrationTile(
                  icon: Icons.phone_android_rounded,
                  label: context.tr('adb_illustration_phone'),
                  color: accent,
                  theme: theme,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.usb_rounded,
                    size: 30,
                    color: theme.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
                _AdbIllustrationTile(
                  icon: Icons.bug_report_rounded,
                  label: context.tr('adb_illustration_debug'),
                  color: const Color(0xFF7C5CFC),
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdbIllustrationTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ThemeProvider theme;

  const _AdbIllustrationTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            color: color.withValues(alpha: theme.isDark ? 0.17 : 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.38)),
          ),
          child: Icon(icon, size: 34, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AdbSetupStep extends StatelessWidget {
  final int number;
  final IconData icon;
  final String text;
  final String imageAsset;
  final ThemeProvider theme;

  const _AdbSetupStep({
    required this.number,
    required this.icon,
    required this.text,
    required this.imageAsset,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00ADB5);

    void openImagePreview() {
      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final size = MediaQuery.sizeOf(dialogContext);
          final logic = dialogContext.read<AppLogic>();
          return GlassDialog(
            child: Dialog(
              backgroundColor: glassDialogBackground(
                theme: theme,
                opacity: logic.dialogOpacity,
              ),
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width * 0.72,
                  maxHeight: size.height * 0.86,
                ),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 3,
                  child: Image.asset(imageAsset, fit: BoxFit.contain),
                ),
              ),
            ),
          );
        },
      );
    }

    final image = Tooltip(
      message: context.tr('adb_image_zoom'),
      child: InkWell(
        onTap: openImagePreview,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            imageAsset,
            width: 112,
            height: 168,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );

    final details = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(icon, size: 19, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.cardBg.withValues(alpha: theme.isDark ? 0.55 : 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.borderTheme),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: image),
                    const SizedBox(height: 12),
                    details,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    image,
                    const SizedBox(width: 14),
                    Expanded(child: details),
                  ],
                ),
        );
      },
    );
  }
}

class _MainWindowState extends State<MainWindow>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSidebarCollapsed = false;
  bool _isMirrorOptionsCollapsed = false;

  // Scrcpy options state
  bool _stayOnTop = false;
  bool _fullscreen = false;
  bool _noControl = false;
  bool _keepAwake = true;
  bool _borderless = false;
  bool _noAudio = true;
  String _selectedScrcpyPreset = 'balanced';
  String? _selectedScrcpyProfile;
  bool _isUpdatingMirrorPosition = false;
  Map<String, double>? _pendingMirrorPosition;
  int _lastToastedMirrorErrorSession = -1;

  final GlobalKey _placeholderKey = GlobalKey();
  Timer? _positionUpdateTimer;
  // Cache last sent position to avoid redundant channel calls (reduces flicker)
  double _lastSentX = -1, _lastSentY = -1, _lastSentW = -1, _lastSentH = -1;
  int _forceUpdateTicks = 0;
  final TextEditingController _textInputController = TextEditingController();
  final TextEditingController _mediaCountController = TextEditingController();
  String _mediaTypeFilter = 'all'; // 'all', 'photos', 'videos'
  final TextEditingController _adbCommandController = TextEditingController();
  final ScrollController _adbConsoleScrollController = ScrollController();
  int _quickToolSubTab = 0; // 0: Text Input, 1: ADB Command
  String _adbConsoleOutput = '';
  bool _isExecutingAdbCommand = false;

  // App freeze tab states
  String _appsSearchQuery = '';
  bool _showSystemApps = false;
  final TextEditingController _appsSearchController = TextEditingController();
  final Set<String> _processingPackages = {};
  final Set<String> _selectedAppPackages = {};
  bool _isBatchProcessing = false;

  // File Explorer selection & search state
  final Set<String> _selectedFilePaths = {};
  String _lastExploredPath = '';
  String _fileSearchQuery = '';
  final TextEditingController _fileSearchController = TextEditingController();

  // App Manager selected app for Inspector
  String? _selectedAppDetailPackage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_handleTabChange);
    _startPositionTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOtaUpdatesOnStartup();
    });
  }

  Future<void> _checkOtaUpdatesOnStartup() async {
    try {
      final otaService = OtaUpdateService();
      final config = await otaService.loadConfig();
      if (!otaService.shouldCheckForUpdates(
        interval: config.checkInterval,
        lastCheckTime: config.lastCheckTime,
      )) {
        return;
      }
      final result = await otaService.checkForUpdates();
      if (result.hasUpdate && result.packageInfo != null && mounted) {
        unawaited(
          showGlassUpdateDialog(
            context: context,
            packageInfo: result.packageInfo!,
          ),
        );
      }
    } catch (e) {
      debugPrint('[OTA] Startup check failed: $e');
    }
  }

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _textInputController.dispose();
    _mediaCountController.dispose();
    _appsSearchController.dispose();
    _fileSearchController.dispose();
    _adbCommandController.dispose();
    _adbConsoleScrollController.dispose();
    super.dispose();
  }

  void _startPositionTimer() {
    // 250ms interval — smooth enough for resize without hammering the channel
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) {
      final logic = Provider.of<AppLogic>(context, listen: false);
      if (logic.isMirroring && _tabController.index == 0) {
        _updateMirrorPosition();
      }
    });
  }

  void _scrollToConsoleBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_adbConsoleScrollController.hasClients) {
        _adbConsoleScrollController.animateTo(
          _adbConsoleScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleTabChange() {
    if (!mounted) return;
    if (_tabController.index != 0) {
      _hideMirrorWindow();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _forceUpdateTicks =
              12; // Force position updates for the next 3 seconds (12 * 250ms)
        });
        _updateMirrorPosition();
      });
    }
  }

  void _updateMirrorPosition() {
    if (!mounted) return;
    final logic = Provider.of<AppLogic>(context, listen: false);
    if (!logic.isMirroring) return;

    final keyContext = _placeholderKey.currentContext;
    if (keyContext == null) return;

    final renderBox = keyContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Convert logic coordinates to physical pixels
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final double x = offset.dx * dpr;
    final double y = offset.dy * dpr;
    final double width = size.width * dpr;
    final double height = size.height * dpr;

    if (_isUpdatingMirrorPosition) {
      _pendingMirrorPosition = {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };
      return;
    }

    // Skip if position hasn't actually changed — avoids redundant channel calls
    if (_forceUpdateTicks <= 0 &&
        x == _lastSentX &&
        y == _lastSentY &&
        width == _lastSentW &&
        height == _lastSentH) {
      return;
    }

    _sendMirrorPosition(x, y, width, height);
  }

  void _scheduleMirrorLayoutUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _tabController.index != 0) return;
      _forceUpdateTicks = 3;
      _updateMirrorPosition();
    });
  }

  void _sendMirrorPosition(double x, double y, double width, double height) {
    if (_forceUpdateTicks > 0) {
      _forceUpdateTicks--;
    }

    _isUpdatingMirrorPosition = true;
    const MethodChannel('ja_route/mirror')
        .invokeMethod<bool>('updateMirrorPosition', {
          'x': x,
          'y': y,
          'width': width,
          'height': height,
        })
        .then((success) {
          if (success == true) {
            _lastSentX = x;
            _lastSentY = y;
            _lastSentW = width;
            _lastSentH = height;
          }
        })
        .catchError((_) => null)
        .whenComplete(() {
          _isUpdatingMirrorPosition = false;
          if (_pendingMirrorPosition != null && mounted) {
            final next = _pendingMirrorPosition!;
            _pendingMirrorPosition = null;
            final nx = next['x']!;
            final ny = next['y']!;
            final nw = next['width']!;
            final nh = next['height']!;
            if (nx != _lastSentX ||
                ny != _lastSentY ||
                nw != _lastSentW ||
                nh != _lastSentH ||
                _forceUpdateTicks > 0) {
              _sendMirrorPosition(nx, ny, nw, nh);
            }
          }
        });
  }

  void _hideMirrorWindow() {
    // Reset cached and pending position so next show always repositions correctly
    _pendingMirrorPosition = null;
    _lastSentX = _lastSentY = _lastSentW = _lastSentH = -1;
    const MethodChannel('ja_route/mirror')
        .invokeMethod('updateMirrorPosition', {
          'x': 0.0,
          'y': 0.0,
          'width': 0.0,
          'height': 0.0,
        })
        .catchError((_) => null);
  }

  Future<void> _saveScrcpyProfile(AppLogic logic) async {
    final controller = TextEditingController(
      text: _selectedScrcpyProfile ?? '',
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('save_profile')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.tr('scrcpy_profile_hint'),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    final presetConfig = ScrcpyQualityPreset.fromId(_selectedScrcpyPreset);
    await logic.saveScrcpyProfile(
      ScrcpyProfile(
        name: name.trim(),
        stayOnTop: _stayOnTop,
        fullscreen: _fullscreen,
        noControl: _noControl,
        keepAwake: _keepAwake,
        borderless: _borderless,
        noAudio: _noAudio,
        preset: _selectedScrcpyPreset,
        maxSize: presetConfig.maxSize,
        maxFps: presetConfig.maxFps,
        bitRate: presetConfig.bitRate,
      ),
    );
    if (!mounted) return;
    setState(() => _selectedScrcpyProfile = name.trim());
    context.showSuccessToast(context.tr('profile_saved'));
  }

  Future<void> _deleteScrcpyProfile(AppLogic logic) async {
    final name = _selectedScrcpyProfile;
    if (name == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ConfirmActionDialog(
        title: context.tr('delete_profile'),
        message: context.tr('profile_delete_confirm', args: {'name': name}),
      ),
    );
    if (confirmed != true || !mounted) return;
    await logic.deleteScrcpyProfile(name);
    if (mounted) setState(() => _selectedScrcpyProfile = null);
  }

  void _applyScrcpyProfile(ScrcpyProfile profile) {
    setState(() {
      _selectedScrcpyProfile = profile.name;
      _stayOnTop = profile.stayOnTop;
      _fullscreen = profile.fullscreen;
      _noControl = profile.noControl;
      _keepAwake = profile.keepAwake;
      _borderless = profile.borderless;
      _noAudio = profile.noAudio;
      _selectedScrcpyPreset = profile.preset;
    });
  }

  void _showCommandPalette() {
    final logic = context.read<AppLogic>();
    final commands = <CommandPaletteCommand>[
      CommandPaletteCommand(
        title: context.tr('scrcpy_tab'),
        subtitle: context.tr('launch_mirror'),
        icon: Icons.screenshot_rounded,
        onSelected: () => _tabController.animateTo(0),
      ),
      CommandPaletteCommand(
        title: context.tr('file_explorer_tab'),
        subtitle: context.tr('pc_side'),
        icon: Icons.folder_shared_rounded,
        onSelected: () => _tabController.animateTo(1),
      ),
      CommandPaletteCommand(
        title: context.tr('sync_folders_btn'),
        subtitle: context.tr('sync_folders_title'),
        icon: Icons.sync_rounded,
        onSelected: () => _tabController.animateTo(2),
      ),
      CommandPaletteCommand(
        title: context.tr('latest_media_tab'),
        subtitle: context.tr('latest_media_title'),
        icon: Icons.photo_library_rounded,
        onSelected: () => _tabController.animateTo(3),
      ),
      CommandPaletteCommand(
        title: context.tr('app_freeze_tab'),
        subtitle: context.tr('search_apps_placeholder'),
        icon: Icons.apps_rounded,
        onSelected: () => _tabController.animateTo(5),
      ),
      CommandPaletteCommand(
        title: context.tr('wireless_adb'),
        subtitle: context.tr('wireless_adb_hint'),
        icon: Icons.wifi_rounded,
        onSelected: () {
          showDialog<void>(
            context: context,
            builder: (_) => const WirelessAdbDialog(),
          );
        },
      ),
      CommandPaletteCommand(
        title: context.tr('quick_tool_fix_port_title'),
        subtitle: context.tr('quick_tool_fix_port_subtitle'),
        icon: Icons.wifi_tethering_rounded,
        onSelected: () {
          showDialog<void>(
            context: context,
            builder: (_) => const WirelessAdbDialog(),
          );
        },
      ),
      CommandPaletteCommand(
        title: context.tr('ntp_time_sync_title'),
        subtitle: context.tr('ntp_time_sync_subtitle'),
        icon: Icons.access_time_filled_rounded,
        onSelected: () {
          showDialog<void>(
            context: context,
            builder: (_) => const NtpTimeSyncDialog(),
          );
        },
      ),
      CommandPaletteCommand(
        title: context.tr('diagnostics'),
        subtitle: context.tr('diagnostics_hint'),
        icon: Icons.health_and_safety_rounded,
        onSelected: () {
          showDialog<void>(
            context: context,
            builder: (_) => const DiagnosticsDialog(),
          );
        },
      ),
      CommandPaletteCommand(
        title: context.tr('workspace'),
        subtitle: context.tr('workspace_title'),
        icon: Icons.workspaces_rounded,
        onSelected: () {
          showDialog<void>(
            context: context,
            builder: (_) => const DeviceWorkspaceDialog(),
          );
        },
      ),
      CommandPaletteCommand(
        title: context.tr('backup_restore'),
        subtitle: context.tr('backup_hint'),
        icon: Icons.import_export_rounded,
        onSelected: () {
          showDialog<void>(
            context: context,
            builder: (_) => const SettingsBackupDialog(),
          );
        },
      ),
      CommandPaletteCommand(
        title: context.tr('check_updates'),
        subtitle: context.tr('ota_tab_title'),
        icon: Icons.system_update_rounded,
        onSelected: () async {
          context.showInfoToast(context.tr('ota_checking'));
          try {
            final result = await OtaUpdateService().checkForUpdates(
              isManual: true,
            );
            if (!mounted) return;
            if (result.hasUpdate && result.packageInfo != null) {
              unawaited(
                showGlassUpdateDialog(
                  context: context,
                  packageInfo: result.packageInfo!,
                ),
              );
            } else if (result.errorMessage != null) {
              context.showErrorToast(
                context.tr(
                  'ota_connection_failed',
                  args: {'error': result.errorMessage!},
                ),
              );
            } else {
              context.showSuccessToast(
                context.tr('ota_no_update', args: {'version': 'v$appVersion'}),
              );
            }
          } catch (e) {
            if (mounted) {
              context.showErrorToast(
                context.tr(
                  'ota_connection_failed',
                  args: {'error': e.toString()},
                ),
              );
            }
          }
        },
      ),
      CommandPaletteCommand(
        title: '${context.tr('check_updates')} (GitHub)',
        subtitle: context.tr('update_title'),
        icon: Icons.cloud_download_rounded,
        onSelected: () {
          showDialog<void>(
            context: context,
            builder: (_) => const UpdateDialog(),
          );
        },
      ),
      CommandPaletteCommand(
        title: context.tr('plugin_manager'),
        subtitle: context.tr('plugin_empty'),
        icon: Icons.extension_rounded,
        onSelected: () {
          showDialog<void>(
            context: context,
            builder: (_) => const PluginDialog(),
          );
        },
      ),
      CommandPaletteCommand(
        title: context.tr('refresh_devices'),
        subtitle: context.tr('device_info'),
        icon: Icons.refresh_rounded,
        onSelected: logic.scanDevices,
      ),
      CommandPaletteCommand(
        title: context.tr('app_cloner_title'),
        subtitle: context.tr('app_cloner_subtitle'),
        icon: Icons.copy_all_rounded,
        onSelected: () {
          showDialog<void>(
            context: context,
            builder: (_) => const AppClonerDialog(),
          );
        },
      ),
    ];
    showDialog<void>(
      context: context,
      builder: (_) => CommandPaletteDialog(commands: commands),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final logic = Provider.of<AppLogic>(context);
    final colors = theme.colors;

    if (logic.mirrorState == MirrorState.error &&
        logic.mirrorSessionId != _lastToastedMirrorErrorSession &&
        logic.lastScrcpyError.isNotEmpty) {
      final sessionId = logic.mirrorSessionId;
      _lastToastedMirrorErrorSession = sessionId;
      final errorMsg = logic.lastScrcpyError;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.showErrorToast(
          '${context.tr('mirror_error_title')}: $errorMsg',
        );
      });
    }

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            _OpenCommandPaletteIntent(),
      },
      child: Actions(
        actions: {
          _OpenCommandPaletteIntent: CallbackAction<_OpenCommandPaletteIntent>(
            onInvoke: (_) {
              _showCommandPalette();
              return null;
            },
          ),
        },
        child: Scaffold(
          backgroundColor: colors.bgPrimary,
          body: Stack(
            children: [
              // 1. Mesh Gradient Base Tint (Translucent)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.bgSecondary,
                        colors.bgSecondary.withValues(alpha: 0.5),
                        colors.bgSecondary.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. GPU-Composited Floating Mesh Orbs
              Positioned.fill(child: MeshBackground(colors: colors)),

              // 3. Main Scaffold Layout: Header + Body (Sidebar + Content)
              Column(
                children: [
                  _buildTopHeader(context, theme, colors, logic),
                  Expanded(
                    child: Row(
                      children: [
                        // Left Sidebar
                        _buildSidebar(context, theme, colors, logic),

                        // Main Content Area
                        Expanded(
                          child: _buildMainContent(
                            context,
                            theme,
                            colors,
                            logic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    ThemeProvider theme,
    AppColors colors,
    AppLogic logic,
  ) {
    final timestamp = _getFallbackBuildTimestamp();
    final selectedDev = logic.selectedDevice;
    final devDetails = selectedDev != null
        ? logic.devicesDetails[selectedDev]
        : null;
    final model = devDetails?['model'] ?? context.tr('android_device_label');
    final version = devDetails?['version'] ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.headerBg,
        border: Border(
          bottom: BorderSide(color: colors.headerBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 1. Sidebar Toggle Button
          IconButton(
            onPressed: () {
              setState(() {
                _isSidebarCollapsed = !_isSidebarCollapsed;
              });
              if (logic.isMirroring && _tabController.index == 0) {
                _scheduleMirrorLayoutUpdate();
              }
            },
            icon: AnimatedRotation(
              turns: _isSidebarCollapsed ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _isSidebarCollapsed
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
                size: 20,
                color: colors.accentCyan,
              ),
            ),
            tooltip: _isSidebarCollapsed
                ? 'Expand Sidebar'
                : 'Collapse Sidebar',
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            splashRadius: 18,
          ),
          const SizedBox(width: 8),

          // 2. Brand Logo + Title + Version Tag
          InkWell(
            onTap: () => _tabController.animateTo(0),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.accentColor, colors.accentCyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primaryGlow.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'JA',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          appName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (BuildInfo.isDebug) ...[
                          const SizedBox(width: 5),
                          PillBadge(
                            label: 'DEBUG',
                            color: colors.accentAmber,
                            bg: colors.accentAmber.withValues(alpha: 0.15),
                            border: colors.accentAmber.withValues(alpha: 0.4),
                            icon: Icons.bug_report_rounded,
                            fontSize: 9,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      BuildInfo.isDebug
                          ? 'v$appVersion ($timestamp)'
                          : 'v$appVersion',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontFamily: 'JetBrains Mono',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 3. Center: Connected Device Status & Action Tools
          Expanded(
            child: Row(
              children: [
                if (selectedDev != null) ...[
                  // Connected Device Capsule (Clickable to switch if multiple)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: logic.connectedDevices.length > 1
                          ? () =>
                                _showDeviceSelectDialog(context, logic, colors)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colors.accentCyan.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x6610B981),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.phone_android_rounded,
                              size: 16,
                              color: colors.accentCyan,
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    model,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$selectedDev • Android $version',
                                    style: TextStyle(
                                      color: colors.textMuted,
                                      fontSize: 9.5,
                                      fontFamily: 'JetBrains Mono',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (logic.connectedDevices.length > 1) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 18,
                                color: colors.textSecondary,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // No Device Capsule
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.subCardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.subCardBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phonelink_erase_rounded,
                          size: 15,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.tr('no_device_connected'),
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(width: 8),

                // Device Quick Action Buttons
                IconButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const WirelessAdbDialog(),
                    );
                  },
                  icon: const Icon(Icons.wifi_rounded, size: 15),
                  color: colors.textSecondary,
                  tooltip: context.tr('wireless_adb'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 26,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const DiagnosticsDialog(),
                    );
                  },
                  icon: const Icon(Icons.health_and_safety_rounded, size: 15),
                  color: colors.textSecondary,
                  tooltip: context.tr('diagnostics'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 26,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const DeviceWorkspaceDialog(),
                    );
                  },
                  icon: const Icon(Icons.workspaces_rounded, size: 15),
                  color: colors.textSecondary,
                  tooltip: context.tr('workspace'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 26,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: () => logic.scanDevices(),
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: logic.isSearchingDevices
                        ? colors.accentCyan
                        : colors.textSecondary,
                    size: 15,
                  ),
                  tooltip: context.tr('refresh_devices'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 26,
                    height: 26,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // 4. Command Palette Quick Trigger Pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showCommandPalette,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.subCardBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.subCardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 14,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Search (Ctrl+K)',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // 5. Dynamic Island Status Capsule
          DynamicIslandCapsule(
            colors: colors,
            isRunning: logic.selectedDevice != null,
            statusText: logic.selectedDevice != null
                ? (logic.isMirroring
                      ? 'MIRROR'
                      : (logic.isGnirehtetRunning ? 'REVERSE' : 'CONNECTED'))
                : 'STANDBY',
            subText: logic.selectedDevice != null
                ? (logic.selectedDevice!.length > 14
                      ? '${logic.selectedDevice!.substring(0, 12)}..'
                      : logic.selectedDevice)
                : '${logic.connectedDevices.length} dev',
            onTap: () => logic.scanDevices(),
          ),
        ],
      ),
    );
  }

  void _showDeviceSelectDialog(
    BuildContext context,
    AppLogic logic,
    AppColors colors,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardBg,
        title: Text(
          context.tr('device_info'),
          style: TextStyle(color: colors.textPrimary, fontSize: 16),
        ),
        content: SizedBox(
          width: 320,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: logic.connectedDevices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, idx) {
              final dev = logic.connectedDevices[idx];
              final details = logic.devicesDetails[dev];
              final isSelected = logic.selectedDevice == dev;
              final model =
                  details?['model'] ?? context.tr('android_device_label');
              return ListTile(
                selected: isSelected,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                leading: Icon(
                  Icons.phone_android_rounded,
                  color: isSelected ? colors.accentCyan : colors.textSecondary,
                ),
                title: Text(
                  model,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  dev,
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  logic.selectDevice(dev);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    ThemeProvider theme,
    AppColors colors,
    AppLogic logic,
  ) {
    final navItems = [
      (context.tr('scrcpy_tab'), Icons.screenshot_rounded),
      (context.tr('file_explorer_tab'), Icons.folder_shared_rounded),
      (context.tr('sync_folders_btn'), Icons.sync_rounded),
      (context.tr('latest_media_tab'), Icons.photo_library_rounded),
      (context.tr('installer_tab'), Icons.system_update_rounded),
      (context.tr('app_freeze_tab'), Icons.apps_rounded),
      (context.tr('quick_tools_tab'), Icons.bolt_rounded),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      onEnd: _scheduleMirrorLayoutUpdate,
      curve: Curves.easeOutCubic,
      width: _isSidebarCollapsed ? 64.0 : 210.0,
      decoration: BoxDecoration(
        color: colors.sidebarBg,
        border: Border(
          right: BorderSide(color: colors.borderDefault, width: 1),
        ),
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _isSidebarCollapsed ? 63 : 209,
          maxWidth: _isSidebarCollapsed ? 63 : 209,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Sidebar Header (Navigation Label / Collapse Button)
              Container(
                height: 40,
                padding: EdgeInsets.symmetric(
                  horizontal: _isSidebarCollapsed ? 0 : 12,
                ),
                child: _isSidebarCollapsed
                    ? Center(
                        child: IconButton(
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                          color: colors.accentCyan,
                          tooltip: 'Expand Sidebar',
                          onPressed: () {
                            setState(() {
                              _isSidebarCollapsed = false;
                            });
                            if (logic.isMirroring &&
                                _tabController.index == 0) {
                              _scheduleMirrorLayoutUpdate();
                            }
                          },
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'NAVIGATION',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              size: 20,
                            ),
                            color: colors.textSecondary,
                            tooltip: 'Collapse Sidebar',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _isSidebarCollapsed = true;
                              });
                              if (logic.isMirroring &&
                                  _tabController.index == 0) {
                                _scheduleMirrorLayoutUpdate();
                              }
                            },
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 4),

              // 2. Navigation Items (The 7 Tabs)
              Expanded(
                child: AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      itemCount: navItems.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final isSelected = _tabController.index == index;
                        final item = navItems[index];
                        final label = item.$1;
                        final icon = item.$2;
                        final isMirrorTab = index == 0;
                        final isMirrorActive = isMirrorTab && logic.isMirroring;

                        if (_isSidebarCollapsed) {
                          return Tooltip(
                            message: label,
                            preferBelow: false,
                            child: InkWell(
                              onTap: () {
                                _tabController.animateTo(index);
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                height: 42,
                                width: 42,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.accentColor.withValues(
                                          alpha: 0.20,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.accentCyan.withValues(
                                            alpha: 0.45,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 19,
                                      color: isSelected
                                          ? colors.accentCyan
                                          : colors.textSecondary,
                                    ),
                                    if (isMirrorActive)
                                      Positioned(
                                        top: 7,
                                        right: 7,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _tabController.animateTo(index);
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.accentColor.withValues(alpha: 0.16)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? colors.accentCyan.withValues(
                                          alpha: 0.45,
                                        )
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    icon,
                                    size: 18,
                                    color: isSelected
                                        ? colors.accentCyan
                                        : colors.textSecondary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? colors.textPrimary
                                            : colors.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isMirrorActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.redAccent.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'REC',
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              Divider(height: 1, color: colors.borderDefault),

              // 3. Bottom Utilities (Settings, Theme, Language, Command Palette)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _isSidebarCollapsed ? 4 : 8.0,
                  vertical: 8.0,
                ),
                child: _isSidebarCollapsed
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (context) =>
                                    const PathsSettingsDialog(),
                              );
                            },
                            icon: const Icon(Icons.settings_rounded, size: 18),
                            color: colors.textSecondary,
                            tooltip: context.tr('settings_tab'),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            onPressed: () => theme.toggleTheme(),
                            icon: Icon(
                              theme.isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              size: 18,
                            ),
                            color: theme.isDark
                                ? colors.accentAmber
                                : colors.accentPurple,
                            tooltip: theme.isDark ? 'Light Mode' : 'Dark Mode',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(height: 4),
                          Consumer<LanguageProvider>(
                            builder: (context, langProv, _) {
                              final flag = langProv.locale == 'en'
                                  ? 'EN'
                                  : (langProv.locale == 'vi' ? 'VI' : 'ZH');
                              return Tooltip(
                                message: context.tr('language'),
                                child: InkWell(
                                  onTap: () {
                                    if (langProv.locale == 'en') {
                                      langProv.setLocale('vi');
                                    } else if (langProv.locale == 'vi') {
                                      langProv.setLocale('zh');
                                    } else {
                                      langProv.setLocale('en');
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      flag,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                        fontFamily: 'JetBrains Mono',
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            onPressed: _showCommandPalette,
                            icon: const Icon(
                              Icons.keyboard_command_key_rounded,
                              size: 18,
                            ),
                            color: colors.textSecondary,
                            tooltip: 'Command Palette (Ctrl+K)',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (context) =>
                                    const PathsSettingsDialog(),
                              );
                            },
                            icon: const Icon(Icons.settings_rounded, size: 18),
                            color: colors.textSecondary,
                            tooltip: context.tr('settings_tab'),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            splashRadius: 18,
                          ),
                          IconButton(
                            onPressed: () => theme.toggleTheme(),
                            icon: Icon(
                              theme.isDark
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              size: 18,
                            ),
                            color: theme.isDark
                                ? colors.accentAmber
                                : colors.accentPurple,
                            tooltip: theme.isDark ? 'Light Mode' : 'Dark Mode',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            splashRadius: 18,
                          ),
                          Consumer<LanguageProvider>(
                            builder: (context, langProv, _) {
                              final flag = langProv.locale == 'en'
                                  ? 'EN'
                                  : (langProv.locale == 'vi' ? 'VI' : 'ZH');
                              return Tooltip(
                                message: context.tr('language'),
                                child: InkWell(
                                  onTap: () {
                                    if (langProv.locale == 'en') {
                                      langProv.setLocale('vi');
                                    } else if (langProv.locale == 'vi') {
                                      langProv.setLocale('zh');
                                    } else {
                                      langProv.setLocale('en');
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.subCardBg,
                                      border: Border.all(
                                        color: colors.subCardBorder,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      flag,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                        fontFamily: 'JetBrains Mono',
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            onPressed: _showCommandPalette,
                            icon: const Icon(
                              Icons.keyboard_command_key_rounded,
                              size: 18,
                            ),
                            color: colors.textSecondary,
                            tooltip: 'Command Palette (Ctrl+K)',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            splashRadius: 18,
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    ThemeProvider theme,
    AppColors colors,
    AppLogic logic,
  ) {
    return Column(
      children: [
        // Verification Banners
        if (logic.adbPath.isEmpty || logic.scrcpyPath.isEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.accentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.accentAmber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colors.accentAmber,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ADB or Scrcpy paths are not configured yet. Auto-detecting, or configure them manually in Settings.',
                    style: TextStyle(color: colors.textPrimary, fontSize: 12.5),
                  ),
                ),
                GlowingActionButton(
                  height: 32,
                  colors: colors,
                  customStartColor: colors.accentAmber,
                  customEndColor: Colors.orange,
                  icon: Icons.search_rounded,
                  label: context.tr('default_search_btn'),
                  onPressed: () => logic.autoDetectPaths(),
                ),
              ],
            ),
          ),

        if (logic.selectedDevice == null)
          Expanded(child: _buildNoDevicePlaceholder(context, theme))
        else ...[
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMirrorTab(context, theme, logic),
                _buildExplorerTab(context, theme, logic),
                const FolderSyncTab(),
                _buildMediaTab(context, theme, logic),
                _buildInstallerTab(context, theme, logic),
                _buildAppFreezeTab(context, theme, logic),
                _buildQuickToolsTab(context, theme, logic),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _getFallbackBuildTimestamp() {
    try {
      final exe = File(Platform.resolvedExecutable);
      final so = File(
        '${exe.parent.path}${Platform.pathSeparator}data${Platform.pathSeparator}app.so',
      );
      final f = so.existsSync() ? so : (exe.existsSync() ? exe : null);
      if (f != null) {
        final dt = f.lastModifiedSync();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
      }
    } catch (_) {}
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  // ==========================================
  // TAB BUILDERS
  // ==========================================

  Widget _buildNoDevicePlaceholder(BuildContext context, ThemeProvider theme) {
    final logic = Provider.of<AppLogic>(context, listen: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 640 ? 20.0 : 48.0;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AdbSetupIllustration(theme: theme),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('adb_setup_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('adb_setup_subtitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('adb_image_disclaimer'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textSecondary.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _AdbSetupStep(
                    number: 1,
                    icon: Icons.settings_rounded,
                    text: context.tr('adb_step_1'),
                    imageAsset: 'assets/images/adb_setup_step_1.png',
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _AdbSetupStep(
                    number: 2,
                    icon: Icons.info_outline_rounded,
                    text: context.tr('adb_step_2'),
                    imageAsset: 'assets/images/adb_setup_step_2.png',
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _AdbSetupStep(
                    number: 3,
                    icon: Icons.developer_mode_rounded,
                    text: context.tr('adb_step_3'),
                    imageAsset: 'assets/images/adb_setup_step_3.png',
                    theme: theme,
                  ),
                  const SizedBox(height: 8),
                  _AdbSetupStep(
                    number: 4,
                    icon: Icons.cable_rounded,
                    text: context.tr('adb_step_4'),
                    imageAsset: 'assets/images/adb_setup_step_4.png',
                    theme: theme,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    context.tr('adb_setup_note'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: logic.isSearchingDevices
                        ? null
                        : () => logic.scanDevices(),
                    icon: logic.isSearchingDevices
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.tr('adb_refresh_button')),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00ADB5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetPill({
    required String id,
    required String label,
    required String tooltip,
    required ThemeProvider theme,
    required bool disabled,
  }) {
    final isSelected = _selectedScrcpyPreset == id;
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: disabled
              ? null
              : () => setState(() => _selectedScrcpyPreset = id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00ADB5).withValues(alpha: 0.25)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00ADB5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF00ADB5)
                    : theme.textSecondary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Tab 1: Screen Mirroring (Scrcpy)
  Widget _buildMirrorTab(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) {
    if (logic.selectedDevice == null) {
      return _buildNoDevicePlaceholder(context, theme);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        // Trigger position update on layout changes
        if (logic.isMirroring && _tabController.index == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateMirrorPosition();
          });
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left control panel (Collapsible)
              if (!_isMirrorOptionsCollapsed)
                SizedBox(
                  width: 320,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.tr('scrcpy_options'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.first_page_rounded,
                                size: 20,
                              ),
                              tooltip: 'Collapse Options Panel',
                              color: theme.textSecondary,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                setState(() {
                                  _isMirrorOptionsCollapsed = true;
                                });
                                _scheduleMirrorLayoutUpdate();
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue:
                                    logic.scrcpyProfiles.any(
                                      (profile) =>
                                          profile.name ==
                                          _selectedScrcpyProfile,
                                    )
                                    ? _selectedScrcpyProfile
                                    : null,
                                isExpanded: true,
                                dropdownColor: theme.dropdownBg,
                                borderRadius: BorderRadius.circular(12),
                                decoration: InputDecoration(
                                  labelText: context.tr('scrcpy_profiles'),
                                  prefixIcon: const Icon(Icons.tune_rounded),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: logic.scrcpyProfiles
                                    .map(
                                      (profile) => DropdownMenuItem<String>(
                                        value: profile.name,
                                        child: Text(profile.name),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: logic.isMirroring
                                    ? null
                                    : (name) {
                                        if (name == null) return;
                                        final profile = logic.scrcpyProfiles
                                            .firstWhere(
                                              (item) => item.name == name,
                                            );
                                        _applyScrcpyProfile(profile);
                                      },
                              ),
                            ),
                            IconButton(
                              onPressed: logic.isMirroring
                                  ? null
                                  : () => _saveScrcpyProfile(logic),
                              tooltip: context.tr('save_profile'),
                              icon: const Icon(Icons.save_rounded),
                              color: const Color(0xFF00ADB5),
                            ),
                            IconButton(
                              onPressed:
                                  logic.isMirroring ||
                                      _selectedScrcpyProfile == null
                                  ? null
                                  : () => _deleteScrcpyProfile(logic),
                              tooltip: context.tr('delete_profile'),
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: Colors.redAccent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Quality Preset Selector
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  context.tr('mirror_quality_preset'),
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _selectedScrcpyPreset == 'low'
                                      ? '1024px • 30fps • 3Mbps'
                                      : _selectedScrcpyPreset == 'high'
                                      ? '1920px • 60fps • 10Mbps'
                                      : '1600px • 60fps • 6Mbps',
                                  style: const TextStyle(
                                    color: Color(0xFF00ADB5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: theme.cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.borderTheme),
                              ),
                              child: Row(
                                children: [
                                  _buildPresetPill(
                                    id: 'low',
                                    label: context.tr('mirror_preset_low'),
                                    tooltip: context.tr(
                                      'mirror_preset_low_desc',
                                    ),
                                    theme: theme,
                                    disabled: logic.isMirroring,
                                  ),
                                  const SizedBox(width: 4),
                                  _buildPresetPill(
                                    id: 'balanced',
                                    label: context.tr('mirror_preset_balanced'),
                                    tooltip: context.tr(
                                      'mirror_preset_balanced_desc',
                                    ),
                                    theme: theme,
                                    disabled: logic.isMirroring,
                                  ),
                                  const SizedBox(width: 4),
                                  _buildPresetPill(
                                    id: 'high',
                                    label: context.tr('mirror_preset_high'),
                                    tooltip: context.tr(
                                      'mirror_preset_high_desc',
                                    ),
                                    theme: theme,
                                    disabled: logic.isMirroring,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          color: theme.cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.borderTheme),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  title: Text(
                                    context.tr('stay_on_top'),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  value: _stayOnTop,
                                  onChanged: logic.isMirroring
                                      ? null
                                      : (v) => setState(
                                          () => _stayOnTop = v ?? false,
                                        ),
                                  activeColor: const Color(0xFF00ADB5),
                                  dense: true,
                                ),
                                CheckboxListTile(
                                  title: Text(
                                    context.tr('fullscreen'),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  value: _fullscreen,
                                  onChanged: logic.isMirroring
                                      ? null
                                      : (v) => setState(
                                          () => _fullscreen = v ?? false,
                                        ),
                                  activeColor: const Color(0xFF00ADB5),
                                  dense: true,
                                ),
                                CheckboxListTile(
                                  title: Text(
                                    context.tr('no_control'),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  value: _noControl,
                                  onChanged: logic.isMirroring
                                      ? null
                                      : (v) => setState(
                                          () => _noControl = v ?? false,
                                        ),
                                  activeColor: const Color(0xFF00ADB5),
                                  dense: true,
                                ),
                                CheckboxListTile(
                                  title: Text(
                                    context.tr('keep_awake'),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  value: _keepAwake,
                                  onChanged: logic.isMirroring
                                      ? null
                                      : (v) => setState(
                                          () => _keepAwake = v ?? false,
                                        ),
                                  activeColor: const Color(0xFF00ADB5),
                                  dense: true,
                                ),
                                CheckboxListTile(
                                  title: Text(
                                    context.tr('borderless'),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  value: _borderless,
                                  onChanged: logic.isMirroring
                                      ? null
                                      : (v) => setState(
                                          () => _borderless = v ?? false,
                                        ),
                                  activeColor: const Color(0xFF00ADB5),
                                  dense: true,
                                ),
                                CheckboxListTile(
                                  title: Text(
                                    context.tr('disable_audio'),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  value: _noAudio,
                                  onChanged: logic.isMirroring
                                      ? null
                                      : (v) => setState(
                                          () => _noAudio = v ?? false,
                                        ),
                                  activeColor: const Color(0xFF00ADB5),
                                  dense: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed:
                                  (logic.mirrorState == MirrorState.stopping)
                                  ? null
                                  : () async {
                                      if (logic.isMirrorRunning ||
                                          logic.isMirrorStarting) {
                                        logic.stopMirroring();
                                        _hideMirrorWindow();
                                      } else {
                                        final ok = await logic.launchMirroring(
                                          stayOnTop: _stayOnTop,
                                          fullscreen: _fullscreen,
                                          noControl: _noControl,
                                          keepAwake: _keepAwake,
                                          borderless: _borderless,
                                          noAudio: _noAudio,
                                          preset: _selectedScrcpyPreset,
                                          getTargetRect: () {
                                            final keyContext =
                                                _placeholderKey.currentContext;
                                            if (keyContext == null) return {};
                                            final renderBox =
                                                keyContext.findRenderObject()
                                                    as RenderBox?;
                                            if (renderBox == null ||
                                                !renderBox.hasSize) {
                                              return {};
                                            }
                                            final offset = renderBox
                                                .localToGlobal(Offset.zero);
                                            final size = renderBox.size;
                                            final dpr = MediaQuery.of(
                                              context,
                                            ).devicePixelRatio;
                                            return {
                                              'x': offset.dx * dpr,
                                              'y': offset.dy * dpr,
                                              'width': size.width * dpr,
                                              'height': size.height * dpr,
                                            };
                                          },
                                        );
                                        if (!context.mounted) return;
                                        if (ok) {
                                          setState(() {
                                            _forceUpdateTicks = 12;
                                          });
                                        } else {
                                          _lastToastedMirrorErrorSession =
                                              logic.mirrorSessionId;
                                          final err =
                                              logic.lastScrcpyError.isNotEmpty
                                              ? logic.lastScrcpyError
                                              : 'Failed to launch Screen Mirror.';
                                          context.showErrorToast(
                                            '${context.tr('mirror_error_title')}: $err',
                                          );
                                        }
                                      }
                                    },
                              icon:
                                  logic.isMirrorStarting ||
                                      logic.mirrorState == MirrorState.stopping
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      logic.isMirrorRunning
                                          ? Icons.stop
                                          : Icons.play_arrow,
                                      size: 20,
                                    ),
                              label: Text(
                                logic.mirrorState == MirrorState.stopping
                                    ? context.tr('mirror_stopping')
                                    : logic.isMirrorStarting
                                    ? context.tr('mirror_starting')
                                    : logic.isMirrorRunning
                                    ? context.tr('stop_mirror')
                                    : context.tr('launch_mirror'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    logic.mirrorState == MirrorState.stopping
                                    ? Colors.grey[700]
                                    : logic.isMirrorStarting
                                    ? const Color(0xFFF59E0B)
                                    : logic.isMirrorRunning
                                    ? Colors.redAccent
                                    : const Color(0xFF00ADB5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed:
                                  (logic.isMirroring || logic.isMirrorStarting)
                                  ? null
                                  : () async {
                                      final ok = await logic
                                          .launchStandaloneMirroring(
                                            stayOnTop: _stayOnTop,
                                            fullscreen: _fullscreen,
                                            noControl: _noControl,
                                            keepAwake: _keepAwake,
                                            borderless: _borderless,
                                            noAudio: _noAudio,
                                            preset: _selectedScrcpyPreset,
                                          );
                                      if (!context.mounted) return;
                                      if (!ok) {
                                        final err =
                                            logic.lastScrcpyError.isNotEmpty
                                            ? logic.lastScrcpyError
                                            : 'Failed to launch standalone mirror.';
                                        context.showErrorToast(
                                          '${context.tr('mirror_error_title')}: $err',
                                        );
                                      }
                                    },
                              icon: const Icon(Icons.open_in_new, size: 20),
                              label: Text(
                                context.tr('mirror_open_standalone'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00ADB5),
                                side: const BorderSide(
                                  color: Color(0xFF00ADB5),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      if (logic.selectedDevice == null) {
                                        context.showErrorToast(
                                          context.tr('no_device_connected'),
                                        );
                                        return;
                                      }
                                      context.showInfoToast(
                                        'Taking screenshot...',
                                      );
                                      final path = await logic.takeScreenshot();
                                      if (context.mounted) {
                                        if (path != null) {
                                          context.showSuccessToast(
                                            'Screenshot saved to $path',
                                            actionLabel: 'Open',
                                            onAction: () {
                                              unawaited(
                                                Process.run('explorer.exe', [
                                                  '/select,',
                                                  path,
                                                ]).then<void>(
                                                  (_) {},
                                                  onError:
                                                      (
                                                        Object _,
                                                        StackTrace _,
                                                      ) {},
                                                ),
                                              );
                                            },
                                          );
                                        } else {
                                          context.showErrorToast(
                                            'Failed to take screenshot.',
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      size: 20,
                                    ),
                                    label: Text(
                                      context.tr('take_screenshot'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF00ADB5),
                                      side: const BorderSide(
                                        color: Color(0xFF00ADB5),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF00ADB5),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.folder_open,
                                    color: Color(0xFF00ADB5),
                                  ),
                                  tooltip: context.tr(
                                    'select_screenshot_folder',
                                  ),
                                  onPressed: () async {
                                    final dir =
                                        await FilePicker.getDirectoryPath();
                                    if (dir != null) {
                                      await logic.saveScreenshotDir(dir);
                                      if (context.mounted) {
                                        context.showSuccessToast(
                                          'Screenshot folder set to: $dir',
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (logic.isMirrorRunning) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00ADB5,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(
                                  0xFF00ADB5,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.sensors_rounded,
                                  size: 16,
                                  color: Color(0xFF00ADB5),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${context.tr('mirror_diagnostics')}: ${logic.mirroringDeviceSerial ?? logic.selectedDevice ?? ''} (${_selectedScrcpyPreset.toUpperCase()})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (_isMirrorOptionsCollapsed) ...[
                Container(
                  width: 48,
                  decoration: BoxDecoration(
                    color: theme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.borderTheme),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.last_page_rounded, size: 20),
                        tooltip: context.tr('scrcpy_options'),
                        color: theme.textSecondary,
                        onPressed: () {
                          setState(() {
                            _isMirrorOptionsCollapsed = false;
                          });
                          _scheduleMirrorLayoutUpdate();
                        },
                      ),
                      const SizedBox(height: 8),
                      Divider(height: 1, color: theme.borderTheme),
                      const SizedBox(height: 8),
                      IconButton(
                        key: const ValueKey('mirror-micro-toggle'),
                        icon:
                            logic.isMirrorStarting ||
                                logic.mirrorState == MirrorState.stopping
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                logic.isMirrorRunning
                                    ? Icons.stop_rounded
                                    : Icons.play_arrow_rounded,
                                size: 22,
                              ),
                        tooltip: logic.mirrorState == MirrorState.stopping
                            ? context.tr('mirror_stopping')
                            : logic.isMirrorStarting
                            ? '${context.tr('mirror_starting')} — ${context.tr('cancel')}'
                            : logic.isMirrorRunning
                            ? context.tr('stop_mirror')
                            : context.tr('launch_mirror'),
                        color: logic.isMirrorStarting
                            ? const Color(0xFFF59E0B)
                            : logic.isMirrorRunning
                            ? Colors.redAccent
                            : const Color(0xFF00ADB5),
                        onPressed: (logic.mirrorState == MirrorState.stopping)
                            ? null
                            : () async {
                                if (logic.isMirrorRunning ||
                                    logic.isMirrorStarting) {
                                  logic.stopMirroring();
                                  _hideMirrorWindow();
                                } else {
                                  final ok = await logic.launchMirroring(
                                    stayOnTop: _stayOnTop,
                                    fullscreen: _fullscreen,
                                    noControl: _noControl,
                                    keepAwake: _keepAwake,
                                    borderless: _borderless,
                                    noAudio: _noAudio,
                                    preset: _selectedScrcpyPreset,
                                    getTargetRect: () {
                                      final keyContext =
                                          _placeholderKey.currentContext;
                                      if (keyContext == null) return {};
                                      final renderBox =
                                          keyContext.findRenderObject()
                                              as RenderBox?;
                                      if (renderBox == null ||
                                          !renderBox.hasSize) {
                                        return {};
                                      }
                                      final offset = renderBox.localToGlobal(
                                        Offset.zero,
                                      );
                                      final size = renderBox.size;
                                      final dpr = MediaQuery.of(
                                        context,
                                      ).devicePixelRatio;
                                      return {
                                        'x': offset.dx * dpr,
                                        'y': offset.dy * dpr,
                                        'width': size.width * dpr,
                                        'height': size.height * dpr,
                                      };
                                    },
                                  );
                                  if (!context.mounted) return;
                                  if (ok) {
                                    setState(() {
                                      _forceUpdateTicks = 12;
                                    });
                                  } else {
                                    _lastToastedMirrorErrorSession =
                                        logic.mirrorSessionId;
                                    final err = logic.lastScrcpyError.isNotEmpty
                                        ? logic.lastScrcpyError
                                        : 'Failed to launch Screen Mirror.';
                                    context.showErrorToast(
                                      '${context.tr('mirror_error_title')}: $err',
                                    );
                                  }
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        tooltip: context.tr('mirror_open_standalone'),
                        color: theme.textSecondary,
                        onPressed: (logic.isMirroring || logic.isMirrorStarting)
                            ? null
                            : () async {
                                final ok = await logic
                                    .launchStandaloneMirroring(
                                      stayOnTop: _stayOnTop,
                                      fullscreen: _fullscreen,
                                      noControl: _noControl,
                                      keepAwake: _keepAwake,
                                      borderless: _borderless,
                                      noAudio: _noAudio,
                                      preset: _selectedScrcpyPreset,
                                    );
                                if (!context.mounted) return;
                                if (!ok) {
                                  final err = logic.lastScrcpyError.isNotEmpty
                                      ? logic.lastScrcpyError
                                      : 'Failed to launch standalone mirror.';
                                  context.showErrorToast(
                                    '${context.tr('mirror_error_title')}: $err',
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, size: 18),
                        tooltip: context.tr('take_screenshot'),
                        color: theme.textSecondary,
                        onPressed: () async {
                          if (logic.selectedDevice == null) {
                            context.showErrorToast(
                              context.tr('no_device_connected'),
                            );
                            return;
                          }
                          context.showInfoToast('Taking screenshot...');
                          final path = await logic.takeScreenshot();
                          if (context.mounted) {
                            if (path != null) {
                              context.showSuccessToast(
                                'Screenshot saved to $path',
                                actionLabel: 'Open',
                                onAction: () {
                                  unawaited(
                                    Process.run('explorer.exe', [
                                      '/select,',
                                      path,
                                    ]).then<void>(
                                      (_) {},
                                      onError: (Object _, StackTrace _) {},
                                    ),
                                  );
                                },
                              );
                            } else {
                              context.showErrorToast(
                                'Failed to take screenshot.',
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
              ] else
                const SizedBox(width: 16),

              // Right side: Screen Mirror container placeholder
              Expanded(
                child: Container(
                  key: _placeholderKey,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.borderTheme, width: 1.5),
                  ),
                  child: logic.isMirrorRunning
                      ? const SizedBox.expand()
                      : logic.isMirrorStarting
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF00ADB5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                context.tr('mirror_starting'),
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                ),
                                child: Text(
                                  context.tr('mirror_initializing_hint'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: theme.textSecondary.withValues(
                                      alpha: 0.7,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.phone_android,
                                  size: 48,
                                  color: theme.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                Provider.of<LanguageProvider>(
                                          context,
                                          listen: false,
                                        ).locale ==
                                        'vi'
                                    ? 'Màn hình thiết bị sẽ hiển thị tại đây khi truyền hình'
                                    : 'Device screen will be displayed here during mirroring',
                                style: TextStyle(
                                  color: theme.textSecondary.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                Provider.of<LanguageProvider>(
                                          context,
                                          listen: false,
                                        ).locale ==
                                        'vi'
                                    ? 'Chọn các tùy chọn bên trái và nhấn nút Bắt đầu.'
                                    : 'Configure settings on the left and click Launch Mirror.',
                                style: TextStyle(
                                  color: theme.textSecondary.withValues(
                                    alpha: 0.4,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Tab 2: Dual-way File Browser (Android directory list)
  Widget _buildExplorerTab(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) {
    if (logic.selectedDevice == null) {
      return _buildNoDevicePlaceholder(context, theme);
    }
    if (logic.androidCurrentPath != _lastExploredPath) {
      _selectedFilePaths.clear();
      _lastExploredPath = logic.androidCurrentPath;
    }

    final pathSegments = logic.androidCurrentPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    final visibleFiles = logic.androidFiles.where((file) {
      if (_fileSearchQuery.isEmpty) return true;
      return file.name.toLowerCase().contains(_fileSearchQuery.toLowerCase());
    }).toList();

    final allVisibleSelected =
        visibleFiles.isNotEmpty &&
        visibleFiles.every((file) => _selectedFilePaths.contains(file.path));

    return Column(
      children: [
        // Path navigation bar with Breadcrumbs & Search
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardBg,
            border: Border(bottom: BorderSide(color: theme.borderTheme)),
          ),
          child: Row(
            children: [
              // Up directory button
              IconButton(
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  color: theme.textPrimary,
                  size: 20,
                ),
                tooltip: context.tr('parent_directory'),
                onPressed:
                    logic.androidCurrentPath == '/' ||
                        logic.androidCurrentPath == '/sdcard'
                    ? null
                    : () {
                        final idx = logic.androidCurrentPath.lastIndexOf('/');
                        var parent = logic.androidCurrentPath.substring(0, idx);
                        if (parent.isEmpty) parent = '/';
                        logic.loadAndroidDirectory(parent);
                      },
              ),
              const SizedBox(width: 4),

              // Interactive Breadcrumbs
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => logic.loadAndroidDirectory('/'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Icon(
                            Icons.home_rounded,
                            size: 18,
                            color: logic.androidCurrentPath == '/'
                                ? const Color(0xFF00ADB5)
                                : theme.textSecondary,
                          ),
                        ),
                      ),
                      for (int i = 0; i < pathSegments.length; i++) ...[
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: theme.textSecondary.withValues(alpha: 0.5),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            final target =
                                '/${pathSegments.sublist(0, i + 1).join('/')}';
                            logic.loadAndroidDirectory(target);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Text(
                              pathSegments[i],
                              style: TextStyle(
                                color: i == pathSegments.length - 1
                                    ? const Color(0xFF00ADB5)
                                    : theme.textPrimary,
                                fontWeight: i == pathSegments.length - 1
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_selectedFilePaths.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00ADB5,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFF00ADB5,
                              ).withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            context.tr(
                              'selected_count',
                              args: {
                                'count': _selectedFilePaths.length.toString(),
                              },
                            ),
                            style: const TextStyle(
                              color: Color(0xFF00ADB5),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Search Filter box
              SizedBox(
                width: 180,
                height: 32,
                child: TextField(
                  controller: _fileSearchController,
                  style: TextStyle(color: theme.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: context.tr('search_files_hint'),
                    hintStyle: TextStyle(
                      color: theme.textSecondary.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: theme.textSecondary,
                    ),
                    suffixIcon: _fileSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 14),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              _fileSearchController.clear();
                              setState(() => _fileSearchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    filled: true,
                    fillColor: theme.isDark ? Colors.black26 : Colors.white60,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.borderTheme),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.borderTheme),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF00ADB5)),
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _fileSearchQuery = val.trim()),
                ),
              ),

              const SizedBox(width: 12),

              // Action buttons (Download selected, Delete selected, New folder, Upload, Refresh)
              if (_selectedFilePaths.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(
                    Icons.download_rounded,
                    color: Color(0xFF00ADB5),
                  ),
                  tooltip: context.tr('download_selected'),
                  onPressed: () async {
                    final dir = await FilePicker.getDirectoryPath();
                    if (!context.mounted) return;
                    if (dir != null) {
                      await _runWithTransferProgress(context, logic, () async {
                        bool allOk = true;
                        for (final filePath in _selectedFilePaths) {
                          final fileItem = logic.androidFiles.firstWhere(
                            (f) => f.path == filePath,
                          );
                          final ok = await logic.pullAndroidFile(
                            filePath,
                            dir,
                            fileSize: fileItem.size,
                          );
                          if (!ok) allOk = false;
                        }
                        return allOk;
                      }, destinationDirectory: dir);
                      setState(() {
                        _selectedFilePaths.clear();
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  tooltip: context.tr('delete_selected'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => ConfirmDeleteDialog(
                        itemName: context.tr(
                          'items_count',
                          args: {'count': _selectedFilePaths.length.toString()},
                        ),
                      ),
                    );
                    if (confirm == true) {
                      bool allOk = true;
                      final pathsToDelete = _selectedFilePaths.toList();
                      for (final filePath in pathsToDelete) {
                        final fileIndex = logic.androidFiles.indexWhere(
                          (file) => file.path == filePath,
                        );
                        if (fileIndex != -1) {
                          final fileItem = logic.androidFiles[fileIndex];
                          final ok = await logic.deleteAndroidFile(
                            filePath,
                            fileItem.isDirectory,
                          );
                          if (!ok) allOk = false;
                        }
                      }
                      setState(() {
                        _selectedFilePaths.clear();
                      });
                      if (context.mounted) {
                        if (allOk) {
                          context.showSuccessToast(
                            context.tr('delete_selected_success'),
                          );
                        } else {
                          context.showErrorToast(
                            context.tr('delete_some_failed'),
                          );
                        }
                      }
                    }
                  },
                ),
                Container(
                  height: 20,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: theme.borderTheme,
                ),
              ],
              IconButton(
                icon: Icon(
                  Icons.create_new_folder_outlined,
                  color: theme.textPrimary,
                  size: 20,
                ),
                tooltip: context.tr('new_folder'),
                onPressed: () async {
                  final name = await showDialog<String>(
                    context: context,
                    builder: (context) => const CreateFolderDialog(),
                  );
                  if (name != null) {
                    final ok = await logic.createAndroidFolder(name);
                    if (context.mounted && !ok) {
                      context.showErrorToast(
                        context.tr('create_directory_failed'),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.upload_file_outlined,
                  color: theme.textPrimary,
                  size: 20,
                ),
                tooltip: context.tr('upload_files'),
                onPressed: () async {
                  final result = await FilePicker.pickFiles(
                    allowMultiple: true,
                  );
                  if (!context.mounted) return;
                  if (result != null && result.files.isNotEmpty) {
                    await _runWithTransferProgress(context, logic, () async {
                      bool allOk = true;
                      for (final file in result.files) {
                        if (file.path != null) {
                          final ok = await logic.pushFileToAndroid(
                            file.path!,
                            logic.androidCurrentPath,
                          );
                          if (!ok) allOk = false;
                        }
                      }
                      return allOk;
                    });
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: theme.textPrimary,
                  size: 20,
                ),
                tooltip: context.tr('refresh_action'),
                onPressed: () =>
                    logic.loadAndroidDirectory(logic.androidCurrentPath),
              ),
            ],
          ),
        ),

        // Data Table Column Headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.headerBg,
            border: Border(bottom: BorderSide(color: theme.borderTheme)),
          ),
          child: Row(
            children: [
              // Checkbox + Name header
              Expanded(
                flex: 6,
                child: Row(
                  children: [
                    Checkbox(
                      value: allVisibleSelected,
                      tristate:
                          _selectedFilePaths.isNotEmpty && !allVisibleSelected,
                      activeColor: const Color(0xFF00ADB5),
                      onChanged: logic.isAndroidLoading || visibleFiles.isEmpty
                          ? null
                          : (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedFilePaths.addAll(
                                    visibleFiles.map((f) => f.path),
                                  );
                                } else {
                                  _selectedFilePaths.clear();
                                }
                              });
                            },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('table_name'),
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (visibleFiles.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${visibleFiles.length})',
                        style: TextStyle(
                          color: theme.textSecondary.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Size header
              Expanded(
                flex: 2,
                child: Text(
                  context.tr('table_size'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Date Modified header
              Expanded(
                flex: 3,
                child: Text(
                  context.tr('table_modified'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Actions header
              Expanded(
                flex: 2,
                child: Text(
                  context.tr('table_actions'),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // File List / Table Content
        Expanded(
          child: logic.isAndroidLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00ADB5)),
                )
              : logic.androidExplorerError.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr(
                          'error_details',
                          args: {
                            'error': logic.androidExplorerError.toString(),
                          },
                        ),
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => logic.loadAndroidDirectory(
                          logic.androidCurrentPath,
                        ),
                        child: Text(context.tr('retry_action')),
                      ),
                    ],
                  ),
                )
              : visibleFiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 52,
                        color: theme.textSecondary.withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _fileSearchQuery.isNotEmpty
                            ? context.tr(
                                'no_files_matching',
                                args: {'query': _fileSearchQuery},
                              )
                            : context.tr('empty_folder'),
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: visibleFiles.length,
                  itemBuilder: (context, index) {
                    final file = visibleFiles[index];
                    final isSelected = _selectedFilePaths.contains(file.path);
                    return InkWell(
                      onTap: () {
                        if (file.isDirectory) {
                          logic.loadAndroidDirectory(file.path);
                        } else {
                          setState(() {
                            if (isSelected) {
                              _selectedFilePaths.remove(file.path);
                            } else {
                              _selectedFilePaths.add(file.path);
                            }
                          });
                        }
                      },
                      hoverColor: theme.cardHoverBg.withValues(alpha: 0.35),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00ADB5).withValues(alpha: 0.12)
                              : Colors.transparent,
                          border: Border(
                            bottom: BorderSide(
                              color: theme.borderTheme,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Column 1: Checkbox + Icon + File name
                            Expanded(
                              flex: 6,
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: const Color(0xFF00ADB5),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedFilePaths.add(file.path);
                                        } else {
                                          _selectedFilePaths.remove(file.path);
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    file.isDirectory
                                        ? Icons.folder_rounded
                                        : Icons.insert_drive_file_rounded,
                                    color: file.isDirectory
                                        ? const Color(0xFF00ADB5)
                                        : theme.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      file.name,
                                      style: TextStyle(
                                        color: file.isDirectory
                                            ? theme.textPrimary
                                            : theme.textPrimary.withValues(
                                                alpha: 0.9,
                                              ),
                                        fontSize: 13,
                                        fontWeight: file.isDirectory
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Column 2: File Size
                            Expanded(
                              flex: 2,
                              child: Text(
                                file.isDirectory
                                    ? '-'
                                    : Utils.formatBytes(file.size),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Column 3: Date modified
                            Expanded(
                              flex: 3,
                              child: Text(
                                file.dateModified,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.textSecondary.withValues(
                                    alpha: 0.8,
                                  ),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Column 4: Row actions
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.download_rounded,
                                      color: theme.textSecondary,
                                      size: 18,
                                    ),
                                    tooltip: context.tr('download_selected'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      final dir =
                                          await FilePicker.getDirectoryPath();
                                      if (dir != null) {
                                        await _runWithTransferProgress(
                                          context,
                                          logic,
                                          () async {
                                            return await logic.pullAndroidFile(
                                              file.path,
                                              dir,
                                              fileSize: file.size,
                                            );
                                          },
                                          destinationDirectory: dir,
                                        );
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    tooltip: context.tr('delete_selected'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (context) =>
                                            ConfirmDeleteDialog(
                                              itemName: file.name,
                                            ),
                                      );
                                      if (confirm == true) {
                                        final ok = await logic
                                            .deleteAndroidFile(
                                              file.path,
                                              file.isDirectory,
                                            );
                                        if (context.mounted && !ok) {
                                          context.showErrorToast(
                                            context.tr('delete_item_failed'),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Tab 3: Latest Media Filter & Copy
  Widget _buildMediaTab(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) {
    if (logic.selectedDevice == null) {
      return _buildNoDevicePlaceholder(context, theme);
    }

    final filteredMedia = logic.latestMedia.where((media) {
      if (_mediaTypeFilter == 'photos' && media.isVideo) return false;
      if (_mediaTypeFilter == 'videos' && !media.isVideo) return false;
      return true;
    }).toList();

    final isAllSelected =
        filteredMedia.isNotEmpty &&
        filteredMedia.every((m) => logic.selectedMediaPaths.contains(m.path));
    final isPartiallySelected =
        logic.selectedMediaPaths.isNotEmpty && !isAllSelected;

    return Column(
      children: [
        // Controls header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardBg,
            border: Border(bottom: BorderSide(color: theme.borderTheme)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Selection, Filter Chips & Quick Select
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Select all checkbox
                      Checkbox(
                        value: isAllSelected
                            ? true
                            : (isPartiallySelected ? null : false),
                        tristate: true,
                        activeColor: const Color(0xFF00ADB5),
                        onChanged: (v) {
                          if (v == true) {
                            for (final m in filteredMedia) {
                              if (!logic.selectedMediaPaths.contains(m.path)) {
                                logic.toggleMediaSelection(m.path);
                              }
                            }
                          } else {
                            for (final m in filteredMedia) {
                              if (logic.selectedMediaPaths.contains(m.path)) {
                                logic.toggleMediaSelection(m.path);
                              }
                            }
                          }
                          _mediaCountController.clear();
                        },
                      ),

                      // Selected count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF00ADB5,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(
                              0xFF00ADB5,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          context.tr(
                            'selected_count',
                            args: {
                              'count': logic.selectedMediaPaths.length
                                  .toString(),
                            },
                          ),
                          style: const TextStyle(
                            color: Color(0xFF00ADB5),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Filter chips (All | Photos | Videos)
                      _buildMediaFilterChip(
                        theme: theme,
                        label: context.tr('media_filter_all'),
                        icon: Icons.collections_outlined,
                        count: logic.latestMedia.length,
                        isSelected: _mediaTypeFilter == 'all',
                        onTap: () => setState(() => _mediaTypeFilter = 'all'),
                      ),
                      const SizedBox(width: 6),
                      _buildMediaFilterChip(
                        theme: theme,
                        label: context.tr('media_filter_photos'),
                        icon: Icons.photo_outlined,
                        count: logic.latestMedia
                            .where((m) => !m.isVideo)
                            .length,
                        isSelected: _mediaTypeFilter == 'photos',
                        onTap: () =>
                            setState(() => _mediaTypeFilter = 'photos'),
                      ),
                      const SizedBox(width: 6),
                      _buildMediaFilterChip(
                        theme: theme,
                        label: context.tr('media_filter_videos'),
                        icon: Icons.videocam_outlined,
                        count: logic.latestMedia.where((m) => m.isVideo).length,
                        isSelected: _mediaTypeFilter == 'videos',
                        onTap: () =>
                            setState(() => _mediaTypeFilter = 'videos'),
                      ),

                      const SizedBox(width: 16),
                      Container(width: 1, height: 20, color: theme.borderTheme),
                      const SizedBox(width: 14),

                      // Quick Select Presets
                      Text(
                        context.tr('select_latest'),
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildQuickPresetChip(
                        theme: theme,
                        label: '10',
                        onTap: () {
                          _mediaCountController.text = '10';
                          logic.selectLatestNMedia(
                            10,
                            isVideo: _mediaTypeFilter == 'all'
                                ? null
                                : _mediaTypeFilter == 'videos',
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      _buildQuickPresetChip(
                        theme: theme,
                        label: '25',
                        onTap: () {
                          _mediaCountController.text = '25';
                          logic.selectLatestNMedia(
                            25,
                            isVideo: _mediaTypeFilter == 'all'
                                ? null
                                : _mediaTypeFilter == 'videos',
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      _buildQuickPresetChip(
                        theme: theme,
                        label: '50',
                        onTap: () {
                          _mediaCountController.text = '50';
                          logic.selectLatestNMedia(
                            50,
                            isVideo: _mediaTypeFilter == 'all'
                                ? null
                                : _mediaTypeFilter == 'videos',
                          );
                        },
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 48,
                        height: 26,
                        child: TextField(
                          controller: _mediaCountController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          cursorColor: const Color(0xFF00ADB5),
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 0,
                            ),
                            filled: true,
                            fillColor: theme.subCardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: theme.borderTheme),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: BorderSide(color: theme.borderTheme),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(
                                color: Color(0xFF00ADB5),
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val) ?? 0;
                            logic.selectLatestNMedia(
                              parsed,
                              isVideo: _mediaTypeFilter == 'all'
                                  ? null
                                  : _mediaTypeFilter == 'videos',
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Right: Actions (Download, Target folder, Refresh)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: logic.selectedMediaPaths.isEmpty
                        ? null
                        : () async {
                            String? targetBase = logic.mediaDownloadDir;
                            if (targetBase.isEmpty) {
                              if (Platform.isWindows) {
                                final userProfile =
                                    Platform.environment['USERPROFILE'];
                                if (userProfile != null) {
                                  targetBase = '$userProfile\\Pictures';
                                }
                              }
                              if (targetBase.isEmpty) {
                                final downloadsDir =
                                    await getDownloadsDirectory();
                                targetBase =
                                    downloadsDir?.path ??
                                    Directory.current.path;
                              }
                            }
                            final now = DateTime.now();
                            final timestamp =
                                "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_"
                                "${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}";
                            final dirPath = '$targetBase\\$timestamp';

                            final targetDir = Directory(dirPath);
                            try {
                              if (!targetDir.existsSync()) {
                                targetDir.createSync(recursive: true);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                context.showErrorToast(
                                  context.tr(
                                    'create_target_failed',
                                    args: {'error': e.toString()},
                                  ),
                                );
                              }
                              return;
                            }

                            if (context.mounted) {
                              unawaited(
                                showDialog<void>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF00ADB5),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final ok = await logic.pullSelectedMedia(dirPath);

                            if (context.mounted) {
                              Navigator.of(context).pop(); // dismiss loading
                              if (ok) {
                                context.showSuccessToast(
                                  context.tr(
                                    'media_downloaded',
                                    args: {
                                      'count': logic.selectedMediaPaths.length
                                          .toString(),
                                      'path': dirPath,
                                    },
                                  ),
                                  actionLabel: context.tr('open_folder'),
                                  onAction: () {
                                    unawaited(
                                      Process.run('explorer.exe', [
                                        dirPath,
                                      ]).then<void>(
                                        (_) {},
                                        onError: (Object _, StackTrace _) {},
                                      ),
                                    );
                                  },
                                );
                              } else {
                                context.showErrorToast(
                                  context.tr(
                                    'media_partial_download',
                                    args: {'path': dirPath},
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: Text(context.tr('download_selected')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00ADB5),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: theme.borderTheme,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.folder_open,
                      color: Color(0xFF00ADB5),
                    ),
                    tooltip: context.tr('select_download_folder'),
                    onPressed: () async {
                      final dir = await FilePicker.getDirectoryPath();
                      if (dir != null) {
                        await logic.saveMediaDownloadDir(dir);
                        if (context.mounted) {
                          context.showSuccessToast(
                            context.tr('media_folder_set', args: {'path': dir}),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.refresh, color: theme.textPrimary),
                    tooltip: context.tr('rescan_media'),
                    onPressed: () => logic.fetchLatestMedia(force: true),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List View of media files
        Expanded(
          child: logic.isMediaLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00ADB5)),
                )
              : filteredMedia.isEmpty
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    constraints: const BoxConstraints(maxWidth: 420),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.borderTheme),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00ADB5,
                            ).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _mediaTypeFilter == 'videos'
                                ? Icons.videocam_off_outlined
                                : Icons.photo_library_outlined,
                            size: 32,
                            color: const Color(0xFF00ADB5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('no_media_found'),
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('media_scan_hint'),
                          style: TextStyle(
                            color: theme.textSecondary.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => logic.fetchLatestMedia(force: true),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(context.tr('scan_media_store')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00ADB5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredMedia.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final media = filteredMedia[index];
                    final isSelected = logic.selectedMediaPaths.contains(
                      media.path,
                    );
                    final dateStr = DateTime.fromMillisecondsSinceEpoch(
                      media.dateAdded * 1000,
                    ).toLocal().toString().substring(0, 16);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00ADB5).withValues(alpha: 0.08)
                            : theme.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00ADB5).withValues(alpha: 0.4)
                              : theme.borderTheme.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: const Color(0xFF00ADB5),
                            onChanged: (_) {
                              logic.toggleMediaSelection(media.path);
                              _mediaCountController.clear();
                            },
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: media.isVideo
                                  ? Colors.amber.withValues(alpha: 0.12)
                                  : const Color(
                                      0xFF00ADB5,
                                    ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              media.isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.image_rounded,
                              color: media.isVideo
                                  ? Colors.amber
                                  : const Color(0xFF00ADB5),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  media.name,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$dateStr  •  ${media.path}',
                                  style: TextStyle(
                                    color: theme.textSecondary.withValues(
                                      alpha: 0.6,
                                    ),
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 14,
                            ),
                            label: Text(
                              context.tr('preview_open'),
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () async {
                              final tempDir = await getTemporaryDirectory();
                              final pulled = await logic.pullAndroidFile(
                                media.path,
                                tempDir.path,
                              );
                              if (pulled) {
                                final localFile = File(
                                  '${tempDir.path}\\${media.name}',
                                );
                                if (localFile.existsSync()) {
                                  await Process.run('explorer.exe', [
                                    localFile.path,
                                  ]);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMediaFilterChip({
    required ThemeProvider theme,
    required String label,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00ADB5).withValues(alpha: 0.15)
              : theme.subCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00ADB5)
                : theme.borderTheme.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? const Color(0xFF00ADB5) : theme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF00ADB5) : theme.textPrimary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF00ADB5).withValues(alpha: 0.2)
                    : theme.borderTheme.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF00ADB5)
                      : theme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPresetChip({
    required ThemeProvider theme,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: theme.subCardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.borderTheme),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Tab 4: APK / XAPK Package Installer
  Widget _buildInstallerTab(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) {
    if (logic.selectedDevice == null) {
      return _buildNoDevicePlaceholder(context, theme);
    }
    final hasInstallerPackages = logic.installerFilePaths.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Pane: File Picker & Queue (flex: 5)
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dropzone / File Picker Card
                InkWell(
                  onTap: logic.isInstalling
                      ? null
                      : () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowMultiple: true,
                            allowedExtensions: ['apk', 'xapk'],
                          );
                          if (result != null) {
                            final paths = result.files
                                .map((file) => file.path)
                                .whereType<String>()
                                .toList();
                            if (paths.isNotEmpty) {
                              logic.selectInstallerFiles(paths);
                            }
                          }
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasInstallerPackages
                            ? theme.borderTheme
                            : const Color(0xFF00ADB5).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF00ADB5,
                            ).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cloud_upload_outlined,
                            size: 26,
                            color: Color(0xFF00ADB5),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          hasInstallerPackages
                              ? context.tr(
                                  'packages_queued',
                                  args: {
                                    'count':
                                        '${logic.installerFilePaths.length}',
                                  },
                                )
                              : context.tr('drag_drop_apk_xapk'),
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.tr('select_apk_xapk'),
                          style: TextStyle(
                            color: theme.textSecondary.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFormatBadge(
                              theme,
                              '.APK',
                              const Color(0xFF00ADB5),
                            ),
                            const SizedBox(width: 6),
                            _buildFormatBadge(
                              theme,
                              '.XAPK',
                              const Color(0xFF7C5CFC),
                            ),
                            const SizedBox(width: 6),
                            _buildFormatBadge(
                              theme,
                              context.tr('split_apks_label'),
                              const Color(0xFFF59E0B),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Queue Section or Device Ready Card
                if (hasInstallerPackages) ...[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.borderTheme),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Queue Header
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.playlist_play_rounded,
                                  size: 18,
                                  color: Color(0xFF00ADB5),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr(
                                      'selected_packages',
                                      args: {
                                        'count':
                                            '${logic.installerFilePaths.length}',
                                      },
                                    ),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (!logic.isInstalling)
                                  InkWell(
                                    onTap: () => logic.clearInstaller(),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.delete_sweep_outlined,
                                            size: 14,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            context.tr('clear_queue'),
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),

                          // Queue List
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              itemCount: logic.installerFilePaths.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final filePath =
                                    logic.installerFilePaths[index];
                                final isXapk =
                                    p.extension(filePath).toLowerCase() ==
                                    '.xapk';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.subCardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: theme.borderTheme.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color:
                                              (isXapk
                                                      ? const Color(0xFF7C5CFC)
                                                      : const Color(0xFF00ADB5))
                                                  .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Icon(
                                          isXapk
                                              ? Icons.archive_outlined
                                              : Icons.android,
                                          size: 16,
                                          color: isXapk
                                              ? const Color(0xFF7C5CFC)
                                              : const Color(0xFF00ADB5),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.basename(filePath),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: theme.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              isXapk
                                                  ? context.tr('xapk_archive')
                                                  : context.tr(
                                                      'standalone_apk',
                                                    ),
                                              style: TextStyle(
                                                color: theme.textSecondary
                                                    .withValues(alpha: 0.6),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!logic.isInstalling)
                                        IconButton(
                                          tooltip: context.tr('remove_package'),
                                          icon: const Icon(
                                            Icons.close,
                                            size: 16,
                                          ),
                                          color: theme.textSecondary,
                                          onPressed: () => logic
                                              .removeInstallerFile(filePath),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                          // Primary Install Button Bar (attached directly below queue)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed:
                                    logic.installerFilePaths.isEmpty ||
                                        logic.installerStatus != 'parsed' ||
                                        logic.isInstalling
                                    ? null
                                    : () async {
                                        final ok = await logic.installPackage();
                                        if (context.mounted) {
                                          if (ok) {
                                            context.showSuccessToast(
                                              context.tr(
                                                'installation_success',
                                              ),
                                            );
                                          } else {
                                            context.showErrorToast(
                                              context.tr(
                                                'installation_failed',
                                                args: {
                                                  'error':
                                                      logic.installerStatus,
                                                },
                                              ),
                                            );
                                          }
                                        }
                                      },
                                icon: logic.isInstalling
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.system_update_alt_rounded,
                                        size: 18,
                                      ),
                                label: Text(
                                  logic.isInstalling
                                      ? context.tr('installing')
                                      : context.tr('install_to_device'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ADB5),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: theme.borderTheme,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Target device ready status card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardBg.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.borderTheme),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_other_rounded,
                            size: 40,
                            color: theme.textSecondary.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.tr('target_device_ready'),
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            logic.selectedDeviceDetails?['model'] ??
                                logic.selectedDevice ??
                                context.tr('android_device_label'),
                            style: const TextStyle(
                              color: Color(0xFF00ADB5),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('sideload_hint'),
                            style: TextStyle(
                              color: theme.textSecondary.withValues(alpha: 0.6),
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Right Pane: Tips Guide (idle) OR Package Inspector + Log Terminal (active)
          Expanded(
            flex: 6,
            child: !hasInstallerPackages
                ? _buildInstallerTipsGuide(context, theme)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Inspector Card (single app or batch summary)
                      _buildInstallerInspectorCard(context, theme, logic),
                      const SizedBox(height: 12),
                      // Terminal Log
                      Expanded(
                        child: _buildInstallerLogTerminal(
                          context,
                          theme,
                          logic,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatBadge(ThemeProvider theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInstallerTipsGuide(BuildContext context, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF00ADB5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Color(0xFF00ADB5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('installer_tips_title'),
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      context.tr('installer_tips_subtitle'),
                      style: TextStyle(
                        color: theme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                _buildInstallerTipTile(
                  theme: theme,
                  icon: Icons.layers_outlined,
                  color: const Color(0xFF00ADB5),
                  title: context.tr('installer_tip_1_title'),
                  desc: context.tr('installer_tip_1_desc'),
                ),
                const SizedBox(height: 12),
                _buildInstallerTipTile(
                  theme: theme,
                  icon: Icons.bolt_outlined,
                  color: const Color(0xFF7C5CFC),
                  title: context.tr('installer_tip_2_title'),
                  desc: context.tr('installer_tip_2_desc'),
                ),
                const SizedBox(height: 12),
                _buildInstallerTipTile(
                  theme: theme,
                  icon: Icons.folder_zip_outlined,
                  color: const Color(0xFFF59E0B),
                  title: context.tr('installer_tip_3_title'),
                  desc: context.tr('installer_tip_3_desc'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallerTipTile({
    required ThemeProvider theme,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.subCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderTheme.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: theme.textSecondary.withValues(alpha: 0.75),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallerInspectorCard(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) {
    final isSingle = logic.installerFilePaths.length == 1;
    final details = logic.installerAppDetails;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Color(0xFF00ADB5),
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('apk_inspector'),
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: logic.installerStatus == 'parsed'
                      ? Colors.teal.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  logic.installerStatus.toUpperCase(),
                  style: TextStyle(
                    color: logic.installerStatus == 'parsed'
                        ? Colors.tealAccent
                        : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isSingle && details.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ADB5).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.android,
                    color: Color(0xFF00ADB5),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details['name'] ??
                            p.basename(logic.installerFilePaths.first),
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              details['packageName'] ?? '',
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (details.containsKey('packageName'))
                            InkWell(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: details['packageName'] ?? '',
                                  ),
                                );
                                context.showSuccessToast(
                                  context.tr('copied_package_id'),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.copy,
                                  size: 13,
                                  color: Color(0xFF00ADB5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (details.containsKey('version')) ...[
                  _buildInspectorChip(
                    theme,
                    context.tr('version_label'),
                    details['version']!,
                  ),
                  const SizedBox(width: 8),
                ],
                if (details.containsKey('type')) ...[
                  _buildInspectorChip(
                    theme,
                    context.tr('type_label'),
                    details['type']!,
                  ),
                ],
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00ADB5),
                    side: BorderSide(
                      color: const Color(0xFF00ADB5).withValues(alpha: 0.4),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  icon: const Icon(Icons.copy_all_rounded, size: 14),
                  label: Text(
                    context.tr('clone_apk_file'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    final firstPath = logic.installerFilePaths.isNotEmpty
                        ? logic.installerFilePaths.first
                        : null;
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AppClonerDialog(
                        directApkPath: firstPath,
                        initialPackage: details['packageName'],
                        initialAppName: details['name'],
                      ),
                    );
                  },
                ),
              ],
            ),
          ] else ...[
            Text(
              context.tr(
                'packages_prepared',
                args: {'count': logic.installerFilePaths.length.toString()},
              ),
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInspectorChip(ThemeProvider theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.subCardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInstallerLogTerminal(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) {
    final terminalBg = theme.isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final headerBg = theme.isDark ? theme.headerBg : const Color(0xFFEDF2F7);
    final defaultTextColor = theme.isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF047857);

    return Container(
      decoration: BoxDecoration(
        color: terminalBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Terminal Title Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: headerBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: theme.borderTheme)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.terminal_rounded,
                  size: 15,
                  color: Color(0xFF00ADB5),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('terminal_log'),
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (logic.installerLog.isNotEmpty) ...[
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                        ClipboardData(text: logic.installerLog),
                      );
                      context.showSuccessToast(context.tr('log_copied'));
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.copy,
                            size: 12,
                            color: Color(0xFF00ADB5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('copy_log_btn'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF00ADB5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => logic.clearInstallerLog(),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 12,
                            color: theme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr('clear_log_btn'),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (logic.isInstalling)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF00ADB5),
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: SingleChildScrollView(
              reverse: true,
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text.rich(
                  Utils.parseAnsi(
                    logic.installerLog.isEmpty
                        ? '${context.tr('installer_waiting')}\n'
                        : logic.installerLog,
                    TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: defaultTextColor,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppFreezeTab(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) {
    if (logic.selectedDevice == null) {
      return _buildNoDevicePlaceholder(context, theme);
    }

    if (logic.apps.isEmpty && !logic.loadingApps && logic.appsError.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        logic.loadApps();
      });
    }

    final filteredApps = logic.apps.where((app) {
      if (!_showSystemApps && app.isSystem) return false;
      if (_appsSearchQuery.isNotEmpty) {
        final query = _appsSearchQuery.toLowerCase();
        return app.packageName.toLowerCase().contains(query) ||
            app.appName.toLowerCase().contains(query);
      }
      return true;
    }).toList();
    final allVisibleSelected =
        filteredApps.isNotEmpty &&
        filteredApps.every(
          (app) => _selectedAppPackages.contains(app.packageName),
        );

    return Column(
      children: [
        // Controls header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardBg,
            border: Border(bottom: BorderSide(color: theme.borderTheme)),
          ),
          child: Row(
            children: [
              // Search input
              Expanded(
                child: TextField(
                  controller: _appsSearchController,
                  style: TextStyle(color: theme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: context.tr('search_apps_placeholder'),
                    hintStyle: TextStyle(
                      color: theme.textSecondary.withValues(alpha: 0.5),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: theme.textSecondary,
                      size: 18,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.borderTheme),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: theme.borderTheme),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF00ADB5)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _appsSearchQuery = value.trim();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Show System Apps checkbox / switch
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Checkbox(
                    value: _showSystemApps,
                    activeColor: const Color(0xFF00ADB5),
                    onChanged: (val) {
                      setState(() {
                        _showSystemApps = val ?? false;
                      });
                    },
                  ),
                  Text(
                    context.tr('show_system_apps'),
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Sort button
              PopupMenuButton<AppSortOption>(
                icon: Icon(Icons.sort, color: theme.textPrimary),
                tooltip: context.tr('sort_apps_tooltip'),
                color: theme.dropdownBg,
                elevation: 10,
                shadowColor: Colors.black.withValues(
                  alpha: theme.isDark ? 0.45 : 0.16,
                ),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.dropdownBorder, width: 1.0),
                ),
                onSelected: (option) {
                  logic.setAppSortOption(option);
                },
                itemBuilder: (context) {
                  Widget sortItem({
                    required AppSortOption value,
                    required IconData icon,
                    required String label,
                  }) {
                    final selected = logic.appSortOption == value;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: selected
                          ? BoxDecoration(
                              color: const Color(
                                0xFF00ADB5,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(7),
                            )
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: selected
                                ? const Color(0xFF00ADB5)
                                : theme.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF00ADB5)
                                  : theme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return [
                    PopupMenuItem(
                      value: AppSortOption.name,
                      child: sortItem(
                        value: AppSortOption.name,
                        icon: Icons.sort_by_alpha,
                        label: context.tr('sort_by_name'),
                      ),
                    ),
                    PopupMenuItem(
                      value: AppSortOption.newest,
                      child: sortItem(
                        value: AppSortOption.newest,
                        icon: Icons.arrow_downward,
                        label: context.tr('sort_by_newest'),
                      ),
                    ),
                    PopupMenuItem(
                      value: AppSortOption.oldest,
                      child: sortItem(
                        value: AppSortOption.oldest,
                        icon: Icons.arrow_upward,
                        label: context.tr('sort_by_oldest'),
                      ),
                    ),
                  ];
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  allVisibleSelected
                      ? Icons.deselect_rounded
                      : Icons.select_all_rounded,
                  color: theme.textPrimary,
                ),
                tooltip: context.tr('select_all_apps'),
                onPressed: filteredApps.isEmpty
                    ? null
                    : () {
                        setState(() {
                          if (allVisibleSelected) {
                            _selectedAppPackages.removeAll(
                              filteredApps.map((app) => app.packageName),
                            );
                          } else {
                            _selectedAppPackages.addAll(
                              filteredApps.map((app) => app.packageName),
                            );
                          }
                        });
                      },
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add_check_rounded),
                color: _selectedAppPackages.isEmpty
                    ? theme.textSecondary.withValues(alpha: 0.45)
                    : const Color(0xFF00ADB5),
                tooltip: context.tr('batch_actions'),
                onPressed: _selectedAppPackages.isEmpty || _isBatchProcessing
                    ? null
                    : () => _showBatchActionPicker(context, theme, logic),
              ),
              if (_selectedAppPackages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${_selectedAppPackages.length}',
                    style: const TextStyle(
                      color: Color(0xFF00ADB5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              // Refresh button
              IconButton(
                icon: Icon(Icons.refresh, color: theme.textPrimary),
                tooltip: context.tr('refresh_list'),
                onPressed: () => logic.loadApps(),
              ),
            ],
          ),
        ),

        // Apps Master-Detail Layout
        Expanded(
          child: logic.loadingApps
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00ADB5)),
                )
              : logic.appsError.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: Colors.redAccent.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr(
                          'error_details',
                          args: {'error': logic.appsError.toString()},
                        ),
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ADB5),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => logic.loadApps(),
                        child: Text(context.tr('default_search_btn')),
                      ),
                    ],
                  ),
                )
              : filteredApps.isEmpty
              ? Center(
                  child: Text(
                    context.tr('no_apps_found'),
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left Column: Master List (55%)
                    Expanded(
                      flex: 55,
                      child: ListView.builder(
                        itemCount: filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = filteredApps[index];
                          final isSelected = _selectedAppPackages.contains(
                            app.packageName,
                          );
                          final isInspected =
                              _selectedAppDetailPackage == app.packageName;

                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedAppDetailPackage = app.packageName;
                              });
                            },
                            hoverColor: theme.cardHoverBg.withValues(
                              alpha: 0.25,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isInspected
                                    ? const Color(
                                        0xFF00ADB5,
                                      ).withValues(alpha: 0.14)
                                    : (isSelected
                                          ? const Color(
                                              0xFF00ADB5,
                                            ).withValues(alpha: 0.06)
                                          : Colors.transparent),
                                border: Border(
                                  bottom: BorderSide(
                                    color: theme.borderTheme,
                                    width: 0.5,
                                  ),
                                  left: isInspected
                                      ? const BorderSide(
                                          color: Color(0xFF00ADB5),
                                          width: 3.5,
                                        )
                                      : BorderSide.none,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: const Color(0xFF00ADB5),
                                    onChanged: (_) {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedAppPackages.remove(
                                            app.packageName,
                                          );
                                        } else {
                                          _selectedAppPackages.add(
                                            app.packageName,
                                          );
                                        }
                                      });
                                    },
                                  ),
                                  Icon(
                                    Icons.android_rounded,
                                    size: 22,
                                    color: app.isFrozen
                                        ? theme.textSecondary.withValues(
                                            alpha: 0.5,
                                          )
                                        : const Color(0xFF00ADB5),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          app.appName,
                                          style: TextStyle(
                                            color: app.isFrozen
                                                ? theme.textSecondary
                                                : theme.textPrimary,
                                            fontSize: 13,
                                            fontWeight: isInspected
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          app.packageName,
                                          style: TextStyle(
                                            color: theme.textSecondary
                                                .withValues(alpha: 0.75),
                                            fontSize: 10,
                                            fontFamily: 'monospace',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (app.isSystem)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.orange.withValues(
                                            alpha: 0.35,
                                          ),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: const Text(
                                        'SYS',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  _buildFreezeActionButton(
                                    context,
                                    theme,
                                    logic,
                                    app,
                                  ),
                                  const SizedBox(width: 2),
                                  _buildAppActionsMenu(
                                    context,
                                    theme,
                                    logic,
                                    app,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Divider
                    Container(width: 1, color: theme.borderTheme),

                    // Right Column: App Inspector Card (45%)
                    Expanded(
                      flex: 45,
                      child: _buildAppInspector(
                        context,
                        theme,
                        logic,
                        filteredApps
                            .where(
                              (a) => a.packageName == _selectedAppDetailPackage,
                            )
                            .firstOrNull,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAppInspector(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
    AndroidApp? app,
  ) {
    if (app == null) {
      final totalCount = logic.apps.length;
      final userCount = logic.apps.where((a) => !a.isSystem).length;
      final systemCount = logic.apps.where((a) => a.isSystem).length;
      final frozenCount = logic.apps.where((a) => a.isFrozen).length;

      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderTheme),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00ADB5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00ADB5).withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                size: 38,
                color: Color(0xFF00ADB5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('app_inspector'),
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.tr('no_app_selected'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.textSecondary, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            // Metrics Bento Grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    label: context.tr('app_summary_total'),
                    value: '$totalCount',
                    color: const Color(0xFF00ADB5),
                    icon: Icons.apps_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    label: context.tr('app_summary_user'),
                    value: '$userCount',
                    color: Colors.blueAccent,
                    icon: Icons.person_outline_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    label: context.tr('app_summary_system'),
                    value: '$systemCount',
                    color: Colors.orangeAccent,
                    icon: Icons.security_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    theme: theme,
                    label: context.tr('app_summary_frozen'),
                    value: '$frozenCount',
                    color: Colors.redAccent,
                    icon: Icons.ac_unit_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final isProcessing = _processingPackages.contains(app.packageName);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderTheme),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ADB5).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF00ADB5).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.android_rounded,
                    size: 30,
                    color: app.isFrozen
                        ? theme.textSecondary.withValues(alpha: 0.5)
                        : const Color(0xFF00ADB5),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.appName,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              app.packageName,
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            tooltip: context.tr('copy_package_id'),
                            color: theme.textSecondary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: app.packageName),
                              );
                              context.showSuccessToast(
                                context.tr(
                                  'copied_value',
                                  args: {'value': app.packageName},
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tags row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (app.isSystem ? Colors.orange : Colors.blue)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (app.isSystem ? Colors.orange : Colors.blue)
                          .withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    app.isSystem
                        ? context.tr('system_app_badge')
                        : context.tr('user_app_badge'),
                    style: TextStyle(
                      color: app.isSystem ? Colors.orange : Colors.blueAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (app.isFrozen ? Colors.red : Colors.green)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (app.isFrozen ? Colors.red : Colors.green)
                          .withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    app.isFrozen
                        ? context.tr('frozen_badge')
                        : context.tr('active_badge'),
                    style: TextStyle(
                      color: app.isFrozen ? Colors.redAccent : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (app.installTime != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardHoverBg.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.borderTheme, width: 0.8),
                    ),
                    child: Text(
                      context.tr(
                        'installed_time',
                        args: {
                          'time': app.installTime!
                              .toLocal()
                              .toString()
                              .substring(0, 16),
                        },
                      ),
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: theme.borderTheme),
            const SizedBox(height: 18),

            // Primary Freeze / Unfreeze Action Button
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: app.isFrozen
                      ? Colors.green
                      : const Color(0xFF00ADB5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                ),
                icon: isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Icon(
                        app.isFrozen
                            ? Icons.flash_on_rounded
                            : Icons.ac_unit_rounded,
                        size: 18,
                      ),
                label: Text(
                  isProcessing
                      ? context.tr('processing_label')
                      : app.isFrozen
                      ? context.tr('action_unfreeze')
                      : context.tr('action_freeze'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        setState(
                          () => _processingPackages.add(app.packageName),
                        );
                        final ok = app.isFrozen
                            ? await logic.unfreezeApp(app.packageName)
                            : await logic.freezeApp(app.packageName);
                        if (!mounted) return;
                        setState(
                          () => _processingPackages.remove(app.packageName),
                        );
                        if (context.mounted && !ok) {
                          context.showErrorToast(
                            context.tr(
                              app.isFrozen
                                  ? 'unfreeze_app_failed'
                                  : 'freeze_app_failed',
                              args: {'app': app.packageName},
                            ),
                          );
                        }
                      },
              ),
            ),
            const SizedBox(height: 14),

            // Secondary Action Grid
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    theme: theme,
                    icon: Icons.play_arrow_rounded,
                    label: context.tr('action_launch'),
                    color: const Color(0xFF00ADB5),
                    onTap: () async {
                      final ok = await logic.launchApp(app.packageName);
                      if (context.mounted) {
                        if (ok) {
                          context.showSuccessToast(
                            context.tr(
                              'launch_success',
                              args: {'app': app.appName},
                            ),
                          );
                        } else {
                          context.showErrorToast(
                            context.tr(
                              'launch_failed',
                              args: {'app': app.appName},
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionTile(
                    theme: theme,
                    icon: Icons.stop_rounded,
                    label: context.tr('action_force_stop'),
                    color: Colors.orangeAccent,
                    onTap: () async {
                      final ok = await logic.forceStopApp(app.packageName);
                      if (context.mounted) {
                        if (ok) {
                          context.showSuccessToast(
                            context.tr(
                              'force_stop_success',
                              args: {'app': app.appName},
                            ),
                          );
                        } else {
                          context.showErrorToast(
                            context.tr(
                              'force_stop_failed',
                              args: {'app': app.appName},
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    theme: theme,
                    icon: Icons.file_download_outlined,
                    label: context.tr('action_extract_apk'),
                    color: Colors.green,
                    onTap: () async {
                      final targetDir = await FilePicker.getDirectoryPath();
                      if (targetDir == null || !context.mounted) return;
                      context.showInfoToast(
                        context.tr(
                          'extracting_app',
                          args: {'app': app.appName},
                        ),
                      );
                      final outPath = await logic.extractAppPackage(
                        packageName: app.packageName,
                        targetDirectory: targetDir,
                        appName: app.appName,
                      );
                      if (context.mounted) {
                        if (outPath != null) {
                          final fileName = p.basename(outPath);
                          context.showSuccessToast(
                            context.tr(
                              'extract_apk_success',
                              args: {'app': app.appName, 'file': fileName},
                            ),
                            actionLabel: context.tr('open_folder'),
                            onAction: () {
                              unawaited(
                                Process.run('explorer.exe', [
                                  targetDir,
                                ]).then<void>(
                                  (_) {},
                                  onError: (Object _, StackTrace _) {},
                                ),
                              );
                            },
                          );
                        } else {
                          context.showErrorToast(
                            context.tr(
                              'extract_apk_failed',
                              args: {'app': app.appName},
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionTile(
                    theme: theme,
                    icon: Icons.cleaning_services_rounded,
                    label: context.tr('action_clear_data'),
                    color: Colors.amber,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => ConfirmActionDialog(
                          title: context.tr('clear_data_btn'),
                          message: context.tr(
                            'clear_data_confirm',
                            args: {'app': app.appName},
                          ),
                        ),
                      );
                      if (confirm == true) {
                        final ok = await logic.clearAppData(app.packageName);
                        if (context.mounted) {
                          if (ok) {
                            context.showSuccessToast(
                              context.tr(
                                'clear_data_success',
                                args: {'app': app.appName},
                              ),
                            );
                          } else {
                            context.showErrorToast(
                              context.tr(
                                'clear_data_failed',
                                args: {'app': app.appName},
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    theme: theme,
                    icon: Icons.copy_all_rounded,
                    label: context.tr('action_clone_app'),
                    color: const Color(0xFF00ADB5),
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (ctx) => AppClonerDialog(app: app),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionTile(
                    theme: theme,
                    icon: Icons.delete_outline_rounded,
                    label: context.tr('action_uninstall'),
                    color: Colors.redAccent,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => ConfirmActionDialog(
                          title: context.tr('uninstall_btn'),
                          message: context.tr(
                            'uninstall_confirm',
                            args: {'app': app.appName},
                          ),
                        ),
                      );
                      if (confirm == true && mounted) {
                        setState(
                          () => _processingPackages.add(app.packageName),
                        );
                        final ok = await logic.uninstallApp(app.packageName);
                        if (!mounted) return;
                        setState(
                          () => _processingPackages.remove(app.packageName),
                        );
                        if (context.mounted) {
                          if (ok) {
                            context.showSuccessToast(
                              context.tr(
                                'uninstall_success',
                                args: {'app': app.appName},
                              ),
                            );
                          } else {
                            context.showErrorToast(
                              context.tr(
                                'uninstall_failed',
                                args: {'app': app.appName},
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required ThemeProvider theme,
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: TextStyle(color: theme.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required ThemeProvider theme,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 38,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.4), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        icon: Icon(icon, size: 16, color: color),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: onTap,
      ),
    );
  }

  Future<void> _showBatchActionPicker(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => GlassDialog(
        child: SimpleDialog(
          backgroundColor: glassDialogBackground(
            theme: theme,
            opacity: logic.dialogOpacity,
          ),
          surfaceTintColor: Colors.transparent,
          title: Text(context.tr('batch_actions')),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'freeze'),
              child: ListTile(
                leading: const Icon(Icons.ac_unit, color: Color(0xFF00ADB5)),
                title: Text(context.tr('batch_freeze')),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'unfreeze'),
              child: ListTile(
                leading: const Icon(Icons.flash_on, color: Colors.green),
                title: Text(context.tr('batch_unfreeze')),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'force_stop'),
              child: ListTile(
                leading: Icon(Icons.stop, color: theme.textSecondary),
                title: Text(context.tr('batch_force_stop')),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'uninstall'),
              child: ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.redAccent,
                ),
                title: Text(
                  context.tr('batch_uninstall'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, 'extract'),
              child: ListTile(
                leading: const Icon(
                  Icons.file_download_outlined,
                  color: Color(0xFF00ADB5),
                ),
                title: Text(context.tr('batch_extract_apk')),
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'extract') {
      final targetDir = await FilePicker.getDirectoryPath();
      if (targetDir == null || !mounted) return;

      final selectedApps = logic.apps
          .where((app) => _selectedAppPackages.contains(app.packageName))
          .toList();
      if (selectedApps.isEmpty) return;

      setState(() => _isBatchProcessing = true);
      context.showInfoToast(
        context.tr(
          'extracting_apps',
          args: {'count': selectedApps.length.toString()},
        ),
      );

      final count = await logic.extractSelectedApps(
        apps: selectedApps,
        targetDirectory: targetDir,
      );

      if (mounted) {
        setState(() {
          _isBatchProcessing = false;
          _selectedAppPackages.clear();
        });
        if (count > 0) {
          context.showSuccessToast(
            context.tr('batch_extract_success', args: {'count': '$count'}),
            actionLabel: context.tr('open_folder'),
            onAction: () {
              unawaited(
                Process.run('explorer.exe', [
                  targetDir,
                ]).then<void>((_) {}, onError: (Object _, StackTrace _) {}),
              );
            },
          );
        } else {
          context.showErrorToast(
            context.tr(
              'batch_result',
              args: {'success': '0', 'failed': '${selectedApps.length}'},
            ),
          );
        }
      }
      return;
    }

    if (action == 'uninstall') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => ConfirmActionDialog(
          title: context.tr('batch_uninstall'),
          message: context.tr(
            'batch_uninstall_confirm',
            args: {'count': '${_selectedAppPackages.length}'},
          ),
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await _runBatchAction(logic, action);
  }

  Future<void> _runBatchAction(AppLogic logic, String action) async {
    final packages = _selectedAppPackages.toList(growable: false);
    if (packages.isEmpty || _isBatchProcessing) return;
    setState(() => _isBatchProcessing = true);
    final result = await logic.runBatchAppAction(
      packageNames: packages,
      action: action,
    );
    if (!mounted) return;
    setState(() {
      _isBatchProcessing = false;
      _selectedAppPackages.clear();
    });
    context.showInfoToast(
      context.tr(
        'batch_result',
        args: {
          'success': '${result.succeeded.length}',
          'failed': '${result.failed.length}',
        },
      ),
    );
  }

  Widget _buildFreezeActionButton(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
    AndroidApp app,
  ) {
    final isProcessing = _processingPackages.contains(app.packageName);

    if (isProcessing) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF00ADB5),
        ),
      );
    }

    if (app.isFrozen) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.withValues(alpha: 0.15),
          foregroundColor: Colors.green,
          elevation: 0,
          side: const BorderSide(color: Colors.green, width: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.flash_on, size: 14),
        label: Text(
          context.tr('unfreeze_btn'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          setState(() {
            _processingPackages.add(app.packageName);
          });
          final ok = await logic.unfreezeApp(app.packageName);
          if (!mounted) return;
          setState(() {
            _processingPackages.remove(app.packageName);
          });
          if (context.mounted && !ok) {
            context.showErrorToast(
              context.tr('unfreeze_app_failed', args: {'app': app.packageName}),
            );
          }
        },
      );
    } else {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00ADB5).withValues(alpha: 0.15),
          foregroundColor: const Color(0xFF00ADB5),
          elevation: 0,
          side: const BorderSide(color: Color(0xFF00ADB5), width: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: const Icon(Icons.ac_unit, size: 14),
        label: Text(
          context.tr('freeze_btn'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          setState(() {
            _processingPackages.add(app.packageName);
          });
          final ok = await logic.freezeApp(app.packageName);
          if (!mounted) return;
          setState(() {
            _processingPackages.remove(app.packageName);
          });
          if (context.mounted && !ok) {
            context.showErrorToast(
              context.tr('freeze_app_failed', args: {'app': app.packageName}),
            );
          }
        },
      );
    }
  }

  Widget _buildAppActionsMenu(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
    AndroidApp app,
  ) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: theme.textSecondary),
      color: theme.dropdownBg,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: theme.isDark ? 0.45 : 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dropdownBorder, width: 1.0),
      ),
      onSelected: (action) async {
        if (action == 'launch') {
          final ok = await logic.launchApp(app.packageName);
          if (context.mounted) {
            if (ok) {
              context.showSuccessToast(
                context.tr('launch_success', args: {'app': app.appName}),
              );
            } else {
              context.showErrorToast(
                context.tr('launch_failed', args: {'app': app.appName}),
              );
            }
          }
        } else if (action == 'force_stop') {
          final ok = await logic.forceStopApp(app.packageName);
          if (context.mounted) {
            if (ok) {
              context.showSuccessToast(
                context.tr('force_stop_success', args: {'app': app.appName}),
              );
            } else {
              context.showErrorToast(
                context.tr('force_stop_failed', args: {'app': app.appName}),
              );
            }
          }
        } else if (action == 'clear_data') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => ConfirmActionDialog(
              title: context.tr('clear_data_btn'),
              message: context.tr(
                'clear_data_confirm',
                args: {'app': app.appName},
              ),
            ),
          );
          if (confirm == true) {
            final ok = await logic.clearAppData(app.packageName);
            if (context.mounted) {
              if (ok) {
                context.showSuccessToast(
                  context.tr('clear_data_success', args: {'app': app.appName}),
                );
              } else {
                context.showErrorToast(
                  context.tr('clear_data_failed', args: {'app': app.appName}),
                );
              }
            }
          }
        } else if (action == 'uninstall') {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => ConfirmActionDialog(
              title: context.tr('uninstall_btn'),
              message: context.tr(
                'uninstall_confirm',
                args: {'app': app.appName},
              ),
            ),
          );
          if (confirm == true && mounted) {
            setState(() {
              _processingPackages.add(app.packageName);
            });
            final ok = await logic.uninstallApp(app.packageName);
            if (!mounted) return;
            setState(() {
              _processingPackages.remove(app.packageName);
            });
            if (context.mounted) {
              if (ok) {
                context.showSuccessToast(
                  context.tr('uninstall_success', args: {'app': app.appName}),
                );
              } else {
                context.showErrorToast(
                  context.tr('uninstall_failed', args: {'app': app.appName}),
                );
              }
            }
          }
        } else if (action == 'extract') {
          final targetDir = await FilePicker.getDirectoryPath();
          if (targetDir != null && context.mounted) {
            context.showInfoToast(
              context.tr('extracting_app', args: {'app': app.appName}),
            );
            final outPath = await logic.extractAppPackage(
              packageName: app.packageName,
              targetDirectory: targetDir,
              appName: app.appName,
            );
            if (context.mounted) {
              if (outPath != null) {
                final fileName = p.basename(outPath);
                context.showSuccessToast(
                  context.tr(
                    'extract_apk_success',
                    args: {'app': app.appName, 'file': fileName},
                  ),
                  actionLabel: context.tr('open_folder'),
                  onAction: () {
                    unawaited(
                      Process.run('explorer.exe', [
                        '/select,',
                        outPath,
                      ]).then<void>(
                        (_) {},
                        onError: (Object _, StackTrace _) {},
                      ),
                    );
                  },
                );
              } else {
                context.showErrorToast(
                  context.tr('extract_apk_failed', args: {'app': app.appName}),
                );
              }
            }
          }
        } else if (action == 'clone') {
          showDialog<void>(
            context: context,
            builder: (ctx) => AppClonerDialog(app: app),
          );
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'launch',
          child: Row(
            children: [
              Icon(Icons.play_arrow, size: 18, color: theme.textSecondary),
              const SizedBox(width: 8),
              Text(
                context.tr('launch_app_btn'),
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'force_stop',
          child: Row(
            children: [
              Icon(Icons.stop, size: 18, color: theme.textSecondary),
              const SizedBox(width: 8),
              Text(
                context.tr('force_stop_btn'),
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear_data',
          child: Row(
            children: [
              Icon(
                Icons.cleaning_services,
                size: 18,
                color: theme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('clear_data_btn'),
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'extract',
          child: Row(
            children: [
              const Icon(
                Icons.file_download_outlined,
                size: 18,
                color: Color(0xFF00ADB5),
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('extract_apk_btn'),
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'clone',
          child: Row(
            children: [
              const Icon(
                Icons.copy_all_rounded,
                size: 18,
                color: Color(0xFF00ADB5),
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('action_clone_app'),
                style: TextStyle(color: theme.textPrimary, fontSize: 13),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'uninstall',
          child: Row(
            children: [
              const Icon(
                Icons.delete_forever,
                size: 18,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('uninstall_btn'),
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickToolsTab(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) {
    if (logic.selectedDevice == null) {
      return _buildNoDevicePlaceholder(context, theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Settings Shortcuts
          Text(
            context.tr('settings_shortcuts'),
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final int crossAxisCount = width >= 1200
                  ? 6
                  : width >= 880
                  ? 4
                  : width >= 580
                  ? 3
                  : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisExtent: 62,
                children: [
                  _buildShortcutCard(
                    icon: Icons.copy_all_rounded,
                    title: context.tr('app_cloner_title'),
                    subtitle: context.tr('app_cloner_subtitle'),
                    theme: theme,
                    isHighlight: true,
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => const AppClonerDialog(),
                      );
                    },
                  ),
                  _buildShortcutCard(
                    icon: Icons.home_rounded,
                    title: context.tr('launcher_settings'),
                    subtitle: 'am start -a ...HOME_SETTINGS',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.settings.HOME_SETTINGS',
                    ]),
                  ),
                  _buildShortcutCard(
                    icon: Icons.lock_rounded,
                    title: context.tr('lock_settings'),
                    subtitle: 'am start -a ...SET_NEW_PASSWORD',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.app.action.SET_NEW_PASSWORD',
                    ]),
                  ),
                  _buildShortcutCard(
                    icon: Icons.language_rounded,
                    title: context.tr('language_settings'),
                    subtitle: 'am start -a ...LOCALE_SETTINGS',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.settings.LOCALE_SETTINGS',
                    ]),
                  ),
                  _buildShortcutCard(
                    icon: Icons.code_rounded,
                    title: context.tr('developer_options'),
                    subtitle: 'am start -a ...DEVELOPMENT_SETTINGS',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.settings.APPLICATION_DEVELOPMENT_SETTINGS',
                    ]),
                  ),
                  _buildShortcutCard(
                    icon: Icons.wifi_rounded,
                    title: context.tr('wifi_settings'),
                    subtitle: 'am start -a ...WIFI_SETTINGS',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.settings.WIFI_SETTINGS',
                    ]),
                  ),
                  _buildShortcutCard(
                    icon: Icons.wifi_tethering_rounded,
                    title: context.tr('quick_tool_fix_port_title'),
                    subtitle: context.tr('quick_tool_fix_port_subtitle'),
                    theme: theme,
                    isHighlight: true,
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => const WirelessAdbDialog(),
                      );
                    },
                  ),
                  _buildShortcutCard(
                    icon: Icons.access_time_filled_rounded,
                    title: context.tr('ntp_time_sync_title'),
                    subtitle: context.tr('ntp_time_sync_subtitle'),
                    theme: theme,
                    isHighlight: true,
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => const NtpTimeSyncDialog(),
                      );
                    },
                  ),
                  _buildShortcutCard(
                    icon: Icons.edit_calendar_rounded,
                    title: context.tr('date_settings'),
                    subtitle: 'am start -a ...DATE_SETTINGS',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.settings.DATE_SETTINGS',
                    ]),
                  ),
                  _buildShortcutCard(
                    icon: Icons.settings_display_rounded,
                    title: context.tr('display_settings'),
                    subtitle: 'am start -a ...DISPLAY_SETTINGS',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.settings.DISPLAY_SETTINGS',
                    ]),
                  ),
                  _buildShortcutCard(
                    icon: Icons.accessibility_new_rounded,
                    title: context.tr('accessibility_settings'),
                    subtitle: 'am start -a ...ACCESSIBILITY_SETTINGS',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.settings.ACCESSIBILITY_SETTINGS',
                    ]),
                  ),
                  _buildShortcutCard(
                    icon: Icons.apps_rounded,
                    title: context.tr('app_settings'),
                    subtitle: 'am start -a ...APPLICATION_SETTINGS',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.settings.APPLICATION_SETTINGS',
                    ]),
                  ),
                  _buildShortcutCard(
                    icon: Icons.phone_android_rounded,
                    title: context.tr('about_phone'),
                    subtitle: 'am start -a ...DEVICE_INFO_SETTINGS',
                    theme: theme,
                    onTap: () => logic.runAdbShellCommand([
                      'am',
                      'start',
                      '-a',
                      'android.settings.DEVICE_INFO_SETTINGS',
                    ]),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. Text Input & ADB Command tool
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _quickToolSubTab == 0
                          ? context.tr('text_input_tool')
                          : context.tr('adb_command_tab'),
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: theme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.borderTheme),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Custom Segmented Switcher for Sub-tabs
                          Container(
                            height: 32,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.borderTheme),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _quickToolSubTab = 0;
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _quickToolSubTab == 0
                                            ? const Color(0xFF00ADB5)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.keyboard_outlined,
                                            size: 14,
                                            color: _quickToolSubTab == 0
                                                ? Colors.white
                                                : theme.textSecondary,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            context.tr('text_input_tab'),
                                            style: TextStyle(
                                              color: _quickToolSubTab == 0
                                                  ? Colors.white
                                                  : theme.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _quickToolSubTab = 1;
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _quickToolSubTab == 1
                                            ? const Color(0xFF00ADB5)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.terminal_rounded,
                                            size: 14,
                                            color: _quickToolSubTab == 1
                                                ? Colors.white
                                                : theme.textSecondary,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            context.tr('adb_command_tab'),
                                            style: TextStyle(
                                              color: _quickToolSubTab == 1
                                                  ? Colors.white
                                                  : theme.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          if (_quickToolSubTab == 0) ...[
                            // --- TEXT INPUT MODE ---
                            if (logic.textInputHistory.isNotEmpty) ...[
                              Row(
                                children: [
                                  Text(
                                    context.tr('command_history_label'),
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      height: 32,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: theme.borderTheme,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          hint: Text(
                                            context.tr('select_history_hint'),
                                            style: TextStyle(
                                              color: theme.textSecondary
                                                  .withValues(alpha: 0.5),
                                              fontSize: 12,
                                            ),
                                          ),
                                          dropdownColor: theme.dropdownBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          style: TextStyle(
                                            color: theme.textPrimary,
                                            fontSize: 12,
                                          ),
                                          items: logic.textInputHistory.map((
                                            historyText,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: historyText,
                                              child: Text(
                                                historyText,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              _textInputController.text = val;
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                            TextField(
                              controller: _textInputController,
                              minLines: 2,
                              maxLines: 2,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 12.5,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                hintText: context.tr('text_input_placeholder'),
                                hintStyle: TextStyle(
                                  color: theme.textSecondary.withValues(
                                    alpha: 0.45,
                                  ),
                                  fontSize: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: theme.borderTheme,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: theme.borderTheme,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00ADB5),
                                  ),
                                ),
                                fillColor: Colors.black26,
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final text = _textInputController.text.trim();
                                  if (text.isEmpty) return;
                                  final String escaped = text
                                      .replaceAll(' ', '%s')
                                      .replaceAll('"', '\\"')
                                      .replaceAll("'", "\\'")
                                      .replaceAll('`', '\\`')
                                      .replaceAll('\$', '\\\$')
                                      .replaceAll('&', '\\&')
                                      .replaceAll('|', '\\|')
                                      .replaceAll(';', '\\;')
                                      .replaceAll('<', '\\<')
                                      .replaceAll('>', '\\>');
                                  final ok = await logic.runAdbShellCommand([
                                    'input',
                                    'text',
                                    escaped,
                                  ]);
                                  if (ok) {
                                    await logic.addTextInputToHistory(text);
                                    _textInputController.clear();
                                  } else {
                                    if (!context.mounted) return;
                                    context.showErrorToast(
                                      'Failed to send text to device.',
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send_rounded, size: 14),
                                label: Text(
                                  context.tr('send_text'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ADB5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 9,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            // --- ADB COMMAND MODE ---
                            Row(
                              children: [
                                Text(
                                  context.tr('predefined_label'),
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: logic.predefinedInputs.isNotEmpty
                                      ? Container(
                                          height: 32,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black26,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: theme.borderTheme,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              hint: Text(
                                                context.tr(
                                                  'select_predefined_hint',
                                                ),
                                                style: TextStyle(
                                                  color: theme.textSecondary
                                                      .withValues(alpha: 0.5),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              dropdownColor: theme.dropdownBg,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              style: TextStyle(
                                                color: theme.textPrimary,
                                                fontSize: 12,
                                              ),
                                              items: logic.predefinedInputs.map(
                                                (item) {
                                                  return DropdownMenuItem<
                                                    String
                                                  >(
                                                    value: item['value'],
                                                    child: Text(
                                                      item['label'] ?? '',
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                },
                                              ).toList(),
                                              onChanged: (val) {
                                                if (val != null) {
                                                  _adbCommandController.text =
                                                      val;
                                                }
                                              },
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'No templates',
                                          style: TextStyle(
                                            color: theme.textSecondary
                                                .withValues(alpha: 0.5),
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                ),
                                if (logic.adbCommandHistory.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    context.tr('command_history_label'),
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      height: 32,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black26,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: theme.borderTheme,
                                        ),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          isExpanded: true,
                                          hint: Text(
                                            context.tr('select_history_hint'),
                                            style: TextStyle(
                                              color: theme.textSecondary
                                                  .withValues(alpha: 0.5),
                                              fontSize: 12,
                                            ),
                                          ),
                                          dropdownColor: theme.dropdownBg,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          style: TextStyle(
                                            color: theme.textPrimary,
                                            fontSize: 12,
                                          ),
                                          items: logic.adbCommandHistory.map((
                                            cmd,
                                          ) {
                                            return DropdownMenuItem<String>(
                                              value: cmd,
                                              child: Text(
                                                cmd,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              _adbCommandController.text = val;
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _adbCommandController,
                              maxLines: 1,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                hintText: context.tr('adb_command_placeholder'),
                                hintStyle: TextStyle(
                                  color: theme.textSecondary.withValues(
                                    alpha: 0.45,
                                  ),
                                  fontSize: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: theme.borderTheme,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: theme.borderTheme,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00ADB5),
                                  ),
                                ),
                                fillColor: Colors.black26,
                                filled: true,
                                prefixIcon: const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF00ADB5),
                                  size: 17,
                                ),
                              ),
                              onSubmitted: (val) async {
                                if (_isExecutingAdbCommand ||
                                    val.trim().isEmpty) {
                                  return;
                                }
                                final cmd = val.trim();
                                setState(() {
                                  _isExecutingAdbCommand = true;
                                  _adbConsoleOutput += '\n\$ $cmd\n';
                                });
                                _scrollToConsoleBottom();

                                final result = await logic.runCustomAdbCommand(
                                  cmd,
                                );

                                setState(() {
                                  _isExecutingAdbCommand = false;
                                  if (result.stdout.isNotEmpty) {
                                    _adbConsoleOutput += result.stdout;
                                  }
                                  if (result.stderr.isNotEmpty) {
                                    _adbConsoleOutput += result.stderr;
                                  }
                                  if (result.stdout.isEmpty &&
                                      result.stderr.isEmpty) {
                                    _adbConsoleOutput +=
                                        '[Process exited with code ${result.exitCode}]\n';
                                  }
                                });
                                _scrollToConsoleBottom();
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('console_output_label'),
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              height: 120,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.borderTheme),
                              ),
                              child: Scrollbar(
                                controller: _adbConsoleScrollController,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _adbConsoleScrollController,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: SelectableText(
                                      _adbConsoleOutput.isEmpty
                                          ? 'Console output will be displayed here...'
                                          : _adbConsoleOutput,
                                      style: TextStyle(
                                        color: theme.isDark
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFF047857),
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _adbConsoleOutput = '';
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 15,
                                    color: Colors.redAccent,
                                  ),
                                  label: Text(
                                    context.tr('clear_console_btn'),
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _isExecutingAdbCommand
                                      ? null
                                      : () async {
                                          final cmd = _adbCommandController.text
                                              .trim();
                                          if (cmd.isEmpty) return;
                                          setState(() {
                                            _isExecutingAdbCommand = true;
                                            _adbConsoleOutput += '\n\$ $cmd\n';
                                          });
                                          _scrollToConsoleBottom();

                                          final result = await logic
                                              .runCustomAdbCommand(cmd);

                                          setState(() {
                                            _isExecutingAdbCommand = false;
                                            if (result.stdout.isNotEmpty) {
                                              _adbConsoleOutput +=
                                                  result.stdout;
                                            }
                                            if (result.stderr.isNotEmpty) {
                                              _adbConsoleOutput +=
                                                  result.stderr;
                                            }
                                            if (result.stdout.isEmpty &&
                                                result.stderr.isEmpty) {
                                              _adbConsoleOutput +=
                                                  '[Process exited with code ${result.exitCode}]\n';
                                            }
                                          });
                                          _scrollToConsoleBottom();
                                        },
                                  icon: _isExecutingAdbCommand
                                      ? const SizedBox(
                                          width: 13,
                                          height: 13,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 15,
                                        ),
                                  label: Text(
                                    context.tr('run_command_btn'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00ADB5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // 3. Navigation / Hardware Key Simulation
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('hardware_keys'),
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: theme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.borderTheme),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              _buildKeyBtn(
                                icon: Icons.arrow_back_rounded,
                                label: context.tr('key_back'),
                                theme: theme,
                                onTap: () => logic.runAdbShellCommand([
                                  'input',
                                  'keyevent',
                                  '4',
                                ]),
                              ),
                              const SizedBox(width: 8),
                              _buildKeyBtn(
                                icon: Icons.circle_outlined,
                                label: context.tr('key_home'),
                                theme: theme,
                                onTap: () => logic.runAdbShellCommand([
                                  'input',
                                  'keyevent',
                                  '3',
                                ]),
                              ),
                              const SizedBox(width: 8),
                              _buildKeyBtn(
                                icon: Icons.crop_square_rounded,
                                label: context.tr('key_recents'),
                                theme: theme,
                                onTap: () => logic.runAdbShellCommand([
                                  'input',
                                  'keyevent',
                                  '187',
                                ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildKeyBtn(
                                icon: Icons.power_settings_new_rounded,
                                label: context.tr('key_power'),
                                theme: theme,
                                onTap: () => logic.runAdbShellCommand([
                                  'input',
                                  'keyevent',
                                  '26',
                                ]),
                              ),
                              const SizedBox(width: 8),
                              _buildKeyBtn(
                                icon: Icons.volume_up_rounded,
                                label: context.tr('key_volume_up'),
                                theme: theme,
                                onTap: () => logic.runAdbShellCommand([
                                  'input',
                                  'keyevent',
                                  '24',
                                ]),
                              ),
                              const SizedBox(width: 8),
                              _buildKeyBtn(
                                icon: Icons.volume_down_rounded,
                                label: context.tr('key_volume_down'),
                                theme: theme,
                                onTap: () => logic.runAdbShellCommand([
                                  'input',
                                  'keyevent',
                                  '25',
                                ]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Device Controls / Reboot actions
          Text(
            context.tr('device_controls'),
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildPowerBtn(
                icon: Icons.restart_alt_rounded,
                label: context.tr('reboot_system'),
                subtitle: context.tr('reboot_system_sub'),
                color: const Color(0xFFF59E0B),
                theme: theme,
                onTap: () => _confirmAction(
                  context,
                  title: context.tr('confirm_reboot'),
                  message: context.tr('confirm_reboot_msg'),
                  onConfirm: () => logic.runAdbRebootCommand(''),
                ),
              ),
              const SizedBox(width: 10),
              _buildPowerBtn(
                icon: Icons.flash_on_rounded,
                label: context.tr('reboot_bootloader'),
                subtitle: context.tr('reboot_bootloader_sub'),
                color: const Color(0xFFF97316),
                theme: theme,
                onTap: () => _confirmAction(
                  context,
                  title: context.tr('confirm_reboot'),
                  message: '${context.tr('confirm_reboot_msg')} (Fastboot)',
                  onConfirm: () => logic.runAdbRebootCommand('bootloader'),
                ),
              ),
              const SizedBox(width: 10),
              _buildPowerBtn(
                icon: Icons.build_circle_outlined,
                label: context.tr('reboot_recovery'),
                subtitle: context.tr('reboot_recovery_sub'),
                color: const Color(0xFFEA580C),
                theme: theme,
                onTap: () => _confirmAction(
                  context,
                  title: context.tr('confirm_reboot'),
                  message: '${context.tr('confirm_reboot_msg')} (Recovery)',
                  onConfirm: () => logic.runAdbRebootCommand('recovery'),
                ),
              ),
              const SizedBox(width: 10),
              _buildPowerBtn(
                icon: Icons.power_settings_new_rounded,
                label: context.tr('power_off'),
                subtitle: context.tr('power_off_sub'),
                color: const Color(0xFFEF4444),
                theme: theme,
                onTap: () => _confirmAction(
                  context,
                  title: context.tr('confirm_power_off'),
                  message: context.tr('confirm_power_off_msg'),
                  onConfirm: () => logic.runAdbPowerOff(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 5. Reverse Tethering (Gnirehtet)
          Text(
            context.tr('reverse_tethering_title'),
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: theme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.borderTheme),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00ADB5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.wifi_tethering_rounded,
                        color: Color(0xFF00ADB5),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                context.tr('reverse_tethering_title'),
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: logic.isGnirehtetRunning
                                      ? Colors.green.withValues(alpha: 0.15)
                                      : Colors.red.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: logic.isGnirehtetRunning
                                        ? Colors.green
                                        : Colors.redAccent,
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  logic.isGnirehtetRunning
                                      ? context
                                            .tr('reverse_tethering_active')
                                            .toUpperCase()
                                      : context
                                            .tr('reverse_tethering_inactive')
                                            .toUpperCase(),
                                  style: TextStyle(
                                    color: logic.isGnirehtetRunning
                                        ? Colors.green
                                        : Colors.redAccent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('reverse_tethering_desc'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textSecondary.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (logic.isGnirehtetRunning) {
                          await logic.stopReverseTethering();
                        } else {
                          if (logic.gnirehtetPath.isEmpty) {
                            context.showErrorToast(
                              'Please configure Gnirehtet path in Settings first.',
                            );
                            return;
                          }
                          final ok = await logic.startReverseTethering();
                          if (context.mounted && !ok) {
                            context.showErrorToast(
                              'Failed to start reverse tethering.',
                            );
                          }
                        }
                      },
                      icon: Icon(
                        logic.isGnirehtetRunning
                            ? Icons.portable_wifi_off_rounded
                            : Icons.wifi_tethering_rounded,
                        size: 16,
                      ),
                      label: Text(
                        logic.isGnirehtetRunning
                            ? context.tr('stop_reverse_tethering')
                            : context.tr('start_reverse_tethering'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: logic.isGnirehtetRunning
                            ? Colors.redAccent
                            : const Color(0xFF00ADB5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                if (logic.isGnirehtetRunning) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blueAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('vpn_instruction'),
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (logic.isGnirehtetRunning ||
                    logic.gnirehtetLogs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.tr('gnirehtet_logs'),
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (logic.gnirehtetLogs.isNotEmpty)
                        InkWell(
                          onTap: () => logic.clearGnirehtetLogs(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              context.tr('clear_console_btn'),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    height: 120,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.isDark
                          ? Colors.black
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.borderTheme),
                    ),
                    child: SingleChildScrollView(
                      reverse: true,
                      child: Text(
                        logic.gnirehtetLogs.isEmpty
                            ? 'No logs available.'
                            : logic.gnirehtetLogs,
                        style: TextStyle(
                          color: theme.isDark
                              ? Colors.greenAccent
                              : const Color(0xFF006400),
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeProvider theme,
    required VoidCallback onTap,
    bool isHighlight = false,
  }) {
    const accent = Color(0xFF00ADB5);
    return Tooltip(
      message: '$title\n$subtitle',
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: accent.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHighlight
                    ? accent.withValues(alpha: 0.35)
                    : theme.borderTheme,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: isHighlight ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textSecondary.withValues(alpha: 0.45),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: theme.textSecondary.withValues(alpha: 0.25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeyBtn({
    required IconData icon,
    required String label,
    required ThemeProvider theme,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: const Color(0xFF00ADB5).withValues(alpha: 0.1),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.borderTheme),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: const Color(0xFF00ADB5)),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPowerBtn({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required ThemeProvider theme,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: color.withValues(alpha: 0.09),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.25)),
              color: color.withValues(alpha: 0.04),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    final theme = context.read<ThemeProvider>();
    final logic = context.read<AppLogic>();
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return GlassDialog(
          child: AlertDialog(
            backgroundColor: glassDialogBackground(
              theme: theme,
              opacity: logic.dialogOpacity,
            ),
            surfaceTintColor: Colors.transparent,
            title: Text(title, style: TextStyle(color: theme.textPrimary)),
            content: Text(
              message,
              style: TextStyle(color: theme.textSecondary),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onConfirm();
                },
                child: const Text(
                  'Confirm',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runWithTransferProgress(
    BuildContext context,
    AppLogic logic,
    Future<bool> Function() action, {
    String? destinationDirectory,
  }) async {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return Consumer<AppLogic>(
            builder: (ctx2, logic, child) {
              final progress = logic.transferProgress;
              final status = logic.transferStatus;
              final theme = ctx2.read<ThemeProvider>();

              return GlassDialog(
                child: AlertDialog(
                  backgroundColor: glassDialogBackground(
                    theme: theme,
                    opacity: logic.dialogOpacity,
                  ),
                  surfaceTintColor: Colors.transparent,
                  title: Text(
                    status.toLowerCase().contains('download')
                        ? 'Downloading...'
                        : 'Uploading...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      progress < 0
                          ? const LinearProgressIndicator(
                              color: Color(0xFF00ADB5),
                              backgroundColor: Colors.black26,
                            )
                          : Column(
                              children: [
                                LinearProgressIndicator(
                                  value: progress,
                                  color: const Color(0xFF00ADB5),
                                  backgroundColor: Colors.black26,
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                      const SizedBox(height: 16),
                      Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        logic.cancelTransfer();
                        Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );

    final success = await action();
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (context.mounted) {
      if (success) {
        context.showSuccessToast(
          context.tr('file_transfer_completed'),
          actionLabel: destinationDirectory != null
              ? context.tr('open_folder')
              : null,
          onAction: destinationDirectory != null
              ? () {
                  unawaited(
                    Process.run('explorer.exe', [
                      destinationDirectory,
                    ]).then<void>((_) {}, onError: (Object _, StackTrace _) {}),
                  );
                }
              : null,
        );
      } else {
        context.showErrorToast(context.tr('file_transfer_failed'));
      }
    }
  }
}

class FolderSyncTab extends StatefulWidget {
  const FolderSyncTab({super.key});

  @override
  State<FolderSyncTab> createState() => _FolderSyncTabState();
}

class _FolderSyncTabState extends State<FolderSyncTab> {
  final TextEditingController _pcPathController = TextEditingController();
  final TextEditingController _androidPathController = TextEditingController();
  String direction = 'pcToAndroid';
  bool deleteExtra = false;
  bool autoSync = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final logic = Provider.of<AppLogic>(context, listen: false);
    _pcPathController.text = logic.lastSyncPcPath;
    _androidPathController.text = logic.lastSyncAndroidPath.isNotEmpty
        ? logic.lastSyncAndroidPath
        : '/sdcard';
    direction = logic.lastSyncDirection;
    deleteExtra = logic.lastSyncDeleteExtra;
    autoSync = logic.lastSyncAutoSync;

    logic.addListener(_onLogicChange);
  }

  void _onLogicChange() {
    final logic = Provider.of<AppLogic>(context, listen: false);
    if (!logic.isSyncing) {
      if (_pcPathController.text != logic.lastSyncPcPath) {
        _pcPathController.text = logic.lastSyncPcPath;
      }
      if (_androidPathController.text != logic.lastSyncAndroidPath) {
        _androidPathController.text = logic.lastSyncAndroidPath;
      }
      if (direction != logic.lastSyncDirection) {
        setState(() {
          direction = logic.lastSyncDirection;
        });
      }
      if (deleteExtra != logic.lastSyncDeleteExtra) {
        setState(() {
          deleteExtra = logic.lastSyncDeleteExtra;
        });
      }
    }
    if (autoSync != logic.lastSyncAutoSync) {
      setState(() {
        autoSync = logic.lastSyncAutoSync;
      });
    }
    if (logic.isSyncing) {
      _scrollToLogBottom();
    }
  }

  @override
  void dispose() {
    final logic = Provider.of<AppLogic>(context, listen: false);
    logic.removeListener(_onLogicChange);
    _pcPathController.dispose();
    _androidPathController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveCurrentSettings(AppLogic logic) {
    logic.saveSyncSettings(
      pcPath: _pcPathController.text,
      androidPath: _androidPathController.text,
      direction: direction,
      deleteExtra: deleteExtra,
      autoSync: autoSync,
    );
  }

  String _getBasename(String path) {
    if (path.isEmpty) return '';
    final separator = path.contains('/') ? '/' : '\\';
    return path.split(separator).last;
  }

  void _cancelSync(AppLogic logic) {
    logic.cancelSyncFolder();
  }

  Future<void> _startSync(AppLogic logic) async {
    final pc = _pcPathController.text.trim();
    final android = _androidPathController.text.trim();

    if (pc.isEmpty) {
      context.showErrorToast(context.tr('error_select_pc_folder'));
      return;
    }

    final preview = await logic.previewFolderSync(
      pcPath: pc,
      androidPath: android,
      direction: direction,
      deleteExtra: deleteExtra,
    );
    if (!mounted) return;
    if (!preview.isSuccess) {
      context.showErrorToast(
        preview.error ?? context.tr('sync_preview_failed'),
      );
      return;
    }

    final confirmed = await _confirmSyncPreview(preview);
    if (!mounted || !confirmed) return;

    _saveCurrentSettings(logic);
    logic.startSyncFolder(
      pcPath: pc,
      androidPath: android,
      direction: direction,
      deleteExtra: deleteExtra,
      confirmedDestructive: deleteExtra,
      expectedDeletePaths: preview.deleteActions
          .map((action) => action.file.absolutePath)
          .toSet(),
    );
  }

  Future<bool> _confirmSyncPreview(AdbSyncPreview preview) async {
    final confirmationController = TextEditingController();
    final requiresTypedConfirmation = preview.deleteCount > 0;
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final logic = Provider.of<AppLogic>(context, listen: false);

    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return GlassDialog(
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    final confirmationMatches =
                        !requiresTypedConfirmation ||
                        confirmationController.text.trim() == 'DELETE';
                    return AlertDialog(
                      backgroundColor: glassDialogBackground(
                        theme: theme,
                        opacity: logic.dialogOpacity,
                      ),
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.borderTheme),
                      ),
                      title: Row(
                        children: [
                          Icon(
                            requiresTypedConfirmation
                                ? Icons.warning_amber_rounded
                                : Icons.fact_check_outlined,
                            color: requiresTypedConfirmation
                                ? Colors.amber
                                : const Color(0xFF00ADB5),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr('sync_preview_title'),
                            style: TextStyle(color: theme.textPrimary),
                          ),
                        ],
                      ),
                      content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr(
                                  'sync_scanned',
                                  args: {
                                    'pc': preview.pcFileCount.toString(),
                                    'android': preview.androidFileCount
                                        .toString(),
                                  },
                                ),
                                style: TextStyle(color: theme.textSecondary),
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _previewCountChip(
                                    icon: Icons.copy_outlined,
                                    label: context.tr(
                                      'sync_copy_count',
                                      args: {
                                        'count': preview.copyCount.toString(),
                                      },
                                    ),
                                    color: const Color(0xFF00ADB5),
                                  ),
                                  _previewCountChip(
                                    icon: Icons.delete_outline,
                                    label: context.tr(
                                      'sync_delete_count',
                                      args: {
                                        'count': preview.deleteCount.toString(),
                                      },
                                    ),
                                    color: preview.deleteCount > 0
                                        ? Colors.redAccent
                                        : theme.textSecondary,
                                  ),
                                ],
                              ),
                              if (requiresTypedConfirmation) ...[
                                const SizedBox(height: 18),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('files_to_delete'),
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...preview.deleteActions
                                          .take(5)
                                          .map(
                                            (action) => Text(
                                              '• ${action.file.relativePath}',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: theme.textPrimary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      if (preview.deleteCount > 5)
                                        Text(
                                          context.tr(
                                            'sync_more_files',
                                            args: {
                                              'count': (preview.deleteCount - 5)
                                                  .toString(),
                                            },
                                          ),
                                          style: TextStyle(
                                            color: theme.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: confirmationController,
                                  autofocus: true,
                                  onChanged: (_) => setDialogState(() {}),
                                  style: TextStyle(color: theme.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: context.tr(
                                      'confirm_delete_hint',
                                    ),
                                    labelStyle: TextStyle(
                                      color: theme.textSecondary,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: theme.borderTheme,
                                      ),
                                    ),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(
                            context.tr('cancel'),
                            style: TextStyle(color: theme.textSecondary),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: confirmationMatches
                              ? () => Navigator.of(dialogContext).pop(true)
                              : null,
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text(context.tr('start_sync_btn')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: requiresTypedConfirmation
                                ? Colors.redAccent
                                : const Color(0xFF00ADB5),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ) ??
          false;
    } finally {
      confirmationController.dispose();
    }
  }

  Widget _previewCountChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  void _scrollToLogBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final logic = Provider.of<AppLogic>(context);
    final isSyncing = logic.isSyncing;
    final progress = logic.syncProgress;
    final statusText = logic.syncStatusText;
    final syncLog = logic.syncLog;
    final isFinished =
        !isSyncing &&
        (statusText == 'Completed' ||
            statusText == 'Error' ||
            statusText == 'Cancelled');

    if (logic.selectedDevice == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sync_disabled,
              size: 64,
              color: theme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('no_device_connected'),
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('select_device'),
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual Sync Pathway Banner
          _buildPathwayHeader(theme),
          const SizedBox(height: 14),

          // Main 2-column layout (flex: 6 vs flex: 6)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Column: Configuration & Recent Syncs (flex: 6)
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Configuration Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.borderTheme),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.tune_rounded,
                                  size: 16,
                                  color: Color(0xFF00ADB5),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  context.tr('sync_folders_title'),
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // PC Folder input
                            Text(
                              context.tr('pc_folder_label'),
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _pcPathController,
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 12,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: context.tr(
                                          'select_pc_folder_hint',
                                        ),
                                        hintStyle: TextStyle(
                                          color: theme.textSecondary.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 12,
                                        ),
                                        filled: true,
                                        fillColor: theme.subCardBg,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 0,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: theme.borderTheme,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF00ADB5),
                                          ),
                                        ),
                                      ),
                                      enabled: !isSyncing,
                                      onChanged: (_) =>
                                          _saveCurrentSettings(logic),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 38,
                                  width: 38,
                                  child: IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme.subCardBg,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: theme.borderTheme,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: const Icon(
                                      Icons.folder_open_rounded,
                                      color: Color(0xFF00ADB5),
                                      size: 18,
                                    ),
                                    tooltip: context.tr('browse_pc_folder'),
                                    onPressed: isSyncing
                                        ? null
                                        : () async {
                                            final path =
                                                await FilePicker.getDirectoryPath();
                                            if (path != null) {
                                              _pcPathController.text = path;
                                              _saveCurrentSettings(logic);
                                            }
                                          },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Android Folder input
                            Text(
                              context.tr('android_folder_label'),
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 38,
                                    child: TextField(
                                      controller: _androidPathController,
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 12,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '/sdcard/...',
                                        hintStyle: TextStyle(
                                          color: theme.textSecondary.withValues(
                                            alpha: 0.5,
                                          ),
                                          fontSize: 12,
                                        ),
                                        filled: true,
                                        fillColor: theme.subCardBg,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 0,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: theme.borderTheme,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF00ADB5),
                                          ),
                                        ),
                                      ),
                                      enabled: !isSyncing,
                                      onChanged: (_) =>
                                          _saveCurrentSettings(logic),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 38,
                                  width: 38,
                                  child: IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme.subCardBg,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(
                                          color: theme.borderTheme,
                                        ),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    icon: const Icon(
                                      Icons.get_app_rounded,
                                      color: Color(0xFF00ADB5),
                                      size: 18,
                                    ),
                                    tooltip: context.tr(
                                      'get_current_folder_btn',
                                    ),
                                    onPressed: isSyncing
                                        ? null
                                        : () {
                                            _androidPathController.text =
                                                logic.androidCurrentPath;
                                            _saveCurrentSettings(logic);
                                          },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Direction & Options Row
                            Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('sync_direction_label'),
                                        style: TextStyle(
                                          color: theme.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        height: 38,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.subCardBg,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: theme.borderTheme,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            value: direction,
                                            dropdownColor: theme.dropdownBg,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            style: TextStyle(
                                              color: theme.textPrimary,
                                              fontSize: 12,
                                            ),
                                            items: [
                                              DropdownMenuItem(
                                                value: 'pcToAndroid',
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 14,
                                                      color: Color(0xFF00ADB5),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      context.tr(
                                                        'sync_direction_pc_to_android',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'androidToPc',
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.arrow_back_rounded,
                                                      size: 14,
                                                      color: Color(0xFF7C5CFC),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      context.tr(
                                                        'sync_direction_android_to_pc',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'syncNewest',
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.sync_alt_rounded,
                                                      size: 14,
                                                      color: Color(0xFFF59E0B),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      context.tr(
                                                        'sync_direction_newest',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            onChanged: isSyncing
                                                ? null
                                                : (val) {
                                                    if (val != null) {
                                                      setState(() {
                                                        direction = val;
                                                      });
                                                      _saveCurrentSettings(
                                                        logic,
                                                      );
                                                    }
                                                  },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: Checkbox(
                                              value: deleteExtra,
                                              activeColor: Colors.redAccent,
                                              onChanged: isSyncing
                                                  ? null
                                                  : (val) {
                                                      if (val != null) {
                                                        setState(() {
                                                          deleteExtra = val;
                                                          if (val) {
                                                            autoSync = false;
                                                          }
                                                        });
                                                        _saveCurrentSettings(
                                                          logic,
                                                        );
                                                      }
                                                    },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              context.tr(
                                                'delete_extra_files_label',
                                              ),
                                              style: TextStyle(
                                                color: deleteExtra
                                                    ? Colors.redAccent
                                                    : theme.textPrimary,
                                                fontSize: 11,
                                                fontWeight: deleteExtra
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Action Button (Start / Pause / Cancel)
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: isSyncing
                                  ? Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: logic.isSyncPaused
                                                ? logic.resumeSyncFolder
                                                : logic.pauseSyncFolder,
                                            icon: Icon(
                                              logic.isSyncPaused
                                                  ? Icons.play_arrow_rounded
                                                  : Icons.pause_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              logic.isSyncPaused
                                                  ? context.tr(
                                                      'resume_sync_btn',
                                                    )
                                                  : context.tr(
                                                      'pause_sync_btn',
                                                    ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _cancelSync(logic),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                            ),
                                            label: Text(
                                              context.tr('cancel'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.redAccent,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: () => _startSync(logic),
                                      icon: const Icon(
                                        Icons.sync_rounded,
                                        size: 18,
                                      ),
                                      label: Text(
                                        context.tr('start_sync_btn'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF00ADB5,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Recent Configurations Card
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.borderTheme),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                    color: Color(0xFF00ADB5),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.tr('recent_sync_title'),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (logic.syncHistory.isNotEmpty &&
                                      !isSyncing)
                                    InkWell(
                                      onTap: () => logic.clearSyncHistory(),
                                      borderRadius: BorderRadius.circular(4),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          context.tr('clear_history_btn'),
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: logic.syncHistory.isEmpty
                                    ? Center(
                                        child: Text(
                                          context.tr('sync_history_empty'),
                                          style: TextStyle(
                                            color: theme.textSecondary
                                                .withValues(alpha: 0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: logic.syncHistory.length,
                                        separatorBuilder: (_, _) =>
                                            const SizedBox(height: 4),
                                        itemBuilder: (context, index) {
                                          final item = logic.syncHistory[index];
                                          final parts = item.split('|');
                                          if (parts.length < 4) {
                                            return const SizedBox.shrink();
                                          }
                                          final histPc = parts[0];
                                          final histAndroid = parts[1];
                                          final histDir = parts[2];
                                          final histDelExtra = parts[3] == '1';

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.subCardBg,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: theme.borderTheme
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '${_getBasename(histPc)} ↔ ${_getBasename(histAndroid)}',
                                                        style: TextStyle(
                                                          color:
                                                              theme.textPrimary,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        context.tr(
                                                          'sync_history_summary',
                                                          args: {
                                                            'direction':
                                                                histDir ==
                                                                    'pcToAndroid'
                                                                ? 'PC→Android'
                                                                : histDir ==
                                                                      'androidToPc'
                                                                ? 'Android→PC'
                                                                : context.tr(
                                                                    'two_way_newest',
                                                                  ),
                                                            'mirror': context.tr(
                                                              histDelExtra
                                                                  ? 'yes_label'
                                                                  : 'no_label',
                                                            ),
                                                          },
                                                        ),
                                                        style: TextStyle(
                                                          color: theme
                                                              .textSecondary
                                                              .withValues(
                                                                alpha: 0.7,
                                                              ),
                                                          fontSize: 10,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (!isSyncing)
                                                  IconButton(
                                                    tooltip: context.tr(
                                                      'restore_configuration',
                                                    ),
                                                    icon: const Icon(
                                                      Icons.replay_rounded,
                                                      size: 16,
                                                      color: Color(0xFF00ADB5),
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _pcPathController.text =
                                                            histPc;
                                                        _androidPathController
                                                                .text =
                                                            histAndroid;
                                                        direction = histDir;
                                                        deleteExtra =
                                                            histDelExtra;
                                                      });
                                                      _saveCurrentSettings(
                                                        logic,
                                                      );
                                                    },
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Right Column: Sync Guide (when idle) OR Console Terminal (when active)
                Expanded(
                  flex: 6,
                  child: (!isSyncing && syncLog.isEmpty)
                      ? _buildSyncGuide(context, theme)
                      : _buildSyncTerminal(
                          context,
                          theme,
                          logic,
                          isSyncing,
                          progress,
                          statusText,
                          syncLog,
                          isFinished,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathwayHeader(ThemeProvider theme) {
    final pcName = _getBasename(_pcPathController.text);
    final androidName = _getBasename(_androidPathController.text);

    IconData arrowIcon = Icons.arrow_forward_rounded;
    Color arrowColor = const Color(0xFF00ADB5);
    String arrowLabel = 'PC ➔ Android';
    if (direction == 'androidToPc') {
      arrowIcon = Icons.arrow_back_rounded;
      arrowColor = const Color(0xFF7C5CFC);
      arrowLabel = 'Android ➔ PC';
    } else if (direction == 'syncNewest') {
      arrowIcon = Icons.sync_alt_rounded;
      arrowColor = const Color(0xFFF59E0B);
      arrowLabel = context.tr('two_way_newest');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Row(
        children: [
          // PC Endpoint
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00ADB5).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.computer_rounded,
              size: 18,
              color: Color(0xFF00ADB5),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('sync_pc_target'),
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  pcName.isEmpty ? context.tr('select_pc_directory') : pcName,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Pathway Connection Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: arrowColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: arrowColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(arrowIcon, size: 14, color: arrowColor),
                const SizedBox(width: 6),
                Text(
                  arrowLabel,
                  style: TextStyle(
                    color: arrowColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Android Endpoint
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  context.tr('sync_android_target'),
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  androidName.isEmpty ? '/sdcard' : androidName,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C5CFC).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.phone_android_rounded,
              size: 18,
              color: Color(0xFF7C5CFC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncGuide(BuildContext context, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF00ADB5).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  size: 20,
                  color: Color(0xFF00ADB5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('sync_overview_title'),
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      context.tr('sync_overview_desc'),
                      style: TextStyle(
                        color: theme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: [
                _buildSyncTipTile(
                  theme: theme,
                  icon: Icons.speed_rounded,
                  color: const Color(0xFF00ADB5),
                  title: context.tr('delta_sync_title'),
                  desc: context.tr('delta_sync_hint'),
                ),
                const SizedBox(height: 10),
                _buildSyncTipTile(
                  theme: theme,
                  icon: Icons.shield_outlined,
                  color: const Color(0xFF7C5CFC),
                  title: context.tr('dry_run_title'),
                  desc: context.tr('dry_run_hint'),
                ),
                const SizedBox(height: 10),
                _buildSyncTipTile(
                  theme: theme,
                  icon: Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  title: context.tr('mirror_mode_title'),
                  desc: context.tr('sync_mirror_notice'),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.subCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.borderTheme),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF00ADB5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('sync_ready_idle'),
                    style: TextStyle(color: theme.textSecondary, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncTipTile({
    required ThemeProvider theme,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.subCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderTheme.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    color: theme.textSecondary.withValues(alpha: 0.75),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncTerminal(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
    bool isSyncing,
    double progress,
    String statusText,
    String syncLog,
    bool isFinished,
  ) {
    final statusParts = statusText.split(' • ');
    final statusKey = const {
      'Starting...': 'sync_starting',
      'Scanning...': 'sync_scanning',
      'Comparing...': 'sync_comparing',
      'Syncing...': 'sync_running',
      'Completed': 'sync_completed',
      'Error': 'sync_error',
      'Cancelled': 'sync_cancelled',
      'Paused': 'sync_paused',
    }[statusParts.first];
    final displayStatus = statusText.isEmpty
        ? context.tr('sync_status_idle')
        : statusKey == null
        ? statusText
        : [context.tr(statusKey), ...statusParts.skip(1)].join(' • ');
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.terminal_rounded,
                      size: 16,
                      color: Color(0xFF00ADB5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('console_log'),
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (syncLog.isNotEmpty)
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: syncLog));
                          context.showSuccessToast(context.tr('log_copied'));
                        },
                        icon: const Icon(
                          Icons.copy,
                          size: 13,
                          color: Color(0xFF00ADB5),
                        ),
                        label: Text(
                          context.tr('copy_log_btn'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF00ADB5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        onPressed: () => logic.clearSyncLog(),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 13,
                          color: Colors.grey,
                        ),
                        label: Text(
                          context.tr('clear_log_btn'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Status & Progress
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.tr(
                        'sync_status_label',
                        args: {'status': displayStatus},
                      ),
                      style: TextStyle(
                        color: isFinished
                            ? Colors.tealAccent
                            : (isSyncing
                                  ? const Color(0xFF00ADB5)
                                  : theme.textSecondary),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isSyncing)
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Color(0xFF00ADB5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: isSyncing ? progress : 0.0,
                  backgroundColor: theme.isDark
                      ? Colors.black26
                      : const Color(0xFFE2E8F0),
                  color: const Color(0xFF00ADB5),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),

          // Terminal output
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.borderTheme),
              ),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      syncLog.isEmpty
                          ? '${context.tr('sync_waiting')}\n'
                          : syncLog,
                      style: TextStyle(
                        color: theme.isDark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF047857),
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
