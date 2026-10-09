import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'adb_service.dart';

/// Explicit, device-bound session. Never logs or persists entered text.
class HelperImeSession {
  HelperImeSession({required this.adbPath, required this.device, this.runner});
  static const helper = 'com.android.adbkeyboard/.AdbIME';
  final String adbPath, device;
  final AdbProcessRunner? runner;
  Future<void> _tail = Future.value();
  String? _original;
  bool _wasEnabled = false, _acceptCommands = true;
  bool active = false;
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<ProcessResult> _run(List<String> command) async {
    if (adbPath.isEmpty || device.isEmpty) {
      throw StateError('helper_command_failed');
    }
    final args = ['-s', device, 'shell', ...command];
    ProcessResult result;
    try {
      if (runner != null) {
        result = await runner!(
          adbPath,
          args,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
      } else {
        final process = await Process.start(adbPath, args);
        final output = utf8.decoder.bind(process.stdout).join();
        final error = utf8.decoder.bind(process.stderr).join();
        final code = await process.exitCode.timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            process.kill();
            throw TimeoutException('ADB');
          },
        );
        result = ProcessResult(process.pid, code, await output, await error);
      }
    } catch (_) {
      throw StateError('helper_command_failed');
    }
    if (result.exitCode != 0 ||
        result.stderr.toString().contains('Exception')) {
      throw StateError('helper_command_failed');
    }
    return result;
  }

  void invalidate() => _acceptCommands = false;
  void _check() {
    if (!_acceptCommands) throw StateError('helper_session_changed');
  }

  Future<void> activate() => _serial(() async {
    _check();
    if (active) return;
    final installed = (await _run([
      'ime',
      'list',
      '-a',
      '-s',
    ])).stdout.toString();
    _check();
    if (!installed.split(RegExp(r'\s+')).contains(helper)) {
      throw StateError('helper_missing');
    }
    final original = (await _run([
      'settings',
      'get',
      'secure',
      'default_input_method',
    ])).stdout.toString().trim();
    _check();
    if (original == helper ||
        !RegExp(r'^[A-Za-z0-9_.]+/[A-Za-z0-9_.]+$').hasMatch(original)) {
      throw StateError('helper_original_unknown');
    }
    final enabled = (await _run([
      'settings',
      'get',
      'secure',
      'enabled_input_methods',
    ])).stdout.toString().trim();
    _check();
    _original = original;
    _wasEnabled = enabled
        .split(':')
        .any((entry) => entry.split(';').first == helper);
    try {
      if (!_wasEnabled) await _run(['ime', 'enable', helper]);
      _check();
      await _run(['ime', 'set', helper]);
      _check();
      final selected = (await _run([
        'settings',
        'get',
        'secure',
        'default_input_method',
      ])).stdout.toString().trim();
      _check();
      if (selected != helper) throw StateError('helper_command_failed');
      active = true;
    } catch (_) {
      await _restore();
      rethrow;
    }
  });
  Future<void> _broadcast(List<String> extras) async {
    _check();
    if (!active) throw StateError('helper_not_active');
    final selected = (await _run([
      'settings',
      'get',
      'secure',
      'default_input_method',
    ])).stdout.toString().trim();
    _check();
    if (selected != helper) throw StateError('helper_not_active');
    final result = await _run([
      'am',
      'broadcast',
      '-p',
      'com.android.adbkeyboard',
      ...extras,
    ]);
    // Delivery acknowledgement is not proof that an editor accepted the text.
    if (!RegExp(
      r'Broadcast completed: result=0\b',
    ).hasMatch(result.stdout.toString())) {
      throw StateError('helper_command_failed');
    }
  }

  Future<void> sendText(String text) => _serial(() async {
    final bytes = utf8.encode(text);
    if (bytes.isEmpty || bytes.length > 8192) {
      throw StateError('helper_text_limit');
    }
    await _broadcast([
      '-a',
      'ADB_INPUT_B64',
      '--es',
      'msg',
      base64Encode(bytes),
    ]);
  });
  Future<void> backspace() =>
      _serial(() => _broadcast(['-a', 'ADB_INPUT_CODE', '--ei', 'code', '67']));
  Future<void> editorAction(int action) => _serial(() async {
    if (action < 2 || action > 6) throw StateError('helper_command_failed');
    await _broadcast(['-a', 'ADB_EDITOR_CODE', '--ei', 'code', '$action']);
  });
  Future<void> close() {
    invalidate();
    return _serial(_restore);
  }

  Future<void> _restore() async {
    final original = _original;
    if (original == null) return;
    try {
      final current = (await _run([
        'settings',
        'get',
        'secure',
        'default_input_method',
      ])).stdout.toString().trim();
      // Preserve a keyboard explicitly selected outside this session.
      if (current == helper) {
        await _run(['ime', 'set', original]);
        final restored = (await _run([
          'settings',
          'get',
          'secure',
          'default_input_method',
        ])).stdout.toString().trim();
        if (restored != original) throw StateError('helper_restore_failed');
      }
      if (!_wasEnabled) await _run(['ime', 'disable', helper]);
      active = false;
      _original = null;
    } catch (_) {
      throw StateError('helper_restore_failed');
    }
  }
}
