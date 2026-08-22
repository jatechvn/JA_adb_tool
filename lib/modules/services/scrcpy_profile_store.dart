import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ScrcpyProfile {
  final String name;
  final bool stayOnTop;
  final bool fullscreen;
  final bool noControl;
  final bool keepAwake;
  final bool borderless;
  final bool noAudio;

  const ScrcpyProfile({
    required this.name,
    required this.stayOnTop,
    required this.fullscreen,
    required this.noControl,
    required this.keepAwake,
    required this.borderless,
    required this.noAudio,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'stayOnTop': stayOnTop,
    'fullscreen': fullscreen,
    'noControl': noControl,
    'keepAwake': keepAwake,
    'borderless': borderless,
    'noAudio': noAudio,
  };

  factory ScrcpyProfile.fromJson(Map<String, dynamic> json) => ScrcpyProfile(
    name: json['name']?.toString() ?? 'Default',
    stayOnTop: json['stayOnTop'] == true,
    fullscreen: json['fullscreen'] == true,
    noControl: json['noControl'] == true,
    keepAwake: json['keepAwake'] != false,
    borderless: json['borderless'] == true,
    noAudio: json['noAudio'] != false,
  );
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
