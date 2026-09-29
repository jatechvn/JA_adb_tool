import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/logic.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final failure in ['none', 'mkdir', 'main', 'patch']) {
    test('XAPK pushes all OBBs and reports failures: $failure', () async {
      final dir = Directory.systemTemp.createTempSync('ja-obb-install-');
      final archive = Archive();
      void add(String name, List<int> bytes) =>
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
      add(
        'manifest.json',
        utf8.encode(jsonEncode({'package_name': 'com.test.clone'})),
      );
      add('base.apk', [1]);
      add('Android/obb/com.test.clone/main.1.com.test.clone.obb', [2]);
      add('Android/obb/com.test.clone/patch.1.com.test.clone.obb', [3]);
      final file = File('${dir.path}/source.xapk')
        ..writeAsBytesSync(ZipEncoder().encode(archive)!);
      final pushes = <String>[];
      final logic = AppLogic(
        initialize: false,
        adbPath: 'fake-adb',
        processRunner: (exe, args, {stdoutEncoding, stderrEncoding}) async {
          var failed = failure == 'mkdir' && args.contains('mkdir');
          if (args.contains('push')) {
            pushes.add(args.last);
            failed = args.last.contains('/$failure.');
          }
          return ProcessResult(
            0,
            failed ? 1 : 0,
            failed ? '' : 'Success',
            failed ? 'denied' : '',
          );
        },
      );
      logic.setSelectedDeviceForTesting('test-device');
      try {
        expect(await logic.installApkPath(file.path), failure == 'none');
        if (failure == 'none') {
          expect(pushes, [
            '/sdcard/Android/obb/com.test.clone/main.1.com.test.clone.obb',
            '/sdcard/Android/obb/com.test.clone/patch.1.com.test.clone.obb',
          ]);
        } else if (failure == 'mkdir') {
          expect(pushes, isEmpty);
        }
      } finally {
        logic.dispose();
      }
    });
  }
}
