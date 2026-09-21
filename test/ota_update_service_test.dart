import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:ja_adb_tool/modules/constants.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/services/ota_update_service.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/dialogs.dart';
import 'package:ja_adb_tool/modules/ui/glass_update_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File configFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ja_adb_tool_ota_test_');
    configFile = File('${tempDir.path}/update_config.json');

    OtaUpdateService().setCustomConfigFileForTesting(configFile);
    OtaUpdateService().setCustomServerDirForTesting(null);
  });

  tearDown(() async {
    OtaUpdateService().setCustomConfigFileForTesting(null);
    OtaUpdateService().setCustomServerDirForTesting(null);

    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('SemanticVersion Unit Tests', () {
    test('Release follows rc and malformed versions are rejected', () {
      expect(
        SemanticVersion.tryParse('1.2.0-rc.2')! <
            SemanticVersion.tryParse('1.2.0-rc.10')!,
        isTrue,
      );
      expect(
        SemanticVersion.tryParse('1.2.0-rc.10')! <
            SemanticVersion.tryParse('1.2.0')!,
        isTrue,
      );
      expect(SemanticVersion.tryParse('1.2.3.4'), isNull);
      expect(
        SemanticVersion.tryParse('1.2.0')!.hashCode,
        equals(SemanticVersion.tryParse('1.2.0+0')!.hashCode),
      );
      expect(
        OtaUpdateService.isValidPackageName('../other_v9.0.0.zip'),
        isFalse,
      );
      expect(
        OtaUpdateService.isValidPackageName('OtherApp_v9.0.0.zip'),
        isFalse,
      );
      expect(
        OtaUpdateService.isValidPackageName(
          'JA_adb_tool_v1.7.5_Windows_x64.zip',
        ),
        isTrue,
      );
    });

    test('Correctly parses SemVer formats with and without prefix', () {
      final v1 = SemanticVersion.tryParse('1.0.0');
      expect(v1, isNotNull);
      expect(v1!.major, equals(1));
      expect(v1.minor, equals(0));
      expect(v1.patch, equals(0));
      expect(v1.build, isNull);

      final v2 = SemanticVersion.tryParse('v1.7.5+14');
      expect(v2, isNotNull);
      expect(v2!.major, equals(1));
      expect(v2.minor, equals(7));
      expect(v2.patch, equals(5));
      expect(v2.build, equals(14));

      final v3 = SemanticVersion.tryParse('1.1');
      expect(v3, isNotNull);
      expect(v3!.major, equals(1));
      expect(v3.minor, equals(1));
      expect(v3.patch, equals(0));

      final vInvalid = SemanticVersion.tryParse('invalid_version_string');
      expect(vInvalid, isNull);

      final vNull = SemanticVersion.tryParse(null);
      expect(vNull, isNull);
    });

    test('SemanticVersion comparison operators work correctly', () {
      final v100 = SemanticVersion.tryParse('1.0.0')!;
      final v101 = SemanticVersion.tryParse('1.0.1')!;
      final v110 = SemanticVersion.tryParse('1.1.0')!;
      final v200 = SemanticVersion.tryParse('2.0.0')!;
      final v100b1 = SemanticVersion.tryParse('1.0.0+1')!;
      final v100b2 = SemanticVersion.tryParse('1.0.0+2')!;

      expect(v100 < v101, isTrue);
      expect(v101 < v110, isTrue);
      expect(v110 < v200, isTrue);
      expect(v200 > v110, isTrue);
      expect(v100b1 < v100b2, isTrue);
      expect(v100 == SemanticVersion.tryParse('1.0.0')!, isTrue);
      expect(v110 >= v100, isTrue);
      expect(v100 <= v110, isTrue);
      expect(v100 > v110, isFalse);
    });

    test('SemanticVersion string representation is consistent', () {
      final v1 = SemanticVersion.tryParse('1.2.3')!;
      expect(v1.toString(), equals('1.2.3'));

      final v2 = SemanticVersion.tryParse('v1.7.5+14')!;
      expect(v2.toString(), equals('1.7.5+14'));
      expect(v2.displayVersion, equals('v1.7.5+14'));
    });
  });

  group('UpdatePackageInfo & OtaUpdateConfig Tests', () {
    test('formattedSize converts bytes to human-readable units', () {
      final pkg0 = UpdatePackageInfo(
        version: SemanticVersion.tryParse('1.0.0')!,
        fileName: 'test.zip',
        fullPath: '/path/test.zip',
        fileSize: 0,
      );
      expect(pkg0.formattedSize, equals('0 B'));

      final pkgKb = UpdatePackageInfo(
        version: SemanticVersion.tryParse('1.0.0')!,
        fileName: 'test.zip',
        fullPath: '/path/test.zip',
        fileSize: 1024,
      );
      expect(pkgKb.formattedSize, equals('1.00 KB'));

      final pkgMb = UpdatePackageInfo(
        version: SemanticVersion.tryParse('1.0.0')!,
        fileName: 'test.zip',
        fullPath: '/path/test.zip',
        fileSize: 15 * 1024 * 1024,
      );
      expect(pkgMb.formattedSize, contains('MB'));
    });

    test('OtaUpdateConfig serialization and deserialization', () {
      const config = OtaUpdateConfig(
        serverPath: r'\\server\share\updates',
        username: 'admin',
        password: 'secretPassword',
        checkInterval: 'weekly',
        autoDownload: false,
      );

      final json = config.toJson();
      expect(json['serverPath'], equals(r'\\server\share\updates'));
      expect(json['username'], equals('admin'));
      expect(json['password'], equals('secretPassword'));
      expect(json['checkInterval'], equals('weekly'));

      final parsed = OtaUpdateConfig.fromJson(json);
      expect(parsed.serverPath, equals(config.serverPath));
      expect(parsed.username, equals(config.username));
      expect(parsed.password, equals(config.password));
      expect(parsed.checkInterval, equals(config.checkInterval));
    });

    test('OtaUpdateConfig defaults use expected LAN update path', () {
      final defaults = OtaUpdateConfig.defaults();
      expect(defaults.serverPath, contains('10.81.141.226'));
      expect(defaults.serverPath, contains('JA_adb_tool'));
      expect(defaults.username, equals('user'));
      expect(defaults.password, equals('user'));
      expect(defaults.checkInterval, equals('daily'));
    });
  });

  group('OtaUpdateService Logic Tests', () {
    test('extractSmbShareRoot properly parses UNC root path', () {
      expect(
        OtaUpdateService.extractSmbShareRoot(
          r'\\10.81.141.226\temp\FBT\JA_PROJECT\JA_Update\JA_adb_tool',
        ),
        equals(r'\\10.81.141.226\temp'),
      );

      expect(
        OtaUpdateService.extractSmbShareRoot(r'\\192.168.1.100\SharedFolder'),
        equals(r'\\192.168.1.100\SharedFolder'),
      );

      expect(
        OtaUpdateService.extractSmbShareRoot('//10.81.141.226/temp/subfolder'),
        equals(r'\\10.81.141.226\temp'),
      );

      expect(OtaUpdateService.extractSmbShareRoot(r'C:\LocalFolder'), isNull);
    });

    test(
      'shouldCheckForUpdates respects configured intervals and elapsed time',
      () {
        final service = OtaUpdateService();
        final now = DateTime(2026, 9, 21, 12, 0, 0);

        expect(
          service.shouldCheckForUpdates(
            interval: 'off',
            lastCheckTime: null,
            now: now,
          ),
          isFalse,
        );

        expect(
          service.shouldCheckForUpdates(
            interval: 'never',
            lastCheckTime: null,
            now: now,
          ),
          isFalse,
        );

        expect(
          service.shouldCheckForUpdates(
            interval: 'startup',
            lastCheckTime: now,
            now: now,
          ),
          isTrue,
        );

        expect(
          service.shouldCheckForUpdates(
            interval: 'daily',
            lastCheckTime: null,
            now: now,
          ),
          isTrue,
        );

        expect(
          service.shouldCheckForUpdates(
            interval: 'daily',
            lastCheckTime: now.subtract(const Duration(hours: 23)),
            now: now,
          ),
          isFalse,
        );

        expect(
          service.shouldCheckForUpdates(
            interval: 'daily',
            lastCheckTime: now.subtract(const Duration(hours: 25)),
            now: now,
          ),
          isTrue,
        );

        expect(
          service.shouldCheckForUpdates(
            interval: 'weekly',
            lastCheckTime: now.subtract(const Duration(days: 6)),
            now: now,
          ),
          isFalse,
        );

        expect(
          service.shouldCheckForUpdates(
            interval: 'weekly',
            lastCheckTime: now.subtract(const Duration(days: 8)),
            now: now,
          ),
          isTrue,
        );
      },
    );

    test('Scans local directory for version.json and zip package', () async {
      final serverDir = Directory('${tempDir.path}/mock_server')..createSync();
      final versionJson = File('${serverDir.path}/version.json');
      final updateZip = File(
        '${serverDir.path}/JA_adb_tool_v9.9.9_Windows_x64.zip',
      );
      updateZip.writeAsStringSync('mock zip content');

      versionJson.writeAsStringSync(
        jsonEncode({
          'version': '9.9.9',
          'package': 'JA_adb_tool_v9.9.9_Windows_x64.zip',
          'releaseNotes': 'Major feature release',
          'releaseDate': '2026-09-21T00:00:00.000Z',
        }),
      );

      OtaUpdateService().setCustomServerDirForTesting(serverDir);

      final result = await OtaUpdateService().checkForUpdates(
        overrideServerPath: serverDir.path,
        isManual: true,
      );

      expect(result.isConnectionSuccess, isTrue);
      expect(result.hasUpdate, isTrue);
      expect(result.packageInfo, isNotNull);
      expect(result.packageInfo!.version.major, equals(9));
      expect(result.packageInfo!.releaseNotes, equals('Major feature release'));

      final savedConfig = await OtaUpdateService().loadConfig();
      expect(savedConfig.lastCheckTime, isNotNull);
      expect(savedConfig.cachedUpdateVersion, equals('9.9.9'));
    });

    test('generateApplyUpdateScript creates safe batch script', () {
      final script = OtaUpdateService.generateApplyUpdateScript(
        oldPid: 12345,
        exeName: 'ja_adb_tool.exe',
        sourceDir: r'C:\temp\staging',
        targetDir: r'C:\apps\ja_adb_tool',
      );

      expect(script, contains('12345'));
      expect(script, contains('ja_adb_tool.exe'));
      expect(script, contains('robocopy'));
      expect(script, contains('update_config.json'));
      expect(script, contains('logs'));
    });
  });

  group('GlassUpdateDialog Widget Tests', () {
    testWidgets(
      'renders version comparison, release notes, and update button',
      (tester) async {
        final packageInfo = UpdatePackageInfo(
          version: SemanticVersion.tryParse('2.0.0')!,
          fileName: 'JA_adb_tool_v2.0.0_Windows_x64.zip',
          fullPath: r'C:\mock\JA_adb_tool_v2.0.0_Windows_x64.zip',
          fileSize: 25 * 1024 * 1024,
          releaseNotes: '- Added LAN OTA updates\n- Added APK extraction',
          releaseDate: DateTime(2026, 9, 21),
        );

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => ThemeProvider()),
              ChangeNotifierProvider(create: (_) => LanguageProvider()),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return ElevatedButton(
                      onPressed: () {
                        showGlassUpdateDialog(
                          context: context,
                          packageInfo: packageInfo,
                        );
                      },
                      child: const Text('Show Dialog'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('v2.0.0'), findsWidgets);
        expect(find.textContaining('Added LAN OTA updates'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('ota-apply-update-button')),
          findsOneWidget,
        );
      },
    );
  });

  group('PathsSettingsDialog OTA Tab Tests', () {
    testWidgets('renders OTA tab with controls', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final languageProvider = LanguageProvider();
      final logic = AppLogic(initialize: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider<AppLogic>.value(value: logic),
            ChangeNotifierProvider.value(value: languageProvider),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => const PathsSettingsDialog(),
                      );
                    },
                    child: const Text('Open Settings'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on OTA Tab (index 1)
      final otaTab = find.text(languageProvider.tr('ota_tab_title'));
      expect(otaTab, findsOneWidget);
      await tester.tap(otaTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify controls are present
      expect(find.byKey(const ValueKey('ota-check-button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ota-test-connection-button')),
        findsOneWidget,
      );
      expect(find.textContaining('v$appVersion'), findsWidgets);

      logic.dispose();
    });
  });
}
