import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/styles_win10.dart';
import 'package:ja_adb_tool/modules/ui/styles_win11.dart';
import 'package:ja_adb_tool/modules/ui/glass_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bento Glassmorphism & Token System Tests', () {
    test('ThemeProvider defaults and direct 1-click toggle', () {
      final provider = ThemeProvider();
      expect(provider.cardBlur, 20.0);
      expect(provider.cardOpacity, 0.25);
      expect(provider.dialogBlur, 20.0);
      expect(provider.dialogOpacity, 0.85);

      final initialDark = provider.isDark;
      provider.toggleTheme();
      expect(provider.isDark, !initialDark);

      provider.setLiveGlassmorphism(
        cardBlur: 25.0,
        cardOpacity: 0.35,
        dialogBlur: 15.0,
        dialogOpacity: 0.90,
      );
      expect(provider.cardBlur, 25.0);
      expect(provider.cardOpacity, 0.35);
      expect(provider.dialogBlur, 15.0);
      expect(provider.dialogOpacity, 0.90);
    });

    test('AppColors token consistency between Win10 and Win11', () {
      expect(win10DarkColors.accentColor, const Color(0xFF00ADB5));
      expect(win11DarkColors.accentColor, const Color(0xFF00ADB5));
      expect(win10LightColors.accentColor, const Color(0xFF00ADB5));
      expect(win11LightColors.accentColor, const Color(0xFF00ADB5));
    });

    testWidgets('BentoCard renders child with glass blur and padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BentoCard(
              colors: win11DarkColors,
              child: Text('Bento Content'),
            ),
          ),
        ),
      );

      expect(find.text('Bento Content'), findsOneWidget);
    });

    testWidgets('SlidingPillTabBar renders tabs and handles selection', (
      tester,
    ) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SlidingPillTabBar(
                  colors: win11DarkColors,
                  currentIndex: selected,
                  tabs: const ['Tab 1', 'Tab 2', 'Tab 3'],
                  icons: const [Icons.home, Icons.devices, Icons.settings],
                  onTabSelected: (idx) => setState(() => selected = idx),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Tab 1'), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.devices), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);

      await tester.tap(find.byIcon(Icons.devices));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(find.text('Tab 2'), findsOneWidget);
    });

    testWidgets('DynamicIslandCapsule renders with status text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicIslandCapsule(
              colors: win11DarkColors,
              isRunning: true,
              statusText: 'LIVE • TEST_DEVICE',
              subText: '1 dev',
            ),
          ),
        ),
      );

      expect(find.text('LIVE • TEST_DEVICE'), findsOneWidget);
      expect(find.text('1 dev'), findsOneWidget);
    });

    testWidgets('GlowingActionButton renders and triggers onPressed', (
      tester,
    ) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlowingActionButton(
              colors: win11DarkColors,
              icon: Icons.play_arrow,
              label: 'START SERVICE',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      expect(find.text('START SERVICE'), findsOneWidget);
      await tester.tap(find.text('START SERVICE'));
      expect(pressed, isTrue);
    });

    testWidgets('AsymmetricMarqueeText renders and handles text updates', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: AsymmetricMarqueeText(
                text: 'v1.7.0 (2026-08-26 15:56:10)',
              ),
            ),
          ),
        ),
      );

      expect(find.text('v1.7.0 (2026-08-26 15:56:10)'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}
