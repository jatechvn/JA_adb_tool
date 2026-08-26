import 'dart:convert';
import 'dart:io';

class AdbCommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const AdbCommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get isSuccess => exitCode == 0;
  String get combinedOutput => [
    stdout.trim(),
    stderr.trim(),
  ].where((value) => value.isNotEmpty).join('\n');
}

class AdbDeviceInfo {
  final String id;
  final String state;

  const AdbDeviceInfo({required this.id, required this.state});
}

class AdbService {
  const AdbService();

  Future<AdbCommandResult> run(
    String executable,
    List<String> arguments,
  ) async {
    if (executable.trim().isEmpty) {
      return const AdbCommandResult(
        exitCode: -1,
        stdout: '',
        stderr: 'ADB executable is not configured.',
      );
    }

    try {
      final result = await Process.run(
        executable,
        arguments,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return AdbCommandResult(
        exitCode: result.exitCode,
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
      );
    } on Object catch (error) {
      return AdbCommandResult(
        exitCode: -1,
        stdout: '',
        stderr: error.toString(),
      );
    }
  }

  Future<AdbCommandResult> connect(String executable, String endpoint) {
    return run(executable, ['connect', endpoint]);
  }

  Future<AdbCommandResult> disconnect(String executable, String endpoint) {
    return run(executable, ['disconnect', endpoint]);
  }

  Future<List<AdbDeviceInfo>> listDevices(String executable) async {
    final result = await run(executable, ['devices']);
    if (!result.isSuccess) return const [];

    return result.stdout
        .split(RegExp(r'\r?\n'))
        .skip(1)
        .map((line) => line.trim().split(RegExp(r'\s+')))
        .where((parts) => parts.length >= 2 && parts.first.isNotEmpty)
        .map((parts) => AdbDeviceInfo(id: parts.first, state: parts[1]))
        .toList(growable: false);
  }

  Future<Map<String, String>> readDeviceDetails(
    String executable,
    String deviceId,
  ) async {
    final model = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'getprop',
      'ro.product.model',
    ]);
    final version = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'getprop',
      'ro.build.version.release',
    ]);
    return {
      'model': model.isSuccess && model.stdout.trim().isNotEmpty
          ? model.stdout.trim()
          : 'Android Device',
      'version': version.isSuccess && version.stdout.trim().isNotEmpty
          ? version.stdout.trim()
          : 'Unknown',
    };
  }
}
