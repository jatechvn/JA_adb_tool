import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/apk_signer.dart';
import 'glass_dialog.dart';
import 'localization.dart';

class ApkSigningSetupDialog extends StatefulWidget {
  const ApkSigningSetupDialog({super.key});
  @override
  State<ApkSigningSetupDialog> createState() => _ApkSigningSetupDialogState();
}

class _ApkSigningSetupDialogState extends State<ApkSigningSetupDialog> {
  final _java = TextEditingController();
  final _tools = TextEditingController();
  bool _busy = false;
  bool _ready = false;
  String? _details;

  @override
  void initState() {
    super.initState();
    try {
      final saved = ApkSigner.loadSettings();
      _java.text = saved['java'] ?? '';
      _tools.text = saved['buildTools'] ?? '';
    } catch (e) {
      _details = e.toString();
    }
  }

  @override
  void dispose() {
    _java.dispose();
    _tools.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final javaPath = _java.text;
    final toolsPath = _tools.text;
    setState(() {
      _busy = true;
      _ready = false;
      _details = null;
    });
    try {
      final signer = ApkSigner.discover(
        javaPath: javaPath,
        buildToolsPath: toolsPath,
      );
      await signer.checkTools();
      await signer.ensureDebugKeystore();
      await ApkSigner.saveSettings(javaPath, toolsPath);
      if (mounted) {
        setState(() {
          _ready = true;
          _details = '${signer.java}\n${signer.jar}\n${signer.keystore}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _details = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _browse(bool java) async {
    final String? path;
    if (java) {
      final result = await FilePicker.pickFiles();
      path = result?.files.single.path;
    } else {
      path = await FilePicker.getDirectoryPath();
    }
    if (!mounted || path == null) return;
    setState(() {
      (java ? _java : _tools).text = path!;
      _ready = false;
    });
  }

  @override
  Widget build(BuildContext context) => GlassDialog(
    title: context.tr('apk_signing_setup'),
    width: 620,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .65,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('apk_signing_help')),
            const SizedBox(height: 16),
            TextField(
              controller: _java,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: context.tr('apk_java_path'),
                hintText: context.tr('apk_auto_detect'),
                suffixIcon: IconButton(
                  tooltip: context.tr('apk_browse'),
                  onPressed: _busy ? null : () => _browse(true),
                  icon: const Icon(Icons.folder_open),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tools,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: context.tr('apk_build_tools_path'),
                hintText: context.tr('apk_auto_detect'),
                suffixIcon: IconButton(
                  tooltip: context.tr('apk_browse'),
                  onPressed: _busy ? null : () => _browse(false),
                  icon: const Icon(Icons.folder_open),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () async {
                    await launchUrl(
                      Uri.parse(
                        'https://developer.android.com/studio/intro/update#sdk-manager',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(context.tr('apk_sdk_guide')),
                ),
                TextButton(
                  onPressed: () async {
                    await launchUrl(
                      Uri.parse('https://adoptium.net/temurin/releases/'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(context.tr('apk_java_guide')),
                ),
              ],
            ),
            Text(context.tr('apk_key_help')),
            const SizedBox(height: 12),
            if (_details != null) ...[
              Text(
                context.tr(_ready ? 'apk_signing_ready' : 'apk_signing_failed'),
              ),
              SelectableText(_details!),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _prepare,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user),
              label: Text(context.tr('apk_signing_prepare')),
            ),
          ],
        ),
      ),
    ),
  );
}
