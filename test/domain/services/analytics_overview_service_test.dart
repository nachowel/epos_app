import 'package:epos_app/data/repositories/analytics_repository.dart';
import 'package:epos_app/domain/models/analytics/analytics_date_range.dart';
import 'package:epos_app/domain/models/analytics/category_product_analytics_section.dart';
import 'package:epos_app/domain/models/analytics/daily_revenue_point.dart';
import 'package:epos_app/domain/models/analytics/overview_metrics.dart';
import 'package:epos_app/domain/models/analytics/payment_split_summary.dart';
import 'package:epos_app/domain/models/analytics/revenue_metrics.dart';
import 'package:epos_app/domain/models/analytics/top_product_summary.dart';
import 'package:epos_app/domain/services/analytics_overview_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsOverviewService', () {
    test('returns zeros and empty previews for empty datasets', () async {
      final AnalyticsOverviewService service = AnalyticsOverviewService(
        repository: _FakeAnalyticsRepository(const OverviewMetrics.empty()),
      );

      expect(
        await service.getOverviewMetrics(_range()),
        const OverviewMetrics.empty(),
      );
    });

    test('applies defensive non-negative normalization', () async {
      final AnalyticsOverviewService service = AnalyticsOverviewService(
        repository: _FakeAnalyticsRepository(
          const OverviewMetrics(
            totalRevenueMinor: -3000,
            orderCount: -2,
            averageOrderValueMinor: -10,
            topProductsPreview: <TopProductSummary>[
              TopProductSummary(
                productId: 1,
                productName: ' Coffee ',
                revenueMinor: -2000,
                quantityCount: -3,
              ),
            ],
            paymentSplitSummary: PaymentSplitSummary(
              cashRevenueMinor: -1200,
              cardRevenueMinor: -1800,
              totalRevenueMinor: -3000,
              cashOrderCount: -1,
              cardOrderCount: -2,
            ),
          ),
        ),
      );

      final OverviewMetrics metrics = await service.getOverviewMetrics(
        _range(),
      );

      expect(metrics.totalRevenueMinor, 0);
      expect(metrics.orderCount, 0);
      expect(metrics.averageOrderValueMinor, 0);
      expect(metrics.topProductsPreview, isEmpty);
      expect(metrics.paymentSplitSummary, const PaymentSplitSummary.empty());
      expect(metrics.customSalesRevenueMinor, 0);
      expect(metrics.customSalesCount, 0);
      expect(metrics.customSalesAverageValueMinor, 0);
    });

    test('computes a safe aov when repository order count is zero', () async {
      final AnalyticsOverviewService service = AnalyticsOverviewService(
        repository: _FakeAnalyticsRepository(
          const OverviewMetrics(
            totalRevenueMinor: 3000,
            orderCount: 0,
            averageOrderValueMinor: 9999,
            topProductsPreview: <TopProductSummary>[],
            paymentSplitSummary: PaymentSplitSummary.empty(),
          ),
        ),
      );

      final OverviewMetrics metrics = await service.getOverviewMetrics(
        _range(),
      );

      expect(metrics.totalRevenueMinor, 3000);
      expect(metrics.orderCount, 0);
      expect(metrics.averageOrderValueMinor, 0);
    });

    test('keeps empty payment split summaries at zero values', () async {
      final AnalyticsOverviewService service = AnalyticsOverviewService(
        repository: _FakeAnalyticsRepository(
          const OverviewMetrics(
            totalRevenueMinor: 1200,
            orderCount: 1,
            averageOrderValueMinor: 1200,
            topProductsPreview: <TopProductSummary>[
              TopProductSummary(
                productId: 1,
                productName: 'Coffee',
                revenueMinor: 1200,
                quantityCount: 1,
              ),
            ],
            paymentSplitSummary: PaymentSplitSummary.empty(),
          ),
        ),
      );

      final OverviewMetrics metrics = await service.getOverviewMetrics(
        _range(),
      );

      expect(metrics.paymentSplitSummary, const PaymentSplitSummary.empty());
    });

    test('limits top products to three and trims names', () async {
      final AnalyticsOverviewService service = AnalyticsOverviewService(
        repository: _FakeAnalyticsRepository(
          const OverviewMetrics(
            totalRevenueMinor: 3000,
            orderCount: 2,
            averageOrderValueMinor: -100,
            topProductsPreview: <TopProductSummary>[
              TopProductSummary(
                productId: 1,
                productName: ' Coffee ',
                revenueMinor: 2000,
                quantityCount: 2,
              ),
              TopProductSummary(
                productId: 2,
                productName: 'Wrap',
                revenueMinor: 700,
                quantityCount: 1,
              ),
              TopProductSummary(
                productId: 3,
                productName: 'Cake',
                revenueMinor: 300,
                quantityCount: 1,
              ),
              TopProductSummary(
                productId: 4,
                productName: 'Tea',
                revenueMinor: 100,
                quantityCount: 1,
              ),
            ],
            paymentSplitSummary: PaymentSplitSummary(
              cashRevenueMinor: 1200,
              cardRevenueMinor: 1800,
              totalRevenueMinor: 3000,
              cashOrderCount: 1,
              cardOrderCount: 1,
            ),
          ),
        ),
      );

      final OverviewMetrics metrics = await service.getOverviewMetrics(
        _range(),
      );

      expect(metrics.totalRevenueMinor, 3000);
      expect(metrics.orderCount, 2);
      expect(metrics.averageOrderValueMinor, 1500);
      expect(metrics.topProductsPreview, hasLength(3));
      expect(metrics.topProductsPreview.first.productName, 'Coffee');
    });

    test('normalizes dedicated custom sale metrics', () async {
      final AnalyticsOverviewService service = AnalyticsOverviewService(
        repository: _FakeAnalyticsRepository(
          const OverviewMetrics(
            totalRevenueMinor: 3000,
            orderCount: 2,
            averageOrderValueMinor: 1500,
            topProductsPreview: <TopProductSummary>[],
            paymentSplitSummary: PaymentSplitSummary.empty(),
            customSalesRevenueMinor: -900,
            customSalesCount: -2,
            customSalesAverageValueMinor: -450,
          ),
        ),
      );

      final OverviewMetrics metrics = await service.getOverviewMetrics(
        _range(),
      );

      expect(metrics.customSalesRevenueMinor, 0);
      expect(metrics.customSalesCount, 0);
      expect(metrics.customSalesAverageValueMinor, 0);
    });
  });
}

AnalyticsDateRange _range() {
  return AnalyticsDateRange.explicit(
    startInclusive: DateTime(2026, 4, 10),
    endExclusive: DateTime(2026, 4, 11),
  );
}

class _FakeAnalyticsRepository implements AnalyticsRepository {
  const _FakeAnalyticsRepository(this._metrics);

  final OverviewMetrics _metrics;

  @override
  Future<List<CategoryProductAnalyticsSection>> getCategoryProductSections(
    AnalyticsDateRange range, {
    int perCategoryLimit = 5,
  }) async {
    return const <CategoryProductAnalyticsSection>[];
  }

  @override
  Future<OverviewMetrics> getOverviewMetrics(AnalyticsDateRange range) async {
    return _metrics;
  }

  @override
  Future<PaymentSplitSummary> getPaymentSplit(AnalyticsDateRange range) async {
    return _metrics.paymentSplitSummary;
  }

  @override
  Future<List<DailyRevenuePoint>> getDailyRevenueSeries(
    AnalyticsDateRange range,
  ) async {
    return const <DailyRevenuePoint>[];
  }

  @override
  Future<RevenueMetrics> getRevenueMetrics(AnalyticsDateRange range) async {
    return RevenueMetrics(
      totalRevenueMinor: _metrics.totalRevenueMinor,
      orderCount: _metrics.orderCount,
      averageOrderValueMinor: _metrics.averageOrderValueMinor,
    );
  }

  @override
  Future<List<TopProductSummary>> getTopProductsOverall(
    AnalyticsDateRange range, {
    int limit = 3,
  }) async {
    return _metrics.topProductsPreview.take(limit).toList(growable: false);
  }
}
