import 'dart:convert';
import 'dart:io';

class SettingsBackupService {
  static const schemaVersion = 1;

  const SettingsBackupService();

  Future<void> exportToFile({
    required String path,
    required Map<String, dynamic> settings,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final payload = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'app': 'JA ADB Tool',
      'settings': settings,
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
  }

  Future<Map<String, dynamic>> importFromFile(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const FormatException('Backup file does not exist.');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Backup root must be an object.');
    }
    final schema = int.tryParse(decoded['schemaVersion']?.toString() ?? '');
    if (schema != schemaVersion) {
      throw FormatException(
        'Unsupported backup schema: ${decoded['schemaVersion']}.',
      );
    }
    final settings = decoded['settings'];
    if (settings is! Map) {
      throw const FormatException('Backup settings are missing.');
    }
    return Map<String, dynamic>.from(settings);
  }
}
