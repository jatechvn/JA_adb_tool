import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_adb_tool/modules/constants.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/styles_win10.dart';
import 'package:ja_adb_tool/modules/ui/styles_win11.dart';
import 'package:ja_adb_tool/modules/ui/glass_widgets.dart';
import 'package:ja_adb_tool/modules/ui/glass_dropdown.dart';
import 'package:ja_adb_tool/modules/ui/app_toast.dart';
import 'package:ja_adb_tool/modules/ui/filter_search_dock.dart';
import 'package:ja_adb_tool/modules/ui/glass_dialog.dart';

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
                text: 'v$appVersion (2026-08-26 15:56:10)',
              ),
            ),
          ),
        ),
      );

      expect(find.text('v$appVersion (2026-08-26 15:56:10)'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('KbdTag renders shortcut label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KbdTag(label: 'Ctrl+K', colors: win11DarkColors),
          ),
        ),
      );

      expect(find.text('Ctrl+K'), findsOneWidget);
    });

    testWidgets('BorderBeam renders child with custom painter', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BorderBeam(child: Text('Beam Content'))),
        ),
      );

      expect(find.text('Beam Content'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('SpotlightGlow renders child without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SpotlightGlow(
              colors: win11DarkColors,
              child: Text('Spotlight Content'),
            ),
          ),
        ),
      );

      expect(find.text('Spotlight Content'), findsOneWidget);
    });

    testWidgets('FilterSearchDock renders search bar and filter pills', (
      tester,
    ) async {
      String selected = 'All';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return FilterSearchDock(
                  colors: win11DarkColors,
                  filters: const ['All', 'Connected', 'Offline'],
                  selectedFilter: selected,
                  onFilterSelected: (f) => setState(() => selected = f),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);

      await tester.tap(find.text('Connected'));
      await tester.pumpAndSettle();
      expect(selected, 'Connected');
    });

    testWidgets(
      'DetailDialog renders title, subtitle, description, and badges',
      (tester) async {
        final theme = ThemeProvider();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: theme,
            child: const MaterialApp(
              home: Scaffold(
                body: DetailDialog(
                  title: 'Test Device Details',
                  isDark: true,
                  subtitle: 'v$appVersion // ANDROID 14',
                  description: 'Detailed inspection for connected target.',
                  tags: ['USB', 'Authorized'],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Test Device Details'), findsOneWidget);
        expect(find.text('v$appVersion // ANDROID 14'), findsOneWidget);
        expect(
          find.text('Detailed inspection for connected target.'),
          findsOneWidget,
        );
        expect(find.text('USB'), findsOneWidget);
        expect(find.text('Authorized'), findsOneWidget);
      },
    );

    testWidgets('showAppToast displays transient toast overlay', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAppToast(
                      context,
                      message: 'Settings Saved Successfully',
                      colors: win11DarkColors,
                    );
                  },
                  child: const Text('Show Toast'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Toast'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Settings Saved Successfully'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3100));
    });

    testWidgets('GlassDropdown renders selected item and handles selection', (
      tester,
    ) async {
      String selected = '1080p';
      final items = [
        const GlassDropdownItem(
          value: '1080p',
          label: '1080p Full HD',
          icon: Icons.hd,
        ),
        const GlassDropdownItem(
          value: '720p',
          label: '720p HD',
          icon: Icons.sd,
        ),
        const GlassDropdownItem(
          value: '480p',
          label: '480p SD',
          icon: Icons.tv,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return GlassDropdown<String>(
                  items: items,
                  value: selected,
                  colors: win11DarkColors,
                  onChanged: (val) => setState(() => selected = val),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('1080p Full HD'), findsOneWidget);

      // Open dropdown menu
      await tester.tap(find.text('1080p Full HD'));
      await tester.pumpAndSettle();

      expect(find.text('720p HD'), findsOneWidget);
      expect(find.text('480p SD'), findsOneWidget);

      // Select 720p
      await tester.tap(find.text('720p HD'));
      await tester.pumpAndSettle();

      expect(selected, '720p');
      expect(find.text('720p HD'), findsOneWidget);
    });

    testWidgets('GlassMultiSelectDropdown handles multiple selections', (
      tester,
    ) async {
      List<String> selected = ['WiFi'];
      final items = [
        const GlassDropdownItem(value: 'USB', label: 'USB Debugging'),
        const GlassDropdownItem(value: 'WiFi', label: 'Wireless ADB'),
        const GlassDropdownItem(value: 'Ethernet', label: 'Ethernet LAN'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return GlassMultiSelectDropdown<String>(
                  items: items,
                  selectedValues: selected,
                  colors: win11DarkColors,
                  onChanged: (val) => setState(() => selected = val),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Đã chọn 1 mục'), findsOneWidget);

      // Open dropdown menu
      await tester.tap(find.text('Đã chọn 1 mục'));
      await tester.pumpAndSettle();

      expect(find.text('USB Debugging'), findsOneWidget);
      expect(find.text('Ethernet LAN'), findsOneWidget);

      // Toggle USB
      await tester.tap(find.text('USB Debugging'));
      await tester.pumpAndSettle();

      expect(selected.contains('USB'), isTrue);
      expect(selected.contains('WiFi'), isTrue);
      expect(selected.length, 2);
    });

    testWidgets(
      'SlidingPillTabBar smart adaptation displays all 7 Vietnamese tabs without cutting off',
      (tester) async {
        int selected = 0;
        final tabs = [
          'Xem màn hình',
          'Quản lý tệp',
          'Đồng bộ thư mục',
          'Ảnh & Video mới',
          'Cài đặt APK/XAPK',
          'Quản lý ứng dụng',
          'Công cụ nhanh',
        ];
        final icons = [
          Icons.screenshot_rounded,
          Icons.folder_shared_rounded,
          Icons.sync_rounded,
          Icons.photo_library_rounded,
          Icons.system_update_rounded,
          Icons.apps_rounded,
          Icons.bolt_rounded,
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 760,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return SlidingPillTabBar(
                        colors: win11DarkColors,
                        currentIndex: selected,
                        tabs: tabs,
                        icons: icons,
                        onTabSelected: (idx) => setState(() => selected = idx),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // All 7 Vietnamese tab labels must be present in the widget tree
        for (final tab in tabs) {
          expect(find.text(tab), findsOneWidget);
        }

        // Ensure the 7th tab is visible in viewport before tapping
        await tester.ensureVisible(find.text('Công cụ nhanh'));
        await tester.pumpAndSettle();

        // Tap on the 7th tab ('Công cụ nhanh')
        await tester.tap(find.text('Công cụ nhanh'));
        await tester.pumpAndSettle();
        expect(selected, 6);
      },
    );

    testWidgets(
      'SlidingPillTabBar displays navigation chevrons when content overflows',
      (tester) async {
        int selected = 0;
        final tabs = [
          'Xem màn hình',
          'Quản lý tệp',
          'Đồng bộ thư mục',
          'Ảnh & Video mới',
          'Cài đặt APK/XAPK',
          'Quản lý ứng dụng',
          'Công cụ nhanh',
        ];
        final icons = [
          Icons.screenshot_rounded,
          Icons.folder_shared_rounded,
          Icons.sync_rounded,
          Icons.photo_library_rounded,
          Icons.system_update_rounded,
          Icons.apps_rounded,
          Icons.bolt_rounded,
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 320, // very narrow, forces overflow
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return SlidingPillTabBar(
                        colors: win11DarkColors,
                        currentIndex: selected,
                        tabs: tabs,
                        icons: icons,
                        onTabSelected: (idx) => setState(() => selected = idx),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Right navigation chevron should appear when overflowed
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

        // Tap right chevron to scroll
        await tester.tap(find.byIcon(Icons.chevron_right_rounded));
        await tester.pumpAndSettle();

        // After scrolling, left navigation chevron should appear
        expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      },
    );
  });
}
