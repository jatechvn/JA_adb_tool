import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/app_power_manager.dart';
import 'package:ja_adb_tool/modules/ui/app_power_gate.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';

void main() {
  testWidgets(
    'Checkbox under AppPowerGate animates position to 1.0 when tapped',
    (tester) async {
      final theme = ThemeProvider();
      bool isChecked = false;

      // Simulate window being visible
      AppPowerManager.instance.onWindowRestore();
      // Simulate interaction to ensure state
      AppPowerManager.instance.recordUserInteraction();

      await tester.pumpWidget(
        MaterialApp(
          theme: theme.themeData,
          builder: (context, child) => AppPowerGate(child: child!),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Center(
                  child: Checkbox(
                    value: isChecked,
                    activeColor: const Color(0xFF00ADB5),
                    checkColor: Colors.white,
                    onChanged: (val) {
                      setState(() {
                        isChecked = val!;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dynamic stateBefore = tester.state(find.byType(Checkbox));
      expect(stateBefore.position.value, equals(0.0));

      // Tap to select
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final dynamic stateAfter = tester.state(find.byType(Checkbox));
      expect(isChecked, isTrue);
      expect(stateAfter.position.value, equals(1.0));

      AppPowerManager.instance.cancelIdleTimer();
    },
  );

  testWidgets('recordUserInteraction unblocks window focus when visible', (
    tester,
  ) async {
    final manager = AppPowerManager.instance;
    // Simulate window losing focus while visible
    manager.onLifecycleStateChanged(AppLifecycleState.inactive);
    expect(manager.isWindowFocused, isFalse);
    expect(manager.isWindowVisible, isTrue);

    // User touches/clicks the window
    manager.recordUserInteraction();
    expect(manager.isWindowFocused, isTrue);
    expect(manager.isUserIdle, isFalse);

    manager.cancelIdleTimer();
  });

  testWidgets(
    'recordUserInteraction unblocks window visibility even if started as detached',
    (tester) async {
      final manager = AppPowerManager.instance;
      // Simulate detached/hidden state
      manager.onLifecycleStateChanged(AppLifecycleState.detached);
      expect(manager.isWindowVisible, isFalse);
      expect(manager.isWindowFocused, isFalse);

      // User interacts with window
      manager.recordUserInteraction();
      expect(manager.isWindowVisible, isTrue);
      expect(manager.isWindowFocused, isTrue);
      expect(manager.isUserIdle, isFalse);
      expect(manager.visibilityNotifier.value, isTrue);

      manager.cancelIdleTimer();
    },
  );
}
