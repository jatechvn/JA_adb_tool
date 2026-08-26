import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class DeviceWorkspaceProfile {
  final String id;
  final String name;
  final String deviceId;
  final String wirelessEndpoint;
  final String adbPath;
  final String scrcpyPath;
  final String gnirehtetPath;
  final String syncPcPath;
  final String syncAndroidPath;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  const DeviceWorkspaceProfile({
    required this.id,
    required this.name,
    required this.deviceId,
    required this.wirelessEndpoint,
    required this.adbPath,
    required this.scrcpyPath,
    required this.gnirehtetPath,
    required this.syncPcPath,
    required this.syncAndroidPath,
    required this.createdAt,
    required this.lastUsedAt,
  });

  DeviceWorkspaceProfile copyWith({DateTime? lastUsedAt}) {
    return DeviceWorkspaceProfile(
      id: id,
      name: name,
      deviceId: deviceId,
      wirelessEndpoint: wirelessEndpoint,
      adbPath: adbPath,
      scrcpyPath: scrcpyPath,
      gnirehtetPath: gnirehtetPath,
      syncPcPath: syncPcPath,
      syncAndroidPath: syncAndroidPath,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'device_id': deviceId,
    'wireless_endpoint': wirelessEndpoint,
    'adb_path': adbPath,
    'scrcpy_path': scrcpyPath,
    'gnirehtet_path': gnirehtetPath,
    'sync_pc_path': syncPcPath,
    'sync_android_path': syncAndroidPath,
    'created_at': createdAt.toIso8601String(),
    'last_used_at': lastUsedAt.toIso8601String(),
  };

  factory DeviceWorkspaceProfile.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return DeviceWorkspaceProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed workspace',
      deviceId: json['device_id']?.toString() ?? '',
      wirelessEndpoint: json['wireless_endpoint']?.toString() ?? '',
      adbPath: json['adb_path']?.toString() ?? '',
      scrcpyPath: json['scrcpy_path']?.toString() ?? '',
      gnirehtetPath: json['gnirehtet_path']?.toString() ?? '',
      syncPcPath: json['sync_pc_path']?.toString() ?? '',
      syncAndroidPath: json['sync_android_path']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? now,
      lastUsedAt:
          DateTime.tryParse(json['last_used_at']?.toString() ?? '') ?? now,
    );
  }
}

class DeviceWorkspaceStore {
  File get _file {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.trim().isNotEmpty) {
      return File(p.join(appData, 'JA ADB Tool', 'device_workspaces.json'));
    }
    return File(
      p.join(p.dirname(Platform.resolvedExecutable), 'device_workspaces.json'),
    );
  }

  Future<List<DeviceWorkspaceProfile>> load() async {
    try {
      if (!_file.existsSync()) return const [];
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! List) return const [];
      final profiles = <DeviceWorkspaceProfile>[];
      for (final item in decoded) {
        if (item is! Map<Object?, Object?>) continue;
        final json = item.map((key, value) => MapEntry(key.toString(), value));
        final profile = DeviceWorkspaceProfile.fromJson(json);
        if (profile.id.isNotEmpty) profiles.add(profile);
      }
      return profiles;
    } on Object catch (_) {
      return const [];
    }
  }

  Future<void> save(List<DeviceWorkspaceProfile> profiles) async {
    _file.parent.createSync(recursive: true);
    final content = const JsonEncoder.withIndent('  ').convert(
      profiles.map((profile) => profile.toJson()).toList(growable: false),
    );
    await _file.writeAsString(content, flush: true);
  }

  Future<List<DeviceWorkspaceProfile>> upsert(
    DeviceWorkspaceProfile profile,
  ) async {
    final profiles = await load();
    final index = profiles.indexWhere((item) => item.id == profile.id);
    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }
    await save(profiles);
    return profiles;
  }

  Future<List<DeviceWorkspaceProfile>> remove(String id) async {
    final profiles = await load();
    profiles.removeWhere((profile) => profile.id == id);
    await save(profiles);
    return profiles;
  }
}
