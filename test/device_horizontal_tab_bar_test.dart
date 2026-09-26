import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_adb_tool/modules/ui/device_horizontal_tab_bar.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';
import 'package:ja_adb_tool/modules/ui/styles_win11.dart';

void main() {
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
}
