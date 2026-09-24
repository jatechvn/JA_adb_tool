import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'localization.dart';

/// Horizontal Device Tab Bar widget for JA ADB Tool.
///
/// Displays connected Android devices as horizontal tabs/pills across the top header.
/// Supports:
/// - Direct 1-click device switching.
/// - Mouse wheel horizontal scrolling when hovering over the tab list.
/// - Dynamic overflow detection.
/// - One-shot tactile elastic bounce nudge hint when the list overflows.
/// - Animated marquee bounce edge indicators (chevrons with gradient mask)
///   indicating that more devices are available to scroll.
class DeviceHorizontalTabBar extends StatefulWidget {
  final List<String> devices;
  final String? selectedDevice;
  final Map<String, Map<String, dynamic>> devicesDetails;
  final ValueChanged<String> onSelectDevice;
  final AppColors colors;
  final bool enableBounceHint;

  const DeviceHorizontalTabBar({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.devicesDetails,
    required this.onSelectDevice,
    required this.colors,
    this.enableBounceHint = true,
  });

  @override
  State<DeviceHorizontalTabBar> createState() => _DeviceHorizontalTabBarState();
}

class _DeviceHorizontalTabBarState extends State<DeviceHorizontalTabBar>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _marqueeBounceController;
  late final Animation<double> _bounceAnim;

  int? _hoveredIndex;
  bool _hasPlayedBounceHint = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _marqueeBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _bounceAnim = Tween<double>(begin: 0.0, end: 4.5).animate(
      CurvedAnimation(
        parent: _marqueeBounceController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant DeviceHorizontalTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.devices != widget.devices ||
        oldWidget.devices.length != widget.devices.length) {
      _hasPlayedBounceHint = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateScrollIndicators();
          if (widget.enableBounceHint) {
            _triggerBounceHint();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _marqueeBounceController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _updateScrollIndicators();
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final canLeft = offset > 4.0;
    final canRight = offset < (maxScroll - 4.0);

    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });

      if (canRight || canLeft) {
        if (!_marqueeBounceController.isAnimating) {
          _marqueeBounceController.repeat(reverse: true);
        }
      } else {
        _marqueeBounceController.stop();
      }
    }
  }

  void _triggerBounceHint() {
    if (!mounted || !_scrollController.hasClients) return;
    if (_hasPlayedBounceHint) return;
    if (_scrollController.position.maxScrollExtent <= 4.0) return;

    _hasPlayedBounceHint = true;
    final double current = _scrollController.offset;
    final double target = math.min(
      current + 42.0,
      _scrollController.position.maxScrollExtent,
    );
    if (target <= current) return;

    _scrollController
        .animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _scrollController.animateTo(
            current,
            duration: const Duration(milliseconds: 460),
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
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildScrollArrow({required bool isLeft}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _scrollBy(isLeft ? -150.0 : 150.0),
        child: Container(
          width: 22,
          height: 28,
          decoration: BoxDecoration(
            color: widget.colors.accentColor.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.colors.accentCyan.withValues(alpha: 0.45),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.accentCyan.withValues(alpha: 0.15),
                blurRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 16,
            color: widget.colors.accentCyan,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.colors.subCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: widget.colors.subCardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.phonelink_erase_rounded,
              size: 15,
              color: widget.colors.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              context.tr('no_device_connected'),
              style: TextStyle(
                color: widget.colors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _updateScrollIndicators();
            if (widget.enableBounceHint) {
              _triggerBounceHint();
            }
          }
        });

        return Container(
          height: 38,
          alignment: Alignment.centerLeft,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Mouse wheel scrollable horizontal tab list
              Listener(
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent &&
                      _scrollController.hasClients) {
                    final double delta = pointerSignal.scrollDelta.dy != 0
                        ? pointerSignal.scrollDelta.dy
                        : pointerSignal.scrollDelta.dx;
                    final targetOffset = (_scrollController.offset + delta)
                        .clamp(0.0, _scrollController.position.maxScrollExtent);
                    _scrollController.animateTo(
                      targetOffset,
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutCubic,
                    );
                  }
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.devices.length, (index) {
                      final dev = widget.devices[index];
                      final isSelected = widget.selectedDevice == dev;
                      final isHovered = _hoveredIndex == index;
                      final details = widget.devicesDetails[dev];
                      final String model =
                          (details?['model']?.toString()) ??
                          context.tr('android_device_label');
                      final String version =
                          (details?['version']?.toString()) ?? 'Android';

                      return Padding(
                        padding: EdgeInsets.only(
                          right: index < widget.devices.length - 1 ? 6.0 : 0.0,
                        ),
                        child: MouseRegion(
                          onEnter: (_) => setState(() => _hoveredIndex = index),
                          onExit: (_) => setState(() => _hoveredIndex = null),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => widget.onSelectDevice(dev),
                              borderRadius: BorderRadius.circular(10),
                              child: Tooltip(
                                message: '$model ($dev)\nAndroid $version',
                                waitDuration: const Duration(milliseconds: 500),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  constraints: const BoxConstraints(
                                    minWidth: 120,
                                    maxWidth: 200,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? widget.colors.accentColor.withValues(
                                            alpha: 0.16,
                                          )
                                        : (isHovered
                                              ? widget.colors.subCardBg
                                                    .withValues(alpha: 0.90)
                                              : widget.colors.subCardBg),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? widget.colors.accentCyan.withValues(
                                              alpha: 0.60,
                                            )
                                          : (isHovered
                                                ? widget.colors.accentCyan
                                                      .withValues(alpha: 0.35)
                                                : widget.colors.subCardBorder),
                                      width: isSelected ? 1.2 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: widget.colors.accentCyan
                                                  .withValues(alpha: 0.15),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Status dot indicator
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? const Color(0xFF10B981)
                                              : widget.colors.textMuted
                                                    .withValues(alpha: 0.4),
                                          boxShadow: isSelected
                                              ? const [
                                                  BoxShadow(
                                                    color: Color(0x6610B981),
                                                    blurRadius: 6,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Icon(
                                        Icons.phone_android_rounded,
                                        size: 15,
                                        color: isSelected
                                            ? widget.colors.accentCyan
                                            : widget.colors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              model,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? widget.colors.textPrimary
                                                    : widget
                                                          .colors
                                                          .textSecondary,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                                fontSize: 11,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '$dev • Android $version',
                                              style: TextStyle(
                                                color: widget.colors.textMuted,
                                                fontSize: 9,
                                                fontFamily: 'JetBrains Mono',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                    }),
                  ),
                ),
              ),

              // Left fade gradient & scroll arrow
              if (_canScrollLeft)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildScrollArrow(isLeft: true),
                      Container(
                        width: 14,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              widget.colors.cardBg.withValues(alpha: 0.85),
                              widget.colors.cardBg.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Right fade gradient & animated bouncing marquee scroll arrow
              if (_canScrollRight)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              widget.colors.cardBg.withValues(alpha: 0.85),
                              widget.colors.cardBg.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _bounceAnim,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_bounceAnim.value, 0),
                            child: child,
                          );
                        },
                        child: _buildScrollArrow(isLeft: false),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
