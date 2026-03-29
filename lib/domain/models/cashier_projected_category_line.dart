class CashierProjectedCategoryLine {
  const CashierProjectedCategoryLine({
    required this.categoryName,
    required this.visibleAmountMinor,
  });

  final String categoryName;
  final int visibleAmountMinor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CashierProjectedCategoryLine &&
        other.categoryName == categoryName &&
        other.visibleAmountMinor == visibleAmountMinor;
  }

  @override
  int get hashCode => Object.hash(categoryName, visibleAmountMinor);
}
