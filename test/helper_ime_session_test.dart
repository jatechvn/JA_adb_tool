import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/helper_ime_session.dart';

class FakeImeAdb {
  String current = 'com.android.inputmethod.latin/.LatinIME';
  bool installed = true, enabled = false, failSet = false, failRestore = false;
  Completer<void>? gate;
  final queryStarted = Completer<void>();
  final calls = <List<String>>[];
  Future<ProcessResult> run(
    String exe,
    List<String> args, {
    Encoding? stdoutEncoding,
    Encoding? stderrEncoding,
  }) async {
    calls.add(List.of(args));
    if (args.contains('default_input_method')) {
      final pending = gate;
      if (pending != null) {
        if (!queryStarted.isCompleted) queryStarted.complete();
        await pending.future;
        gate = null;
      }
      return ProcessResult(1, 0, current, '');
    }
    if (args.contains('enabled_input_methods')) {
      return ProcessResult(
        1,
        0,
        enabled
            ? HelperImeSession.helper
            : 'com.android.inputmethod.latin/.LatinIME',
        '',
      );
    }
    if (args.contains('list')) {
      return ProcessResult(1, 0, installed ? HelperImeSession.helper : '', '');
    }
    if (args.contains('set')) {
      if ((args.last == HelperImeSession.helper && failSet) ||
          (args.last != HelperImeSession.helper && failRestore)) {
        return ProcessResult(1, 1, '', 'failed');
      }
      current = args.last;
    }
    if (args.contains('enable')) enabled = true;
    if (args.contains('disable')) enabled = false;
    return ProcessResult(
      1,
      0,
      args.contains('broadcast') ? 'Broadcast completed: result=0' : '',
      '',
    );
  }

  HelperImeSession session() =>
      HelperImeSession(adbPath: 'fake-adb', device: 'A', runner: run);
}

void main() {
  test(
    'UTF-8 transport, explicit keys, original IME restoration and device binding',
    () async {
      final adb = FakeImeAdb();
      final session = adb.session();
      await session.activate();
      const text = "Xin chào 😀 '\n; &";
      await session.sendText(text);
      final broadcast = adb.calls.firstWhere(
        (args) => args.contains('ADB_INPUT_B64'),
      );
      expect(utf8.decode(base64Decode(broadcast.last)), text);
      await session.backspace();
      await session.editorAction(3);
      expect(
        adb.calls.any(
          (args) => args.contains('ADB_INPUT_CODE') && args.last == '67',
        ),
        isTrue,
      );
      await session.close();
      expect(adb.current, 'com.android.inputmethod.latin/.LatinIME');
      expect(adb.enabled, isFalse);
      expect(session.active, isFalse);
      expect(
        adb.calls.every((args) => args[0] == '-s' && args[1] == 'A'),
        isTrue,
      );
    },
  );
  test('missing helper never changes IME', () async {
    final adb = FakeImeAdb()..installed = false;
    await expectLater(adb.session().activate(), throwsStateError);
    expect(
      adb.calls.any((args) => args.contains('set') || args.contains('enable')),
      isFalse,
    );
  });
  test('activation failure rolls back newly enabled helper', () async {
    final adb = FakeImeAdb()..failSet = true;
    await expectLater(adb.session().activate(), throwsStateError);
    expect(adb.enabled, isFalse);
    expect(adb.current, 'com.android.inputmethod.latin/.LatinIME');
  });
  test('restore failure retains snapshot for retry', () async {
    final adb = FakeImeAdb();
    final session = adb.session();
    await session.activate();
    adb.failRestore = true;
    await expectLater(session.close(), throwsStateError);
    expect(session.active, isTrue);
    adb.failRestore = false;
    await session.close();
    expect(adb.enabled, isFalse);
  });
  test('close invalidates pending send before it can broadcast', () async {
    final adb = FakeImeAdb();
    final session = adb.session();
    await session.activate();
    final gate = Completer<void>();
    adb.gate = gate;
    final send = session.sendText('old device text');
    final rejected = expectLater(send, throwsStateError);
    await adb.queryStarted.future;
    final close = session.close();
    gate.complete();
    await rejected;
    await close;
    expect(adb.calls.any((args) => args.contains('broadcast')), isFalse);
  });
  test(
    'preserves originally enabled helper and external IME selection',
    () async {
      final adb = FakeImeAdb()..enabled = true;
      final session = adb.session();
      await session.activate();
      adb.current = 'other.keyboard/.IME';
      await session.close();
      expect(adb.current, 'other.keyboard/.IME');
      expect(adb.enabled, isTrue);
    },
  );
  test('limits text bytes and does not retry failed sends', () async {
    final adb = FakeImeAdb();
    final session = adb.session();
    await session.activate();
    await expectLater(session.sendText(''), throwsStateError);
    await expectLater(session.sendText('😀' * 3000), throwsStateError);
    adb.current = 'other.keyboard/.IME';
    await expectLater(session.sendText('sample'), throwsStateError);
    expect(adb.calls.any((args) => args.contains('broadcast')), isFalse);
    await session.close();
  });
}
