class WeeklyRevenuePoint {
  const WeeklyRevenuePoint({
    required this.weekStart,
    required this.revenueMinor,
    required this.orderCount,
  });

  final DateTime weekStart;
  final int revenueMinor;
  final int orderCount;
}
