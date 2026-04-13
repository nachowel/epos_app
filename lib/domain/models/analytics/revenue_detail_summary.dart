import 'analytics_revenue_preset.dart';
import 'daily_revenue_point.dart';

enum RevenueComparisonDirection { up, down, flat, none }

class RevenueDetailSummary {
  const RevenueDetailSummary({
    required this.preset,
    required this.totalRevenueMinor,
    required this.orderCount,
    required this.averageOrderValueMinor,
    required this.dailyRevenueSeries,
    required this.comparisonLabel,
    required this.comparisonRevenueMinor,
    required this.comparisonOrderCount,
    required this.comparisonAverageOrderValueMinor,
    required this.comparisonDeltaRevenueMinor,
    required this.comparisonDirection,
  });

  const RevenueDetailSummary.empty({
    required this.preset,
    required this.comparisonLabel,
  }) : totalRevenueMinor = 0,
       orderCount = 0,
       averageOrderValueMinor = 0,
       dailyRevenueSeries = const <DailyRevenuePoint>[],
       comparisonRevenueMinor = 0,
       comparisonOrderCount = 0,
       comparisonAverageOrderValueMinor = 0,
       comparisonDeltaRevenueMinor = 0,
       comparisonDirection = RevenueComparisonDirection.none;

  final AnalyticsRevenuePreset preset;
  final int totalRevenueMinor;
  final int orderCount;
  final int averageOrderValueMinor;
  final List<DailyRevenuePoint> dailyRevenueSeries;
  final String comparisonLabel;
  final int comparisonRevenueMinor;
  final int comparisonOrderCount;
  final int comparisonAverageOrderValueMinor;
  final int comparisonDeltaRevenueMinor;
  final RevenueComparisonDirection comparisonDirection;

  bool get hasData =>
      totalRevenueMinor > 0 ||
      orderCount > 0 ||
      dailyRevenueSeries.any(
        (DailyRevenuePoint point) =>
            point.revenueMinor > 0 || point.orderCount > 0,
      );

  RevenueDetailSummary copyWith({
    AnalyticsRevenuePreset? preset,
    int? totalRevenueMinor,
    int? orderCount,
    int? averageOrderValueMinor,
    List<DailyRevenuePoint>? dailyRevenueSeries,
    String? comparisonLabel,
    int? comparisonRevenueMinor,
    int? comparisonOrderCount,
    int? comparisonAverageOrderValueMinor,
    int? comparisonDeltaRevenueMinor,
    RevenueComparisonDirection? comparisonDirection,
  }) {
    return RevenueDetailSummary(
      preset: preset ?? this.preset,
      totalRevenueMinor: totalRevenueMinor ?? this.totalRevenueMinor,
      orderCount: orderCount ?? this.orderCount,
      averageOrderValueMinor:
          averageOrderValueMinor ?? this.averageOrderValueMinor,
      dailyRevenueSeries: dailyRevenueSeries ?? this.dailyRevenueSeries,
      comparisonLabel: comparisonLabel ?? this.comparisonLabel,
      comparisonRevenueMinor:
          comparisonRevenueMinor ?? this.comparisonRevenueMinor,
      comparisonOrderCount: comparisonOrderCount ?? this.comparisonOrderCount,
      comparisonAverageOrderValueMinor:
          comparisonAverageOrderValueMinor ??
          this.comparisonAverageOrderValueMinor,
      comparisonDeltaRevenueMinor:
          comparisonDeltaRevenueMinor ?? this.comparisonDeltaRevenueMinor,
      comparisonDirection: comparisonDirection ?? this.comparisonDirection,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RevenueDetailSummary &&
        other.preset == preset &&
        other.totalRevenueMinor == totalRevenueMinor &&
        other.orderCount == orderCount &&
        other.averageOrderValueMinor == averageOrderValueMinor &&
        other.comparisonLabel == comparisonLabel &&
        other.comparisonRevenueMinor == comparisonRevenueMinor &&
        other.comparisonOrderCount == comparisonOrderCount &&
        other.comparisonAverageOrderValueMinor ==
            comparisonAverageOrderValueMinor &&
        other.comparisonDeltaRevenueMinor == comparisonDeltaRevenueMinor &&
        other.comparisonDirection == comparisonDirection &&
        _listEquals(other.dailyRevenueSeries, dailyRevenueSeries);
  }

  @override
  int get hashCode => Object.hash(
    preset,
    totalRevenueMinor,
    orderCount,
    averageOrderValueMinor,
    Object.hashAll(dailyRevenueSeries),
    comparisonLabel,
    comparisonRevenueMinor,
    comparisonOrderCount,
    comparisonAverageOrderValueMinor,
    comparisonDeltaRevenueMinor,
    comparisonDirection,
  );

  bool _listEquals(
    List<DailyRevenuePoint> left,
    List<DailyRevenuePoint> right,
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
