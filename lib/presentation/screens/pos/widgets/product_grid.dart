import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../domain/models/product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    required this.title,
    required this.productCount,
    required this.products,
    required this.isLoading,
    required this.onTapProduct,
    required this.viewportWidth,
    super.key,
  });

  static const double _mainAxisSpacing = 10;
  static const double _crossAxisSpacing = 10;
  static const double _childAspectRatio = 1.02;

  final String title;
  final int productCount;
  final List<Product> products;
  final bool isLoading;
  final ValueChanged<Product>? onTapProduct;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.82)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.038),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppStrings.products,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$productCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border.withValues(alpha: 0.84)),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacingLg),
          child: Text(
            AppStrings.noProductsInCategory,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int crossAxisCount = _resolveCrossAxisCount(
          productAreaWidth: constraints.maxWidth,
          viewportWidth: viewportWidth,
        );

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: _mainAxisSpacing,
            crossAxisSpacing: _crossAxisSpacing,
            childAspectRatio: _childAspectRatio,
          ).copyWith(crossAxisCount: crossAxisCount),
          itemBuilder: (BuildContext context, int index) {
            final Product product = products[index];
            return ProductCard(
              key: ValueKey<int>(product.id),
              product: product,
              onTap: onTapProduct == null ? null : () => onTapProduct!(product),
            );
          },
        );
      },
    );
  }

  int _resolveCrossAxisCount({
    required double productAreaWidth,
    required double viewportWidth,
  }) {
    if (productAreaWidth < 460 || viewportWidth < 900) {
      return 2;
    }
    if (productAreaWidth < 760) {
      return 3;
    }
    if (productAreaWidth < 1080) {
      return 4;
    }
    return 5;
  }
}

extension on SliverGridDelegateWithFixedCrossAxisCount {
  SliverGridDelegateWithFixedCrossAxisCount copyWith({int? crossAxisCount}) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount ?? this.crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: childAspectRatio,
    );
  }
}
