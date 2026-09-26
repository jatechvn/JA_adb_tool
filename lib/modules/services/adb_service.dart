import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class NtpQueryResult {
  final bool isSuccess;
  final String host;
  final DateTime? serverTime;
  final int roundTripMs;
  final int stratum;
  final String? errorMessage;

  const NtpQueryResult({
    required this.isSuccess,
    required this.host,
    this.serverTime,
    this.roundTripMs = 0,
    this.stratum = 0,
    this.errorMessage,
  });

  factory NtpQueryResult.success({
    required String host,
    required DateTime serverTime,
    required int roundTripMs,
    required int stratum,
  }) => NtpQueryResult(
    isSuccess: true,
    host: host,
    serverTime: serverTime,
    roundTripMs: roundTripMs,
    stratum: stratum,
  );

  factory NtpQueryResult.failure(String host, String errorMessage) =>
      NtpQueryResult(isSuccess: false, host: host, errorMessage: errorMessage);
}

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

typedef AdbProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      Encoding? stdoutEncoding,
      Encoding? stderrEncoding,
    });

class AdbService {
  final AdbProcessRunner? runner;

  const AdbService({this.runner});

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
      final activeRunner = runner ?? Process.run;
      final result = await activeRunner(
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

  /// Sets runtime and persistent ADB TCP port properties on the device.
  Future<AdbCommandResult> setAdbTcpPort(
    String executable,
    String deviceId,
    int port,
  ) async {
    await run(executable, [
      '-s',
      deviceId,
      'shell',
      'setprop',
      'service.adb.tcp.port',
      '$port',
    ]);
    return run(executable, [
      '-s',
      deviceId,
      'shell',
      'setprop',
      'persist.adb.tcp.port',
      '$port',
    ]);
  }

  /// Restarts adbd on the device listening on the specified TCP/IP port.
  Future<AdbCommandResult> restartTcpip(
    String executable,
    String deviceId,
    int port,
  ) {
    return run(executable, ['-s', deviceId, 'tcpip', '$port']);
  }

  /// Queries the device for its active local Wi-Fi / Ethernet IPv4 address.
  Future<String?> getDeviceIp(String executable, String deviceId) async {
    // 1. Try DHCP property for wlan0
    final dhcp = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'getprop',
      'dhcp.wlan0.ipaddress',
    ]);
    final dhcpIp = dhcp.stdout.trim();
    if (isValidIpv4(dhcpIp)) {
      return dhcpIp;
    }

    // 2. Try ip -f inet addr show wlan0
    final ipWlan0 = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'ip',
      '-f',
      'inet',
      'addr',
      'show',
      'wlan0',
    ]);
    final parsedWlan0 = extractIpv4(ipWlan0.stdout);
    if (parsedWlan0 != null) {
      return parsedWlan0;
    }

    // 3. Try ip route show
    final ipRoute = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'ip',
      'route',
    ]);
    final routeIp = extractRouteSrcIpv4(ipRoute.stdout);
    if (routeIp != null) {
      return routeIp;
    }

    // 4. Fallback: all inet addresses excluding loopback
    final ipAll = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'ip',
      '-f',
      'inet',
      'addr',
    ]);
    return extractIpv4(ipAll.stdout);
  }

  /// Disconnects any old/ephemeral port endpoints for the same IP (e.g. 192.168.1.5:41979)
  /// when connecting to a fixed port (e.g. 5555).
  Future<List<String>> disconnectStaleEndpoints(
    String executable,
    String host,
    int activePort,
  ) async {
    final devices = await listDevices(executable);
    final disconnected = <String>[];
    for (final device in devices) {
      final id = device.id;
      if (id.startsWith('$host:')) {
        final colon = id.lastIndexOf(':');
        if (colon != -1) {
          final port = int.tryParse(id.substring(colon + 1));
          if (port != null && port != activePort) {
            final res = await disconnect(executable, id);
            if (res.isSuccess) {
              disconnected.add(id);
            }
          }
        }
      }
    }
    return disconnected;
  }

  /// Retrieves the installed APK file paths on device for [packageName] via `pm path`.
  Future<List<String>> getAppApkPaths(
    String executable, {
    required String deviceId,
    required String packageName,
  }) async {
    final result = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'pm',
      'path',
      packageName,
    ]);
    if (!result.isSuccess) return const [];
    return parsePmPathOutput(result.stdout);
  }

  /// Parses raw output of `pm path <package>` into a list of APK file paths on Android.
  static List<String> parsePmPathOutput(String stdout) {
    return stdout
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .map(
          (line) => line.startsWith('package:')
              ? line.substring('package:'.length).trim()
              : line,
        )
        .where((path) => path.isNotEmpty && path.endsWith('.apk'))
        .toList(growable: false);
  }

  static bool isValidIpv4(String ip) {
    if (ip.isEmpty || ip == '127.0.0.1') return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  static String? extractIpv4(String text) {
    final regex = RegExp(
      r'inet\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(?:/\d+)?',
    );
    for (final match in regex.allMatches(text)) {
      final ip = match.group(1);
      if (ip != null && isValidIpv4(ip)) {
        return ip;
      }
    }
    return null;
  }

  static String? extractRouteSrcIpv4(String text) {
    final regex = RegExp(r'\bsrc\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b');
    for (final match in regex.allMatches(text)) {
      final ip = match.group(1);
      if (ip != null && isValidIpv4(ip)) {
        return ip;
      }
    }
    return null;
  }

  /// Pure Dart UDP client to query an NTP server (port 123).
  static Future<NtpQueryResult> queryNtpServer(
    String host, {
    int port = 123,
    Duration timeout = const Duration(milliseconds: 1600),
  }) async {
    final sw = Stopwatch()..start();
    RawDatagramSocket? socket;
    Timer? timer;
    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) {
        return NtpQueryResult.failure(host, 'DNS lookup failed');
      }
      final address = addresses.first;
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final packet = Uint8List(48);
      packet[0] = 0x1B; // LI=0, VN=3, Mode=3 (client)
      socket.send(packet, address, port);

      final completer = Completer<NtpQueryResult>();
      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(
            NtpQueryResult.failure(
              host,
              'Timeout (${timeout.inMilliseconds}ms)',
            ),
          );
        }
      });

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket?.receive();
          if (dg != null && dg.data.length >= 48) {
            sw.stop();
            final data = ByteData.sublistView(dg.data);
            final secondsSince1900 = data.getUint32(40);
            if (secondsSince1900 > 2208988800) {
              final unixSec = secondsSince1900 - 2208988800;
              final serverTime = DateTime.fromMillisecondsSinceEpoch(
                unixSec * 1000,
                isUtc: true,
              ).toLocal();
              final stratum = dg.data[1];
              if (!completer.isCompleted) {
                completer.complete(
                  NtpQueryResult.success(
                    host: host,
                    serverTime: serverTime,
                    roundTripMs: sw.elapsedMilliseconds,
                    stratum: stratum,
                  ),
                );
              }
            }
          }
        }
      });

      final result = await completer.future;
      return result;
    } catch (e) {
      return NtpQueryResult.failure(host, e.toString());
    } finally {
      timer?.cancel();
      socket?.close();
    }
  }

  /// Scans an entire /24 IPv4 subnet concurrently via pure Dart UDP socket
  /// to discover active, responsive NTP servers in ~1.5 seconds.
  static Future<List<NtpQueryResult>> scanNtpSubnet(
    String subnetPrefix, {
    Duration timeout = const Duration(milliseconds: 1800),
  }) async {
    var prefix = subnetPrefix.trim();
    if (prefix.endsWith('.')) {
      prefix = prefix.substring(0, prefix.length - 1);
    }
    final parts = prefix.split('.');
    if (parts.length >= 3) {
      prefix = '${parts[0]}.${parts[1]}.${parts[2]}';
    } else {
      return [];
    }

    final found = <String, NtpQueryResult>{};
    RawDatagramSocket? socket;
    final completer = Completer<List<NtpQueryResult>>();
    final swMap = <String, Stopwatch>{};

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      final packet = Uint8List(48);
      packet[0] = 0x1B;

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          while (true) {
            final dg = socket?.receive();
            if (dg == null) break;
            if (dg.data.length >= 48) {
              final fromIp = dg.address.address;
              final sw = swMap[fromIp];
              sw?.stop();
              final rtt = sw?.elapsedMilliseconds ?? 0;

              final data = ByteData.sublistView(dg.data);
              final secondsSince1900 = data.getUint32(40);
              if (secondsSince1900 > 2208988800) {
                final unixSec = secondsSince1900 - 2208988800;
                final serverTime = DateTime.fromMillisecondsSinceEpoch(
                  unixSec * 1000,
                  isUtc: true,
                ).toLocal();
                final stratum = dg.data[1];
                found[fromIp] = NtpQueryResult.success(
                  host: fromIp,
                  serverTime: serverTime,
                  roundTripMs: rtt,
                  stratum: stratum,
                );
              }
            }
          }
        }
      });

      for (var i = 1; i <= 254; i++) {
        final targetIp = '$prefix.$i';
        swMap[targetIp] = Stopwatch()..start();
        try {
          socket.send(packet, InternetAddress(targetIp), 123);
          await Future<void>.delayed(const Duration(milliseconds: 3));
        } catch (_) {}
      }

      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(found.values.toList());
        }
      });

      final results = await completer.future;
      results.sort((a, b) => a.roundTripMs.compareTo(b.roundTripMs));
      return results;
    } catch (_) {
      return found.values.toList();
    } finally {
      socket?.close();
    }
  }

  /// Reads current system date/time from the device via ADB.
  Future<String?> getDeviceTime(String executable, String deviceId) async {
    final result = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'date "+%Y-%m-%d %H:%M:%S %Z"',
    ]);
    if (result.isSuccess && result.stdout.trim().isNotEmpty) {
      final out = result.stdout.trim();
      if (!out.startsWith('date [') &&
          !out.contains('usage:') &&
          !out.contains('invalid')) {
        return out;
      }
    }
    // Fallback for Android toolbox or shells that don't support custom date format string
    final fallback = await run(executable, ['-s', deviceId, 'shell', 'date']);
    if (fallback.isSuccess && fallback.stdout.trim().isNotEmpty) {
      return fallback.stdout.trim();
    }
    return null;
  }

  /// Reads current configured NTP server from Android global settings.
  Future<String?> getDeviceNtpServer(String executable, String deviceId) async {
    final result = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'settings get global ntp_server',
    ]);
    if (result.isSuccess) {
      final val = result.stdout.trim();
      if (val.isNotEmpty && val.toLowerCase() != 'null') {
        return val;
      }
    }
    return null;
  }

  /// Sets global ntp_server on device and ensures auto_time is enabled (1).
  Future<bool> setDeviceNtpServer(
    String executable,
    String deviceId,
    String server,
  ) async {
    final res1 = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'settings put global ntp_server $server',
    ]);
    final res2 = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'settings put global auto_time 1',
    ]);
    return res1.isSuccess && res2.isSuccess;
  }

  /// Pings a host from the Android device to check device-to-server IP connectivity.
  Future<bool> pingDeviceHost(
    String executable,
    String deviceId,
    String host, {
    int count = 2,
    int timeout = 1,
  }) async {
    final result = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'ping -c $count -W $timeout $host',
    ]);
    return result.isSuccess;
  }

  /// Forces Android to refresh network time by toggling airplane mode or network interfaces.
  Future<bool> forceDeviceTimeSync(String executable, String deviceId) async {
    final res = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'cmd connectivity airplane-mode enable 2>/dev/null && sleep 1 && cmd connectivity airplane-mode disable 2>/dev/null || (settings put global airplane_mode_on 1 && am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true 2>/dev/null && sleep 1 && settings put global airplane_mode_on 0 && am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false 2>/dev/null) || (svc wifi disable 2>/dev/null && sleep 1 && svc wifi enable 2>/dev/null)',
    ]);
    return res.isSuccess;
  }

  /// Directly sets the Android device system clock to match the host PC's time.
  /// Used as a 1-click rescue fallback when no network or NTP server is available.
  Future<bool> syncDeviceTimeToHost(
    String executable,
    String deviceId,
    DateTime hostTime,
  ) async {
    final epochMs = hostTime.millisecondsSinceEpoch;
    final y = hostTime.year.toString().padLeft(4, '0');
    final m = hostTime.month.toString().padLeft(2, '0');
    final d = hostTime.day.toString().padLeft(2, '0');
    final hh = hostTime.hour.toString().padLeft(2, '0');
    final mm = hostTime.minute.toString().padLeft(2, '0');
    final ss = hostTime.second.toString().padLeft(2, '0');

    // 1. Temporarily disable auto_time so manual date change is accepted
    await run(executable, [
      '-s',
      deviceId,
      'shell',
      'settings put global auto_time 0',
    ]);

    // 2. Set date using multi-version compatible syntax:
    // First try 'cmd alarm set-time <epochMs>' which works on Android 8.0+ non-root shell.
    // Next try 'date -s YYYYMMDD.hhmmss' which is supported by Android toolbox (Android 4.x/5.x/6.x).
    // Next try 'date -s "YYYY-MM-DD hh:mm:ss"' which is supported by toybox/busybox.
    // Finally try 'date MMDDhhmmYYYY.ss'.
    // NOTE: NEVER use 'date -u @...' as toolbox misparses @ as 0.0, resetting clock to 1969 with exit code 0!
    final setDateRes = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'cmd alarm set-time $epochMs 2>/dev/null || date -s "$y$m$d.$hh$mm$ss" 2>/dev/null || date -s "$y-$m-$d $hh:$mm:$ss" 2>/dev/null || date "$m$d$hh$mm$y.$ss" 2>/dev/null',
    ]);
    return setDateRes.isSuccess;
  }

  /// Fetches time detector, network time update service, and recent NTP logcat dumps.
  Future<String> getDeviceTimeDiagnostics(
    String executable,
    String deviceId,
  ) async {
    final result = await run(executable, [
      '-s',
      deviceId,
      'shell',
      'echo "=== TIME DETECTOR ==="; dumpsys time_detector; echo "\n=== NETWORK TIME UPDATE SERVICE ==="; dumpsys network_time_update_service; echo "\n=== LOGCAT NTP ==="; logcat -d -t 25 -s NetworkTimeUpdateService,TimeDetector,NtpTrustedTime',
    ]);
    return result.combinedOutput;
  }
}
