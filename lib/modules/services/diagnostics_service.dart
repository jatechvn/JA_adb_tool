import 'dart:io';

import 'adb_service.dart';

enum DiagnosticStatus { pass, warning, fail }

class DiagnosticCheck {
  final String key;
  final String title;
  final DiagnosticStatus status;
  final String details;

  const DiagnosticCheck({
    required this.key,
    required this.title,
    required this.status,
    required this.details,
  });
}

class DiagnosticsReport {
  final DateTime generatedAt;
  final List<DiagnosticCheck> checks;

  const DiagnosticsReport({required this.generatedAt, required this.checks});

  bool get hasFailure =>
      checks.any((check) => check.status == DiagnosticStatus.fail);

  String get plainText => checks
      .map(
        (check) =>
            '[${check.status.name.toUpperCase()}] ${check.title}: ${check.details}',
      )
      .join('\n');
}

class DiagnosticsService {
  final AdbService adbService;

  const DiagnosticsService({this.adbService = const AdbService()});

  Future<DiagnosticsReport> run({
    required String adbPath,
    required String scrcpyPath,
    required String gnirehtetPath,
    String? selectedDevice,
  }) async {
    final checks = <DiagnosticCheck>[];
    checks.add(_fileCheck('adb_path', 'ADB executable', adbPath));
    checks.add(_fileCheck('scrcpy_path', 'Scrcpy executable', scrcpyPath));
    checks.add(
      _fileCheck('gnirehtet_path', 'Gnirehtet executable', gnirehtetPath),
    );

    final adbVersion = await adbService.run(adbPath, ['version']);
    checks.add(
      DiagnosticCheck(
        key: 'adb_command',
        title: 'ADB command',
        status: adbVersion.isSuccess
            ? DiagnosticStatus.pass
            : DiagnosticStatus.fail,
        details: adbVersion.isSuccess
            ? adbVersion.combinedOutput.split('\n').first
            : adbVersion.combinedOutput,
      ),
    );

    final devices = await adbService.listDevices(adbPath);
    final connected = devices.where((device) => device.state == 'device');
    checks.add(
      DiagnosticCheck(
        key: 'device_scan',
        title: 'Device scan',
        status: connected.isNotEmpty
            ? DiagnosticStatus.pass
            : DiagnosticStatus.warning,
        details: connected.isNotEmpty
            ? '${connected.length} device(s) authorized'
            : 'No authorized Android device found',
      ),
    );

    if (selectedDevice != null && selectedDevice.isNotEmpty) {
      final selected = devices.where((device) => device.id == selectedDevice);
      final exists = selected.isNotEmpty && selected.first.state == 'device';
      checks.add(
        DiagnosticCheck(
          key: 'selected_device',
          title: 'Selected device',
          status: exists ? DiagnosticStatus.pass : DiagnosticStatus.warning,
          details: exists
              ? '$selectedDevice is authorized'
              : '$selectedDevice is not currently authorized',
        ),
      );
    }

    return DiagnosticsReport(generatedAt: DateTime.now(), checks: checks);
  }

  DiagnosticCheck _fileCheck(String key, String title, String path) {
    if (path.trim().isEmpty) {
      return DiagnosticCheck(
        key: key,
        title: title,
        status: DiagnosticStatus.warning,
        details: 'Path is not configured',
      );
    }
    final file = File(path);
    return DiagnosticCheck(
      key: key,
      title: title,
      status: file.existsSync() ? DiagnosticStatus.pass : DiagnosticStatus.fail,
      details: file.existsSync() ? path : 'File not found: $path',
    );
  }
}
