class DailyRevenuePoint {
  const DailyRevenuePoint({
    required this.date,
    required this.revenueMinor,
    required this.orderCount,
  });

  final DateTime date;
  final int revenueMinor;
  final int orderCount;

  DailyRevenuePoint copyWith({
    DateTime? date,
    int? revenueMinor,
    int? orderCount,
  }) {
    return DailyRevenuePoint(
      date: date ?? this.date,
      revenueMinor: revenueMinor ?? this.revenueMinor,
      orderCount: orderCount ?? this.orderCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DailyRevenuePoint &&
        other.date == date &&
        other.revenueMinor == revenueMinor &&
        other.orderCount == orderCount;
  }

  @override
  int get hashCode => Object.hash(date, revenueMinor, orderCount);
}
