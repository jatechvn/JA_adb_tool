import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/adb_service.dart';
import 'package:ja_adb_tool/modules/ui/app_toast.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';

void main() {
  group('AdbService.parsePmPathOutput tests', () {
    test('parses single package path correctly', () {
      const output =
          'package:/data/app/~~aBc123==/com.example.app-1/base.apk\n';
      final paths = AdbService.parsePmPathOutput(output);
      expect(
        paths,
        equals(['/data/app/~~aBc123==/com.example.app-1/base.apk']),
      );
    });

    test('parses split APK paths correctly', () {
      const output = '''
package:/data/app/~~xyz==/com.test.split-1/base.apk
package:/data/app/~~xyz==/com.test.split-1/split_config.arm64_v8a.apk
package:/data/app/~~xyz==/com.test.split-1/split_config.xxhdpi.apk
''';
      final paths = AdbService.parsePmPathOutput(output);
      expect(paths.length, equals(3));
      expect(paths[0], equals('/data/app/~~xyz==/com.test.split-1/base.apk'));
      expect(
        paths[1],
        equals('/data/app/~~xyz==/com.test.split-1/split_config.arm64_v8a.apk'),
      );
      expect(
        paths[2],
        equals('/data/app/~~xyz==/com.test.split-1/split_config.xxhdpi.apk'),
      );
    });

    test('returns empty list on empty or whitespace output', () {
      expect(AdbService.parsePmPathOutput(''), isEmpty);
      expect(AdbService.parsePmPathOutput('   \n  \r\n '), isEmpty);
    });

    test('handles paths without package: prefix gracefully', () {
      const output = '/data/app/com.app/base.apk';
      final paths = AdbService.parsePmPathOutput(output);
      expect(paths, equals(['/data/app/com.app/base.apk']));
    });
  });

  group('Dropdown & Menu glass tokens test', () {
    test('Dark theme dropdownBg has high solid opacity (>= 0.95)', () {
      final theme = ThemeProvider();
      if (!theme.isDark) {
        theme.toggleTheme();
      }
      expect(theme.dropdownBg.a, greaterThanOrEqualTo(0.95));
      expect(theme.dropdownBorder.a, greaterThan(0.1));
    });

    test('Light theme dropdownBg has high solid opacity (>= 0.95)', () {
      final theme = ThemeProvider();
      if (theme.isDark) {
        theme.toggleTheme();
      }
      expect(theme.dropdownBg.a, greaterThanOrEqualTo(0.95));
      expect(theme.dropdownBorder.a, greaterThan(0.1));
    });
  });

  group('AppToast widget tests', () {
    testWidgets(
      'AppToastWidget renders message and triggers onAction callback',
      (tester) async {
        var actionTriggered = false;
        var dismissTriggered = false;
        final theme = ThemeProvider();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  AppToastWidget(
                    message: 'Test Toast Message',
                    icon: Icons.check_circle_rounded,
                    colors: theme.colors,
                    accent: theme.colors.accentEmerald,
                    actionLabel: 'Open Folder',
                    onAction: () {
                      actionTriggered = true;
                    },
                    onDismiss: () {
                      dismissTriggered = true;
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Test Toast Message'), findsOneWidget);
        expect(find.text('Open Folder'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

        await tester.tap(find.text('Open Folder'));
        await tester.pump();

        expect(actionTriggered, isTrue);
        expect(dismissTriggered, isTrue);
      },
    );

    testWidgets('AppToastWidget renders without actionLabel when omitted', (
      tester,
    ) async {
      final theme = ThemeProvider();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                AppToastWidget(
                  message: 'Simple Info Toast',
                  icon: Icons.info_outline_rounded,
                  colors: theme.colors,
                  accent: theme.colors.accentCyan,
                  onDismiss: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Simple Info Toast'), findsOneWidget);
      expect(find.text('Open Folder'), findsNothing);
    });
  });
}
