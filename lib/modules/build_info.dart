import 'dart:io';

import 'package:flutter/foundation.dart';

import 'constants.dart';

/// Runtime build metadata and command-line debug mode.
///
/// The portable debug launcher passes `-debug` to the compiled executable so
/// testers can distinguish a diagnostic run from a normal release run.
class BuildInfo {
  static bool isCliDebug = false;
  static final String debugTimestamp = _generateBuildTimestamp();

  static bool get isDebug => kDebugMode || isCliDebug;

  static const String version = appVersion;

  static String _generateBuildTimestamp() {
    try {
      final executable = File(Platform.resolvedExecutable);
      final appSo = File(
        '${executable.parent.path}${Platform.pathSeparator}data'
        '${Platform.pathSeparator}app.so',
      );
      final target = appSo.existsSync() ? appSo : executable;
      if (target.existsSync()) {
        final modified = target.lastModifiedSync();
        final date =
            '${modified.year.toString().padLeft(4, '0')}-'
            '${modified.month.toString().padLeft(2, '0')}-'
            '${modified.day.toString().padLeft(2, '0')}';
        final time =
            '${modified.hour.toString().padLeft(2, '0')}:'
            '${modified.minute.toString().padLeft(2, '0')}:'
            '${modified.second.toString().padLeft(2, '0')}';
        return '$date $time';
      }
    } catch (_) {
      // Fall through to a readable timestamp if the executable metadata is
      // unavailable (for example during a test run).
    }
    return DateTime.now()
        .toIso8601String()
        .split('.')
        .first
        .replaceFirst('T', ' ');
  }
}
