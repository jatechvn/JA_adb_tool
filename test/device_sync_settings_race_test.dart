import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ja_adb_tool/modules/logic.dart';

class PendingConfig extends Fake implements File {
  final reads = <Completer<String>>[];
  @override
  Future<bool> exists() async => true;
  @override
  Future<String> readAsString({Encoding encoding = utf8}) {
    final read = Completer<String>();
    reads.add(read);
    return read.future;
  }
}

class SyncLogic extends AppLogic {
  SyncLogic(File file) : super(initialize: false, syncSettingsFile: file);
  @override
  Future<String?> detectSelectedDeviceWifiIp() async => null;
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final reconnect in [false, true]) {
    test(
      'late sync config cannot overwrite current session reconnect=$reconnect',
      () async {
        final config = PendingConfig();
        final logic = SyncLogic(config);
        addTearDown(logic.dispose);
        await logic.selectDevice('A');
        await flush();
        await logic.selectDevice('B');
        await flush();
        if (reconnect) {
          await logic.selectDevice('A');
          await flush();
        }
        final current = reconnect ? 'A' : 'B';
        config.reads.last.complete(
          '{"device_sync_settings":{"$current":{"pc_path":"CURRENT","android_path":"/current"}}}',
        );
        await flush();
        config.reads.first.complete(
          '{"device_sync_settings":{"A":{"pc_path":"STALE","android_path":"/stale","auto_sync":true}}}',
        );
        if (reconnect) config.reads[1].complete('{}');
        await flush();
        expect(logic.lastSyncPcPath, 'CURRENT');
        expect(logic.lastSyncAndroidPath, '/current');
        expect(logic.lastSyncAutoSync, isFalse);
      },
    );
  }
  test('pending config completion after dispose does not publish', () async {
    final config = PendingConfig();
    final logic = SyncLogic(config);
    await logic.selectDevice('A');
    await flush();
    logic.dispose();
    config.reads.single.complete(
      '{"device_sync_settings":{"A":{"pc_path":"STALE"}}}',
    );
    await flush();
    expect(logic.lastSyncPcPath, isEmpty);
  });
}
