import 'dart:io';
import 'package:path/path.dart' as p;

typedef SigningProcessRunner =
    Future<ProcessResult> Function(String, List<String>);

/// Uses Android Build Tools, not JAR/v1-only signing. No shell interpolation.
class ApkSigner {
  final String java;
  final String jar;
  final String zipalign;
  final String keystore;
  final SigningProcessRunner run;

  ApkSigner({
    required this.java,
    required this.jar,
    required this.zipalign,
    required this.keystore,
    SigningProcessRunner? runner,
  }) : run = runner ?? ((exe, args) => Process.run(exe, args));

  static ApkSigner discover() {
    final env = Platform.environment;
    final sdkRoots = [
      env['ANDROID_SDK_ROOT'],
      env['ANDROID_HOME'],
      if (env['LOCALAPPDATA'] != null)
        p.join(env['LOCALAPPDATA']!, 'Android', 'Sdk'),
    ];
    final home = env['USERPROFILE'] ?? env['HOME'];
    if (home == null) throw StateError('User home unavailable.');
    final key = p.join(home, '.android', 'debug.keystore');
    if (!File(key).existsSync()) {
      throw StateError(
        'Missing debug.keystore. Create an Android debug keystore before cloning.',
      );
    }
    for (final root in sdkRoots.whereType<String>()) {
      final buildTools = Directory(p.join(root, 'build-tools'));
      if (!buildTools.existsSync()) continue;
      final versions = buildTools.listSync().whereType<Directory>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final version in versions) {
        final jar = p.join(version.path, 'lib', 'apksigner.jar');
        final align = p.join(
          version.path,
          Platform.isWindows ? 'zipalign.exe' : 'zipalign',
        );
        if (!File(jar).existsSync() || !File(align).existsSync()) continue;
        final javaHome = env['JAVA_HOME'];
        final java = javaHome == null
            ? 'java'
            : p.join(javaHome, 'bin', Platform.isWindows ? 'java.exe' : 'java');
        return ApkSigner(java: java, jar: jar, zipalign: align, keystore: key);
      }
    }
    throw StateError(
      'Android Build Tools (apksigner and zipalign) required. Set ANDROID_SDK_ROOT.',
    );
  }

  Future<void> signAndVerify(String unsigned, String signed) async {
    Future<ProcessResult> checked(String exe, List<String> args) async {
      final result = await run(exe, args);
      if (result.exitCode != 0) {
        throw StateError('APK signing tool failed: ${result.stderr}');
      }
      return result;
    }

    final aligned = '$unsigned.aligned.apk';
    await checked(zipalign, ['-P', '16', '4', unsigned, aligned]);
    await checked(java, [
      '-jar',
      jar,
      'sign',
      '--ks',
      keystore,
      '--ks-key-alias',
      'androiddebugkey',
      '--ks-pass',
      'pass:android',
      '--key-pass',
      'pass:android',
      '--v2-signing-enabled',
      'true',
      '--out',
      signed,
      aligned,
    ]);
    final verified = await checked(java, [
      '-jar',
      jar,
      'verify',
      '--verbose',
      signed,
    ]);
    if (!RegExp(
      r'Verified using v2 scheme[^\r\n]*:\s*true',
    ).hasMatch(verified.stdout.toString())) {
      throw StateError('APK verification did not confirm a v2 signature.');
    }
  }
}
