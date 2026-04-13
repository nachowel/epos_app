class TopProductSummary {
  const TopProductSummary({
    required this.productId,
    required this.productName,
    required this.revenueMinor,
    this.quantityCount,
  });

  final int? productId;
  final String productName;
  final int revenueMinor;
  final int? quantityCount;

  bool get hasSales => revenueMinor > 0 || (quantityCount ?? 0) > 0;

  TopProductSummary copyWith({
    Object? productId = _unset,
    String? productName,
    int? revenueMinor,
    Object? quantityCount = _unset,
  }) {
    return TopProductSummary(
      productId: productId == _unset ? this.productId : productId as int?,
      productName: productName ?? this.productName,
      revenueMinor: revenueMinor ?? this.revenueMinor,
      quantityCount: quantityCount == _unset
          ? this.quantityCount
          : quantityCount as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TopProductSummary &&
        other.productId == productId &&
        other.productName == productName &&
        other.revenueMinor == revenueMinor &&
        other.quantityCount == quantityCount;
  }

  @override
  int get hashCode =>
      Object.hash(productId, productName, revenueMinor, quantityCount);
}

const Object _unset = Object();
