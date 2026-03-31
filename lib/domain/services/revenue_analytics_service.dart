import 'package:intl/intl.dart';

import '../../core/errors/exceptions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/revenue_analytics_repository.dart';
import '../models/daily_revenue_point.dart';
import '../models/hourly_distribution.dart';
import '../models/revenue_comparison.dart';
import '../models/revenue_insights.dart';
import '../models/revenue_summary.dart';
import '../models/user.dart';
import '../models/weekly_revenue_point.dart';

class RevenueAnalyticsService {
  const RevenueAnalyticsService({
    required RevenueAnalyticsRepository repository,
  }) : _repository = repository;

  final RevenueAnalyticsRepository _repository;

  Future<RevenueSummary> getRevenueSummary({required User user}) async {
    _ensureAdmin(user);

    final RevenueAnalyticsSnapshot snapshot = await _repository
        .fetchRevenueAnalytics();
    final List<DailyRevenuePoint> dailyTrend = snapshot.dailyTrend
        .map(
          (RevenueAnalyticsDailyPoint point) => DailyRevenuePoint(
            date: _parseDateKey(point.dateKey),
            revenueMinor: point.revenueMinor,
            orderCount: point.orderCount,
          ),
        )
        .toList(growable: false);
    final List<WeeklyRevenuePoint> weeklySummary = snapshot.weeklySummary
        .map(
          (RevenueAnalyticsWeeklyPoint point) => WeeklyRevenuePoint(
            weekStart: _parseDateKey(point.weekStartKey),
            revenueMinor: point.revenueMinor,
            orderCount: point.orderCount,
          ),
        )
        .toList(growable: false);
    final List<HourlyDistribution> hourlyDistribution =
        snapshot.hourlyDistribution
            .map(
              (RevenueAnalyticsHourlyPoint point) => HourlyDistribution(
                hour: point.hour,
                orderCount: point.orderCount,
                revenueMinor: point.revenueMinor,
              ),
            )
            .toList(growable: false)
          ..sort(
            (HourlyDistribution left, HourlyDistribution right) =>
                left.hour.compareTo(right.hour),
          );

    final RevenueComparison todayRevenue = RevenueComparison(
      currentValue: snapshot.todayRevenueMinor,
      previousValue: snapshot.yesterdayRevenueMinor,
      metricFormat: RevenueMetricFormat.currencyMinor,
    );
    final RevenueComparison thisWeekRevenue = RevenueComparison(
      currentValue: snapshot.thisWeekRevenueMinor,
      previousValue: snapshot.lastWeekRevenueMinor,
      metricFormat: RevenueMetricFormat.currencyMinor,
    );
    final RevenueComparison thisMonthRevenue = RevenueComparison(
      currentValue: snapshot.thisMonthRevenueMinor,
      previousValue: snapshot.lastMonthRevenueMinor,
      metricFormat: RevenueMetricFormat.currencyMinor,
    );
    final RevenueComparison averageOrderValueCurrentWeek = RevenueComparison(
      currentValue: _averageOrderValueMinor(
        snapshot.thisWeekRevenueMinor,
        snapshot.thisWeekOrderCount,
      ),
      previousValue: _averageOrderValueMinor(
        snapshot.lastWeekRevenueMinor,
        snapshot.lastWeekOrderCount,
      ),
      metricFormat: RevenueMetricFormat.currencyMinor,
    );

    return RevenueSummary(
      generatedAt: snapshot.generatedAt,
      timezone: snapshot.timezone,
      todayRevenue: todayRevenue,
      thisWeekRevenue: thisWeekRevenue,
      thisMonthRevenue: thisMonthRevenue,
      averageOrderValueCurrentWeek: averageOrderValueCurrentWeek,
      dailyTrend: dailyTrend,
      weeklySummary: weeklySummary,
      hourlyDistribution: hourlyDistribution,
      insights: _buildInsights(
        thisWeekRevenue: thisWeekRevenue,
        dailyTrend: dailyTrend,
        hourlyDistribution: hourlyDistribution,
      ),
    );
  }

  RevenueInsights _buildInsights({
    required RevenueComparison thisWeekRevenue,
    required List<DailyRevenuePoint> dailyTrend,
    required List<HourlyDistribution> hourlyDistribution,
  }) {
    return RevenueInsights(
      weeklyPerformance: _buildWeeklyPerformanceMessage(thisWeekRevenue),
      revenueMomentum: _buildRevenueMomentumMessage(dailyTrend),
      strongestDay: _buildStrongestDayMessage(dailyTrend),
      weakestDay: _buildWeakestDayMessage(dailyTrend),
      peakHours: _buildPeakHoursMessage(hourlyDistribution),
      lowHours: _buildLowHoursMessage(hourlyDistribution),
      topHourConcentration: _buildTopHourConcentrationMessage(
        hourlyDistribution,
      ),
      distributionBalance: _buildDistributionBalanceMessage(hourlyDistribution),
    );
  }

  String _buildWeeklyPerformanceMessage(RevenueComparison comparison) {
    final double? change = comparison.percentageChange;
    if (change == null) {
      return comparison.currentValue == 0
          ? 'This week is flat versus last week.'
          : 'This week is higher than last week, which had no paid revenue.';
    }
    if (comparison.isFlat) {
      return 'This week is flat versus last week.';
    }
    final String direction = change > 0 ? 'higher' : 'lower';
    return 'This week is ${change.abs().toStringAsFixed(1)}% $direction than last week.';
  }

  String _buildRevenueMomentumMessage(List<DailyRevenuePoint> dailyTrend) {
    final int totalRevenue = _totalDailyRevenue(dailyTrend);
    if (totalRevenue == 0) {
      return 'Revenue has not generated any paid sales over the last ${dailyTrend.length} days.';
    }
    final int splitIndex = (dailyTrend.length / 2).floor();
    final int firstHalf = dailyTrend
        .take(splitIndex)
        .fold<int>(
          0,
          (int sum, DailyRevenuePoint point) => sum + point.revenueMinor,
        );
    final int secondHalf = dailyTrend
        .skip(splitIndex)
        .fold<int>(
          0,
          (int sum, DailyRevenuePoint point) => sum + point.revenueMinor,
        );

    if (firstHalf == secondHalf) {
      return 'Revenue has remained flat over the last ${dailyTrend.length} days.';
    }
    if (firstHalf == 0) {
      return 'Revenue has increased over the last ${dailyTrend.length} days.';
    }
    final double change = ((secondHalf - firstHalf) / firstHalf) * 100;
    final String direction = secondHalf > firstHalf ? 'increased' : 'decreased';
    return 'Revenue has $direction over the last ${dailyTrend.length} days by ${change.abs().toStringAsFixed(1)}%.';
  }

  String _buildStrongestDayMessage(List<DailyRevenuePoint> dailyTrend) {
    if (_totalDailyRevenue(dailyTrend) == 0) {
      return 'Strongest day is unavailable because there is no paid revenue in the last ${dailyTrend.length} days.';
    }
    DailyRevenuePoint strongest = dailyTrend.first;
    for (final DailyRevenuePoint point in dailyTrend.skip(1)) {
      if (point.revenueMinor > strongest.revenueMinor ||
          (point.revenueMinor == strongest.revenueMinor &&
              point.orderCount > strongest.orderCount)) {
        strongest = point;
      }
    }
    return 'Strongest day is ${_dayLabel(strongest.date)} with ${CurrencyFormatter.fromMinor(strongest.revenueMinor)}.';
  }

  String _buildWeakestDayMessage(List<DailyRevenuePoint> dailyTrend) {
    if (dailyTrend.isEmpty) {
      return 'Weakest day is unavailable because no daily buckets were returned.';
    }
    DailyRevenuePoint weakest = dailyTrend.first;
    for (final DailyRevenuePoint point in dailyTrend.skip(1)) {
      if (point.revenueMinor < weakest.revenueMinor ||
          (point.revenueMinor == weakest.revenueMinor &&
              point.orderCount < weakest.orderCount)) {
        weakest = point;
      }
    }
    return 'Weakest day is ${_dayLabel(weakest.date)} with ${CurrencyFormatter.fromMinor(weakest.revenueMinor)}.';
  }

  String _buildPeakHoursMessage(List<HourlyDistribution> hourlyDistribution) {
    final _HourWindow? window = _selectHourWindow(
      hourlyDistribution,
      preferPeak: true,
    );
    final int totalRevenue = _totalHourlyRevenue(hourlyDistribution);
    if (window == null || totalRevenue == 0 || window.revenueMinor == 0) {
      return 'Peak hours are unavailable because there is no hourly revenue yet.';
    }
    final double share = (window.revenueMinor / totalRevenue) * 100;
    return 'Peak hours are ${_hourRange(window.startHour, window.endHourExclusive)} contributing ${share.toStringAsFixed(1)}% of revenue.';
  }

  String _buildLowHoursMessage(List<HourlyDistribution> hourlyDistribution) {
    final _HourWindow? window = _selectHourWindow(
      hourlyDistribution,
      preferPeak: false,
    );
    if (window == null) {
      return 'Low performance hours are unavailable because hourly buckets were not returned.';
    }
    return 'Low performance hours are ${_hourRange(window.startHour, window.endHourExclusive)}.';
  }

  String _buildTopHourConcentrationMessage(
    List<HourlyDistribution> hourlyDistribution,
  ) {
    final int totalRevenue = _totalHourlyRevenue(hourlyDistribution);
    if (totalRevenue == 0) {
      return 'Top 20% hours generate 0.0% of revenue because there are no paid sales yet.';
    }
    final List<HourlyDistribution> sorted =
        List<HourlyDistribution>.from(hourlyDistribution)..sort(
          (HourlyDistribution left, HourlyDistribution right) =>
              right.revenueMinor.compareTo(left.revenueMinor),
        );
    final int topHourCount = ((hourlyDistribution.length * 0.2).ceil()).clamp(
      1,
      hourlyDistribution.length,
    );
    final int topHourRevenue = sorted
        .take(topHourCount)
        .fold<int>(
          0,
          (int sum, HourlyDistribution point) => sum + point.revenueMinor,
        );
    final double share = (topHourRevenue / totalRevenue) * 100;
    return 'Top 20% hours generate ${share.toStringAsFixed(1)}% of revenue.';
  }

  String _buildDistributionBalanceMessage(
    List<HourlyDistribution> hourlyDistribution,
  ) {
    final int totalRevenue = _totalHourlyRevenue(hourlyDistribution);
    if (totalRevenue == 0) {
      return 'Revenue is evenly distributed because there is no paid revenue yet.';
    }
    final List<HourlyDistribution> sorted =
        List<HourlyDistribution>.from(hourlyDistribution)..sort(
          (HourlyDistribution left, HourlyDistribution right) =>
              right.revenueMinor.compareTo(left.revenueMinor),
        );
    final int topHourCount = ((hourlyDistribution.length * 0.2).ceil()).clamp(
      1,
      hourlyDistribution.length,
    );
    final int topHourRevenue = sorted
        .take(topHourCount)
        .fold<int>(
          0,
          (int sum, HourlyDistribution point) => sum + point.revenueMinor,
        );
    final double share = (topHourRevenue / totalRevenue) * 100;
    return share >= 55
        ? 'Revenue is concentrated in a small set of hours.'
        : 'Revenue is fairly evenly distributed across the day.';
  }

  int _averageOrderValueMinor(int revenueMinor, int orderCount) {
    if (orderCount <= 0) {
      return 0;
    }
    return (revenueMinor / orderCount).round();
  }

  DateTime _parseDateKey(String key) {
    final List<String> parts = key.split('-');
    if (parts.length != 3) {
      throw FormatException('Invalid analytics date key: $key');
    }
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
      12,
    );
  }

  int _totalDailyRevenue(List<DailyRevenuePoint> dailyTrend) {
    return dailyTrend.fold<int>(
      0,
      (int sum, DailyRevenuePoint point) => sum + point.revenueMinor,
    );
  }

  int _totalHourlyRevenue(List<HourlyDistribution> hourlyDistribution) {
    return hourlyDistribution.fold<int>(
      0,
      (int sum, HourlyDistribution point) => sum + point.revenueMinor,
    );
  }

  String _dayLabel(DateTime value) {
    return DateFormat('EEE d MMM').format(value);
  }

  _HourWindow? _selectHourWindow(
    List<HourlyDistribution> hourlyDistribution, {
    required bool preferPeak,
  }) {
    if (hourlyDistribution.length < 3) {
      return null;
    }

    _HourWindow? selected;
    for (int start = 0; start <= hourlyDistribution.length - 3; start += 1) {
      int revenueMinor = 0;
      int orderCount = 0;
      for (int index = start; index < start + 3; index += 1) {
        revenueMinor += hourlyDistribution[index].revenueMinor;
        orderCount += hourlyDistribution[index].orderCount;
      }
      final _HourWindow candidate = _HourWindow(
        startHour: start,
        endHourExclusive: start + 3,
        revenueMinor: revenueMinor,
        orderCount: orderCount,
      );
      if (selected == null) {
        selected = candidate;
        continue;
      }

      final bool shouldReplace = preferPeak
          ? candidate.revenueMinor > selected.revenueMinor ||
                (candidate.revenueMinor == selected.revenueMinor &&
                    candidate.orderCount > selected.orderCount)
          : candidate.revenueMinor < selected.revenueMinor ||
                (candidate.revenueMinor == selected.revenueMinor &&
                    candidate.orderCount < selected.orderCount);
      if (shouldReplace) {
        selected = candidate;
      }
    }
    return selected;
  }

  String _hourRange(int startHour, int endHourExclusive) {
    final String start = '${startHour.toString().padLeft(2, '0')}:00';
    final String end = '${endHourExclusive.toString().padLeft(2, '0')}:00';
    return '$start-$end';
  }

  void _ensureAdmin(User user) {
    if (user.role != UserRole.admin) {
      throw UnauthorisedException('Only admins can access revenue analytics.');
    }
  }
}

class _HourWindow {
  const _HourWindow({
    required this.startHour,
    required this.endHourExclusive,
    required this.revenueMinor,
    required this.orderCount,
  });

  final int startHour;
  final int endHourExclusive;
  final int revenueMinor;
  final int orderCount;
}
