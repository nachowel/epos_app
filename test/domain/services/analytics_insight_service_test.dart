import 'package:epos_app/domain/models/analytics/analytics_insight.dart';
import 'package:epos_app/domain/models/analytics/analytics_revenue_preset.dart';
import 'package:epos_app/domain/models/analytics/category_product_analytics_section.dart';
import 'package:epos_app/domain/models/analytics/payment_split_summary.dart';
import 'package:epos_app/domain/models/analytics/product_analytics_item.dart';
import 'package:epos_app/domain/models/analytics/revenue_detail_summary.dart';
import 'package:epos_app/domain/services/analytics_insight_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsInsightService', () {
    test('builds revenue up insight from comparison delta', () {
      const AnalyticsInsightService service = AnalyticsInsightService();

      final List<AnalyticsInsight> insights = service.buildOverviewInsights(
        revenueSummary: _summary(
          totalRevenueMinor: 15000,
          comparisonRevenueMinor: 10000,
          comparisonDeltaRevenueMinor: 5000,
        ),
        categorySections: const <CategoryProductAnalyticsSection>[],
        paymentSplitSummary: const PaymentSplitSummary.empty(),
      );

      expect(
        insights.first,
        const AnalyticsInsight(
          message: 'Revenue is up 50% vs last period',
          type: AnalyticsInsightType.revenue,
          priority: 1,
        ),
      );
    });

    test('builds revenue down insight from comparison delta', () {
      const AnalyticsInsightService service = AnalyticsInsightService();

      final List<AnalyticsInsight> insights = service.buildOverviewInsights(
        revenueSummary: _summary(
          totalRevenueMinor: 8000,
          comparisonRevenueMinor: 10000,
          comparisonDeltaRevenueMinor: -2000,
        ),
        categorySections: const <CategoryProductAnalyticsSection>[],
        paymentSplitSummary: const PaymentSplitSummary.empty(),
      );

      expect(
        insights.first,
        const AnalyticsInsight(
          message: 'Revenue is down 20% vs last period',
          type: AnalyticsInsightType.revenue,
          priority: 1,
        ),
      );
    });

    test('builds dominant payment insight', () {
      const AnalyticsInsightService service = AnalyticsInsightService();

      final List<AnalyticsInsight> insights = service.buildOverviewInsights(
        revenueSummary: null,
        categorySections: const <CategoryProductAnalyticsSection>[],
        paymentSplitSummary: const PaymentSplitSummary(
          cashRevenueMinor: 3000,
          cardRevenueMinor: 7000,
          totalRevenueMinor: 10000,
          cashOrderCount: 3,
          cardOrderCount: 7,
        ),
      );

      expect(
        insights.single,
        const AnalyticsInsight(
          message: 'Card payments dominate (70%)',
          type: AnalyticsInsightType.payment,
          priority: 3,
        ),
      );
    });

    test('builds balanced payment insight for mid split', () {
      const AnalyticsInsightService service = AnalyticsInsightService();

      final List<AnalyticsInsight> insights = service.buildOverviewInsights(
        revenueSummary: null,
        categorySections: const <CategoryProductAnalyticsSection>[],
        paymentSplitSummary: const PaymentSplitSummary(
          cashRevenueMinor: 4800,
          cardRevenueMinor: 5200,
          totalRevenueMinor: 10000,
          cashOrderCount: 4,
          cardOrderCount: 5,
        ),
      );

      expect(
        insights.single,
        const AnalyticsInsight(
          message: 'Payments are balanced between card and cash',
          type: AnalyticsInsightType.payment,
          priority: 3,
        ),
      );
    });

    test('builds top category insight from highest revenue section', () {
      const AnalyticsInsightService service = AnalyticsInsightService();

      final List<AnalyticsInsight> insights = service.buildOverviewInsights(
        revenueSummary: null,
        categorySections: const <CategoryProductAnalyticsSection>[
          CategoryProductAnalyticsSection(
            categoryId: 1,
            categoryName: 'Breakfasts',
            totalRevenueMinor: 22000,
            products: <ProductAnalyticsItem>[],
          ),
          CategoryProductAnalyticsSection(
            categoryId: 2,
            categoryName: 'Coffee',
            totalRevenueMinor: 18000,
            products: <ProductAnalyticsItem>[],
          ),
        ],
        paymentSplitSummary: const PaymentSplitSummary.empty(),
      );

      expect(
        insights.single,
        const AnalyticsInsight(
          message: 'Breakfasts led revenue (55%)',
          type: AnalyticsInsightType.product,
          priority: 2,
        ),
      );
    });

    test('suppresses aov insight when order count is too low', () {
      const AnalyticsInsightService service = AnalyticsInsightService();

      final List<AnalyticsInsight> insights = service.buildOverviewInsights(
        revenueSummary: _summary(
          totalRevenueMinor: 15000,
          orderCount: 8,
          comparisonRevenueMinor: 0,
          comparisonDeltaRevenueMinor: 0,
        ),
        categorySections: const <CategoryProductAnalyticsSection>[],
        paymentSplitSummary: const PaymentSplitSummary.empty(),
      );

      expect(insights, isEmpty);
    });

    test('suppresses revenue insight for small percentage deltas', () {
      const AnalyticsInsightService service = AnalyticsInsightService();

      final List<AnalyticsInsight> insights = service.buildOverviewInsights(
        revenueSummary: _summary(
          totalRevenueMinor: 10300,
          comparisonRevenueMinor: 10000,
          comparisonDeltaRevenueMinor: 300,
        ),
        categorySections: const <CategoryProductAnalyticsSection>[],
        paymentSplitSummary: const PaymentSplitSummary.empty(),
      );

      expect(insights, isEmpty);
    });

    test('suppresses top category insight below share threshold', () {
      const AnalyticsInsightService service = AnalyticsInsightService();

      final List<AnalyticsInsight> insights = service.buildOverviewInsights(
        revenueSummary: null,
        categorySections: const <CategoryProductAnalyticsSection>[
          CategoryProductAnalyticsSection(
            categoryId: 1,
            categoryName: 'Breakfasts',
            totalRevenueMinor: 3900,
            products: <ProductAnalyticsItem>[],
          ),
          CategoryProductAnalyticsSection(
            categoryId: 2,
            categoryName: 'Coffee',
            totalRevenueMinor: 3200,
            products: <ProductAnalyticsItem>[],
          ),
          CategoryProductAnalyticsSection(
            categoryId: 3,
            categoryName: 'Bakery',
            totalRevenueMinor: 2900,
            products: <ProductAnalyticsItem>[],
          ),
        ],
        paymentSplitSummary: const PaymentSplitSummary.empty(),
      );

      expect(insights, isEmpty);
    });

    test('revenue insight suppresses lower-priority aov insight', () {
      const AnalyticsInsightService service = AnalyticsInsightService();

      final List<AnalyticsInsight> insights = service.buildOverviewInsights(
        revenueSummary: _summary(
          totalRevenueMinor: 15000,
          orderCount: 12,
          averageOrderValueMinor: 2500,
          comparisonRevenueMinor: 10000,
          comparisonAverageOrderValueMinor: 2000,
          comparisonDeltaRevenueMinor: 5000,
        ),
        categorySections: const <CategoryProductAnalyticsSection>[
          CategoryProductAnalyticsSection(
            categoryId: 1,
            categoryName: 'Breakfasts',
            totalRevenueMinor: 22000,
            products: <ProductAnalyticsItem>[],
          ),
        ],
        paymentSplitSummary: const PaymentSplitSummary(
          cashRevenueMinor: 3000,
          cardRevenueMinor: 7000,
          totalRevenueMinor: 10000,
          cashOrderCount: 3,
          cardOrderCount: 7,
        ),
      );

      expect(insights, hasLength(3));
      expect(
        insights.map((AnalyticsInsight insight) => insight.type),
        <AnalyticsInsightType?>[
          AnalyticsInsightType.revenue,
          AnalyticsInsightType.product,
          AnalyticsInsightType.payment,
        ],
      );
    });
  });
}

RevenueDetailSummary _summary({
  required int totalRevenueMinor,
  required int comparisonRevenueMinor,
  required int comparisonDeltaRevenueMinor,
  int orderCount = 6,
  int averageOrderValueMinor = 2000,
  int comparisonAverageOrderValueMinor = 1800,
}) {
  return RevenueDetailSummary(
    preset: AnalyticsRevenuePreset.thisWeek,
    totalRevenueMinor: totalRevenueMinor,
    orderCount: orderCount,
    averageOrderValueMinor: averageOrderValueMinor,
    dailyRevenueSeries: const [],
    comparisonLabel: 'Compared to last week',
    comparisonRevenueMinor: comparisonRevenueMinor,
    comparisonOrderCount: 5,
    comparisonAverageOrderValueMinor: comparisonAverageOrderValueMinor,
    comparisonDeltaRevenueMinor: comparisonDeltaRevenueMinor,
    comparisonDirection: comparisonDeltaRevenueMinor > 0
        ? RevenueComparisonDirection.up
        : RevenueComparisonDirection.down,
  );
}
