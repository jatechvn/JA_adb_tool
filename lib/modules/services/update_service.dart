import 'dart:convert';
import 'dart:io';

class UpdateInfo {
  final String version;
  final String tagName;
  final String releaseUrl;
  final String releaseNotes;
  final bool isNewer;

  const UpdateInfo({
    required this.version,
    required this.tagName,
    required this.releaseUrl,
    required this.releaseNotes,
    required this.isNewer,
  });
}

class UpdateService {
  final String repository;

  const UpdateService({required this.repository});

  Future<UpdateInfo?> checkLatest({required String currentVersion}) async {
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(
            Uri.parse(
              'https://api.github.com/repos/$repository/releases/latest',
            ),
          )
          .timeout(const Duration(seconds: 8));
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'JA-ADB-Tool');
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      if (response.statusCode != HttpStatus.ok) return null;
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final tag = decoded['tag_name']?.toString() ?? '';
      final version = tag.replaceFirst(RegExp(r'^v', caseSensitive: false), '');
      if (version.isEmpty) return null;
      return UpdateInfo(
        version: version,
        tagName: tag,
        releaseUrl:
            decoded['html_url']?.toString() ??
            'https://github.com/$repository/releases',
        releaseNotes: decoded['body']?.toString() ?? '',
        isNewer: _compareVersions(version, currentVersion) > 0,
      );
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  int _compareVersions(String left, String right) {
    final a = _parts(left);
    final b = _parts(right);
    for (var index = 0; index < 3; index++) {
      final result = a[index].compareTo(b[index]);
      if (result != 0) return result;
    }
    return 0;
  }

  List<int> _parts(String value) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(value);
    if (match == null) return const [0, 0, 0];
    return [
      int.tryParse(match.group(1)!) ?? 0,
      int.tryParse(match.group(2)!) ?? 0,
      int.tryParse(match.group(3)!) ?? 0,
    ];
  }
}
