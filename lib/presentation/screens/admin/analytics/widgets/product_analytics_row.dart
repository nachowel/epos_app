import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../domain/models/analytics/product_analytics_item.dart';

class ProductAnalyticsRow extends StatelessWidget {
  const ProductAnalyticsRow({
    required this.rank,
    required this.product,
    super.key,
  });

  final int rank;
  final ProductAnalyticsItem product;

  bool get _isTopProduct => rank == 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (_isTopProduct)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      size: 16,
                      color: AppColors.warningStrong,
                    ),
                  ),
                Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: _isTopProduct
                        ? FontWeight.w900
                        : FontWeight.w700,
                    color: _isTopProduct
                        ? AppColors.warningStrong
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _isTopProduct
                        ? FontWeight.w800
                        : FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.quantityCount} sold',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          Text(
            CurrencyFormatter.fromMinor(product.revenueMinor),
            style: TextStyle(
              fontSize: 15,
              fontWeight: _isTopProduct ? FontWeight.w900 : FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
