import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../domain/models/analytics/top_product_summary.dart';
import 'analytics_kpi_card.dart';

class TopProductsPreviewCard extends StatelessWidget {
  const TopProductsPreviewCard({
    required this.products,
    required this.onTap,
    super.key,
  });

  final List<TopProductSummary> products;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnalyticsKpiCard(
      title: 'Top Products',
      icon: Icons.local_fire_department_rounded,
      onTap: onTap,
      accentColor: AppColors.warningStrong,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: products.isEmpty
            ? const <Widget>[
                Text(
                  'No paid product revenue yet.',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ]
            : List<Widget>.generate(products.length, (int index) {
                final TopProductSummary product = products[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == products.length - 1
                        ? 0
                        : AppSizes.spacingSm,
                  ),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacingSm),
                      Expanded(
                        child: Text(
                          product.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.spacingSm),
                      Text(
                        CurrencyFormatter.fromMinor(product.revenueMinor),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
      ),
    );
  }
}
