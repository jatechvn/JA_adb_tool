import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/services/ota_update_service.dart';
import 'package:ja_adb_tool/modules/ui/main_window.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';
import 'package:ja_adb_tool/modules/ui/app_toast.dart';

class MockScreenshotLogic extends AppLogic {
  MockScreenshotLogic() : super(initialize: false);

  bool _mockMirrorRunning = false;
  void setMirrorRunningForTesting(bool running) {
    _mockMirrorRunning = running;
    notifyListeners();
  }

  @override
  bool get isMirrorRunning => _mockMirrorRunning;
  @override
  bool get isMirroring => _mockMirrorRunning;
  @override
  String? get selectedDevice => 'mock-device';
  @override
  String get adbPath => 'mock-adb';
  @override
  String get scrcpyPath => 'mock-scrcpy';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Screenshot Logic Tests', () {
    test('isCapturingScreenshot initial state is false', () {
      final logic = AppLogic(initialize: false);
      expect(logic.isCapturingScreenshot, isFalse);
      logic.dispose();
    });

    test(
      'takeScreenshot returns null immediately if no device selected',
      () async {
        final logic = AppLogic(initialize: false);
        expect(logic.selectedDevice, isNull);
        final res = await logic.takeScreenshot();
        expect(res, isNull);
        expect(logic.isCapturingScreenshot, isFalse);
        logic.dispose();
      },
    );

    test('isRotatingScreen initial state is false', () {
      final logic = AppLogic(initialize: false);
      expect(logic.isRotatingScreen, isFalse);
      logic.dispose();
    });

    test(
      'rotateDeviceScreen returns false immediately if no device selected',
      () async {
        final logic = AppLogic(initialize: false);
        expect(logic.selectedDevice, isNull);
        final res = await logic.rotateDeviceScreen();
        expect(res, isFalse);
        expect(logic.isRotatingScreen, isFalse);
        logic.dispose();
      },
    );
  });

  group('Toast Alignment & Scrcpy Occlusion Protection', () {
    testWidgets(
      'AppToastWidget positions at bottom-left when alignment is bottomLeft',
      (tester) async {
        final theme = ThemeProvider();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  AppToastWidget(
                    message: 'Test Screenshot Toast',
                    icon: Icons.camera_alt,
                    colors: theme.colors,
                    accent: Colors.cyan,
                    onDismiss: () {},
                    alignment: Alignment.bottomLeft,
                  ),
                ],
              ),
            ),
          ),
        );

        final positionedFinder = find.byType(Positioned);
        expect(positionedFinder, findsOneWidget);
        final positioned = tester.widget<Positioned>(positionedFinder);
        expect(positioned.left, equals(24));
        expect(positioned.right, isNull);
        expect(positioned.bottom, equals(28));

        // Verify maxWidth is constrained to 420 to prevent Scrcpy HWND occlusion
        final constrainedFinder = find.descendant(
          of: find.byType(AppToastWidget),
          matching: find.byType(ConstrainedBox),
        );
        expect(constrainedFinder, findsOneWidget);
        final constrained = tester.widget<ConstrainedBox>(constrainedFinder);
        expect(constrained.constraints.maxWidth, equals(420));
      },
    );

    testWidgets(
      'AppToastWidget positions centered when alignment is bottomCenter',
      (tester) async {
        final theme = ThemeProvider();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  AppToastWidget(
                    message: 'Test Center Toast',
                    icon: Icons.info,
                    colors: theme.colors,
                    accent: Colors.cyan,
                    onDismiss: () {},
                    alignment: Alignment.bottomCenter,
                  ),
                ],
              ),
            ),
          ),
        );

        final positionedFinder = find.byType(Positioned);
        expect(positionedFinder, findsOneWidget);
        final positioned = tester.widget<Positioned>(positionedFinder);
        expect(positioned.left, equals(0));
        expect(positioned.right, equals(0));
        expect(positioned.bottom, equals(28));
      },
    );

    testWidgets(
      'showAppToast auto-selects bottomLeft when logic.isMirrorRunning is true',
      (tester) async {
        final logic = MockScreenshotLogic();
        final theme = ThemeProvider();

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AppLogic>.value(value: logic),
              ChangeNotifierProvider<ThemeProvider>.value(value: theme),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        context.showSuccessToast('Screenshot saved to disk');
                      },
                      child: const Text('Show Toast'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        // Tap to trigger toast when mirror is not running
        await tester.tap(find.text('Show Toast'));
        await tester.pump();
        var toastWidget = tester.widget<AppToastWidget>(
          find.byType(AppToastWidget),
        );
        expect(toastWidget.alignment, equals(Alignment.bottomCenter));

        // Dismiss
        toastWidget.onDismiss();
        await tester.pump();

        // Set mirror state to running via mock
        logic.setMirrorRunningForTesting(true);
        await tester.tap(find.text('Show Toast'));
        await tester.pump();

        toastWidget = tester.widget<AppToastWidget>(
          find.byType(AppToastWidget),
        );
        expect(toastWidget.alignment, equals(Alignment.bottomLeft));

        toastWidget.onDismiss();
        await tester.pump(const Duration(seconds: 4));
        logic.dispose();
      },
    );
  });

  group('Mirror Sidebar UI Layout & Screenshot Visibility', () {
    for (final locale in ['en', 'vi', 'zh']) {
      testWidgets(
        'Screenshot button and 2-column options are visible at 1280x800 in $locale',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final dir = Directory.systemTemp.createTempSync('screen-layout-');
          final ota = OtaUpdateService();
          ota.setCustomConfigFileForTesting(File('${dir.path}/update.json'));
          await tester.runAsync(
            () => ota.saveConfig(
              OtaUpdateConfig.defaults().copyWith(checkInterval: 'off'),
            ),
          );
          final logic = MockScreenshotLogic();
          final theme = ThemeProvider();

          tester.view.physicalSize = const Size(1280, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(() => ota.setCustomConfigFileForTesting(null));

          final lang = LanguageProvider.forTesting(locale);

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AppLogic>.value(value: logic),
                ChangeNotifierProvider<ThemeProvider>.value(value: theme),
                ChangeNotifierProvider<LanguageProvider>.value(value: lang),
              ],
              child: const MaterialApp(home: MainWindow()),
            ),
          );

          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          // Verify Take Screenshot button is in the tree and visible
          final screenshotBtnText = lang.tr('take_screenshot');
          final screenshotBtn = find.text(screenshotBtnText);
          expect(screenshotBtn, findsOneWidget);

          // Verify Rotate Screen button is in the tree and visible
          final rotateBtnText = lang.tr('rotate_screen');
          final rotateBtn = find.text(rotateBtnText);
          expect(rotateBtn, findsOneWidget);

          // Verify folder picker button is present
          final folderTooltip = lang.tr('select_screenshot_folder');
          expect(find.byTooltip(folderTooltip), findsOneWidget);

          // Verify Start/Launch Mirror button is present
          final launchBtnText = lang.tr('launch_mirror');
          expect(find.text(launchBtnText), findsOneWidget);

          // Verify compact options (e.g. stay on top, fullscreen) are present
          expect(find.text(lang.tr('stay_on_top')), findsOneWidget);
          expect(find.text(lang.tr('fullscreen')), findsOneWidget);
          expect(find.text(lang.tr('no_control')), findsOneWidget);
          expect(find.text(lang.tr('keep_awake')), findsOneWidget);
          expect(find.text(lang.tr('borderless')), findsOneWidget);
          expect(find.text(lang.tr('disable_audio')), findsOneWidget);

          // Verify Mirror Options sidebar width is 240px (expanded mirror area)
          final sidebarSizedBoxFinder = find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 240,
          );
          expect(sidebarSizedBoxFinder, findsOneWidget);

          // Check that screenshot button is within top 400px of screen (not pushed down)
          final renderBox = tester.renderObject(screenshotBtn) as RenderBox;
          final position = renderBox.localToGlobal(Offset.zero);
          expect(
            position.dy,
            lessThan(450),
          ); // Comfortably in upper half of the 800px window

          await tester.pumpWidget(const SizedBox.shrink());
          logic.dispose();
          theme.dispose();
          lang.dispose();
          await tester.pump();
        },
      );
    }
  });

  group('Quick Tools & App Cloner Navigation Tests', () {
    testWidgets('Quick tools grid does not contain app cloner shortcut', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory.systemTemp.createTempSync('quick-cloner-');
      final ota = OtaUpdateService();
      ota.setCustomConfigFileForTesting(File('${dir.path}/update.json'));
      await tester.runAsync(
        () => ota.saveConfig(
          OtaUpdateConfig.defaults().copyWith(checkInterval: 'off'),
        ),
      );
      final logic = MockScreenshotLogic();
      final theme = ThemeProvider();
      final lang = LanguageProvider.forTesting('en');

      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => ota.setCustomConfigFileForTesting(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppLogic>.value(value: logic),
            ChangeNotifierProvider<ThemeProvider>.value(value: theme),
            ChangeNotifierProvider<LanguageProvider>.value(value: lang),
          ],
          child: const MaterialApp(home: MainWindow()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Quick Tools tab (nav item index 6)
      final quickToolsNav = find.text(lang.tr('quick_tools_tab'));
      expect(quickToolsNav, findsOneWidget);
      await tester.tap(quickToolsNav);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify App Cloner is NOT in Quick Tools grid
      final appClonerText = lang.tr('app_cloner_title');
      expect(find.text(appClonerText), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      logic.dispose();
      theme.dispose();
      lang.dispose();
      await tester.pump();
    });
  });
}
