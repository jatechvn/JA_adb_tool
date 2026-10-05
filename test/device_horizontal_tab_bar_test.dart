import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_adb_tool/modules/ui/device_horizontal_tab_bar.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';
import 'package:ja_adb_tool/modules/ui/styles_win11.dart';

void main() {
  for (final colors in [win11DarkColors, win11LightColors]) {
    testWidgets(
      'optimistic highlight and parent reconciliation ${colors.subCardBg}',
      (tester) async {
        String? parentSelection = 'A';
        String? requested;
        late StateSetter updateParent;
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => LanguageProvider.forTesting('en'),
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    updateParent = setState;
                    return DeviceHorizontalTabBar(
                      devices: const ['A', 'B'],
                      selectedDevice: parentSelection,
                      devicesDetails: const {
                        'A': {'model': 'One', 'version': '12'},
                        'B': {'model': 'Two', 'version': '14'},
                      },
                      onSelectDevice: (device) => requested = device,
                      colors: colors,
                      enableBounceHint: false,
                    );
                  },
                ),
              ),
            ),
          ),
        );
        Color? background(String id) =>
            (tester
                        .widget<Container>(
                          find
                              .descendant(
                                of: find.byKey(ValueKey(id)),
                                matching: find.byType(Container),
                              )
                              .first,
                        )
                        .decoration!
                    as BoxDecoration)
                .color;
        await tester.tap(find.text('Two'));
        await tester.pump();
        expect(requested, 'B');
        expect(parentSelection, 'A');
        expect(background('B'), colors.accentColor.withValues(alpha: 0.16));
        expect(background('A'), colors.subCardBg);
        updateParent(() => parentSelection = 'B');
        await tester.pump();
        updateParent(() => parentSelection = 'A');
        await tester.pump();
        expect(background('A'), colors.accentColor.withValues(alpha: 0.16));
        expect(background('B'), colors.subCardBg);
        updateParent(() => parentSelection = null);
        await tester.pump();
        expect(background('A'), colors.subCardBg);
        expect(background('B'), colors.subCardBg);
      },
    );
  }
  testWidgets('DeviceHorizontalTabBar shows no-device capsule when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider.forTesting('en'),
        child: MaterialApp(
          home: Scaffold(
            body: DeviceHorizontalTabBar(
              devices: const [],
              selectedDevice: null,
              devicesDetails: const {},
              onSelectDevice: (_) {},
              colors: win11DarkColors,
              enableBounceHint: false,
            ),
          ),
        ),
      ),
    );

    expect(find.text('No Device Connected'), findsOneWidget);
    expect(find.byIcon(Icons.phonelink_erase_rounded), findsOneWidget);
  });

  testWidgets(
    'DeviceHorizontalTabBar renders multiple tabs and allows selection',
    (tester) async {
      String? selected;
      const devices = ['dev_alpha', 'dev_beta'];
      const details = {
        'dev_alpha': {'model': 'Pixel 7', 'version': '13'},
        'dev_beta': {'model': 'Galaxy S23', 'version': '14'},
      };

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider.forTesting('en'),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 50,
                child: DeviceHorizontalTabBar(
                  devices: devices,
                  selectedDevice: 'dev_alpha',
                  devicesDetails: details,
                  onSelectDevice: (d) => selected = d,
                  colors: win11DarkColors,
                  enableBounceHint: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pixel 7'), findsOneWidget);
      expect(find.text('Galaxy S23'), findsOneWidget);

      // Tap on beta device
      await tester.tap(find.text('Galaxy S23'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(selected, 'dev_beta');
    },
  );

  testWidgets('DeviceHorizontalTabBar handles mouse pointer scroll event', (
    tester,
  ) async {
    const devices = ['dev_1', 'dev_2', 'dev_3', 'dev_4', 'dev_5'];
    final details = {
      for (final d in devices) d: {'model': 'Phone $d', 'version': '12'},
    };

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider.forTesting('en'),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 50,
              child: DeviceHorizontalTabBar(
                devices: devices,
                selectedDevice: 'dev_1',
                devicesDetails: details,
                onSelectDevice: (_) {},
                colors: win11DarkColors,
                enableBounceHint: false,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Trigger PointerScrollEvent over the bar
    final center = tester.getCenter(find.byType(SingleChildScrollView));
    await tester.sendEventToBinding(
      PointerScrollEvent(position: center, scrollDelta: const Offset(0, 100)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'DeviceHorizontalTabBar activates bounce hint and marquee indicator on overflow',
    (tester) async {
      const devices = ['dev_1', 'dev_2', 'dev_3', 'dev_4', 'dev_5', 'dev_6'];
      final details = {
        for (final d in devices) d: {'model': 'Phone $d', 'version': '11'},
      };

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider.forTesting('en'),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 250,
                height: 50,
                child: DeviceHorizontalTabBar(
                  devices: devices,
                  selectedDevice: 'dev_1',
                  devicesDetails: details,
                  onSelectDevice: (_) {},
                  colors: win11DarkColors,
                  enableBounceHint: true,
                ),
              ),
            ),
          ),
        ),
      );

      // Initial frame triggers post-frame bounce hint
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      // Right chevron indicator should appear because list overflows 250px width
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Click right arrow to scroll
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DeviceHorizontalTabBar switches selection highlight immediately on tap without delay',
    (tester) async {
      String? selectedDevice = 'dev_1';
      const devices = ['dev_1', 'dev_2'];
      const details = {
        'dev_1': {'model': 'Device One', 'version': '12'},
        'dev_2': {'model': 'Device Two', 'version': '14'},
      };

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider.forTesting('en'),
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 50,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return DeviceHorizontalTabBar(
                      devices: devices,
                      selectedDevice: selectedDevice,
                      devicesDetails: details,
                      onSelectDevice: (d) {
                        setState(() => selectedDevice = d);
                      },
                      colors: win11DarkColors,
                      enableBounceHint: false,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Verify dev_1 container has selected styling
      final dev1Finder = find.byKey(const ValueKey('dev_1'));
      final dev2Finder = find.byKey(const ValueKey('dev_2'));
      expect(dev1Finder, findsOneWidget);
      expect(dev2Finder, findsOneWidget);
      BoxDecoration decorationFor(Finder finder) =>
          tester
                  .widget<Container>(
                    find
                        .descendant(
                          of: finder,
                          matching: find.byType(Container),
                        )
                        .first,
                  )
                  .decoration!
              as BoxDecoration;
      void expectStyle(Finder finder, {required bool selected}) {
        final decoration = decorationFor(finder);
        final border = decoration.border! as Border;
        expect(
          decoration.color,
          selected
              ? win11DarkColors.accentColor.withValues(alpha: 0.16)
              : win11DarkColors.subCardBg,
        );
        expect(
          border.top.color,
          selected
              ? win11DarkColors.accentCyan.withValues(alpha: 0.60)
              : win11DarkColors.subCardBorder,
        );
        expect(border.top.width, selected ? 1.2 : 1.0);
      }

      expectStyle(dev1Finder, selected: true);
      expectStyle(dev2Finder, selected: false);

      // Tap Device Two
      await tester.tap(find.text('Device Two'));
      // Single pump frame (0ms duration)
      await tester.pump();

      expect(selectedDevice, 'dev_2');
      // Tab bar Container decoration updates synchronously on the same frame
      expectStyle(dev1Finder, selected: false);
      expectStyle(dev2Finder, selected: true);
      await tester.tap(find.text('Device One'));
      await tester.pump();
      expectStyle(dev1Finder, selected: true);
      expectStyle(dev2Finder, selected: false);
      expect(tester.takeException(), isNull);
    },
  );
}
