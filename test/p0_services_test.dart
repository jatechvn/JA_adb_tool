import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../lib/modules/services/adb_service.dart';
import '../lib/modules/services/device_workspace_store.dart';
import '../lib/modules/services/scrcpy_profile_store.dart';
import '../lib/modules/services/settings_backup_service.dart';

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

  test('ScrcpyProfile preserves mirroring options during JSON round-trip', () {
    const profile = ScrcpyProfile(
      name: 'Presentation',
      stayOnTop: true,
      fullscreen: true,
      noControl: false,
      keepAwake: true,
      borderless: false,
      noAudio: true,
    );

    final restored = ScrcpyProfile.fromJson(profile.toJson());

    expect(restored.name, profile.name);
    expect(restored.stayOnTop, isTrue);
    expect(restored.fullscreen, isTrue);
    expect(restored.noControl, isFalse);
    expect(restored.noAudio, isTrue);
  });

  test(
    'SettingsBackupService writes and validates a settings snapshot',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ja_adb_backup_test_',
      );
      try {
        final path = '${tempDir.path}${Platform.pathSeparator}settings.json';
        const service = SettingsBackupService();
        await service.exportToFile(
          path: path,
          settings: const {'adb_path': r'C:\tools\adb.exe'},
        );

        final restored = await service.importFromFile(path);

        expect(restored['adb_path'], r'C:\tools\adb.exe');
      } finally {
        await tempDir.delete(recursive: true);
      }
    },
  );
}
