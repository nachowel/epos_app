import 'package:epos_app/data/repositories/analytics_repository.dart';
import 'package:epos_app/domain/models/analytics/analytics_date_range.dart';
import 'package:epos_app/domain/models/analytics/category_product_analytics_section.dart';
import 'package:epos_app/domain/models/analytics/daily_revenue_point.dart';
import 'package:epos_app/domain/models/analytics/overview_metrics.dart';
import 'package:epos_app/domain/models/analytics/payment_split_summary.dart';
import 'package:epos_app/domain/models/analytics/revenue_metrics.dart';
import 'package:epos_app/domain/models/analytics/top_product_summary.dart';
import 'package:epos_app/domain/services/analytics_payments_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsPaymentsService', () {
    test('keeps payment split revenue primary and clamps negatives', () async {
      final AnalyticsPaymentsService service = AnalyticsPaymentsService(
        repository: _FakeAnalyticsRepository(
          const PaymentSplitSummary(
            cashRevenueMinor: -100,
            cardRevenueMinor: 2400,
            totalRevenueMinor: -50,
            cashOrderCount: -2,
            cardOrderCount: 3,
          ),
        ),
      );

      expect(
        await service.getPaymentSplitSummary(_range()),
        const PaymentSplitSummary(
          cashRevenueMinor: 0,
          cardRevenueMinor: 2400,
          totalRevenueMinor: 2400,
          cashOrderCount: 0,
          cardOrderCount: 3,
        ),
      );
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
  const _FakeAnalyticsRepository(this._summary);

  final PaymentSplitSummary _summary;

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
    return const <DailyRevenuePoint>[];
  }

  @override
  Future<OverviewMetrics> getOverviewMetrics(AnalyticsDateRange range) async {
    return const OverviewMetrics.empty();
  }

  @override
  Future<PaymentSplitSummary> getPaymentSplit(AnalyticsDateRange range) async {
    return _summary;
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
    return const RevenueMetrics.empty();
  }
}
