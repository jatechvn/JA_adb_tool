import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/services/apk_signer.dart';
import 'app_cloner_regression_test.dart' as fixtures;
import 'package:ja_adb_tool/modules/ui/app_cloner_dialog.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';

void main() {
  const testXapkPath =
      r'D:\OLD\APK\Scanner_OK\WhatsApp+Messenger_2.26.36.74_APKPure.xapk';
  const testPackage = 'com.whatsapp';
  const testAppName = 'WhatsApp';

  group('XAPK AppClonerDialog Widget Tests', () {
    for (final locale in ['en', 'vi', 'zh']) {
      testWidgets(
        'renders AppClonerDialog cleanly for XAPK at 1280x800 in $locale',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final language = LanguageProvider.forTesting(locale);
          final logic = AppLogic(initialize: false);

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AppLogic>.value(value: logic),
                ChangeNotifierProvider(create: (_) => ThemeProvider()),
                ChangeNotifierProvider<LanguageProvider>.value(value: language),
              ],
              child: const MaterialApp(
                home: Scaffold(
                  body: AppClonerDialog(
                    directApkPath: testXapkPath,
                    initialPackage: testPackage,
                    initialAppName: testAppName,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          // Verify Source App Information
          expect(find.text(testAppName), findsWidgets);
          expect(find.text(testPackage), findsOneWidget);

          // Verify Local XAPK badge
          expect(find.text('Local XAPK'), findsOneWidget);

          // Verify default cloned values
          expect(find.text('$testAppName (Clone 1)'), findsOneWidget);
          expect(find.text('$testPackage.clone1'), findsOneWidget);

          // Verify tab labels
          expect(find.text(language.tr('clone_tab_apk')), findsOneWidget);
          expect(
            find.text(language.tr('clone_tab_dual_space')),
            findsOneWidget,
          );

          // Verify action buttons
          expect(find.text(language.tr('start_cloning_btn')), findsOneWidget);
          expect(find.text(language.tr('apk_signing_setup')), findsOneWidget);

          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }

    testWidgets('allows editing cloned name, package, and options for XAPK', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final language = LanguageProvider.forTesting('en');
      final logic = AppLogic(initialize: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppLogic>.value(value: logic),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<LanguageProvider>.value(value: language),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AppClonerDialog(
                directApkPath: testXapkPath,
                initialPackage: testPackage,
                initialAppName: testAppName,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // Enter custom clone name
      await tester.enterText(textFields.first, 'WhatsApp Clone Dual');
      await tester.pump();
      expect(find.text('WhatsApp Clone Dual'), findsOneWidget);

      // Enter custom package ID
      await tester.enterText(textFields.at(1), 'com.whatsapp.dualclone');
      await tester.pump();
      expect(find.text('com.whatsapp.dualclone'), findsOneWidget);

      // Toggle save to PC checkbox
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      // Export dir field should now appear
      expect(find.byType(TextField), findsNWidgets(3));

      // Test tab switching to Dual Space
      await tester.tap(find.text(language.tr('clone_tab_dual_space')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch back to APK/XAPK Clone tab
      await tester.tap(find.text(language.tr('clone_tab_apk')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('WhatsApp Clone Dual'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('AxmlModifier Split APK & XAPK Manifest Tests', () {
    test(
      'AxmlModifier allows and processes split manifests with isSplit: true',
      () {
        const oldPkg = 'com.whatsapp';
        const splitAttr = 'config.arm64_v8a';

        final initialBytes = _createMockSplitManifest(
          package: oldPkg,
          split: splitAttr,
        );

        // Verify that modifyManifest now succeeds on split manifests!
        final modifiedBytes = AxmlModifier.modifyManifest(
          manifestBytes: initialBytes,
          oldPackage: oldPkg,
          newPackage: 'com.whatsapp.clone1',
          isSplit: true,
        );

        expect(modifiedBytes, isNotNull);
        expect(modifiedBytes.length, greaterThan(0));

        // Check that parseManifestInfo identifies it as split
        final info = AxmlModifier.parseManifestInfo(modifiedBytes);
        expect(info['packageName'], equals('com.whatsapp.clone1'));
        expect(info['isSplit'], equals('true'));
        expect(info['splitName'], equals('config.arm64_v8a'));
      },
    );

    test(
      'readApkManifestInfo parses manifest.json from XAPK archive',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('ja_xapk_test_');
        try {
          final mockXapkFile = File('${tempDir.path}/test.xapk');
          final archive = Archive();
          final manifestJsonContent = utf8.encode(
            jsonEncode({
              'xapk_version': 1,
              'package_name': 'com.whatsapp',
              'name': 'WhatsApp',
              'version_code': 24263674,
              'version_name': '2.26.36.74',
            }),
          );
          archive.addFile(
            ArchiveFile(
              'manifest.json',
              manifestJsonContent.length,
              manifestJsonContent,
            ),
          );
          final zipBytes = ZipEncoder().encode(archive)!;
          mockXapkFile.writeAsBytesSync(zipBytes);

          // Test async read
          final asyncInfo = await AxmlModifier.readApkManifestInfo(
            mockXapkFile.path,
          );
          expect(asyncInfo, isNotNull);
          expect(asyncInfo!['packageName'], equals('com.whatsapp'));
          expect(asyncInfo['name'], equals('WhatsApp'));
          expect(asyncInfo['versionName'], equals('2.26.36.74'));
          expect(asyncInfo['versionCode'], equals('24263674'));

          // Test sync read
          final syncInfo = AxmlModifier.readApkManifestInfoSync(
            mockXapkFile.path,
          );
          expect(syncInfo, isNotNull);
          expect(syncInfo!['packageName'], equals('com.whatsapp'));
          expect(syncInfo['name'], equals('WhatsApp'));
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'cloneXapkFile end-to-end workflow extracts, renames, signs, and repacks',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('ja_xapk_e2e_');
        try {
          final mockXapkFile = File('${tempDir.path}/whatsapp_source.xapk');
          final archive = Archive();
          final manifestJsonContent = utf8.encode(
            jsonEncode({
              'xapk_version': 1,
              'package_name': 'com.whatsapp',
              'name': 'WhatsApp',
              'version_code': 24263674,
              'version_name': '2.26.36.74',
              'split_apks': [
                {'file': 'com.whatsapp.apk', 'id': 'base'},
                {'file': 'config.arm64_v8a.apk', 'id': 'config.arm64_v8a'},
              ],
            }),
          );
          archive.addFile(
            ArchiveFile(
              'manifest.json',
              manifestJsonContent.length,
              manifestJsonContent,
            ),
          );

          // Add a mock split APK
          final splitManifestBytes = _createMockSplitManifest(
            package: 'com.whatsapp',
            split: 'config.arm64_v8a',
          );
          final splitApkArchive = Archive();
          splitApkArchive.addFile(
            ArchiveFile(
              'AndroidManifest.xml',
              splitManifestBytes.length,
              splitManifestBytes,
            ),
          );
          final splitApkBytes = ZipEncoder().encode(splitApkArchive)!;
          archive.addFile(
            ArchiveFile(
              'config.arm64_v8a.apk',
              splitApkBytes.length,
              splitApkBytes,
            ),
          );

          final baseManifest = AxmlModifier.modifyManifest(
            manifestBytes: fixtures.manifest(),
            oldPackage: 'com.test.app',
            newPackage: 'com.whatsapp',
          );
          final baseArchive = Archive()
            ..addFile(
              ArchiveFile(
                'AndroidManifest.xml',
                baseManifest.length,
                baseManifest,
              ),
            );
          final baseBytes = ZipEncoder().encode(baseArchive)!;
          archive.addFile(
            ArchiveFile('com.whatsapp.apk', baseBytes.length, baseBytes),
          );
          archive.addFile(
            ArchiveFile('Android/obb/com.whatsapp/main.1.com.whatsapp.obb', 2, [
              1,
              2,
            ]),
          );
          archive.addFile(
            ArchiveFile(
              'Android/obb/com.whatsapp/patch.1.com.whatsapp.obb',
              2,
              [3, 4],
            ),
          );

          final xapkBytes = ZipEncoder().encode(archive)!;
          mockXapkFile.writeAsBytesSync(xapkBytes);

          final outDir = Directory('${tempDir.path}/output');
          outDir.createSync();

          final cloner = AppClonerService(signerFactory: () => MockApkSigner());
          final result = await cloner.cloneXapkFile(
            sourceXapkPath: mockXapkFile.path,
            targetDirectory: outDir.path,
            oldPackage: 'com.whatsapp',
            newPackage: 'com.whatsapp.clone1',
            newAppName: 'WhatsApp Dual',
          );

          expect(result.isSuccess, isTrue);
          expect(result.outputPath, isNotNull);
          expect(File(result.outputPath!).existsSync(), isTrue);

          // Verify output XAPK contents
          final outXapkBytes = File(result.outputPath!).readAsBytesSync();
          final outArchive = ZipDecoder().decodeBytes(outXapkBytes);
          final outManifest = outArchive.findFile('manifest.json');
          expect(outManifest, isNotNull);

          final outManifestJson =
              jsonDecode(utf8.decode(outManifest!.content as List<int>)) as Map;
          expect(
            outManifestJson['package_name'],
            equals('com.whatsapp.clone1'),
          );
          expect(outManifestJson['name'], equals('WhatsApp Dual'));
          expect(outManifestJson['split_apks'], [
            {'file': 'com.whatsapp.clone1.apk', 'id': 'base'},
            {'file': 'config.arm64_v8a.apk', 'id': 'config.arm64_v8a'},
          ]);
          for (final name in [
            'com.whatsapp.clone1.apk',
            'config.arm64_v8a.apk',
          ]) {
            final apk = outArchive.findFile(name);
            expect(apk, isNotNull);
            final contents = ZipDecoder().decodeBytes(
              apk!.content as List<int>,
            );
            final info = AxmlModifier.parseManifestInfo(
              Uint8List.fromList(
                contents.findFile('AndroidManifest.xml')!.content as List<int>,
              ),
            );
            expect(info['packageName'], 'com.whatsapp.clone1');
            if (name.startsWith('config.')) expect(info['isSplit'], 'true');
          }
          expect(
            outArchive
                .findFile(
                  'Android/obb/com.whatsapp.clone1/main.1.com.whatsapp.clone1.obb',
                )!
                .content,
            [1, 2],
          );
          expect(
            outArchive
                .findFile(
                  'Android/obb/com.whatsapp.clone1/patch.1.com.whatsapp.clone1.obb',
                )!
                .content,
            [3, 4],
          );
        } finally {
          tempDir.deleteSync(recursive: true);
        }
      },
    );

    test(
      'If WhatsApp XAPK exists on disk, reads manifest info cleanly',
      () async {
        final file = File(testXapkPath);
        if (file.existsSync()) {
          final info = await AxmlModifier.readApkManifestInfo(testXapkPath);
          expect(info, isNotNull);
          expect(info!['packageName'], equals('com.whatsapp'));
          expect(info['name'], contains('WhatsApp'));
        }
      },
    );

    test('installApkPath triggers loadApps automatically on success', () async {
      final commands = <List<String>>[];
      final logic = AppLogic(
        initialize: false,
        adbPath: 'mock_adb',
        processRunner:
            (
              exe,
              args, {
              runInShell = false,
              stdoutEncoding,
              stderrEncoding,
            }) async {
              commands.add(args);
              if (args.contains('pm') && args.contains('list')) {
                return ProcessResult(0, 0, 'package:com.whatsapp.clone1\n', '');
              }
              return ProcessResult(0, 0, 'Success', '');
            },
      );
      logic.setSelectedDeviceForTesting('device_123');

      final success = await logic.installApkPath('test_clone.apk');
      expect(success, isTrue);
      // Allow unawaited loadApps() to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        logic.apps.any((a) => a.packageName == 'com.whatsapp.clone1'),
        isTrue,
      );
    });
  });
}

class MockApkSigner extends ApkSigner {
  MockApkSigner()
    : super(
        java: 'java',
        jar: 'mock.jar',
        keystore: 'mock.jks',
        manageDebugKeystore: false,
        runner: (exe, args) async =>
            ProcessResult(0, 0, 'Verified using v2 scheme: true', ''),
      );

  @override
  Future<void> signAndVerify(String unsigned, String signed) async {
    await File(unsigned).copy(signed);
  }
}

Uint8List _createMockSplitManifest({
  required String package,
  required String split,
}) {
  final strings = [package, split, 'split', 'package', 'manifest'];
  final strBytesList = <List<int>>[];
  for (final s in strings) {
    final b = BytesBuilder();
    final enc = utf8.encode(s);
    b.addByte(s.length);
    b.addByte(enc.length);
    b.add(enc);
    b.addByte(0);
    strBytesList.add(b.toBytes());
  }

  final stringsDataBuilder = BytesBuilder();
  final offsets = <int>[];
  for (final sb in strBytesList) {
    offsets.add(stringsDataBuilder.length);
    stringsDataBuilder.add(sb);
  }
  final unaligned = stringsDataBuilder.length % 4;
  if (unaligned != 0) {
    for (var i = 0; i < 4 - unaligned; i++) {
      stringsDataBuilder.addByte(0);
    }
  }
  final stringsData = stringsDataBuilder.toBytes();

  const headerSize = 28;
  final offsetsSize = strings.length * 4;
  final stringsStart = headerSize + offsetsSize;
  final poolChunkSize = stringsStart + stringsData.length;

  final poolBuilder = BytesBuilder();
  final pHeader = ByteData(headerSize);
  pHeader.setUint16(0, 0x0001, Endian.little);
  pHeader.setUint16(2, headerSize, Endian.little);
  pHeader.setUint32(4, poolChunkSize, Endian.little);
  pHeader.setUint32(8, strings.length, Endian.little);
  pHeader.setUint32(12, 0, Endian.little);
  pHeader.setUint32(16, 0x00000100, Endian.little); // UTF-8
  pHeader.setUint32(20, stringsStart, Endian.little);
  pHeader.setUint32(24, 0, Endian.little);
  poolBuilder.add(pHeader.buffer.asUint8List());

  final offsetsData = ByteData(offsetsSize);
  for (var i = 0; i < strings.length; i++) {
    offsetsData.setUint32(i * 4, offsets[i], Endian.little);
  }
  poolBuilder.add(offsetsData.buffer.asUint8List());
  poolBuilder.add(stringsData);
  final poolBytes = poolBuilder.toBytes();

  const attrCount = 2;
  const attrSize = 20;
  const attrStart = 20;
  const elemChunkSize = 16 + attrStart + attrCount * attrSize;

  final elemBuilder = ByteData(elemChunkSize);
  elemBuilder.setUint16(0, 0x0102, Endian.little);
  elemBuilder.setUint16(2, 16, Endian.little);
  elemBuilder.setUint32(4, elemChunkSize, Endian.little);
  elemBuilder.setUint32(8, 1, Endian.little);
  elemBuilder.setUint32(12, 0xFFFFFFFF, Endian.little);
  elemBuilder.setUint32(16, 0xFFFFFFFF, Endian.little);
  elemBuilder.setUint32(20, 4, Endian.little); // tag = 'manifest'
  elemBuilder.setUint16(24, attrStart, Endian.little);
  elemBuilder.setUint16(26, attrSize, Endian.little);
  elemBuilder.setUint16(28, attrCount, Endian.little);
  elemBuilder.setUint16(30, 0, Endian.little);
  elemBuilder.setUint16(32, 0, Endian.little);
  elemBuilder.setUint16(34, 0, Endian.little);

  // Attr 0: package="package"
  const a0 = 36;
  elemBuilder.setUint32(a0, 0xFFFFFFFF, Endian.little);
  elemBuilder.setUint32(a0 + 4, 3, Endian.little); // name = 'package'
  elemBuilder.setUint32(a0 + 8, 0, Endian.little); // rawValue = package
  elemBuilder.setUint16(a0 + 12, 8, Endian.little);
  elemBuilder.setUint8(a0 + 14, 0);
  elemBuilder.setUint8(a0 + 15, 3);
  elemBuilder.setUint32(a0 + 16, 0, Endian.little);

  // Attr 1: split="split"
  const a1 = 56;
  elemBuilder.setUint32(a1, 0xFFFFFFFF, Endian.little);
  elemBuilder.setUint32(a1 + 4, 2, Endian.little); // name = 'split'
  elemBuilder.setUint32(a1 + 8, 1, Endian.little); // rawValue = split
  elemBuilder.setUint16(a1 + 12, 8, Endian.little);
  elemBuilder.setUint8(a1 + 14, 0);
  elemBuilder.setUint8(a1 + 15, 3);
  elemBuilder.setUint32(a1 + 16, 1, Endian.little);

  final totalSize = 8 + poolBytes.length + elemChunkSize;
  final fHeader = ByteData(8);
  fHeader.setUint32(0, 0x00080003, Endian.little);
  fHeader.setUint32(4, totalSize, Endian.little);

  final fullAxml = BytesBuilder();
  fullAxml.add(fHeader.buffer.asUint8List());
  fullAxml.add(poolBytes);
  fullAxml.add(elemBuilder.buffer.asUint8List());

  return fullAxml.toBytes();
}
