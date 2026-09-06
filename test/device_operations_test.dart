import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:path/path.dart' as p;

class TestLogic extends AppLogic {
  TestLogic(
    AdbProcessRunner runner, {
    Future<Process> Function(String, List<String>)? starter,
  }) : super(
         initialize: false,
         adbPath: 'fake-adb',
         processRunner: runner,
         transferStarter: starter,
       );

  @override
  Future<void> loadDeviceSyncSettings(String deviceId) async {}
  @override
  Future<void> fetchLatestMedia({bool force = false}) async {}
  @override
  Future<void> addSyncHistory(
    String pc,
    String android,
    String direction,
    bool deleteExtra,
  ) async {}
  @override
  Future<void> triggerAndroidMediaScan(String path, {String? deviceId}) async {}
}

class FakeProcess implements Process {
  final Completer<int> completion = Completer<int>();
  @override
  Future<int> get exitCode => completion.future;
  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode('transfer output'));
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!completion.isCompleted) completion.complete(1);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProcessResult ok([String text = '']) => ProcessResult(1, 0, text, '');
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('late package results cannot replace the new device list', () async {
    final old = Completer<ProcessResult>();
    final logic = TestLogic((
      exe,
      args, {
      stdoutEncoding,
      stderrEncoding,
    }) async {
      if (args.contains('packages') && args.contains('-3')) {
        return args[1] == 'A' ? old.future : ok('package:com.b.app');
      }
      return ok();
    });
    await logic.selectDevice('A');
    final first = logic.loadApps();
    await logic.selectDevice('B');
    await logic.loadApps();
    old.complete(ok('package:com.a.app'));
    await first;
    expect(logic.apps.map((a) => a.packageName), ['com.b.app']);
    expect(logic.loadingApps, isFalse);
    logic.dispose();
  });

  test('older directory requests cannot overwrite a later folder', () async {
    final old = Completer<ProcessResult>();
    final logic = TestLogic((
      exe,
      args, {
      stdoutEncoding,
      stderrEncoding,
    }) async {
      if (args.last == '/old/') return old.future;
      if (args.last == '/new/') {
        return ok('-rw-rw---- 1 root root 4 2026-09-06 12:00 new.txt');
      }
      return ok();
    });
    await logic.selectDevice('A');
    final first = logic.loadAndroidDirectory('/old');
    await logic.loadAndroidDirectory('/new');
    old.complete(ok('-rw-rw---- 1 root root 4 2026-09-06 12:00 old.txt'));
    await first;
    expect(logic.androidFiles.map((f) => f.name), ['new.txt']);
    logic.dispose();
  });

  test('A to B to A rejects results from the first A session', () async {
    final old = Completer<ProcessResult>();
    var calls = 0;
    final logic = TestLogic((
      exe,
      args, {
      stdoutEncoding,
      stderrEncoding,
    }) async {
      if (args.contains('packages') && args.contains('-3')) {
        return ++calls == 1 ? old.future : ok('package:com.fresh.app');
      }
      return ok();
    });
    await logic.selectDevice('A');
    final first = logic.loadApps();
    await logic.selectDevice('B');
    await logic.selectDevice('A');
    await logic.loadApps();
    old.complete(ok('package:com.stale.app'));
    await first;
    expect(logic.apps.single.packageName, 'com.fresh.app');
    logic.dispose();
  });

  for (final outcome in ['failure', 'success', 'cancel']) {
    test(
      'download $outcome preserves destination until successful completion',
      () async {
        final dir = await Directory.systemTemp.createTemp('adb-regression-');
        final target = File(p.join(dir.path, 'photo.jpg'));
        await target.writeAsString('original');
        final started = Completer<void>();
        final process = FakeProcess();
        final targets = <String>[];
        final logic = TestLogic(
          (exe, args, {stdoutEncoding, stderrEncoding}) async => ok(),
          starter: (exe, args) async {
            targets.add(args[1]);
            await File(args.last).writeAsString('replacement');
            started.complete();
            return process;
          },
        );
        try {
          await logic.selectDevice('A');
          final download = logic.pullAndroidFile(
            '/sdcard/photo.jpg',
            dir.path,
            fileSize: 11,
          );
          await started.future;
          await flush();
          expect(await target.readAsString(), 'original');
          await logic.selectDevice('B');
          if (outcome == 'cancel') {
            logic.cancelTransfer();
          } else {
            process.completion.complete(outcome == 'success' ? 0 : 1);
          }
          expect(await download, outcome == 'success');
          expect(
            await target.readAsString(),
            outcome == 'success' ? 'replacement' : 'original',
          );
          expect(targets, ['A']);
          expect(dir.listSync().length, 1);
        } finally {
          logic.dispose();
          await dir.delete(recursive: true);
        }
      },
    );
  }

  test('all APKs in a batch stay on the original device', () async {
    final first = Completer<ProcessResult>();
    final targets = <String>[];
    final logic = TestLogic((
      exe,
      args, {
      stdoutEncoding,
      stderrEncoding,
    }) async {
      if (args.contains('install')) {
        targets.add(args[1]);
        return targets.length == 1 ? first.future : ok();
      }
      return ok();
    });
    await logic.selectDevice('A');
    logic.selectInstallerFiles(['one.apk', 'two.apk']);
    await flush();
    final install = logic.installPackages();
    await flush();
    await logic.selectDevice('B');
    first.complete(ok());
    expect(await install, isTrue);
    expect(targets, ['A', 'A']);
    logic.dispose();
  });

  test('sync keeps its scan and copies on the initial device', () async {
    final dir = await Directory.systemTemp.createTemp('adb-sync-test-');
    await File(p.join(dir.path, 'one.txt')).writeAsString('one');
    await File(p.join(dir.path, 'two.txt')).writeAsString('two');
    final scanned = Completer<void>();
    final scan = Completer<ProcessResult>();
    final targets = <String>[];
    final logic = TestLogic((
      exe,
      args, {
      stdoutEncoding,
      stderrEncoding,
    }) async {
      if (args.contains('find')) {
        targets.add(args[1]);
        scanned.complete();
        return scan.future;
      }
      if (args.contains('push') || args.contains('mkdir')) targets.add(args[1]);
      return ok();
    });
    try {
      await logic.selectDevice('A');
      final finished = Completer<void>();
      logic.addListener(() {
        if (!logic.isSyncing && !finished.isCompleted) finished.complete();
      });
      logic.startSyncFolder(
        pcPath: dir.path,
        androidPath: '/sdcard/test',
        direction: 'pcToAndroid',
        deleteExtra: false,
      );
      await scanned.future;
      await logic.selectDevice('B');
      scan.complete(ok());
      await finished.future.timeout(const Duration(seconds: 5));
      expect(targets.length, 5);
      expect(targets.every((target) => target == 'A'), isTrue);
    } finally {
      logic.dispose();
      await dir.delete(recursive: true);
    }
  });
}
