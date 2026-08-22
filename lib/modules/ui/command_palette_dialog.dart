import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'styles.dart';
import 'localization.dart';

class CommandPaletteCommand {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onSelected;

  const CommandPaletteCommand({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onSelected,
  });
}

class CommandPaletteDialog extends StatefulWidget {
  final List<CommandPaletteCommand> commands;

  const CommandPaletteDialog({super.key, required this.commands});

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      if (mounted) setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final query = _query.toLowerCase();
    final filtered = widget.commands
        .where(
          (command) =>
              query.isEmpty ||
              command.title.toLowerCase().contains(query) ||
              command.subtitle.toLowerCase().contains(query),
        )
        .toList(growable: false);

    return Dialog(
      backgroundColor: theme.cardBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: context.tr('command_palette_hint'),
                  suffixIcon: IconButton(
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.clear_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: filtered.isEmpty
                    ? Center(child: Text(context.tr('no_apps_found')))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final command = filtered[index];
                          return ListTile(
                            leading: Icon(
                              command.icon,
                              color: const Color(0xFF00ADB5),
                            ),
                            title: Text(command.title),
                            subtitle: Text(command.subtitle),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            onTap: () {
                              Navigator.of(context).pop();
                              command.onSelected();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
