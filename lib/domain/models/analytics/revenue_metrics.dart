class RevenueMetrics {
  const RevenueMetrics({
    required this.totalRevenueMinor,
    required this.orderCount,
    required this.averageOrderValueMinor,
  });

  const RevenueMetrics.empty()
    : totalRevenueMinor = 0,
      orderCount = 0,
      averageOrderValueMinor = 0;

  final int totalRevenueMinor;
  final int orderCount;
  final int averageOrderValueMinor;

  RevenueMetrics copyWith({
    int? totalRevenueMinor,
    int? orderCount,
    int? averageOrderValueMinor,
  }) {
    return RevenueMetrics(
      totalRevenueMinor: totalRevenueMinor ?? this.totalRevenueMinor,
      orderCount: orderCount ?? this.orderCount,
      averageOrderValueMinor:
          averageOrderValueMinor ?? this.averageOrderValueMinor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RevenueMetrics &&
        other.totalRevenueMinor == totalRevenueMinor &&
        other.orderCount == orderCount &&
        other.averageOrderValueMinor == averageOrderValueMinor;
  }

  @override
  int get hashCode =>
      Object.hash(totalRevenueMinor, orderCount, averageOrderValueMinor);
}
