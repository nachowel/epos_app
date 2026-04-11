import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../domain/models/category.dart';

class CategoryBar extends StatefulWidget {
  const CategoryBar({
    required this.categories,
    required this.categoryProductCounts,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.onSelectCategory,
    super.key,
  });

  final List<Category> categories;
  final Map<int, int> categoryProductCounts;
  final int? selectedCategoryId;
  final bool isLoading;
  final ValueChanged<int?> onSelectCategory;

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalProductCount = widget.categoryProductCounts.values.fold(
      0,
      (int sum, int count) => sum + count,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.borderStrong, width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryDarker.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    AppStrings.categories,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                _CountBadge(count: totalProductCount, compact: true),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.borderStrong),
          Expanded(
            child: widget.isLoading && widget.categories.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : widget.categories.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.spacingMd),
                      child: Text(
                        AppStrings.noCategories,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _scrollController,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                      itemCount: widget.categories.length + 1,
                      itemBuilder: (BuildContext context, int index) {
                        if (index == 0) {
                          return _CategoryTile(
                            label: AppStrings.allCategories,
                            count: totalProductCount,
                            icon: Icons.apps_rounded,
                            isSelected: widget.selectedCategoryId == null,
                            onTap: () => widget.onSelectCategory(null),
                          );
                        }

                        final Category category = widget.categories[index - 1];
                        return _CategoryTile(
                          label: category.name,
                          count: widget.categoryProductCounts[category.id] ?? 0,
                          icon: _resolveCategoryIcon(category.name),
                          isSelected: widget.selectedCategoryId == category.id,
                          onTap: () => widget.onSelectCategory(category.id),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(10);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: isSelected ? AppColors.primaryLight : Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: SizedBox(
            height: 46,
            child: Row(
              children: <Widget>[
                Container(
                  width: 4,
                  margin: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryStrong
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 7),
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.primaryDarker
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _CountBadge(count: count, isSelected: isSelected),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    this.isSelected = false,
    this.compact = false,
  });

  final int count;
  final bool isSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = compact
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
        : const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5);

    final BoxDecoration? decoration = compact
        ? null
        : BoxDecoration(
            color: isSelected ? AppColors.primaryStrong : AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryStrong
                  : AppColors.borderStrong,
            ),
          );

    return Container(
      constraints: BoxConstraints(minWidth: compact ? 0 : 18),
      padding: padding,
      decoration: decoration,
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 10 : 10.5,
          fontWeight: compact ? FontWeight.w600 : FontWeight.w700,
          color: compact
              ? AppColors.textSecondary
              : (isSelected
                    ? AppColors.textOnPrimary
                    : AppColors.textSecondary),
          height: 1,
        ),
      ),
    );
  }
}

IconData _resolveCategoryIcon(String label) {
  final String normalized = label.toLowerCase();
  if (normalized.contains('drink') || normalized.contains('coffee')) {
    return Icons.local_cafe_outlined;
  }
  if (normalized.contains('dessert') || normalized.contains('cake')) {
    return Icons.icecream_outlined;
  }
  if (normalized.contains('breakfast')) {
    return Icons.breakfast_dining_outlined;
  }
  if (normalized.contains('sandwich') || normalized.contains('burger')) {
    return Icons.lunch_dining_outlined;
  }
  return Icons.label_outline_rounded;
}
