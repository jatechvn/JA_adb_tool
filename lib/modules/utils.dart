// lib/modules/utils.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'logger_config.dart';

class Utils {
  /// Formats byte sizes into human readable strings (e.g., 1.23 GB)
  static String formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    int i = 0;
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Safe double parser
  static double parseDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Safe int parser
  static int parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    return defaultValue;
  }

  /// Runs a command on the local operating system
  static Future<ProcessResult> runLocalCommand(
    String command,
    List<String> args,
  ) async {
    try {
      logger.info('Executing local command: $command ${args.join(' ')}');
      final result = await Process.run(
        command,
        args,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      return result;
    } catch (e) {
      logger.severe('Failed to execute local command: $e');
      return ProcessResult(0, -1, '', 'Failed to execute command: $e');
    }
  }

  /// Formats a duration in seconds into a friendly string (e.g., 2d 5h 30m)
  static String formatUptime(int seconds) {
    if (seconds <= 0) return 'Unknown';
    final days = seconds ~/ (24 * 3600);
    final hours = (seconds % (24 * 3600)) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0 || parts.isEmpty) parts.add('${minutes}m');

    return parts.join(' ');
  }

  /// Cleans up non-color ANSI escape sequences like cursor movements and title changes
  static String cleanTerminalText(String text) {
    String cleaned = text.replaceAll('\r\n', '\n').replaceAll('\r', '');
    cleaned = cleaned.replaceAll(
      RegExp(r'\x1B\][0-9]*;[^\x07\x1B]*(\x07|\x1B\\)'),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\x1B\[\??[0-9;]*[a-df-ln-zAF-Z]'),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\x1B[=>]'), '');
    cleaned = cleaned.replaceAll('\x07', '');
    return cleaned;
  }

  /// Parses ANSI escape codes from a string and converts them into a TextSpan
  static TextSpan parseAnsi(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final ansiPattern = RegExp(r'\x1B\[([0-9;]*)m');

    int lastMatchEnd = 0;
    TextStyle currentStyle = baseStyle;

    for (final match in ansiPattern.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastMatchEnd, match.start),
            style: currentStyle,
          ),
        );
      }

      final codes = match.group(1)?.split(';') ?? [];
      currentStyle = _applyAnsiCodes(currentStyle, baseStyle, codes);

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(
        TextSpan(text: text.substring(lastMatchEnd), style: currentStyle),
      );
    }

    return TextSpan(children: spans);
  }

  static TextStyle _applyAnsiCodes(
    TextStyle current,
    TextStyle base,
    List<String> codes,
  ) {
    TextStyle style = current;

    if (codes.isEmpty || codes.first == '' || codes.first == '0') {
      return base;
    }

    for (final code in codes) {
      final val = int.tryParse(code);
      if (val == null) continue;

      switch (val) {
        case 0:
          style = base;
          break;
        case 1:
          style = style.copyWith(fontWeight: FontWeight.bold);
          break;
        case 3:
          style = style.copyWith(fontStyle: FontStyle.italic);
          break;
        case 4:
          style = style.copyWith(decoration: TextDecoration.underline);
          break;
        case 30:
          style = style.copyWith(color: Colors.black);
          break;
        case 31:
          style = style.copyWith(color: Colors.redAccent);
          break;
        case 32:
          style = style.copyWith(color: const Color(0xFF00E676));
          break;
        case 33:
          style = style.copyWith(color: Colors.amberAccent);
          break;
        case 34:
          style = style.copyWith(color: const Color(0xFF2979FF));
          break;
        case 35:
          style = style.copyWith(color: Colors.purpleAccent);
          break;
        case 36:
          style = style.copyWith(color: const Color(0xFF00ADB5));
          break;
        case 37:
          style = style.copyWith(color: Colors.white);
          break;
        case 90:
          style = style.copyWith(color: Colors.grey);
          break;
        case 91:
          style = style.copyWith(color: Colors.redAccent);
          break;
        case 92:
          style = style.copyWith(color: Colors.greenAccent);
          break;
        case 93:
          style = style.copyWith(color: Colors.yellowAccent);
          break;
        case 94:
          style = style.copyWith(color: Colors.blueAccent);
          break;
        case 95:
          style = style.copyWith(color: Colors.pinkAccent);
          break;
        case 96:
          style = style.copyWith(color: Colors.cyanAccent);
          break;
        case 97:
          style = style.copyWith(color: Colors.white);
          break;
      }
    }

    return style;
  }
}
