import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ja_adb_tool/modules/services/apk_signer.dart';

void main() {
  test(
    'ignores cwd and parent JARs and never copies them next to executable',
    () {
      final root = Directory.systemTemp.createTempSync('ja-signer-trust-');
      final app = Directory('${root.path}/release')..createSync();
      Directory('${root.path}/bin').createSync();
      File(
        '${root.path}/bin/uber-apk-signer.jar',
      ).writeAsStringSync('untrusted');
      final previous = Directory.current;
      try {
        Directory.current = root;
        expect(
          ApkSigner.findTrustedUberSigner(
            executablePath: '${app.path}/app.exe',
          ),
          isNull,
        );
        expect(Directory('${app.path}/bin').existsSync(), isFalse);
      } finally {
        Directory.current = previous;
      }
    },
  );

  test(
    'accepts bundled JAR but explicit Build Tools directory takes precedence',
    () {
      final root = Directory.systemTemp.createTempSync('ja-signer-bundle-');
      Directory('${root.path}/bin').createSync();
      final jar = File('${root.path}/bin/uber-apk-signer.jar')
        ..writeAsStringSync('fixture');
      expect(
        ApkSigner.findTrustedUberSigner(executablePath: '${root.path}/app.exe'),
        jar.path.replaceAll('/', Platform.pathSeparator),
      );
      expect(
        ApkSigner.findTrustedUberSigner(
          executablePath: '${root.path}/app.exe',
          configuredTools: '${root.path}/build-tools',
        ),
        isNull,
      );
      expect(
        ApkSigner.findTrustedUberSigner(
          executablePath: '${root.path}/app.exe',
          configuredTools: jar.absolute.path,
        ),
        jar.absolute.path,
      );
      expect(
        () => ApkSigner.findTrustedUberSigner(
          executablePath: '${root.path}/app.exe',
          configuredTools: '${root.path}/missing.jar',
        ),
        throwsStateError,
      );
      expect(
        () => ApkSigner.findTrustedUberSigner(
          executablePath: '${root.path}/app.exe',
          configuredTools: 'relative.jar',
        ),
        throwsStateError,
      );
    },
  );
}
