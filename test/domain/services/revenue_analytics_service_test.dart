import 'package:epos_app/data/repositories/revenue_analytics_repository.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/revenue_analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevenueAnalyticsService', () {
    test('computes comparison-driven KPIs and strengthened insights', () async {
      final RevenueAnalyticsService service = RevenueAnalyticsService(
        repository: _FakeRevenueAnalyticsRepository(
          _buildSnapshot(
            generatedAt: DateTime.utc(2026, 3, 31, 20),
            todayRevenueMinor: 3500,
            yesterdayRevenueMinor: 2000,
            thisWeekRevenueMinor: 5500,
            lastWeekRevenueMinor: 11500,
            thisMonthRevenueMinor: 18200,
            lastMonthRevenueMinor: 12000,
            thisWeekOrderCount: 3,
            lastWeekOrderCount: 5,
            dailyRevenueByDate: <String, int>{
              '2026-03-18': 0,
              '2026-03-19': 0,
              '2026-03-20': 0,
              '2026-03-21': 500,
              '2026-03-22': 0,
              '2026-03-23': 2500,
              '2026-03-24': 4000,
              '2026-03-25': 0,
              '2026-03-26': 0,
              '2026-03-27': 500,
              '2026-03-28': 3000,
              '2026-03-29': 1500,
              '2026-03-30': 2000,
              '2026-03-31': 3500,
            },
            weeklyRevenueByStart: <String, int>{
              '2026-02-23': 0,
              '2026-03-02': 0,
              '2026-03-09': 0,
              '2026-03-16': 1200,
              '2026-03-23': 11500,
              '2026-03-30': 5500,
            },
            hourlyRevenueByHour: <int, int>{
              7: 4000,
              9: 3000,
              10: 1500,
              11: 2000,
              15: 2500,
              16: 500,
              18: 2500,
              20: 1500,
            },
          ),
        ),
      );

      final summary = await service.getRevenueSummary(user: _adminUser());

      expect(summary.todayRevenue.currentValue, 3500);
      expect(summary.todayRevenue.previousValue, 2000);
      expect(summary.thisWeekRevenue.currentValue, 5500);
      expect(summary.thisWeekRevenue.previousValue, 11500);
      expect(summary.thisMonthRevenue.currentValue, 18200);
      expect(summary.thisMonthRevenue.previousValue, 12000);
      expect(summary.averageOrderValueCurrentWeek.currentValue, 1833);
      expect(summary.averageOrderValueCurrentWeek.previousValue, 2300);

      expect(summary.dailyTrend, hasLength(14));
      expect(summary.dailyTrend.first.revenueMinor, 0);
      expect(summary.dailyTrend.last.revenueMinor, 3500);
      expect(summary.weeklySummary, hasLength(6));
      expect(summary.weeklySummary.last.revenueMinor, 5500);
      expect(summary.hourlyDistribution, hasLength(24));
      expect(summary.hourlyDistribution[0].revenueMinor, 0);
      expect(summary.hourlyDistribution[7].revenueMinor, 4000);
      expect(summary.hourlyDistribution[20].revenueMinor, 1500);

      expect(
        summary.insights.weeklyPerformance,
        'This week is 52.2% lower than last week.',
      );
      expect(
        summary.insights.revenueMomentum,
        'Revenue has increased over the last 14 days by 50.0%.',
      );
      expect(
        summary.insights.strongestDay,
        'Strongest day is Tue 24 Mar with £40.00.',
      );
      expect(
        summary.insights.weakestDay,
        'Weakest day is Wed 18 Mar with £0.00.',
      );
      expect(
        summary.insights.peakHours,
        'Peak hours are 07:00-10:00 contributing 40.0% of revenue.',
      );
      expect(
        summary.insights.lowHours,
        'Low performance hours are 00:00-03:00.',
      );
      expect(
        summary.insights.topHourConcentration,
        'Top 20% hours generate 80.0% of revenue.',
      );
      expect(
        summary.insights.distributionBalance,
        'Revenue is concentrated in a small set of hours.',
      );
    });

    test(
      'handles an empty dataset without crashes and keeps insights meaningful',
      () async {
        final RevenueAnalyticsService service = RevenueAnalyticsService(
          repository: _FakeRevenueAnalyticsRepository(
            _buildSnapshot(
              generatedAt: DateTime.utc(2026, 3, 31, 12),
              todayRevenueMinor: 0,
              yesterdayRevenueMinor: 0,
              thisWeekRevenueMinor: 0,
              lastWeekRevenueMinor: 0,
              thisMonthRevenueMinor: 0,
              lastMonthRevenueMinor: 0,
              thisWeekOrderCount: 0,
              lastWeekOrderCount: 0,
            ),
          ),
        );

        final summary = await service.getRevenueSummary(user: _adminUser());

        expect(summary.hasPaidData, isFalse);
        expect(summary.todayRevenue.percentageChange, 0);
        expect(summary.thisWeekRevenue.percentageChange, 0);
        expect(summary.averageOrderValueCurrentWeek.currentValue, 0);
        expect(summary.dailyTrend, hasLength(14));
        expect(summary.weeklySummary, hasLength(6));
        expect(summary.hourlyDistribution, hasLength(24));
        expect(
          summary.insights.weeklyPerformance,
          'This week is flat versus last week.',
        );
        expect(
          summary.insights.revenueMomentum,
          'Revenue has not generated any paid sales over the last 14 days.',
        );
        expect(
          summary.insights.peakHours,
          'Peak hours are unavailable because there is no hourly revenue yet.',
        );
        expect(
          summary.insights.topHourConcentration,
          'Top 20% hours generate 0.0% of revenue because there are no paid sales yet.',
        );
      },
    );

    test(
      'handles division by zero and single-day revenue spikes safely',
      () async {
        final RevenueAnalyticsService service = RevenueAnalyticsService(
          repository: _FakeRevenueAnalyticsRepository(
            _buildSnapshot(
              generatedAt: DateTime.utc(2026, 3, 31, 12),
              todayRevenueMinor: 5000,
              yesterdayRevenueMinor: 0,
              thisWeekRevenueMinor: 5000,
              lastWeekRevenueMinor: 0,
              thisMonthRevenueMinor: 5000,
              lastMonthRevenueMinor: 0,
              thisWeekOrderCount: 1,
              lastWeekOrderCount: 0,
              dailyRevenueByDate: <String, int>{'2026-03-31': 5000},
              hourlyRevenueByHour: <int, int>{13: 5000},
            ),
          ),
        );

        final summary = await service.getRevenueSummary(user: _adminUser());

        expect(summary.todayRevenue.percentageChange, isNull);
        expect(summary.thisWeekRevenue.percentageChange, isNull);
        expect(summary.thisMonthRevenue.percentageChange, isNull);
        expect(summary.averageOrderValueCurrentWeek.currentValue, 5000);
        expect(summary.averageOrderValueCurrentWeek.previousValue, 0);
        expect(
          summary.insights.weeklyPerformance,
          'This week is higher than last week, which had no paid revenue.',
        );
        expect(
          summary.insights.revenueMomentum,
          'Revenue has increased over the last 14 days.',
        );
        expect(
          summary.insights.peakHours,
          'Peak hours are 11:00-14:00 contributing 100.0% of revenue.',
        );
      },
    );
  });
}

class _FakeRevenueAnalyticsRepository implements RevenueAnalyticsRepository {
  const _FakeRevenueAnalyticsRepository(this._snapshot);

  final RevenueAnalyticsSnapshot _snapshot;

  @override
  Future<RevenueAnalyticsSnapshot> fetchRevenueAnalytics() async => _snapshot;
}

RevenueAnalyticsSnapshot _buildSnapshot({
  required DateTime generatedAt,
  required int todayRevenueMinor,
  required int yesterdayRevenueMinor,
  required int thisWeekRevenueMinor,
  required int lastWeekRevenueMinor,
  required int thisMonthRevenueMinor,
  required int lastMonthRevenueMinor,
  required int thisWeekOrderCount,
  required int lastWeekOrderCount,
  Map<String, int> dailyRevenueByDate = const <String, int>{},
  Map<String, int> weeklyRevenueByStart = const <String, int>{},
  Map<int, int> hourlyRevenueByHour = const <int, int>{},
}) {
  const List<String> dailyKeys = <String>[
    '2026-03-18',
    '2026-03-19',
    '2026-03-20',
    '2026-03-21',
    '2026-03-22',
    '2026-03-23',
    '2026-03-24',
    '2026-03-25',
    '2026-03-26',
    '2026-03-27',
    '2026-03-28',
    '2026-03-29',
    '2026-03-30',
    '2026-03-31',
  ];
  const List<String> weeklyKeys = <String>[
    '2026-02-23',
    '2026-03-02',
    '2026-03-09',
    '2026-03-16',
    '2026-03-23',
    '2026-03-30',
  ];

  return RevenueAnalyticsSnapshot(
    generatedAt: generatedAt,
    timezone: 'Europe/London',
    todayRevenueMinor: todayRevenueMinor,
    yesterdayRevenueMinor: yesterdayRevenueMinor,
    thisWeekRevenueMinor: thisWeekRevenueMinor,
    lastWeekRevenueMinor: lastWeekRevenueMinor,
    thisMonthRevenueMinor: thisMonthRevenueMinor,
    lastMonthRevenueMinor: lastMonthRevenueMinor,
    thisWeekOrderCount: thisWeekOrderCount,
    lastWeekOrderCount: lastWeekOrderCount,
    dailyTrend: dailyKeys
        .map(
          (String key) => RevenueAnalyticsDailyPoint(
            dateKey: key,
            revenueMinor: dailyRevenueByDate[key] ?? 0,
            orderCount: (dailyRevenueByDate[key] ?? 0) > 0 ? 1 : 0,
          ),
        )
        .toList(growable: false),
    weeklySummary: weeklyKeys
        .map(
          (String key) => RevenueAnalyticsWeeklyPoint(
            weekStartKey: key,
            revenueMinor: weeklyRevenueByStart[key] ?? 0,
            orderCount: (weeklyRevenueByStart[key] ?? 0) > 0 ? 1 : 0,
          ),
        )
        .toList(growable: false),
    hourlyDistribution: List<RevenueAnalyticsHourlyPoint>.generate(24, (
      int hour,
    ) {
      final int revenueMinor = hourlyRevenueByHour[hour] ?? 0;
      return RevenueAnalyticsHourlyPoint(
        hour: hour,
        revenueMinor: revenueMinor,
        orderCount: revenueMinor > 0 ? 1 : 0,
      );
    }, growable: false),
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
