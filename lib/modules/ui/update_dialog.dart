import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../constants.dart';
import '../logic.dart';
import '../services/update_service.dart';
import 'glass_dialog.dart';
import 'localization.dart';
import 'styles.dart';

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  late Future<UpdateInfo?> _future;

  @override
  void initState() {
    super.initState();
    _future = const UpdateService(
      repository: 'jatechvn/JA_adb_tool',
    ).checkLatest(currentVersion: appVersion);
  }

  void _retry() {
    setState(() {
      _future = const UpdateService(
        repository: 'jatechvn/JA_adb_tool',
      ).checkLatest(currentVersion: appVersion);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final logic = context.watch<AppLogic>();
    return GlassDialog(
      child: AlertDialog(
        backgroundColor: glassDialogBackground(
          theme: theme,
          opacity: logic.dialogOpacity,
        ),
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: Color(0xFF00ADB5)),
            const SizedBox(width: 10),
            Text(context.tr('update_title')),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: FutureBuilder<UpdateInfo?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(context.tr('update_checking')),
                  ],
                );
              }
              final info = snapshot.data;
              if (info == null) return Text(context.tr('update_unavailable'));
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.isNewer
                        ? context.tr(
                            'update_available',
                            args: {'version': info.version},
                          )
                        : context.tr(
                            'update_up_to_date',
                            args: {'version': appVersion},
                          ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (info.isNewer && info.releaseNotes.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      info.releaseNotes.trim(),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.textSecondary, height: 1.3),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: _retry, child: Text(context.tr('retry'))),
          FutureBuilder<UpdateInfo?>(
            future: _future,
            builder: (context, snapshot) {
              final url = snapshot.data?.releaseUrl;
              if (url == null || !snapshot.hasData) {
                return const SizedBox.shrink();
              }
              return FilledButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(context.tr('open_release')),
              );
            },
          ),
        ],
      ),
    );
  }
}
