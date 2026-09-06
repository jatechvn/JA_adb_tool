import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_colors.dart';
import 'styles.dart';
import 'glass_widgets.dart';

/// Item definition for [GlassDropdown] and [GlassMultiSelectDropdown].
class GlassDropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? subtitle;
  final Color? accentColor;
  final String? badge;

  const GlassDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.subtitle,
    this.accentColor,
    this.badge,
  });
}

/// A modern Apple Liquid Glass Dropdown selector for single selection.
/// Adheres strictly to the project's Frosted Glassmorphism design system:
/// - Custom glass popup with BackdropFilter blur and highlight edge.
/// - Scrollable with [BouncingScrollPhysics] for long lists.
/// - Integrated live search field for quickly filtering long lists (>5 items).
/// - Selected item displays active pill background with accent color.
class GlassDropdown<T> extends StatefulWidget {
  final List<GlassDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T> onChanged;
  final String hintText;
  final AppColors colors;
  final double maxHeight;
  final bool enableSearch;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GlassDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    required this.colors,
    this.hintText = 'Chọn một mục…',
    this.maxHeight = 280,
    this.enableSearch = true,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  @override
  State<GlassDropdown<T>> createState() => _GlassDropdownState<T>();
}

class _GlassDropdownState<T> extends State<GlassDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  void _showOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Barrier dismiss on tap outside
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
              ),
            ),
            Positioned(
              width: size.width < 220 ? 260 : size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 6),
                child: _GlassDropdownMenu<T>(
                  items: widget.items,
                  selectedValue: widget.value,
                  maxHeight: widget.maxHeight,
                  enableSearch: widget.enableSearch && widget.items.length > 5,
                  colors: widget.colors,
                  onSelected: (val) {
                    _removeOverlay();
                    widget.onChanged(val);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final selectedItem = widget.items.cast<GlassDropdownItem<T>?>().firstWhere(
      (item) => item?.value == widget.value,
      orElse: () => null,
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleDropdown,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          hoverColor: colors.cardHoverBg.withValues(alpha: 0.15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _isOpen
                    ? colors.accentColor.withValues(alpha: 0.5)
                    : colors.subCardBorder,
                width: 1.1,
              ),
              boxShadow: [
                if (_isOpen)
                  BoxShadow(
                    color: colors.primaryGlow.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedItem?.icon != null) ...[
                  Icon(
                    selectedItem!.icon,
                    size: 16,
                    color: selectedItem.accentColor ?? colors.accentCyan,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    selectedItem?.label ?? widget.hintText,
                    style: TextStyle(
                      color: selectedItem != null
                          ? colors.textPrimary
                          : colors.textMuted,
                      fontSize: 12.5,
                      fontWeight: selectedItem != null
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selectedItem?.badge != null) ...[
                  const SizedBox(width: 6),
                  PillBadge(
                    label: selectedItem!.badge!,
                    color: selectedItem.accentColor ?? colors.accentEmerald,
                    bg: (selectedItem.accentColor ?? colors.accentEmerald)
                        .withValues(alpha: 0.12),
                    border: (selectedItem.accentColor ?? colors.accentEmerald)
                        .withValues(alpha: 0.35),
                    fontSize: 9.5,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _isOpen ? colors.accentColor : colors.textMuted,
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

class _GlassDropdownMenu<T> extends StatefulWidget {
  final List<GlassDropdownItem<T>> items;
  final T? selectedValue;
  final double maxHeight;
  final bool enableSearch;
  final AppColors colors;
  final ValueChanged<T> onSelected;

  const _GlassDropdownMenu({
    required this.items,
    required this.selectedValue,
    required this.maxHeight,
    required this.enableSearch,
    required this.colors,
    required this.onSelected,
  });

  @override
  State<_GlassDropdownMenu<T>> createState() => _GlassDropdownMenuState<T>();
}

class _GlassDropdownMenuState<T> extends State<_GlassDropdownMenu<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<GlassDropdownItem<T>> _filteredItems = widget.items;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredItems = widget.items;
      } else {
        final q = query.toLowerCase();
        _filteredItems = widget.items.where((item) {
          final l = item.label.toLowerCase();
          final s = item.subtitle?.toLowerCase() ?? '';
          final b = item.badge?.toLowerCase() ?? '';
          return l.contains(q) || s.contains(q) || b.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    ThemeProvider? theme;
    try {
      theme = Provider.of<ThemeProvider>(context, listen: false);
    } catch (_) {}
    final isDark =
        theme?.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final dropdownBlur = theme?.dialogBlur ?? 20.0;
    final dropdownOpacity = theme?.dialogOpacity ?? (isDark ? 0.95 : 0.98);

    // High-opacity glass surface with live tuning support
    final dropdownBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: dropdownOpacity)
        : const Color(0xFFFFFFFF).withValues(alpha: dropdownOpacity);
    final dropdownBorder = isDark
        ? const Color(0x38FFFFFF)
        : const Color(0x29000000);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: dropdownBlur, sigmaY: dropdownBlur),
          child: Container(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            decoration: BoxDecoration(
              color: dropdownBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dropdownBorder, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Highlight border line
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.glassHighlight.withValues(alpha: 0.8),
                        colors.glassHighlight.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),

                // Search field for long lists
                if (widget.enableSearch) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x33000000)
                            : const Color(0x0D000000),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x26FFFFFF)
                              : const Color(0x1A000000),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 15,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: _filter,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText:
                                    'Tìm kiếm ${widget.items.length} mục…',
                                hintStyle: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                          if (_searchCtrl.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _filter('');
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: colors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: colors.subCardBorder, height: 1),
                ],

                // Scrollable Item List with BouncingScrollPhysics
                Flexible(
                  child: _filteredItems.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Không tìm thấy mục phù hợp',
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _filteredItems.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 2),
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final isSelected =
                                item.value == widget.selectedValue;

                            return InkWell(
                              onTap: () => widget.onSelected(item.value),
                              borderRadius: BorderRadius.circular(10),
                              hoverColor: colors.cardHoverBg.withValues(
                                alpha: 0.25,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.accentColor.withValues(
                                          alpha: 0.14,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.accentColor.withValues(
                                            alpha: 0.35,
                                          )
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    if (item.icon != null) ...[
                                      Icon(
                                        item.icon,
                                        size: 16,
                                        color: isSelected
                                            ? colors.accentCyan
                                            : (item.accentColor ??
                                                  colors.textMuted),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            item.label,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? colors.textPrimary
                                                  : colors.textSecondary,
                                              fontSize: 12,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          if (item.subtitle != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle!,
                                              style: TextStyle(
                                                color: colors.textMuted,
                                                fontSize: 10.5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (item.badge != null) ...[
                                      const SizedBox(width: 6),
                                      PillBadge(
                                        label: item.badge!,
                                        color: isSelected
                                            ? colors.accentCyan
                                            : colors.textMuted,
                                        bg:
                                            (isSelected
                                                    ? colors.accentCyan
                                                    : colors.subCardBg)
                                                .withValues(alpha: 0.12),
                                        border:
                                            (isSelected
                                                    ? colors.accentCyan
                                                    : colors.subCardBorder)
                                                .withValues(alpha: 0.3),
                                        fontSize: 9,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                      ),
                                    ],
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.check_rounded,
                                        size: 16,
                                        color: colors.accentCyan,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
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

/// A modern Apple Liquid Glass Dropdown selector for multiple selection.
class GlassMultiSelectDropdown<T> extends StatefulWidget {
  final List<GlassDropdownItem<T>> items;
  final List<T> selectedValues;
  final ValueChanged<List<T>> onChanged;
  final String hintText;
  final AppColors colors;
  final double maxHeight;
  final bool enableSearch;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const GlassMultiSelectDropdown({
    super.key,
    required this.items,
    required this.selectedValues,
    required this.onChanged,
    required this.colors,
    this.hintText = 'Chọn các mục…',
    this.maxHeight = 280,
    this.enableSearch = true,
    this.borderRadius = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  @override
  State<GlassMultiSelectDropdown<T>> createState() =>
      _GlassMultiSelectDropdownState<T>();
}

class _GlassMultiSelectDropdownState<T>
    extends State<GlassMultiSelectDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() => _isOpen = false);
    }
  }

  void _showOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
              ),
            ),
            Positioned(
              width: size.width < 240 ? 280 : size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, size.height + 6),
                child: StatefulBuilder(
                  builder: (context, setOverlayState) {
                    return _GlassMultiSelectMenu<T>(
                      items: widget.items,
                      selectedValues: widget.selectedValues,
                      maxHeight: widget.maxHeight,
                      enableSearch:
                          widget.enableSearch && widget.items.length > 5,
                      colors: widget.colors,
                      onToggle: (val) {
                        final current = List<T>.from(widget.selectedValues);
                        if (current.contains(val)) {
                          current.remove(val);
                        } else {
                          current.add(val);
                        }
                        widget.onChanged(current);
                        setOverlayState(() {});
                        if (mounted) setState(() {});
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final count = widget.selectedValues.length;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleDropdown,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          hoverColor: colors.cardHoverBg.withValues(alpha: 0.15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: colors.subCardBg,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _isOpen
                    ? colors.accentColor.withValues(alpha: 0.5)
                    : colors.subCardBorder,
                width: 1.1,
              ),
              boxShadow: [
                if (_isOpen)
                  BoxShadow(
                    color: colors.primaryGlow.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    count == 0 ? widget.hintText : 'Đã chọn $count mục',
                    style: TextStyle(
                      color: count > 0 ? colors.textPrimary : colors.textMuted,
                      fontSize: 12.5,
                      fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  PillBadge(
                    label: '$count',
                    color: colors.accentEmerald,
                    bg: colors.accentEmerald.withValues(alpha: 0.14),
                    border: colors.accentEmerald.withValues(alpha: 0.35),
                    fontSize: 9.5,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: _isOpen ? colors.accentColor : colors.textMuted,
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

class _GlassMultiSelectMenu<T> extends StatefulWidget {
  final List<GlassDropdownItem<T>> items;
  final List<T> selectedValues;
  final double maxHeight;
  final bool enableSearch;
  final AppColors colors;
  final ValueChanged<T> onToggle;

  const _GlassMultiSelectMenu({
    required this.items,
    required this.selectedValues,
    required this.maxHeight,
    required this.enableSearch,
    required this.colors,
    required this.onToggle,
  });

  @override
  State<_GlassMultiSelectMenu<T>> createState() =>
      _GlassMultiSelectMenuState<T>();
}

class _GlassMultiSelectMenuState<T> extends State<_GlassMultiSelectMenu<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  late List<GlassDropdownItem<T>> _filteredItems = widget.items;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredItems = widget.items;
      } else {
        final q = query.toLowerCase();
        _filteredItems = widget.items.where((item) {
          final l = item.label.toLowerCase();
          final s = item.subtitle?.toLowerCase() ?? '';
          return l.contains(q) || s.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    ThemeProvider? theme;
    try {
      theme = Provider.of<ThemeProvider>(context, listen: false);
    } catch (_) {}
    final isDark =
        theme?.isDark ?? (Theme.of(context).brightness == Brightness.dark);
    final dropdownBlur = theme?.dialogBlur ?? 20.0;
    final dropdownOpacity = theme?.dialogOpacity ?? (isDark ? 0.95 : 0.98);

    final dropdownBg = isDark
        ? const Color(0xFF1E293B).withValues(alpha: dropdownOpacity)
        : const Color(0xFFFFFFFF).withValues(alpha: dropdownOpacity);
    final dropdownBorder = isDark
        ? const Color(0x38FFFFFF)
        : const Color(0x29000000);

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: dropdownBlur, sigmaY: dropdownBlur),
          child: Container(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            decoration: BoxDecoration(
              color: dropdownBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dropdownBorder, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Highlight top line
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.glassHighlight.withValues(alpha: 0.8),
                        colors.glassHighlight.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                ),

                if (widget.enableSearch) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x33000000)
                            : const Color(0x0D000000),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x26FFFFFF)
                              : const Color(0x1A000000),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 15,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: _filter,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText:
                                    'Tìm kiếm ${widget.items.length} mục…',
                                hintStyle: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(color: colors.subCardBorder, height: 1),
                ],

                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = widget.selectedValues.contains(
                        item.value,
                      );

                      return InkWell(
                        onTap: () => widget.onToggle(item.value),
                        borderRadius: BorderRadius.circular(10),
                        hoverColor: colors.cardHoverBg.withValues(alpha: 0.25),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.accentColor.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? colors.accentColor.withValues(alpha: 0.35)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.accentColor
                                      : colors.subCardBg,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isSelected
                                        ? colors.accentColor
                                        : colors.subCardBorder,
                                    width: 1.2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              if (item.icon != null) ...[
                                Icon(
                                  item.icon,
                                  size: 16,
                                  color: isSelected
                                      ? colors.accentCyan
                                      : (item.accentColor ?? colors.textMuted),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
