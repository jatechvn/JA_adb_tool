import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import 'glass_dialog.dart';
import 'localization.dart';
import 'styles.dart';

class SettingsBackupDialog extends StatelessWidget {
  const SettingsBackupDialog({super.key});

  Future<void> _export(BuildContext context, AppLogic logic) async {
    final path = await FilePicker.saveFile(
      dialogTitle: context.tr('backup_settings'),
      fileName: 'ja_adb_tool_settings.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return;
    try {
      await logic.exportSettingsBackup(path);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('backup_exported'))));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('backup_failed'))));
    }
  }

  Future<void> _import(BuildContext context, AppLogic logic) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: context.tr('restore_settings'),
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final ok = await logic.importSettingsBackup(path);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(ok ? 'backup_imported' : 'backup_import_failed'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final logic = context.watch<AppLogic>();
    return GlassDialog(
      child: AlertDialog(
        backgroundColor: glassDialogBackground(
          theme: theme,
          opacity: logic.dialogOpacity,
        ),
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.import_export_rounded, color: Color(0xFF00ADB5)),
            const SizedBox(width: 10),
            Text(context.tr('backup_restore')),
          ],
        ),
        content: Text(
          context.tr('backup_hint'),
          style: TextStyle(color: theme.textSecondary, height: 1.35),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _import(context, logic),
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(context.tr('restore_settings')),
          ),
          FilledButton.icon(
            onPressed: () => _export(context, logic),
            icon: const Icon(Icons.save_alt_rounded),
            label: Text(context.tr('backup_settings')),
          ),
        ],
      ),
    );
  }
}
