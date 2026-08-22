// lib/modules/ui/main_window.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'styles.dart';
import 'dialogs.dart';
import 'command_palette_dialog.dart';
import 'device_workspace_dialog.dart';
import 'diagnostics_dialog.dart';
import 'localization.dart';
import 'wireless_adb_dialog.dart';
import 'settings_backup_dialog.dart';
import 'update_dialog.dart';
import 'plugin_dialog.dart';
import '../logic.dart';
import '../utils.dart';
import '../constants.dart';
import '../build_info.dart';
import '../services/scrcpy_profile_store.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _OpenCommandPaletteIntent extends Intent {
  const _OpenCommandPaletteIntent();
}

class _PingPongMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _PingPongMarquee({required this.text, required this.style});

  @override
  State<_PingPongMarquee> createState() => _PingPongMarqueeState();
}

class _PingPongMarqueeState extends State<_PingPongMarquee> {
  static const _holdDuration = Duration(milliseconds: 1200);
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runLoop());
  }

  Future<void> _runLoop() async {
    if (!mounted || !_scrollController.hasClients) return;
    await Future<void>.delayed(_holdDuration);
    if (!mounted || !_scrollController.hasClients) return;

    final maxScrollExtent = _scrollController.position.maxScrollExtent;
    if (maxScrollExtent <= 0) return;
    final travelMs = (widget.text.length * 70).clamp(1200, 5000);

    while (mounted) {
      await _scrollController.animateTo(
        maxScrollExtent,
        duration: Duration(milliseconds: travelMs),
        curve: Curves.linear,
      );
      if (!mounted) return;
      await Future<void>.delayed(_holdDuration);
      if (!mounted) return;
      await _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: travelMs),
        curve: Curves.linear,
      );
      if (!mounted) return;
      await Future<void>.delayed(_holdDuration);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
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
          return Dialog(
            backgroundColor: theme.cardBg,
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

  // Scrcpy options state
  bool _stayOnTop = false;
  bool _fullscreen = false;
  bool _noControl = false;
  bool _keepAwake = true;
  bool _borderless = false;
  bool _noAudio = true;
  String? _selectedScrcpyProfile;

  final GlobalKey _placeholderKey = GlobalKey();
  Timer? _positionUpdateTimer;
  // Cache last sent position to avoid redundant channel calls (reduces flicker)
  double _lastSentX = -1, _lastSentY = -1, _lastSentW = -1, _lastSentH = -1;
  int _forceUpdateTicks = 0;
  final TextEditingController _textInputController = TextEditingController();
  final TextEditingController _mediaCountController = TextEditingController();
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

  // File Explorer selection state
  final Set<String> _selectedFilePaths = {};
  String _lastExploredPath = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.addListener(_handleTabChange);
    _startPositionTimer();
  }

  @override
  void dispose() {
    _positionUpdateTimer?.cancel();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _textInputController.dispose();
    _mediaCountController.dispose();
    _appsSearchController.dispose();
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
    if (_tabController.index != 0) {
      _hideMirrorWindow();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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

    // Skip if position hasn't actually changed — avoids redundant channel calls
    if (_forceUpdateTicks <= 0 &&
        x == _lastSentX &&
        y == _lastSentY &&
        width == _lastSentW &&
        height == _lastSentH)
      return;

    if (_forceUpdateTicks > 0) {
      _forceUpdateTicks--;
    }

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
        .catchError((_) => null);
  }

  void _hideMirrorWindow() {
    // Reset cached position so next show always repositions correctly
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
    if (!mounted || name == null || name.trim().isEmpty) return;
    await logic.saveScrcpyProfile(
      ScrcpyProfile(
        name: name,
        stayOnTop: _stayOnTop,
        fullscreen: _fullscreen,
        noControl: _noControl,
        keepAwake: _keepAwake,
        borderless: _borderless,
        noAudio: _noAudio,
      ),
    );
    if (!mounted) return;
    setState(() => _selectedScrcpyProfile = name.trim());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('profile_saved'))));
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
        subtitle: context.tr('update_title'),
        icon: Icons.system_update_rounded,
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
          backgroundColor: theme.scaffoldBg,
          body: Row(
            children: [
              // 1. LEFT SIDEBAR
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color: theme.sidebarBg,
                  border: Border(
                    right: BorderSide(color: theme.borderTheme, width: 1),
                  ),
                ),
                child: Column(
                  children: [
                    // Top margin to avoid titlebar controls
                    const SizedBox(height: 36),

                    // Sidebar Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.adb,
                            color: Color(0xFF00ADB5),
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  appName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: theme.textPrimary,
                                    fontFamily: 'Outfit',
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Text(
                                  'v$appVersion',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.textSecondary.withOpacity(0.6),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                if (BuildInfo.isDebug) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: double.infinity,
                                    clipBehavior: Clip.hardEdge,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withValues(
                                        alpha: 0.16,
                                      ),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: Colors.amber.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    child: _PingPongMarquee(
                                      text:
                                          'DEBUG · v${BuildInfo.version} (${BuildInfo.debugTimestamp})',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: Colors.white10),

                    // Devices List Section
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 10,
                        top: 16,
                        bottom: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              context.tr('device_info').toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.textSecondary.withOpacity(0.7),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (_) => const WirelessAdbDialog(),
                                  );
                                },
                                icon: const Icon(Icons.wifi_rounded, size: 18),
                                color: theme.textSecondary,
                                tooltip: context.tr('wireless_adb'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 30,
                                  height: 30,
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
                                icon: const Icon(
                                  Icons.health_and_safety_rounded,
                                  size: 18,
                                ),
                                color: theme.textSecondary,
                                tooltip: context.tr('diagnostics'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 30,
                                  height: 30,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (_) =>
                                        const DeviceWorkspaceDialog(),
                                  );
                                },
                                icon: const Icon(
                                  Icons.workspaces_rounded,
                                  size: 18,
                                ),
                                color: theme.textSecondary,
                                tooltip: context.tr('workspace'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 30,
                                  height: 30,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: () => logic.scanDevices(),
                                icon: Icon(
                                  Icons.refresh,
                                  color: logic.isSearchingDevices
                                      ? const Color(0xFF00ADB5)
                                      : theme.textSecondary,
                                  size: 18,
                                ),
                                tooltip: context.tr('refresh_devices'),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 30,
                                  height: 30,
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: logic.connectedDevices.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_android,
                                    size: 40,
                                    color: theme.textSecondary.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('no_device_connected'),
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    context.tr('no_devices_found'),
                                    style: TextStyle(
                                      color: theme.textSecondary.withOpacity(
                                        0.6,
                                      ),
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              itemCount: logic.connectedDevices.length,
                              itemBuilder: (context, index) {
                                final dev = logic.connectedDevices[index];
                                final details = logic.devicesDetails[dev];

                                final isSelected = logic.selectedDevice == dev;
                                final model =
                                    details?['model'] ?? 'Android Device';
                                final version =
                                    details?['version'] ?? 'Unknown';

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  child: InkWell(
                                    onTap: () => logic.selectDevice(dev),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(
                                                0xFF00ADB5,
                                              ).withOpacity(0.15)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? const Color(
                                                  0xFF00ADB5,
                                                ).withOpacity(0.4)
                                              : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.phone_android,
                                            color: isSelected
                                                ? const Color(0xFF00ADB5)
                                                : theme.textSecondary,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  model,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal,
                                                    color: theme.textPrimary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '$dev • Android $version',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: theme.textSecondary
                                                        .withOpacity(0.7),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    const Divider(height: 1, color: Colors.white10),

                    // Bottom Tools (Theme, Language, Settings in one row)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 1. Settings (Paths) Button
                          IconButton(
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (context) =>
                                    const PathsSettingsDialog(),
                              );
                            },
                            icon: const Icon(Icons.settings, size: 20),
                            color: theme.textSecondary,
                            tooltip: context.tr('settings_tab'),
                          ),

                          // 2. Language Button
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
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.textSecondary.withOpacity(
                                          0.3,
                                        ),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      flag,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: theme.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // 3. Theme Toggle Button
                          IconButton(
                            onPressed: () => theme.toggleTheme(),
                            icon: Icon(
                              theme.isDark ? Icons.light_mode : Icons.dark_mode,
                              size: 20,
                            ),
                            color: theme.textSecondary,
                            tooltip: theme.isDark ? 'Light Mode' : 'Dark Mode',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. MAIN CONTENT AREA
              Expanded(
                child: Container(
                  color: theme.mainBg,
                  child: Column(
                    children: [
                      const SizedBox(height: 36),

                      // Verification Banners
                      if (logic.adbPath.isEmpty || logic.scrcpyPath.isEmpty)
                        Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'ADB or Scrcpy paths are not configured yet. Auto-detecting, or configure them manually in Settings.',
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => logic.autoDetectPaths(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber,
                                  foregroundColor: Colors.black87,
                                ),
                                child: Text(context.tr('default_search_btn')),
                              ),
                            ],
                          ),
                        ),

                      if (logic.selectedDevice == null)
                        Expanded(
                          child: _buildNoDevicePlaceholder(context, theme),
                        )
                      else ...[
                        // Tab Bar Headers
                        TabBar(
                          controller: _tabController,
                          isScrollable: false,
                          labelColor: const Color(0xFF00ADB5),
                          unselectedLabelColor: theme.textSecondary,
                          indicatorColor: const Color(0xFF00ADB5),
                          dividerColor: Colors.white10,
                          tabs: [
                            Tab(
                              text: context.tr('scrcpy_tab'),
                              icon: const Icon(Icons.screenshot, size: 20),
                            ),
                            Tab(
                              text: context.tr('file_explorer_tab'),
                              icon: const Icon(Icons.folder_shared, size: 20),
                            ),
                            Tab(
                              text: context.tr('sync_folders_btn'),
                              icon: const Icon(Icons.sync, size: 20),
                            ),
                            Tab(
                              text: context.tr('latest_media_tab'),
                              icon: const Icon(Icons.photo_library, size: 20),
                            ),
                            Tab(
                              text: context.tr('installer_tab'),
                              icon: const Icon(Icons.system_update, size: 20),
                            ),
                            Tab(
                              text: context.tr('app_freeze_tab'),
                              icon: const Icon(Icons.apps, size: 20),
                            ),
                            Tab(
                              text: context.tr('quick_tools_tab'),
                              icon: const Icon(Icons.bolt, size: 20),
                            ),
                          ],
                        ),

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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              // Left control panel
              SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('scrcpy_options'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value:
                                  logic.scrcpyProfiles.any(
                                    (profile) =>
                                        profile.name == _selectedScrcpyProfile,
                                  )
                                  ? _selectedScrcpyProfile
                                  : null,
                              isExpanded: true,
                              dropdownColor: theme.cardBg,
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
                                    : (v) =>
                                          setState(() => _noAudio = v ?? false),
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
                            onPressed: () async {
                              if (logic.isMirroring) {
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
                                  getTargetRect: () {
                                    final keyContext =
                                        _placeholderKey.currentContext;
                                    if (keyContext == null) return {};
                                    final renderBox =
                                        keyContext.findRenderObject()
                                            as RenderBox?;
                                    if (renderBox == null || !renderBox.hasSize)
                                      return {};
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
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Failed to launch Screen Mirror. Check Scrcpy path.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(
                              logic.isMirroring ? Icons.stop : Icons.play_arrow,
                              size: 20,
                            ),
                            label: Text(
                              logic.isMirroring
                                  ? context.tr('stop_mirror')
                                  : context.tr('launch_mirror'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: logic.isMirroring
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
                            onPressed: () async {
                              final ok = await logic.launchStandaloneMirroring(
                                stayOnTop: _stayOnTop,
                                fullscreen: _fullscreen,
                                noControl: _noControl,
                                keepAwake: _keepAwake,
                                borderless: _borderless,
                                noAudio: _noAudio,
                              );
                              if (!context.mounted) return;
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Failed to launch standalone mirror. Check Scrcpy path.',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_new, size: 20),
                            label: Text(
                              context.tr('launch_standalone_mirror'),
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
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.tr('no_device_connected'),
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    scaffoldMessenger.showSnackBar(
                                      const SnackBar(
                                        content: Row(
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text('Taking screenshot...'),
                                          ],
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    final path = await logic.takeScreenshot();
                                    if (path != null) {
                                      scaffoldMessenger.hideCurrentSnackBar();
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Screenshot saved to $path',
                                          ),
                                          action: SnackBarAction(
                                            label: 'Open',
                                            onPressed: () {
                                              unawaited(
                                                Process.run('explorer.exe', [
                                                  '/select,',
                                                  path,
                                                ]).then<void>(
                                                  (_) {},
                                                  onError:
                                                      (
                                                        Object _,
                                                        StackTrace __,
                                                      ) {},
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    } else {
                                      scaffoldMessenger.hideCurrentSnackBar();
                                      scaffoldMessenger.showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Failed to take screenshot.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.camera_alt, size: 20),
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
                                tooltip: context.tr('select_screenshot_folder'),
                                onPressed: () async {
                                  final dir =
                                      await FilePicker.getDirectoryPath();
                                  if (dir != null) {
                                    await logic.saveScreenshotDir(dir);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Screenshot folder set to: $dir',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Right side: Screen Mirror container placeholder
              Expanded(
                child: Container(
                  key: _placeholderKey,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.borderTheme, width: 1.5),
                  ),
                  child: logic.isMirroring
                      ? const SizedBox.expand()
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.phone_android,
                                  size: 48,
                                  color: theme.textSecondary.withOpacity(0.4),
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
                                  color: theme.textSecondary.withOpacity(0.7),
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
                                  color: theme.textSecondary.withOpacity(0.4),
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
    return Column(
      children: [
        // Path navigation bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.cardBg,
            border: Border(bottom: BorderSide(color: theme.borderTheme)),
          ),
          child: Row(
            children: [
              // Select All Checkbox
              Checkbox(
                value:
                    _selectedFilePaths.isNotEmpty &&
                    _selectedFilePaths.length == logic.androidFiles.length,
                tristate:
                    _selectedFilePaths.isNotEmpty &&
                    _selectedFilePaths.length < logic.androidFiles.length,
                activeColor: const Color(0xFF00ADB5),
                onChanged: logic.isAndroidLoading || logic.androidFiles.isEmpty
                    ? null
                    : (val) {
                        setState(() {
                          if (val == true) {
                            _selectedFilePaths.addAll(
                              logic.androidFiles.map((f) => f.path),
                            );
                          } else {
                            _selectedFilePaths.clear();
                          }
                        });
                      },
              ),
              const SizedBox(width: 4),
              // Up directory button
              IconButton(
                icon: Icon(Icons.arrow_upward, color: theme.textPrimary),
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
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        logic.androidCurrentPath,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_selectedFilePaths.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${_selectedFilePaths.length} selected)',
                        style: const TextStyle(
                          color: Color(0xFF00ADB5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_selectedFilePaths.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.download, color: Color(0xFF00ADB5)),
                  tooltip: 'Download Selected',
                  onPressed: () async {
                    final dir = await FilePicker.getDirectoryPath();
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
                      });
                      setState(() {
                        _selectedFilePaths.clear();
                      });
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Delete Selected',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => ConfirmDeleteDialog(
                        itemName: '${_selectedFilePaths.length} items',
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              allOk
                                  ? 'Deleted selected items successfully!'
                                  : 'Failed to delete some items.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(width: 8),
                Container(
                  height: 20,
                  width: 1,
                  color: theme.textSecondary.withOpacity(0.3),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: Icon(Icons.create_new_folder, color: theme.textPrimary),
                tooltip: context.tr('new_folder'),
                onPressed: () async {
                  final name = await showDialog<String>(
                    context: context,
                    builder: (context) => const CreateFolderDialog(),
                  );
                  if (name != null) {
                    final ok = await logic.createAndroidFolder(name);
                    if (mounted && !ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to create directory'),
                        ),
                      );
                    }
                  }
                },
              ),
              IconButton(
                icon: Icon(Icons.upload_file, color: theme.textPrimary),
                tooltip: context.tr('upload_files'),
                onPressed: () async {
                  final result = await FilePicker.pickFiles(
                    allowMultiple: true,
                  );
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
                icon: Icon(Icons.refresh, color: theme.textPrimary),
                onPressed: () =>
                    logic.loadAndroidDirectory(logic.androidCurrentPath),
              ),
            ],
          ),
        ),

        // File List
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
                        Icons.error_outline,
                        size: 48,
                        color: Colors.redAccent.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Error: ${logic.androidExplorerError}',
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => logic.loadAndroidDirectory(
                          logic.androidCurrentPath,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: logic.androidFiles.length,
                  itemBuilder: (context, index) {
                    final file = logic.androidFiles[index];
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.borderTheme,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _selectedFilePaths.contains(file.path),
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
                            Icon(
                              file.isDirectory
                                  ? Icons.folder
                                  : Icons.insert_drive_file,
                              color: file.isDirectory
                                  ? const Color(0xFF00ADB5)
                                  : theme.textSecondary,
                            ),
                          ],
                        ),
                        title: Text(
                          file.name,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          file.isDirectory
                              ? file.dateModified
                              : '${Utils.formatBytes(file.size)} • ${file.dateModified}',
                          style: TextStyle(
                            color: theme.textSecondary.withOpacity(0.7),
                            fontSize: 11,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Download pull button
                            IconButton(
                              icon: Icon(
                                Icons.download,
                                color: theme.textSecondary,
                                size: 20,
                              ),
                              tooltip: context.tr('download_selected'),
                              onPressed: () async {
                                final dir = await FilePicker.getDirectoryPath();
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
                                  );
                                }
                              },
                            ),
                            // Delete button
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: context.tr('delete_selected'),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) =>
                                      ConfirmDeleteDialog(itemName: file.name),
                                );
                                if (confirm == true) {
                                  final ok = await logic.deleteAndroidFile(
                                    file.path,
                                    file.isDirectory,
                                  );
                                  if (mounted && !ok) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to delete item.'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                        onTap: file.isDirectory
                            ? () => logic.loadAndroidDirectory(file.path)
                            : null,
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
              Row(
                children: [
                  Checkbox(
                    value:
                        logic.latestMedia.isNotEmpty &&
                        logic.selectedMediaPaths.length ==
                            logic.latestMedia.length,
                    tristate:
                        logic.selectedMediaPaths.isNotEmpty &&
                        logic.selectedMediaPaths.length <
                            logic.latestMedia.length,
                    activeColor: const Color(0xFF00ADB5),
                    onChanged: (v) {
                      logic.selectAllMedia(v ?? false);
                      _mediaCountController.clear();
                    },
                  ),
                  Text(
                    context.tr(
                      'selected_count',
                      args: {
                        'count': logic.selectedMediaPaths.length.toString(),
                      },
                    ),
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    context.tr('select_latest'),
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    height: 28,
                    child: TextField(
                      controller: _mediaCountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 0,
                        ),
                        filled: true,
                        fillColor: theme.mainBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
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
                        logic.selectLatestNMedia(parsed);
                      },
                    ),
                  ),
                ],
              ),
              Row(
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
                              if (!await targetDir.exists()) {
                                await targetDir.create(recursive: true);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to create target directory: $e',
                                    ),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Successfully downloaded ${logic.selectedMediaPaths.length} files to $dirPath'
                                        : 'Copy completed with warnings. Checked folder: $dirPath',
                                  ),
                                  duration: const Duration(seconds: 7),
                                  action: SnackBarAction(
                                    label: 'Open Folder',
                                    onPressed: () {
                                      unawaited(
                                        Process.run('explorer.exe', [
                                          dirPath,
                                        ]).then<void>(
                                          (_) {},
                                          onError: (Object _, StackTrace __) {},
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.copy, size: 16),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Media download folder set to: $dir',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.refresh, color: theme.textPrimary),
                    onPressed: () => logic.fetchLatestMedia(),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List Grid View of files
        Expanded(
          child: logic.isMediaLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00ADB5)),
                )
              : logic.latestMedia.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: theme.textSecondary.withOpacity(0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('no_media_found'),
                        style: TextStyle(color: theme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => logic.fetchLatestMedia(),
                        child: const Text('Scan Media Store'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: logic.latestMedia.length,
                  itemBuilder: (context, index) {
                    final media = logic.latestMedia[index];
                    final isSelected = logic.selectedMediaPaths.contains(
                      media.path,
                    );
                    final dateStr = DateTime.fromMillisecondsSinceEpoch(
                      media.dateAdded * 1000,
                    ).toLocal().toString().substring(0, 16);

                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.borderTheme,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (_) {
                          logic.toggleMediaSelection(media.path);
                          _mediaCountController.clear();
                        },
                        activeColor: const Color(0xFF00ADB5),
                        title: Row(
                          children: [
                            Icon(
                              media.isVideo ? Icons.movie : Icons.image,
                              color: media.isVideo
                                  ? Colors.amber
                                  : const Color(0xFF00ADB5),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                media.name,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(left: 32.0),
                          child: Text(
                            '$dateStr\n${media.path}',
                            style: TextStyle(
                              color: theme.textSecondary.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                        ),
                        secondary: TextButton(
                          child: const Text('Preview & Open'),
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
                                // Open file on PC
                                await Process.run('explorer.exe', [
                                  localFile.path,
                                ]);
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag and drop / file selector
          InkWell(
            onTap: () async {
              final result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['apk', 'xapk'],
              );
              if (result != null && result.files.single.path != null) {
                logic.selectInstallerFile(result.files.single.path!);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00ADB5).withOpacity(0.4),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_upload_outlined,
                    size: 40,
                    color: Color(0xFF00ADB5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    logic.installerFilePath != null
                        ? logic.installerFilePath!.split('\\').last
                        : context.tr('drag_drop_apk_xapk'),
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (logic.installerFilePath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        context.tr(
                          'current_path',
                          args: {'path': logic.installerFilePath!},
                        ),
                        style: TextStyle(
                          color: theme.textSecondary.withOpacity(0.5),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // App info card
          if (logic.installerAppDetails.isNotEmpty) ...[
            Card(
              color: theme.cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: theme.borderTheme),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('apk_details'),
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Name:',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          logic.installerAppDetails['name'] ?? '',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Type:',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          logic.installerAppDetails['type'] ?? '',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (logic.installerAppDetails.containsKey('packageName'))
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Package ID:',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            logic.installerAppDetails['packageName'] ?? '',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    if (logic.installerAppDetails.containsKey('version'))
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Version:',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            logic.installerAppDetails['version'] ?? '',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons & terminal logger
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.borderTheme),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Text.rich(
                  Utils.parseAnsi(
                    logic.installerLog,
                    TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: theme.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (logic.installerFilePath != null)
                TextButton(
                  onPressed: logic.isInstalling
                      ? null
                      : () => logic.clearInstaller(),
                  child: Text(
                    context.tr('cancel'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: logic.installerFilePath == null || logic.isInstalling
                    ? null
                    : () async {
                        final ok = await logic.installPackage();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'App installed successfully!'
                                    : 'Failed to install application.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.install_desktop, size: 18),
                label: Text(
                  logic.isInstalling
                      ? context.tr('installing')
                      : context.tr('install_button'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00ADB5),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: theme.borderTheme,
                ),
              ),
            ],
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
                      color: theme.textSecondary.withOpacity(0.5),
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
                color: theme.cardBg,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: theme.borderTheme),
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
                    ? theme.textSecondary.withOpacity(0.45)
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
                    style: TextStyle(
                      color: const Color(0xFF00ADB5),
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

        // Apps list
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
                        Icons.error_outline,
                        size: 48,
                        color: Colors.redAccent.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Error: ${logic.appsError}',
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
                        child: Text(
                          context.tr('default_search_btn'),
                        ), // Reuse or just 'Retry'
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
              : ListView.builder(
                  itemCount: filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = filteredApps[index];
                    final isSelected = _selectedAppPackages.contains(
                      app.packageName,
                    );
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.borderTheme,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
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
                                    _selectedAppPackages.add(app.packageName);
                                  }
                                });
                              },
                            ),
                            Icon(
                              Icons.android,
                              color: app.isFrozen
                                  ? theme.textSecondary.withOpacity(0.5)
                                  : const Color(0xFF00ADB5),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedAppPackages.remove(app.packageName);
                            } else {
                              _selectedAppPackages.add(app.packageName);
                            }
                          });
                        },
                        title: Text(
                          app.appName,
                          style: TextStyle(
                            color: app.isFrozen
                                ? theme.textSecondary
                                : theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.packageName,
                                style: TextStyle(
                                  color: theme.textSecondary.withOpacity(0.8),
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (app.isSystem)
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.orange.withOpacity(0.4),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: const Text(
                                        'SYSTEM',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: app.isFrozen
                                          ? Colors.red.withOpacity(0.15)
                                          : Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: app.isFrozen
                                            ? Colors.red.withOpacity(0.4)
                                            : Colors.green.withOpacity(0.4),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      app.isFrozen ? 'FROZEN' : 'ACTIVE',
                                      style: TextStyle(
                                        color: app.isFrozen
                                            ? Colors.redAccent
                                            : Colors.green,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (app.installTime != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Installed: ${app.installTime!.toLocal().toString().substring(0, 16)}',
                                      style: TextStyle(
                                        color: theme.textSecondary.withOpacity(
                                          0.6,
                                        ),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildFreezeActionButton(
                              context,
                              theme,
                              logic,
                              app,
                            ),
                            const SizedBox(width: 4),
                            _buildAppActionsMenu(context, theme, logic, app),
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

  Future<void> _showBatchActionPicker(
    BuildContext context,
    ThemeProvider theme,
    AppLogic logic,
  ) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: theme.cardBg,
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
        ],
      ),
    );
    if (!mounted || action == null) return;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            'batch_result',
            args: {
              'success': '${result.succeeded.length}',
              'failed': '${result.failed.length}',
            },
          ),
        ),
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
          backgroundColor: Colors.green.withOpacity(0.15),
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
          setState(() {
            _processingPackages.remove(app.packageName);
          });
          if (mounted && !ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to unfreeze ${app.packageName}')),
            );
          }
        },
      );
    } else {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00ADB5).withOpacity(0.15),
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
          setState(() {
            _processingPackages.remove(app.packageName);
          });
          if (mounted && !ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to freeze ${app.packageName}')),
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
      color: theme.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.borderTheme),
      ),
      onSelected: (action) async {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (action == 'launch') {
          final ok = await logic.launchApp(app.packageName);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? context.tr('launch_success', args: {'app': app.appName})
                    : context.tr('launch_failed', args: {'app': app.appName}),
              ),
            ),
          );
        } else if (action == 'force_stop') {
          final ok = await logic.forceStopApp(app.packageName);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? context.tr(
                        'force_stop_success',
                        args: {'app': app.appName},
                      )
                    : context.tr(
                        'force_stop_failed',
                        args: {'app': app.appName},
                      ),
              ),
            ),
          );
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
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? context.tr(
                          'clear_data_success',
                          args: {'app': app.appName},
                        )
                      : context.tr(
                          'clear_data_failed',
                          args: {'app': app.appName},
                        ),
                ),
              ),
            );
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
          if (confirm == true) {
            setState(() {
              _processingPackages.add(app.packageName);
            });
            final ok = await logic.uninstallApp(app.packageName);
            setState(() {
              _processingPackages.remove(app.packageName);
            });
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(
                  ok
                      ? context.tr(
                          'uninstall_success',
                          args: {'app': app.appName},
                        )
                      : context.tr(
                          'uninstall_failed',
                          args: {'app': app.appName},
                        ),
                ),
              ),
            );
          }
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
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            children: [
              _buildShortcutCard(
                icon: Icons.home,
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
                icon: Icons.lock,
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
                icon: Icons.language,
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
                icon: Icons.code,
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
                icon: Icons.wifi,
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
                icon: Icons.settings_display,
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
                icon: Icons.accessibility,
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
                icon: Icons.apps,
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
                icon: Icons.phone_android,
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
          ),
          const SizedBox(height: 32),

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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: theme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.borderTheme),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Custom Segmented Switcher for Sub-tabs
                          Container(
                            height: 40,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(10),
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
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.keyboard,
                                            size: 16,
                                            color: _quickToolSubTab == 0
                                                ? Colors.white
                                                : theme.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.tr('text_input_tab'),
                                            style: TextStyle(
                                              color: _quickToolSubTab == 0
                                                  ? Colors.white
                                                  : theme.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
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
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.terminal,
                                            size: 16,
                                            color: _quickToolSubTab == 1
                                                ? Colors.white
                                                : theme.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            context.tr('adb_command_tab'),
                                            style: TextStyle(
                                              color: _quickToolSubTab == 1
                                                  ? Colors.white
                                                  : theme.textSecondary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
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
                          const SizedBox(height: 16),

                          if (_quickToolSubTab == 0) ...[
                            // --- TEXT INPUT MODE ---
                            if (logic.textInputHistory.isNotEmpty) ...[
                              Row(
                                children: [
                                  Text(
                                    context.tr('command_history_label'),
                                    style: TextStyle(
                                      color: theme.textSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
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
                                                  .withOpacity(0.5),
                                              fontSize: 13,
                                            ),
                                          ),
                                          dropdownColor: theme.cardBg,
                                          style: TextStyle(
                                            color: theme.textPrimary,
                                            fontSize: 13,
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
                              const SizedBox(height: 16),
                            ],
                            TextField(
                              controller: _textInputController,
                              maxLines: 3,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13,
                              ),
                              decoration: InputDecoration(
                                hintText: context.tr('text_input_placeholder'),
                                hintStyle: TextStyle(
                                  color: theme.textSecondary.withOpacity(0.5),
                                  fontSize: 13,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.borderTheme,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.borderTheme,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00ADB5),
                                  ),
                                ),
                                fillColor: Colors.black26,
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final text = _textInputController.text.trim();
                                  if (text.isEmpty) return;
                                  String escaped = text
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to send text to device.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send, size: 16),
                                label: Text(
                                  context.tr('send_text'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00ADB5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: logic.predefinedInputs.isNotEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
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
                                                      .withOpacity(0.5),
                                                  fontSize: 13,
                                                ),
                                              ),
                                              dropdownColor: theme.cardBg,
                                              style: TextStyle(
                                                color: theme.textPrimary,
                                                fontSize: 13,
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
                                                .withOpacity(0.5),
                                            fontSize: 13,
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
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
                                                  .withOpacity(0.5),
                                              fontSize: 13,
                                            ),
                                          ),
                                          dropdownColor: theme.cardBg,
                                          style: TextStyle(
                                            color: theme.textPrimary,
                                            fontSize: 13,
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
                            const SizedBox(height: 16),
                            TextField(
                              controller: _adbCommandController,
                              maxLines: 1,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                hintText: context.tr('adb_command_placeholder'),
                                hintStyle: TextStyle(
                                  color: theme.textSecondary.withOpacity(0.5),
                                  fontSize: 13,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.borderTheme,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: theme.borderTheme,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF00ADB5),
                                  ),
                                ),
                                fillColor: Colors.black26,
                                filled: true,
                                prefixIcon: const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF00ADB5),
                                  size: 18,
                                ),
                              ),
                              onSubmitted: (val) async {
                                if (_isExecutingAdbCommand ||
                                    val.trim().isEmpty)
                                  return;
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
                            const SizedBox(height: 16),
                            Text(
                              context.tr('console_output_label'),
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              height: 180,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.isDark
                                    ? const Color(0xFF1E1E1E)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
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
                                            ? const Color(0xFF00FF00)
                                            : const Color(0xFF006400),
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                  label: Text(
                                    context.tr('clear_console_btn'),
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
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
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.play_arrow, size: 16),
                                  label: Text(
                                    context.tr('run_command_btn'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00ADB5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 16,
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
              const SizedBox(width: 24),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20.0),
                      decoration: BoxDecoration(
                        color: theme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.borderTheme),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildKeyBtn(
                                icon: Icons.arrow_back,
                                label: context.tr('key_back'),
                                theme: theme,
                                onTap: () => logic.runAdbShellCommand([
                                  'input',
                                  'keyevent',
                                  '4',
                                ]),
                              ),
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
                              _buildKeyBtn(
                                icon: Icons.crop_square,
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
                          const SizedBox(height: 16),
                          Divider(color: theme.borderTheme),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildKeyBtn(
                                icon: Icons.power_settings_new,
                                label: context.tr('key_power'),
                                theme: theme,
                                onTap: () => logic.runAdbShellCommand([
                                  'input',
                                  'keyevent',
                                  '26',
                                ]),
                              ),
                              _buildKeyBtn(
                                icon: Icons.volume_up,
                                label: context.tr('key_volume_up'),
                                theme: theme,
                                onTap: () => logic.runAdbShellCommand([
                                  'input',
                                  'keyevent',
                                  '24',
                                ]),
                              ),
                              _buildKeyBtn(
                                icon: Icons.volume_down,
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
          const SizedBox(height: 32),

          // 4. Device Controls / Reboot actions
          Text(
            context.tr('device_controls'),
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: theme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.borderTheme),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPowerBtn(
                  icon: Icons.restart_alt,
                  label: context.tr('reboot_system'),
                  color: Colors.amberAccent,
                  theme: theme,
                  onTap: () => _confirmAction(
                    context,
                    title: context.tr('confirm_reboot'),
                    message: context.tr('confirm_reboot_msg'),
                    onConfirm: () => logic.runAdbRebootCommand(''),
                  ),
                ),
                _buildPowerBtn(
                  icon: Icons.flash_on,
                  label: context.tr('reboot_bootloader'),
                  color: Colors.orangeAccent,
                  theme: theme,
                  onTap: () => _confirmAction(
                    context,
                    title: context.tr('confirm_reboot'),
                    message: context.tr('confirm_reboot_msg') + ' (Fastboot)',
                    onConfirm: () => logic.runAdbRebootCommand('bootloader'),
                  ),
                ),
                _buildPowerBtn(
                  icon: Icons.build_circle,
                  label: context.tr('reboot_recovery'),
                  color: Colors.deepOrangeAccent,
                  theme: theme,
                  onTap: () => _confirmAction(
                    context,
                    title: context.tr('confirm_reboot'),
                    message: context.tr('confirm_reboot_msg') + ' (Recovery)',
                    onConfirm: () => logic.runAdbRebootCommand('recovery'),
                  ),
                ),
                _buildPowerBtn(
                  icon: Icons.power_settings_new,
                  label: context.tr('power_off'),
                  color: Colors.redAccent,
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
          ),
          const SizedBox(height: 32),

          // 5. Reverse Tethering (Gnirehtet)
          Text(
            context.tr('reverse_tethering_title'),
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: theme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.borderTheme),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('reverse_tethering_desc'),
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: logic.isGnirehtetRunning
                                      ? Colors.green.withOpacity(0.15)
                                      : Colors.red.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: logic.isGnirehtetRunning
                                        ? Colors.green
                                        : Colors.red,
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
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (logic.isGnirehtetRunning) {
                          await logic.stopReverseTethering();
                        } else {
                          if (logic.gnirehtetPath.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please configure Gnirehtet path in Settings first.',
                                ),
                              ),
                            );
                            return;
                          }
                          final ok = await logic.startReverseTethering();
                          if (context.mounted && !ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Failed to start reverse tethering.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      icon: Icon(
                        logic.isGnirehtetRunning
                            ? Icons.portable_wifi_off
                            : Icons.wifi_tethering,
                        size: 18,
                      ),
                      label: Text(
                        logic.isGnirehtetRunning
                            ? context.tr('stop_reverse_tethering')
                            : context.tr('start_reverse_tethering'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: logic.isGnirehtetRunning
                            ? Colors.redAccent
                            : const Color(0xFF00ADB5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                if (logic.isGnirehtetRunning) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr('vpn_instruction'),
                            style: const TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  context.tr('gnirehtet_logs'),
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.isDark
                        ? Colors.black
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
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
  }) {
    return Material(
      color: theme.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFF00ADB5).withOpacity(0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.borderTheme),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ADB5).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF00ADB5), size: 20),
              ),
              const SizedBox(width: 14),
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
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textSecondary.withOpacity(0.4),
                        fontSize: 10,
                      ),
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

  Widget _buildKeyBtn({
    required IconData icon,
    required String label,
    required ThemeProvider theme,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: theme.textPrimary),
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.04),
            padding: const EdgeInsets.all(12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildPowerBtn({
    required IconData icon,
    required String label,
    required Color color,
    required ThemeProvider theme,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withOpacity(0.1),
            foregroundColor: color,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: color.withOpacity(0.2)),
            ),
          ),
          child: Icon(icon, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: theme.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(message, style: const TextStyle(color: Colors.white70)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
        );
      },
    );
  }

  Future<void> _runWithTransferProgress(
    BuildContext context,
    AppLogic logic,
    Future<bool> Function() action,
  ) async {
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return Consumer<AppLogic>(
            builder: (ctx2, logic, child) {
              final progress = logic.transferProgress;
              final status = logic.transferStatus;

              return AlertDialog(
                backgroundColor: const Color(0xFF1E1E24),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'File transfer completed successfully!'
                : 'File transfer failed or was cancelled.',
          ),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('error_select_pc_folder'))),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(preview.error ?? 'Unable to create sync preview.'),
        ),
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

    try {
      return await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  final confirmationMatches =
                      !requiresTypedConfirmation ||
                      confirmationController.text.trim() == 'DELETE';
                  return AlertDialog(
                    backgroundColor: theme.cardBg,
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
                          'Sync preview',
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
                              'Scanned ${preview.pcFileCount} PC files and ${preview.androidFileCount} Android files.',
                              style: TextStyle(color: theme.textSecondary),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _previewCountChip(
                                  icon: Icons.copy_outlined,
                                  label: '${preview.copyCount} copy/update',
                                  color: const Color(0xFF00ADB5),
                                ),
                                _previewCountChip(
                                  icon: Icons.delete_outline,
                                  label: '${preview.deleteCount} delete',
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
                                  color: Colors.redAccent.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.redAccent.withOpacity(0.5),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Files to delete',
                                      style: TextStyle(
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
                                        '… and ${preview.deleteCount - 5} more file(s)',
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
                                  labelText: 'Type DELETE to confirm',
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
                        onPressed: () => Navigator.of(dialogContext).pop(false),
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
                        label: const Text('Start sync'),
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
        color: color.withOpacity(0.12),
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
              color: theme.textSecondary.withOpacity(0.3),
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
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Card(
              color: theme.cardBg.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.borderTheme),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('sync_folders_title'),
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      context.tr('pc_folder_label'),
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pcPathController,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: context.tr('select_pc_folder_hint'),
                              hintStyle: TextStyle(
                                color: theme.textSecondary.withOpacity(0.5),
                              ),
                              filled: true,
                              fillColor: Colors.black12,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.borderTheme,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF00ADB5),
                                ),
                              ),
                            ),
                            enabled: !isSyncing,
                            onChanged: (_) => _saveCurrentSettings(logic),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.folder_open,
                            color: Color(0xFF00ADB5),
                          ),
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
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      context.tr('android_folder_label'),
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _androidPathController,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: '/sdcard/...',
                              hintStyle: TextStyle(
                                color: theme.textSecondary.withOpacity(0.5),
                              ),
                              filled: true,
                              fillColor: Colors.black12,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: theme.borderTheme,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF00ADB5),
                                ),
                              ),
                            ),
                            enabled: !isSyncing,
                            onChanged: (_) => _saveCurrentSettings(logic),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.get_app,
                            color: Color(0xFF00ADB5),
                          ),
                          tooltip: context.tr('get_current_folder_btn'),
                          onPressed: isSyncing
                              ? null
                              : () {
                                  _androidPathController.text =
                                      logic.androidCurrentPath;
                                  _saveCurrentSettings(logic);
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      context.tr('sync_direction_label'),
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.borderTheme),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: direction,
                          dropdownColor: theme.cardBg,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 13,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'pcToAndroid',
                              child: Text(
                                context.tr('sync_direction_pc_to_android'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'androidToPc',
                              child: Text(
                                context.tr('sync_direction_android_to_pc'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'syncNewest',
                              child: Text(context.tr('sync_direction_newest')),
                            ),
                          ],
                          onChanged: isSyncing
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() {
                                      direction = val;
                                    });
                                    _saveCurrentSettings(logic);
                                  }
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Checkbox(
                          value: deleteExtra,
                          activeColor: const Color(0xFF00ADB5),
                          onChanged: isSyncing
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() {
                                      deleteExtra = val;
                                      if (val) autoSync = false;
                                    });
                                    _saveCurrentSettings(logic);
                                  }
                                },
                        ),
                        Expanded(
                          child: Text(
                            context.tr('delete_extra_files_label'),
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Checkbox(
                          value: autoSync,
                          activeColor: const Color(0xFF00ADB5),
                          onChanged: (val) {
                            if (val != null) {
                              if (val && deleteExtra) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Auto Sync cannot run while Delete extra is enabled.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                autoSync = val;
                              });
                              _saveCurrentSettings(logic);
                              if (val) {
                                unawaited(_startSync(logic));
                              } else {
                                if (logic.isSyncing) {
                                  logic.cancelSyncFolder();
                                }
                              }
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            context.tr('auto_sync_label'),
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

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
                                          ? Icons.play_arrow
                                          : Icons.pause,
                                      size: 18,
                                    ),
                                    label: Text(
                                      logic.isSyncPaused
                                          ? context.tr('resume_sync_btn')
                                          : context.tr('pause_sync_btn'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _cancelSync(logic),
                                    icon: const Icon(Icons.cancel, size: 18),
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
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ElevatedButton.icon(
                              onPressed: () => _startSync(logic),
                              icon: const Icon(Icons.sync, size: 18),
                              label: Text(
                                context.tr('start_sync_btn'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00ADB5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 10),

                    Text(
                      context.tr('recent_sync_title'),
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: logic.syncHistory.isEmpty
                          ? Center(
                              child: Text(
                                context.tr('sync_history_empty'),
                                style: TextStyle(
                                  color: theme.textSecondary.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: logic.syncHistory.length,
                              itemBuilder: (context, index) {
                                final item = logic.syncHistory[index];
                                final parts = item.split('|');
                                if (parts.length < 4)
                                  return const SizedBox.shrink();
                                final histPc = parts[0];
                                final histAndroid = parts[1];
                                final histDir = parts[2];
                                final histDelExtra = parts[3] == '1';

                                return Card(
                                  color: Colors.black12,
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                      color: Colors.white10,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 0,
                                    ),
                                    dense: true,
                                    title: Text(
                                      '${_getBasename(histPc)} ↔ ${_getBasename(histAndroid)}',
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      'Dir: ${histDir == "pcToAndroid" ? "PC→Android" : (histDir == "androidToPc" ? "Android→PC" : "Newest")} | Mirror: ${histDelExtra ? "Yes" : "No"}',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                    trailing: isSyncing
                                        ? null
                                        : IconButton(
                                            icon: const Icon(
                                              Icons.arrow_forward,
                                              size: 16,
                                              color: Color(0xFF00ADB5),
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _pcPathController.text = histPc;
                                                _androidPathController.text =
                                                    histAndroid;
                                                direction = histDir;
                                                deleteExtra = histDelExtra;
                                              });
                                              _saveCurrentSettings(logic);
                                            },
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (logic.syncHistory.isNotEmpty && !isSyncing)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => logic.clearSyncHistory(),
                          child: Text(
                            context.tr('clear_history_btn'),
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 20),

          Expanded(
            flex: 7,
            child: Card(
              color: theme.cardBg.withOpacity(0.4),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: theme.borderTheme),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Console Log / Status',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (syncLog.isNotEmpty)
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: syncLog),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Log copied to clipboard'),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.copy,
                                  size: 14,
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
                              TextButton.icon(
                                onPressed: () {
                                  logic.clearSyncLog();
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 14,
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
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status: ${statusText.isEmpty ? context.tr("sync_status_idle") : statusText}',
                          style: TextStyle(
                            color: isFinished
                                ? Colors.tealAccent
                                : (isSyncing
                                      ? const Color(0xFF00ADB5)
                                      : theme.textSecondary),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isSyncing)
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              color: Color(0xFF00ADB5),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: isSyncing ? progress : 0.0,
                      backgroundColor: Colors.black26,
                      color: const Color(0xFF00ADB5),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 16),

                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.isDark
                              ? const Color(0xFF1E1E1E)
                              : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
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
                                    ? 'Waiting for sync to start...\n'
                                    : syncLog,
                                style: TextStyle(
                                  color: theme.isDark
                                      ? const Color(0xFF00FF00)
                                      : const Color(0xFF006400),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
