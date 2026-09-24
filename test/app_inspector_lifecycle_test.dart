import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/services/ota_update_service.dart';
import 'package:ja_adb_tool/modules/ui/main_window.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';

class PendingAppLogic extends AppLogic {
  PendingAppLogic() : super(initialize: false);
  final pending = Completer<bool>();
  bool ready = false;
  @override
  String? get selectedDevice => ready ? 'test-device' : null;
  @override
  String get adbPath => 'test-adb';
  @override
  String get scrcpyPath => 'test-scrcpy';
  @override
  Future<bool> freezeApp(String packageName) => pending.future;
  @override
  Future<bool> unfreezeApp(String packageName) => pending.future;
  @override
  Future<bool> uninstallApp(String packageName) => pending.future;
}

void main() {
  for (final action in ['Freeze', 'Unfreeze', 'Uninstall']) {
    testWidgets('closing window while Inspector $action is pending is safe', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final dir = Directory.systemTemp.createTempSync('mirror-layout-');
      final ota = OtaUpdateService();
      ota.setCustomConfigFileForTesting(File('${dir.path}/update.json'));
      await tester.runAsync(
        () => ota.saveConfig(
          OtaUpdateConfig.defaults().copyWith(checkInterval: 'off'),
        ),
      );
      final logic = PendingAppLogic();
      logic.apps.add(
        AndroidApp(
          packageName: 'test.app',
          appName: 'Test App',
          isSystem: false,
          isFrozen: action == 'Unfreeze',
        ),
      );
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => ota.setCustomConfigFileForTesting(null));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AppLogic>.value(value: logic),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ],
          child: const MaterialApp(home: MainWindow()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('App Manager').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      logic.ready = true;
      logic.notifyListeners();
      await tester.pump();
      await tester.tap(find.text('Test App').first);
      await tester.pump();
      if (action == 'Uninstall') {
        await tester.tap(find.text('Uninstall').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
      } else {
        await tester.tap(find.widgetWithText(ElevatedButton, action).last);
      }
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      logic.pending.complete(false);
      await tester.pump();
      expect(tester.takeException(), isNull);
      logic.dispose();
      await tester.pump();
    });
  }
}
