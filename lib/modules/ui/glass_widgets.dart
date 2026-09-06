import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'app_colors.dart';

/// A single blurred, slowly-drifting circle used by [MeshBackground].
class MeshOrb extends StatefulWidget {
  const MeshOrb({
    super.key,
    required this.color,
    required this.size,
    required this.duration,
    required this.travel,
  });

  final Color color;
  final double size;
  final Duration duration;
  final Offset travel;

  @override
  State<MeshOrb> createState() => _MeshOrbState();
}

class _MeshOrbState extends State<MeshOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        switch (state) {
          case AppLifecycleState.hidden:
          case AppLifecycleState.paused:
            _controller.stop();
          case AppLifecycleState.resumed:
            _controller.repeat(reverse: true);
          case AppLifecycleState.inactive:
          case AppLifecycleState.detached:
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary gives this continuously-drifting orb its own
    // compositor layer, so the 85px blur isn't recomputed as part of
    // whatever sits above it in the tree.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeInOutSine.transform(_controller.value);
          return Transform.translate(
            offset: Offset(widget.travel.dx * t, widget.travel.dy * t),
            child: child,
          );
        },
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Ambient mesh background: 3 drifting [MeshOrb]s behind the app content.
class MeshBackground extends StatelessWidget {
  const MeshBackground({super.key, required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -160,
          left: -160,
          child: MeshOrb(
            color: colors.orb1.withValues(alpha: colors.orbOpacity),
            size: 480,
            duration: const Duration(seconds: 16),
            travel: const Offset(60, 70),
          ),
        ),
        Positioned(
          bottom: -140,
          right: -120,
          child: MeshOrb(
            color: colors.orb2.withValues(alpha: colors.orbOpacity),
            size: 440,
            duration: const Duration(seconds: 18),
            travel: const Offset(-60, -60),
          ),
        ),
        Positioned(
          top: 180,
          right: 120,
          child: MeshOrb(
            color: colors.orb3.withValues(alpha: colors.orbOpacity),
            size: 340,
            duration: const Duration(seconds: 20),
            travel: const Offset(-40, 45),
          ),
        ),
      ],
    );
  }
}

/// Reusable frosted-glass surface: blurred backdrop + soft outer shadow +
/// a faint top-edge highlight line standing in for a native inset shadow.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.colors,
    required this.child,
    this.blurSigma = 24,
    this.borderRadius = 16,
    this.padding,
    this.borderColor,
    this.backgroundColor,
  });

  final AppColors colors;
  final Widget child;
  final double blurSigma;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      // RepaintBoundary isolates the BackdropFilter into its own compositor layer.
      child: RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? colors.glassBg,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor ?? colors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border(
                top: BorderSide(color: colors.glassHighlight, width: 1),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small rounded-pill badge, optionally with a glowing status dot.
class PillBadge extends StatelessWidget {
  const PillBadge({
    super.key,
    required this.label,
    required this.color,
    required this.bg,
    required this.border,
    this.showDot = false,
    this.icon,
    this.fontSize = 11,
    this.padding,
  });

  final String label;
  final Color color;
  final Color bg;
  final Color border;
  final bool showDot;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [BoxShadow(color: color, blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            Icon(icon, size: fontSize, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted Bento Grid Card with highlight top-border and soft glow on hover.
class BentoCard extends StatelessWidget {
  final AppColors colors;
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blurSigma;
  final VoidCallback? onTap;
  final bool isFeatured;
  final Color? customBg;
  final Color? customBorder;
  final double? bgOpacity;

  const BentoCard({
    super.key,
    required this.colors,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(20),
    this.blurSigma = 20,
    this.onTap,
    this.isFeatured = false,
    this.customBg,
    this.customBorder,
    this.bgOpacity,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBg =
        customBg ??
        (bgOpacity != null
            ? colors.cardBg.withValues(alpha: bgOpacity!)
            : colors.cardBg);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              hoverColor: colors.cardHoverBg.withValues(alpha: 0.15),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: effectiveBg,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color:
                        customBorder ??
                        (isFeatured
                            ? colors.accentColor.withValues(alpha: 0.4)
                            : colors.borderDefault),
                    width: isFeatured ? 1.2 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    if (isFeatured)
                      BoxShadow(
                        color: colors.primaryGlow.withValues(alpha: 0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                  ],
                ),
                foregroundDecoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border(
                    top: BorderSide(
                      color: isFeatured
                          ? colors.accentCyan.withValues(alpha: 0.6)
                          : colors.glassHighlight,
                      width: 1,
                    ),
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated 3-bar sound wave / equalizer indicator for active status.
class WaveIndicator extends StatefulWidget {
  final Color color;
  final double height;
  const WaveIndicator({super.key, required this.color, this.height = 14});

  @override
  State<WaveIndicator> createState() => _WaveIndicatorState();
}

class _WaveIndicatorState extends State<WaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        switch (state) {
          case AppLifecycleState.hidden:
          case AppLifecycleState.paused:
            _controller.stop();
          case AppLifecycleState.resumed:
            _controller.repeat(reverse: true);
          case AppLifecycleState.inactive:
          case AppLifecycleState.detached:
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        final h1 = (widget.height * (0.3 + 0.7 * val))
            .clamp(3.0, widget.height)
            .toDouble();
        final h2 = (widget.height * (0.9 - 0.6 * val))
            .clamp(3.0, widget.height)
            .toDouble();
        final h3 = (widget.height * (0.4 + 0.5 * (1 - val)))
            .clamp(3.0, widget.height)
            .toDouble();

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildBar(h1),
            const SizedBox(width: 2),
            _buildBar(h2),
            const SizedBox(width: 2),
            _buildBar(h3),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

/// Dynamic Island Status Capsule for the top header with Asymmetric Marquee text.
class DynamicIslandCapsule extends StatelessWidget {
  final AppColors colors;
  final bool isRunning;
  final String statusText;
  final String? subText;
  final VoidCallback? onTap;
  final Color? customColor;

  const DynamicIslandCapsule({
    super.key,
    required this.colors,
    required this.isRunning,
    required this.statusText,
    this.subText,
    this.onTap,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = customColor ?? colors.accentEmerald;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colors.subCardBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isRunning
                  ? activeColor.withValues(alpha: 0.45)
                  : colors.subCardBorder,
            ),
            boxShadow: [
              if (isRunning)
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isRunning) ...[
                WaveIndicator(color: activeColor, height: 12),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activeColor,
                    boxShadow: [BoxShadow(color: activeColor, blurRadius: 6)],
                  ),
                ),
              ] else ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.textMuted,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: AsymmetricMarqueeText(
                  text: statusText,
                  style: TextStyle(
                    color: isRunning ? activeColor : colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'JetBrains Mono',
                    letterSpacing: 0.35,
                  ),
                ),
              ),
              if (subText != null && subText!.isNotEmpty) ...[
                const SizedBox(width: 5),
                Container(
                  constraints: const BoxConstraints(maxWidth: 90),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: colors.subCardBorder.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: AsymmetricMarqueeText(
                    text: subText!,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Intelligent Adaptive Sliding Magnetic Pill Tab Bar.
/// - Responsive Space Adaptation:
///   * Wide / Spacious: displays full icons and labels for all tabs.
///   * Medium / Standard: intelligently switches to sleek Text-Only mode to fit all tabs (e.g. Vietnamese titles) without hiding or cutting off.
///   * Compact / Narrow: collapses unselected tabs to icons (accordion mode) with smooth hover expand preview.
/// - Tactile Bounce Hint Nudge: mirrors sample_components_motion elastic bounce on load, overflow, or language change so users instantly know more tabs exist.
/// - Windows Desktop Mouse-Wheel Scrolling: seamless horizontal scrolling with mouse wheel.
/// - Glass Navigation Chevrons: subtle interactive glowing arrow buttons that appear when scrolled/overflowed.
/// - Active Tab Auto-Scroll: automatically ensures the selected tab glides into view.
class SlidingPillTabBar extends StatefulWidget {
  final AppColors colors;
  final int currentIndex;
  final List<String> tabs;
  final List<IconData> icons;
  final ValueChanged<int> onTabSelected;
  final bool adaptiveCollapse;
  final bool enableBounceHint;
  final bool enableChevrons;

  const SlidingPillTabBar({
    super.key,
    required this.colors,
    required this.currentIndex,
    required this.tabs,
    required this.icons,
    required this.onTabSelected,
    this.adaptiveCollapse = true,
    this.enableBounceHint = true,
    this.enableChevrons = true,
  });

  @override
  State<SlidingPillTabBar> createState() => _SlidingPillTabBarState();
}

class _SlidingPillTabBarState extends State<SlidingPillTabBar> {
  int? _hoveredIndex;
  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _tabKeys;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  bool _hasTriggeredInitialBounce = false;
  Timer? _bounceTimer;

  @override
  void initState() {
    super.initState();
    _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollIndicators();
      _scrollToIndex(widget.currentIndex, animate: false);
      if (widget.enableBounceHint) {
        _checkAndTriggerBounce();
      }
    });
  }

  @override
  void didUpdateWidget(covariant SlidingPillTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      _tabKeys = List.generate(widget.tabs.length, (_) => GlobalKey());
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToIndex(widget.currentIndex);
      });
    }
    // Re-trigger bounce hint if tab titles changed (e.g. switching between EN and VI)
    if (oldWidget.tabs.join('|') != widget.tabs.join('|')) {
      _hasTriggeredInitialBounce = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateScrollIndicators();
        if (widget.enableBounceHint) {
          _checkAndTriggerBounce();
        }
      });
    }
  }

  @override
  void dispose() {
    _bounceTimer?.cancel();
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final canLeft = offset > 4.0;
    final canRight = offset < maxScroll - 4.0;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    if (index < 0 || index >= _tabKeys.length) return;
    final keyContext = _tabKeys[index].currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
        curve: Curves.easeOutCubic,
        alignment: 0.5,
      );
    }
  }

  void _checkAndTriggerBounce() {
    if (_hasTriggeredInitialBounce) return;
    _bounceTimer?.cancel();
    _bounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted || !_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 6.0) {
        _hasTriggeredInitialBounce = true;
        _triggerBounceHint();
      }
    });
  }

  /// Tactile Bounce Top / Right Nudge hint animation (mirrors sample_components_motion pattern)
  void _triggerBounceHint() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final startOffset = _scrollController.offset;
    final peekOffset = math.min(startOffset + 38.0, maxScroll);
    if (peekOffset <= startOffset) return;

    _scrollController
        .animateTo(
          peekOffset,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            startOffset,
            duration: const Duration(milliseconds: 480),
            curve: Curves.elasticOut,
          );
        });
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildNavArrow({required bool isLeft}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () => _scrollBy(isLeft ? -130.0 : 130.0),
        child: Container(
          width: 22,
          height: 26,
          decoration: BoxDecoration(
            color: widget.colors.accentColor.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: widget.colors.accentColor.withValues(alpha: 0.50),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.accentColor.withValues(alpha: 0.18),
                blurRadius: 6,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 15,
            color: widget.colors.accentColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth;
        final tabCount = widget.tabs.length;

        // Smart space calculations:
        // Full width (Icon + Text): ~134px per tab + container padding
        final fullWidthNeeded = tabCount * 134.0 + 24.0;
        // Text-only width (No icon): ~92px per tab + container padding
        final textOnlyWidthNeeded = tabCount * 92.0 + 24.0;

        final bool canFitFull = availableWidth >= fullWidthNeeded;
        final bool canFitTextOnly = availableWidth >= textOnlyWidthNeeded;

        // When space is medium (e.g. 640px to 940px): omit icons so all Vietnamese tab labels fit without cutting off.
        // When space is narrow (< 640px): unselected tabs collapse to icons (accordion dock).
        final bool showIcon =
            canFitFull || (!canFitTextOnly && widget.adaptiveCollapse);
        final bool shouldCollapse =
            widget.adaptiveCollapse && !canFitFull && !canFitTextOnly;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _updateScrollIndicators();
            if (widget.enableBounceHint) {
              _checkAndTriggerBounce();
            }
          }
        });

        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: widget.colors.subCardBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: widget.colors.subCardBorder),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent &&
                      _scrollController.hasClients) {
                    final double delta = pointerSignal.scrollDelta.dy != 0
                        ? pointerSignal.scrollDelta.dy
                        : pointerSignal.scrollDelta.dx;
                    final newOffset = (_scrollController.offset + delta).clamp(
                      0.0,
                      _scrollController.position.maxScrollExtent,
                    );
                    _scrollController.jumpTo(newOffset);
                  }
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.tabs.length, (index) {
                      final isSelected = widget.currentIndex == index;
                      final isHovered = _hoveredIndex == index;
                      final showLabel =
                          isSelected || isHovered || !shouldCollapse;

                      final decoration = isSelected
                          ? BoxDecoration(
                              color: widget.colors.accentColor,
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: widget.colors.accentColor.withValues(
                                  alpha: 0.45,
                                ),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.colors.accentColor.withValues(
                                    alpha: 0.20,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            )
                          : (isHovered
                                ? BoxDecoration(
                                    color: widget.colors.cardHoverBg.withValues(
                                      alpha: 0.35,
                                    ),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: widget.colors.accentColor
                                          .withValues(alpha: 0.45),
                                      width: 1.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.colors.accentColor
                                            .withValues(alpha: 0.16),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                      BoxShadow(
                                        color: widget.colors.glassHighlight
                                            .withValues(alpha: 0.30),
                                        blurRadius: 4,
                                        offset: const Offset(0, -1),
                                      ),
                                    ],
                                  )
                                : const BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(100),
                                    ),
                                  ));

                      // Specular Mirror Top Reflection Line
                      final foregroundDeco = isSelected
                          ? BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.2,
                                ),
                              ),
                            )
                          : (isHovered
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border(
                                      top: BorderSide(
                                        color: widget.colors.glassHighlight
                                            .withValues(alpha: 0.95),
                                        width: 1.2,
                                      ),
                                    ),
                                  )
                                : null);

                      return MouseRegion(
                        key: _tabKeys[index],
                        onEnter: (_) => setState(() => _hoveredIndex = index),
                        onExit: (_) => setState(() => _hoveredIndex = null),
                        child: Tooltip(
                          message: widget.tabs[index],
                          waitDuration: const Duration(milliseconds: 600),
                          child: GestureDetector(
                            onTap: () {
                              _scrollToIndex(index);
                              widget.onTabSelected(index);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.symmetric(
                                horizontal: showLabel ? 11.5 : 9.0,
                                vertical: 5.5,
                              ),
                              decoration: decoration,
                              foregroundDecoration: foregroundDeco,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showIcon) ...[
                                    Icon(
                                      widget.icons[index],
                                      size: 14.0,
                                      color: isSelected
                                          ? Colors.white
                                          : (isHovered
                                                ? widget.colors.textPrimary
                                                : widget.colors.textSecondary),
                                    ),
                                    if (showLabel) const SizedBox(width: 5.0),
                                  ],
                                  if (showLabel) ...[
                                    ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: canFitFull ? 142 : 122,
                                      ),
                                      child: isSelected
                                          ? AsymmetricMarqueeText(
                                              text: widget.tabs[index],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.2,
                                              ),
                                            )
                                          : Text(
                                              widget.tabs[index],
                                              style: TextStyle(
                                                color: isHovered
                                                    ? widget.colors.textPrimary
                                                    : widget
                                                          .colors
                                                          .textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              // Left fade gradient and navigation chevron
              if (_canScrollLeft) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(100),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            widget.colors.subCardBg,
                            widget.colors.subCardBg.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.enableChevrons)
                  Positioned(left: 2, child: _buildNavArrow(isLeft: true)),
              ],
              // Right fade gradient and navigation chevron
              if (_canScrollRight) ...[
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 24,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(100),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            widget.colors.subCardBg,
                            widget.colors.subCardBg.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.enableChevrons)
                  Positioned(right: 2, child: _buildNavArrow(isLeft: false)),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Asymmetric Ping-Pong Marquee Text widget:
/// - Only scrolls if text overflows the container constraints.
/// - Hold at start for [pauseStart] (e.g. 1400ms).
/// - Smoothly scrolls forward to the end.
/// - Hold at end for [pauseEnd] (e.g. 1400ms).
/// - Smoothly scrolls back to start.
/// - Zero performance overhead when text fits within bounds.
class AsymmetricMarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration pauseStart;
  final Duration pauseEnd;
  final double velocity; // px/sec
  final Curve forwardCurve;
  final Curve returnCurve;

  const AsymmetricMarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseStart = const Duration(milliseconds: 1400),
    this.pauseEnd = const Duration(milliseconds: 1400),
    this.velocity = 35.0,
    this.forwardCurve = Curves.easeInOutCubic,
    this.returnCurve = Curves.easeInOutCubic,
  });

  @override
  State<AsymmetricMarqueeText> createState() => _AsymmetricMarqueeTextState();
}

class _AsymmetricMarqueeTextState extends State<AsymmetricMarqueeText> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _scheduleStart();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AsymmetricMarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _timer?.cancel();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed && mounted) {
          _scheduleStart();
        }
      });
    }
  }

  void _scheduleStart() {
    _timer?.cancel();
    if (_isDisposed || !mounted) return;
    if (!_scrollController.hasClients) {
      _timer = Timer(const Duration(milliseconds: 150), _scheduleStart);
      return;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _timer = Timer(widget.pauseStart, _animateForward);
  }

  void _animateForward() {
    _timer?.cancel();
    if (_isDisposed || !mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final duration = Duration(
      milliseconds: ((maxScroll / widget.velocity) * 1000)
          .round()
          .clamp(600, 6000)
          .toInt(),
    );

    _scrollController
        .animateTo(maxScroll, duration: duration, curve: widget.forwardCurve)
        .then((_) {
          if (_isDisposed || !mounted) return;
          _timer = Timer(widget.pauseEnd, _animateReturn);
        });
  }

  void _animateReturn() {
    _timer?.cancel();
    if (_isDisposed || !mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final duration = Duration(
      milliseconds: ((maxScroll / (widget.velocity * 1.25)) * 1000)
          .round()
          .clamp(500, 5000)
          .toInt(),
    );

    _scrollController
        .animateTo(0, duration: duration, curve: widget.returnCurve)
        .then((_) {
          if (_isDisposed || !mounted) return;
          _timer = Timer(widget.pauseStart, _animateForward);
        });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}

/// High-tech glowing action button with vibrant gradients and tactile feedback.
class GlowingActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final AppColors colors;
  final double height;
  final Color? customStartColor;
  final Color? customEndColor;

  const GlowingActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    required this.colors,
    this.height = 40,
    this.customStartColor,
    this.customEndColor,
  });

  @override
  Widget build(BuildContext context) {
    final start =
        customStartColor ??
        (isDestructive ? const Color(0xFFF43F5E) : colors.accentColor);
    final end =
        customEndColor ??
        (isDestructive ? const Color(0xFFE11D48) : colors.accentCyan);

    final gradient = LinearGradient(
      colors: [start, end],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final glowColor = isDestructive
        ? const Color(0x66F43F5E)
        : (customStartColor != null
              ? customStartColor!.withValues(alpha: 0.35)
              : colors.primaryGlow);

    final isDisabled = onPressed == null;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ).copyWith(elevation: WidgetStateProperty.all(0)),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isDisabled
                ? LinearGradient(colors: [colors.subCardBg, colors.subCardBg])
                : gradient,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled
                  ? colors.subCardBorder
                  : Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isDisabled ? colors.textMuted : Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: isDisabled ? colors.textMuted : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small keyboard-shortcut badge (e.g. "Ctrl+K", "ESC").
class KbdTag extends StatelessWidget {
  const KbdTag({super.key, required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: colors.subCardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.subCardBorder),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 10,
          fontFamily: 'JetBrains Mono',
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Animated gradient border sweep — wrap any child (typically a [BentoCard])
/// to add a rotating, glowing accent border marking it "live"/"featured"/
/// "selected".
class BorderBeam extends StatefulWidget {
  const BorderBeam({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.colors = const [
      Color(0xFF00D2FF),
      Color(0xFF00ADB5),
      Color(0xFFA855F7),
    ],
    this.strokeWidth = 1.5,
    this.duration = const Duration(seconds: 5),
  });

  final Widget child;
  final double borderRadius;
  final List<Color> colors;
  final double strokeWidth;
  final Duration duration;

  @override
  State<BorderBeam> createState() => _BorderBeamState();
}

class _BorderBeamState extends State<BorderBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        switch (state) {
          case AppLifecycleState.hidden:
          case AppLifecycleState.paused:
            _controller.stop();
          case AppLifecycleState.resumed:
            _controller.repeat();
          case AppLifecycleState.inactive:
          case AppLifecycleState.detached:
            break;
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same isolation as MeshOrb: this beam repaints every frame while it's
    // visible, so give it its own layer instead of dragging the card
    // content along for each repaint.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            foregroundPainter: _BorderBeamPainter(
              progress: _controller.value,
              borderRadius: widget.borderRadius,
              colors: widget.colors,
              strokeWidth: widget.strokeWidth,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _BorderBeamPainter extends CustomPainter {
  _BorderBeamPainter({
    required this.progress,
    required this.borderRadius,
    required this.colors,
    required this.strokeWidth,
  });

  final double progress;
  final double borderRadius;
  final List<Color> colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty ||
        !strokeWidth.isFinite ||
        strokeWidth <= 0 ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }

    final safeStrokeWidth = math.min(
      strokeWidth,
      math.min(size.width, size.height),
    );
    if (safeStrokeWidth <= 0) return;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        safeStrokeWidth / 2,
        safeStrokeWidth / 2,
        size.width - safeStrokeWidth,
        size.height - safeStrokeWidth,
      ),
      Radius.circular(
        math.min(borderRadius, math.min(size.width, size.height) / 2),
      ),
    );

    final gradient = SweepGradient(
      colors: [...colors, colors.first],
      stops: List.generate(colors.length + 1, (i) => i / colors.length),
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final paint = Paint()
      ..shader = gradient.createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = safeStrokeWidth;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _BorderBeamPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.colors != colors ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Mouse-follow spotlight glow — wrap a card's child to add a soft radial
/// highlight that tracks the cursor on hover.
class SpotlightGlow extends StatefulWidget {
  const SpotlightGlow({
    super.key,
    required this.colors,
    required this.child,
    this.borderRadius = 20,
    this.glowColor,
  });

  final AppColors colors;
  final Widget child;
  final double borderRadius;
  final Color? glowColor;

  @override
  State<SpotlightGlow> createState() => _SpotlightGlowState();
}

class _SpotlightGlowState extends State<SpotlightGlow> {
  // ValueNotifier instead of setState: mouse-move on Windows can fire far
  // more often than the frame rate, and setState would rebuild `child`
  // on every single event. Scoping the rebuild to a ValueListenableBuilder
  // around just the glow overlay is the Flutter equivalent of the
  // rAF-pending-flag throttle.
  final ValueNotifier<Offset?> _localPosition = ValueNotifier(null);

  @override
  void dispose() {
    _localPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor ?? widget.colors.accentColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return MouseRegion(
            onHover: (event) => _localPosition.value = event.localPosition,
            onExit: (_) => _localPosition.value = null,
            child: Stack(
              children: [
                widget.child,
                if (w > 0 && h > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<Offset?>(
                          valueListenable: _localPosition,
                          builder: (context, position, _) {
                            if (position == null) {
                              return const SizedBox.shrink();
                            }
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(
                                    (position.dx / w) * 2 - 1,
                                    (position.dy / h) * 2 - 1,
                                  ),
                                  radius: 0.9,
                                  colors: [
                                    glow.withValues(alpha: 0.12),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
