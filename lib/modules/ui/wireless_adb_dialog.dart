import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import 'styles.dart';
import 'localization.dart';

class WirelessAdbDialog extends StatefulWidget {
  const WirelessAdbDialog({super.key});

  @override
  State<WirelessAdbDialog> createState() => _WirelessAdbDialogState();
}

class _WirelessAdbDialogState extends State<WirelessAdbDialog> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController(text: '5555');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _connect(AppLogic logic) async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (port == null) {
      return;
    }
    await logic.connectWirelessDevice(host, port);
  }

  Future<void> _disconnect(AppLogic logic, String endpoint) {
    return logic.disconnectWirelessDevice(endpoint);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return AlertDialog(
      backgroundColor: theme.cardBg,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          const Icon(Icons.wifi_rounded, color: Color(0xFF00ADB5)),
          const SizedBox(width: 10),
          Expanded(child: Text(context.tr('wireless_adb_title'))),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Consumer<AppLogic>(
          builder: (context, logic, _) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('wireless_adb_hint'),
                    style: TextStyle(color: theme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _hostController,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            labelText: context.tr('wireless_host'),
                            prefixIcon: const Icon(Icons.router_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: context.tr('wireless_port'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: logic.isWirelessConnecting
                        ? null
                        : () => _connect(logic),
                    icon: logic.isWirelessConnecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link_rounded),
                    label: Text(context.tr('wireless_connect')),
                  ),
                  if (logic.wirelessStatus.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      logic.wirelessStatus,
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    context.tr('wireless_saved_endpoints'),
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (logic.wirelessEndpoints.isEmpty)
                    Text(
                      context.tr('wireless_no_endpoints'),
                      style: TextStyle(color: theme.textSecondary),
                    )
                  else
                    ...logic.wirelessEndpoints.map(
                      (endpoint) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.devices_other_rounded),
                        title: Text(endpoint),
                        trailing: IconButton(
                          tooltip: context.tr('wireless_disconnect'),
                          icon: const Icon(Icons.link_off_rounded),
                          onPressed: () => _disconnect(logic, endpoint),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
      ],
    );
  }
}
