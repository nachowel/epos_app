import 'dart:convert';

import 'package:epos_app/data/repositories/analytics_repository.dart';
import 'package:epos_app/domain/models/analytics/analytics_date_range.dart';
import 'package:epos_app/domain/models/analytics/analytics_detail_preset.dart';
import 'package:epos_app/domain/models/analytics/category_product_analytics_section.dart';
import 'package:epos_app/domain/models/analytics/daily_revenue_point.dart';
import 'package:epos_app/domain/models/analytics/overview_metrics.dart';
import 'package:epos_app/domain/models/analytics/payment_split_summary.dart';
import 'package:epos_app/domain/models/analytics/product_analytics_item.dart';
import 'package:epos_app/domain/models/analytics/revenue_metrics.dart';
import 'package:epos_app/domain/models/analytics/top_product_summary.dart';
import 'package:epos_app/domain/services/analytics_export_service.dart';
import 'package:epos_app/domain/services/analytics_overview_service.dart';
import 'package:epos_app/domain/services/analytics_payments_service.dart';
import 'package:epos_app/domain/services/analytics_products_service.dart';
import 'package:epos_app/domain/services/analytics_revenue_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsExportService', () {
    test('exports empty analytics payload with stable structure', () async {
      final AnalyticsExportService service = _service(
        const _FakeAnalyticsRepository.empty(),
      );

      final String json = await service.exportAnalytics(
        preset: AnalyticsDetailPreset.thisWeek,
      );
      final Map<String, dynamic> payload =
          jsonDecode(json) as Map<String, dynamic>;

      expect(payload['summary'], isA<Map<String, dynamic>>());
      expect(payload['dailyRevenue'], isA<List<dynamic>>());
      expect(payload['topProducts'], isA<List<dynamic>>());
      expect(payload['categories'], isA<List<dynamic>>());
      expect(payload['paymentSplit'], isA<Map<String, dynamic>>());
      expect(
        payload['analysisPrompt'],
        contains('Analyze this cafe analytics data.'),
      );
      expect(payload['summary']['orderCount'], 0);
      expect(payload['paymentSplit']['cardSharePercent'], 0);
      expect(_containsNull(payload), isFalse);
    });

    test(
      'exports populated analytics payload as parseable curated json',
      () async {
        final AnalyticsExportService service = _service(
          _FakeAnalyticsRepository(
            overviewMetrics: OverviewMetrics(
              totalRevenueMinor: 123456,
              orderCount: 12,
              averageOrderValueMinor: 10288,
              topProductsPreview: const <TopProductSummary>[
                TopProductSummary(
                  productId: 1,
                  productName: 'Flat White',
                  revenueMinor: 4020,
                  quantityCount: 18,
                ),
                TopProductSummary(
                  productId: 2,
                  productName: 'Croissant',
                  revenueMinor: 2210,
                  quantityCount: 9,
                ),
              ],
              paymentSplitSummary: const PaymentSplitSummary(
                cashRevenueMinor: 40000,
                cardRevenueMinor: 83456,
                totalRevenueMinor: 123456,
                cashOrderCount: 4,
                cardOrderCount: 8,
              ),
              customSalesRevenueMinor: 3456,
              customSalesCount: 3,
              customSalesAverageValueMinor: 1152,
            ),
            revenueMetricsByStart: <DateTime, RevenueMetrics>{
              DateTime(2026, 4, 13): const RevenueMetrics(
                totalRevenueMinor: 123456,
                orderCount: 12,
                averageOrderValueMinor: 10288,
              ),
              DateTime(2026, 4, 12): const RevenueMetrics(
                totalRevenueMinor: 100000,
                orderCount: 10,
                averageOrderValueMinor: 10000,
              ),
            },
            dailyRevenueByStart: <DateTime, List<DailyRevenuePoint>>{
              DateTime(2026, 4, 13): <DailyRevenuePoint>[
                DailyRevenuePoint(
                  date: DateTime(2026, 4, 13),
                  revenueMinor: 56789,
                  orderCount: 5,
                ),
              ],
            },
            categorySections: const <CategoryProductAnalyticsSection>[
              CategoryProductAnalyticsSection(
                categoryId: 1,
                categoryName: 'Coffee',
                totalRevenueMinor: 70000,
                products: <ProductAnalyticsItem>[
                  ProductAnalyticsItem(
                    productId: 1,
                    productName: 'Flat White',
                    revenueMinor: 4020,
                    quantityCount: 18,
                  ),
                  ProductAnalyticsItem(
                    productId: 2,
                    productName: 'Latte',
                    revenueMinor: 3000,
                    quantityCount: 14,
                  ),
                ],
              ),
            ],
            paymentSplit: const PaymentSplitSummary(
              cashRevenueMinor: 40000,
              cardRevenueMinor: 83456,
              totalRevenueMinor: 123456,
              cashOrderCount: 4,
              cardOrderCount: 8,
            ),
          ),
        );

        final String json = await service.exportAnalytics(
          preset: AnalyticsDetailPreset.thisWeek,
        );
        final Map<String, dynamic> payload =
            jsonDecode(json) as Map<String, dynamic>;

        expect(payload['summary']['selectedPreset']['key'], 'this_week');
        expect(payload['summary']['totalRevenue']['minor'], 123456);
        expect(payload['summary']['comparisonDeltaPercent'], 23);
        expect(payload['summary']['customSales']['revenue']['minor'], 3456);
        expect(payload['summary']['customSales']['count'], 3);
        expect(
          payload['summary']['customSales']['averageValue']['minor'],
          1152,
        );
        expect(payload['dailyRevenue'][0]['date'], '2026-04-13');
        expect(payload['topProducts'][0]['productName'], 'Flat White');
        expect(payload['topProducts'][0]['quantity'], 18);
        expect(payload['categories'][0]['categoryName'], 'Coffee');
        expect(
          payload['categories'][0]['topProducts'][0]['productName'],
          'Flat White',
        );
        expect(payload['paymentSplit']['cardSharePercent'], 68);
        expect(_containsNull(payload), isFalse);
      },
    );
  });
}

AnalyticsExportService _service(_FakeAnalyticsRepository repository) {
  return AnalyticsExportService(
    overviewService: AnalyticsOverviewService(repository: repository),
    revenueService: AnalyticsRevenueService(repository: repository),
    productsService: AnalyticsProductsService(repository: repository),
    paymentsService: AnalyticsPaymentsService(repository: repository),
    nowProvider: () => DateTime(2026, 4, 13, 10),
  );
}

bool _containsNull(Object? value) {
  if (value == null) {
    return true;
  }
  if (value is Map<Object?, Object?>) {
    return value.values.any(_containsNull);
  }
  if (value is Iterable<Object?>) {
    return value.any(_containsNull);
  }
  return false;
}

class _FakeAnalyticsRepository implements AnalyticsRepository {
  const _FakeAnalyticsRepository({
    required this.overviewMetrics,
    required this.revenueMetricsByStart,
    required this.dailyRevenueByStart,
    required this.categorySections,
    required this.paymentSplit,
  });

  const _FakeAnalyticsRepository.empty()
    : overviewMetrics = const OverviewMetrics.empty(),
      revenueMetricsByStart = const <DateTime, RevenueMetrics>{},
      dailyRevenueByStart = const <DateTime, List<DailyRevenuePoint>>{},
      categorySections = const <CategoryProductAnalyticsSection>[],
      paymentSplit = const PaymentSplitSummary.empty();

  final OverviewMetrics overviewMetrics;
  final Map<DateTime, RevenueMetrics> revenueMetricsByStart;
  final Map<DateTime, List<DailyRevenuePoint>> dailyRevenueByStart;
  final List<CategoryProductAnalyticsSection> categorySections;
  final PaymentSplitSummary paymentSplit;

  @override
  Future<List<CategoryProductAnalyticsSection>> getCategoryProductSections(
    AnalyticsDateRange range, {
    int perCategoryLimit = 5,
  }) async {
    return categorySections;
  }

  @override
  Future<List<DailyRevenuePoint>> getDailyRevenueSeries(
    AnalyticsDateRange range,
  ) async {
    return dailyRevenueByStart[range.startInclusive] ??
        const <DailyRevenuePoint>[];
  }

  @override
  Future<OverviewMetrics> getOverviewMetrics(AnalyticsDateRange range) async {
    return overviewMetrics;
  }

  @override
  Future<PaymentSplitSummary> getPaymentSplit(AnalyticsDateRange range) async {
    return paymentSplit;
  }

  @override
  Future<List<TopProductSummary>> getTopProductsOverall(
    AnalyticsDateRange range, {
    int limit = 3,
  }) async {
    return overviewMetrics.topProductsPreview;
  }

  @override
  Future<RevenueMetrics> getRevenueMetrics(AnalyticsDateRange range) async {
    return revenueMetricsByStart[range.startInclusive] ??
        const RevenueMetrics.empty();
  }
}
