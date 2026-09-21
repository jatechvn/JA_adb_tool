import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants.dart';
import '../services/ota_update_service.dart';
import 'localization.dart';
import 'styles.dart';

/// Mở hộp thoại cập nhật Bento Frosted Glass
Future<void> showGlassUpdateDialog({
  required BuildContext context,
  required UpdatePackageInfo packageInfo,
}) {
  final theme = Provider.of<ThemeProvider>(context, listen: false);
  final isDark = theme.isDark;

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'GlassUpdateDialog',
    barrierColor: isDark
        ? Colors.black.withValues(alpha: 0.65)
        : Colors.black.withValues(alpha: 0.40),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) =>
        GlassUpdateDialog(packageInfo: packageInfo),
    transitionBuilder: (ctx, anim1, anim2, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.94,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    },
  );
}

/// Hộp thoại thông báo cập nhật Bento Frosted Glass
class GlassUpdateDialog extends StatefulWidget {
  final UpdatePackageInfo packageInfo;

  const GlassUpdateDialog({super.key, required this.packageInfo});

  @override
  State<GlassUpdateDialog> createState() => _GlassUpdateDialogState();
}

class _GlassUpdateDialogState extends State<GlassUpdateDialog> {
  bool _isUpdating = false;
  double _progress = 0.0;
  String _statusText = '';
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isUpdating = true;
      _errorMessage = null;
      _progress = 0.05;
      _statusText = context.tr('ota_updating');
    });

    try {
      await OtaUpdateService().performUpdate(
        widget.packageInfo,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _progress = prog;
              _statusText = status;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdating = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDark;
    final c = theme.colors;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (!_isUpdating &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            width: 520,
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: isDark ? 0.14 : 0.09,
                ),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: isDark ? 0.04 : 0.03),
                        border: Border(
                          bottom: BorderSide(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [c.accentBlue, c.accentCyan],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: c.accentBlue.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.system_update_alt_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('ota_update_title'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr(
                                    'ota_update_available',
                                    args: {
                                      'version': widget
                                          .packageInfo
                                          .version
                                          .displayVersion,
                                    },
                                  ),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: c.accentEmerald,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!_isUpdating)
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              tooltip: MaterialLocalizations.of(
                                context,
                              ).closeButtonTooltip,
                              splashRadius: 18,
                              color: isDark ? Colors.white70 : Colors.black54,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                        ],
                      ),
                    ),

                    // Body
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Version Comparison & Size Cards
                          Row(
                            children: [
                              // Current Version Badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(
                                              alpha: isDark ? 0.05 : 0.04,
                                            ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('ota_current_version'),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.black45,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'v$appVersion',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: c.accentBlue,
                              ),
                              const SizedBox(width: 8),
                              // New Version Badge
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: c.accentEmerald.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: c.accentEmerald.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('ota_latest_version'),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: c.accentEmerald,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            widget
                                                .packageInfo
                                                .version
                                                .displayVersion,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: c.accentEmerald,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 13,
                                            color: c.accentEmerald,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Metadata Pills (Size, Date, File)
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildMetadataPill(
                                icon: Icons.inventory_2_outlined,
                                label: widget.packageInfo.formattedSize,
                                isDark: isDark,
                                c: c,
                              ),
                              if (widget.packageInfo.releaseDate != null)
                                _buildMetadataPill(
                                  icon: Icons.calendar_today_outlined,
                                  label:
                                      '${widget.packageInfo.releaseDate!.year}-${widget.packageInfo.releaseDate!.month.toString().padLeft(2, '0')}-${widget.packageInfo.releaseDate!.day.toString().padLeft(2, '0')}',
                                  isDark: isDark,
                                  c: c,
                                ),
                              _buildMetadataPill(
                                icon: Icons.folder_zip_outlined,
                                label: widget.packageInfo.fileName,
                                isDark: isDark,
                                c: c,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Release Notes Section
                          Text(
                            context.tr('ota_release_notes'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 130,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  (isDark ? Colors.black : Colors.grey.shade100)
                                      .withValues(alpha: isDark ? 0.35 : 0.7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.08),
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                widget.packageInfo.releaseNotes ??
                                    context.tr(
                                      'ota_update_available',
                                      args: {
                                        'version': widget
                                            .packageInfo
                                            .version
                                            .displayVersion,
                                      },
                                    ),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.45,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),

                          // Error Banner
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: c.accentRose.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: c.accentRose.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: c.accentRose,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: c.accentRose,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Progress Bar when Updating
                          if (_isUpdating) ...[
                            const SizedBox(height: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _statusText,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: c.accentBlue,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${(_progress * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: c.accentBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: _progress,
                                    minHeight: 7,
                                    backgroundColor:
                                        (isDark ? Colors.white : Colors.black)
                                            .withValues(alpha: 0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      c.accentBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Actions Bar
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: isDark ? 0.02 : 0.02),
                        border: Border(
                          top: BorderSide(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!_isUpdating)
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                MaterialLocalizations.of(
                                  context,
                                ).cancelButtonLabel,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            key: const ValueKey('ota-apply-update-button'),
                            onPressed: _isUpdating ? null : _startUpdate,
                            icon: _isUpdating
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 16),
                            label: Text(
                              _isUpdating
                                  ? context.tr('ota_updating')
                                  : context.tr('ota_update_now'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: c.accentEmerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataPill({
    required IconData icon,
    required String label,
    required bool isDark,
    required dynamic c,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(
          alpha: isDark ? 0.06 : 0.05,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white70 : Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
