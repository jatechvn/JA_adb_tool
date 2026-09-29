import 'dart:io';
import 'dart:convert';
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
  final bool manageDebugKeystore;
  final bool isUberSigner;
  final String? keyAlias;
  final String? storePass;
  final String? keyPass;

  ApkSigner({
    required this.java,
    required this.jar,
    this.zipalign = '',
    required this.keystore,
    SigningProcessRunner? runner,
    this.manageDebugKeystore = false,
    this.isUberSigner = false,
    this.keyAlias,
    this.storePass,
    this.keyPass,
  }) : run = runner ?? ((exe, args) => Process.run(exe, args));

  static File get settingsFile {
    final env = Platform.environment;
    final root = env['APPDATA'] ?? env['USERPROFILE'] ?? env['HOME'];
    if (root == null) {
      throw StateError('User configuration directory unavailable.');
    }
    return File(p.join(root, 'JA ADB Tool', 'apk-signing.json'));
  }

  static Map<String, String> loadSettings() {
    if (!settingsFile.existsSync()) return {};
    final data =
        jsonDecode(settingsFile.readAsStringSync()) as Map<String, dynamic>;
    return {
      'java': data['java'] as String? ?? '',
      'buildTools': data['buildTools'] as String? ?? '',
    };
  }

  static Future<void> saveSettings(String java, String buildTools) async {
    final file = settingsFile;
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'java': java.trim(), 'buildTools': buildTools.trim()}),
      flush: true,
    );
  }

  static List<String> _findWindowsJdks(String javaName) {
    final results = <String>[];
    for (final base in [
      r'C:\Program Files\Java',
      r'C:\Program Files (x86)\Java',
      r'C:\Program Files\Android\Android Studio\jbr',
      r'C:\Program Files\Eclipse Adoptium',
      r'C:\Program Files\Semeru',
      r'C:\Program Files\Zulu',
      r'C:\Program Files\Microsoft',
      r'C:\Program Files\BellSoft',
      r'C:\Program Files\Amazon Corretto',
    ]) {
      final dir = Directory(base);
      if (dir.existsSync()) {
        try {
          final directExe = p.join(dir.path, 'bin', javaName);
          if (File(directExe).existsSync()) results.add(directExe);
          for (final sub in dir.listSync().whereType<Directory>()) {
            final exe = p.join(sub.path, 'bin', javaName);
            if (File(exe).existsSync()) results.add(exe);
            try {
              for (final sub2 in sub.listSync().whereType<Directory>()) {
                final exe2 = p.join(sub2.path, 'bin', javaName);
                if (File(exe2).existsSync()) results.add(exe2);
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
    }
    return results;
  }

  /// Only an explicit selection or the shipped executable's own bin is trusted.
  /// Never search cwd, ancestors, script location, or user-writable caches.
  static String? findTrustedUberSigner({
    required String executablePath,
    String configuredTools = '',
  }) {
    if (configuredTools.isNotEmpty) {
      if (!configuredTools.toLowerCase().endsWith('.jar')) return null;
      if (!p.isAbsolute(configuredTools) ||
          !File(configuredTools).existsSync()) {
        throw StateError(
          'Selected signer JAR is missing or not an absolute path.',
        );
      }
      return configuredTools;
    }
    final bundled = p.join(
      p.dirname(executablePath),
      'bin',
      'uber-apk-signer.jar',
    );
    return File(bundled).existsSync() ? bundled : null;
  }

  static ApkSigner discover({String? javaPath, String? buildToolsPath}) {
    final env = Platform.environment;
    final saved = javaPath != null && buildToolsPath != null
        ? <String, String>{}
        : loadSettings();
    final configuredJava = (javaPath ?? saved['java'] ?? '').trim();
    final configuredTools = (buildToolsPath ?? saved['buildTools'] ?? '')
        .trim();
    final sdkRoots = [
      env['ANDROID_SDK_ROOT'],
      env['ANDROID_HOME'],
      if (env['LOCALAPPDATA'] != null)
        p.join(env['LOCALAPPDATA']!, 'Android', 'Sdk'),
    ];
    final home = env['USERPROFILE'] ?? env['HOME'];
    if (home == null) throw StateError('User home unavailable.');
    final key = p.join(home, '.android', 'debug.keystore');
    final javaName = Platform.isWindows ? 'java.exe' : 'java';
    final candidates = <String>[
      if (configuredJava.isNotEmpty) configuredJava,
      if (configuredJava.isEmpty) ...[
        if (env['JAVA_HOME'] != null)
          p.join(env['JAVA_HOME']!, 'bin', javaName),
        if (Platform.isWindows) ...[
          r'C:\Program Files\Android\Android Studio\jbr\bin\java.exe',
          r'C:\Program Files\Java\jdk-17\bin\java.exe',
          r'C:\Program Files\Java\jdk-21\bin\java.exe',
          r'C:\Program Files\Java\jdk-11\bin\java.exe',
          ..._findWindowsJdks(javaName),
        ],
        for (final dir in (env['PATH'] ?? '').split(
          Platform.isWindows ? ';' : ':',
        ))
          if (dir.isNotEmpty) p.join(dir, javaName),
      ],
    ];
    final java = candidates
        .where((path) => File(path).existsSync())
        .firstOrNull;
    if (java == null) {
      throw StateError(
        'Java not found. Install a JDK or select its bin/java executable in Signing setup.',
      );
    }

    final uberJar = findTrustedUberSigner(
      executablePath: Platform.resolvedExecutable,
      configuredTools: configuredTools,
    );
    if (uberJar != null) {
      return ApkSigner(
        java: java,
        jar: uberJar,
        zipalign: '',
        keystore: key,
        manageDebugKeystore: false,
        isUberSigner: true,
      );
    }

    final versions = <Directory>[];
    if (configuredTools.isNotEmpty) versions.add(Directory(configuredTools));
    for (final root in sdkRoots.whereType<String>()) {
      if (configuredTools.isNotEmpty) break;
      final buildTools = Directory(p.join(root, 'build-tools'));
      if (!buildTools.existsSync()) continue;
      final found = buildTools.listSync().whereType<Directory>().toList()
        ..sort((a, b) {
          final aa = p.basename(a.path).split('.');
          final bb = p.basename(b.path).split('.');
          for (var i = 0; i < 3; i++) {
            final cmp = (int.tryParse(i < bb.length ? bb[i] : '0') ?? 0)
                .compareTo(int.tryParse(i < aa.length ? aa[i] : '0') ?? 0);
            if (cmp != 0) return cmp;
          }
          return b.path.compareTo(a.path);
        });
      versions.addAll(found);
    }
    for (final version in versions) {
      final jar = p.join(version.path, 'lib', 'apksigner.jar');
      final align = p.join(
        version.path,
        Platform.isWindows ? 'zipalign.exe' : 'zipalign',
      );
      if (!File(jar).existsSync() || !File(align).existsSync()) continue;
      return ApkSigner(
        java: java,
        jar: jar,
        zipalign: align,
        keystore: key,
        manageDebugKeystore: true,
      );
    }
    throw StateError(
      'Android Build Tools (apksigner and zipalign) required. Set ANDROID_SDK_ROOT or place uber-apk-signer.jar in bin/.',
    );
  }

  Future<ProcessResult> _checked(String exe, List<String> args) async {
    final result = await run(exe, args);
    if (result.exitCode != 0) {
      throw StateError(
        'Signing tool failed: ${result.stderr} ${result.stdout}',
      );
    }
    return result;
  }

  /// Checks actual executables before any APK is unpacked or a key is created.
  Future<void> checkTools() async {
    await _checked(java, ['-version']);
    if (isUberSigner) {
      await _checked(java, ['-jar', jar, '--version']);
      return;
    }
    await _checked(java, ['-jar', jar, 'version']);
    if (!File(zipalign).existsSync()) {
      throw StateError('zipalign not found: $zipalign');
    }
  }

  Future<void> ensureDebugKeystore() async {
    if (isUberSigner) return;
    final key = File(keystore);
    final keytool = p.join(
      p.dirname(java),
      Platform.isWindows ? 'keytool.exe' : 'keytool',
    );
    if (!File(keytool).existsSync()) {
      throw StateError(
        'keytool not found. Select Java from a JDK in Signing setup.',
      );
    }
    Future<void> validate(String path) => _checked(keytool, [
      '-list',
      '-keystore',
      path,
      '-storepass',
      'android',
      '-alias',
      'androiddebugkey',
    ]).then((_) {});
    if (await key.exists()) {
      await validate(keystore);
      return;
    }
    await key.parent.create(recursive: true);
    final stage = await Directory.systemTemp.createTemp('ja-debug-key-');
    final stagedKey = p.join(stage.path, 'debug.keystore');
    await _checked(keytool, [
      '-genkeypair',
      '-noprompt',
      '-keystore',
      stagedKey,
      '-storepass',
      'android',
      '-keypass',
      'android',
      '-alias',
      'androiddebugkey',
      '-keyalg',
      'RSA',
      '-keysize',
      '2048',
      '-validity',
      '10000',
      '-dname',
      'CN=Android Debug,O=Android,C=US',
    ]);
    await validate(stagedKey);
    // Exclusive creation prevents replacing a key created by another request.
    try {
      await key.create(exclusive: true);
    } on FileSystemException {
      if (!await key.exists()) rethrow;
      await validate(keystore);
      return;
    }
    await key.writeAsBytes(await File(stagedKey).readAsBytes(), flush: true);
    await validate(keystore);
  }

  Future<void> signAndVerify(String unsigned, String signed) async {
    if (manageDebugKeystore) {
      await checkTools();
      await ensureDebugKeystore();
    }
    Future<ProcessResult> checked(String exe, List<String> args) async {
      final result = await run(exe, args);
      if (result.exitCode != 0) {
        throw StateError(
          'APK signing tool failed: ${result.stderr} ${result.stdout}',
        );
      }
      return result;
    }

    if (isUberSigner) {
      final tempOutDir = await Directory.systemTemp.createTemp('ja_uber_sign_');
      try {
        final args = <String>[
          '-jar',
          jar,
          '-a',
          unsigned,
          '-o',
          tempOutDir.path,
          '--allowResign',
          if (keystore.isNotEmpty &&
              File(keystore).existsSync() &&
              !manageDebugKeystore) ...[
            '--ks',
            keystore,
            if (keyAlias != null && keyAlias!.isNotEmpty) ...[
              '--ksAlias',
              keyAlias!,
            ],
            if (storePass != null && storePass!.isNotEmpty) ...[
              '--ksPass',
              storePass!,
            ],
            if (keyPass != null && keyPass!.isNotEmpty) ...[
              '--ksKeyPass',
              keyPass!,
            ],
          ],
        ];
        final result = await checked(java, args);
        final apks = tempOutDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.apk'))
            .toList();
        if (apks.isEmpty) {
          throw StateError(
            'uber-apk-signer completed but no output APK was found in ${tempOutDir.path}.\nOutput: ${result.stdout}',
          );
        }
        await apks.first.copy(signed);
      } finally {
        try {
          await tempOutDir.delete(recursive: true);
        } catch (_) {}
      }
      return;
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
