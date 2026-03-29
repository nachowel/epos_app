class ShiftReportCategoryLine {
  const ShiftReportCategoryLine({
    required this.categoryName,
    required this.totalMinor,
  });

  final String categoryName;
  final int totalMinor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShiftReportCategoryLine &&
        other.categoryName == categoryName &&
        other.totalMinor == totalMinor;
  }

  @override
  int get hashCode => Object.hash(categoryName, totalMinor);
}
