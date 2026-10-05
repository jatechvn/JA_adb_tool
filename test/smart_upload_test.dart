import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/smart_upload_service.dart';

class FakeProcess implements Process {
  final int exitCodeValue;
  final Stream<List<int>> stderrStream;
  final Stream<List<int>> stdoutStream;
  final int pidValue;

  FakeProcess({
    this.exitCodeValue = 0,
    Stream<List<int>>? stderr,
    Stream<List<int>>? stdout,
    this.pidValue = 1234,
  }) : stderrStream = stderr ?? const Stream.empty(),
       stdoutStream = stdout ?? const Stream.empty();

  @override
  Future<int> get exitCode => Future.value(exitCodeValue);

  @override
  Stream<List<int>> get stderr => stderrStream;

  @override
  Stream<List<int>> get stdout => stdoutStream;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  int get pid => pidValue;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

void main() {
  group('SmartUploadService - resolveUniqueRemoteName', () {
    test('returns original name when no collision exists', () {
      final result = SmartUploadService.resolveUniqueRemoteName(
        'document.pdf',
        {'photo.jpg', 'video.mp4'},
      );
      expect(result, 'document.pdf');
    });

    test('appends (1) when single collision exists', () {
      final result = SmartUploadService.resolveUniqueRemoteName(
        'document.pdf',
        {'document.pdf', 'photo.jpg'},
      );
      expect(result, 'document (1).pdf');
    });

    test('increments suffix number when (1) already exists', () {
      final result = SmartUploadService.resolveUniqueRemoteName(
        'document.pdf',
        {'document.pdf', 'document (1).pdf', 'document (2).pdf'},
      );
      expect(result, 'document (3).pdf');
    });

    test('correctly handles filename without extension', () {
      final result = SmartUploadService.resolveUniqueRemoteName('README', {
        'README',
        'README (1)',
      });
      expect(result, 'README (2)');
    });

    test('correctly handles dotfiles', () {
      final result = SmartUploadService.resolveUniqueRemoteName('.gitignore', {
        '.gitignore',
      });
      expect(result, '.gitignore (1)');
    });
  });

  group('SmartUploadService - prepareBatchPlan', () {
    late Directory tempDir;
    late File testFile1;
    late File testFile2;
    late Directory subDir;
    late File nestedFile;
    final service = SmartUploadService();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('upload_test_');
      testFile1 = File('${tempDir.path}/hello.txt');
      await testFile1.writeAsString('Hello World');

      testFile2 = File('${tempDir.path}/image.png');
      await testFile2.writeAsBytes(List.filled(100, 42));

      subDir = Directory('${tempDir.path}/nested_folder');
      await subDir.create();
      nestedFile = File('${subDir.path}/inner.json');
      await nestedFile.writeAsString('{"key": "value"}');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('scans individual files and calculates total metrics', () async {
      final plan = await service.prepareBatchPlan(
        localPaths: [testFile1.path, testFile2.path],
        targetDirectory: '/sdcard/Download',
        existingRemoteNames: {'hello.txt'},
      );

      expect(plan.totalFiles, 2);
      expect(plan.totalBytes, testFile1.lengthSync() + testFile2.lengthSync());
      expect(plan.items.length, 2);

      // hello.txt has conflict
      final item1 = plan.items.firstWhere((i) => i.originalName == 'hello.txt');
      expect(item1.isConflict, isTrue);
      expect(item1.targetPath, '/sdcard/Download/hello.txt');

      // image.png has no conflict
      final item2 = plan.items.firstWhere((i) => i.originalName == 'image.png');
      expect(item2.isConflict, isFalse);
      expect(plan.hasConflicts, isTrue);
      expect(plan.conflicts.length, 1);
    });

    test(
      'scans folders recursively and preserves directory structure',
      () async {
        final plan = await service.prepareBatchPlan(
          localPaths: [subDir.path],
          targetDirectory: '/sdcard/Download',
          existingRemoteNames: {},
        );

        expect(plan.totalFiles, 1);
        final nestedItem = plan.items.first;
        expect(nestedItem.originalName, 'inner.json');
        expect(nestedItem.relativePath, 'nested_folder/inner.json');
        expect(
          nestedItem.targetPath,
          '/sdcard/Download/nested_folder/inner.json',
        );
        expect(nestedItem.isConflict, isFalse);
      },
    );
  });

  group('SmartUploadService - executeBatch', () {
    late Directory tempDir;
    late File testFile1;
    late File testFile2;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('upload_exec_test_');
      testFile1 = File('${tempDir.path}/file1.txt');
      await testFile1.writeAsString('First file contents');

      testFile2 = File('${tempDir.path}/file2.txt');
      await testFile2.writeAsString('Second file contents');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('executes batch with rename conflict resolution', () async {
      final service = SmartUploadService();
      final plan = await service.prepareBatchPlan(
        localPaths: [testFile1.path],
        targetDirectory: '/sdcard/Download',
        existingRemoteNames: {'file1.txt'},
      );

      expect(plan.items.first.isConflict, isTrue);

      final executedPushes = <List<String>>[];

      await service.executeBatch(
        adbPath: 'adb',
        deviceId: 'device123',
        plan: plan,
        conflictPolicy: FileConflictPolicy.rename,
        onProgress: (_) {},
        startProcess: (exe, args) async {
          executedPushes.add(args);
          return FakeProcess();
        },
        runProcess: (exe, args) async {
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(plan.items.first.status, FileUploadItemStatus.completed);
      expect(plan.items.first.targetName, 'file1 (1).txt');
      expect(plan.items.first.targetPath, '/sdcard/Download/file1 (1).txt');

      // Verify adb push pushed to renamed remote destination
      expect(executedPushes.first.last, '/sdcard/Download/file1 (1).txt');
    });

    test('skips conflicting files when policy is skip', () async {
      final service = SmartUploadService();
      final plan = await service.prepareBatchPlan(
        localPaths: [testFile1.path, testFile2.path],
        targetDirectory: '/sdcard/Download',
        existingRemoteNames: {'file1.txt'},
      );

      final pushedFiles = <String>[];
      BatchUploadProgress? finalProgress;

      await service.executeBatch(
        adbPath: 'adb',
        deviceId: 'device123',
        plan: plan,
        conflictPolicy: FileConflictPolicy.skip,
        onProgress: (p) => finalProgress = p,
        startProcess: (exe, args) async {
          pushedFiles.add(args[args.indexOf('push') + 1]);
          return FakeProcess();
        },
        runProcess: (exe, args) async {
          return ProcessResult(1234, 0, '', '');
        },
      );

      expect(plan.items[0].status, FileUploadItemStatus.skipped);
      expect(plan.items[1].status, FileUploadItemStatus.completed);
      expect(finalProgress?.skippedFiles, 1);
      expect(finalProgress?.completedFiles, 1);
      expect(pushedFiles.length, 1);
      expect(pushedFiles.first, testFile2.path);
    });

    test('overwrites conflicting files when policy is overwrite', () async {
      final service = SmartUploadService();
      final plan = await service.prepareBatchPlan(
        localPaths: [testFile1.path],
        targetDirectory: '/sdcard/Download',
        existingRemoteNames: {'file1.txt'},
      );

      await service.executeBatch(
        adbPath: 'adb',
        deviceId: 'device123',
        plan: plan,
        conflictPolicy: FileConflictPolicy.overwrite,
        onProgress: (_) {},
        startProcess: (exe, args) async => FakeProcess(),
        runProcess: (exe, args) async => ProcessResult(1234, 0, '', ''),
      );

      expect(plan.items.first.status, FileUploadItemStatus.overwritten);
      expect(plan.items.first.targetName, 'file1.txt');
    });

    test('aborts gracefully when cancel is requested during batch', () async {
      final service = SmartUploadService();
      final plan = await service.prepareBatchPlan(
        localPaths: [testFile1.path, testFile2.path],
        targetDirectory: '/sdcard/Download',
        existingRemoteNames: {},
      );

      int pushCount = 0;

      await service.executeBatch(
        adbPath: 'adb',
        deviceId: 'device123',
        plan: plan,
        conflictPolicy: FileConflictPolicy.rename,
        onProgress: (p) {
          if (p.currentItem?.originalName == 'file1.txt' &&
              !service.isCancelled) {
            service.cancel();
          }
        },
        startProcess: (exe, args) async {
          pushCount++;
          return FakeProcess();
        },
        runProcess: (exe, args) async => ProcessResult(1234, 0, '', ''),
      );

      expect(service.isCancelled, isTrue);
      expect(plan.items[1].status, FileUploadItemStatus.cancelled);
      expect(pushCount, 1);
    });

    test('skips active item when skipCurrent is called', () async {
      final service = SmartUploadService();
      final plan = await service.prepareBatchPlan(
        localPaths: [testFile1.path, testFile2.path],
        targetDirectory: '/sdcard/Download',
        existingRemoteNames: {},
      );

      await service.executeBatch(
        adbPath: 'adb',
        deviceId: 'device123',
        plan: plan,
        conflictPolicy: FileConflictPolicy.rename,
        onProgress: (p) {
          if (p.currentItem?.originalName == 'file1.txt' &&
              !service.isSkipRequested) {
            service.skipCurrent();
          }
        },
        startProcess: (exe, args) async => FakeProcess(),
        runProcess: (exe, args) async => ProcessResult(1234, 0, '', ''),
      );

      expect(plan.items[0].status, FileUploadItemStatus.skipped);
      expect(plan.items[1].status, FileUploadItemStatus.completed);
    });
  });
}
