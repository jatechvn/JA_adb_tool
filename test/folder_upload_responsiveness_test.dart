import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/ui/dialogs.dart';
import 'package:ja_adb_tool/modules/ui/main_window.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Create Folder & Upload Responsiveness Tests', () {
    test(
      'createAndroidFolder sets isAndroidLoading immediately during execution',
      () async {
        bool sawLoadingDuringExecution = false;

        final logic = AppLogic(
          initialize: false,
          adbPath: 'fake-adb',
          processRunner: (exe, args, {stdoutEncoding, stderrEncoding}) async {
            if (args.contains('mkdir')) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return ProcessResult(1, 0, '', '');
            }
            if (args.contains('ls')) {
              return ProcessResult(
                1,
                0,
                'total 0\ndrwxr-xr-x 2 root root 4096 2026-01-01 00:00 .\ndrwxr-xr-x 2 root root 4096 2026-01-01 00:00 ..\n',
                '',
              );
            }
            return ProcessResult(1, 0, '', '');
          },
        );

        unawaited(logic.selectDevice('dev-1'));
        expect(logic.isAndroidLoading, isFalse);

        logic.addListener(() {
          if (logic.isAndroidLoading) {
            sawLoadingDuringExecution = true;
          }
        });

        final future = logic.createAndroidFolder('my_new_folder');
        expect(logic.isAndroidLoading, isTrue); // Instant 0ms feedback!

        final ok = await future;
        expect(ok, isTrue);
        expect(sawLoadingDuringExecution, isTrue);
        expect(logic.isAndroidLoading, isFalse);
      },
    );

    testWidgets('CreateFolderDialog submits on Enter key press', (
      tester,
    ) async {
      String? submittedName;
      final lang = LanguageProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(
              create: (_) => AppLogic(initialize: false, adbPath: 'fake-adb'),
            ),
            ChangeNotifierProvider.value(value: lang),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    submittedName = await showDialog<String>(
                      context: context,
                      builder: (ctx) => const CreateFolderDialog(),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CreateFolderDialog), findsOneWidget);

      // Enter text and submit with onSubmitted (Enter)
      await tester.enterText(find.byType(TextField), 'TestFolder123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CreateFolderDialog), findsNothing);
      expect(submittedName, equals('TestFolder123'));
    });

    test(
      'Media preload caches empty results so ADB is not spammed every 5s',
      () async {
        int queryCount = 0;

        final logic = AppLogic(
          initialize: false,
          adbPath: 'fake-adb',
          processRunner: (exe, args, {stdoutEncoding, stderrEncoding}) async {
            if (args.contains('content') && args.contains('query')) {
              queryCount++;
              return ProcessResult(1, 0, 'No result found.\n', '');
            }
            if (args.contains('devices')) {
              return ProcessResult(
                1,
                0,
                'List of devices attached\ndev-test\tdevice\n',
                '',
              );
            }
            return ProcessResult(1, 0, '', '');
          },
        );

        // First query
        final firstFetch = await logic.ensureLatestMediaForTesting('dev-test');
        expect(firstFetch, isEmpty);
        expect(queryCount, greaterThan(0));

        final countAfterFirst = queryCount;

        // Second query with !force should return cached result immediately without calling adb
        final secondFetch = await logic.ensureLatestMediaForTesting('dev-test');
        expect(secondFetch, isEmpty);
        expect(
          queryCount,
          equals(countAfterFirst),
        ); // Cached! No additional ADB calls!
      },
    );

    testWidgets(
      'File Explorer toolbar renders direct New Folder, Upload Files, and Upload Folder buttons',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final logic = AppLogic(
          initialize: false,
          adbPath: 'fake-adb',
          processRunner: (exe, args, {stdoutEncoding, stderrEncoding}) async {
            if (args.contains('ls')) {
              return ProcessResult(
                1,
                0,
                'total 0\ndrwxr-xr-x 2 root root 4096 2026-01-01 00:00 .\ndrwxr-xr-x 2 root root 4096 2026-01-01 00:00 ..\n',
                '',
              );
            }
            return ProcessResult(1, 0, '', '');
          },
        );
        unawaited(logic.selectDevice('dev-toolbar-test'));

        final theme = ThemeProvider();
        final lang = LanguageProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: theme),
              ChangeNotifierProvider.value(value: logic),
              ChangeNotifierProvider.value(value: lang),
            ],
            child: const MaterialApp(home: MainWindow()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to Explorer Tab (index 1)
        final explorerTabFinder = find.text('File Explorer');
        expect(explorerTabFinder, findsOneWidget);
        await tester.tap(explorerTabFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify that direct action buttons are present in the explorer toolbar
        expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
        expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget);
        expect(find.byIcon(Icons.drive_folder_upload_outlined), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsAtLeastNWidgets(1));
      },
    );
  });
}
