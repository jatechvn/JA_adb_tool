import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import 'glass_dialog.dart';
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final logic = context.read<AppLogic>();
      if (logic.selectedDevice != null) {
        logic.detectSelectedDeviceWifiIp().then((ip) {
          if (mounted && ip != null && _hostController.text.isEmpty) {
            _hostController.text = ip;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _fixPort(AppLogic logic) async {
    final success = await logic.fixAndConnectWirelessPort(port: 5555);
    if (mounted && success && logic.cachedDeviceWifiIp != null) {
      _hostController.text = logic.cachedDeviceWifiIp!;
    }
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
    final logic = context.watch<AppLogic>();

    if (_hostController.text.isEmpty && logic.cachedDeviceWifiIp != null) {
      _hostController.text = logic.cachedDeviceWifiIp!;
    }

    final hasSelectedDevice = logic.selectedDevice != null;
    final deviceModel =
        logic.selectedDeviceDetails?['model'] ?? logic.selectedDevice ?? '';

    return GlassDialog(
      child: AlertDialog(
        backgroundColor: glassDialogBackground(
          theme: theme,
          opacity: logic.dialogOpacity,
        ),
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.wifi_rounded, color: Color(0xFF00ADB5)),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('wireless_adb_title'))),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Cố định cổng 5555 (1-Click Fix & Connect) ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ADB5).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00ADB5).withValues(alpha: 0.28),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00ADB5,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.auto_fix_high_rounded,
                              color: Color(0xFF00ADB5),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('wireless_fix_port_card_title'),
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  context.tr('wireless_fix_port_card_subtitle'),
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 11.5,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      if (hasSelectedDevice) ...[
                        // Target Device info
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.borderTheme.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.smartphone_rounded,
                                size: 16,
                                color: Color(0xFF00ADB5),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  deviceModel,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.wifi,
                                    size: 14,
                                    color: logic.cachedDeviceWifiIp != null
                                        ? Colors.greenAccent
                                        : theme.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    logic.cachedDeviceWifiIp ??
                                        context.tr(
                                          'wireless_fix_port_detecting_ip',
                                        ),
                                    style: TextStyle(
                                      color: logic.cachedDeviceWifiIp != null
                                          ? theme.textPrimary
                                          : theme.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded),
                                    iconSize: 15,
                                    color: const Color(0xFF00ADB5),
                                    tooltip: context.tr(
                                      'wireless_refresh_ip_tooltip',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.only(left: 4),
                                    constraints: const BoxConstraints(),
                                    onPressed: () =>
                                        logic.detectSelectedDeviceWifiIp(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: logic.isFixingWirelessPort
                                ? null
                                : () => _fixPort(logic),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF00ADB5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: logic.isFixingWirelessPort
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.bolt_rounded, size: 18),
                            label: Text(
                              context.tr('wireless_fix_port_btn'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        // Progress / result feedback
                        if (logic.wirelessFixStatus.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  logic.wirelessFixStatus.contains(
                                    'Connected to',
                                  )
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    logic.wirelessFixStatus.contains(
                                      'Connected to',
                                    )
                                    ? Colors.green.withValues(alpha: 0.4)
                                    : theme.borderTheme,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  logic.wirelessFixStatus.contains(
                                        'Connected to',
                                      )
                                      ? Icons.check_circle_rounded
                                      : Icons.info_outline_rounded,
                                  size: 15,
                                  color:
                                      logic.wirelessFixStatus.contains(
                                        'Connected to',
                                      )
                                      ? Colors.greenAccent
                                      : theme.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    logic.wirelessFixStatus,
                                    style: TextStyle(
                                      color:
                                          logic.wirelessFixStatus.contains(
                                            'Connected to',
                                          )
                                          ? theme.textPrimary
                                          : theme.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (logic.wirelessFixStatus.contains(
                            'Connected to',
                          )) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 13,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    context.tr('wireless_fix_port_unplug_hint'),
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ] else ...[
                        // No selected device hint
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.usb_rounded,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr('wireless_fix_port_no_usb_hint'),
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── 2. Kết nối thủ công qua IP / Port ──
                Text(
                  context.tr('wireless_manual_connect_header'),
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('wireless_adb_hint'),
                  style: TextStyle(color: theme.textSecondary, fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _hostController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: context.tr('wireless_host'),
                          prefixIcon: const Icon(
                            Icons.router_outlined,
                            size: 18,
                          ),
                          isDense: true,
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
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                      : const Icon(Icons.link_rounded, size: 18),
                  label: Text(context.tr('wireless_connect')),
                ),
                if (logic.wirelessStatus.isNotEmpty &&
                    !logic.wirelessFixStatus.contains(
                      logic.wirelessStatus,
                    )) ...[
                  const SizedBox(height: 8),
                  Text(
                    logic.wirelessStatus,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],

                const SizedBox(height: 18),

                // ── 3. Danh sách Endpoint đã lưu ──
                Text(
                  context.tr('wireless_saved_endpoints'),
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                if (logic.wirelessEndpoints.isEmpty)
                  Text(
                    context.tr('wireless_no_endpoints'),
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  )
                else
                  ...logic.wirelessEndpoints.map(
                    (endpoint) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.devices_other_rounded,
                        size: 18,
                      ),
                      title: Text(
                        endpoint,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: context.tr('wireless_disconnect'),
                        icon: const Icon(Icons.link_off_rounded, size: 18),
                        onPressed: () => _disconnect(logic, endpoint),
                      ),
                    ),
                  ),
              ],
            ),
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
