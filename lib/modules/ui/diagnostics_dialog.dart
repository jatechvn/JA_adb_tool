import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import '../services/diagnostics_service.dart';
import 'glass_dialog.dart';
import 'styles.dart';
import 'localization.dart';

class DiagnosticsDialog extends StatefulWidget {
  const DiagnosticsDialog({super.key});

  @override
  State<DiagnosticsDialog> createState() => _DiagnosticsDialogState();
}

class _DiagnosticsDialogState extends State<DiagnosticsDialog> {
  bool _running = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (!mounted) return;
    setState(() => _running = true);
    await context.read<AppLogic>().runDiagnostics();
    if (mounted) setState(() => _running = false);
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
            const Icon(
              Icons.health_and_safety_rounded,
              color: Color(0xFF00ADB5),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(context.tr('diagnostics_title'))),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 360,
          child: Builder(
            builder: (context) {
              final report = logic.diagnosticsReport;
              if (_running || report == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView.separated(
                itemCount: report.checks.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final check = report.checks[index];
                  final color = switch (check.status) {
                    DiagnosticStatus.pass => Colors.green,
                    DiagnosticStatus.warning => Colors.orange,
                    DiagnosticStatus.fail => Colors.red,
                  };
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      check.status == DiagnosticStatus.pass
                          ? Icons.check_circle_rounded
                          : check.status == DiagnosticStatus.warning
                          ? Icons.warning_rounded
                          : Icons.error_rounded,
                      color: color,
                    ),
                    title: Text(check.title),
                    subtitle: Text(check.details),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: logic.diagnosticsReport == null
                ? null
                : () {
                    Clipboard.setData(
                      ClipboardData(text: logic.diagnosticsReport!.plainText),
                    );
                  },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(context.tr('diagnostics_copy')),
          ),
          TextButton.icon(
            onPressed: _running ? null : _run,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(context.tr('diagnostics_run')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
        ],
      ),
    );
  }
}
