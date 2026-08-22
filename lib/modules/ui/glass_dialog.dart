import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic.dart';
import 'styles.dart';

/// The minimum blur used when a translucent dialog is enabled.
///
/// Without this floor, a low-opacity surface with zero blur lets the text and
/// controls behind the dialog show through and become unreadable.
const double glassDialogLegibilityBlur = 6.0;

double effectiveGlassDialogBlur({
  required double blur,
  required double opacity,
}) {
  final safeBlur = blur.clamp(0.0, 30.0).toDouble();
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

/// Applies the persisted dialog blur settings to any modal surface.
///
/// [blur] and [opacity] can be supplied by a settings preview so the dialog
/// updates live before values are committed to [AppLogic].
class GlassDialog extends StatelessWidget {
  final Widget child;
  final double? blur;
  final double? opacity;

  const GlassDialog({super.key, required this.child, this.blur, this.opacity});

  @override
  Widget build(BuildContext context) {
    final logic = context.watch<AppLogic>();
    final configuredBlur = blur ?? logic.dialogBlur;
    final configuredOpacity = opacity ?? logic.dialogOpacity;
    final effectiveBlur = effectiveGlassDialogBlur(
      blur: configuredBlur,
      opacity: configuredOpacity,
    );

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: effectiveBlur, sigmaY: effectiveBlur),
      child: child,
    );
  }
}
