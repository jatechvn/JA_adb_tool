import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'glass_widgets.dart';

/// A search field + horizontal row of toggleable filter pills, styled to
/// match the glass design system. Use above a grid/list view (e.g. a device
/// list, a package list) to let the user narrow results.
class FilterSearchDock extends StatelessWidget {
  const FilterSearchDock({
    super.key,
    required this.colors,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterSelected,
    this.searchController,
    this.onSearchChanged,
    this.searchHint = 'Search…',
  });

  final AppColors colors;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterSelected;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      colors: colors,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: colors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: TextStyle(color: colors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: searchHint,
                    hintStyle: TextStyle(color: colors.textMuted),
                  ),
                ),
              ),
            ],
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(color: colors.subCardBorder, height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: filters.map((f) {
                final isSelected = f == selectedFilter;
                return GestureDetector(
                  onTap: () => onFilterSelected(f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? colors.accentColor : colors.subCardBg,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : colors.subCardBorder,
                      ),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: isSelected ? Colors.white : colors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
