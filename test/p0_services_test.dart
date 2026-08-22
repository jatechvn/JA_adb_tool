import 'package:flutter_test/flutter_test.dart';

import '../lib/modules/services/adb_service.dart';
import '../lib/modules/services/device_workspace_store.dart';

void main() {
  test('AdbService returns a safe failure for an empty executable', () async {
    final result = await const AdbService().run('', const ['version']);

    expect(result.isSuccess, isFalse);
    expect(result.exitCode, -1);
    expect(result.stderr, contains('not configured'));
  });

  test('DeviceWorkspaceProfile serializes and restores its fields', () {
    final created = DateTime.utc(2026, 8, 22, 12, 30);
    final profile = DeviceWorkspaceProfile(
      id: 'pixel_1',
      name: 'Pixel test',
      deviceId: '192.168.1.10:5555',
      wirelessEndpoint: '192.168.1.10:5555',
      adbPath: r'C:\tools\adb.exe',
      scrcpyPath: r'C:\tools\scrcpy.exe',
      gnirehtetPath: r'C:\tools\gnirehtet.exe',
      syncPcPath: r'C:\sync',
      syncAndroidPath: '/sdcard/sync',
      createdAt: created,
      lastUsedAt: created,
    );

    final restored = DeviceWorkspaceProfile.fromJson(profile.toJson());

    expect(restored.id, profile.id);
    expect(restored.name, profile.name);
    expect(restored.deviceId, profile.deviceId);
    expect(restored.wirelessEndpoint, profile.wirelessEndpoint);
    expect(restored.adbPath, profile.adbPath);
    expect(restored.syncAndroidPath, profile.syncAndroidPath);
    expect(restored.createdAt, created);
  });
}
