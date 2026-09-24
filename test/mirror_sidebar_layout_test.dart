import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/services/ota_update_service.dart';
import 'package:ja_adb_tool/modules/ui/main_window.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';

void main() {
  testWidgets('sidebar expands and collapses without intermediate overflow', (
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
    final logic = AppLogic(initialize: false);
    tester.view.physicalSize = const Size(1280, 800);
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
    for (final label in [
      'Collapse Sidebar',
      'Expand Sidebar',
      'Collapse Sidebar',
      'Expand Sidebar',
    ]) {
      await tester.tap(find.byTooltip(label).last);
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    logic.dispose();
    await tester.pump();
  });
}
