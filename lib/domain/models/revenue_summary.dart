import 'analytics/analytics_period.dart';
import 'daily_revenue_point.dart';
import 'hourly_distribution.dart';
import 'revenue_comparison.dart';
import 'revenue_intelligence_inputs.dart';
import 'revenue_insights.dart';
import 'semantic_sales_analytics.dart';
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
    required this.intelligenceInputs,
    required this.selectedPeriodSummary,
    this.semanticSalesAnalytics = const SemanticSalesAnalytics.empty(),
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
  final RevenueIntelligenceInputs intelligenceInputs;
  final RevenueSelectedPeriodSummary selectedPeriodSummary;
  final SemanticSalesAnalytics semanticSalesAnalytics;

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

  List<String> get dataQualityNotes => intelligenceInputs.dataQualityNotes;
}

class RevenueSelectedPeriodSummary {
  const RevenueSelectedPeriodSummary({
    required this.selection,
    required this.startDate,
    required this.endDate,
    required this.comparisonStartDate,
    required this.comparisonEndDate,
    required this.dayCount,
    required this.revenue,
    required this.orderCount,
    required this.averageOrderValue,
    required this.cancelledOrderCount,
    required this.paymentMix,
  });

  final AnalyticsPeriodSelection selection;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime comparisonStartDate;
  final DateTime comparisonEndDate;
  final int dayCount;
  final RevenueComparison revenue;
  final RevenueComparison orderCount;
  final RevenueComparison averageOrderValue;
  final RevenueComparison cancelledOrderCount;
  final RevenuePaymentMixComparison paymentMix;

  String get label => selection.label;
}
