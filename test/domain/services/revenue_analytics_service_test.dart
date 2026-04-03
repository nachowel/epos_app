import 'package:epos_app/data/repositories/revenue_analytics_repository.dart';
import 'package:epos_app/domain/models/analytics/analytics_period.dart';
import 'package:epos_app/domain/models/analytics/insight.dart';
import 'package:epos_app/domain/models/revenue_summary.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/revenue_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevenueAnalyticsService', () {
    test(
      'builds selected-period summary and structured insights from expanded snapshot',
      () async {
        final RevenueAnalyticsService service = RevenueAnalyticsService(
          repository: _FakeRevenueAnalyticsRepository(
            snapshots: <String, RevenueAnalyticsSnapshot>{
              'last_14_days': _buildSnapshot(
                selection: const AnalyticsPeriodSelection.preset(
                  AnalyticsPresetPeriod.last14Days,
                ),
                comparisonStart: DateTime.utc(2026, 3, 4),
                comparisonEnd: DateTime.utc(2026, 3, 17),
                periodRevenueMinor: 18200,
                previousPeriodRevenueMinor: 12000,
                periodOrderCount: 8,
                previousPeriodOrderCount: 6,
                periodAverageOrderValueMinor: 2275,
                previousPeriodAverageOrderValueMinor: 2000,
                periodCashRevenueMinor: 10200,
                periodCardRevenueMinor: 8000,
                previousPeriodCashRevenueMinor: 4500,
                previousPeriodCardRevenueMinor: 7500,
                periodCancelledOrderCount: 2,
                previousPeriodCancelledOrderCount: 1,
                topProductsCurrentPeriod: const <RevenueAnalyticsTopProductPoint>[
                  RevenueAnalyticsTopProductPoint(
                    productKey: '11',
                    productName: 'Flat White',
                    quantitySold: 8,
                    revenueMinor: 6400,
                  ),
                ],
                topProductsPreviousPeriod: const <RevenueAnalyticsTopProductPoint>[
                  RevenueAnalyticsTopProductPoint(
                    productKey: '12',
                    productName: 'Cappuccino',
                    quantitySold: 5,
                    revenueMinor: 4000,
                  ),
                ],
                dataQualityNotes: const <String>[
                  'refunds not available in remote analytics',
                ],
              ),
            },
          ),
        );

        final RevenueSummary summary = await service.getRevenueSummary(
          user: _adminUser(),
          periodSelection: const AnalyticsPeriodSelection.preset(
            AnalyticsPresetPeriod.last14Days,
          ),
        );

        expect(summary.selectedPeriodSummary.label, 'Last 14 Days');
        expect(summary.selectedPeriodSummary.revenue.currentValue, 18200);
        expect(summary.selectedPeriodSummary.revenue.previousValue, 12000);
        expect(summary.selectedPeriodSummary.orderCount.currentValue, 8);
        expect(summary.selectedPeriodSummary.averageOrderValue.currentValue, 2275);
        expect(
          summary.selectedPeriodSummary.paymentMix.cashRevenue.currentValue,
          10200,
        );
        expect(
          summary.selectedPeriodSummary.cancelledOrderCount.currentValue,
          2,
        );
        expect(summary.dataQualityNotes, contains('refunds not available in remote analytics'));

        final Insight periodRevenueInsight = _findInsight(
          summary,
          'period_revenue_delta',
        );
        expect(periodRevenueInsight.title, 'Last 14 Days Revenue');
        expect(periodRevenueInsight.evidence['current_value'], 18200);
        expect(periodRevenueInsight.evidence['previous_value'], 12000);

        expect(
          summary.insights.weeklyPerformance,
          'last 14 days is 51.7% higher than the previous equivalent period.',
        );
      },
    );

    test('period-specific fetch changes summary context and repository request', () async {
      final _FakeRevenueAnalyticsRepository repository = _FakeRevenueAnalyticsRepository(
        snapshots: <String, RevenueAnalyticsSnapshot>{
          'today': _buildSnapshot(
            selection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.today,
            ),
            comparisonStart: DateTime.utc(2026, 3, 30),
            comparisonEnd: DateTime.utc(2026, 3, 30),
            periodRevenueMinor: 3500,
            previousPeriodRevenueMinor: 2000,
            periodOrderCount: 2,
            previousPeriodOrderCount: 1,
            periodAverageOrderValueMinor: 1750,
            previousPeriodAverageOrderValueMinor: 2000,
          ),
          'this_month': _buildSnapshot(
            selection: const AnalyticsPeriodSelection.preset(
              AnalyticsPresetPeriod.thisMonth,
            ),
            comparisonStart: DateTime.utc(2026, 3, 1),
            comparisonEnd: DateTime.utc(2026, 3, 30),
            periodRevenueMinor: 48600,
            previousPeriodRevenueMinor: 45200,
            periodOrderCount: 28,
            previousPeriodOrderCount: 26,
            periodAverageOrderValueMinor: 1736,
            previousPeriodAverageOrderValueMinor: 1738,
          ),
        },
      );
      final RevenueAnalyticsService service = RevenueAnalyticsService(
        repository: repository,
      );

      final RevenueSummary todaySummary = await service.getRevenueSummary(
        user: _adminUser(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.today,
        ),
      );
      final RevenueSummary monthSummary = await service.getRevenueSummary(
        user: _adminUser(),
        periodSelection: const AnalyticsPeriodSelection.preset(
          AnalyticsPresetPeriod.thisMonth,
        ),
      );

      expect(repository.requestedSelections, <AnalyticsPeriodSelection>[
        const AnalyticsPeriodSelection.preset(AnalyticsPresetPeriod.today),
        const AnalyticsPeriodSelection.preset(AnalyticsPresetPeriod.thisMonth),
      ]);
      expect(todaySummary.selectedPeriodSummary.label, 'Today');
      expect(monthSummary.selectedPeriodSummary.label, 'This Month');
      expect(todaySummary.selectedPeriodSummary.revenue.currentValue, 3500);
      expect(monthSummary.selectedPeriodSummary.revenue.currentValue, 48600);
      expect(
        _findInsight(todaySummary, 'period_revenue_delta').title,
        'Today Revenue',
      );
      expect(
        _findInsight(monthSummary, 'period_revenue_delta').title,
        'This Month Revenue',
      );
    });
  });
}

class _FakeRevenueAnalyticsRepository implements RevenueAnalyticsRepository {
  _FakeRevenueAnalyticsRepository({
    required Map<String, RevenueAnalyticsSnapshot> snapshots,
  }) : _snapshots = snapshots;

  final Map<String, RevenueAnalyticsSnapshot> _snapshots;
  final List<AnalyticsPeriodSelection> requestedSelections =
      <AnalyticsPeriodSelection>[];

  @override
  Future<RevenueAnalyticsSnapshot> fetchRevenueAnalytics() async {
    return _snapshots['this_week'] ??
        _snapshots.values.first;
  }

  @override
  Future<RevenueAnalyticsSnapshot> fetchAnalytics({
    required AnalyticsPeriodSelection selection,
  }) async {
    requestedSelections.add(selection);
    final RevenueAnalyticsSnapshot? snapshot = _snapshots[selection.queryValue];
    if (snapshot == null) {
      throw StateError('Missing fake snapshot for ${selection.queryValue}');
    }
    return snapshot;
  }
}

RevenueAnalyticsSnapshot _buildSnapshot({
  required AnalyticsPeriodSelection selection,
  required DateTime comparisonStart,
  required DateTime comparisonEnd,
  required int periodRevenueMinor,
  required int previousPeriodRevenueMinor,
  required int periodOrderCount,
  required int previousPeriodOrderCount,
  required int periodAverageOrderValueMinor,
  required int previousPeriodAverageOrderValueMinor,
  int periodCashRevenueMinor = 0,
  int periodCardRevenueMinor = 0,
  int previousPeriodCashRevenueMinor = 0,
  int previousPeriodCardRevenueMinor = 0,
  int periodCancelledOrderCount = 0,
  int previousPeriodCancelledOrderCount = 0,
  List<RevenueAnalyticsTopProductPoint> topProductsCurrentPeriod =
      const <RevenueAnalyticsTopProductPoint>[],
  List<RevenueAnalyticsTopProductPoint> topProductsPreviousPeriod =
      const <RevenueAnalyticsTopProductPoint>[],
  List<String> dataQualityNotes = const <String>[],
}) {
  final DateTime generatedAt = DateTime.utc(2026, 3, 31, 12);
  final RevenueAnalyticsPeriodWindow periodWindow = RevenueAnalyticsPeriodWindow(
    selection: selection,
    startDate: selection.start ?? DateTime.utc(2026, 3, 18),
    endDate: selection.end ?? DateTime.utc(2026, 3, 31),
    dayCount: selection.preset == AnalyticsPresetPeriod.today ? 1 : 14,
  );

  return RevenueAnalyticsSnapshot(
    generatedAt: generatedAt,
    timezone: 'Europe/London',
    todayRevenueMinor: periodRevenueMinor,
    yesterdayRevenueMinor: previousPeriodRevenueMinor,
    thisWeekRevenueMinor: periodRevenueMinor,
    lastWeekRevenueMinor: previousPeriodRevenueMinor,
    thisMonthRevenueMinor: periodRevenueMinor,
    lastMonthRevenueMinor: previousPeriodRevenueMinor,
    thisWeekOrderCount: periodOrderCount,
    lastWeekOrderCount: previousPeriodOrderCount,
    periodWindow: periodWindow,
    comparisonWindow: RevenueAnalyticsComparisonWindow(
      startDate: comparisonStart,
      endDate: comparisonEnd,
      dayCount: periodWindow.dayCount,
      basis: 'previous_equivalent_period',
    ),
    periodRevenueMinor: periodRevenueMinor,
    previousPeriodRevenueMinor: previousPeriodRevenueMinor,
    periodOrderCount: periodOrderCount,
    previousPeriodOrderCount: previousPeriodOrderCount,
    periodAverageOrderValueMinor: periodAverageOrderValueMinor,
    previousPeriodAverageOrderValueMinor: previousPeriodAverageOrderValueMinor,
    periodCashRevenueMinor: periodCashRevenueMinor,
    periodCardRevenueMinor: periodCardRevenueMinor,
    previousPeriodCashRevenueMinor: previousPeriodCashRevenueMinor,
    previousPeriodCardRevenueMinor: previousPeriodCardRevenueMinor,
    periodCancelledOrderCount: periodCancelledOrderCount,
    previousPeriodCancelledOrderCount: previousPeriodCancelledOrderCount,
    todayOrderCount: periodOrderCount,
    yesterdayOrderCount: previousPeriodOrderCount,
    thisMonthOrderCount: periodOrderCount,
    lastMonthOrderCount: previousPeriodOrderCount,
    thisWeekAverageOrderValueMinor: periodAverageOrderValueMinor,
    lastWeekAverageOrderValueMinor: previousPeriodAverageOrderValueMinor,
    thisMonthAverageOrderValueMinor: periodAverageOrderValueMinor,
    lastMonthAverageOrderValueMinor: previousPeriodAverageOrderValueMinor,
    thisWeekCashRevenueMinor: periodCashRevenueMinor,
    thisWeekCardRevenueMinor: periodCardRevenueMinor,
    lastWeekCashRevenueMinor: previousPeriodCashRevenueMinor,
    lastWeekCardRevenueMinor: previousPeriodCardRevenueMinor,
    thisMonthCashRevenueMinor: periodCashRevenueMinor,
    thisMonthCardRevenueMinor: periodCardRevenueMinor,
    lastMonthCashRevenueMinor: previousPeriodCashRevenueMinor,
    lastMonthCardRevenueMinor: previousPeriodCardRevenueMinor,
    thisWeekCancelledOrderCount: periodCancelledOrderCount,
    lastWeekCancelledOrderCount: previousPeriodCancelledOrderCount,
    thisMonthCancelledOrderCount: periodCancelledOrderCount,
    lastMonthCancelledOrderCount: previousPeriodCancelledOrderCount,
    dailyTrend: <RevenueAnalyticsDailyPoint>[
      RevenueAnalyticsDailyPoint(
        dateKey: '2026-03-30',
        revenueMinor: previousPeriodRevenueMinor,
        orderCount: previousPeriodOrderCount,
      ),
      RevenueAnalyticsDailyPoint(
        dateKey: '2026-03-31',
        revenueMinor: periodRevenueMinor,
        orderCount: periodOrderCount,
      ),
    ],
    weeklySummary: <RevenueAnalyticsWeeklyPoint>[
      RevenueAnalyticsWeeklyPoint(
        weekStartKey: '2026-03-24',
        revenueMinor: previousPeriodRevenueMinor,
        orderCount: previousPeriodOrderCount,
      ),
      RevenueAnalyticsWeeklyPoint(
        weekStartKey: '2026-03-31',
        revenueMinor: periodRevenueMinor,
        orderCount: periodOrderCount,
      ),
    ],
    hourlyDistribution: List<RevenueAnalyticsHourlyPoint>.generate(24, (
      int hour,
    ) {
      return RevenueAnalyticsHourlyPoint(
        hour: hour,
        revenueMinor: hour == 12 ? periodRevenueMinor : 0,
        orderCount: hour == 12 ? periodOrderCount : 0,
      );
    }, growable: false),
    daypartDistribution: const <RevenueAnalyticsDaypartPoint>[
      RevenueAnalyticsDaypartPoint(
        daypart: 'breakfast',
        revenueMinor: 1000,
        orderCount: 1,
      ),
      RevenueAnalyticsDaypartPoint(
        daypart: 'lunch',
        revenueMinor: 2000,
        orderCount: 1,
      ),
      RevenueAnalyticsDaypartPoint(
        daypart: 'afternoon',
        revenueMinor: 0,
        orderCount: 0,
      ),
      RevenueAnalyticsDaypartPoint(
        daypart: 'evening',
        revenueMinor: 0,
        orderCount: 0,
      ),
      RevenueAnalyticsDaypartPoint(
        daypart: 'late',
        revenueMinor: 0,
        orderCount: 0,
      ),
    ],
    topProductsCurrentPeriod: topProductsCurrentPeriod,
    topProductsPreviousPeriod: topProductsPreviousPeriod,
    dataQualityNotes: dataQualityNotes,
  );
}

User _adminUser() {
  return User(
    id: 1,
    name: 'Admin',
    pin: null,
    password: null,
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Insight _findInsight(RevenueSummary summary, String code) {
  return summary.insights.structuredInsights.firstWhere(
    (Insight insight) => insight.code == code,
  );
}
