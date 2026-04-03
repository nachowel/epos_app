import 'package:intl/intl.dart';

import '../../core/errors/exceptions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/revenue_analytics_repository.dart';
import '../models/analytics/analytics_period.dart';
import '../models/analytics/insight.dart';
import '../models/daily_revenue_point.dart';
import '../models/hourly_distribution.dart';
import '../models/revenue_comparison.dart';
import '../models/revenue_intelligence_inputs.dart';
import '../models/revenue_insights.dart';
import '../models/revenue_summary.dart';
import '../models/user.dart';
import '../models/weekly_revenue_point.dart';

class RevenueAnalyticsService {
  const RevenueAnalyticsService({
    required RevenueAnalyticsRepository repository,
  }) : _repository = repository;

  final RevenueAnalyticsRepository _repository;

  Future<RevenueSummary> getRevenueSummary({
    required User user,
    AnalyticsPeriodSelection? periodSelection,
  }) async {
    _ensureAdmin(user);

    final RevenueAnalyticsSnapshot snapshot = switch (periodSelection) {
      final AnalyticsPeriodSelection selection => await _repository
          .fetchAnalytics(selection: selection),
      null => await _repository.fetchRevenueAnalytics(),
    };
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
    final List<RevenueDaypartPoint> daypartDistribution =
        snapshot.daypartDistribution
            .map(
              (RevenueAnalyticsDaypartPoint point) => RevenueDaypartPoint(
                daypart: point.daypart,
                orderCount: point.orderCount,
                revenueMinor: point.revenueMinor,
              ),
            )
            .toList(growable: false)
          ..sort(
            (RevenueDaypartPoint left, RevenueDaypartPoint right) =>
                _daypartSortKey(
                  left.daypart,
                ).compareTo(_daypartSortKey(right.daypart)),
          );
    final List<RevenueProductMover> topProductsCurrentPeriod = snapshot
        .topProductsCurrentPeriod
        .map(
          (RevenueAnalyticsTopProductPoint point) => RevenueProductMover(
            productKey: point.productKey,
            productName: point.productName,
            quantitySold: point.quantitySold,
            revenueMinor: point.revenueMinor,
          ),
        )
        .toList(growable: false);
    final List<RevenueProductMover> topProductsPreviousPeriod = snapshot
        .topProductsPreviousPeriod
        .map(
          (RevenueAnalyticsTopProductPoint point) => RevenueProductMover(
            productKey: point.productKey,
            productName: point.productName,
            quantitySold: point.quantitySold,
            revenueMinor: point.revenueMinor,
          ),
        )
        .toList(growable: false);

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
      currentValue:
          snapshot.thisWeekAverageOrderValueMinor ??
          _averageOrderValueMinor(
            snapshot.thisWeekRevenueMinor,
            snapshot.thisWeekOrderCount,
          ),
      previousValue:
          snapshot.lastWeekAverageOrderValueMinor ??
          _averageOrderValueMinor(
            snapshot.lastWeekRevenueMinor,
            snapshot.lastWeekOrderCount,
          ),
      metricFormat: RevenueMetricFormat.currencyMinor,
    );
    final RevenueIntelligenceInputs intelligenceInputs =
        RevenueIntelligenceInputs(
          todayOrderCount: RevenueComparison(
            currentValue:
                snapshot.todayOrderCount ?? _orderCountAtOffset(dailyTrend, 0),
            previousValue:
                snapshot.yesterdayOrderCount ??
                _orderCountAtOffset(dailyTrend, 1),
            metricFormat: RevenueMetricFormat.count,
          ),
          monthOrderCount: RevenueComparison(
            currentValue: snapshot.thisMonthOrderCount ?? 0,
            previousValue: snapshot.lastMonthOrderCount ?? 0,
            metricFormat: RevenueMetricFormat.count,
          ),
          averageOrderValueThisWeek: averageOrderValueCurrentWeek,
          averageOrderValueThisMonth: RevenueComparison(
            currentValue:
                snapshot.thisMonthAverageOrderValueMinor ??
                _averageOrderValueMinor(
                  snapshot.thisMonthRevenueMinor,
                  snapshot.thisMonthOrderCount ?? 0,
                ),
            previousValue:
                snapshot.lastMonthAverageOrderValueMinor ??
                _averageOrderValueMinor(
                  snapshot.lastMonthRevenueMinor,
                  snapshot.lastMonthOrderCount ?? 0,
                ),
            metricFormat: RevenueMetricFormat.currencyMinor,
          ),
          thisWeekPaymentMix: RevenuePaymentMixComparison(
            cashRevenue: RevenueComparison(
              currentValue: snapshot.thisWeekCashRevenueMinor ?? 0,
              previousValue: snapshot.lastWeekCashRevenueMinor ?? 0,
              metricFormat: RevenueMetricFormat.currencyMinor,
            ),
            cardRevenue: RevenueComparison(
              currentValue: snapshot.thisWeekCardRevenueMinor ?? 0,
              previousValue: snapshot.lastWeekCardRevenueMinor ?? 0,
              metricFormat: RevenueMetricFormat.currencyMinor,
            ),
          ),
          thisMonthPaymentMix: RevenuePaymentMixComparison(
            cashRevenue: RevenueComparison(
              currentValue: snapshot.thisMonthCashRevenueMinor ?? 0,
              previousValue: snapshot.lastMonthCashRevenueMinor ?? 0,
              metricFormat: RevenueMetricFormat.currencyMinor,
            ),
            cardRevenue: RevenueComparison(
              currentValue: snapshot.thisMonthCardRevenueMinor ?? 0,
              previousValue: snapshot.lastMonthCardRevenueMinor ?? 0,
              metricFormat: RevenueMetricFormat.currencyMinor,
            ),
          ),
          thisWeekCancelledOrderCount: RevenueComparison(
            currentValue: snapshot.thisWeekCancelledOrderCount ?? 0,
            previousValue: snapshot.lastWeekCancelledOrderCount ?? 0,
            metricFormat: RevenueMetricFormat.count,
          ),
          thisMonthCancelledOrderCount: RevenueComparison(
            currentValue: snapshot.thisMonthCancelledOrderCount ?? 0,
            previousValue: snapshot.lastMonthCancelledOrderCount ?? 0,
            metricFormat: RevenueMetricFormat.count,
          ),
          daypartDistribution: daypartDistribution,
          topProductsCurrentPeriod: topProductsCurrentPeriod,
          topProductsPreviousPeriod: topProductsPreviousPeriod,
          dataQualityNotes: snapshot.dataQualityNotes,
        );
    final RevenueSelectedPeriodSummary selectedPeriodSummary =
        _buildSelectedPeriodSummary(
          snapshot: snapshot,
          requestedSelection: periodSelection,
          dailyTrend: dailyTrend,
          intelligenceInputs: intelligenceInputs,
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
        selectedPeriodSummary: selectedPeriodSummary,
        dailyTrend: dailyTrend,
        hourlyDistribution: hourlyDistribution,
        intelligenceInputs: intelligenceInputs,
      ),
      intelligenceInputs: intelligenceInputs,
      selectedPeriodSummary: selectedPeriodSummary,
    );
  }

  RevenueSelectedPeriodSummary _buildSelectedPeriodSummary({
    required RevenueAnalyticsSnapshot snapshot,
    required AnalyticsPeriodSelection? requestedSelection,
    required List<DailyRevenuePoint> dailyTrend,
    required RevenueIntelligenceInputs intelligenceInputs,
  }) {
    final AnalyticsPeriodSelection resolvedSelection =
        snapshot.periodWindow?.selection ??
        requestedSelection ??
        const AnalyticsPeriodSelection.preset(AnalyticsPresetPeriod.thisWeek);
    final DateTime startDate =
        snapshot.periodWindow?.startDate ??
        (dailyTrend.isEmpty ? snapshot.generatedAt : dailyTrend.first.date);
    final DateTime endDate =
        snapshot.periodWindow?.endDate ??
        (dailyTrend.isEmpty ? snapshot.generatedAt : dailyTrend.last.date);
    final DateTime comparisonStartDate =
        snapshot.comparisonWindow?.startDate ?? startDate.subtract(const Duration(days: 1));
    final DateTime comparisonEndDate =
        snapshot.comparisonWindow?.endDate ?? startDate.subtract(const Duration(days: 1));
    final int dayCount =
        snapshot.periodWindow?.dayCount ??
        (dailyTrend.isEmpty ? 1 : dailyTrend.length);

    return RevenueSelectedPeriodSummary(
      selection: resolvedSelection,
      startDate: startDate,
      endDate: endDate,
      comparisonStartDate: comparisonStartDate,
      comparisonEndDate: comparisonEndDate,
      dayCount: dayCount,
      revenue: RevenueComparison(
        currentValue:
            snapshot.periodRevenueMinor ??
            _fallbackRevenueCurrent(snapshot, resolvedSelection),
        previousValue:
            snapshot.previousPeriodRevenueMinor ??
            _fallbackRevenuePrevious(snapshot, resolvedSelection),
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      orderCount: RevenueComparison(
        currentValue:
            snapshot.periodOrderCount ??
            _fallbackOrderCurrent(snapshot, resolvedSelection, intelligenceInputs),
        previousValue:
            snapshot.previousPeriodOrderCount ??
            _fallbackOrderPrevious(snapshot, resolvedSelection, intelligenceInputs),
        metricFormat: RevenueMetricFormat.count,
      ),
      averageOrderValue: RevenueComparison(
        currentValue:
            snapshot.periodAverageOrderValueMinor ??
            _fallbackAverageOrderCurrent(
              snapshot,
              resolvedSelection,
              intelligenceInputs,
            ),
        previousValue:
            snapshot.previousPeriodAverageOrderValueMinor ??
            _fallbackAverageOrderPrevious(
              snapshot,
              resolvedSelection,
              intelligenceInputs,
            ),
        metricFormat: RevenueMetricFormat.currencyMinor,
      ),
      cancelledOrderCount: RevenueComparison(
        currentValue:
            snapshot.periodCancelledOrderCount ??
            _fallbackCancelledCurrent(snapshot, resolvedSelection, intelligenceInputs),
        previousValue:
            snapshot.previousPeriodCancelledOrderCount ??
            _fallbackCancelledPrevious(snapshot, resolvedSelection, intelligenceInputs),
        metricFormat: RevenueMetricFormat.count,
      ),
      paymentMix: RevenuePaymentMixComparison(
        cashRevenue: RevenueComparison(
          currentValue:
              snapshot.periodCashRevenueMinor ??
              _fallbackCashCurrent(snapshot, resolvedSelection, intelligenceInputs),
          previousValue:
              snapshot.previousPeriodCashRevenueMinor ??
              _fallbackCashPrevious(snapshot, resolvedSelection, intelligenceInputs),
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
        cardRevenue: RevenueComparison(
          currentValue:
              snapshot.periodCardRevenueMinor ??
              _fallbackCardCurrent(snapshot, resolvedSelection, intelligenceInputs),
          previousValue:
              snapshot.previousPeriodCardRevenueMinor ??
              _fallbackCardPrevious(snapshot, resolvedSelection, intelligenceInputs),
          metricFormat: RevenueMetricFormat.currencyMinor,
        ),
      ),
    );
  }

  RevenueInsights _buildInsights({
    required RevenueSelectedPeriodSummary selectedPeriodSummary,
    required List<DailyRevenuePoint> dailyTrend,
    required List<HourlyDistribution> hourlyDistribution,
    required RevenueIntelligenceInputs intelligenceInputs,
  }) {
    final String weeklyPerformance = _buildPeriodPerformanceMessage(
      selectedPeriodSummary.label,
      selectedPeriodSummary.revenue,
    );
    final String revenueMomentum = _buildRevenueMomentumMessage(dailyTrend);
    final String strongestDay = _buildStrongestDayMessage(dailyTrend);
    final String weakestDay = _buildWeakestDayMessage(dailyTrend);
    final String peakHours = _buildPeakHoursMessage(hourlyDistribution);
    final String lowHours = _buildLowHoursMessage(hourlyDistribution);
    final String topHourConcentration = _buildTopHourConcentrationMessage(
      hourlyDistribution,
    );
    final String distributionBalance = _buildDistributionBalanceMessage(
      hourlyDistribution,
    );

    return RevenueInsights(
      weeklyPerformance: weeklyPerformance,
      revenueMomentum: revenueMomentum,
      strongestDay: strongestDay,
      weakestDay: weakestDay,
      peakHours: peakHours,
      lowHours: lowHours,
      topHourConcentration: topHourConcentration,
      distributionBalance: distributionBalance,
      structuredInsights: _buildStructuredInsights(
        selectedPeriodSummary: selectedPeriodSummary,
        dailyTrend: dailyTrend,
        hourlyDistribution: hourlyDistribution,
        intelligenceInputs: intelligenceInputs,
        weeklyPerformance: weeklyPerformance,
        revenueMomentum: revenueMomentum,
        strongestDay: strongestDay,
        weakestDay: weakestDay,
        peakHours: peakHours,
        lowHours: lowHours,
        topHourConcentration: topHourConcentration,
        distributionBalance: distributionBalance,
      ),
    );
  }

  String _buildPeriodPerformanceMessage(
    String periodLabel,
    RevenueComparison comparison,
  ) {
    final String normalizedLabel = periodLabel.toLowerCase();
    final double? change = comparison.percentageChange;
    if (change == null) {
      return comparison.currentValue == 0
          ? '$periodLabel is flat versus the previous equivalent period.'
          : '$periodLabel is higher than the previous equivalent period, which had no paid revenue.';
    }
    if (comparison.isFlat) {
      return '$periodLabel is flat versus the previous equivalent period.';
    }
    final String direction = change > 0 ? 'higher' : 'lower';
    return '$normalizedLabel is ${change.abs().toStringAsFixed(1)}% $direction than the previous equivalent period.';
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

  List<Insight> _buildStructuredInsights({
    required RevenueSelectedPeriodSummary selectedPeriodSummary,
    required List<DailyRevenuePoint> dailyTrend,
    required List<HourlyDistribution> hourlyDistribution,
    required RevenueIntelligenceInputs intelligenceInputs,
    required String weeklyPerformance,
    required String revenueMomentum,
    required String strongestDay,
    required String weakestDay,
    required String peakHours,
    required String lowHours,
    required String topHourConcentration,
    required String distributionBalance,
  }) {
    final String periodLabel = selectedPeriodSummary.label;
    final String periodTitlePrefix = selectedPeriodSummary.selection.isCustom
        ? 'Selected Period'
        : periodLabel;
    return <Insight>[
      _buildDeltaInsight(
        code: 'period_revenue_delta',
        title: '$periodTitlePrefix Revenue',
        message: weeklyPerformance,
        comparison: selectedPeriodSummary.revenue,
        higherIsBetter: true,
      ),
      _buildMomentumInsight(dailyTrend: dailyTrend, message: revenueMomentum),
      _buildStrongestDayInsight(dailyTrend: dailyTrend, message: strongestDay),
      _buildWeakestDayInsight(dailyTrend: dailyTrend, message: weakestDay),
      _buildPeakHoursInsight(
        hourlyDistribution: hourlyDistribution,
        message: peakHours,
      ),
      _buildLowHoursInsight(
        hourlyDistribution: hourlyDistribution,
        message: lowHours,
      ),
      _buildConcentrationInsight(
        hourlyDistribution: hourlyDistribution,
        message: topHourConcentration,
      ),
      _buildDistributionBalanceInsight(
        hourlyDistribution: hourlyDistribution,
        message: distributionBalance,
      ),
      _buildDeltaInsight(
        code: 'period_order_count_delta',
        title: '$periodTitlePrefix Order Count',
        message: _buildComparisonMessage(
          label: '$periodTitlePrefix order count',
          comparison: selectedPeriodSummary.orderCount,
          higherIsBetter: true,
          format: RevenueMetricFormat.count,
        ),
        comparison: selectedPeriodSummary.orderCount,
        higherIsBetter: true,
      ),
      _buildDeltaInsight(
        code: 'monthly_order_count_delta',
        title: 'Monthly Order Count',
        message: _buildComparisonMessage(
          label: 'This month order count',
          comparison: intelligenceInputs.monthOrderCount,
          higherIsBetter: true,
          format: RevenueMetricFormat.count,
        ),
        comparison: intelligenceInputs.monthOrderCount,
        higherIsBetter: true,
      ),
      _buildDeltaInsight(
        code: 'period_average_order_value_delta',
        title: '$periodTitlePrefix Average Order Value',
        message: _buildComparisonMessage(
          label: 'Average order value for $periodLabel',
          comparison: selectedPeriodSummary.averageOrderValue,
          higherIsBetter: true,
          format: RevenueMetricFormat.currencyMinor,
        ),
        comparison: selectedPeriodSummary.averageOrderValue,
        higherIsBetter: true,
      ),
      _buildDeltaInsight(
        code: 'monthly_average_order_value_delta',
        title: 'Monthly Average Order Value',
        message: _buildComparisonMessage(
          label: 'Average order value this month',
          comparison: intelligenceInputs.averageOrderValueThisMonth,
          higherIsBetter: true,
          format: RevenueMetricFormat.currencyMinor,
        ),
        comparison: intelligenceInputs.averageOrderValueThisMonth,
        higherIsBetter: true,
      ),
      _buildPaymentMixInsight(
        code: 'period_payment_mix',
        title: '$periodTitlePrefix Payment Mix',
        mix: selectedPeriodSummary.paymentMix,
      ),
      _buildPaymentMixInsight(
        code: 'monthly_payment_mix',
        title: 'Monthly Payment Mix',
        mix: intelligenceInputs.thisMonthPaymentMix,
      ),
      _buildDeltaInsight(
        code: 'period_cancelled_order_delta',
        title: '$periodTitlePrefix Cancelled Orders',
        message: _buildComparisonMessage(
          label: 'Cancelled orders for $periodLabel',
          comparison: selectedPeriodSummary.cancelledOrderCount,
          higherIsBetter: false,
          format: RevenueMetricFormat.count,
        ),
        comparison: selectedPeriodSummary.cancelledOrderCount,
        higherIsBetter: false,
      ),
      _buildDeltaInsight(
        code: 'monthly_cancelled_order_delta',
        title: 'Monthly Cancelled Orders',
        message: _buildComparisonMessage(
          label: 'Cancelled orders this month',
          comparison: intelligenceInputs.thisMonthCancelledOrderCount,
          higherIsBetter: false,
          format: RevenueMetricFormat.count,
        ),
        comparison: intelligenceInputs.thisMonthCancelledOrderCount,
        higherIsBetter: false,
      ),
      _buildDaypartInsight(intelligenceInputs.daypartDistribution),
      _buildTopProductInsight(
        currentPeriod: intelligenceInputs.topProductsCurrentPeriod,
        previousPeriod: intelligenceInputs.topProductsPreviousPeriod,
      ),
      ..._buildDataQualityInsights(intelligenceInputs.dataQualityNotes),
    ];
  }

  Insight _buildDeltaInsight({
    required String code,
    required String title,
    required String message,
    required RevenueComparison comparison,
    required bool higherIsBetter,
  }) {
    return Insight(
      code: code,
      severity: _comparisonSeverity(
        comparison: comparison,
        higherIsBetter: higherIsBetter,
      ),
      title: title,
      message: message,
      evidence: <String, dynamic>{
        'current_value': comparison.currentValue,
        'previous_value': comparison.previousValue,
        'absolute_change': comparison.absoluteChange,
        'percentage_change': _roundedPercentage(comparison.percentageChange),
        'higher_is_better': higherIsBetter,
      },
    );
  }

  Insight _buildMomentumInsight({
    required List<DailyRevenuePoint> dailyTrend,
    required String message,
  }) {
    final int splitIndex = (dailyTrend.length / 2).floor();
    final int firstHalfRevenue = dailyTrend
        .take(splitIndex)
        .fold<int>(
          0,
          (int sum, DailyRevenuePoint point) => sum + point.revenueMinor,
        );
    final int secondHalfRevenue = dailyTrend
        .skip(splitIndex)
        .fold<int>(
          0,
          (int sum, DailyRevenuePoint point) => sum + point.revenueMinor,
        );
    final RevenueComparison comparison = RevenueComparison(
      currentValue: secondHalfRevenue,
      previousValue: firstHalfRevenue,
      metricFormat: RevenueMetricFormat.currencyMinor,
    );
    return Insight(
      code: 'revenue_momentum_14d',
      severity: _comparisonSeverity(
        comparison: comparison,
        higherIsBetter: true,
      ),
      title: '14-Day Revenue Momentum',
      message: message,
      evidence: <String, dynamic>{
        'window_days': dailyTrend.length,
        'first_half_revenue_minor': firstHalfRevenue,
        'second_half_revenue_minor': secondHalfRevenue,
        'percentage_change': _roundedPercentage(comparison.percentageChange),
      },
    );
  }

  Insight _buildStrongestDayInsight({
    required List<DailyRevenuePoint> dailyTrend,
    required String message,
  }) {
    final DailyRevenuePoint? strongest = _selectStrongestDay(dailyTrend);
    return Insight(
      code: 'strongest_day',
      severity: strongest == null
          ? InsightSeverity.info
          : InsightSeverity.positive,
      title: 'Strongest Day',
      message: message,
      evidence: <String, dynamic>{
        'date': strongest?.date.toIso8601String(),
        'revenue_minor': strongest?.revenueMinor ?? 0,
        'order_count': strongest?.orderCount ?? 0,
      },
    );
  }

  Insight _buildWeakestDayInsight({
    required List<DailyRevenuePoint> dailyTrend,
    required String message,
  }) {
    final DailyRevenuePoint? weakest = _selectWeakestDay(dailyTrend);
    return Insight(
      code: 'weakest_day',
      severity: weakest == null || weakest.revenueMinor == 0
          ? InsightSeverity.warning
          : InsightSeverity.info,
      title: 'Weakest Day',
      message: message,
      evidence: <String, dynamic>{
        'date': weakest?.date.toIso8601String(),
        'revenue_minor': weakest?.revenueMinor ?? 0,
        'order_count': weakest?.orderCount ?? 0,
      },
    );
  }

  Insight _buildPeakHoursInsight({
    required List<HourlyDistribution> hourlyDistribution,
    required String message,
  }) {
    final _HourWindow? window = _selectHourWindow(
      hourlyDistribution,
      preferPeak: true,
    );
    final int totalRevenue = _totalHourlyRevenue(hourlyDistribution);
    final double share = window == null || totalRevenue == 0
        ? 0
        : (window.revenueMinor / totalRevenue) * 100;
    return Insight(
      code: 'peak_hours',
      severity: window == null || window.revenueMinor == 0
          ? InsightSeverity.info
          : InsightSeverity.positive,
      title: 'Peak Hours',
      message: message,
      evidence: <String, dynamic>{
        'start_hour': window?.startHour,
        'end_hour_exclusive': window?.endHourExclusive,
        'revenue_minor': window?.revenueMinor ?? 0,
        'order_count': window?.orderCount ?? 0,
        'revenue_share_percent': double.parse(share.toStringAsFixed(1)),
      },
    );
  }

  Insight _buildLowHoursInsight({
    required List<HourlyDistribution> hourlyDistribution,
    required String message,
  }) {
    final _HourWindow? window = _selectHourWindow(
      hourlyDistribution,
      preferPeak: false,
    );
    return Insight(
      code: 'low_hours',
      severity: window == null ? InsightSeverity.info : InsightSeverity.warning,
      title: 'Low Hours',
      message: message,
      evidence: <String, dynamic>{
        'start_hour': window?.startHour,
        'end_hour_exclusive': window?.endHourExclusive,
        'revenue_minor': window?.revenueMinor ?? 0,
        'order_count': window?.orderCount ?? 0,
      },
    );
  }

  Insight _buildConcentrationInsight({
    required List<HourlyDistribution> hourlyDistribution,
    required String message,
  }) {
    final int totalRevenue = _totalHourlyRevenue(hourlyDistribution);
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
    final double share = totalRevenue == 0
        ? 0
        : (topHourRevenue / totalRevenue) * 100;
    return Insight(
      code: 'top_hour_concentration',
      severity: share >= 70
          ? InsightSeverity.warning
          : share >= 55
          ? InsightSeverity.info
          : InsightSeverity.positive,
      title: 'Top Hour Concentration',
      message: message,
      evidence: <String, dynamic>{
        'top_hour_count': topHourCount,
        'top_hour_revenue_minor': topHourRevenue,
        'total_revenue_minor': totalRevenue,
        'revenue_share_percent': double.parse(share.toStringAsFixed(1)),
      },
    );
  }

  Insight _buildDistributionBalanceInsight({
    required List<HourlyDistribution> hourlyDistribution,
    required String message,
  }) {
    final int totalRevenue = _totalHourlyRevenue(hourlyDistribution);
    final int populatedHours = hourlyDistribution
        .where((HourlyDistribution point) => point.revenueMinor > 0)
        .length;
    return Insight(
      code: 'distribution_balance',
      severity: totalRevenue == 0
          ? InsightSeverity.info
          : populatedHours <= 3
          ? InsightSeverity.warning
          : InsightSeverity.positive,
      title: 'Distribution Balance',
      message: message,
      evidence: <String, dynamic>{
        'populated_hours': populatedHours,
        'total_hours': hourlyDistribution.length,
        'total_revenue_minor': totalRevenue,
      },
    );
  }

  Insight _buildPaymentMixInsight({
    required String code,
    required String title,
    required RevenuePaymentMixComparison mix,
  }) {
    final int currentCash = mix.cashRevenue.currentValue;
    final int currentCard = mix.cardRevenue.currentValue;
    final int totalCurrent = currentCash + currentCard;
    final double cashShare = totalCurrent == 0
        ? 0
        : (currentCash / totalCurrent) * 100;
    final double cardShare = totalCurrent == 0
        ? 0
        : (currentCard / totalCurrent) * 100;
    final String message = totalCurrent == 0
        ? '$title is unavailable because there is no mirrored payment revenue for this period.'
        : '$title is ${cashShare.toStringAsFixed(1)}% cash and ${cardShare.toStringAsFixed(1)}% card.';
    return Insight(
      code: code,
      severity: totalCurrent == 0
          ? InsightSeverity.info
          : cashShare >= 85 || cardShare >= 85
          ? InsightSeverity.warning
          : InsightSeverity.info,
      title: title,
      message: message,
      evidence: <String, dynamic>{
        'cash_revenue_minor': currentCash,
        'card_revenue_minor': currentCard,
        'cash_share_percent': double.parse(cashShare.toStringAsFixed(1)),
        'card_share_percent': double.parse(cardShare.toStringAsFixed(1)),
        'previous_cash_revenue_minor': mix.cashRevenue.previousValue,
        'previous_card_revenue_minor': mix.cardRevenue.previousValue,
      },
    );
  }

  Insight _buildDaypartInsight(List<RevenueDaypartPoint> daypartDistribution) {
    if (daypartDistribution.isEmpty) {
      return const Insight(
        code: 'daypart_distribution',
        severity: InsightSeverity.info,
        title: 'Daypart Pattern',
        message:
            'Daypart pattern is unavailable because no daypart revenue buckets were returned.',
        evidence: <String, dynamic>{'bucket_count': 0},
      );
    }

    RevenueDaypartPoint strongest = daypartDistribution.first;
    RevenueDaypartPoint weakest = daypartDistribution.first;
    for (final RevenueDaypartPoint point in daypartDistribution.skip(1)) {
      if (point.revenueMinor > strongest.revenueMinor ||
          (point.revenueMinor == strongest.revenueMinor &&
              point.orderCount > strongest.orderCount)) {
        strongest = point;
      }
      if (point.revenueMinor < weakest.revenueMinor ||
          (point.revenueMinor == weakest.revenueMinor &&
              point.orderCount < weakest.orderCount)) {
        weakest = point;
      }
    }

    return Insight(
      code: 'daypart_distribution',
      severity: strongest.revenueMinor == 0
          ? InsightSeverity.info
          : InsightSeverity.positive,
      title: 'Daypart Pattern',
      message:
          'Strongest daypart is ${strongest.daypart} and weakest daypart is ${weakest.daypart}.',
      evidence: <String, dynamic>{
        'strongest_daypart': strongest.daypart,
        'strongest_revenue_minor': strongest.revenueMinor,
        'strongest_order_count': strongest.orderCount,
        'weakest_daypart': weakest.daypart,
        'weakest_revenue_minor': weakest.revenueMinor,
        'weakest_order_count': weakest.orderCount,
      },
    );
  }

  Insight _buildTopProductInsight({
    required List<RevenueProductMover> currentPeriod,
    required List<RevenueProductMover> previousPeriod,
  }) {
    final RevenueProductMover? currentLeader = currentPeriod.isEmpty
        ? null
        : currentPeriod.first;
    final RevenueProductMover? previousLeader = previousPeriod.isEmpty
        ? null
        : previousPeriod.first;
    final String message = currentLeader == null
        ? 'Top product movers are unavailable because no mirrored product sales were returned for the comparison periods.'
        : previousLeader == null
        ? 'Top current product is ${currentLeader.productName} with ${CurrencyFormatter.fromMinor(currentLeader.revenueMinor)}.'
        : currentLeader.productKey == previousLeader.productKey
        ? 'Top current product remains ${currentLeader.productName}.'
        : 'Top current product is ${currentLeader.productName}, replacing ${previousLeader.productName}.';
    return Insight(
      code: 'top_product_current_period',
      severity: currentLeader == null
          ? InsightSeverity.info
          : previousLeader != null &&
                currentLeader.productKey == previousLeader.productKey
          ? InsightSeverity.positive
          : InsightSeverity.info,
      title: 'Top Product Mover',
      message: message,
      evidence: <String, dynamic>{
        'current_product_key': currentLeader?.productKey,
        'current_product_name': currentLeader?.productName,
        'current_quantity_sold': currentLeader?.quantitySold ?? 0,
        'current_revenue_minor': currentLeader?.revenueMinor ?? 0,
        'previous_product_key': previousLeader?.productKey,
        'previous_product_name': previousLeader?.productName,
        'previous_quantity_sold': previousLeader?.quantitySold ?? 0,
        'previous_revenue_minor': previousLeader?.revenueMinor ?? 0,
      },
    );
  }

  List<Insight> _buildDataQualityInsights(List<String> notes) {
    return notes
        .map<Insight>((String note) {
          return switch (note) {
            'refunds not available in remote analytics' => Insight(
              code: 'data_quality_refunds_unavailable',
              severity: InsightSeverity.info,
              title: 'Data Quality',
              message: note,
              evidence: <String, dynamic>{'note': note},
            ),
            'true shift intelligence unavailable because shifts are not mirrored' =>
              Insight(
                code: 'data_quality_shift_intelligence_unavailable',
                severity: InsightSeverity.info,
                title: 'Data Quality',
                message: note,
                evidence: <String, dynamic>{'note': note},
              ),
            'product mover aggregation is name-based because stable mirrored product identifiers were unavailable for part of the dataset' =>
              Insight(
                code: 'data_quality_product_movers_name_based',
                severity: InsightSeverity.warning,
                title: 'Data Quality',
                message: note,
                evidence: <String, dynamic>{'note': note},
              ),
            'cancelled attribution unavailable for some mirror rows because reliable cancelled_at was missing' =>
              Insight(
                code: 'data_quality_cancelled_at_missing',
                severity: InsightSeverity.warning,
                title: 'Data Quality',
                message: note,
                evidence: <String, dynamic>{'note': note},
              ),
            'cancelled attribution unavailable for some mirror rows because cancelled_at was invalid' =>
              Insight(
                code: 'data_quality_cancelled_at_invalid',
                severity: InsightSeverity.warning,
                title: 'Data Quality',
                message: note,
                evidence: <String, dynamic>{'note': note},
              ),
            _ => Insight(
              code: 'data_quality_generic',
              severity: InsightSeverity.warning,
              title: 'Data Quality',
              message: note,
              evidence: <String, dynamic>{'note': note},
            ),
          };
        })
        .toList(growable: false);
  }

  String _buildComparisonMessage({
    required String label,
    required RevenueComparison comparison,
    required bool higherIsBetter,
    required RevenueMetricFormat format,
  }) {
    final String current = _formatMetric(comparison.currentValue, format);
    final String previous = _formatMetric(comparison.previousValue, format);
    final double? percentageChange = comparison.percentageChange;
    if (percentageChange == null) {
      return comparison.currentValue == 0
          ? '$label is $current with no previous-period activity.'
          : '$label is $current versus $previous in the previous period.';
    }
    if (comparison.isFlat) {
      return '$label is flat at $current versus $previous.';
    }
    final String direction = comparison.absoluteChange > 0
        ? (higherIsBetter ? 'up' : 'higher')
        : (higherIsBetter ? 'down' : 'lower');
    return '$label is $direction ${percentageChange.abs().toStringAsFixed(1)}% at $current versus $previous.';
  }

  InsightSeverity _comparisonSeverity({
    required RevenueComparison comparison,
    required bool higherIsBetter,
  }) {
    if (comparison.absoluteChange == 0) {
      return InsightSeverity.info;
    }
    final bool isPositiveOutcome = higherIsBetter
        ? comparison.absoluteChange > 0
        : comparison.absoluteChange < 0;
    final double? percentageChange = comparison.percentageChange;
    if (percentageChange == null) {
      return isPositiveOutcome
          ? InsightSeverity.positive
          : InsightSeverity.negative;
    }
    final double magnitude = percentageChange.abs();
    if (magnitude < 3) {
      return InsightSeverity.info;
    }
    if (isPositiveOutcome) {
      return magnitude >= 10 ? InsightSeverity.positive : InsightSeverity.info;
    }
    return magnitude >= 10 ? InsightSeverity.negative : InsightSeverity.warning;
  }

  DailyRevenuePoint? _selectStrongestDay(List<DailyRevenuePoint> dailyTrend) {
    if (dailyTrend.isEmpty || _totalDailyRevenue(dailyTrend) == 0) {
      return null;
    }
    DailyRevenuePoint strongest = dailyTrend.first;
    for (final DailyRevenuePoint point in dailyTrend.skip(1)) {
      if (point.revenueMinor > strongest.revenueMinor ||
          (point.revenueMinor == strongest.revenueMinor &&
              point.orderCount > strongest.orderCount)) {
        strongest = point;
      }
    }
    return strongest;
  }

  DailyRevenuePoint? _selectWeakestDay(List<DailyRevenuePoint> dailyTrend) {
    if (dailyTrend.isEmpty) {
      return null;
    }
    DailyRevenuePoint weakest = dailyTrend.first;
    for (final DailyRevenuePoint point in dailyTrend.skip(1)) {
      if (point.revenueMinor < weakest.revenueMinor ||
          (point.revenueMinor == weakest.revenueMinor &&
              point.orderCount < weakest.orderCount)) {
        weakest = point;
      }
    }
    return weakest;
  }

  int _fallbackRevenueCurrent(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.today => snapshot.todayRevenueMinor,
      AnalyticsPresetPeriod.thisMonth => snapshot.thisMonthRevenueMinor,
      AnalyticsPresetPeriod.thisWeek || AnalyticsPresetPeriod.last14Days || null =>
        snapshot.thisWeekRevenueMinor,
    };
  }

  int _fallbackRevenuePrevious(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.today => snapshot.yesterdayRevenueMinor,
      AnalyticsPresetPeriod.thisMonth => snapshot.lastMonthRevenueMinor,
      AnalyticsPresetPeriod.thisWeek || AnalyticsPresetPeriod.last14Days || null =>
        snapshot.lastWeekRevenueMinor,
    };
  }

  int _fallbackOrderCurrent(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.today => intelligenceInputs.todayOrderCount.currentValue,
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.monthOrderCount.currentValue,
      AnalyticsPresetPeriod.thisWeek || AnalyticsPresetPeriod.last14Days || null =>
        snapshot.thisWeekOrderCount,
    };
  }

  int _fallbackOrderPrevious(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.today => intelligenceInputs.todayOrderCount.previousValue,
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.monthOrderCount.previousValue,
      AnalyticsPresetPeriod.thisWeek || AnalyticsPresetPeriod.last14Days || null =>
        snapshot.lastWeekOrderCount,
    };
  }

  int _fallbackAverageOrderCurrent(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.today =>
        _averageOrderValueMinor(
          snapshot.todayRevenueMinor,
          intelligenceInputs.todayOrderCount.currentValue,
        ),
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.averageOrderValueThisMonth.currentValue,
      AnalyticsPresetPeriod.thisWeek || AnalyticsPresetPeriod.last14Days || null =>
        intelligenceInputs.averageOrderValueThisWeek.currentValue,
    };
  }

  int _fallbackAverageOrderPrevious(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.today =>
        _averageOrderValueMinor(
          snapshot.yesterdayRevenueMinor,
          intelligenceInputs.todayOrderCount.previousValue,
        ),
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.averageOrderValueThisMonth.previousValue,
      AnalyticsPresetPeriod.thisWeek || AnalyticsPresetPeriod.last14Days || null =>
        intelligenceInputs.averageOrderValueThisWeek.previousValue,
    };
  }

  int _fallbackCancelledCurrent(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.thisMonthCancelledOrderCount.currentValue,
      AnalyticsPresetPeriod.today || AnalyticsPresetPeriod.thisWeek ||
      AnalyticsPresetPeriod.last14Days || null =>
        intelligenceInputs.thisWeekCancelledOrderCount.currentValue,
    };
  }

  int _fallbackCancelledPrevious(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.thisMonthCancelledOrderCount.previousValue,
      AnalyticsPresetPeriod.today || AnalyticsPresetPeriod.thisWeek ||
      AnalyticsPresetPeriod.last14Days || null =>
        intelligenceInputs.thisWeekCancelledOrderCount.previousValue,
    };
  }

  int _fallbackCashCurrent(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.thisMonthPaymentMix.cashRevenue.currentValue,
      AnalyticsPresetPeriod.today || AnalyticsPresetPeriod.thisWeek ||
      AnalyticsPresetPeriod.last14Days || null =>
        intelligenceInputs.thisWeekPaymentMix.cashRevenue.currentValue,
    };
  }

  int _fallbackCashPrevious(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.thisMonthPaymentMix.cashRevenue.previousValue,
      AnalyticsPresetPeriod.today || AnalyticsPresetPeriod.thisWeek ||
      AnalyticsPresetPeriod.last14Days || null =>
        intelligenceInputs.thisWeekPaymentMix.cashRevenue.previousValue,
    };
  }

  int _fallbackCardCurrent(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.thisMonthPaymentMix.cardRevenue.currentValue,
      AnalyticsPresetPeriod.today || AnalyticsPresetPeriod.thisWeek ||
      AnalyticsPresetPeriod.last14Days || null =>
        intelligenceInputs.thisWeekPaymentMix.cardRevenue.currentValue,
    };
  }

  int _fallbackCardPrevious(
    RevenueAnalyticsSnapshot snapshot,
    AnalyticsPeriodSelection selection,
    RevenueIntelligenceInputs intelligenceInputs,
  ) {
    return switch (selection.preset) {
      AnalyticsPresetPeriod.thisMonth =>
        intelligenceInputs.thisMonthPaymentMix.cardRevenue.previousValue,
      AnalyticsPresetPeriod.today || AnalyticsPresetPeriod.thisWeek ||
      AnalyticsPresetPeriod.last14Days || null =>
        intelligenceInputs.thisWeekPaymentMix.cardRevenue.previousValue,
    };
  }

  int _averageOrderValueMinor(int revenueMinor, int orderCount) {
    if (orderCount <= 0) {
      return 0;
    }
    return (revenueMinor / orderCount).round();
  }

  int _orderCountAtOffset(
    List<DailyRevenuePoint> dailyTrend,
    int daysFromEndInclusive,
  ) {
    final int index = dailyTrend.length - 1 - daysFromEndInclusive;
    if (index < 0 || index >= dailyTrend.length) {
      return 0;
    }
    return dailyTrend[index].orderCount;
  }

  int _daypartSortKey(String daypart) {
    return switch (daypart) {
      'breakfast' => 0,
      'lunch' => 1,
      'afternoon' => 2,
      'evening' => 3,
      'late' => 4,
      _ => 99,
    };
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

  double? _roundedPercentage(double? value) {
    if (value == null) {
      return null;
    }
    return double.parse(value.toStringAsFixed(1));
  }

  String _formatMetric(int value, RevenueMetricFormat format) {
    return switch (format) {
      RevenueMetricFormat.currencyMinor => CurrencyFormatter.fromMinor(value),
      RevenueMetricFormat.count => '$value',
    };
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
