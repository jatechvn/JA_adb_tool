import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ScrcpyQualityPreset {
  final String id;
  final int maxSize;
  final int maxFps;
  final int bitRate;

  const ScrcpyQualityPreset({
    required this.id,
    required this.maxSize,
    required this.maxFps,
    required this.bitRate,
  });

  static const low = ScrcpyQualityPreset(
    id: 'low',
    maxSize: 1024,
    maxFps: 30,
    bitRate: 3,
  );

  static const balanced = ScrcpyQualityPreset(
    id: 'balanced',
    maxSize: 1600,
    maxFps: 60,
    bitRate: 6,
  );

  static const high = ScrcpyQualityPreset(
    id: 'high',
    maxSize: 1920,
    maxFps: 60,
    bitRate: 10,
  );

  static const List<ScrcpyQualityPreset> all = [low, balanced, high];

  static ScrcpyQualityPreset fromId(String? id) {
    switch (id) {
      case 'low':
        return low;
      case 'high':
        return high;
      case 'balanced':
      default:
        return balanced;
    }
  }
}

class ScrcpyProfile {
  final String name;
  final bool stayOnTop;
  final bool fullscreen;
  final bool noControl;
  final bool keepAwake;
  final bool borderless;
  final bool noAudio;
  final String preset;
  final int maxSize;
  final int maxFps;
  final int bitRate;

  const ScrcpyProfile({
    required this.name,
    required this.stayOnTop,
    required this.fullscreen,
    required this.noControl,
    required this.keepAwake,
    required this.borderless,
    required this.noAudio,
    this.preset = 'balanced',
    this.maxSize = 1600,
    this.maxFps = 60,
    this.bitRate = 6,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'stayOnTop': stayOnTop,
    'fullscreen': fullscreen,
    'noControl': noControl,
    'keepAwake': keepAwake,
    'borderless': borderless,
    'noAudio': noAudio,
    'preset': preset,
    'maxSize': maxSize,
    'maxFps': maxFps,
    'bitRate': bitRate,
  };

  factory ScrcpyProfile.fromJson(Map<String, dynamic> json) {
    final presetId = json['preset']?.toString() ?? 'balanced';
    final defaultPreset = ScrcpyQualityPreset.fromId(presetId);
    return ScrcpyProfile(
      name: json['name']?.toString() ?? 'Default',
      stayOnTop: json['stayOnTop'] == true,
      fullscreen: json['fullscreen'] == true,
      noControl: json['noControl'] == true,
      keepAwake: json['keepAwake'] != false,
      borderless: json['borderless'] == true,
      noAudio: json['noAudio'] != false,
      preset: presetId,
      maxSize: (json['maxSize'] as num?)?.toInt() ?? defaultPreset.maxSize,
      maxFps: (json['maxFps'] as num?)?.toInt() ?? defaultPreset.maxFps,
      bitRate: (json['bitRate'] as num?)?.toInt() ?? defaultPreset.bitRate,
    );
  }
}

class ScrcpyProfileStore {
  File _file() {
    final appData = Platform.environment['APPDATA'];
    final base = appData == null || appData.isEmpty
        ? p.dirname(Platform.resolvedExecutable)
        : appData;
    return File(p.join(base, 'JA ADB Tool', 'scrcpy_profiles.json'));
  }

  Future<List<ScrcpyProfile>> load() async {
    try {
      final file = _file();
      if (!file.existsSync()) return const [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<Object?, Object?>>()
          .map(
            (entry) => ScrcpyProfile.fromJson(Map<String, dynamic>.from(entry)),
          )
          .where((profile) => profile.name.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<ScrcpyProfile> profiles) async {
    final file = _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        profiles.map((profile) => profile.toJson()).toList(growable: false),
      ),
    );
  }
}
