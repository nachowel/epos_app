import 'daily_revenue_point.dart';
import 'hourly_distribution.dart';
import 'revenue_comparison.dart';
import 'revenue_insights.dart';
import 'weekly_revenue_point.dart';

class RevenueSummary {
  const RevenueSummary({
    required this.generatedAt,
    required this.timezone,
    required this.todayRevenue,
    required this.thisWeekRevenue,
    required this.thisMonthRevenue,
    required this.averageOrderValueCurrentWeek,
    required this.dailyTrend,
    required this.weeklySummary,
    required this.hourlyDistribution,
    required this.insights,
  });

  final DateTime generatedAt;
  final String timezone;
  final RevenueComparison todayRevenue;
  final RevenueComparison thisWeekRevenue;
  final RevenueComparison thisMonthRevenue;
  final RevenueComparison averageOrderValueCurrentWeek;
  final List<DailyRevenuePoint> dailyTrend;
  final List<WeeklyRevenuePoint> weeklySummary;
  final List<HourlyDistribution> hourlyDistribution;
  final RevenueInsights insights;

  bool get hasPaidData {
    return dailyTrend.any(
          (DailyRevenuePoint point) =>
              point.revenueMinor > 0 || point.orderCount > 0,
        ) ||
        weeklySummary.any(
          (WeeklyRevenuePoint point) =>
              point.revenueMinor > 0 || point.orderCount > 0,
        );
  }
}
