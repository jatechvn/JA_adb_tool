import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/services/app_power_manager.dart';
import 'package:ja_adb_tool/modules/ui/glass_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppPowerManager powerManager;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    powerManager = AppPowerManager.instance;
    powerManager.resetForTesting();
  });

  tearDown(() {
    powerManager.resetForTesting();
  });

  group('AsymmetricMarqueeText Session Epoch & Offset Freezing Tests', () {
    testWidgets('scrolls when text overflows constraints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 120,
              child: AsymmetricMarqueeText(
                text:
                    'This is a very long text string that overflows 120px easily',
                pauseStart: Duration(milliseconds: 100),
                pauseEnd: Duration(milliseconds: 100),
                velocity: 60.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AsymmetricMarqueeText), findsOneWidget);

      // Wait initial pause
      await tester.pump(const Duration(milliseconds: 120));

      // Pump 500ms into scrolling
      await tester.pump(const Duration(milliseconds: 500));

      final scrollable = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(AsymmetricMarqueeText),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final offset = scrollable.controller?.offset ?? 0.0;
      expect(offset, greaterThan(0.0));
    });

    testWidgets('freezes offset on blur and prevents ghost callbacks', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: AsymmetricMarqueeText(
                text:
                    'Another very long overflow sentence testing blur freezing',
                pauseStart: Duration(milliseconds: 100),
                pauseEnd: Duration(milliseconds: 100),
                velocity: 50.0,
              ),
            ),
          ),
        ),
      );

      // Start scrolling
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 400));

      final scrollable = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(AsymmetricMarqueeText),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final offsetBeforeBlur = scrollable.controller?.offset ?? 0.0;
      expect(offsetBeforeBlur, greaterThan(0.0));

      // Blur window — must freeze offset and cancel timer
      powerManager.onWindowBlur();
      await tester.pump();

      // Check offset is frozen at current position
      final offsetAtBlur = scrollable.controller?.offset ?? 0.0;
      expect(offsetAtBlur, closeTo(offsetBeforeBlur, 2.0));

      // Advance time while blurred — offset must remain frozen
      await tester.pump(const Duration(seconds: 3));
      final offsetStillFrozen = scrollable.controller?.offset ?? 0.0;
      expect(offsetStillFrozen, equals(offsetAtBlur));

      // Zero transient animation frames while blurred
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('resumes from frozen offset without snapping to 0', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: AsymmetricMarqueeText(
                text: 'Long sentence testing resumption from frozen position',
                pauseStart: Duration(milliseconds: 100),
                pauseEnd: Duration(milliseconds: 100),
                velocity: 50.0,
              ),
            ),
          ),
        ),
      );

      // Scroll forward
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 300));

      final scrollable = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(AsymmetricMarqueeText),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final frozenOffset = scrollable.controller?.offset ?? 0.0;
      expect(frozenOffset, greaterThan(0.0));

      // Blur
      powerManager.onWindowBlur();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Refocus window
      powerManager.onWindowFocus();
      await tester.pump();

      // Ensure it did not immediately snap back to 0 on resume
      final offsetOnResume = scrollable.controller?.offset ?? 0.0;
      expect(offsetOnResume, closeTo(frozenOffset, 2.0));

      // Pump to continue scrolling forward from frozen offset
      await tester.pump(const Duration(milliseconds: 400));
      final offsetAfterResume = scrollable.controller?.offset ?? 0.0;
      expect(offsetAfterResume, greaterThan(offsetOnResume));
    });
  });
}
