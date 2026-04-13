import 'product_analytics_item.dart';

class CategoryProductAnalyticsSection {
  const CategoryProductAnalyticsSection({
    required this.categoryId,
    required this.categoryName,
    required this.totalRevenueMinor,
    required this.products,
  });

  final int categoryId;
  final String categoryName;
  final int totalRevenueMinor;
  final List<ProductAnalyticsItem> products;

  CategoryProductAnalyticsSection copyWith({
    int? categoryId,
    String? categoryName,
    int? totalRevenueMinor,
    List<ProductAnalyticsItem>? products,
  }) {
    return CategoryProductAnalyticsSection(
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      totalRevenueMinor: totalRevenueMinor ?? this.totalRevenueMinor,
      products: products ?? this.products,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CategoryProductAnalyticsSection &&
        other.categoryId == categoryId &&
        other.categoryName == categoryName &&
        other.totalRevenueMinor == totalRevenueMinor &&
        _listEquals(other.products, products);
  }

  @override
  int get hashCode => Object.hash(
    categoryId,
    categoryName,
    totalRevenueMinor,
    Object.hashAll(products),
  );

  bool _listEquals(
    List<ProductAnalyticsItem> left,
    List<ProductAnalyticsItem> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
