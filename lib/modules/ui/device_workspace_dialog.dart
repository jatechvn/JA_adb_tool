import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import 'glass_dialog.dart';
import 'styles.dart';
import 'localization.dart';

class DeviceWorkspaceDialog extends StatefulWidget {
  const DeviceWorkspaceDialog({super.key});

  @override
  State<DeviceWorkspaceDialog> createState() => _DeviceWorkspaceDialogState();
}

class _DeviceWorkspaceDialogState extends State<DeviceWorkspaceDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save(AppLogic logic) async {
    final profile = await logic.saveCurrentWorkspace(_nameController.text);
    if (!mounted) return;
    if (profile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('workspace_empty'))));
      return;
    }
    _nameController.clear();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.tr('workspace_saved'))));
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
            const Icon(Icons.workspaces_rounded, color: Color(0xFF00ADB5)),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('workspace_title'))),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 360,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: context.tr('workspace_name'),
                        prefixIcon: const Icon(Icons.label_outline_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: logic.selectedDevice == null
                        ? null
                        : () => _save(logic),
                    child: Text(context.tr('workspace_save_current')),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: logic.workspaceProfiles.isEmpty
                    ? Center(child: Text(context.tr('workspace_empty')))
                    : ListView.separated(
                        itemCount: logic.workspaceProfiles.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final profile = logic.workspaceProfiles[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.devices_rounded),
                            title: Text(profile.name),
                            subtitle: Text(profile.deviceId),
                            trailing: Wrap(
                              spacing: 2,
                              children: [
                                IconButton(
                                  tooltip: context.tr('workspace_apply'),
                                  onPressed: () async {
                                    final applied = await logic.applyWorkspace(
                                      profile,
                                    );
                                    if (!context.mounted) return;
                                    if (!applied) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            context.tr('no_devices_found'),
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.open_in_new_rounded),
                                ),
                                IconButton(
                                  tooltip: context.tr('workspace_delete'),
                                  onPressed: () =>
                                      logic.deleteWorkspace(profile.id),
                                  icon: const Icon(Icons.delete_outline),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
        ],
      ),
    );
  }
}
