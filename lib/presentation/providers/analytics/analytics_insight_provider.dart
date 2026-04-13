import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../domain/models/analytics/analytics_date_range.dart';
import '../../../domain/models/analytics/analytics_insight.dart';
import '../../../domain/models/analytics/analytics_revenue_preset.dart';
import '../../../domain/models/analytics/category_product_analytics_section.dart';
import '../../../domain/models/analytics/payment_split_summary.dart';
import '../../../domain/models/analytics/revenue_detail_summary.dart';
import 'analytics_overview_provider.dart';

final FutureProvider<List<AnalyticsInsight>> analyticsOverviewInsightsProvider =
    FutureProvider<List<AnalyticsInsight>>((Ref ref) async {
      final AnalyticsOverviewState overviewState = ref.watch(
        analyticsOverviewNotifierProvider,
      );
      if (!overviewState.hasLoaded || overviewState.isEmpty) {
        return const <AnalyticsInsight>[];
      }

      final AnalyticsDateRange range = overviewState.range;
      final AnalyticsDateRangePreset preset = overviewState.selectedPreset;
      final Future<List<CategoryProductAnalyticsSection>> categoryFuture = ref
          .read(analyticsProductsServiceProvider)
          .getCategoryProductSections(range);
      final Future<PaymentSplitSummary> paymentFuture = ref
          .read(analyticsPaymentsServiceProvider)
          .getPaymentSplitSummary(range);
      final Future<RevenueDetailSummary?> revenueFuture =
          switch (_comparisonPresetForOverviewPreset(preset)) {
            final AnalyticsRevenuePreset comparablePreset =>
              ref
                  .read(analyticsRevenueServiceProvider)
                  .getRevenueDetailSummary(
                    preset: comparablePreset,
                    now: range.endExclusive.subtract(
                      const Duration(minutes: 1),
                    ),
                  ),
            null => Future<RevenueDetailSummary?>.value(null),
          };

      final List<dynamic> results = await Future.wait<dynamic>(
        <Future<dynamic>>[categoryFuture, paymentFuture, revenueFuture],
      );

      return ref
          .read(analyticsInsightServiceProvider)
          .buildOverviewInsights(
            revenueSummary: results[2] as RevenueDetailSummary?,
            categorySections:
                results[0] as List<CategoryProductAnalyticsSection>,
            paymentSplitSummary: results[1] as PaymentSplitSummary,
          );
    });

AnalyticsRevenuePreset? _comparisonPresetForOverviewPreset(
  AnalyticsDateRangePreset preset,
) {
  return switch (preset) {
    AnalyticsDateRangePreset.thisWeek => AnalyticsRevenuePreset.thisWeek,
    AnalyticsDateRangePreset.thisMonth => AnalyticsRevenuePreset.thisMonth,
    AnalyticsDateRangePreset.lastWeek => AnalyticsRevenuePreset.lastWeek,
    AnalyticsDateRangePreset.last2Weeks => AnalyticsRevenuePreset.last2Weeks,
    AnalyticsDateRangePreset.today || AnalyticsDateRangePreset.explicit => null,
  };
}
