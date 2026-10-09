import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ja_adb_tool/modules/services/helper_ime_session.dart';

// Explicit physical-device diagnostic, not part of flutter test.
Future<void> main(List<String> args) async {
  if (args.length != 1 || args.single != 'bc4cd33a') {
    throw ArgumentError(
      'Pass bc4cd33a explicitly and focus its sample Settings search editor.',
    );
  }
  final adb = File('bin/adb.exe').absolute.path;
  final device = args.single;
  Future<String> shell(List<String> command) async {
    final result = await Process.run(
      adb,
      ['-s', device, 'shell', ...command],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) throw StateError('Diagnostic ADB command failed');
    return result.stdout.toString();
  }

  Future<String> readSample() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final dumped = await shell([
        'uiautomator',
        'dump',
        '/data/local/tmp/ja-ime-test.xml',
      ]);
      if (!dumped.contains('UI hierchary dumped')) continue;
      final xml = await shell(['cat', '/data/local/tmp/ja-ime-test.xml']);
      final node = RegExp(
        r'<node[^>]*resource-id="android:id/search_src_text"[^>]*>',
      ).firstMatch(xml)?.group(0);
      if (node != null &&
          node.contains('package="com.android.settings.intelligence"') &&
          node.contains('password="false"')) {
        return RegExp(r' text="([^"]*)"')
            .firstMatch(node)!
            .group(1)!
            .replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|\d+);'), (match) {
              final code = match.group(1)!;
              return String.fromCharCode(
                code.startsWith('x')
                    ? int.parse(code.substring(1), radix: 16)
                    : int.parse(code),
              );
            });
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    throw StateError('Sample editor unavailable');
  }

  final initial = await readSample();
  if (![
    'Search…',
    'Xin chào Việt Nam 12',
    ' JA Việt 😀',
    'JA Việt 😀',
    'JA Việt ',
  ].contains(initial)) {
    throw StateError(
      'Not an empty or known sample query; refusing to change user text.',
    );
  }
  final session = HelperImeSession(adbPath: adb, device: device);
  try {
    await session.activate();
    // Clear only a whitelisted synthetic query; selection can be select-all.
    await shell([
      'am',
      'broadcast',
      '-p',
      'com.android.adbkeyboard',
      '-a',
      'ADB_CLEAR_TEXT',
    ]);
    await session.sendText('JA Việt 😀');
    if (await readSample() != 'JA Việt 😀') {
      throw StateError('Text readback mismatch');
    }
    stdout.writeln('Dart service UTF-8 readback PASS');
    await session.backspace();
    if (await readSample() != 'JA Việt ') {
      throw StateError('Backspace readback mismatch');
    }
    stdout.writeln('Dart service Backspace readback PASS');
    await session.editorAction(3);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!(await shell([
      'dumpsys',
      'input_method',
    ])).contains('mInputShown=false')) {
      throw StateError('SEARCH action not observed');
    }
    stdout.writeln('Dart service editor SEARCH PASS');
  } finally {
    await session.close();
    final current = (await shell([
      'settings',
      'get',
      'secure',
      'default_input_method',
    ])).trim();
    if (current != 'com.android.inputmethod.latin/.LatinIME') {
      throw StateError('Restore mismatch');
    }
    stdout.writeln('Dart service LatinIME restore PASS');
  }
}
