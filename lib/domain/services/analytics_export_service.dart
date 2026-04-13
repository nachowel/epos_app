import 'dart:convert';

import '../../core/utils/currency_formatter.dart';
import '../models/analytics/analytics_date_range.dart';
import '../models/analytics/analytics_detail_preset.dart';
import '../models/analytics/category_product_analytics_section.dart';
import '../models/analytics/overview_metrics.dart';
import '../models/analytics/payment_split_summary.dart';
import '../models/analytics/product_analytics_item.dart';
import '../models/analytics/revenue_detail_summary.dart';
import '../models/analytics/top_product_summary.dart';
import 'analytics_overview_service.dart';
import 'analytics_payments_service.dart';
import 'analytics_products_service.dart';
import 'analytics_revenue_service.dart';

class AnalyticsExportService {
  const AnalyticsExportService({
    required AnalyticsOverviewService overviewService,
    required AnalyticsRevenueService revenueService,
    required AnalyticsProductsService productsService,
    required AnalyticsPaymentsService paymentsService,
    DateTime Function()? nowProvider,
  }) : _overviewService = overviewService,
       _revenueService = revenueService,
       _productsService = productsService,
       _paymentsService = paymentsService,
       _nowProvider = nowProvider ?? DateTime.now;

  static const String analysisPrompt =
      'Analyze this cafe analytics data.\n\n'
      'Focus on:\n'
      '- revenue trends\n'
      '- best performing categories\n'
      '- weak areas\n'
      '- payment behavior\n'
      '- actionable insights\n\n'
      'Keep it short and practical.';

  final AnalyticsOverviewService _overviewService;
  final AnalyticsRevenueService _revenueService;
  final AnalyticsProductsService _productsService;
  final AnalyticsPaymentsService _paymentsService;
  final DateTime Function() _nowProvider;

  Future<String> exportAnalytics({
    required AnalyticsDetailPreset preset,
  }) async {
    final DateTime now = _nowProvider();
    final AnalyticsDateRange range = AnalyticsDateRange.resolvePreset(
      preset: analyticsDateRangePresetFromDetailPreset(preset),
      now: now,
    );

    final List<dynamic> results = await Future.wait<dynamic>(<Future<dynamic>>[
      _overviewService.getOverviewMetrics(range),
      _revenueService.getRevenueDetailSummary(
        preset: analyticsRevenuePresetFromDetailPreset(preset),
        now: now,
      ),
      _productsService.getCategoryProductSections(range),
      _paymentsService.getPaymentSplitSummary(range),
    ]);

    final OverviewMetrics overview = results[0] as OverviewMetrics;
    final RevenueDetailSummary revenue = results[1] as RevenueDetailSummary;
    final List<CategoryProductAnalyticsSection> categories =
        results[2] as List<CategoryProductAnalyticsSection>;
    final PaymentSplitSummary paymentSplit = results[3] as PaymentSplitSummary;

    final Map<String, Object> payload = <String, Object>{
      'summary': _buildSummary(
        preset: preset,
        overview: overview,
        revenue: revenue,
      ),
      'dailyRevenue': _buildDailyRevenue(revenue),
      'topProducts': _buildTopProducts(overview.topProductsPreview),
      'categories': _buildCategories(categories),
      'paymentSplit': _buildPaymentSplit(paymentSplit),
      'analysisPrompt': analysisPrompt,
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Map<String, Object> _buildSummary({
    required AnalyticsDetailPreset preset,
    required OverviewMetrics overview,
    required RevenueDetailSummary revenue,
  }) {
    return <String, Object>{
      'selectedPreset': <String, Object>{
        'key': analyticsDetailPresetQueryValue(preset),
        'label': analyticsDetailPresetLabel(preset),
      },
      'totalRevenue': _money(overview.totalRevenueMinor),
      'orderCount': overview.orderCount,
      'aov': _money(overview.averageOrderValueMinor),
      'comparisonRevenue': _money(revenue.comparisonRevenueMinor),
      'comparisonDeltaPercent': _deltaPercent(
        deltaMinor: revenue.comparisonDeltaRevenueMinor,
        baselineMinor: revenue.comparisonRevenueMinor,
      ),
      'comparisonLabel': revenue.comparisonLabel,
    };
  }

  List<Map<String, Object>> _buildDailyRevenue(RevenueDetailSummary revenue) {
    return revenue.dailyRevenueSeries
        .map(
          (point) => <String, Object>{
            'date': _date(point.date),
            'revenue': _money(point.revenueMinor),
          },
        )
        .toList(growable: false);
  }

  List<Map<String, Object>> _buildTopProducts(
    List<TopProductSummary> products,
  ) {
    return products
        .map(
          (product) => <String, Object>{
            'productName': product.productName,
            'revenue': _money(product.revenueMinor),
            'quantity': product.quantityCount ?? 0,
          },
        )
        .toList(growable: false);
  }

  List<Map<String, Object>> _buildCategories(
    List<CategoryProductAnalyticsSection> categories,
  ) {
    return categories
        .map(
          (section) => <String, Object>{
            'categoryName': section.categoryName,
            'totalRevenue': _money(section.totalRevenueMinor),
            'topProducts': section.products
                .take(5)
                .map(
                  (ProductAnalyticsItem product) => <String, Object>{
                    'productName': product.productName,
                    'revenue': _money(product.revenueMinor),
                    'quantity': product.quantityCount,
                  },
                )
                .toList(growable: false),
          },
        )
        .toList(growable: false);
  }

  Map<String, Object> _buildPaymentSplit(PaymentSplitSummary summary) {
    return <String, Object>{
      'cardRevenue': _money(summary.cardRevenueMinor),
      'cashRevenue': _money(summary.cashRevenueMinor),
      'cardOrders': summary.cardOrderCount,
      'cashOrders': summary.cashOrderCount,
      'cardSharePercent': _sharePercent(summary.cardRevenueShare),
      'cashSharePercent': _sharePercent(summary.cashRevenueShare),
    };
  }

  Map<String, Object> _money(int minor) {
    return <String, Object>{
      'minor': minor,
      'formatted': CurrencyFormatter.fromMinor(minor),
    };
  }

  String _date(DateTime value) {
    return value.toIso8601String().split('T').first;
  }

  int _deltaPercent({required int deltaMinor, required int baselineMinor}) {
    if (baselineMinor <= 0) {
      return 0;
    }
    return ((deltaMinor / baselineMinor) * 100).round();
  }

  int _sharePercent(double? share) {
    if (share == null) {
      return 0;
    }
    return (share * 100).round();
  }
}
