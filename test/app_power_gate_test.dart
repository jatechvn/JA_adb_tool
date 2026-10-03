import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/app_power_manager.dart';
import 'package:ja_adb_tool/modules/ui/app_power_gate.dart';
import 'package:ja_adb_tool/modules/ui/glass_widgets.dart';

class _OrdinaryTicker extends StatefulWidget {
  const _OrdinaryTicker({required this.onTick});
  final VoidCallback onTick;
  @override
  State<_OrdinaryTicker> createState() => _OrdinaryTickerState();
}

class _OrdinaryTickerState extends State<_OrdinaryTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(widget.onTick)
          ..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void main() {
  final power = AppPowerManager.instance;
  setUp(() => power.resetForTesting());
  tearDown(() => power.resetForTesting());
  for (final wave in [false, true]) {
    testWidgets('real animation preserves reverse phase wave=$wave', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppPowerGate(
            child: wave
                ? const WaveIndicator(color: Colors.blue)
                : const MeshOrb(
                    color: Colors.blue,
                    size: 20,
                    duration: Duration(milliseconds: 900),
                    travel: Offset(10, 10),
                  ),
          ),
        ),
      );
      final owner = find.byType(wave ? WaveIndicator : MeshOrb);
      final builder = tester.widget<AnimatedBuilder>(
        find
            .descendant(of: owner, matching: find.byType(AnimatedBuilder))
            .first,
      );
      final controller = builder.animation as AnimationController;
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(controller.status, AnimationStatus.reverse);
      for (var i = 0; i < 3; i++) {
        final frozen = controller.value;
        power.onWindowBlur();
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        expect(controller.value, frozen);
        power.onWindowFocus();
        await tester.pump();
        // The gate unmutes tickers during build; initialize their next tick.
        await tester.pump();
        expect(controller.value, closeTo(frozen, 0.0001));
        await tester.pump(const Duration(milliseconds: 100));
        expect(controller.value, lessThan(frozen));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final initiallyHidden in [false, true]) {
    testWidgets(
      'Navigator and overlay tickers obey power gate; hidden=$initiallyHidden',
      (tester) async {
        power.resetForTesting(
          visible: !initiallyHidden,
          focused: !initiallyHidden,
        );
        var ticks = 0;
        var backgroundTicks = 0;
        final timer = Timer.periodic(
          const Duration(milliseconds: 100),
          (_) => backgroundTicks++,
        );
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            builder: (_, child) => AppPowerGate(child: child!),
            home: _OrdinaryTicker(onTick: () => ticks++),
          ),
        );
        final entry = OverlayEntry(
          builder: (_) => _OrdinaryTicker(onTick: () => ticks++),
        );
        navigator.currentState!.overlay!.insert(entry);
        await tester.pump();
        final initial = ticks;
        await tester.pump(const Duration(milliseconds: 200));
        expect(ticks, initiallyHidden ? initial : greaterThan(initial));

        for (final pause in [
          power.onWindowBlur,
          power.onWindowMinimize,
          () => power.onLifecycleStateChanged(AppLifecycleState.hidden),
        ]) {
          pause();
          await tester.pump();
          final frozen = ticks;
          final serviceBefore = backgroundTicks;
          await tester.pump(const Duration(seconds: 2));
          expect(ticks, frozen);
          expect(backgroundTicks, greaterThan(serviceBefore));
          power.onWindowRestore();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(ticks, frozen);
          power.onWindowFocus();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(ticks, greaterThan(frozen));
        }
        timer.cancel();
        entry.remove();
        entry.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test('minimize clears stale focus; restore does not resume until focus', () {
    power.onWindowMinimize();
    power.onWindowRestore();
    expect(power.shouldAnimateIndicators, isFalse);
    power.onWindowFocus();
    expect(power.shouldAnimateIndicators, isTrue);
  });
  test('hidden to inactive is visible but unfocused', () {
    power.onLifecycleStateChanged(AppLifecycleState.hidden);
    power.onLifecycleStateChanged(AppLifecycleState.inactive);
    expect(power.visibilityNotifier.value, isTrue);
    expect(power.shouldAnimateIndicators, isFalse);
  });
}
