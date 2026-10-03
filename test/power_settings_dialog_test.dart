import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/services/app_power_manager.dart';
import 'package:ja_adb_tool/modules/services/ota_update_service.dart';
import 'package:ja_adb_tool/modules/ui/dialogs.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppPowerManager powerManager;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    powerManager = AppPowerManager.instance;
    powerManager.resetForTesting(idleSleepEnabled: true);
    tempDir = Directory.systemTemp.createTempSync('power-dialog-test-');
    OtaUpdateService().setCustomConfigFileForTesting(
      File('${tempDir.path}/update.json'),
    );
  });

  tearDown(() {
    OtaUpdateService().setCustomConfigFileForTesting(null);
    try {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    } catch (_) {}
    powerManager.resetForTesting();
  });

  Widget buildTestDialog() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AppLogic(initialize: false)),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const MaterialApp(home: Scaffold(body: PathsSettingsDialog())),
    );
  }

  group('PathsSettingsDialog Power & GPU Optimization Tests', () {
    testWidgets(
      'renders power optimization section with switch and choice chips',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestDialog());
        await tester.pumpAndSettle();

        // Find switch
        final switchFinder = find.byType(Switch);
        await tester.ensureVisible(switchFinder);
        expect(switchFinder, findsOneWidget);
        final switchWidget = tester.widget<Switch>(switchFinder);
        expect(switchWidget.value, isTrue);

        // Find choice chips (12s, 30s, 60s)
        expect(find.byType(ChoiceChip), findsNWidgets(3));
        powerManager.cancelIdleTimer();
      },
    );

    testWidgets('toggling switch disables choice chips', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      await tester.ensureVisible(switchFinder);

      // Toggle switch to off
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);

      // Chips should be hidden when switch is false
      expect(find.byType(ChoiceChip), findsNothing);
      powerManager.cancelIdleTimer();
    });

    testWidgets('selecting 30s choice chip updates selection', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      // Find the second choice chip (which is 30s)
      final choiceChips = find.byType(ChoiceChip);
      await tester.ensureVisible(choiceChips.at(1));
      await tester.tap(choiceChips.at(1));
      await tester.pumpAndSettle();

      final updatedChip = tester.widget<ChoiceChip>(choiceChips.at(1));
      expect(updatedChip.selected, isTrue);
      powerManager.cancelIdleTimer();
    });

    testWidgets('cancel button rolls back modified power values', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestDialog());
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      await tester.ensureVisible(switchFinder);

      // Toggle switch to false inside dialog
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Click Cancel button
      final cancelButton = find.byWidgetPredicate(
        (w) =>
            w is TextButton &&
            w.child is Text &&
            (w.child as Text).data?.toLowerCase().contains('cancel') == true,
      );
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton);
      } else {
        await tester.tap(find.byIcon(Icons.close));
      }
      await tester.pumpAndSettle();

      // Manager must retain original values
      expect(powerManager.idleSleepEnabled, isTrue);
      powerManager.cancelIdleTimer();
    });
  });
}
