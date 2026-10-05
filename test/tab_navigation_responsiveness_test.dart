import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/ui/main_window.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';

class NavigationLogic extends AppLogic {
  NavigationLogic(Completer<ProcessResult> pending)
    : super(
        initialize: false,
        adbPath: 'fake-adb',
        processRunner: (exe, args, {stdoutEncoding, stderrEncoding}) =>
            pending.future,
      );
  @override
  Future<void> loadDeviceSyncSettings(String id) async {}
  @override
  Future<String?> detectSelectedDeviceWifiIp() async => null;
}

void main() {
  final tabStack = find.byWidgetPredicate(
    (widget) => widget is IndexedStack && widget.children.length == 7,
  );
  for (final tickersEnabled in [true, false]) {
    testWidgets(
      'navigation paints in one frame with pending ADB and tickers=$tickersEnabled',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final pending = Completer<ProcessResult>();
        final logic = NavigationLogic(pending);
        await logic.selectDevice('A');
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
            child: MaterialApp(
              home: TickerMode(
                enabled: tickersEnabled,
                child: const MainWindow(),
              ),
            ),
          ),
        );
        expect(find.text('Launch Mirroring').hitTestable(), findsOneWidget);
        expect(find.byType(FolderSyncTab, skipOffstage: false), findsNothing);
        expect(
          tester
              .widget<TickerMode>(
                find.byKey(const ValueKey('main-tab-3'), skipOffstage: false),
              )
              .enabled,
          isFalse,
        );
        await tester.tap(find.text('Latest Media').last);
        await tester.pump();
        expect(tester.widget<IndexedStack>(tabStack).index, 3);
        expect(find.text('Launch Mirroring').hitTestable(), findsNothing);
        expect(pending.isCompleted, isFalse);
        expect(
          tester
              .widget<TickerMode>(
                find.byKey(const ValueKey('main-tab-0'), skipOffstage: false),
              )
              .enabled,
          isFalse,
        );
        expect(
          tester
              .widget<TickerMode>(
                find.byKey(const ValueKey('main-tab-3'), skipOffstage: false),
              )
              .enabled,
          isTrue,
        );
        await tester.tap(find.text('File Explorer').last);
        await tester.pump();
        expect(tester.widget<IndexedStack>(tabStack).index, 1);
        await tester.tap(find.text('Screen Mirror').last);
        await tester.pump();
        expect(tester.widget<IndexedStack>(tabStack).index, 0);
        expect(find.text('Launch Mirroring').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Folder Sync').last);
        await tester.pump();
        final syncState = tester.state(find.byType(FolderSyncTab));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Screen Mirror').last);
        await tester.pump();
        await tester.tap(find.text('Folder Sync').last);
        await tester.pump();
        expect(
          identical(syncState, tester.state(find.byType(FolderSyncTab))),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete(ProcessResult(1, 0, '', ''));
        await tester.pump();
        logic.dispose();
        theme.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
