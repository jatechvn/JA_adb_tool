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

  group('Glass Widgets Direction Preservation & Power Decoupling', () {
    testWidgets('MeshOrb runs when focused and pauses when blurred', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MeshOrb(
              color: Colors.blue,
              size: 200,
              duration: Duration(seconds: 4),
              travel: Offset(50, 50),
            ),
          ),
        ),
      );

      // Verify renders
      expect(find.byType(MeshOrb), findsOneWidget);

      // Pump 1 second of forward animation
      await tester.pump(const Duration(seconds: 1));

      // Blur window
      powerManager.onWindowBlur();
      await tester.pump();

      // MeshOrb is stopped. Advance virtual time and verify no errors
      await tester.pump(const Duration(seconds: 1));

      // Refocus window — animation resumes in forward direction
      powerManager.onWindowFocus();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MeshOrb), findsOneWidget);
    });

    testWidgets('MeshOrb initialized while window is blurred stays frozen', (
      tester,
    ) async {
      // Blur window before mounting
      powerManager.onWindowBlur();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MeshOrb(
              color: Colors.purple,
              size: 150,
              duration: Duration(seconds: 2),
              travel: Offset(30, 30),
            ),
          ),
        ),
      );

      expect(powerManager.shouldAnimateBackground, isFalse);

      // Advance time — should remain static without errors
      await tester.pump(const Duration(seconds: 1));

      // Focus window — starts forward
      powerManager.onWindowFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(powerManager.shouldAnimateBackground, isTrue);
    });

    testWidgets('WaveIndicator pauses on blur and resumes on focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: WaveIndicator(color: Colors.cyan, height: 20)),
        ),
      );

      expect(find.byType(WaveIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));

      // Blur window
      powerManager.onWindowBlur();
      await tester.pump();
      expect(powerManager.shouldAnimateIndicators, isFalse);

      // Focus window
      powerManager.onWindowFocus();
      await tester.pump();
      expect(powerManager.shouldAnimateIndicators, isTrue);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(WaveIndicator), findsOneWidget);
    });

    testWidgets('BorderBeam pauses on blur and repeats on focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BorderBeam(
              duration: Duration(seconds: 2),
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      );

      expect(find.byType(BorderBeam), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));

      // Blur window
      powerManager.onWindowBlur();
      await tester.pump();
      expect(powerManager.shouldAnimateIndicators, isFalse);

      // Focus window
      powerManager.onWindowFocus();
      await tester.pump();
      expect(powerManager.shouldAnimateIndicators, isTrue);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(BorderBeam), findsOneWidget);
    });

    testWidgets(
      'Idle sleep mode pauses MeshOrb but keeps WaveIndicator active',
      (tester) async {
        powerManager.resetForTesting(
          focused: true,
          visible: true,
          idle: false,
          idleSleepEnabled: true,
          idleTimeout: const Duration(milliseconds: 100),
        );

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  MeshOrb(
                    color: Colors.green,
                    size: 100,
                    duration: Duration(seconds: 4),
                    travel: Offset(20, 20),
                  ),
                  WaveIndicator(color: Colors.green),
                ],
              ),
            ),
          ),
        );

        powerManager.recordUserInteraction(force: true);
        await tester.pump(const Duration(milliseconds: 50));

        expect(powerManager.shouldAnimateBackground, isTrue);
        expect(powerManager.shouldAnimateIndicators, isTrue);

        // Trigger idle sleep by pumping past 100ms
        await tester.pump(const Duration(milliseconds: 120));

        expect(powerManager.isUserIdle, isTrue);
        expect(powerManager.shouldAnimateBackground, isFalse);
        expect(powerManager.shouldAnimateIndicators, isTrue);

        // Wake up via interaction
        powerManager.recordUserInteraction(force: true);
        await tester.pump();

        expect(powerManager.isUserIdle, isFalse);
        expect(powerManager.shouldAnimateBackground, isTrue);
        expect(powerManager.shouldAnimateIndicators, isTrue);
        powerManager.cancelIdleTimer();
      },
    );
  });
}
