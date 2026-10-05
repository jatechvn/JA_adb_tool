import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/logic.dart';
import 'package:ja_adb_tool/modules/ui/main_window.dart';
import 'package:ja_adb_tool/modules/ui/styles.dart';
import 'package:ja_adb_tool/modules/ui/localization.dart';

class MockFileExplorerLogic extends AppLogic {
  int directoryLoads = 0;

  List<String> _mockDevices = [];
  @override
  List<String> get connectedDevices =>
      _mockDevices.isNotEmpty ? _mockDevices : super.connectedDevices;

  MockFileExplorerLogic({List<String>? initialDevices, String? selectedDev})
    : super(
        initialize: false,
        adbPath: 'fake-adb',
        processRunner: (exe, args, {stdoutEncoding, stderrEncoding}) async {
          // Emulate empty directory response for `ls -la`
          if (args.contains('ls')) {
            return ProcessResult(
              1,
              0,
              'total 0\ndrwxr-xr-x 2 root root 4096 2026-01-01 00:00 .\ndrwxr-xr-x 2 root root 4096 2026-01-01 00:00 ..\n',
              '',
            );
          }
          if (args.contains('devices')) {
            return ProcessResult(
              1,
              0,
              'List of devices attached\ndevice-A\tdevice\ndevice-B\tdevice\n',
              '',
            );
          }
          if (args.contains('getprop')) {
            if (args.contains('ro.product.model')) {
              return ProcessResult(1, 0, 'Pixel 8\n', '');
            }
            if (args.contains('ro.build.version.release')) {
              return ProcessResult(1, 0, '14\n', '');
            }
          }
          return ProcessResult(1, 0, '', '');
        },
      ) {
    if (initialDevices != null) {
      _mockDevices = initialDevices;
    }
  }

  void setTestDevice(String? dev) {
    selectDevice(dev);
  }

  @override
  Future<void> loadAndroidDirectory(String path) async {
    directoryLoads++;
    await super.loadAndroidDirectory(path);
  }

  @override
  Future<void> loadDeviceSyncSettings(String deviceId) async {}

  @override
  Future<String?> detectSelectedDeviceWifiIp() async => null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Empty Directory & Device Nav Regression Tests', () {
    test(
      'Empty directory marks isAndroidDirectoryLoaded as true and stops loading',
      () async {
        final logic = MockFileExplorerLogic();
        addTearDown(logic.dispose);

        await logic.selectDevice('device-A');
        expect(logic.isAndroidDirectoryLoaded('/sdcard/Documents'), isFalse);

        await logic.loadAndroidDirectory('/sdcard/Documents');

        expect(logic.isAndroidDirectoryLoaded('/sdcard/Documents'), isTrue);
        expect(logic.androidFiles, isEmpty);
        expect(logic.isAndroidLoading, isFalse);
        expect(logic.androidExplorerError, isEmpty);
        expect(logic.directoryLoads, equals(1));

        // Selecting a new device resets directory loaded state
        await logic.selectDevice('device-B');
        expect(logic.isAndroidDirectoryLoaded('/sdcard/Documents'), isFalse);
      },
    );

    test(
      'Apps load marks isAppsLoadedForDevice as true and resets on device switch',
      () async {
        final logic = MockFileExplorerLogic();
        addTearDown(logic.dispose);

        await logic.selectDevice('device-A');
        expect(logic.isAppsLoadedForDevice('device-A'), isFalse);

        await logic.loadApps();
        expect(logic.isAppsLoadedForDevice('device-A'), isTrue);

        await logic.selectDevice('device-B');
        expect(logic.isAppsLoadedForDevice('device-A'), isFalse);
        expect(logic.isAppsLoadedForDevice('device-B'), isFalse);
      },
    );

    testWidgets(
      'Empty folder does not trigger infinite post-frame load loop in File Explorer',
      (tester) async {
        final logic = MockFileExplorerLogic();
        addTearDown(logic.dispose);
        await logic.selectDevice('device-A');

        final theme = ThemeProvider();
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ThemeProvider>.value(value: theme),
              ChangeNotifierProvider<AppLogic>.value(value: logic),
              ChangeNotifierProvider(
                create: (_) => LanguageProvider.forTesting('en'),
              ),
            ],
            child: const MaterialApp(home: MainWindow()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Switch to File Explorer Tab (index 1)
        await tester.tap(find.text('File Explorer').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        // Initial load for /sdcard should have been called once or twice at most, never infinitely!
        final loadsAfterOpen = logic.directoryLoads;
        expect(loadsAfterOpen, lessThanOrEqualTo(2));

        // Pump 10 more frames to ensure no infinite post-frame callbacks are queued
        for (int i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // The count of directory loads must NOT increase
        expect(logic.directoryLoads, equals(loadsAfterOpen));
        expect(logic.isAndroidLoading, isFalse);
      },
    );

    test(
      'Fast device discovery in scanDevices updates connected devices and selected device immediately',
      () async {
        final logic = MockFileExplorerLogic();
        addTearDown(logic.dispose);

        int notifyCount = 0;
        logic.addListener(() => notifyCount++);

        await logic.scanDevices();

        expect(logic.connectedDevices, containsAll(['device-A', 'device-B']));
        expect(logic.selectedDevice, equals('device-A'));
        expect(notifyCount, greaterThan(0));
      },
    );
  });
}
