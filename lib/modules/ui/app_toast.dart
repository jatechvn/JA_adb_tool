import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Shows a transient glass toast notification near the bottom of the screen.
/// Auto-dismisses after [duration]. Call from anywhere with a [BuildContext]
/// that has an [Overlay] ancestor (e.g. anywhere under a [Scaffold]/[MaterialApp]).
void showAppToast(
  BuildContext context, {
  required String message,
  required AppColors colors,
  IconData icon = Icons.check_circle_rounded,
  Color? accentColor,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  final accent = accentColor ?? colors.accentEmerald;

  entry = OverlayEntry(
    builder: (context) => _ToastWidget(
      message: message,
      icon: icon,
      colors: colors,
      accent: accent,
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({
    required this.message,
    required this.icon,
    required this.colors,
    required this.accent,
  });

  final String message;
  final IconData icon;
  final AppColors colors;
  final Color accent;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: c.subCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
