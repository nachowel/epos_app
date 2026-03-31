import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../domain/models/product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    required this.products,
    required this.isLoading,
    required this.onTapProduct,
    required this.viewportWidth,
    super.key,
  });

  static const double _targetMaxExtent = 170;
  static const double _mainAxisSpacing = 8;
  static const double _crossAxisSpacing = 8;
  static const double _childAspectRatio = 0.78;
  static const double _minimumItemWidthForSixColumns = _targetMaxExtent - 30;

  final List<Product> products;
  final bool isLoading;
  final ValueChanged<Product>? onTapProduct;
  final double viewportWidth;

  @override
  Widget build(BuildContext context) {
    if (isLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (products.isEmpty) {
      return Center(
        child: Text(
          AppStrings.noProductsInCategory,
          style: const TextStyle(
            fontSize: AppSizes.fontSm,
            color: AppColors.textSecondary,
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
          padding: const EdgeInsets.all(8),
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
    if (viewportWidth < 1000) {
      return 4;
    }

    if (viewportWidth <= 1300) {
      return 5;
    }

    final double sixColumnWidth = _itemWidthFor(
      width: productAreaWidth,
      columns: 6,
    );
    if (sixColumnWidth >= _minimumItemWidthForSixColumns) {
      return 6;
    }
    return 5;
  }

  double _itemWidthFor({required double width, required int columns}) {
    final double availableWidth = math.max(0, width - 16);
    return (availableWidth - ((columns - 1) * _crossAxisSpacing)) / columns;
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
