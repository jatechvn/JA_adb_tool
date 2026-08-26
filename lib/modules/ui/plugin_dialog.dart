import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/plugin_registry.dart';
import '../logic.dart';
import 'glass_dialog.dart';
import 'localization.dart';
import 'styles.dart';

class PluginDialog extends StatefulWidget {
  const PluginDialog({super.key});

  @override
  State<PluginDialog> createState() => _PluginDialogState();
}

class _PluginDialogState extends State<PluginDialog> {
  final PluginRegistry _registry = PluginRegistry();
  late Future<List<ToolPluginDescriptor>> _future;

  @override
  void initState() {
    super.initState();
    _future = _registry.scan();
  }

  void _reload() {
    setState(() => _future = _registry.scan());
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
            const Icon(Icons.extension_rounded, color: Color(0xFF00ADB5)),
            const SizedBox(width: 10),
            Text(context.tr('plugin_manager')),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 320,
          child: FutureBuilder<List<ToolPluginDescriptor>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final plugins = snapshot.data ?? const <ToolPluginDescriptor>[];
              if (plugins.isEmpty) {
                return Center(
                  child: Text(
                    context.tr('plugin_empty'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.textSecondary, height: 1.35),
                  ),
                );
              }
              return ListView.separated(
                itemCount: plugins.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final plugin = plugins[index];
                  return SwitchListTile(
                    value: plugin.enabled,
                    activeThumbColor: const Color(0xFF00ADB5),
                    title: Text('${plugin.name}  v${plugin.version}'),
                    subtitle: Text(
                      plugin.description.isEmpty
                          ? plugin.entryPoint
                          : plugin.description,
                    ),
                    onChanged: (enabled) async {
                      await _registry.setEnabled(plugin.id, enabled);
                      _reload();
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: _reload,
            child: Text(context.tr('refresh_list')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
        ],
      ),
    );
  }
}
