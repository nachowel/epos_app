import '../../data/repositories/analytics_repository.dart';
import '../models/analytics/analytics_date_range.dart';
import '../models/analytics/analytics_revenue_preset.dart';
import '../models/analytics/daily_revenue_point.dart';
import '../models/analytics/revenue_detail_summary.dart';
import '../models/analytics/revenue_metrics.dart';

class AnalyticsRevenueService {
  const AnalyticsRevenueService({required AnalyticsRepository repository})
    : _repository = repository;

  final AnalyticsRepository _repository;

  Future<RevenueDetailSummary> getRevenueDetailSummary({
    required AnalyticsRevenuePreset preset,
    DateTime? now,
  }) async {
    final _RevenueRangeBundle bundle = _resolveRanges(
      preset: preset,
      now: now ?? DateTime.now(),
    );

    final RevenueMetrics currentMetrics = _normalizeMetrics(
      await _repository.getRevenueMetrics(bundle.currentRange),
    );
    final RevenueMetrics comparisonMetrics = _normalizeMetrics(
      await _repository.getRevenueMetrics(bundle.comparisonRange),
    );
    final List<DailyRevenuePoint> currentSeries = _fillMissingDays(
      range: bundle.currentRange,
      rawSeries: await _repository.getDailyRevenueSeries(bundle.currentRange),
    );

    final int comparisonDeltaRevenueMinor =
        currentMetrics.totalRevenueMinor - comparisonMetrics.totalRevenueMinor;

    return RevenueDetailSummary(
      preset: preset,
      totalRevenueMinor: currentMetrics.totalRevenueMinor,
      orderCount: currentMetrics.orderCount,
      averageOrderValueMinor: currentMetrics.averageOrderValueMinor,
      dailyRevenueSeries: currentSeries,
      comparisonLabel: analyticsRevenueComparisonLabel(preset),
      comparisonRevenueMinor: comparisonMetrics.totalRevenueMinor,
      comparisonOrderCount: comparisonMetrics.orderCount,
      comparisonAverageOrderValueMinor:
          comparisonMetrics.averageOrderValueMinor,
      comparisonDeltaRevenueMinor: comparisonDeltaRevenueMinor,
      comparisonDirection: _comparisonDirection(
        currentRevenueMinor: currentMetrics.totalRevenueMinor,
        comparisonRevenueMinor: comparisonMetrics.totalRevenueMinor,
        deltaRevenueMinor: comparisonDeltaRevenueMinor,
      ),
    );
  }

  _RevenueRangeBundle _resolveRanges({
    required AnalyticsRevenuePreset preset,
    required DateTime now,
  }) {
    final DateTime today = AnalyticsDateRange.startOfCivilDay(now);
    switch (preset) {
      case AnalyticsRevenuePreset.thisWeek:
        final DateTime weekStart = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        final AnalyticsDateRange currentRange = AnalyticsDateRange.explicit(
          startInclusive: weekStart,
          endExclusive: today.add(const Duration(days: 1)),
        );
        final int spanDays = currentRange.duration.inDays;
        return _RevenueRangeBundle(
          currentRange: currentRange,
          comparisonRange: AnalyticsDateRange.explicit(
            startInclusive: weekStart.subtract(Duration(days: spanDays)),
            endExclusive: weekStart,
          ),
        );
      case AnalyticsRevenuePreset.lastWeek:
        final DateTime thisWeekStart = today.subtract(
          Duration(days: today.weekday - DateTime.monday),
        );
        final DateTime lastWeekStart = thisWeekStart.subtract(
          const Duration(days: 7),
        );
        return _RevenueRangeBundle(
          currentRange: AnalyticsDateRange.explicit(
            startInclusive: lastWeekStart,
            endExclusive: thisWeekStart,
          ),
          comparisonRange: AnalyticsDateRange.explicit(
            startInclusive: lastWeekStart.subtract(const Duration(days: 7)),
            endExclusive: lastWeekStart,
          ),
        );
      case AnalyticsRevenuePreset.last2Weeks:
        final DateTime currentEnd = today.add(const Duration(days: 1));
        final DateTime currentStart = currentEnd.subtract(
          const Duration(days: 14),
        );
        return _RevenueRangeBundle(
          currentRange: AnalyticsDateRange.explicit(
            startInclusive: currentStart,
            endExclusive: currentEnd,
          ),
          comparisonRange: AnalyticsDateRange.explicit(
            startInclusive: currentStart.subtract(const Duration(days: 14)),
            endExclusive: currentStart,
          ),
        );
      case AnalyticsRevenuePreset.thisMonth:
        final DateTime monthStart = DateTime(today.year, today.month);
        final DateTime currentEnd = today.add(const Duration(days: 1));
        final int spanDays = currentEnd.difference(monthStart).inDays;
        final DateTime previousMonthStart = DateTime(
          monthStart.year,
          monthStart.month - 1,
        );
        final DateTime previousMonthEndExclusive = monthStart;
        final DateTime previousMonthCandidateEnd = previousMonthStart.add(
          Duration(days: spanDays),
        );
        return _RevenueRangeBundle(
          currentRange: AnalyticsDateRange.explicit(
            startInclusive: monthStart,
            endExclusive: currentEnd,
          ),
          comparisonRange: AnalyticsDateRange.explicit(
            startInclusive: previousMonthStart,
            endExclusive:
                previousMonthCandidateEnd.isAfter(previousMonthEndExclusive)
                ? previousMonthEndExclusive
                : previousMonthCandidateEnd,
          ),
        );
    }
  }

  RevenueMetrics _normalizeMetrics(RevenueMetrics metrics) {
    final int totalRevenueMinor = _normalizeRevenueMinor(
      metrics.totalRevenueMinor,
    );
    final int orderCount = _normalizeCount(metrics.orderCount);
    final int normalizedAov = orderCount == 0
        ? 0
        : _normalizeRevenueMinor(metrics.averageOrderValueMinor) > 0
        ? _normalizeRevenueMinor(metrics.averageOrderValueMinor)
        : totalRevenueMinor ~/ orderCount;

    return RevenueMetrics(
      totalRevenueMinor: totalRevenueMinor,
      orderCount: orderCount,
      averageOrderValueMinor: normalizedAov,
    );
  }

  List<DailyRevenuePoint> _fillMissingDays({
    required AnalyticsDateRange range,
    required List<DailyRevenuePoint> rawSeries,
  }) {
    final Map<DateTime, DailyRevenuePoint> pointsByDay =
        <DateTime, DailyRevenuePoint>{};
    for (final DailyRevenuePoint point in rawSeries) {
      final DateTime day = AnalyticsDateRange.startOfCivilDay(point.date);
      final DailyRevenuePoint existing =
          pointsByDay[day] ??
          DailyRevenuePoint(date: day, revenueMinor: 0, orderCount: 0);
      pointsByDay[day] = DailyRevenuePoint(
        date: day,
        revenueMinor:
            _normalizeRevenueMinor(existing.revenueMinor) +
            _normalizeRevenueMinor(point.revenueMinor),
        orderCount:
            _normalizeCount(existing.orderCount) +
            _normalizeCount(point.orderCount),
      );
    }

    final int dayCount = range.duration.inDays;
    return List<DailyRevenuePoint>.generate(dayCount, (int index) {
      final DateTime day = range.startInclusive.add(Duration(days: index));
      return pointsByDay[day] ??
          DailyRevenuePoint(date: day, revenueMinor: 0, orderCount: 0);
    }, growable: false);
  }

  RevenueComparisonDirection _comparisonDirection({
    required int currentRevenueMinor,
    required int comparisonRevenueMinor,
    required int deltaRevenueMinor,
  }) {
    if (currentRevenueMinor == 0 && comparisonRevenueMinor == 0) {
      return RevenueComparisonDirection.none;
    }
    if (deltaRevenueMinor > 0) {
      return RevenueComparisonDirection.up;
    }
    if (deltaRevenueMinor < 0) {
      return RevenueComparisonDirection.down;
    }
    return RevenueComparisonDirection.flat;
  }

  int _normalizeRevenueMinor(int value) => value < 0 ? 0 : value;

  int _normalizeCount(int value) => value < 0 ? 0 : value;
}

class _RevenueRangeBundle {
  const _RevenueRangeBundle({
    required this.currentRange,
    required this.comparisonRange,
  });

  final AnalyticsDateRange currentRange;
  final AnalyticsDateRange comparisonRange;
}
