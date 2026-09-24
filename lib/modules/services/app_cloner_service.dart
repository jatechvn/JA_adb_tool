import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'adb_service.dart';
import 'apk_signer.dart';

final _logger = Logger('AppClonerService');

/// Represents an Android user profile (e.g. Owner 0, Work Profile 10, Dual App 95).
class AndroidUserProfile {
  final int id;
  final String name;
  final int flags;
  final bool isRunning;
  final bool isCloneSpace;

  const AndroidUserProfile({
    required this.id,
    required this.name,
    this.flags = 0,
    this.isRunning = false,
    this.isCloneSpace = false,
  });

  bool get isOwner => id == 0;

  @override
  String toString() =>
      'AndroidUserProfile(id: $id, name: "$name", cloneSpace: $isCloneSpace)';
}

/// Result of an APK Cloning operation.
class ClonedApkResult {
  final bool isSuccess;
  final String? outputPath;
  final String? newPackageName;
  final String? newAppName;
  final String? errorMessage;
  final String log;

  const ClonedApkResult({
    required this.isSuccess,
    this.outputPath,
    this.newPackageName,
    this.newAppName,
    this.errorMessage,
    this.log = '',
  });

  factory ClonedApkResult.success({
    required String outputPath,
    required String newPackageName,
    String? newAppName,
    String log = '',
  }) => ClonedApkResult(
    isSuccess: true,
    outputPath: outputPath,
    newPackageName: newPackageName,
    newAppName: newAppName,
    log: log,
  );

  factory ClonedApkResult.failure(String errorMessage, {String log = ''}) =>
      ClonedApkResult(isSuccess: false, errorMessage: errorMessage, log: log);
}

/// Helper class to parse and modify Android Binary XML (AXML) `AndroidManifest.xml`.
class AxmlModifier {
  static const int axmlFileMagic = 0x00080003;
  static const int stringPoolMagic = 0x001C0001;
  static const int utf8Flag = 0x00000100;

  /// Modifies `AndroidManifest.xml` binary bytes by replacing package name,
  /// ContentProvider authorities, and optionally app name in the String Pool.
  static Uint8List modifyManifest({
    required Uint8List manifestBytes,
    required String oldPackage,
    required String newPackage,
    String? oldAppName,
    String? newAppName,
  }) {
    if (manifestBytes.length < 8) {
      throw const FormatException(
        'Manifest file is too small to be valid AXML.',
      );
    }

    final byteData = ByteData.sublistView(manifestBytes);
    final fileMagic = byteData.getUint32(0, Endian.little);
    if (fileMagic != axmlFileMagic) {
      throw FormatException(
        'Invalid AXML magic number: 0x${fileMagic.toRadixString(16)}',
      );
    }

    // Locate String Pool chunk (starts right after 8-byte file header)
    const offset = 8;
    if (offset + 28 > manifestBytes.length) {
      throw const FormatException(
        'Unexpected end of file before String Pool header.',
      );
    }

    final poolMagic = byteData.getUint32(offset, Endian.little);
    if (poolMagic != stringPoolMagic) {
      throw FormatException(
        'Expected String Pool chunk at offset 8, found 0x${poolMagic.toRadixString(16)}',
      );
    }

    final poolChunkSize = byteData.getUint32(offset + 4, Endian.little);
    final stringCount = byteData.getUint32(offset + 8, Endian.little);
    final styleCount = byteData.getUint32(offset + 12, Endian.little);
    final flags = byteData.getUint32(offset + 16, Endian.little);
    final stringsStart = byteData.getUint32(offset + 20, Endian.little);
    final stylesStart = byteData.getUint32(offset + 24, Endian.little);

    final isUtf8 = (flags & utf8Flag) != 0;

    // Read string offsets
    final stringOffsets = <int>[];
    for (var i = 0; i < stringCount; i++) {
      stringOffsets.add(byteData.getUint32(offset + 28 + i * 4, Endian.little));
    }

    // Read style offsets if any
    final styleOffsets = <int>[];
    final styleOffsetsOffset = offset + 28 + stringCount * 4;
    for (var i = 0; i < styleCount; i++) {
      styleOffsets.add(
        byteData.getUint32(styleOffsetsOffset + i * 4, Endian.little),
      );
    }

    // Extract strings
    final stringsAbsStart = offset + stringsStart;
    final strings = <String>[];

    for (var i = 0; i < stringCount; i++) {
      final sOffset = stringsAbsStart + stringOffsets[i];
      if (isUtf8) {
        // UTF-8 length prefixes:
        // First length: character length (1 or 2 bytes)
        var p = sOffset;
        var charLen = manifestBytes[p++];
        if ((charLen & 0x80) != 0) {
          charLen = ((charLen & 0x7F) << 8) | manifestBytes[p++];
        }
        // Second length: byte length (1 or 2 bytes)
        var byteLen = manifestBytes[p++];
        if ((byteLen & 0x80) != 0) {
          byteLen = ((byteLen & 0x7F) << 8) | manifestBytes[p++];
        }
        final strBytes = manifestBytes.sublist(p, p + byteLen);
        strings.add(utf8.decode(strBytes, allowMalformed: true));
      } else {
        // UTF-16LE length prefix:
        // 2 bytes (or 4 bytes if > 0x7FFF)
        var p = sOffset;
        var charLen = byteData.getUint16(p, Endian.little);
        p += 2;
        if ((charLen & 0x8000) != 0) {
          final high = charLen & 0x7FFF;
          final low = byteData.getUint16(p, Endian.little);
          p += 2;
          charLen = (high << 16) | low;
        }
        final byteLen = charLen * 2;
        final rawBytes = manifestBytes.sublist(p, p + byteLen);
        final chars = <int>[];
        for (var c = 0; c < byteLen; c += 2) {
          chars.add(rawBytes[c] | (rawBytes[c + 1] << 8));
        }
        strings.add(String.fromCharCodes(chars));
      }
    }

    // Patch attribute references, never shared string-pool values: a package
    // string may also be used by a class name, action, permission or metadata.
    final modifiedStrings = List<String>.of(strings);
    final treeBytes = Uint8List.fromList(manifestBytes);
    final tree = ByteData.sublistView(treeBytes);
    const androidNs = 'http://schemas.android.com/apk/res/android';
    String stringAt(int index) {
      if (index < 0 || index >= strings.length) {
        throw const FormatException('Invalid manifest string reference.');
      }
      return strings[index];
    }

    void setString(int attr, String value) {
      final index = modifiedStrings.length;
      modifiedStrings.add(value);
      tree.setUint32(attr + 8, index, Endian.little);
      tree.setUint16(attr + 12, 8, Endian.little);
      tree.setUint8(attr + 14, 0);
      tree.setUint8(
        attr + 15,
        3,
      ); // TYPE_STRING, including resource-backed labels.
      tree.setUint32(attr + 16, index, Endian.little);
    }

    var foundPackage = false;
    var foundApplication = false;
    var foundLabel = false;
    var cursor = offset + poolChunkSize;
    while (cursor < treeBytes.length) {
      if (cursor + 8 > treeBytes.length) {
        throw const FormatException('Truncated XML chunk.');
      }
      final type = tree.getUint16(cursor, Endian.little);
      final header = tree.getUint16(cursor + 2, Endian.little);
      final size = tree.getUint32(cursor + 4, Endian.little);
      if (size < header || header < 8 || cursor + size > treeBytes.length) {
        throw const FormatException('Invalid XML chunk size.');
      }
      if (type == 0x0102) {
        if (header != 16 || size < 36) {
          throw const FormatException('Invalid start-element chunk.');
        }
        final tag = stringAt(tree.getUint32(cursor + 20, Endian.little));
        final attrStart = tree.getUint16(cursor + 24, Endian.little);
        final attrSize = tree.getUint16(cursor + 26, Endian.little);
        final count = tree.getUint16(cursor + 28, Endian.little);
        if (attrStart < 20 ||
            attrSize < 20 ||
            16 + attrStart + count * attrSize > size) {
          throw const FormatException('Invalid attribute table.');
        }
        if (tag == 'application') foundApplication = true;
        for (var i = 0; i < count; i++) {
          final a = cursor + 16 + attrStart + i * attrSize;
          final nsIndex = tree.getUint32(a, Endian.little);
          final ns = nsIndex == 0xffffffff ? '' : stringAt(nsIndex);
          final name = stringAt(tree.getUint32(a + 4, Endian.little));
          final valueType = tree.getUint8(a + 15);
          final value = valueType == 3
              ? stringAt(tree.getUint32(a + 16, Endian.little))
              : null;
          if (tag == 'manifest' && ns.isEmpty && name == 'split') {
            throw const FormatException(
              'Split APK is not supported. Use Dual Space.',
            );
          }
          if (tag == 'manifest' && ns == androidNs && name == 'sharedUserId') {
            throw const FormatException(
              'Shared-user APK cannot be safely re-signed.',
            );
          }
          if (tag == 'manifest' && ns.isEmpty && name == 'package') {
            if (value != oldPackage) {
              throw const FormatException(
                'Source package does not match manifest.',
              );
            }
            foundPackage = true;
            setString(a, newPackage);
          } else if (ns == androidNs &&
              name == 'label' &&
              (tag == 'application' ||
                  tag == 'activity' ||
                  tag == 'activity-alias') &&
              newAppName != null &&
              newAppName.isNotEmpty) {
            setString(a, newAppName);
            if (tag == 'application') foundLabel = true;
          } else if (ns == androidNs &&
              name == 'authorities' &&
              tag == 'provider') {
            if (value == null) {
              throw const FormatException('Resource authorities unsupported.');
            }
            setString(
              a,
              value
                  .split(';')
                  .map(
                    (authority) => authority.startsWith(oldPackage)
                        ? newPackage + authority.substring(oldPackage.length)
                        : '$authority.$newPackage',
                  )
                  .join(';'),
            );
          } else if (ns == androidNs &&
              value != null &&
              ((name == 'name' &&
                      const {
                        'application',
                        'activity',
                        'activity-alias',
                        'service',
                        'receiver',
                        'provider',
                        'instrumentation',
                      }.contains(tag)) ||
                  const {
                    'targetActivity',
                    'parentActivityName',
                    'backupAgent',
                    'appComponentFactory',
                    'manageSpaceActivity',
                  }.contains(name))) {
            // DEX classes stay in the original namespace.
            setString(
              a,
              value.startsWith('.')
                  ? '$oldPackage$value'
                  : value.contains('.')
                  ? value
                  : '$oldPackage.$value',
            );
          }
        }
      }
      cursor += size;
    }
    if (!foundPackage || !foundApplication) {
      throw const FormatException('Manifest package/application missing.');
    }
    if (newAppName != null && newAppName.isNotEmpty && !foundLabel) {
      throw const FormatException(
        'Application has no label attribute; cannot rename safely.',
      );
    }

    // Rebuild string pool data
    final newStringBytes = BytesBuilder();
    final newOffsets = <int>[];

    for (final s in modifiedStrings) {
      newOffsets.add(newStringBytes.length);
      if (isUtf8) {
        final encoded = utf8.encode(s);
        // Write char length
        if (s.length > 0x7F) {
          newStringBytes.addByte(0x80 | ((s.length >> 8) & 0x7F));
          newStringBytes.addByte(s.length & 0xFF);
        } else {
          newStringBytes.addByte(s.length);
        }
        // Write byte length
        if (encoded.length > 0x7F) {
          newStringBytes.addByte(0x80 | ((encoded.length >> 8) & 0x7F));
          newStringBytes.addByte(encoded.length & 0xFF);
        } else {
          newStringBytes.addByte(encoded.length);
        }
        newStringBytes.add(encoded);
        newStringBytes.addByte(0x00); // Null terminator
      } else {
        final codeUnits = s.codeUnits;
        if (codeUnits.length > 0x7FFF) {
          final high = (codeUnits.length >> 16) | 0x8000;
          final low = codeUnits.length & 0xFFFF;
          newStringBytes.addByte(high & 0xFF);
          newStringBytes.addByte((high >> 8) & 0xFF);
          newStringBytes.addByte(low & 0xFF);
          newStringBytes.addByte((low >> 8) & 0xFF);
        } else {
          newStringBytes.addByte(codeUnits.length & 0xFF);
          newStringBytes.addByte((codeUnits.length >> 8) & 0xFF);
        }
        for (final cu in codeUnits) {
          newStringBytes.addByte(cu & 0xFF);
          newStringBytes.addByte((cu >> 8) & 0xFF);
        }
        // 2-byte null terminator
        newStringBytes.addByte(0x00);
        newStringBytes.addByte(0x00);
      }
    }

    // Align string pool data to 4 bytes
    final unalignedBytes = newStringBytes.length % 4;
    if (unalignedBytes != 0) {
      for (var p = 0; p < 4 - unalignedBytes; p++) {
        newStringBytes.addByte(0x00);
      }
    }

    final newStringsData = newStringBytes.toBytes();

    // Preserve styles data if any
    final stylesLen = (stylesStart != 0 && stylesStart < poolChunkSize)
        ? (poolChunkSize - stylesStart)
        : 0;
    Uint8List stylesData = Uint8List(0);
    if (stylesLen > 0) {
      stylesData = manifestBytes.sublist(
        offset + stylesStart,
        offset + poolChunkSize,
      );
    }

    // Reconstruct new String Pool chunk
    const headerSize = 28;
    final offsetsSize = modifiedStrings.length * 4 + styleCount * 4;
    final newStringsStartOffset = headerSize + offsetsSize;
    final newStylesStartOffset = stylesLen > 0
        ? (newStringsStartOffset + newStringsData.length)
        : 0;
    final newPoolChunkSize =
        newStringsStartOffset + newStringsData.length + stylesData.length;

    final poolBuilder = BytesBuilder();
    final pHeader = ByteData(headerSize);
    pHeader.setUint16(0, 0x0001, Endian.little); // String pool chunk type
    pHeader.setUint16(2, headerSize, Endian.little);
    pHeader.setUint32(4, newPoolChunkSize, Endian.little);
    pHeader.setUint32(8, modifiedStrings.length, Endian.little);
    pHeader.setUint32(12, styleCount, Endian.little);
    pHeader.setUint32(
      16,
      flags & ~1,
      Endian.little,
    ); // Pool is no longer sorted.
    pHeader.setUint32(20, newStringsStartOffset, Endian.little);
    pHeader.setUint32(24, newStylesStartOffset, Endian.little);
    poolBuilder.add(pHeader.buffer.asUint8List());

    // Write new string offsets
    final offsetsData = ByteData(modifiedStrings.length * 4);
    for (var i = 0; i < modifiedStrings.length; i++) {
      offsetsData.setUint32(i * 4, newOffsets[i], Endian.little);
    }
    poolBuilder.add(offsetsData.buffer.asUint8List());

    // Write style offsets if any
    if (styleCount > 0) {
      final sOffsetsData = ByteData(styleCount * 4);
      for (var i = 0; i < styleCount; i++) {
        sOffsetsData.setUint32(i * 4, styleOffsets[i], Endian.little);
      }
      poolBuilder.add(sOffsetsData.buffer.asUint8List());
    }

    // Add string bytes
    poolBuilder.add(newStringsData);

    // Add styles bytes if any
    if (stylesData.isNotEmpty) {
      poolBuilder.add(stylesData);
    }

    final newPoolBytes = poolBuilder.toBytes();

    // Rebuild entire AXML: File Header + New Pool Chunk + Remaining Chunks
    final remainingChunksOffset = offset + poolChunkSize;
    final remainingChunks = remainingChunksOffset < manifestBytes.length
        ? treeBytes.sublist(remainingChunksOffset)
        : Uint8List(0);

    final newTotalFileSize = 8 + newPoolBytes.length + remainingChunks.length;
    final finalBuilder = BytesBuilder();

    // 8-byte file header
    final fHeader = ByteData(8);
    fHeader.setUint32(0, axmlFileMagic, Endian.little);
    fHeader.setUint32(4, newTotalFileSize, Endian.little);
    finalBuilder.add(fHeader.buffer.asUint8List());

    // New pool
    finalBuilder.add(newPoolBytes);

    // Remaining chunks
    if (remainingChunks.isNotEmpty) {
      finalBuilder.add(remainingChunks);
    }

    return finalBuilder.toBytes();
  }
}

/// Service that handles Standalone APK Cloning (modifying manifest, repacking, signing)
/// and ADB Multi-User / Dual Space Cloning.
class AppClonerService {
  final AdbService _adbService;
  final ApkSigner Function() _signerFactory;

  AppClonerService({
    AdbService? adbService,
    ApkSigner Function()? signerFactory,
  }) : _adbService = adbService ?? const AdbService(),
       _signerFactory = signerFactory ?? ApkSigner.discover;

  // ---------------------------------------------------------------------------
  // METHOD 1: Standalone APK Cloning & Repackaging
  // ---------------------------------------------------------------------------

  /// Modifies an input APK file, updates its `AndroidManifest.xml` (renames package
  /// and authorities), strips old signatures, repacks to ZIP, and signs with debug keystore.
  Future<ClonedApkResult> cloneApkFile({
    required String sourceApkPath,
    required String targetDirectory,
    required String oldPackage,
    required String newPackage,
    String? newAppName,
    void Function(String step, double progress)? onProgress,
  }) async {
    final logLines = <String>[];
    void log(String msg) {
      logLines.add(msg);
      _logger.info(msg);
    }

    try {
      final packagePattern = RegExp(
        r'^[a-zA-Z][a-zA-Z0-9_]*(\.[a-zA-Z][a-zA-Z0-9_]*)+$',
      );
      if (!packagePattern.hasMatch(newPackage) ||
          !packagePattern.hasMatch(oldPackage) ||
          newPackage == oldPackage) {
        return ClonedApkResult.failure('Invalid or unchanged package ID.');
      }
      if (p.extension(sourceApkPath).toLowerCase() != '.apk') {
        return ClonedApkResult.failure(
          'Split APK/XAPK cloning is unsupported. Use Dual Space.',
        );
      }
      final sourceFile = File(sourceApkPath);
      if (!sourceFile.existsSync()) {
        return ClonedApkResult.failure(
          'Source APK file not found at: $sourceApkPath',
        );
      }

      onProgress?.call('Reading and parsing source APK...', 0.15);
      log(
        'Reading source APK: ${p.basename(sourceApkPath)} (${(sourceFile.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB)',
      );
      final apkBytes = await sourceFile.readAsBytes();

      final archive = ZipDecoder().decodeBytes(apkBytes);
      ArchiveFile? manifestFile;

      onProgress?.call('Modifying AndroidManifest.xml binary...', 0.35);
      log('Searching for AndroidManifest.xml in archive...');
      for (final file in archive.files) {
        if (file.name == 'AndroidManifest.xml') {
          manifestFile = file;
          break;
        }
      }

      if (manifestFile == null) {
        return ClonedApkResult.failure(
          'AndroidManifest.xml not found in APK archive.',
          log: logLines.join('\n'),
        );
      }

      final rawManifestBytes = manifestFile.content as List<int>;
      log('Patching package: $oldPackage -> $newPackage');
      final patchedManifestBytes = AxmlModifier.modifyManifest(
        manifestBytes: Uint8List.fromList(rawManifestBytes),
        oldPackage: oldPackage,
        newPackage: newPackage,
        newAppName: newAppName,
      );
      log(
        'AndroidManifest.xml successfully patched (${patchedManifestBytes.length} bytes)',
      );

      // Replace manifest in archive
      archive.addFile(
        ArchiveFile(
          'AndroidManifest.xml',
          patchedManifestBytes.length,
          patchedManifestBytes,
        ),
      );

      onProgress?.call('Stripping old cryptographic signatures...', 0.50);
      log('Removing obsolete signatures in META-INF/...');
      final filesToKeep = <ArchiveFile>[];
      for (final file in archive.files) {
        final name = file.name.toUpperCase();
        if (name.startsWith('META-INF/') &&
            (name.endsWith('.SF') ||
                name.endsWith('.RSA') ||
                name.endsWith('.DSA') ||
                name.endsWith('.EC') ||
                name.endsWith('MANIFEST.MF'))) {
          // Skip old signature file
          continue;
        }
        filesToKeep.add(file);
      }

      final cleanArchive = Archive();
      for (final file in filesToKeep) {
        cleanArchive.addFile(file);
      }

      onProgress?.call('Re-packing modified APK archive...', 0.70);
      log('Re-packing modified APK zip archive...');
      final zipEncoder = ZipEncoder();
      final repackedBytes = zipEncoder.encode(cleanArchive);
      if (repackedBytes == null) {
        return ClonedApkResult.failure(
          'Failed to encode modified APK archive.',
          log: logLines.join('\n'),
        );
      }

      final outDir = Directory(targetDirectory);
      if (!outDir.existsSync()) {
        outDir.createSync(recursive: true);
      }

      final outputApkPath = p.join(targetDirectory, '${newPackage}_cloned.apk');
      final outputFile = File(outputApkPath);
      if (outputFile.existsSync()) {
        return ClonedApkResult.failure(
          'Output already exists. Choose another package ID or folder.',
        );
      }
      final signer = _signerFactory();
      final stage = Directory.systemTemp.createTempSync('ja_clone_sign_');
      final unsignedPath = p.join(stage.path, 'unsigned.apk');
      final signedPath = p.join(stage.path, 'signed.apk');
      await File(unsignedPath).writeAsBytes(repackedBytes);

      onProgress?.call('Signing cloned APK...', 0.85);
      await signer.signAndVerify(unsignedPath, signedPath);
      await File(signedPath).copy(outputApkPath);
      onProgress?.call('Cloning completed successfully!', 1.0);
      log('APK aligned, signed and verified with v2 signature.');

      return ClonedApkResult.success(
        outputPath: outputApkPath,
        newPackageName: newPackage,
        newAppName: newAppName,
        log: logLines.join('\n'),
      );
    } catch (e, stack) {
      _logger.severe('APK cloning failed: $e', e, stack);
      return ClonedApkResult.failure(
        'APK cloning error: $e',
        log: logLines.join('\n'),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // METHOD 2: ADB Multi-User & Dual Space (Instant Cloning)
  // ---------------------------------------------------------------------------

  /// Fetches all user profiles on the connected device via `pm list users`.
  Future<List<AndroidUserProfile>> listDeviceUsers(
    String adbPath,
    String deviceId,
  ) async {
    final result = await _adbService.run(adbPath, [
      '-s',
      deviceId,
      'shell',
      'pm',
      'list',
      'users',
    ]);

    if (!result.isSuccess) {
      _logger.warning('Failed to list device users: ${result.stderr}');
      return const [AndroidUserProfile(id: 0, name: 'Owner', isRunning: true)];
    }

    final profiles = <AndroidUserProfile>[];
    final lines = result.stdout.split('\n');

    // Parse lines like: "UserInfo{0:Owner:13} running" or "UserInfo{10:Work profile:30} running"
    final regex = RegExp(
      r'UserInfo\{(\d+):([^:]+):([0-9a-fA-F]+)\}(?:\s+(\w+))?',
    );
    for (final line in lines) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final id = int.tryParse(match.group(1)!) ?? 0;
        final name = match.group(2) ?? 'User $id';
        final flags = int.tryParse(match.group(3)!, radix: 16) ?? 0;
        final status = match.group(4) ?? '';
        final isRunning = status.toLowerCase() == 'running';
        final isCloneSpace =
            id != 0 &&
            (name.toLowerCase().contains('clone') ||
                name.toLowerCase().contains('work') ||
                name.toLowerCase().contains('dual'));

        profiles.add(
          AndroidUserProfile(
            id: id,
            name: name,
            flags: flags,
            isRunning: isRunning,
            isCloneSpace: isCloneSpace,
          ),
        );
      }
    }

    if (profiles.isEmpty) {
      profiles.add(
        const AndroidUserProfile(id: 0, name: 'Owner', isRunning: true),
      );
    }
    return profiles;
  }

  /// Creates a new managed clone space profile on device.
  Future<int?> createCloneProfile(
    String adbPath,
    String deviceId, {
    String name = 'JA Clone Space',
  }) async {
    // Try creating managed work profile first
    var result = await _adbService.run(adbPath, [
      '-s',
      deviceId,
      'shell',
      'pm',
      'create-user',
      '--profileOf',
      '0',
      '--managed',
      name,
    ]);

    if (!result.isSuccess ||
        !result.stdout.contains('Success: created user id')) {
      // Fallback to standard secondary user
      result = await _adbService.run(adbPath, [
        '-s',
        deviceId,
        'shell',
        'pm',
        'create-user',
        name,
      ]);
    }

    if (result.isSuccess) {
      final match = RegExp(r'created user id (\d+)').firstMatch(result.stdout);
      if (match != null) {
        final newId = int.tryParse(match.group(1)!);
        if (newId != null) {
          // Start the user profile
          await _adbService.run(adbPath, [
            '-s',
            deviceId,
            'shell',
            'am',
            'start-user',
            '$newId',
          ]);
          return newId;
        }
      }
    }

    _logger.warning('Failed to create clone profile: ${result.combinedOutput}');
    return null;
  }

  /// Installs an existing package into the specified user profile in under 1 second.
  Future<bool> installAppToProfile(
    String adbPath,
    String deviceId, {
    required int userId,
    required String packageName,
  }) async {
    final result = await _adbService.run(adbPath, [
      '-s',
      deviceId,
      'shell',
      'pm',
      'install-existing',
      '--user',
      '$userId',
      packageName,
    ]);

    return result.isSuccess && !result.stdout.toLowerCase().contains('failed');
  }

  /// Launches an app in the specified user profile.
  Future<bool> launchAppInProfile(
    String adbPath,
    String deviceId, {
    required int userId,
    required String packageName,
  }) async {
    final result = await _adbService.run(adbPath, [
      '-s',
      deviceId,
      'shell',
      'monkey',
      '--user',
      '$userId',
      '-p',
      packageName,
      '-c',
      'android.intent.category.LAUNCHER',
      '1',
    ]);

    return result.isSuccess;
  }

  /// Removes an app from the specified user profile without deleting the primary app.
  Future<bool> uninstallAppFromProfile(
    String adbPath,
    String deviceId, {
    required int userId,
    required String packageName,
  }) async {
    final result = await _adbService.run(adbPath, [
      '-s',
      deviceId,
      'shell',
      'pm',
      'uninstall',
      '--user',
      '$userId',
      packageName,
    ]);

    return result.isSuccess;
  }
}
