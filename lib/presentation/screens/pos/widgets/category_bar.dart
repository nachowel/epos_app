import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../domain/models/category.dart';

class CategoryBar extends StatefulWidget {
  const CategoryBar({
    required this.categories,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.onSelectCategory,
    super.key,
  });

  final List<Category> categories;
  final int? selectedCategoryId;
  final bool isLoading;
  final ValueChanged<int?> onSelectCategory;

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  static const int _pinnedCategoryCount = 4;
  final ScrollController _scrollController = ScrollController();
  bool _showTrailingFade = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFadeState());
  }

  @override
  void didUpdateWidget(covariant CategoryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categories != widget.categories) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncFadeState());
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.categories.isEmpty) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.categories.isEmpty) {
      return SizedBox(
        height: 56,
        child: Center(
          child: Text(
            AppStrings.noCategories,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final int pinnedCount = math.min(
      _pinnedCategoryCount,
      widget.categories.length,
    );
    final List<Category> pinnedCategories = widget.categories
        .take(pinnedCount)
        .toList(growable: false);
    final List<Category> scrollableCategories = widget.categories
        .skip(pinnedCount)
        .toList(growable: false);

    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: <Widget>[
          _CategoryChip(
            label: AppStrings.allCategories,
            isSelected: widget.selectedCategoryId == null,
            onTap: () => widget.onSelectCategory(null),
          ),
          ...pinnedCategories.map(
            (Category category) => Padding(
              padding: const EdgeInsets.only(left: AppSizes.spacingSm),
              child: _CategoryChip(
                label: category.name,
                isSelected: widget.selectedCategoryId == category.id,
                onTap: () => widget.onSelectCategory(category.id),
              ),
            ),
          ),
          if (scrollableCategories.isNotEmpty) ...<Widget>[
            const SizedBox(width: AppSizes.spacingSm),
            Expanded(
              child: Stack(
                children: <Widget>[
                  ListView.separated(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: scrollableCategories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSizes.spacingSm),
                    itemBuilder: (BuildContext context, int index) {
                      final Category category = scrollableCategories[index];
                      return _CategoryChip(
                        label: category.name,
                        isSelected: widget.selectedCategoryId == category.id,
                        onTap: () => widget.onSelectCategory(category.id),
                      );
                    },
                  ),
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: _showTrailingFade ? 1 : 0,
                        child: Container(
                          width: 36,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: <Color>[
                                Color(0x00F2F4F7),
                                AppColors.background,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleScroll() {
    _syncFadeState();
  }

  void _syncFadeState() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final bool shouldShow =
        _scrollController.position.maxScrollExtent > 0 &&
        _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 4;
    if (_showTrailingFade == shouldShow) {
      return;
    }
    setState(() {
      _showTrailingFade = shouldShow;
    });
  }
}

class _CategoryChip extends StatefulWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_CategoryChip> createState() => _CategoryChipState();
}

class _CategoryChipState extends State<_CategoryChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color chipColor = widget.isSelected
        ? AppColors.chipSelectedBackground
        : AppColors.surface;

    return AnimatedScale(
      duration: const Duration(milliseconds: 110),
      scale: _isPressed ? 0.98 : 1,
      child: Material(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (bool value) {
            if (_isPressed == value) {
              return;
            }
            setState(() {
              _isPressed = value;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            constraints: const BoxConstraints(minWidth: 88, maxWidth: 132),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? AppColors.chipSelectedBackground
                    : AppColors.border.withValues(alpha: 0.9),
              ),
            ),
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: widget.isSelected
                    ? FontWeight.w700
                    : FontWeight.w600,
                color: widget.isSelected
                    ? AppColors.chipSelectedText
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
