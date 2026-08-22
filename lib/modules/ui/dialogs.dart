// lib/modules/ui/dialogs.dart

import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'styles.dart';
import 'localization.dart';
import '../logic.dart';
import '../constants.dart';

class ConfirmDeleteDialog extends StatelessWidget {
  final String itemName;

  const ConfirmDeleteDialog({super.key, required this.itemName});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: AlertDialog(
        backgroundColor: theme.cardBg.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Text(
          context.tr('confirm_delete'),
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          context.tr('confirm_delete_msg', args: {'name': itemName}),
          style: TextStyle(color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('delete_selected')),
          ),
        ],
      ),
    );
  }
}

class CreateFolderDialog extends StatefulWidget {
  const CreateFolderDialog({super.key});

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: AlertDialog(
        backgroundColor: theme.cardBg.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Text(
          context.tr('create_folder'),
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: _controller,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            labelText: context.tr('folder_name'),
            labelStyle: TextStyle(color: theme.textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: theme.borderTheme),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF00ADB5)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.of(context).pop(name);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ADB5),
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('create')),
          ),
        ],
      ),
    );
  }
}

class MessageDialog extends StatelessWidget {
  final String title;
  final String message;

  const MessageDialog({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: AlertDialog(
        backgroundColor: theme.cardBg.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: TextStyle(color: theme.textSecondary)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00ADB5),
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class ConfirmActionDialog extends StatelessWidget {
  final String title;
  final String message;

  const ConfirmActionDialog({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: AlertDialog(
        backgroundColor: theme.cardBg.withOpacity(0.9),
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: TextStyle(color: theme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
  }
}

class _SettingsInfoContent {
  Future<void> _openLink(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('open_link_failed'))));
    }
  }

  Widget _aboutTab(BuildContext context, ThemeProvider theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.tr('about_version')} $appVersion',
            style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('about_desc'),
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openLink(context, projectWebsite),
                icon: const Icon(Icons.language_rounded, size: 15),
                label: Text(context.tr('project_website')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00ADB5),
                  side: const BorderSide(color: Color(0x6600ADB5)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _openLink(context, projectRepository),
                icon: const Icon(Icons.code_rounded, size: 15),
                label: Text(context.tr('source_code')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textPrimary,
                  side: BorderSide(color: theme.borderTheme),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guideTab(BuildContext context, ThemeProvider theme) {
    const guideKeys = [
      'guide_connect',
      'guide_mirror',
      'guide_file',
      'guide_sync',
      'guide_media',
      'guide_install',
      'guide_tether',
      'guide_tools',
      'guide_settings',
    ];
    const guideIcons = [
      Icons.usb_rounded,
      Icons.cast_rounded,
      Icons.folder_open_rounded,
      Icons.sync_rounded,
      Icons.perm_media_rounded,
      Icons.install_mobile_rounded,
      Icons.wifi_tethering_rounded,
      Icons.construction_rounded,
      Icons.settings_rounded,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: List.generate(guideKeys.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  guideIcons[index],
                  color: const Color(0xFF00ADB5),
                  size: 17,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.tr(guideKeys[index]),
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _AboutSettingsTab extends StatelessWidget {
  const _AboutSettingsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return _SettingsInfoContent()._aboutTab(context, theme);
  }
}

class _UserGuideSettingsTab extends StatelessWidget {
  const _UserGuideSettingsTab();

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return _SettingsInfoContent()._guideTab(context, theme);
  }
}

class PathsSettingsDialog extends StatefulWidget {
  const PathsSettingsDialog({super.key});

  @override
  State<PathsSettingsDialog> createState() => _PathsSettingsDialogState();
}

class _PathsSettingsDialogState extends State<PathsSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _adbController;
  late TextEditingController _scrcpyController;
  late TextEditingController _gnirehtetController;
  late double _bgBlur;
  late double _bgOpacity;
  late double _dialogBlur;
  late double _dialogOpacity;
  bool _glassExpanded = true;
  late final TabController _settingsTabController;
  int _activeSettingsTab = 0;

  @override
  void initState() {
    super.initState();
    _settingsTabController = TabController(length: 3, vsync: this)
      ..addListener(_handleSettingsTabChanged);
    final logic = Provider.of<AppLogic>(context, listen: false);
    _adbController = TextEditingController(text: logic.adbPath);
    _scrcpyController = TextEditingController(text: logic.scrcpyPath);
    _gnirehtetController = TextEditingController(text: logic.gnirehtetPath);
    _bgBlur = logic.bgBlur;
    _bgOpacity = logic.bgOpacity;
    _dialogBlur = logic.dialogBlur;
    _dialogOpacity = logic.dialogOpacity;
  }

  @override
  void dispose() {
    _settingsTabController
      ..removeListener(_handleSettingsTabChanged)
      ..dispose();
    _adbController.dispose();
    _scrcpyController.dispose();
    _gnirehtetController.dispose();
    super.dispose();
  }

  void _handleSettingsTabChanged() {
    final index = _settingsTabController.index;
    if (_activeSettingsTab == index) {
      return;
    }
    // Update the panel as soon as TabController.index changes. Waiting for
    // indexIsChanging to finish makes the tab feel unresponsive because the
    // content is rebuilt only after the tab animation has completed.
    setState(() => _activeSettingsTab = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final logic = Provider.of<AppLogic>(context);
    final effectiveDialogBlur = _dialogOpacity < 1.0 && _dialogBlur < 6.0
        ? 6.0
        : _dialogBlur;
    final effectiveBgBlur = _bgOpacity < 1.0 && _bgBlur < 6.0 ? 6.0 : _bgBlur;

    Widget buildGlassSlider({
      required String label,
      required double value,
      required double min,
      required double max,
      required ValueChanged<double> onChanged,
      bool isPercent = false,
    }) {
      final display = isPercent
          ? '${(value * 100).round()}%'
          : '${value.toStringAsFixed(0)}px';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(color: theme.textPrimary, fontSize: 12),
                  ),
                ),
                Text(
                  display,
                  style: TextStyle(color: theme.textSecondary, fontSize: 11),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: isPercent ? 18 : 30,
                activeColor: const Color(0xFF2196F3),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );
    }

    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: effectiveDialogBlur,
        sigmaY: effectiveDialogBlur,
      ),
      child: AlertDialog(
        backgroundColor: theme.cardBg.withOpacity(_dialogOpacity),
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.tr('advanced_settings'),
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: theme.textSecondary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TabBar(
                controller: _settingsTabController,
                labelColor: const Color(0xFF2196F3),
                unselectedLabelColor: theme.textSecondary,
                indicatorColor: const Color(0xFF2196F3),
                tabs: [
                  Tab(text: context.tr('advanced_settings')),
                  Tab(text: context.tr('about')),
                  Tab(text: context.tr('user_guide')),
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.topCenter,
                child: KeyedSubtree(
                  key: ValueKey(_activeSettingsTab),
                  child: (_activeSettingsTab == 0
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.62,
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ADB input
                                Text(
                                  context.tr('path_to_adb'),
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _adbController,
                                        style: TextStyle(
                                          color: theme.textPrimary,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                        decoration: InputDecoration(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                          filled: true,
                                          fillColor: theme.mainBg,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.folder_open,
                                        color: theme.textPrimary,
                                      ),
                                      onPressed: () async {
                                        final fileResult =
                                            await FilePicker.pickFiles(
                                              type: FileType.custom,
                                              allowedExtensions: ['exe'],
                                            );
                                        if (fileResult != null &&
                                            fileResult.files.single.path !=
                                                null) {
                                          setState(() {
                                            _adbController.text =
                                                fileResult.files.single.path!;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Scrcpy input
                                Text(
                                  context.tr('path_to_scrcpy'),
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _scrcpyController,
                                        style: TextStyle(
                                          color: theme.textPrimary,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                        decoration: InputDecoration(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                          filled: true,
                                          fillColor: theme.mainBg,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.folder_open,
                                        color: theme.textPrimary,
                                      ),
                                      onPressed: () async {
                                        final fileResult =
                                            await FilePicker.pickFiles(
                                              type: FileType.custom,
                                              allowedExtensions: ['exe'],
                                            );
                                        if (fileResult != null &&
                                            fileResult.files.single.path !=
                                                null) {
                                          setState(() {
                                            _scrcpyController.text =
                                                fileResult.files.single.path!;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Gnirehtet input
                                Text(
                                  context.tr('gnirehtet_path'),
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _gnirehtetController,
                                        style: TextStyle(
                                          color: theme.textPrimary,
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                        ),
                                        decoration: InputDecoration(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                          filled: true,
                                          fillColor: theme.mainBg,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
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
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(
                                        Icons.folder_open,
                                        color: theme.textPrimary,
                                      ),
                                      onPressed: () async {
                                        final fileResult =
                                            await FilePicker.pickFiles(
                                              type: FileType.custom,
                                              allowedExtensions: ['exe'],
                                            );
                                        if (fileResult != null &&
                                            fileResult.files.single.path !=
                                                null) {
                                          setState(() {
                                            _gnirehtetController.text =
                                                fileResult.files.single.path!;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 18),
                                Theme(
                                  data: Theme.of(
                                    context,
                                  ).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    initiallyExpanded: _glassExpanded,
                                    onExpansionChanged: (expanded) {
                                      setState(() => _glassExpanded = expanded);
                                    },
                                    leading: const Icon(
                                      Icons.blur_on_rounded,
                                      color: Color(0xFF2196F3),
                                      size: 20,
                                    ),
                                    title: Text(
                                      context.tr('glass_settings_title'),
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      context.tr('glass_settings_subtitle'),
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          height: 64,
                                          width: double.infinity,
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              const DecoratedBox(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      Color(0xFF00ADB5),
                                                      Color(0xFF5E35B1),
                                                      Color(0xFFFF8F00),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              BackdropFilter(
                                                filter: ImageFilter.blur(
                                                  sigmaX: effectiveBgBlur,
                                                  sigmaY: effectiveBgBlur,
                                                ),
                                                child: ColoredBox(
                                                  color: theme.mainBg
                                                      .withOpacity(_bgOpacity),
                                                  child: Center(
                                                    child: Text(
                                                      context.tr(
                                                        'glass_preview',
                                                      ),
                                                      style: TextStyle(
                                                        color:
                                                            theme.textPrimary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      buildGlassSlider(
                                        label: context.tr('bg_blur_label'),
                                        value: _bgBlur,
                                        min: 0,
                                        max: 30,
                                        onChanged: (value) =>
                                            setState(() => _bgBlur = value),
                                      ),
                                      buildGlassSlider(
                                        label: context.tr('bg_opacity_label'),
                                        value: _bgOpacity,
                                        min: 0.1,
                                        max: 1.0,
                                        isPercent: true,
                                        onChanged: (value) =>
                                            setState(() => _bgOpacity = value),
                                      ),
                                      buildGlassSlider(
                                        label: context.tr('dialog_blur_label'),
                                        value: _dialogBlur,
                                        min: 0,
                                        max: 30,
                                        onChanged: (value) =>
                                            setState(() => _dialogBlur = value),
                                      ),
                                      buildGlassSlider(
                                        label: context.tr(
                                          'dialog_opacity_label',
                                        ),
                                        value: _dialogOpacity,
                                        min: 0.3,
                                        max: 1.0,
                                        isPercent: true,
                                        onChanged: (value) => setState(
                                          () => _dialogOpacity = value,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.sizeOf(context).height * 0.62,
                          ),
                          child: _activeSettingsTab == 1
                              ? const _AboutSettingsTab()
                              : const _UserGuideSettingsTab(),
                        )),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 2,
                children: [
                  Text(
                    'v$appVersion',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(
                    Icons.settings_suggest_rounded,
                    size: 17,
                    color: Color(0xFF2196F3),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await logic.autoDetectPaths();
                      if (!mounted) return;
                      setState(() {
                        _adbController.text = logic.adbPath;
                        _scrcpyController.text = logic.scrcpyPath;
                        _gnirehtetController.text = logic.gnirehtetPath;
                      });
                    },
                    icon: const Icon(Icons.search, size: 15),
                    label: Text(context.tr('default_search_btn')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00ADB5),
                      side: const BorderSide(color: Color(0xFF00ADB5)),
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _bgBlur = AppLogic.defaultBgBlur;
                      _bgOpacity = AppLogic.defaultBgOpacity;
                      _dialogBlur = AppLogic.defaultDialogBlur;
                      _dialogOpacity = AppLogic.defaultDialogOpacity;
                    }),
                    child: Text(context.tr('reset_defaults')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('cancel')),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await logic.savePaths(
                        _adbController.text,
                        _scrcpyController.text,
                        _gnirehtetController.text,
                      );
                      await logic.saveGlassSettings(
                        bgBlur: _bgBlur,
                        bgOpacity: _bgOpacity,
                        dialogBlur: _dialogBlur,
                        dialogOpacity: _dialogOpacity,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.tr('settings_saved'))),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(context.tr('save_settings')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── About App Dialog ─────────────────────────────────────────────────────────
class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  Future<void> _openLink(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('open_link_failed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    final guideKeys = [
      'guide_connect',
      'guide_mirror',
      'guide_file',
      'guide_sync',
      'guide_media',
      'guide_install',
      'guide_tether',
      'guide_tools',
      'guide_settings',
    ];

    final guideIcons = [
      Icons.usb_rounded,
      Icons.cast_rounded,
      Icons.folder_open_rounded,
      Icons.sync_rounded,
      Icons.perm_media_rounded,
      Icons.install_mobile_rounded,
      Icons.wifi_tethering_rounded,
      Icons.construction_rounded,
      Icons.settings_rounded,
    ];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.borderTheme.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00ADB5).withOpacity(0.12),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00ADB5), Color(0xFF007B83)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.adb_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'JA ADB Tool',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${context.tr('about_version')} $appVersion',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      tooltip: context.tr('about_close'),
                    ),
                  ],
                ),
              ),

              // ── Scrollable content ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00ADB5).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00ADB5).withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          context.tr('about_desc'),
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 13.5,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Project links
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _openLink(context, projectWebsite),
                            icon: const Icon(Icons.language_rounded, size: 16),
                            label: Text(context.tr('project_website')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF00ADB5),
                              side: const BorderSide(color: Color(0x6600ADB5)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openLink(context, projectRepository),
                            icon: const Icon(Icons.code_rounded, size: 16),
                            label: Text(context.tr('source_code')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.textPrimary,
                              side: BorderSide(color: theme.borderTheme),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Usage Guide title
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book_rounded,
                            color: Color(0xFF00ADB5),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('guide_title'),
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Guide steps
                      ...List.generate(guideKeys.length, (i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00ADB5,
                                  ).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  guideIcons[i],
                                  color: const Color(0xFF00ADB5),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  context.tr(guideKeys[i]),
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),

                      // Made by
                      Center(
                        child: Text(
                          context.tr('about_made_by'),
                          style: TextStyle(
                            color: theme.textSecondary.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(context.tr('about_close')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00ADB5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }
}

class UserGuideDialog extends StatelessWidget {
  const UserGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    const guideKeys = [
      'guide_connect',
      'guide_mirror',
      'guide_file',
      'guide_sync',
      'guide_media',
      'guide_install',
      'guide_tether',
      'guide_tools',
      'guide_settings',
    ];
    const guideIcons = [
      Icons.usb_rounded,
      Icons.cast_rounded,
      Icons.folder_open_rounded,
      Icons.sync_rounded,
      Icons.perm_media_rounded,
      Icons.install_mobile_rounded,
      Icons.wifi_tethering_rounded,
      Icons.construction_rounded,
      Icons.settings_rounded,
    ];

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
          decoration: BoxDecoration(
            color: theme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.borderTheme.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00ADB5), Color(0xFF007B83)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.tr('user_guide'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: List.generate(guideKeys.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF00ADB5,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                guideIcons[index],
                                color: const Color(0xFF00ADB5),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                context.tr(guideKeys[index]),
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00ADB5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(context.tr('about_close')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FolderSyncDialog extends StatefulWidget {
  final String androidPath;

  const FolderSyncDialog({super.key, required this.androidPath});

  @override
  State<FolderSyncDialog> createState() => _FolderSyncDialogState();
}

class _FolderSyncDialogState extends State<FolderSyncDialog> {
  String? pcPath;
  String direction = 'pcToAndroid';
  bool deleteExtra = false;
  bool isSyncing = false;
  bool isFinished = false;
  double progress = 0.0;
  String statusText = '';
  String syncLog = '';
  StreamSubscription<AdbSyncProgressEvent>? syncSub;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    syncSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startSync(AppLogic logic) {
    if (pcPath == null || pcPath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('error_select_pc_folder'))),
      );
      return;
    }

    setState(() {
      isSyncing = true;
      isFinished = false;
      progress = 0.0;
      statusText = 'Starting...';
      syncLog = '';
    });

    syncSub = logic
        .syncFolders(
          pcPath: pcPath!,
          androidPath: widget.androidPath,
          direction: direction,
          deleteExtra: deleteExtra,
        )
        .listen(
          (event) {
            setState(() {
              syncLog += event.logMessage;
              if (event.status == 'scanning') {
                statusText = 'Scanning...';
              } else if (event.status == 'comparing') {
                statusText = 'Comparing...';
              } else if (event.status == 'syncing') {
                statusText = 'Syncing...';
                progress = event.percentage;
              } else if (event.status == 'completed') {
                statusText = 'Completed';
                progress = 1.0;
                isSyncing = false;
                isFinished = true;
              } else if (event.status == 'error') {
                statusText = 'Error';
                isSyncing = false;
                isFinished = true;
              }
            });
            _scrollToLogBottom();
          },
          onError: (Object e, StackTrace stackTrace) {
            setState(() {
              isSyncing = false;
              isFinished = true;
              statusText = 'Error';
              syncLog += '\nError occurred: $e\n';
            });
            _scrollToLogBottom();
          },
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
    final logic = Provider.of<AppLogic>(context, listen: false);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: Dialog(
        backgroundColor: theme.cardBg.withOpacity(0.95),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 550,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  const Icon(Icons.sync, color: Color(0xFF00ADB5), size: 24),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('sync_folders_title'),
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (!isSyncing && !isFinished) ...[
                // PC Folder Picker
                Text(
                  context.tr('pc_folder_label'),
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.borderTheme),
                        ),
                        child: Text(
                          pcPath ?? context.tr('select_pc_folder_hint'),
                          style: TextStyle(
                            color: pcPath == null
                                ? theme.textSecondary.withOpacity(0.5)
                                : theme.textPrimary,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.folder_open,
                        color: Color(0xFF00ADB5),
                      ),
                      onPressed: () async {
                        final String? path =
                            await FilePicker.getDirectoryPath();
                        if (path != null) {
                          setState(() {
                            pcPath = path;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Android Folder (Read-only)
                Text(
                  context.tr('android_folder_label'),
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.borderTheme),
                  ),
                  child: Text(
                    widget.androidPath,
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),

                // Direction dropdown
                Text(
                  context.tr('sync_direction_label'),
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.borderTheme),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: direction,
                      dropdownColor: theme.cardBg,
                      style: TextStyle(color: theme.textPrimary, fontSize: 13),
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
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            direction = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Delete Extra checkbox
                Row(
                  children: [
                    Checkbox(
                      value: deleteExtra,
                      activeColor: const Color(0xFF00ADB5),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            deleteExtra = val;
                          });
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
                const SizedBox(height: 24),

                // Status Idle / Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        context.tr('cancel'),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _startSync(logic),
                      icon: const Icon(Icons.sync, size: 16),
                      label: Text(
                        context.tr('start_sync_btn'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ADB5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Syncing / Completed UI
                Text(
                  'Status: $statusText',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.black26,
                  color: const Color(0xFF00ADB5),
                ),
                const SizedBox(height: 16),

                // Dark log console
                Container(
                  width: double.infinity,
                  height: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
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
                          syncLog.isEmpty ? 'Preparing sync...\n' : syncLog,
                          style: const TextStyle(
                            color: Color(0xFF00FF00),
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.4,
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
                    if (isSyncing)
                      TextButton(
                        onPressed: () {
                          syncSub?.cancel();
                          setState(() {
                            isSyncing = false;
                            isFinished = true;
                            syncLog += '\nSync cancelled by user.\n';
                          });
                        },
                        child: Text(
                          context.tr('cancel'),
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          logic.loadAndroidDirectory(widget.androidPath);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00ADB5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(context.tr('about_close')),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
