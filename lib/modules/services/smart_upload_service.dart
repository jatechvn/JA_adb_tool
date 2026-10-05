import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../utils.dart';

/// Policy for handling filename conflicts when uploading to Android.
enum FileConflictPolicy {
  /// Prompt the user for each conflicting file or before upload.
  ask,

  /// Overwrite the existing file on Android.
  overwrite,

  /// Skip uploading the conflicting file, keeping the existing one on Android.
  skip,

  /// Auto-rename the uploaded file (e.g., "file (1).ext") to keep both.
  rename,
}

/// Status of an individual file in the upload batch.
enum FileUploadItemStatus {
  pending,
  checking,
  uploading,
  completed,
  overwritten,
  skipped,
  failed,
  cancelled,
}

/// Item representing a single file in the upload batch.
class FileUploadItem {
  final String sourcePath;
  final String relativePath;
  final String originalName;
  final int totalBytes;

  String targetName;
  String targetPath;
  FileUploadItemStatus status;
  int transferredBytes;
  String? errorMessage;
  bool isConflict;
  int? existingRemoteSize;

  FileUploadItem({
    required this.sourcePath,
    required this.relativePath,
    required this.originalName,
    required this.totalBytes,
    required this.targetName,
    required this.targetPath,
    this.status = FileUploadItemStatus.pending,
    this.transferredBytes = 0,
    this.errorMessage,
    this.isConflict = false,
    this.existingRemoteSize,
  });

  double get progress => totalBytes > 0
      ? (transferredBytes / totalBytes).clamp(0.0, 1.0)
      : (status == FileUploadItemStatus.completed ||
                status == FileUploadItemStatus.overwritten
            ? 1.0
            : 0.0);
}

/// Plan describing all files to be uploaded, total volume, and detected conflicts.
class UploadBatchPlan {
  final String targetDirectory;
  final List<FileUploadItem> items;

  UploadBatchPlan({required this.targetDirectory, required this.items});

  int get totalBytes => items.fold(0, (sum, i) => sum + i.totalBytes);
  int get totalFiles => items.length;

  List<FileUploadItem> get conflicts =>
      items.where((i) => i.isConflict).toList();
  bool get hasConflicts => conflicts.isNotEmpty;
}

/// Real-time progress snapshot of the upload batch.
class BatchUploadProgress {
  final int totalFiles;
  final int completedFiles;
  final int skippedFiles;
  final int failedFiles;
  final int totalBytes;
  final int transferredBytes;
  final double overallProgress;
  final double currentFileProgress;
  final FileUploadItem? currentItem;
  final double speedBytesPerSec;
  final Duration? estimatedTimeRemaining;
  final bool isFinished;
  final bool isCancelled;
  final String statusMessage;

  const BatchUploadProgress({
    required this.totalFiles,
    required this.completedFiles,
    required this.skippedFiles,
    required this.failedFiles,
    required this.totalBytes,
    required this.transferredBytes,
    required this.overallProgress,
    required this.currentFileProgress,
    this.currentItem,
    this.speedBytesPerSec = 0.0,
    this.estimatedTimeRemaining,
    this.isFinished = false,
    this.isCancelled = false,
    this.statusMessage = '',
  });

  String get speedFormatted =>
      '${Utils.formatBytes(speedBytesPerSec.toInt())}/s';

  String get etaFormatted {
    if (estimatedTimeRemaining == null ||
        estimatedTimeRemaining!.inSeconds <= 0) {
      return '--';
    }
    final totalSec = estimatedTimeRemaining!.inSeconds;
    if (totalSec < 60) return '${totalSec}s';
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m}m ${s}s';
  }
}

/// Service managing smart file & folder upload from PC to Android devices.
class SmartUploadService {
  static final Logger _logger = Logger('SmartUploadService');

  Process? _activeProcess;
  bool _cancelRequested = false;
  bool _skipCurrentRequested = false;

  /// Generates a unique target filename on Android when [baseName] already exists in [existingNames].
  /// Example: "photo.jpg" -> "photo (1).jpg", "photo (2).jpg".
  static String resolveUniqueRemoteName(
    String baseName,
    Set<String> existingNames,
  ) {
    if (!existingNames.contains(baseName)) return baseName;

    final dotIndex = baseName.lastIndexOf('.');
    final String stem = dotIndex > 0
        ? baseName.substring(0, dotIndex)
        : baseName;
    final String ext = dotIndex > 0 ? baseName.substring(dotIndex) : '';

    int counter = 1;
    while (true) {
      final candidate = '$stem ($counter)$ext';
      if (!existingNames.contains(candidate)) {
        return candidate;
      }
      counter++;
    }
  }

  /// Scans local files/folders and checks them against existing files on Android.
  Future<UploadBatchPlan> prepareBatchPlan({
    required List<String> localPaths,
    required String targetDirectory,
    required Set<String> existingRemoteNames,
    Map<String, int>? existingRemoteSizes,
  }) async {
    final List<FileUploadItem> items = [];
    final normalizedTargetDir = targetDirectory.endsWith('/')
        ? targetDirectory
        : '$targetDirectory/';

    for (final rawPath in localPaths) {
      final type = FileSystemEntity.typeSync(rawPath);

      if (type == FileSystemEntityType.file) {
        final file = File(rawPath);
        final fileName = p.basename(rawPath);
        final size = file.existsSync() ? file.lengthSync() : 0;
        final targetPath = '$normalizedTargetDir$fileName';
        final isConflict = existingRemoteNames.contains(fileName);

        items.add(
          FileUploadItem(
            sourcePath: rawPath,
            relativePath: fileName,
            originalName: fileName,
            totalBytes: size,
            targetName: fileName,
            targetPath: targetPath,
            isConflict: isConflict,
            existingRemoteSize: isConflict && existingRemoteSizes != null
                ? existingRemoteSizes[fileName]
                : null,
          ),
        );
      } else if (type == FileSystemEntityType.directory) {
        final dir = Directory(rawPath);
        final baseDirName = p.basename(rawPath);
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            final rel = p.relative(entity.path, from: p.dirname(rawPath));
            final normalizedRel = rel.replaceAll(r'\', '/');
            final fileName = p.basename(entity.path);
            final size = entity.existsSync() ? entity.lengthSync() : 0;
            final targetPath = '$normalizedTargetDir$normalizedRel';

            // Check if top-level root item conflicts
            final isConflict = normalizedRel == fileName
                ? existingRemoteNames.contains(fileName)
                : existingRemoteNames.contains(baseDirName);

            int? remoteSize;
            if (isConflict &&
                existingRemoteSizes != null &&
                normalizedRel == fileName) {
              remoteSize = existingRemoteSizes[fileName];
            }

            items.add(
              FileUploadItem(
                sourcePath: entity.path,
                relativePath: normalizedRel,
                originalName: fileName,
                totalBytes: size,
                targetName: fileName,
                targetPath: targetPath,
                isConflict: isConflict,
                existingRemoteSize: remoteSize,
              ),
            );
          }
        }
      }
    }

    return UploadBatchPlan(targetDirectory: targetDirectory, items: items);
  }

  /// Cancels the entire ongoing upload batch.
  void cancel() {
    _cancelRequested = true;
    _activeProcess?.kill();
    _activeProcess = null;
  }

  /// Whether cancellation has been requested.
  bool get isCancelled => _cancelRequested;

  /// Skips the currently uploading file and moves to the next file.
  void skipCurrent() {
    _skipCurrentRequested = true;
    _activeProcess?.kill();
    _activeProcess = null;
  }

  /// Whether skip for the current file has been requested.
  bool get isSkipRequested => _skipCurrentRequested;

  /// Executes the batch upload according to the selected [conflictPolicy].
  Future<void> executeBatch({
    required String adbPath,
    required String deviceId,
    required UploadBatchPlan plan,
    required FileConflictPolicy conflictPolicy,
    Future<FileConflictPolicy?> Function(FileUploadItem item)? onConflictPrompt,
    required void Function(BatchUploadProgress progress) onProgress,
    required Future<ProcessResult> Function(
      String executable,
      List<String> args,
    )
    runProcess,
    Future<Process> Function(String executable, List<String> args)?
    startProcess,
  }) async {
    _cancelRequested = false;
    _skipCurrentRequested = false;

    final existingNames = plan.items
        .where((i) => i.isConflict)
        .map((i) => i.originalName)
        .toSet();

    int totalBatchTransferred = 0;
    int completedCount = 0;
    int skippedCount = 0;
    int failedCount = 0;

    DateTime lastProgressTime = DateTime.now();
    int lastProgressBytes = 0;
    double currentSpeed = 0.0;

    void emitProgress({
      FileUploadItem? currentItem,
      double currentFileProgress = 0.0,
      bool isFinished = false,
      String statusMessage = '',
    }) {
      final now = DateTime.now();
      final timeDelta =
          now.difference(lastProgressTime).inMilliseconds / 1000.0;
      if (timeDelta >= 0.5) {
        final bytesDelta = totalBatchTransferred - lastProgressBytes;
        if (bytesDelta >= 0 && timeDelta > 0) {
          final instantSpeed = bytesDelta / timeDelta;
          currentSpeed = currentSpeed == 0.0
              ? instantSpeed
              : (currentSpeed * 0.7 + instantSpeed * 0.3);
          lastProgressBytes = totalBatchTransferred;
          lastProgressTime = now;
        }
      }

      final remainingBytes = plan.totalBytes - totalBatchTransferred;
      Duration? eta;
      if (currentSpeed > 1024 && remainingBytes > 0) {
        final remainingSec = (remainingBytes / currentSpeed).round();
        eta = Duration(seconds: remainingSec);
      }

      final overallRatio = plan.totalBytes > 0
          ? (totalBatchTransferred / plan.totalBytes).clamp(0.0, 1.0)
          : (isFinished ? 1.0 : 0.0);

      onProgress(
        BatchUploadProgress(
          totalFiles: plan.totalFiles,
          completedFiles: completedCount,
          skippedFiles: skippedCount,
          failedFiles: failedCount,
          totalBytes: plan.totalBytes,
          transferredBytes: totalBatchTransferred,
          overallProgress: overallRatio,
          currentFileProgress: currentFileProgress.clamp(0.0, 1.0),
          currentItem: currentItem,
          speedBytesPerSec: currentSpeed,
          estimatedTimeRemaining: eta,
          isFinished: isFinished,
          isCancelled: _cancelRequested,
          statusMessage: statusMessage,
        ),
      );
    }

    emitProgress(statusMessage: 'Preparing upload...');

    final activePolicy = conflictPolicy;

    for (int index = 0; index < plan.items.length; index++) {
      if (_cancelRequested) {
        for (int j = index; j < plan.items.length; j++) {
          plan.items[j].status = FileUploadItemStatus.cancelled;
        }
        break;
      }

      final item = plan.items[index];
      _skipCurrentRequested = false;
      FileConflictPolicy itemPolicy = activePolicy;

      // Handle conflict if detected
      if (item.isConflict) {
        if (activePolicy == FileConflictPolicy.ask &&
            onConflictPrompt != null) {
          final chosen = await onConflictPrompt(item);
          if (chosen == null || _cancelRequested) {
            _cancelRequested = true;
            for (int j = index; j < plan.items.length; j++) {
              plan.items[j].status = FileUploadItemStatus.cancelled;
            }
            break;
          }
          itemPolicy = chosen;
        }

        if (itemPolicy == FileConflictPolicy.skip) {
          item.status = FileUploadItemStatus.skipped;
          skippedCount++;
          emitProgress(
            currentItem: item,
            statusMessage: 'Skipped ${item.originalName}',
          );
          continue;
        } else if (itemPolicy == FileConflictPolicy.rename) {
          final newName = resolveUniqueRemoteName(
            item.originalName,
            existingNames,
          );
          existingNames.add(newName);
          item.targetName = newName;
          final parentDir = p.dirname(item.targetPath).replaceAll(r'\', '/');
          item.targetPath = '$parentDir/$newName';
        }
      }

      // Ensure remote target directory exists
      final targetParentDir = p.dirname(item.targetPath).replaceAll(r'\', '/');
      if (targetParentDir.isNotEmpty && targetParentDir != '/') {
        try {
          await runProcess(adbPath, [
            '-s',
            deviceId,
            'shell',
            'mkdir',
            '-p',
            targetParentDir,
          ]);
        } catch (e) {
          _logger.warning('Failed to ensure directory $targetParentDir: $e');
        }
      }

      item.status = FileUploadItemStatus.uploading;
      emitProgress(
        currentItem: item,
        statusMessage: 'Uploading ${item.originalName}...',
      );

      Timer? itemStatTimer;
      final fileTotalSize = item.totalBytes;
      int fileTransferred = 0;

      try {
        final startFn = startProcess ?? Process.start;
        final process = await startFn(adbPath, [
          '-s',
          deviceId,
          'push',
          item.sourcePath,
          item.targetPath,
        ]);
        _activeProcess = process;

        final stderrBuf = StringBuffer();
        process.stderr
            .transform(utf8.decoder)
            .listen((data) => stderrBuf.write(data));

        if (fileTotalSize > 0) {
          itemStatTimer = Timer.periodic(const Duration(milliseconds: 400), (
            _,
          ) async {
            if (_cancelRequested ||
                _skipCurrentRequested ||
                _activeProcess == null) {
              return;
            }
            try {
              final statRes = await runProcess(adbPath, [
                '-s',
                deviceId,
                'shell',
                'stat',
                '-c',
                '%s',
                item.targetPath,
              ]);
              final out = statRes.stdout.toString().trim();
              if (out.isNotEmpty && !out.contains('No such file')) {
                final curSize = int.tryParse(out) ?? 0;
                final delta = curSize - fileTransferred;
                if (delta > 0) {
                  fileTransferred = curSize;
                  item.transferredBytes = curSize;
                  totalBatchTransferred += delta;
                  final ratio = (curSize / fileTotalSize).clamp(0.0, 1.0);
                  emitProgress(
                    currentItem: item,
                    currentFileProgress: ratio,
                    statusMessage:
                        'Uploading ${item.originalName} (${(ratio * 100).toInt()}%)',
                  );
                }
              }
            } catch (_) {}
          });
        }

        final exitCode = await process.exitCode;
        itemStatTimer?.cancel();
        _activeProcess = null;

        if (_cancelRequested) {
          for (int j = index; j < plan.items.length; j++) {
            plan.items[j].status = FileUploadItemStatus.cancelled;
          }
          break;
        }

        if (_skipCurrentRequested) {
          item.status = FileUploadItemStatus.skipped;
          skippedCount++;
          emitProgress(
            currentItem: item,
            statusMessage: 'Skipped ${item.originalName}',
          );
          continue;
        }

        final stderrStr = stderrBuf.toString();

        if (exitCode == 0) {
          final remainder = fileTotalSize - fileTransferred;
          if (remainder > 0) {
            totalBatchTransferred += remainder;
            item.transferredBytes = fileTotalSize;
          }
          item.status =
              (item.isConflict && itemPolicy == FileConflictPolicy.overwrite)
              ? FileUploadItemStatus.overwritten
              : FileUploadItemStatus.completed;
          completedCount++;
          emitProgress(
            currentItem: item,
            currentFileProgress: 1.0,
            statusMessage: 'Finished ${item.originalName}',
          );
        } else {
          // Check for Android 13 FUSE "Bad address" bug
          if (stderrStr.contains('Bad address') ||
              stderrStr.contains('remote couldn\'t create file')) {
            _logger.info('Attempting FUSE workaround for ${item.originalName}');
            const stagingDir = '/sdcard/Android/data/com.android.browser';
            final stagingPath = '$stagingDir/${item.targetName}';

            final stageRes = await runProcess(adbPath, [
              '-s',
              deviceId,
              'push',
              item.sourcePath,
              stagingDir,
            ]);

            if (stageRes.exitCode == 0) {
              final mvRes = await runProcess(adbPath, [
                '-s',
                deviceId,
                'shell',
                'mv',
                stagingPath,
                item.targetPath,
              ]);
              if (mvRes.exitCode == 0) {
                final remainder = fileTotalSize - fileTransferred;
                if (remainder > 0) {
                  totalBatchTransferred += remainder;
                  item.transferredBytes = fileTotalSize;
                }
                item.status =
                    (item.isConflict &&
                        itemPolicy == FileConflictPolicy.overwrite)
                    ? FileUploadItemStatus.overwritten
                    : FileUploadItemStatus.completed;
                completedCount++;
                emitProgress(
                  currentItem: item,
                  currentFileProgress: 1.0,
                  statusMessage: 'Finished ${item.originalName} via staging',
                );
                continue;
              }
            }
          }

          item.status = FileUploadItemStatus.failed;
          item.errorMessage = stderrStr.trim().isNotEmpty
              ? stderrStr.trim()
              : 'Process exited with code $exitCode';
          failedCount++;
          _logger.warning(
            'Failed to push ${item.originalName}: ${item.errorMessage}',
          );
          emitProgress(
            currentItem: item,
            statusMessage: 'Failed: ${item.originalName}',
          );
        }
      } catch (e) {
        itemStatTimer?.cancel();
        _activeProcess = null;
        item.status = FileUploadItemStatus.failed;
        item.errorMessage = e.toString();
        failedCount++;
        emitProgress(
          currentItem: item,
          statusMessage: 'Error uploading ${item.originalName}',
        );
      }
    }

    emitProgress(
      isFinished: true,
      statusMessage: _cancelRequested
          ? 'Upload cancelled'
          : 'Upload finished: $completedCount completed, $skippedCount skipped, $failedCount failed',
    );
  }
}
