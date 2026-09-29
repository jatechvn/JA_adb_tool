import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/xapk_archive.dart';
import 'package:ja_adb_tool/modules/services/app_cloner_service.dart';
import 'package:ja_adb_tool/modules/services/apk_signer.dart';

void main() {
  late Directory stage;
  setUp(() => stage = Directory.systemTemp.createTempSync('ja-xapk-safety-'));
  // Test artifacts are retained; never touch user packages.
  File fixture(List<ArchiveFile> files) {
    final archive = Archive();
    for (final file in files) {
      archive.addFile(file);
    }
    return File('${stage.path}/source.xapk')
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
  }

  test('rejects traversal before extracting any entry', () async {
    final source = fixture([
      ArchiveFile('base.apk', 1, [1]),
      ArchiveFile('../escape.apk', 1, [2]),
    ]);
    final destination = Directory('${stage.path}/out')..createSync();
    await expectLater(
      extractXapkInBackground(source.path, destination.path),
      throwsFormatException,
    );
    expect(destination.listSync(), isEmpty);
    expect(File('${stage.path}/escape.apk').existsSync(), isFalse);
  });

  test('enforces archive size, entry count and expanded size', () {
    final source = fixture([ArchiveFile('base.apk', 1024, Uint8List(1024))]);
    expect(
      () => openValidatedXapk(source.path, maxArchiveBytes: 1),
      throwsFormatException,
    );
    expect(
      () => openValidatedXapk(source.path, maxEntries: 0),
      throwsFormatException,
    );
    expect(
      () => openValidatedXapk(source.path, maxUncompressedBytes: 100),
      throwsFormatException,
    );
  });

  test(
    'clone service rejects unsafe archive before signing or publishing',
    () async {
      final source = fixture([
        ArchiveFile('../escape.apk', 1, [1]),
      ]);
      var signed = false;
      final service = AppClonerService(
        signerFactory: () => ApkSigner(
          java: 'unused',
          jar: 'unused',
          keystore: 'unused',
          runner: (exe, args) async {
            signed = true;
            return ProcessResult(0, 0, '', '');
          },
        ),
      );
      final result = await service.cloneXapkFile(
        sourceXapkPath: source.path,
        targetDirectory: stage.path,
        oldPackage: 'com.test.app',
        newPackage: 'com.test.clone',
      );
      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('unsafe archive entry'));
      expect(signed, isFalse);
      expect(
        File('${stage.path}/com.test.clone_cloned.xapk').existsSync(),
        isFalse,
      );
    },
  );

  test(
    'ZIP workers keep event loop responsive and preserve file bytes',
    () async {
      final input = Directory('${stage.path}/input')..createSync();
      final data = Uint8List(8 * 1024 * 1024);
      for (var i = 0; i < data.length; i++) {
        data[i] = i % 251;
      }
      File('${input.path}/base.apk').writeAsBytesSync(data);
      final output = '${stage.path}/result.xapk';
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 1),
        (_) => ticks++,
      );
      try {
        await packageDirectoryInBackground(input.path, output);
        expect(ticks, greaterThan(0));
        ticks = 0;
        final unpacked = Directory('${stage.path}/unpacked')..createSync();
        await extractXapkInBackground(output, unpacked.path);
        expect(ticks, greaterThan(0));
        expect(File('${unpacked.path}/base.apk').readAsBytesSync(), data);
      } finally {
        timer.cancel();
      }
    },
  );
}
