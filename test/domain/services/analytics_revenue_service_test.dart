import 'package:epos_app/data/repositories/analytics_repository.dart';
import 'package:epos_app/domain/models/analytics/analytics_date_range.dart';
import 'package:epos_app/domain/models/analytics/analytics_revenue_preset.dart';
import 'package:epos_app/domain/models/analytics/category_product_analytics_section.dart';
import 'package:epos_app/domain/models/analytics/daily_revenue_point.dart';
import 'package:epos_app/domain/models/analytics/overview_metrics.dart';
import 'package:epos_app/domain/models/analytics/payment_split_summary.dart';
import 'package:epos_app/domain/models/analytics/revenue_detail_summary.dart';
import 'package:epos_app/domain/models/analytics/revenue_metrics.dart';
import 'package:epos_app/domain/models/analytics/top_product_summary.dart';
import 'package:epos_app/domain/services/analytics_revenue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsRevenueService', () {
    test('fills missing days with zeros and preserves day order', () async {
      final AnalyticsRevenueService service = AnalyticsRevenueService(
        repository: _FakeAnalyticsRepository(
          metricsByStart: <DateTime, RevenueMetrics>{
            DateTime(2026, 4, 6): const RevenueMetrics(
              totalRevenueMinor: 3200,
              orderCount: 2,
              averageOrderValueMinor: 1600,
            ),
            DateTime(2026, 4, 1): const RevenueMetrics.empty(),
          },
          seriesByStart: <DateTime, List<DailyRevenuePoint>>{
            DateTime(2026, 4, 6): <DailyRevenuePoint>[
              DailyRevenuePoint(
                date: DateTime(2026, 4, 7),
                revenueMinor: 1200,
                orderCount: 1,
              ),
              DailyRevenuePoint(
                date: DateTime(2026, 4, 9),
                revenueMinor: 2000,
                orderCount: 1,
              ),
            ],
          },
        ),
      );

      final RevenueDetailSummary summary = await service
          .getRevenueDetailSummary(
            preset: AnalyticsRevenuePreset.thisWeek,
            now: DateTime(2026, 4, 10, 12),
          );

      expect(summary.totalRevenueMinor, 3200);
      expect(summary.orderCount, 2);
      expect(summary.averageOrderValueMinor, 1600);
      expect(summary.dailyRevenueSeries, <DailyRevenuePoint>[
        DailyRevenuePoint(
          date: DateTime(2026, 4, 6),
          revenueMinor: 0,
          orderCount: 0,
        ),
        DailyRevenuePoint(
          date: DateTime(2026, 4, 7),
          revenueMinor: 1200,
          orderCount: 1,
        ),
        DailyRevenuePoint(
          date: DateTime(2026, 4, 8),
          revenueMinor: 0,
          orderCount: 0,
        ),
        DailyRevenuePoint(
          date: DateTime(2026, 4, 9),
          revenueMinor: 2000,
          orderCount: 1,
        ),
        DailyRevenuePoint(
          date: DateTime(2026, 4, 10),
          revenueMinor: 0,
          orderCount: 0,
        ),
      ]);
      expect(summary.comparisonLabel, 'Compared to last week');
      expect(summary.comparisonOrderCount, 0);
      expect(summary.comparisonAverageOrderValueMinor, 0);
    });

    test('normalizes negative aggregates and keeps aov safe', () async {
      final AnalyticsRevenueService service = AnalyticsRevenueService(
        repository: _FakeAnalyticsRepository(
          metricsByStart: <DateTime, RevenueMetrics>{
            DateTime(2026, 4, 6): const RevenueMetrics(
              totalRevenueMinor: -3000,
              orderCount: -2,
              averageOrderValueMinor: -99,
            ),
            DateTime(2026, 4, 4): const RevenueMetrics(
              totalRevenueMinor: -100,
              orderCount: -1,
              averageOrderValueMinor: -50,
            ),
          },
          seriesByStart: <DateTime, List<DailyRevenuePoint>>{
            DateTime(2026, 4, 6): <DailyRevenuePoint>[
              DailyRevenuePoint(
                date: DateTime(2026, 4, 7),
                revenueMinor: -20,
                orderCount: -1,
              ),
            ],
          },
        ),
      );

      final RevenueDetailSummary summary = await service
          .getRevenueDetailSummary(
            preset: AnalyticsRevenuePreset.thisWeek,
            now: DateTime(2026, 4, 7, 12),
          );

      expect(summary.totalRevenueMinor, 0);
      expect(summary.orderCount, 0);
      expect(summary.averageOrderValueMinor, 0);
      expect(summary.dailyRevenueSeries, <DailyRevenuePoint>[
        DailyRevenuePoint(
          date: DateTime(2026, 4, 6),
          revenueMinor: 0,
          orderCount: 0,
        ),
        DailyRevenuePoint(
          date: DateTime(2026, 4, 7),
          revenueMinor: 0,
          orderCount: 0,
        ),
      ]);
      expect(summary.comparisonDirection, RevenueComparisonDirection.none);
      expect(summary.comparisonAverageOrderValueMinor, 0);
    });

    test('changes comparison label by preset', () async {
      final AnalyticsRevenueService service = AnalyticsRevenueService(
        repository: _FakeAnalyticsRepository(
          metricsByStart: <DateTime, RevenueMetrics>{
            DateTime(2026, 3, 1): const RevenueMetrics(
              totalRevenueMinor: 6200,
              orderCount: 4,
              averageOrderValueMinor: 1550,
            ),
            DateTime(2026, 2, 1): const RevenueMetrics(
              totalRevenueMinor: 5400,
              orderCount: 3,
              averageOrderValueMinor: 1800,
            ),
          },
          seriesByStart: <DateTime, List<DailyRevenuePoint>>{
            DateTime(2026, 3, 1): <DailyRevenuePoint>[
              DailyRevenuePoint(
                date: DateTime(2026, 3, 1),
                revenueMinor: 6200,
                orderCount: 4,
              ),
            ],
          },
        ),
      );

      final RevenueDetailSummary summary = await service
          .getRevenueDetailSummary(
            preset: AnalyticsRevenuePreset.thisMonth,
            now: DateTime(2026, 3, 1, 10),
          );

      expect(summary.comparisonLabel, 'Compared to last month');
      expect(summary.comparisonDirection, RevenueComparisonDirection.up);
      expect(summary.comparisonDeltaRevenueMinor, 800);
      expect(summary.comparisonAverageOrderValueMinor, 1800);
    });
  });
}

class _FakeAnalyticsRepository implements AnalyticsRepository {
  const _FakeAnalyticsRepository({
    required this.metricsByStart,
    required this.seriesByStart,
  });

  final Map<DateTime, RevenueMetrics> metricsByStart;
  final Map<DateTime, List<DailyRevenuePoint>> seriesByStart;

  @override
  Future<List<CategoryProductAnalyticsSection>> getCategoryProductSections(
    AnalyticsDateRange range, {
    int perCategoryLimit = 5,
  }) async {
    return const <CategoryProductAnalyticsSection>[];
  }

  @override
  Future<List<DailyRevenuePoint>> getDailyRevenueSeries(
    AnalyticsDateRange range,
  ) async {
    return seriesByStart[range.startInclusive] ?? const <DailyRevenuePoint>[];
  }

  @override
  Future<OverviewMetrics> getOverviewMetrics(AnalyticsDateRange range) async {
    return const OverviewMetrics.empty();
  }

  @override
  Future<PaymentSplitSummary> getPaymentSplit(AnalyticsDateRange range) async {
    return const PaymentSplitSummary.empty();
  }

  @override
  Future<List<TopProductSummary>> getTopProductsOverall(
    AnalyticsDateRange range, {
    int limit = 3,
  }) async {
    return const <TopProductSummary>[];
  }

  @override
  Future<RevenueMetrics> getRevenueMetrics(AnalyticsDateRange range) async {
    return metricsByStart[range.startInclusive] ?? const RevenueMetrics.empty();
  }
}
