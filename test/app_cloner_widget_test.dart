import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/ui/app_cloner_dialog.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';

void main() {
  const testApkPath = r'D:\OLD\APK\Scanner_OK\foxlearn-3.5.8.apk';
  const testPackage = 'com.example.foxconniqdemo';
  const testAppName = 'Foxconniqdemo';

  group('AppClonerDialog Widget Tests', () {
    for (final locale in ['en', 'vi', 'zh']) {
      testWidgets('renders AppClonerDialog cleanly at 1280x800 in $locale', (
        tester,
      ) async {
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
                  directApkPath: testApkPath,
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

        // Verify default cloned values
        expect(find.text('$testAppName (Clone 1)'), findsOneWidget);
        expect(find.text('$testPackage.clone1'), findsOneWidget);

        // Verify tab labels
        expect(find.text(language.tr('clone_tab_apk')), findsOneWidget);
        expect(find.text(language.tr('clone_tab_dual_space')), findsOneWidget);

        // Verify action buttons
        expect(find.text(language.tr('start_cloning_btn')), findsOneWidget);
        expect(find.text(language.tr('apk_signing_setup')), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('allows editing cloned name, package, and toggling options', (
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
                directApkPath: testApkPath,
                initialPackage: testPackage,
                initialAppName: testAppName,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test changing cloned app name
      final nameFields = find.byType(TextField);
      expect(nameFields, findsWidgets);

      // Enter custom name
      await tester.enterText(nameFields.first, 'Foxconn Test App 2');
      await tester.pump();
      expect(find.text('Foxconn Test App 2'), findsOneWidget);

      // Enter custom package ID
      await tester.enterText(
        nameFields.at(1),
        'com.example.foxconniqdemo.test2',
      );
      await tester.pump();
      expect(find.text('com.example.foxconniqdemo.test2'), findsOneWidget);

      // Toggle save to PC checkbox
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));
      await tester.tap(checkboxes.last);
      await tester.pumpAndSettle();

      // Export dir field should now appear
      expect(find.byType(TextField), findsNWidgets(3));

      // Test tab switching
      await tester.tap(find.text(language.tr('clone_tab_dual_space')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch back to APK Clone tab
      await tester.tap(find.text(language.tr('clone_tab_apk')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Foxconn Test App 2'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
      'sanitizes placeholder initialPackage such as "Will determine during install"',
      (tester) async {
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
                  directApkPath: 'Fu-learning [3.5.2].apk',
                  initialPackage: 'Will determine during install',
                  initialAppName: 'Fu-learning [3.5.2].apk',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ensure no exceptions occurred
        expect(tester.takeException(), isNull);

        // Verify that "Will determine during install.clone1" is NOT used as package
        expect(find.text('Will determine during install.clone1'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
