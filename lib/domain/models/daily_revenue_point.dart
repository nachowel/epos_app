class DailyRevenuePoint {
  const DailyRevenuePoint({
    required this.date,
    required this.revenueMinor,
    required this.orderCount,
  });

  final DateTime date;
  final int revenueMinor;
  final int orderCount;
}
