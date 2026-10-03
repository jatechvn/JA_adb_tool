import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/services/app_power_manager.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/ntp_time_sync_dialog.dart';

class _ObservedLogic extends AppLogic {
  _ObservedLogic() : super(initialize: false);
  int dialogReads = 0;
  @override
  double get dialogOpacity {
    dialogReads++;
    return super.dialogOpacity;
  }
}

void main() {
  testWidgets('NTP presentation timer pauses hidden and refreshes on restore', (
    tester,
  ) async {
    final power = AppPowerManager.instance;
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    power.resetForTesting();
    final logic = _ObservedLogic();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppLogic>.value(value: logic),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(
            create: (_) => LanguageProvider.forTesting('en'),
          ),
        ],
        child: Builder(
          builder: (context) => MaterialApp(
            theme: context.watch<ThemeProvider>().themeData,
            home: const Scaffold(body: NtpTimeSyncDialog()),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final initial = logic.dialogReads;
    await tester.pump(const Duration(seconds: 1));
    expect(logic.dialogReads, greaterThan(initial));
    power.onWindowMinimize();
    await tester.pump();
    final frozen = logic.dialogReads;
    await tester.pump(const Duration(seconds: 5));
    expect(logic.dialogReads, frozen);
    power.onWindowRestore();
    await tester.pump();
    expect(logic.dialogReads, greaterThan(frozen));
    final restored = logic.dialogReads;
    await tester.pump(const Duration(seconds: 1));
    expect(logic.dialogReads, greaterThan(restored));
    await tester.pumpWidget(const SizedBox.shrink());
    power.resetForTesting();
    logic.dispose();
  });
}
