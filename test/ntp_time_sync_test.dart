import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/logic.dart';

ProcessResult _ok([String text = '']) => ProcessResult(1, 0, text, '');
ProcessResult _fail([String text = 'error']) => ProcessResult(1, 1, '', text);

void main() {
  group('NtpQueryResult Model Tests', () {
    test('NtpQueryResult.success creates valid active result', () {
      final now = DateTime.now();
      final res = NtpQueryResult.success(
        host: '10.81.184.80',
        serverTime: now,
        roundTripMs: 15,
        stratum: 2,
      );

      expect(res.isSuccess, isTrue);
      expect(res.host, '10.81.184.80');
      expect(res.serverTime, now);
      expect(res.roundTripMs, 15);
      expect(res.stratum, 2);
      expect(res.errorMessage, isNull);
    });

    test('NtpQueryResult.failure creates failed result with error message', () {
      final res = NtpQueryResult.failure('192.0.2.1', 'Connection timed out');

      expect(res.isSuccess, isFalse);
      expect(res.host, '192.0.2.1');
      expect(res.serverTime, isNull);
      expect(res.roundTripMs, 0);
      expect(res.stratum, 0);
      expect(res.errorMessage, 'Connection timed out');
    });
  });

  group('AdbService NTP Helpers with Mock Runner', () {
    test('getDeviceTime returns parsed time string from adb output', () async {
      final service = AdbService(
        runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          expect(args.contains('date "+%Y-%m-%d %H:%M:%S %Z"'), isTrue);
          return _ok('2026-03-01 02:22:31 ICT\n');
        },
      );

      final time = await service.getDeviceTime('adb', 'dev1');
      expect(time, '2026-03-01 02:22:31 ICT');
    });

    test(
      'getDeviceNtpServer returns configured server or null if null',
      () async {
        final service1 = AdbService(
          runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
            return _ok('10.81.184.80\n');
          },
        );
        expect(
          await service1.getDeviceNtpServer('adb', 'dev1'),
          '10.81.184.80',
        );

        final service2 = AdbService(
          runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
            return _ok('null\n');
          },
        );
        expect(await service2.getDeviceNtpServer('adb', 'dev1'), isNull);
      },
    );

    test(
      'setDeviceNtpServer updates global ntp_server and enables auto_time',
      () async {
        final commandsExecuted = <String>[];
        final service = AdbService(
          runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
            commandsExecuted.add(args.join(' '));
            return _ok();
          },
        );

        final success = await service.setDeviceNtpServer(
          'adb',
          'dev1',
          '10.81.184.80',
        );
        expect(success, isTrue);
        expect(
          commandsExecuted.any(
            (cmd) =>
                cmd.contains('settings put global ntp_server 10.81.184.80'),
          ),
          isTrue,
        );
        expect(
          commandsExecuted.any(
            (cmd) => cmd.contains('settings put global auto_time 1'),
          ),
          isTrue,
        );
      },
    );

    test('pingDeviceHost tests IP connectivity from Android shell', () async {
      final service = AdbService(
        runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          if (args.any((a) => a.contains('10.81.184.80'))) {
            return _ok(
              '64 bytes from 10.81.184.80: icmp_seq=1 ttl=64 time=2.1 ms',
            );
          }
          return _fail('100% packet loss');
        },
      );

      expect(
        await service.pingDeviceHost('adb', 'dev1', '10.81.184.80'),
        isTrue,
      );
      expect(await service.pingDeviceHost('adb', 'dev1', '192.0.2.1'), isFalse);
    });

    test('forceDeviceTimeSync triggers airplane mode cycle', () async {
      final commandsExecuted = <String>[];
      final service = AdbService(
        runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          commandsExecuted.add(args.join(' '));
          return _ok();
        },
      );

      final ok = await service.forceDeviceTimeSync('adb', 'dev1');
      expect(ok, isTrue);
      expect(
        commandsExecuted.any((cmd) => cmd.contains('airplane-mode enable')),
        isTrue,
      );
    });

    test(
      'syncDeviceTimeToHost sets date via fallback syntax and disables auto_time',
      () async {
        final commandsExecuted = <String>[];
        final service = AdbService(
          runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
            commandsExecuted.add(args.join(' '));
            return _ok();
          },
        );

        final targetTime = DateTime(2026, 3, 17, 10, 30, 45);
        final ok = await service.syncDeviceTimeToHost(
          'adb',
          'dev1',
          targetTime,
        );

        expect(ok, isTrue);
        expect(
          commandsExecuted.any(
            (cmd) => cmd.contains('settings put global auto_time 0'),
          ),
          isTrue,
        );
        expect(
          commandsExecuted.any(
            (cmd) => cmd.contains('date -u @') || cmd.contains('date '),
          ),
          isTrue,
        );
      },
    );

    test('getDeviceTimeDiagnostics returns dumpsys output', () async {
      final service = AdbService(
        runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          return _ok(
            '=== TIME DETECTOR ===\nmTimeDetector=true\n=== NETWORK TIME ===\n',
          );
        },
      );

      final logs = await service.getDeviceTimeDiagnostics('adb', 'dev1');
      expect(logs, contains('TIME DETECTOR'));
      expect(logs, contains('NETWORK TIME'));
    });
  });

  group('AppLogic NTP Integration with Mock AdbService', () {
    test('loadDeviceTimeAndNtp populates state variables', () async {
      final mockService = AdbService(
        runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          final joined = args.join(' ');
          if (joined.contains('date "+%Y-%m-%d')) {
            return _ok('2026-03-17 11:30:00 ICT');
          }
          if (joined.contains('settings get global ntp_server')) {
            return _ok('10.81.184.80');
          }
          return _ok();
        },
      );

      final logic = AppLogic(
        initialize: false,
        adbPath: 'adb',
        adbService: mockService,
      );

      // Simulate device selection
      await logic.selectDevice('device_test_123');
      await logic.loadDeviceTimeAndNtp();

      expect(logic.deviceCurrentTime, '2026-03-17 11:30:00 ICT');
      expect(logic.deviceNtpServer, '10.81.184.80');
    });

    test('applyNtpServerAndSync configures server and updates state', () async {
      String? serverSet;
      final mockService = AdbService(
        runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
          final joined = args.join(' ');
          if (joined.contains('settings put global ntp_server')) {
            serverSet = joined.split(' ').last;
            return _ok();
          }
          if (joined.contains('settings get global ntp_server')) {
            return _ok(serverSet ?? '');
          }
          if (joined.contains('date "+%Y-%m-%d')) {
            return _ok('2026-03-17 11:35:00 ICT');
          }
          return _ok();
        },
      );

      final logic = AppLogic(
        initialize: false,
        adbPath: 'adb',
        adbService: mockService,
      );

      await logic.selectDevice('device_test_123');
      final result = await logic.applyNtpServerAndSync('10.81.184.80');

      expect(result, isTrue);
      expect(logic.deviceNtpServer, '10.81.184.80');
      expect(logic.ntpStatusMessage, contains('successfully'));
    });

    test(
      'syncDeviceToPcTime triggers direct host time synchronization',
      () async {
        bool dateCommandCalled = false;
        final mockService = AdbService(
          runner: (exe, args, {stderrEncoding, stdoutEncoding}) async {
            final joined = args.join(' ');
            if (joined.contains('date -u @') || joined.contains('date "')) {
              dateCommandCalled = true;
            }
            if (joined.contains('date "+%Y-%m-%d')) {
              return _ok('2026-03-17 11:40:00 ICT');
            }
            return _ok();
          },
        );

        final logic = AppLogic(
          initialize: false,
          adbPath: 'adb',
          adbService: mockService,
        );

        await logic.selectDevice('device_test_123');
        final ok = await logic.syncDeviceToPcTime();

        expect(ok, isTrue);
        expect(dateCommandCalled, isTrue);
        expect(logic.deviceCurrentTime, '2026-03-17 11:40:00 ICT');
      },
    );
  });
}
