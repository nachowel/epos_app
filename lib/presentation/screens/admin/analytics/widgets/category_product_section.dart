import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../domain/models/analytics/category_product_analytics_section.dart';
import 'product_analytics_row.dart';

class CategoryProductSection extends StatefulWidget {
  const CategoryProductSection({
    required this.section,
    required this.defaultExpanded,
    super.key,
  });

  final CategoryProductAnalyticsSection section;
  final bool defaultExpanded;

  @override
  State<CategoryProductSection> createState() => _CategoryProductSectionState();
}

class _CategoryProductSectionState extends State<CategoryProductSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.defaultExpanded;
  }

  @override
  void didUpdateWidget(covariant CategoryProductSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.categoryId != widget.section.categoryId) {
      _isExpanded = widget.defaultExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final CategoryProductAnalyticsSection section = widget.section;

    return Container(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingLg),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingMd),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          section.categoryName,
                          style: const TextStyle(
                            fontSize: AppSizes.fontMd,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.fromMinor(
                            section.totalRevenueMinor,
                          ),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _isExpanded
                        ? 'Collapse section'
                        : 'Expand section',
                    onPressed: _toggleExpanded,
                    icon: Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Column(
              children: List<Widget>.generate(section.products.length, (
                int index,
              ) {
                return Column(
                  children: <Widget>[
                    ProductAnalyticsRow(
                      rank: index + 1,
                      product: section.products[index],
                    ),
                    if (index < section.products.length - 1)
                      const Divider(height: 1, color: AppColors.border),
                  ],
                );
              }),
            ),
        ],
      ),
    );
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }
}
