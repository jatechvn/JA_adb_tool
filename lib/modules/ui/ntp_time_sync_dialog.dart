import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import 'glass_dialog.dart';
import 'localization.dart';
import 'styles.dart';

class NtpTimeSyncDialog extends StatefulWidget {
  const NtpTimeSyncDialog({super.key});

  @override
  State<NtpTimeSyncDialog> createState() => _NtpTimeSyncDialogState();
}

class _NtpTimeSyncDialogState extends State<NtpTimeSyncDialog> {
  late final TextEditingController _serverController;
  late final TextEditingController _subnetController;
  Timer? _clockTicker;
  DateTime _currentPcTime = DateTime.now();
  bool _showDiagnostics = false;

  static const List<String> _intranetPresets = ['10.81.184.80', '10.81.184.81'];

  static const List<String> _publicPresets = [
    'time.google.com',
    'pool.ntp.org',
    'time.cloudflare.com',
  ];

  @override
  void initState() {
    super.initState();
    _serverController = TextEditingController();
    _subnetController = TextEditingController(text: '10.81.184');

    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentPcTime = DateTime.now();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final logic = context.read<AppLogic>();
      if (logic.selectedDevice != null) {
        logic.loadDeviceTimeAndNtp().then((_) {
          if (mounted && logic.deviceNtpServer.isNotEmpty) {
            _serverController.text = logic.deviceNtpServer;
          } else if (mounted && _serverController.text.isEmpty) {
            _serverController.text = '10.81.184.80';
          }
        });

        // Initialize subnet prefix from Wi-Fi IP if available
        final wifiIp = logic.cachedDeviceWifiIp;
        if (wifiIp != null && wifiIp.isNotEmpty) {
          final prefix = _extractSubnetPrefix(wifiIp);
          if (prefix.isNotEmpty) {
            _subnetController.text = prefix;
          }
        } else {
          logic.detectSelectedDeviceWifiIp().then((ip) {
            if (mounted && ip != null && ip.isNotEmpty) {
              final prefix = _extractSubnetPrefix(ip);
              if (prefix.isNotEmpty) {
                _subnetController.text = prefix;
              }
            }
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _serverController.dispose();
    _subnetController.dispose();
    super.dispose();
  }

  String _extractSubnetPrefix(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length >= 3) {
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }
    return '';
  }

  /// Formats a DateTime into YYYY-MM-DD HH:mm:ss
  String _formatDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  /// Tries to parse device date string and compare with current PC time.
  _DriftInfo _calculateDrift(String deviceTimeStr) {
    if (deviceTimeStr.isEmpty) {
      return const _DriftInfo.unknown();
    }

    try {
      final reg = RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})');
      final match = reg.firstMatch(deviceTimeStr);
      if (match == null) {
        return const _DriftInfo.unknown();
      }

      final isUtc =
          deviceTimeStr.contains('UTC') || deviceTimeStr.contains('GMT');
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final hour = int.parse(match.group(4)!);
      final min = int.parse(match.group(5)!);
      final sec = int.parse(match.group(6)!);

      final deviceDt = isUtc
          ? DateTime.utc(year, month, day, hour, min, sec).toLocal()
          : DateTime(year, month, day, hour, min, sec);

      final diff = deviceDt.difference(_currentPcTime);
      final totalSec = diff.inSeconds.abs();

      if (totalSec <= 3) {
        return _DriftInfo(
          isSynced: true,
          label: '${totalSec}s',
          isDrifting: false,
        );
      }

      final days = diff.inDays.abs();
      final hours = (diff.inHours.abs() % 24).toString().padLeft(2, '0');
      final mins = (diff.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final secs = (diff.inSeconds.abs() % 60).toString().padLeft(2, '0');
      final sign = diff.isNegative ? '-' : '+';

      final label = days > 0
          ? '$sign$days d $hours:$mins:$secs'
          : '$sign$hours:$mins:$secs';

      return _DriftInfo(isSynced: false, label: label, isDrifting: true);
    } catch (_) {
      return const _DriftInfo.unknown();
    }
  }

  Future<void> _testServer(AppLogic logic) async {
    final host = _serverController.text.trim();
    if (host.isEmpty) return;
    await logic.testNtpServer(host);
  }

  Future<void> _applyServer(AppLogic logic) async {
    final host = _serverController.text.trim();
    if (host.isEmpty) return;
    final success = await logic.applyNtpServerAndSync(host);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.tr('ntp_apply_success')
              : context.tr('ntp_apply_failed'),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _syncToPc(AppLogic logic) async {
    final success = await logic.syncDeviceToPcTime();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? context.tr('ntp_sync_to_pc_success')
              : context.tr('ntp_sync_to_pc_failed'),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _scanSubnet(AppLogic logic) async {
    final prefix = _subnetController.text.trim();
    await logic.scanSubnetForNtpServers(prefix.isNotEmpty ? prefix : null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final logic = context.watch<AppLogic>();

    final hasDevice = logic.selectedDevice != null;
    final deviceModel =
        logic.selectedDeviceDetails?['model'] ?? logic.selectedDevice ?? '';
    final drift = _calculateDrift(logic.deviceCurrentTime);

    return GlassDialog(
      child: AlertDialog(
        backgroundColor: glassDialogBackground(
          theme: theme,
          opacity: logic.dialogOpacity,
        ),
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(
              Icons.access_time_filled_rounded,
              color: Color(0xFF00ADB5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('ntp_time_sync_title'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    context.tr('ntp_time_sync_subtitle'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: context.tr('refresh'),
              onPressed: () => logic.loadDeviceTimeAndNtp(),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 1. Thẻ Trạng thái Đồng hồ Hệ thống & Drift ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ADB5).withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF00ADB5).withValues(alpha: 0.28),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF00ADB5,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.schedule_rounded,
                              color: Color(0xFF00ADB5),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              context.tr('ntp_device_clock_title'),
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (hasDevice)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: theme.borderTheme.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.smartphone_rounded,
                                    size: 13,
                                    color: Color(0xFF00ADB5),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    deviceModel,
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Clock values comparison row
                      Row(
                        children: [
                          Expanded(
                            child: _buildClockBox(
                              label: context.tr('ntp_device_time'),
                              value: logic.deviceCurrentTime.isNotEmpty
                                  ? logic.deviceCurrentTime
                                  : '...',
                              icon: Icons.phone_android_rounded,
                              theme: theme,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildClockBox(
                              label: context.tr('ntp_pc_time'),
                              value: _formatDateTime(_currentPcTime),
                              icon: Icons.computer_rounded,
                              theme: theme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Drift status indicator and 1-Click Sync to PC button
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: drift.isSynced
                                  ? Colors.green.withValues(alpha: 0.15)
                                  : (drift.isDrifting
                                        ? Colors.amber.withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: drift.isSynced
                                    ? Colors.green.withValues(alpha: 0.4)
                                    : (drift.isDrifting
                                          ? Colors.amber.withValues(alpha: 0.5)
                                          : Colors.grey.withValues(alpha: 0.3)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  drift.isSynced
                                      ? Icons.check_circle_rounded
                                      : (drift.isDrifting
                                            ? Icons.warning_amber_rounded
                                            : Icons.help_outline_rounded),
                                  size: 14,
                                  color: drift.isSynced
                                      ? Colors.greenAccent
                                      : (drift.isDrifting
                                            ? Colors.amberAccent
                                            : theme.textSecondary),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  drift.isSynced
                                      ? '${context.tr('ntp_drift_synced')} (${drift.label})'
                                      : '${context.tr('ntp_drift_label')}: ${drift.label}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: drift.isSynced
                                        ? Colors.greenAccent
                                        : (drift.isDrifting
                                              ? Colors.amberAccent
                                              : theme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: (hasDevice && !logic.isSyncingTime)
                                ? () => _syncToPc(logic)
                                : null,
                            icon: logic.isSyncingTime
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.flash_on_rounded, size: 15),
                            label: Text(
                              context.tr('ntp_sync_to_pc_btn'),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF00ADB5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── 2. Thẻ Cấu hình Máy chủ NTP ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardBg.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.borderTheme.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.dns_rounded,
                            size: 16,
                            color: theme.colors.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.tr('ntp_server_config_title'),
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            context.tr('ntp_current_server'),
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              logic.deviceNtpServer.isNotEmpty
                                  ? logic.deviceNtpServer
                                  : context.tr('none'),
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: logic.deviceNtpServer.isNotEmpty
                                    ? const Color(0xFF00ADB5)
                                    : theme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Input row
                      TextField(
                        controller: _serverController,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                        decoration: InputDecoration(
                          hintText: context.tr('ntp_server_input_hint'),
                          hintStyle: TextStyle(
                            color: theme.textSecondary.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                          isDense: true,
                          prefixIcon: const Icon(
                            Icons.router_rounded,
                            size: 18,
                          ),
                          suffixIcon: _serverController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _serverController.clear();
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.black12,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: BorderSide(
                              color: theme.borderTheme.withValues(alpha: 0.3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(9),
                            borderSide: const BorderSide(
                              color: Color(0xFF00ADB5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Fast Presets
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${context.tr('ntp_presets_foxconn')}:',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: theme.textSecondary,
                            ),
                          ),
                          for (final p in _intranetPresets)
                            ActionChip(
                              label: Text(p),
                              labelStyle: const TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: const Color(
                                0xFF00ADB5,
                              ).withValues(alpha: 0.12),
                              side: BorderSide(
                                color: const Color(
                                  0xFF00ADB5,
                                ).withValues(alpha: 0.3),
                              ),
                              onPressed: () {
                                setState(() {
                                  _serverController.text = p;
                                });
                              },
                            ),
                          const SizedBox(width: 4),
                          Text(
                            '${context.tr('ntp_presets_public')}:',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: theme.textSecondary,
                            ),
                          ),
                          for (final p in _publicPresets)
                            ActionChip(
                              label: Text(p),
                              labelStyle: const TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                              ),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              side: BorderSide(
                                color: theme.borderTheme.withValues(alpha: 0.3),
                              ),
                              onPressed: () {
                                setState(() {
                                  _serverController.text = p;
                                });
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Action Buttons (Test & Apply)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: logic.isCheckingNtp
                                  ? null
                                  : () => _testServer(logic),
                              icon: logic.isCheckingNtp
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.network_check_rounded,
                                      size: 16,
                                    ),
                              label: Text(
                                context.tr('ntp_test_btn'),
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: (hasDevice && !logic.isSyncingTime)
                                  ? () => _applyServer(logic)
                                  : null,
                              icon: logic.isSyncingTime
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.sync_rounded, size: 16),
                              label: Text(
                                context.tr('ntp_apply_sync_btn'),
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00ADB5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 9,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── 3. Thẻ Quét Dò NTP Subnet Tự Động (/24 Scanner) ──
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.cardBg.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.borderTheme.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.radar_rounded,
                            size: 16,
                            color: theme.colors.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.tr('ntp_subnet_scanner_title'),
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _subnetController,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 12.5,
                                fontFamily: 'monospace',
                              ),
                              decoration: InputDecoration(
                                hintText: context.tr('ntp_subnet_input_hint'),
                                prefixIcon: const Icon(
                                  Icons.lan_rounded,
                                  size: 17,
                                ),
                                suffixText: '.1 - .254',
                                suffixStyle: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 11,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.black12,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: theme.borderTheme.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: logic.isScanningNtp
                                ? null
                                : () => _scanSubnet(logic),
                            icon: logic.isScanningNtp
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.search_rounded, size: 16),
                            label: Text(
                              logic.isScanningNtp
                                  ? context.tr('ntp_scanning')
                                  : context.tr('ntp_scan_btn'),
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Scanned server results
                      if (logic.discoveredNtpServers.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          context.tr(
                            'ntp_servers_found',
                            args: {
                              'count': logic.discoveredNtpServers.length
                                  .toString(),
                            },
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.greenAccent.shade400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: logic.discoveredNtpServers.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final item = logic.discoveredNtpServers[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: theme.borderTheme.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: Colors.greenAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      item.host,
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontFamily: 'monospace',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${item.roundTripMs}ms',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white10,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Stratum ${item.stratum}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.textSecondary,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    FilledButton(
                                      onPressed: () {
                                        setState(() {
                                          _serverController.text = item.host;
                                        });
                                        _applyServer(logic);
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF00ADB5,
                                        ),
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 3,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        context.tr('ntp_use_server_btn'),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── 4. Nhật Ký Chẩn Đoán & Logs (Collapsible) ──
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardBg.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.borderTheme.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _showDiagnostics = !_showDiagnostics;
                          });
                          if (_showDiagnostics &&
                              logic.ntpDiagnosticLogs.isEmpty &&
                              hasDevice) {
                            logic.loadTimeDiagnostics();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.terminal_rounded,
                                size: 16,
                                color: theme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('ntp_diagnostics_title'),
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showDiagnostics
                                    ? Icons.expand_less_rounded
                                    : Icons.expand_more_rounded,
                                size: 18,
                                color: theme.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showDiagnostics) ...[
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: hasDevice
                                        ? () => logic.loadTimeDiagnostics()
                                        : null,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 14,
                                    ),
                                    label: Text(
                                      context.tr('ntp_view_diagnostics_btn'),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (logic.ntpDiagnosticLogs.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 15,
                                      ),
                                      tooltip: context.tr('copy'),
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: logic.ntpDiagnosticLogs,
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(context.tr('copied')),
                                            duration: const Duration(
                                              seconds: 2,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 180,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: theme.borderTheme.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  child: SelectableText(
                                    logic.ntpDiagnosticLogs.isNotEmpty
                                        ? logic.ntpDiagnosticLogs
                                        : 'Chưa có dữ liệu chẩn đoán.',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10.5,
                                      color: Colors.white70,
                                      height: 1.35,
                                    ),
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

                // Status message banner
                if (logic.ntpStatusMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00ADB5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF00ADB5).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: Color(0xFF00ADB5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            logic.ntpStatusMessage,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: theme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 14),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => logic.clearNtpStatusMessage(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildClockBox({
    required String label,
    required String value,
    required IconData icon,
    required ThemeProvider theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.borderTheme.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: const Color(0xFF00ADB5)),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: theme.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DriftInfo {
  final bool isSynced;
  final String label;
  final bool isDrifting;

  const _DriftInfo({
    required this.isSynced,
    required this.label,
    required this.isDrifting,
  });

  const _DriftInfo.unknown()
    : isSynced = false,
      label = '--',
      isDrifting = false;
}
