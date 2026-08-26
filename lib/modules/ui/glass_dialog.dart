// lib/modules/ui/glass_dialog.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic.dart';
import 'styles.dart';

/// The minimum blur used when a translucent dialog is enabled.
const double glassDialogLegibilityBlur = 6.0;

double effectiveGlassDialogBlur({
  required double blur,
  required double opacity,
}) {
  final safeBlur = blur.clamp(0.0, 40.0).toDouble();
  return opacity < 1.0 && safeBlur < glassDialogLegibilityBlur
      ? glassDialogLegibilityBlur
      : safeBlur;
}

Color glassDialogBackground({
  required ThemeProvider theme,
  required double opacity,
}) {
  return theme.cardBg.withValues(alpha: opacity.clamp(0.3, 1.0).toDouble());
}

/// Frosted Glass Dialog supporting both simple Backdrop wrapper mode
/// and full-featured Bento Modal Dialog mode with header, close button, and actions.
class GlassDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final double width;
  final double? height;
  final bool? isDark;
  final double? blur;
  final double? opacity;
  final double? blurSigma;
  final double? bgOpacity;
  final IconData? icon;
  final Widget? headerTrailing;
  final List<Widget>? actions;

  const GlassDialog({
    super.key,
    required this.child,
    this.title,
    this.width = 620,
    this.height,
    this.isDark,
    this.blur,
    this.opacity,
    this.blurSigma,
    this.bgOpacity,
    this.icon,
    this.headerTrailing,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final logic = context.watch<AppLogic>();
    final c = theme.colors;

    final effectiveIsDark = isDark ?? theme.isDark;
    final configuredBlur = blurSigma ?? blur ?? logic.dialogBlur;
    final configuredOpacity = bgOpacity ?? opacity ?? logic.dialogOpacity;

    final effectiveBlur = effectiveGlassDialogBlur(
      blur: configuredBlur,
      opacity: configuredOpacity,
    );

    // If title is not provided, act as simple BackdropFilter wrapper for existing custom Dialogs
    if (title == null) {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: effectiveBlur,
          sigmaY: effectiveBlur,
        ),
        child: child,
      );
    }

    final enableTransparency = Platform.isWindows;
    final bg = enableTransparency
        ? (effectiveIsDark
              ? const Color(0xFF0F172A).withValues(
                  alpha: configuredOpacity.clamp(0.3, 1.0).toDouble(),
                )
              : const Color(0xFFFFFFFF).withValues(
                  alpha: configuredOpacity.clamp(0.3, 1.0).toDouble(),
                ))
        : (effectiveIsDark ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF));

    final border = c.borderDefault;

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: effectiveIsDark ? 0.45 : 0.15,
                  ),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border(
                top: BorderSide(color: c.glassHighlight, width: 1),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Column(
                mainAxisSize: height == null
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                children: [
                  // Modal Title Header with Close Button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: c.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 18, color: c.accentColor),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const Spacer(),
                        if (headerTrailing != null) ...[
                          headerTrailing!,
                          const SizedBox(width: 10),
                        ],
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: c.subCardBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.subCardBorder),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: c.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: c.borderDefault, height: 1),
                  if (height != null) Expanded(child: child) else child,
                  if (actions != null && actions!.isNotEmpty) ...[
                    Divider(color: c.borderDefault, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
