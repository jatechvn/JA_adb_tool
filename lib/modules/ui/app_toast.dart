import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_colors.dart';
import 'styles.dart';

OverlayEntry? _activeToastEntry;

/// Shows a transient glass toast notification near the bottom of the screen.
/// Auto-dismisses after [duration]. Call from anywhere with a [BuildContext]
/// that has an [Overlay] ancestor (e.g. anywhere under a [Scaffold]/[MaterialApp]).
void showAppToast(
  BuildContext context, {
  required String message,
  required AppColors colors,
  IconData icon = Icons.check_circle_rounded,
  Color? accentColor,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  // Dismiss previous toast if still active
  _activeToastEntry?.remove();
  _activeToastEntry = null;

  late OverlayEntry entry;
  final accent = accentColor ?? colors.accentEmerald;

  void dismiss() {
    if (entry.mounted) {
      entry.remove();
      if (_activeToastEntry == entry) {
        _activeToastEntry = null;
      }
    }
  }

  entry = OverlayEntry(
    builder: (context) => AppToastWidget(
      message: message,
      icon: icon,
      colors: colors,
      accent: accent,
      actionLabel: actionLabel,
      onAction: onAction,
      onDismiss: dismiss,
    ),
  );

  _activeToastEntry = entry;
  overlay.insert(entry);

  Future.delayed(duration, () {
    dismiss();
  });
}

class AppToastWidget extends StatefulWidget {
  const AppToastWidget({
    super.key,
    required this.message,
    required this.icon,
    required this.colors,
    required this.accent,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  final String message;
  final IconData icon;
  final AppColors colors;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  State<AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<AppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Positioned(
      bottom: 32,
      left: 0,
      right: 0,
      child: Center(
        child: FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.3), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: c.dropdownBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: widget.accent, size: 18),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (widget.actionLabel != null &&
                            widget.onAction != null) ...[
                          const SizedBox(width: 14),
                          InkWell(
                            onTap: () {
                              widget.onDismiss();
                              widget.onAction!();
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: widget.accent.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: widget.accent.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: TextStyle(
                                  color: widget.accent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension AppToastExtension on BuildContext {
  void showAppToastNotification(
    String message, {
    IconData icon = Icons.check_circle_rounded,
    Color? accentColor,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Provider.of<ThemeProvider>(this, listen: false);
    showAppToast(
      this,
      message: message,
      colors: theme.colors,
      icon: icon,
      accentColor: accentColor,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  void showSuccessToast(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Provider.of<ThemeProvider>(this, listen: false);
    showAppToast(
      this,
      message: message,
      colors: theme.colors,
      icon: Icons.check_circle_rounded,
      accentColor: theme.colors.accentEmerald,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  void showErrorToast(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final theme = Provider.of<ThemeProvider>(this, listen: false);
    showAppToast(
      this,
      message: message,
      colors: theme.colors,
      icon: Icons.error_outline_rounded,
      accentColor: theme.colors.accentRose,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  void showInfoToast(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 3),
  }) {
    final theme = Provider.of<ThemeProvider>(this, listen: false);
    showAppToast(
      this,
      message: message,
      colors: theme.colors,
      icon: Icons.info_outline_rounded,
      accentColor: theme.colors.accentCyan,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }
}
