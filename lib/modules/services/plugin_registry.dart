import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

class ToolPluginDescriptor {
  final String id;
  final String name;
  final String version;
  final String description;
  final String entryPoint;
  final bool enabled;

  const ToolPluginDescriptor({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.entryPoint,
    required this.enabled,
  });

  ToolPluginDescriptor copyWith({bool? enabled}) => ToolPluginDescriptor(
    id: id,
    name: name,
    version: version,
    description: description,
    entryPoint: entryPoint,
    enabled: enabled ?? this.enabled,
  );

  factory ToolPluginDescriptor.fromJson(Map<String, dynamic> json) {
    return ToolPluginDescriptor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      version: json['version']?.toString() ?? '0.0.0',
      description: json['description']?.toString() ?? '',
      entryPoint: json['entryPoint']?.toString() ?? '',
      enabled: json['enabled'] != false,
    );
  }
}

class PluginRegistry {
  Directory get _directory {
    final appData = Platform.environment['APPDATA'];
    final root = appData == null || appData.trim().isEmpty
        ? p.dirname(Platform.resolvedExecutable)
        : appData;
    return Directory(p.join(root, 'JA ADB Tool', 'plugins'));
  }

  File get _stateFile => File(p.join(_directory.path, 'plugin_state.json'));

  Future<List<ToolPluginDescriptor>> scan() async {
    try {
      if (!_directory.existsSync()) return const [];
      final state = await _loadState();
      final result = <ToolPluginDescriptor>[];
      for (final entity in _directory.listSync()) {
        if (entity is! File ||
            p.extension(entity.path).toLowerCase() != '.json') {
          continue;
        }
        if (p.basename(entity.path) == p.basename(_stateFile.path)) continue;
        try {
          final decoded = jsonDecode(await entity.readAsString());
          if (decoded is! Map) continue;
          final descriptor = ToolPluginDescriptor.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          if (descriptor.id.isEmpty || descriptor.name.isEmpty) continue;
          result.add(
            descriptor.copyWith(
              enabled: state[descriptor.id] ?? descriptor.enabled,
            ),
          );
        } catch (_) {
          // Ignore malformed manifests so one bad plugin does not block startup.
        }
      }
      result.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final state = await _loadState();
    state[id] = enabled;
    await _directory.create(recursive: true);
    await _stateFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state),
    );
  }

  Future<Map<String, bool>> _loadState() async {
    try {
      if (!_stateFile.existsSync()) return {};
      final decoded = jsonDecode(await _stateFile.readAsString());
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value == true),
      );
    } catch (_) {
      return {};
    }
  }
}
