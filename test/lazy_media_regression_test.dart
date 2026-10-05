import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/ui/main_window.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';

class ReviewLogic extends AppLogic {
  ReviewLogic()
    : super(
        initialize: false,
        adbPath: 'fake-adb',
        processRunner: (exe, args, {stdoutEncoding, stderrEncoding}) async =>
            ProcessResult(1, 0, '', ''),
      );

  @override
  Future<void> loadDeviceSyncSettings(String deviceId) async {}
  @override
  Future<String?> detectSelectedDeviceWifiIp() async => null;
}

class EmptyMediaLogic extends ReviewLogic {
  int fetches = 0;
  @override
  Future<void> fetchLatestMedia({bool force = false}) async {
    fetches++;
    await super.fetchLatestMedia(force: force);
  }
}

void main() {
  test(
    'uncached selection must not mark a nonexistent media job loading',
    () async {
      final logic = ReviewLogic();
      addTearDown(logic.dispose);
      await logic.selectDevice('device-A');
      await Future<void>.delayed(Duration.zero);
      expect(
        logic.isMediaLoading,
        isFalse,
        reason: 'No fetch starts, and Media tab refuses to fetch while loading',
      );
    },
  );

  testWidgets('empty media result should not refetch on every rebuild', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final logic = EmptyMediaLogic();
    await logic.selectDevice('device-A');
    final theme = ThemeProvider();
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppLogic>.value(value: logic),
          ChangeNotifierProvider<ThemeProvider>.value(value: theme),
          ChangeNotifierProvider(
            create: (_) => LanguageProvider.forTesting('en'),
          ),
        ],
        child: const MaterialApp(home: MainWindow()),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.text(LanguageProvider.forTesting('en').tr('latest_media_tab')).last,
    );
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    final initialFetches = logic.fetches;
    theme.toggleTheme();
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    final finalFetches = logic.fetches;
    expect(logic.hasRequestedLatestMedia, isTrue);
    expect(logic.isMediaLoading, isFalse);
    await tester.runAsync(() => logic.fetchLatestMedia(force: true));
    expect(logic.fetches, initialFetches + 1);
    await tester.runAsync(() => logic.selectDevice('device-B'));
    expect(logic.hasRequestedLatestMedia, isFalse);
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    expect(logic.fetches, initialFetches + 2);
    await tester.pumpWidget(const SizedBox.shrink());
    logic.dispose();
    theme.dispose();
    expect(initialFetches, greaterThan(0));
    expect(
      finalFetches,
      initialFetches,
      reason: 'Empty result triggers repeated automatic fetches',
    );
  });
}
