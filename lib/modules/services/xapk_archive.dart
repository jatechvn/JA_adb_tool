import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

const int _maxXapkArchiveBytes = 1024 * 1024 * 1024;
const int _maxXapkEntries = 512;
const int _maxXapkUncompressedBytes = 2 * 1024 * 1024 * 1024;

bool isSafeXapkEntryPath(String entryPath) {
  final normalized = p.posix.normalize(entryPath.replaceAll('\\', '/'));
  return normalized.isNotEmpty &&
      !p.posix.isAbsolute(normalized) &&
      normalized != '..' &&
      !normalized.startsWith('../') &&
      !RegExp(r'^[a-zA-Z]:').hasMatch(normalized);
}

Archive openValidatedXapk(
  String xapkPath, {
  int maxArchiveBytes = _maxXapkArchiveBytes,
  int maxEntries = _maxXapkEntries,
  int maxUncompressedBytes = _maxXapkUncompressedBytes,
}) {
  final archiveFile = File(xapkPath);
  final archiveBytes = archiveFile.lengthSync();
  if (archiveBytes > maxArchiveBytes) {
    throw const FormatException('XAPK is larger than the 1 GB safety limit.');
  }

  final archive = ZipDecoder().decodeBuffer(InputFileStream(xapkPath));
  if (archive.files.length > maxEntries) {
    final count = archive.files.length;
    archive.clearSync();
    throw FormatException('XAPK has too many entries ($count).');
  }

  var uncompressedBytes = 0;
  for (final entry in archive.files) {
    if (!isSafeXapkEntryPath(entry.name) || entry.isSymbolicLink) {
      archive.clearSync();
      throw FormatException(
        'XAPK contains an unsafe archive entry: ${entry.name}',
      );
    }
    uncompressedBytes += entry.size;
    if (uncompressedBytes > maxUncompressedBytes) {
      archive.clearSync();
      throw const FormatException('XAPK expands beyond the 2 GB safety limit.');
    }
  }
  return archive;
}

Future<void> extractXapkInBackground(String source, String destination) =>
    Isolate.run(() {
      final archive = openValidatedXapk(source);
      try {
        for (final entry in archive.files) {
          if (!entry.isFile) continue;
          final name = p.posix.normalize(entry.name.replaceAll('\\', '/'));
          final target = p.joinAll([destination, ...name.split('/')]);
          if (!p.isWithin(destination, target)) {
            throw const FormatException(
              'XAPK entry escapes staging directory.',
            );
          }
          File(target).parent.createSync(recursive: true);
          final output = OutputFileStream(target);
          try {
            entry.writeContent(output);
          } finally {
            output.closeSync();
          }
        }
      } finally {
        archive.clearSync();
      }
    });

Future<void> packageDirectoryInBackground(String source, String output) =>
    Isolate.run(() async {
      final encoder = ZipFileEncoder();
      encoder.create(output);
      try {
        for (final entity in Directory(source).listSync(recursive: true)) {
          if (entity is File &&
              p.canonicalize(entity.path) != p.canonicalize(output)) {
            await encoder.addFile(
              entity,
              p.relative(entity.path, from: source).replaceAll('\\', '/'),
            );
          }
        }
      } finally {
        await encoder.close();
      }
    });
