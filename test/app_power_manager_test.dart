import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/services/app_power_manager.dart';

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

  group('AppPowerManager Window & Lifecycle States', () {
    test('initial state has all animations active', () {
      expect(powerManager.isWindowFocused, isTrue);
      expect(powerManager.isWindowVisible, isTrue);
      expect(powerManager.isUserIdle, isFalse);
      expect(powerManager.shouldAnimateBackground, isTrue);
      expect(powerManager.shouldAnimateIndicators, isTrue);
      expect(powerManager.shouldAnimateMarquee, isTrue);
    });

    test('onWindowBlur pauses all 3 animation notifiers immediately', () {
      powerManager.onWindowBlur();

      expect(powerManager.isWindowFocused, isFalse);
      expect(powerManager.shouldAnimateBackground, isFalse);
      expect(powerManager.shouldAnimateIndicators, isFalse);
      expect(powerManager.shouldAnimateMarquee, isFalse);
    });

    test('onWindowFocus resumes all 3 animation notifiers', () {
      powerManager.onWindowBlur();
      expect(powerManager.shouldAnimateBackground, isFalse);

      powerManager.onWindowFocus();
      expect(powerManager.isWindowFocused, isTrue);
      expect(powerManager.shouldAnimateBackground, isTrue);
      expect(powerManager.shouldAnimateIndicators, isTrue);
      expect(powerManager.shouldAnimateMarquee, isTrue);
    });

    test('onWindowMinimize pauses all animations', () {
      powerManager.onWindowMinimize();

      expect(powerManager.isWindowVisible, isFalse);
      expect(powerManager.shouldAnimateBackground, isFalse);
      expect(powerManager.shouldAnimateIndicators, isFalse);
      expect(powerManager.shouldAnimateMarquee, isFalse);
    });

    test('onWindowRestore makes visible but respects blur state', () {
      powerManager.onWindowBlur();
      powerManager.onWindowMinimize();
      expect(powerManager.shouldAnimateBackground, isFalse);

      powerManager.onWindowRestore();
      expect(powerManager.isWindowVisible, isTrue);
      expect(powerManager.isWindowFocused, isFalse);
      // Because window is still unfocused (blur), animations must remain paused
      expect(powerManager.shouldAnimateBackground, isFalse);
      expect(powerManager.shouldAnimateIndicators, isFalse);
      expect(powerManager.shouldAnimateMarquee, isFalse);
    });

    test('AppLifecycleState mapping works correctly', () {
      powerManager.onLifecycleStateChanged(AppLifecycleState.inactive);
      expect(powerManager.isWindowFocused, isFalse);
      expect(powerManager.shouldAnimateBackground, isFalse);

      powerManager.onLifecycleStateChanged(AppLifecycleState.resumed);
      expect(powerManager.isWindowFocused, isTrue);
      expect(powerManager.isWindowVisible, isTrue);
      expect(powerManager.shouldAnimateBackground, isTrue);

      powerManager.onLifecycleStateChanged(AppLifecycleState.hidden);
      expect(powerManager.isWindowVisible, isFalse);
      expect(powerManager.shouldAnimateBackground, isFalse);
    });
  });

  group('AppPowerManager Idle Sleep Mode & Throttling', () {
    test(
      'idle sleep mode pauses MeshOrb background while indicators & marquee stay running',
      () async {
        powerManager.resetForTesting(
          focused: true,
          visible: true,
          idle: false,
          idleSleepEnabled: true,
          idleTimeout: const Duration(milliseconds: 50),
        );

        powerManager.recordUserInteraction(force: true);
        expect(powerManager.shouldAnimateBackground, isTrue);
        expect(powerManager.shouldAnimateIndicators, isTrue);
        expect(powerManager.shouldAnimateMarquee, isTrue);

        // Wait for idle timeout to fire
        await Future<void>.delayed(const Duration(milliseconds: 70));

        expect(powerManager.isUserIdle, isTrue);
        // Background must pause
        expect(powerManager.shouldAnimateBackground, isFalse);
        // Indicators and marquee MUST stay active
        expect(powerManager.shouldAnimateIndicators, isTrue);
        expect(powerManager.shouldAnimateMarquee, isTrue);
      },
    );

    test('user interaction wakes background immediately', () async {
      powerManager.resetForTesting(
        focused: true,
        visible: true,
        idle: true,
        idleSleepEnabled: true,
      );
      expect(powerManager.shouldAnimateBackground, isFalse);

      powerManager.recordUserInteraction(force: true);

      expect(powerManager.isUserIdle, isFalse);
      expect(powerManager.shouldAnimateBackground, isTrue);
    });

    test(
      'disabling idle sleep mode keeps background active continuously',
      () async {
        powerManager.resetForTesting(
          focused: true,
          visible: true,
          idle: false,
          idleSleepEnabled: false,
          idleTimeout: const Duration(milliseconds: 50),
        );

        powerManager.recordUserInteraction(force: true);
        await Future<void>.delayed(const Duration(milliseconds: 70));

        expect(powerManager.isUserIdle, isFalse);
        expect(powerManager.shouldAnimateBackground, isTrue);
      },
    );

    test('interaction throttling respects 600ms boundary', () {
      powerManager.resetForTesting(focused: true, visible: true, idle: false);

      powerManager.recordUserInteraction(force: true);
      // Immediate second call without force should be throttled
      powerManager.recordUserInteraction(force: false);
      expect(powerManager.isUserIdle, isFalse);
    });

    test('configuration persistence saves and loads correctly', () async {
      await powerManager.setIdleSleepEnabled(false);
      await powerManager.setIdleTimeoutSeconds(30);

      expect(powerManager.idleSleepEnabled, isFalse);
      expect(powerManager.idleTimeoutSeconds, 30);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppPowerManager.keyIdleSleepEnabled), isFalse);
      expect(prefs.getInt(AppPowerManager.keyIdleTimeoutSeconds), 30);

      // Reset and re-load
      powerManager.resetForTesting();
      await powerManager.loadConfig();

      expect(powerManager.idleSleepEnabled, isFalse);
      expect(powerManager.idleTimeoutSeconds, 30);
    });
  });
}
