import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/app_cloner_service.dart';
import 'package:ja_adb_tool/modules/services/apk_signer.dart';

const ns = 'http://schemas.android.com/apk/res/android';

Uint8List manifest({bool utf16 = false, bool split = false}) {
  final strings = [
    'manifest',
    'package',
    'com.test.app',
    ns,
    'application',
    'label',
    'activity',
    'name',
    '.MainActivity',
    'provider',
    'authorities',
    'com.test.app.provider;custom.provider',
    'com.test.app.App',
    'split',
    'config.en',
  ];
  final data = BytesBuilder();
  final offsets = <int>[];
  for (final s in strings) {
    offsets.add(data.length);
    if (utf16) {
      data.add([s.length, 0]);
      for (final c in s.codeUnits) {
        data.add([c & 255, c >> 8]);
      }
      data.add([0, 0]);
    } else {
      final encoded = utf8.encode(s);
      data.add([s.length, encoded.length, ...encoded, 0]);
    }
  }
  while (data.length % 4 != 0) {
    data.addByte(0);
  }
  final pool = ByteData(28 + strings.length * 4 + data.length);
  pool.setUint16(0, 1, Endian.little);
  pool.setUint16(2, 28, Endian.little);
  pool.setUint32(4, pool.lengthInBytes, Endian.little);
  pool.setUint32(8, strings.length, Endian.little);
  pool.setUint32(16, utf16 ? 0 : 256, Endian.little);
  pool.setUint32(20, 28 + strings.length * 4, Endian.little);
  for (var i = 0; i < offsets.length; i++) {
    pool.setUint32(28 + i * 4, offsets[i], Endian.little);
  }
  pool.buffer.asUint8List().setRange(
    28 + strings.length * 4,
    pool.lengthInBytes,
    data.toBytes(),
  );
  Uint8List tag(int name, List<List<int>> attrs) {
    final b = ByteData(36 + attrs.length * 20);
    b.setUint16(0, 0x102, Endian.little);
    b.setUint16(2, 16, Endian.little);
    b.setUint32(4, b.lengthInBytes, Endian.little);
    b.setUint32(20, name, Endian.little);
    b.setUint16(24, 20, Endian.little);
    b.setUint16(26, 20, Endian.little);
    b.setUint16(28, attrs.length, Endian.little);
    for (var i = 0; i < attrs.length; i++) {
      final a = 36 + i * 20, v = attrs[i];
      b.setUint32(a, v[0], Endian.little);
      b.setUint32(a + 4, v[1], Endian.little);
      b.setUint32(a + 8, 0xffffffff, Endian.little);
      b.setUint16(a + 12, 8, Endian.little);
      b.setUint8(a + 15, v[2]);
      b.setUint32(a + 16, v[3], Endian.little);
    }
    return b.buffer.asUint8List();
  }

  final body = BytesBuilder()
    ..add(pool.buffer.asUint8List())
    ..add(
      tag(0, [
        [0xffffffff, 1, 3, 2],
        if (split) [0xffffffff, 13, 3, 14],
      ]),
    )
    ..add(
      tag(4, [
        [3, 5, 1, 0x7f010001],
        [3, 7, 3, 12],
      ]),
    )
    ..add(
      tag(6, [
        [3, 7, 3, 8],
      ]),
    )
    ..add(
      tag(9, [
        [3, 10, 3, 11],
      ]),
    );
  final header = ByteData(8)
    ..setUint32(0, 0x80003, Endian.little)
    ..setUint32(4, body.length + 8, Endian.little);
  return (BytesBuilder()
        ..add(header.buffer.asUint8List())
        ..add(body.toBytes()))
      .toBytes();
}

List<String> attributes(Uint8List bytes) {
  final b = ByteData.sublistView(bytes), strings = <String>[];
  final utf16 = b.getUint32(24, Endian.little) == 0;
  for (var i = 0; i < b.getUint32(16, Endian.little); i++) {
    final start =
        8 +
        b.getUint32(28, Endian.little) +
        b.getUint32(36 + i * 4, Endian.little);
    final length = utf16 ? b.getUint16(start, Endian.little) : bytes[start + 1];
    strings.add(
      utf16
          ? String.fromCharCodes(
              List.generate(
                length,
                (j) => b.getUint16(start + 2 + j * 2, Endian.little),
              ),
            )
          : utf8.decode(bytes.sublist(start + 2, start + 2 + length)),
    );
  }
  final values = <String>[];
  var cursor = 8 + b.getUint32(12, Endian.little);
  while (cursor < bytes.length) {
    for (var i = 0; i < b.getUint16(cursor + 28, Endian.little); i++) {
      final a = cursor + 36 + i * 20;
      if (b.getUint8(a + 15) == 3) {
        values.add(strings[b.getUint32(a + 16, Endian.little)]);
      }
    }
    cursor += b.getUint32(cursor + 4, Endian.little);
  }
  return values;
}

void main() {
  for (final utf16 in [false, true]) {
    test(
      'attribute-aware package, resource label and classes utf16=$utf16',
      () {
        final patched = AxmlModifier.modifyManifest(
          manifestBytes: manifest(utf16: utf16),
          oldPackage: 'com.test.app',
          newPackage: 'com.test.clone',
          newAppName: 'Bản sao 克隆',
        );
        expect(attributes(patched), [
          'com.test.clone',
          'Bản sao 克隆',
          'com.test.app.App',
          'com.test.app.MainActivity',
          'com.test.clone.provider;custom.provider.com.test.clone',
        ]);
      },
    );
  }
  test('split manifests are supported', () {
    final patched = AxmlModifier.modifyManifest(
      manifestBytes: manifest(split: true),
      oldPackage: 'com.test.app',
      newPackage: 'com.test.clone',
    );
    expect(
      AxmlModifier.parseManifestInfo(patched)['packageName'],
      'com.test.clone',
    );
  });
  test('mismatched package fails closed for base and split', () {
    for (final split in [true, false]) {
      expect(
        () => AxmlModifier.modifyManifest(
          manifestBytes: manifest(split: split),
          oldPackage: 'wrong.app',
          newPackage: 'com.test.clone',
        ),
        throwsFormatException,
      );
    }
  });
  test('signing requires align, sign and verified v2 in that order', () async {
    final calls = <List<String>>[];
    final signer = ApkSigner(
      java: 'java',
      jar: 'sign.jar',
      zipalign: 'zipalign',
      keystore: 'key',
      runner: (exe, args) async {
        calls.add([exe, ...args]);
        return ProcessResult(
          0,
          0,
          'Verified using v2 scheme (APK Signature Scheme v2): true',
          '',
        );
      },
    );
    await signer.signAndVerify('unsigned', 'signed');
    expect(calls[0].first, 'zipalign');
    expect(calls[1], contains('sign'));
    expect(calls[2], contains('verify'));
    expect(calls[1], contains('--v2-signing-enabled'));
  });
  for (final failAt in [0, 1, 2, 3]) {
    test(
      'signer rejects failure at stage $failAt including unverified v2',
      () async {
        var call = 0;
        final signer = ApkSigner(
          java: 'java',
          jar: 'sign.jar',
          zipalign: 'zipalign',
          keystore: 'key',
          runner: (exe, args) async =>
              ProcessResult(0, call++ == failAt ? 1 : 0, '', 'failed'),
        );
        await expectLater(
          signer.signAndVerify('unsigned', 'signed'),
          throwsStateError,
        );
      },
    );
  }
  test('service rejects XAPK and unsafe package paths', () async {
    final service = AppClonerService();
    for (final input in [
      ('source.xapk', 'com.test.clone'),
      ('source.apk', '../escape'),
    ]) {
      final result = await service.cloneApkFile(
        sourceApkPath: input.$1,
        targetDirectory: 'unused',
        oldPackage: 'com.test.app',
        newPackage: input.$2,
      );
      expect(result.isSuccess, isFalse);
    }
  });
  test('signing failure never publishes a success APK', () async {
    final dir = Directory.systemTemp.createTempSync('clone-regression-');
    final bytes = manifest();
    final archive = Archive()
      ..addFile(ArchiveFile('AndroidManifest.xml', bytes.length, bytes));
    final source = File('${dir.path}/source.apk')
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
    final service = AppClonerService(
      signerFactory: () => ApkSigner(
        java: 'java',
        jar: 'sign.jar',
        zipalign: 'align',
        keystore: 'key',
        runner: (_, _) async => ProcessResult(0, 1, '', 'failed'),
      ),
    );
    final result = await service.cloneApkFile(
      sourceApkPath: source.path,
      targetDirectory: dir.path,
      oldPackage: 'com.test.app',
      newPackage: 'com.test.clone',
    );
    expect(result.isSuccess, isFalse);
    expect(File('${dir.path}/com.test.clone_cloned.apk').existsSync(), isFalse);
  });

  test('uber-apk-signer runner signs and copies apk to target path', () async {
    final dir = Directory.systemTemp.createTempSync('uber-signer-test-');
    final unsigned = '${dir.path}/unsigned.apk';
    final signed = '${dir.path}/signed.apk';
    File(unsigned).writeAsStringSync('unsigned-content');

    final signer = ApkSigner(
      java: 'java',
      jar: 'uber-apk-signer.jar',
      zipalign: '',
      keystore: 'debug.keystore',
      isUberSigner: true,
      runner: (exe, args) async {
        // Find the -o directory and create output apk
        final outIdx = args.indexOf('-o');
        if (outIdx != -1 && outIdx + 1 < args.length) {
          final outDir = args[outIdx + 1];
          File(
            '$outDir/unsigned-aligned-debugSigned.apk',
          ).writeAsStringSync('signed-and-aligned-content');
        }
        return ProcessResult(0, 0, 'Successfully processed 1 APKs', '');
      },
    );

    await signer.signAndVerify(unsigned, signed);
    expect(File(signed).existsSync(), isTrue);
    expect(File(signed).readAsStringSync(), 'signed-and-aligned-content');
  });

  test('rewrites custom permissions starting with oldPackage', () {
    final strings = [
      'manifest', // 0
      'package', // 1
      'com.test.app', // 2
      ns, // 3
      'permission', // 4
      'name', // 5
      'com.test.app.permission.CUSTOM', // 6
      'application', // 7
    ];
    final data = BytesBuilder();
    final offsets = <int>[];
    for (final s in strings) {
      offsets.add(data.length);
      final encoded = utf8.encode(s);
      data.add([s.length, encoded.length, ...encoded, 0]);
    }
    while (data.length % 4 != 0) {
      data.addByte(0);
    }
    final pool = ByteData(28 + strings.length * 4 + data.length);
    pool.setUint16(0, 1, Endian.little);
    pool.setUint16(2, 28, Endian.little);
    pool.setUint32(4, pool.lengthInBytes, Endian.little);
    pool.setUint32(8, strings.length, Endian.little);
    pool.setUint32(16, 256, Endian.little);
    pool.setUint32(20, 28 + strings.length * 4, Endian.little);
    for (var i = 0; i < offsets.length; i++) {
      pool.setUint32(28 + i * 4, offsets[i], Endian.little);
    }
    pool.buffer.asUint8List().setRange(
      28 + strings.length * 4,
      pool.lengthInBytes,
      data.toBytes(),
    );

    Uint8List makeTag(int name, List<List<int>> attrs) {
      final b = ByteData(36 + attrs.length * 20);
      b.setUint16(0, 0x102, Endian.little);
      b.setUint16(2, 16, Endian.little);
      b.setUint32(4, b.lengthInBytes, Endian.little);
      b.setUint32(20, name, Endian.little);
      b.setUint16(24, 20, Endian.little);
      b.setUint16(26, 20, Endian.little);
      b.setUint16(28, attrs.length, Endian.little);
      for (var i = 0; i < attrs.length; i++) {
        final a = 36 + i * 20, v = attrs[i];
        b.setUint32(a, v[0], Endian.little);
        b.setUint32(a + 4, v[1], Endian.little);
        b.setUint32(a + 8, 0xffffffff, Endian.little);
        b.setUint16(a + 12, 8, Endian.little);
        b.setUint8(a + 15, v[2]);
        b.setUint32(a + 16, v[3], Endian.little);
      }
      return b.buffer.asUint8List();
    }

    final body = BytesBuilder()
      ..add(pool.buffer.asUint8List())
      ..add(
        makeTag(0, [
          [0xffffffff, 1, 3, 2], // manifest package="com.test.app"
        ]),
      )
      ..add(
        makeTag(4, [
          [
            3,
            5,
            3,
            6,
          ], // permission android:name="com.test.app.permission.CUSTOM"
        ]),
      )
      ..add(
        makeTag(7, []), // application
      );
    final header = ByteData(8)
      ..setUint32(0, 0x80003, Endian.little)
      ..setUint32(4, body.length + 8, Endian.little);
    final manifestBytes =
        (BytesBuilder()
              ..add(header.buffer.asUint8List())
              ..add(body.toBytes()))
            .toBytes();

    final patched = AxmlModifier.modifyManifest(
      manifestBytes: manifestBytes,
      oldPackage: 'com.test.app',
      newPackage: 'com.test.clone',
    );

    expect(attributes(patched), [
      'com.test.clone',
      'com.test.clone.permission.CUSTOM',
    ]);
  });

  test('parseManifestInfo extracts package name from manifest bytes', () {
    final bytes = manifest();
    final info = AxmlModifier.parseManifestInfo(bytes);
    expect(info['packageName'], 'com.test.app');
  });

  test(
    'cloneApkFile auto-detects real package when oldPackage is placeholder',
    () async {
      final dir = Directory.systemTemp.createTempSync(
        'clone-placeholder-test-',
      );
      final bytes = manifest();
      final archive = Archive()
        ..addFile(ArchiveFile('AndroidManifest.xml', bytes.length, bytes));
      final source = File('${dir.path}/source.apk')
        ..writeAsBytesSync(ZipEncoder().encode(archive)!);

      final service = AppClonerService(
        signerFactory: () => ApkSigner(
          java: 'java',
          jar: 'uber-apk-signer.jar',
          zipalign: '',
          keystore: 'key',
          isUberSigner: true,
          runner: (exe, args) async {
            final outIdx = args.indexOf('-o');
            if (outIdx != -1 && outIdx + 1 < args.length) {
              final outDir = args[outIdx + 1];
              File(
                '$outDir/unsigned-aligned-debugSigned.apk',
              ).writeAsStringSync('signed');
            }
            return ProcessResult(0, 0, 'Successfully processed 1 APKs', '');
          },
        ),
      );

      // Pass placeholder with spaces: 'Will determine during install'
      final result = await service.cloneApkFile(
        sourceApkPath: source.path,
        targetDirectory: dir.path,
        oldPackage: 'Will determine during install',
        newPackage: 'com.test.clone',
      );

      expect(result.isSuccess, isTrue);
      expect(
        File('${dir.path}/com.test.clone_cloned.apk').existsSync(),
        isTrue,
      );
    },
  );
}
