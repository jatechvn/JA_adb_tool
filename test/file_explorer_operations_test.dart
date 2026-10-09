import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/logic.dart';

class TestLogic extends AppLogic {
  TestLogic(AdbProcessRunner runner)
    : super(initialize: false, adbPath: 'fake-adb', processRunner: runner);

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

ProcessResult ok([String text = '']) => ProcessResult(1, 0, text, '');
ProcessResult fail([String error = 'error']) => ProcessResult(1, 1, '', error);

void main() {
  group('File Explorer Operations Tests', () {
    test(
      'renameAndroidFile successfully executes adb shell mv and reloads',
      () async {
        final executedArgs = <List<String>>[];
        final logic = TestLogic((
          exe,
          args, {
          stdoutEncoding,
          stderrEncoding,
        }) async {
          executedArgs.add(List<String>.from(args));
          if (args.contains('ls') && args.contains('-la')) {
            return ok(
              '-rw-rw---- 1 root root 1024 2026-10-06 10:00 document_renamed.pdf\n',
            );
          }
          return ok();
        });

        await logic.selectDevice('device-1');
        await logic.loadAndroidDirectory('/sdcard/Download');

        final success = await logic.renameAndroidFile(
          '/sdcard/Download/document.pdf',
          'document_renamed.pdf',
        );

        expect(success, isTrue);
        // Verify shell mv was invoked
        final mvCall = executedArgs.firstWhere(
          (call) => call.contains('shell') && call.contains('mv'),
        );
        expect(mvCall, contains('/sdcard/Download/document.pdf'));
        expect(mvCall, contains('/sdcard/Download/document_renamed.pdf'));
        logic.dispose();
      },
    );

    test(
      'renameAndroidFile rejects empty names or names containing path separators',
      () async {
        final executedArgs = <List<String>>[];
        final logic = TestLogic((
          exe,
          args, {
          stdoutEncoding,
          stderrEncoding,
        }) async {
          executedArgs.add(List<String>.from(args));
          return ok();
        });

        await logic.selectDevice('device-1');

        final resEmpty = await logic.renameAndroidFile(
          '/sdcard/Download/doc.txt',
          '   ',
        );
        final resSlash = await logic.renameAndroidFile(
          '/sdcard/Download/doc.txt',
          'sub/doc.txt',
        );

        expect(resEmpty, isFalse);
        expect(resSlash, isFalse);
        expect(executedArgs.where((call) => call.contains('mv')), isEmpty);
        logic.dispose();
      },
    );

    test(
      'moveAndroidFiles creates target directory and executes adb shell mv for each file',
      () async {
        final executedArgs = <List<String>>[];
        final logic = TestLogic((
          exe,
          args, {
          stdoutEncoding,
          stderrEncoding,
        }) async {
          executedArgs.add(List<String>.from(args));
          return ok();
        });

        await logic.selectDevice('device-1');

        final success = await logic.moveAndroidFiles([
          '/sdcard/Download/file1.png',
          '/sdcard/Download/file2.png',
        ], '/sdcard/Pictures/Screenshots');

        expect(success, isTrue);

        // Verify mkdir -p was executed
        final mkdirCall = executedArgs.firstWhere(
          (call) => call.contains('shell') && call.contains('mkdir'),
        );
        expect(mkdirCall, contains('/sdcard/Pictures/Screenshots'));

        // Verify mv calls
        final mvCalls = executedArgs
            .where((call) => call.contains('shell') && call.contains('mv'))
            .toList();
        expect(mvCalls.length, 2);
        expect(mvCalls[0], contains('/sdcard/Download/file1.png'));
        expect(mvCalls[0], contains('/sdcard/Pictures/Screenshots/'));
        expect(mvCalls[1], contains('/sdcard/Download/file2.png'));
        expect(mvCalls[1], contains('/sdcard/Pictures/Screenshots/'));

        logic.dispose();
      },
    );

    test(
      'moveAndroidFiles returns false and reports error if shell mv fails',
      () async {
        final logic = TestLogic((
          exe,
          args, {
          stdoutEncoding,
          stderrEncoding,
        }) async {
          if (args.contains('mv')) {
            return fail('Permission denied');
          }
          return ok();
        });

        await logic.selectDevice('device-1');

        final success = await logic.moveAndroidFiles([
          '/sdcard/protected.txt',
        ], '/sdcard/Destination');

        expect(success, isFalse);
        logic.dispose();
      },
    );

    test(
      'copyAndroidFiles creates target directory and executes adb shell cp -r for each file',
      () async {
        final executedArgs = <List<String>>[];
        final logic = TestLogic((
          exe,
          args, {
          stdoutEncoding,
          stderrEncoding,
        }) async {
          executedArgs.add(List<String>.from(args));
          return ok();
        });

        await logic.selectDevice('device-1');

        final success = await logic.copyAndroidFiles([
          '/sdcard/Download/file1.png',
          '/sdcard/Download/file2.png',
        ], '/sdcard/Pictures/Backup');

        expect(success, isTrue);

        // Verify mkdir -p was executed
        final mkdirCall = executedArgs.firstWhere(
          (call) => call.contains('shell') && call.contains('mkdir'),
        );
        expect(mkdirCall, contains('/sdcard/Pictures/Backup'));

        // Verify cp -r calls
        final cpCalls = executedArgs
            .where((call) => call.contains('shell') && call.contains('cp'))
            .toList();
        expect(cpCalls.length, 2);
        expect(cpCalls[0], contains('-r'));
        expect(cpCalls[0], contains('/sdcard/Download/file1.png'));
        expect(cpCalls[0], contains('/sdcard/Pictures/Backup/'));
        expect(cpCalls[1], contains('-r'));
        expect(cpCalls[1], contains('/sdcard/Download/file2.png'));
        expect(cpCalls[1], contains('/sdcard/Pictures/Backup/'));

        logic.dispose();
      },
    );

    test(
      'copyAndroidFiles returns false and reports error if shell cp fails',
      () async {
        final logic = TestLogic((
          exe,
          args, {
          stdoutEncoding,
          stderrEncoding,
        }) async {
          if (args.contains('cp')) {
            return fail('No space left on device');
          }
          return ok();
        });

        await logic.selectDevice('device-1');

        final success = await logic.copyAndroidFiles([
          '/sdcard/bigfile.iso',
        ], '/sdcard/Destination');

        expect(success, isFalse);
        logic.dispose();
      },
    );
  });
}
