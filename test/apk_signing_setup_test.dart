import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/apk_signer.dart';

void main() {
  for (final scenario in ['existing', 'missing', 'failure', 'invalid']) {
    test('debug keystore setup: $scenario', () async {
      final dir = Directory.systemTemp.createTempSync('ja-key-test-');
      final key = File('${dir.path}/debug.keystore');
      if (scenario == 'existing' || scenario == 'invalid') {
        key.writeAsStringSync('original-key');
      }
      File(
        '${dir.path}/${Platform.isWindows ? 'keytool.exe' : 'keytool'}',
      ).writeAsStringSync('stub');
      final calls = <List<String>>[];
      final signer = ApkSigner(
        java: '${dir.path}/java.exe',
        jar: 'unused',
        zipalign: 'unused',
        keystore: key.path,
        runner: (_, args) async {
          calls.add(args);
          if (scenario == 'failure' || scenario == 'invalid') {
            return ProcessResult(0, 1, '', 'simulated failure');
          }
          if (args.contains('-genkeypair')) {
            File(
              args[args.indexOf('-keystore') + 1],
            ).writeAsStringSync('new-key');
          }
          return ProcessResult(0, 0, '', '');
        },
      );
      if (scenario == 'failure' || scenario == 'invalid') {
        await expectLater(signer.ensureDebugKeystore(), throwsStateError);
        expect(key.existsSync(), scenario == 'invalid');
      } else {
        await signer.ensureDebugKeystore();
        expect(
          key.readAsStringSync(),
          scenario == 'existing' ? 'original-key' : 'new-key',
        );
        expect(
          calls.where((c) => c.contains('-genkeypair')).length,
          scenario == 'existing' ? 0 : 1,
        );
      }
      if (scenario == 'invalid') expect(key.readAsStringSync(), 'original-key');
    });
  }
}
