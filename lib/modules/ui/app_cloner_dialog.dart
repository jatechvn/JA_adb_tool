import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../logic.dart';
import 'app_colors.dart';
import 'app_toast.dart';
import 'glass_dialog.dart';
import 'localization.dart';
import 'styles.dart';
import 'apk_signing_setup_dialog.dart';

class AppClonerDialog extends StatefulWidget {
  final AndroidApp? app;
  final String? directApkPath;
  final String? initialPackage;
  final String? initialAppName;

  const AppClonerDialog({
    super.key,
    this.app,
    this.directApkPath,
    this.initialPackage,
    this.initialAppName,
  });

  @override
  State<AppClonerDialog> createState() => _AppClonerDialogState();
}

class _AppClonerDialogState extends State<AppClonerDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final TextEditingController _nameController;
  late final TextEditingController _packageController;
  late final TextEditingController _exportDirController;

  String _sourcePackage = '';
  String _sourceAppName = '';
  bool _isDirectApk = false;

  // APK Clone options
  bool _installToDevice = true;
  bool _saveToPc = false;
  bool _isCloning = false;
  double _cloneProgress = 0.0;
  String _cloneStatusText = '';
  String _cloneLog = '';

  // Dual Space options
  bool _loadingProfiles = false;
  List<AndroidUserProfile> _profiles = [];
  bool _isManagingSpace = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _isDirectApk =
        widget.directApkPath != null && widget.directApkPath!.isNotEmpty;
    _sourcePackage =
        widget.app?.packageName ??
        widget.initialPackage ??
        (_isDirectApk ? 'com.app.cloned' : 'com.example.app');

    _sourceAppName =
        widget.app?.appName ??
        widget.initialAppName ??
        (_isDirectApk
            ? p.basenameWithoutExtension(widget.directApkPath!)
            : 'Application');

    _nameController = TextEditingController(text: '$_sourceAppName (Clone 1)');
    _packageController = TextEditingController(text: '$_sourcePackage.clone1');
    _exportDirController = TextEditingController();

    _loadDualSpaceProfiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _packageController.dispose();
    _exportDirController.dispose();
    super.dispose();
  }

  Future<void> _loadDualSpaceProfiles() async {
    final logic = context.read<AppLogic>();
    if (logic.selectedDevice == null) return;

    setState(() => _loadingProfiles = true);
    try {
      final profiles = await logic.getDeviceUserProfiles();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _loadingProfiles = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfiles = false);
    }
  }

  Future<void> _startApkCloning(AppLogic logic) async {
    final newPkg = _packageController.text.trim();
    final newName = _nameController.text.trim();

    if (newPkg.isEmpty) {
      context.showErrorToast('Package ID cannot be empty');
      return;
    }
    if (newPkg == _sourcePackage) {
      context.showErrorToast(
        'New Package ID must differ from original package',
      );
      return;
    }

    setState(() {
      _isCloning = true;
      _cloneProgress = 0.05;
      _cloneStatusText = context.tr('cloning_in_progress');
      _cloneLog = 'Initializing App Cloner engine...\n';
    });

    try {
      final targetDir = _saveToPc && _exportDirController.text.isNotEmpty
          ? _exportDirController.text.trim()
          : Directory.systemTemp.createTempSync('ja_cloned_output_').path;

      ClonedApkResult result;
      if (_isDirectApk) {
        result = await logic.cloneDirectApkFile(
          sourceApkPath: widget.directApkPath!,
          oldPackage: _sourcePackage,
          newPackageName: newPkg,
          newAppName: newName.isNotEmpty ? newName : null,
          targetDirectory: targetDir,
          onProgress: (step, progress) {
            if (mounted) {
              setState(() {
                _cloneStatusText = step;
                _cloneProgress = progress;
                _cloneLog += '$step\n';
              });
            }
          },
        );
      } else {
        result = await logic.cloneInstalledApp(
          packageName: _sourcePackage,
          newPackageName: newPkg,
          newAppName: newName.isNotEmpty ? newName : null,
          targetDirectory: targetDir,
          onProgress: (step, progress) {
            if (mounted) {
              setState(() {
                _cloneStatusText = step;
                _cloneProgress = progress;
                _cloneLog += '$step\n';
              });
            }
          },
        );
      }

      if (!mounted) return;

      if (result.isSuccess &&
          _installToDevice &&
          logic.selectedDevice != null) {
        setState(() {
          _cloneStatusText = 'Installing cloned package to device...';
          _cloneProgress = 0.92;
          _cloneLog +=
              'Installing ${result.outputPath} onto ${logic.selectedDevice}...\n';
        });

        final installRes = await logic.installApkPath(result.outputPath!);
        if (!installRes) {
          result = ClonedApkResult.failure(
            'APK was created, but installation failed. ${result.outputPath}',
          );
        }
        if (mounted) {
          setState(() {
            _cloneLog += installRes
                ? 'Successfully installed to device!\n'
                : 'Installation failed or permission rejected on device.\n';
          });
        }
      }

      if (mounted) {
        setState(() {
          _isCloning = false;
          _cloneProgress = result.isSuccess ? 1.0 : 0.0;
          _cloneStatusText = result.isSuccess
              ? context.tr('cloning_success')
              : context.tr('cloning_failed');
        });

        if (result.isSuccess) {
          context.showSuccessToast(context.tr('cloning_success'));
        } else {
          context.showErrorToast(
            result.errorMessage ?? context.tr('cloning_failed'),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _cloneProgress = 0;
          _cloneStatusText = context.tr('cloning_failed');
          _cloneLog += '\n$error\n';
        });
        context.showErrorToast(context.tr('cloning_failed'));
      }
    } finally {
      if (mounted) setState(() => _isCloning = false);
    }
  }

  Future<void> _createDualSpace(AppLogic logic) async {
    setState(() => _isManagingSpace = true);
    try {
      final newId = await logic.createDeviceCloneProfile(
        name: 'JA Clone Space',
      );
      if (!mounted) return;
      if (newId != null) {
        context.showSuccessToast('Created clone space profile User $newId');
        await _loadDualSpaceProfiles();
      } else {
        context.showErrorToast('Failed to create clone profile on device');
      }
    } finally {
      if (mounted) setState(() => _isManagingSpace = false);
    }
  }

  Future<void> _cloneToDualSpace(AppLogic logic, int userId) async {
    setState(() => _isManagingSpace = true);
    try {
      final ok = await logic.installAppToCloneProfile(
        userId: userId,
        packageName: _sourcePackage,
      );
      if (!mounted) return;
      if (ok) {
        context.showSuccessToast(
          'Successfully cloned $_sourceAppName to User $userId!',
        );
      } else {
        context.showErrorToast('Failed to install into User $userId');
      }
    } finally {
      if (mounted) setState(() => _isManagingSpace = false);
    }
  }

  Future<void> _launchInDualSpace(AppLogic logic, int userId) async {
    final ok = await logic.launchAppInCloneProfile(
      userId: userId,
      packageName: _sourcePackage,
    );
    if (mounted) {
      if (ok) {
        context.showSuccessToast('Launched $_sourceAppName in User $userId');
      } else {
        context.showErrorToast('Failed to launch application');
      }
    }
  }

  Future<void> _removeFromDualSpace(AppLogic logic, int userId) async {
    final ok = await logic.uninstallAppFromCloneProfile(
      userId: userId,
      packageName: _sourcePackage,
    );
    if (mounted) {
      if (ok) {
        context.showSuccessToast('Removed $_sourceAppName from User $userId');
      } else {
        context.showErrorToast('Failed to remove application');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final colors = theme.colors;
    final logic = context.watch<AppLogic>();

    return GlassDialog(
      width: 680,
      title: context.tr('app_cloner_title'),
      icon: Icons.copy_all_rounded,
      headerTrailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00ADB5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF00ADB5).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  size: 13,
                  color: Color(0xFF00ADB5),
                ),
                const SizedBox(width: 5),
                Text(
                  logic.selectedDevice ?? 'No Device',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00ADB5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Target App Header Card
          _buildAppHeaderCard(theme, colors),
          const SizedBox(height: 12),

          // Tab Bar
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: theme.isDark
                  ? theme.subCardBg.withValues(alpha: 0.6)
                  : const Color(0xFFEDF2F7),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.borderTheme),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF00ADB5),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: theme.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 14),
                      SizedBox(width: 6),
                      Text('APK File Clone'),
                    ],
                  ),
                ),
                Tab(
                  icon: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.dashboard_customize_rounded, size: 14),
                      SizedBox(width: 6),
                      Text('Dual Space (Multi-User)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab Content
          SizedBox(
            height: 440,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildApkCloneTab(theme, colors, logic),
                _buildDualSpaceTab(theme, colors, logic),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppHeaderCard(ThemeProvider theme, AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.isDark ? theme.subCardBg : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.borderTheme),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF00ADB5).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00ADB5).withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.android_rounded,
              size: 26,
              color: Color(0xFF00ADB5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sourceAppName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _sourcePackage,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (_isDirectApk ? Colors.purple : Colors.blue).withValues(
                alpha: 0.15,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: (_isDirectApk ? Colors.purple : Colors.blue).withValues(
                  alpha: 0.4,
                ),
              ),
            ),
            child: Text(
              _isDirectApk ? 'Local APK' : 'Device App',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _isDirectApk ? Colors.purpleAccent : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApkCloneTab(
    ThemeProvider theme,
    AppColors colors,
    AppLogic logic,
  ) {
    final terminalBg = theme.isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final defaultTextColor = theme.isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF047857);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Inputs
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _isCloning
                  ? null
                  : () async {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => const ApkSigningSetupDialog(),
                      );
                    },
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(context.tr('apk_signing_setup')),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('new_app_name_label'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _nameController,
                        enabled: !_isCloning,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.label_rounded, size: 16),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('new_package_id_label'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _packageController,
                        enabled: !_isCloning,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: theme.textPrimary,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.fingerprint_rounded,
                            size: 16,
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Options Checkboxes
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _installToDevice,
            enabled: !_isCloning && logic.selectedDevice != null,
            title: Text(
              context.tr('install_after_clone'),
              style: TextStyle(fontSize: 12, color: theme.textPrimary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => _installToDevice = v ?? true),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _saveToPc,
            enabled: !_isCloning,
            title: Text(
              context.tr('save_to_pc'),
              style: TextStyle(fontSize: 12, color: theme.textPrimary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => _saveToPc = v ?? false),
          ),

          if (_saveToPc) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _exportDirController,
                      enabled: !_isCloning,
                      style: TextStyle(fontSize: 11, color: theme.textPrimary),
                      decoration: InputDecoration(
                        hintText: context.tr('choose_export_folder'),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  tooltip: context.tr('choose_export_folder'),
                  onPressed: _isCloning
                      ? null
                      : () async {
                          final dir = await FilePicker.getDirectoryPath();
                          if (dir != null && mounted) {
                            setState(() => _exportDirController.text = dir);
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Progress and Log Area
          if (_isCloning || _cloneLog.isNotEmpty) ...[
            const SizedBox(height: 6),
            if (_isCloning) ...[
              LinearProgressIndicator(
                value: _cloneProgress > 0 ? _cloneProgress : null,
                color: const Color(0xFF00ADB5),
                backgroundColor: theme.isDark
                    ? Colors.black26
                    : const Color(0xFFE2E8F0),
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Text(
                _cloneStatusText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00ADB5),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Container(
              height: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: terminalBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.borderTheme),
              ),
              child: SingleChildScrollView(
                reverse: true,
                child: Text(
                  _cloneLog,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: defaultTextColor,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Clone Button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ADB5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: _isCloning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.rocket_launch_rounded, size: 18),
              label: Text(
                _isCloning
                    ? context.tr('cloning_in_progress')
                    : context.tr('start_cloning_btn'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              onPressed: _isCloning ? null : () => _startApkCloning(logic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualSpaceTab(
    ThemeProvider theme,
    AppColors colors,
    AppLogic logic,
  ) {
    if (logic.selectedDevice == null) {
      return Center(
        child: Text(
          'Connect a device to use Dual Space cloning.',
          style: TextStyle(color: theme.textSecondary, fontSize: 13),
        ),
      );
    }

    final secondaryProfiles = _profiles.where((p) => !p.isOwner).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Architecture Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_rounded,
                  size: 20,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('dual_space_guide_title'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('dual_space_guide_desc'),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Profiles section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('device_profiles_title'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                tooltip: 'Refresh profiles',
                onPressed: _loadingProfiles ? null : _loadDualSpaceProfiles,
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_loadingProfiles)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (secondaryProfiles.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.isDark ? theme.subCardBg : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.borderTheme),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.space_dashboard_rounded,
                    size: 32,
                    color: Colors.amber,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr('no_dual_space_found'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: theme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isManagingSpace
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 16,
                          ),
                    label: Text(
                      context.tr('create_dual_space_btn'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: _isManagingSpace
                        ? null
                        : () => _createDualSpace(logic),
                  ),
                ],
              ),
            ),
          ] else ...[
            for (final profile in secondaryProfiles) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.isDark
                      ? theme.subCardBg
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.borderTheme),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00ADB5).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.work_outline_rounded,
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
                            '${profile.name} (User ${profile.id})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profile.isRunning ? 'Active & Running' : 'Stopped',
                            style: TextStyle(
                              fontSize: 11,
                              color: profile.isRunning
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00ADB5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text(
                        context.tr('install_to_space_btn'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _isManagingSpace
                          ? null
                          : () => _cloneToDualSpace(logic, profile.id),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      tooltip: context.tr('launch_in_space_btn'),
                      color: Colors.green,
                      onPressed: _isManagingSpace
                          ? null
                          : () => _launchInDualSpace(logic, profile.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      tooltip: context.tr('remove_from_space_btn'),
                      color: Colors.redAccent,
                      onPressed: _isManagingSpace
                          ? null
                          : () => _removeFromDualSpace(logic, profile.id),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(context.tr('create_dual_space_btn')),
                onPressed: _isManagingSpace
                    ? null
                    : () => _createDualSpace(logic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
