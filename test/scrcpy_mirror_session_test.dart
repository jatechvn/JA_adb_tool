import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/logic.dart';

class FakeMirrorProcess implements Process {
  final Completer<int> exitCompleter = Completer<int>();
  final StreamController<List<int>> stdoutController =
      StreamController<List<int>>.broadcast();
  final StreamController<List<int>> stderrController =
      StreamController<List<int>>.broadcast();
  final int _pid;

  FakeMirrorProcess({this._pid = 1234});

  void dispose() {
    stdoutController.close();
    stderrController.close();
  }

  @override
  int get pid => _pid;

  @override
  Future<int> get exitCode => exitCompleter.future;

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!exitCompleter.isCompleted) {
      exitCompleter.complete(143);
    }
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestMirrorLogic extends AppLogic {
  TestMirrorLogic({AdbProcessRunner? runner, super.scrcpyStarter})
    : super(
        initialize: false,
        adbPath: 'fake-adb',
        processRunner:
            runner ??
            ((
              exe,
              args, {
              Encoding? stdoutEncoding,
              Encoding? stderrEncoding,
            }) async => ProcessResult(1, 0, '', '')),
      ) {
    mirrorEmbedInitialDelay = Duration.zero;
    mirrorEmbedPollInterval = Duration.zero;
    mirrorEmbedMaxAttempts = 0;
    mirrorRetryDelay = Duration.zero;
    setScrcpyPathForTesting('C:\\tools\\scrcpy.exe');
    setSelectedDeviceForTesting('device-123');
  }

  @override
  Future<void> loadDeviceSyncSettings(String deviceId) async {}
  @override
  Future<void> fetchLatestMedia({bool force = false}) async {}
  @override
  Future<void> loadAndroidDirectory(String path) async {}
  @override
  Future<String?> detectSelectedDeviceWifiIp() async => null;
}

void main() {
  for (final action in ['stop', 'restart', 'switch', 'dispose']) {
    testWidgets('retry delay respects $action', (tester) async {
      final processes = <FakeMirrorProcess>[];
      final logic = TestMirrorLogic(
        scrcpyStarter: (_, _) async {
          final proc = FakeMirrorProcess();
          processes.add(proc);
          return proc;
        },
      );
      logic.mirrorRetryDelay = const Duration(seconds: 1);
      await logic.launchMirroring();
      processes.first.exitCompleter.complete(1);
      await tester.pump();
      if (action == 'dispose') {
        logic.dispose();
      } else if (action == 'switch') {
        await logic.selectDevice('device-456');
      } else {
        logic.stopMirroring();
        if (action == 'restart') await logic.launchMirroring();
      }
      await tester.pump(const Duration(seconds: 1));
      expect(processes.length, action == 'restart' ? 2 : 1);
      expect(
        logic.mirrorState,
        action == 'restart' ? MirrorState.starting : MirrorState.stopped,
      );
      if (action != 'dispose') logic.dispose();
      for (final proc in processes) {
        proc.dispose();
      }
      await tester.pump();
    });
  }

  for (final initial in [true, false]) {
    testWidgets('dispose cancels ${initial ? 'initial' : 'poll'} embed timer', (
      tester,
    ) async {
      final proc = FakeMirrorProcess();
      final logic = TestMirrorLogic(scrcpyStarter: (_, _) async => proc);
      logic.mirrorEmbedMaxAttempts = 30;
      logic.mirrorEmbedInitialDelay = initial
          ? const Duration(seconds: 2)
          : Duration.zero;
      logic.mirrorEmbedPollInterval = const Duration(milliseconds: 200);
      await logic.launchMirroring();
      await tester.pump();
      logic.dispose();
      proc.dispose();
      await tester.pump();
      // testWidgets verifies there are no pending timers without advancing time.
    });
  }

  testWidgets('cancel while retry spawn awaits cannot restore error', (
    tester,
  ) async {
    final first = FakeMirrorProcess();
    final retry = FakeMirrorProcess();
    final pending = Completer<Process>();
    var starts = 0;
    final logic = TestMirrorLogic(
      scrcpyStarter: (_, _) async {
        return ++starts == 1 ? first : await pending.future;
      },
    );
    await logic.launchMirroring();
    first.exitCompleter.complete(1);
    await tester.pump();
    expect(starts, 2);
    logic.stopMirroring();
    pending.complete(retry);
    await tester.pump();
    expect(logic.mirrorState, MirrorState.stopped);
    expect(retry.exitCompleter.isCompleted, isTrue);
    logic.dispose();
    first.dispose();
    retry.dispose();
    await tester.pump();
  });

  group('ScrcpyQualityPreset tests', () {
    test('standard presets have expected values', () {
      expect(ScrcpyQualityPreset.low.id, 'low');
      expect(ScrcpyQualityPreset.low.maxSize, 1024);
      expect(ScrcpyQualityPreset.low.maxFps, 30);
      expect(ScrcpyQualityPreset.low.bitRate, 3);

      expect(ScrcpyQualityPreset.balanced.id, 'balanced');
      expect(ScrcpyQualityPreset.balanced.maxSize, 1600);
      expect(ScrcpyQualityPreset.balanced.maxFps, 60);
      expect(ScrcpyQualityPreset.balanced.bitRate, 6);

      expect(ScrcpyQualityPreset.high.id, 'high');
      expect(ScrcpyQualityPreset.high.maxSize, 1920);
      expect(ScrcpyQualityPreset.high.maxFps, 60);
      expect(ScrcpyQualityPreset.high.bitRate, 10);
    });

    test('fromId returns correct preset or defaults to balanced', () {
      expect(ScrcpyQualityPreset.fromId('low').id, 'low');
      expect(ScrcpyQualityPreset.fromId('balanced').id, 'balanced');
      expect(ScrcpyQualityPreset.fromId('high').id, 'high');
      expect(ScrcpyQualityPreset.fromId('unknown').id, 'balanced');
      expect(ScrcpyQualityPreset.fromId(null).id, 'balanced');
    });
  });

  group('ScrcpyProfile serialization & migration tests', () {
    test('toJson and fromJson preserve preset and quality limits', () {
      const profile = ScrcpyProfile(
        name: 'Gamer Profile',
        stayOnTop: true,
        fullscreen: false,
        noControl: false,
        keepAwake: true,
        borderless: true,
        noAudio: false,
        preset: 'high',
        maxSize: 1920,
        maxFps: 60,
        bitRate: 10,
      );

      final json = profile.toJson();
      expect(json['name'], 'Gamer Profile');
      expect(json['preset'], 'high');
      expect(json['maxSize'], 1920);
      expect(json['maxFps'], 60);
      expect(json['bitRate'], 10);

      final reconstructed = ScrcpyProfile.fromJson(json);
      expect(reconstructed.name, profile.name);
      expect(reconstructed.stayOnTop, true);
      expect(reconstructed.keepAwake, true);
      expect(reconstructed.borderless, true);
      expect(reconstructed.preset, 'high');
      expect(reconstructed.maxSize, 1920);
      expect(reconstructed.maxFps, 60);
      expect(reconstructed.bitRate, 10);
    });

    test(
      'fromJson gracefully falls back for legacy profiles without preset',
      () {
        final legacyJson = {
          'name': 'Legacy Profile',
          'stayOnTop': false,
          'fullscreen': true,
          'noControl': true,
          'keepAwake': false,
          'borderless': false,
          'noAudio': true,
        };

        final profile = ScrcpyProfile.fromJson(legacyJson);
        expect(profile.name, 'Legacy Profile');
        expect(profile.fullscreen, true);
        expect(profile.noControl, true);
        expect(profile.noAudio, true);
        expect(profile.preset, 'balanced');
        expect(profile.maxSize, 1600);
        expect(profile.maxFps, 60);
        expect(profile.bitRate, 6);
      },
    );
  });

  group('AppLogic.buildScrcpyArgs tests', () {
    test('builds standard embedded arguments with balanced preset', () {
      final args = AppLogic.buildScrcpyArgs(
        serial: 'emulator-5554',
        preset: 'balanced',
      );

      expect(args, contains('-s'));
      expect(args[args.indexOf('-s') + 1], 'emulator-5554');
      expect(args, contains('--window-title'));
      expect(args[args.indexOf('--window-title') + 1], 'JA_ADB_Tool_Mirror');
      expect(args, contains('-m'));
      expect(args[args.indexOf('-m') + 1], '1600');
      expect(args, contains('--max-fps'));
      expect(args[args.indexOf('--max-fps') + 1], '60');
      expect(args, contains('-b'));
      expect(args[args.indexOf('-b') + 1], '6M');
    });

    test('builds arguments for low Wi-Fi preset and standalone window', () {
      final args = AppLogic.buildScrcpyArgs(
        serial: '192.168.1.50:5555',
        preset: 'low',
        isStandalone: true,
      );

      expect(args, contains('-s'));
      expect(args[args.indexOf('-s') + 1], '192.168.1.50:5555');
      expect(args, contains('--window-title'));
      expect(
        args[args.indexOf('--window-title') + 1],
        'JA ADB Tool - Mirror (192.168.1.50:5555)',
      );
      expect(args, contains('-m'));
      expect(args[args.indexOf('-m') + 1], '1024');
      expect(args, contains('--max-fps'));
      expect(args[args.indexOf('--max-fps') + 1], '30');
      expect(args, contains('-b'));
      expect(args[args.indexOf('-b') + 1], '3M');
    });

    test('builds arguments with all optional flags enabled', () {
      final args = AppLogic.buildScrcpyArgs(
        serial: 'ABC12345',
        preset: 'high',
        stayOnTop: true,
        fullscreen: true,
        noControl: true,
        keepAwake: true,
        borderless: true,
        noAudio: true,
      );

      expect(args, contains('--always-on-top'));
      expect(args, contains('--fullscreen'));
      expect(args, contains('--no-control'));
      expect(args, contains('--stay-awake'));
      expect(args, contains('--window-borderless'));
      expect(args, contains('--no-audio'));
      expect(args, contains('-m'));
      expect(args[args.indexOf('-m') + 1], '1920');
      expect(args, contains('--max-fps'));
      expect(args[args.indexOf('--max-fps') + 1], '60');
      expect(args, contains('-b'));
      expect(args[args.indexOf('-b') + 1], '10M');
    });
  });

  group('MirrorState transitions & session lifecycle tests', () {
    test('initial state is stopped', () {
      final logic = AppLogic(initialize: false, adbPath: 'fake-adb');
      expect(logic.mirrorState, MirrorState.stopped);
      expect(logic.isMirroring, isFalse);
      expect(logic.isMirrorRunning, isFalse);
      expect(logic.isMirrorStarting, isFalse);
      expect(logic.mirroringDeviceSerial, isNull);
    });

    test('input validation returns false and sets lastScrcpyError', () async {
      final logic = AppLogic(initialize: false, adbPath: 'fake-adb');
      final ok1 = await logic.launchMirroring();
      expect(ok1, isFalse);
      expect(logic.lastScrcpyError, 'No Android device selected.');

      logic.setSelectedDeviceForTesting('dev-1');
      final ok2 = await logic.launchMirroring();
      expect(ok2, isFalse);
      expect(
        logic.lastScrcpyError,
        'Scrcpy executable path is not configured.',
      );

      final ok3 = await logic.launchStandaloneMirroring();
      expect(ok3, isFalse);
    });

    test(
      'premature exit retries once, second exit transitions to error with stderr and cleared serial',
      () async {
        int startCount = 0;
        final processes = <FakeMirrorProcess>[];

        final logic = TestMirrorLogic(
          scrcpyStarter: (exe, args) async {
            startCount++;
            final proc = FakeMirrorProcess(pid: 1000 + startCount);
            processes.add(proc);
            return proc;
          },
        );

        final launchFuture = logic.launchMirroring();
        expect(await launchFuture, isTrue);
        expect(startCount, 1);

        // Emit stderr and exit with code 1 for the 1st process
        processes[0].stderrController.add(
          utf8.encode('ERROR: Device unauthorized\n'),
        );
        processes[0].exitCompleter.complete(1);

        // Allow microtasks and retry to run
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Exactly one retry happened
        expect(startCount, 2);

        // 2nd process also exits with code 1
        processes[1].stderrController.add(
          utf8.encode('ERROR: Device still unauthorized\n'),
        );
        processes[1].exitCompleter.complete(1);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Must not retry a 2nd time (budget exhausted)
        expect(startCount, 2);
        expect(logic.mirrorState, MirrorState.error);
        expect(logic.isMirrorStarting, isFalse);
        expect(logic.isMirrorRunning, isFalse);
        expect(logic.mirroringDeviceSerial, isNull);
        expect(logic.lastScrcpyError, contains('Device still unauthorized'));
      },
    );

    test(
      'stopMirroring during starting transitions to stopped, increments session id, ignores stale exit',
      () async {
        int startCount = 0;
        late FakeMirrorProcess proc;

        final logic = TestMirrorLogic(
          scrcpyStarter: (exe, args) async {
            startCount++;
            proc = FakeMirrorProcess();
            return proc;
          },
        );

        final launchFuture = logic.launchMirroring();
        expect(await launchFuture, isTrue);
        expect(logic.mirrorState, MirrorState.starting);
        final originalSessionId = logic.mirrorSessionId;

        // User cancels/stops while starting
        logic.stopMirroring();
        expect(logic.mirrorState, MirrorState.stopped);
        expect(logic.mirrorSessionId, greaterThan(originalSessionId));

        // Stale process exits with error code after stop
        proc.stderrController.add(utf8.encode('Killed by user'));
        if (!proc.exitCompleter.isCompleted) {
          proc.exitCompleter.complete(1);
        }

        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Should NOT retry and should remain stopped
        expect(startCount, 1);
        expect(logic.mirrorState, MirrorState.stopped);
        expect(logic.mirroringDeviceSerial, isNull);
      },
    );

    test(
      'embed timeout transitions to error and terminates scrcpy process',
      () async {
        late FakeMirrorProcess proc;
        final logic = TestMirrorLogic(
          scrcpyStarter: (exe, args) async {
            proc = FakeMirrorProcess();
            return proc;
          },
        );
        logic.mirrorEmbedMaxAttempts = 1;

        final ok = await logic.launchMirroring();
        expect(ok, isTrue);

        // Wait for embed loop (with 1 attempt, delay 0) to timeout
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(logic.mirrorState, MirrorState.error);
        expect(logic.isMirrorStarting, isFalse);
        expect(logic.mirroringDeviceSerial, isNull);
        expect(logic.lastScrcpyError, contains('Window embedding timed out'));
        expect(proc.exitCompleter.isCompleted, isTrue);
      },
    );

    test(
      'launchStandaloneMirroring captures thrown error in lastScrcpyError',
      () async {
        final logic = TestMirrorLogic(
          scrcpyStarter: (exe, args) async {
            throw Exception('Process spawn failure: Access Denied');
          },
        );

        final ok = await logic.launchStandaloneMirroring();
        expect(ok, isFalse);
        expect(
          logic.lastScrcpyError,
          contains('Process spawn failure: Access Denied'),
        );
      },
    );

    test('selectDevice stops active mirror session', () async {
      final logic = TestMirrorLogic(
        scrcpyStarter: (exe, args) async {
          return FakeMirrorProcess();
        },
      );

      await logic.launchMirroring();
      expect(logic.isMirrorStarting, isTrue);

      // Selecting another device should stop mirror
      await logic.selectDevice('device-456');
      expect(logic.mirrorState, MirrorState.stopped);
      expect(logic.mirroringDeviceSerial, isNull);
    });
  });
}
