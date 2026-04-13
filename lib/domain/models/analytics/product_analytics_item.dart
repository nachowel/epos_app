class ProductAnalyticsItem {
  const ProductAnalyticsItem({
    required this.productId,
    required this.productName,
    required this.revenueMinor,
    required this.quantityCount,
  });

  final int productId;
  final String productName;
  final int revenueMinor;
  final int quantityCount;

  ProductAnalyticsItem copyWith({
    int? productId,
    String? productName,
    int? revenueMinor,
    int? quantityCount,
  }) {
    return ProductAnalyticsItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      revenueMinor: revenueMinor ?? this.revenueMinor,
      quantityCount: quantityCount ?? this.quantityCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ProductAnalyticsItem &&
        other.productId == productId &&
        other.productName == productName &&
        other.revenueMinor == revenueMinor &&
        other.quantityCount == quantityCount;
  }

  @override
  int get hashCode =>
      Object.hash(productId, productName, revenueMinor, quantityCount);
}
