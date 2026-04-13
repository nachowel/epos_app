import '../models/analytics/analytics_insight.dart';
import '../models/analytics/category_product_analytics_section.dart';
import '../models/analytics/payment_split_summary.dart';
import '../models/analytics/revenue_detail_summary.dart';

class AnalyticsInsightService {
  const AnalyticsInsightService({this.maxInsights = 4})
    : assert(maxInsights > 0);

  final int maxInsights;
  static const int _minimumMeaningfulDeltaPercent = 5;
  static const int _minimumAovOrderCount = 10;
  static const double _dominantPaymentShareThreshold = 0.65;
  static const double _balancedPaymentShareThreshold = 0.45;
  static const double _topCategoryShareThreshold = 0.40;

  List<AnalyticsInsight> buildOverviewInsights({
    RevenueDetailSummary? revenueSummary,
    required List<CategoryProductAnalyticsSection> categorySections,
    required PaymentSplitSummary paymentSplitSummary,
  }) {
    final AnalyticsInsight? revenueInsight = _buildRevenueInsight(
      revenueSummary,
    );
    final AnalyticsInsight? aovInsight = revenueInsight == null
        ? _buildAovInsight(revenueSummary)
        : null;
    final List<AnalyticsInsight> insights = <AnalyticsInsight>[
      if (revenueInsight case final AnalyticsInsight item) item,
      if (_buildTopCategoryInsight(categorySections)
          case final AnalyticsInsight item)
        item,
      if (_buildPaymentInsight(paymentSplitSummary)
          case final AnalyticsInsight item)
        item,
      if (aovInsight case final AnalyticsInsight item) item,
    ];
    final Map<AnalyticsInsightType?, AnalyticsInsight> uniqueByType =
        <AnalyticsInsightType?, AnalyticsInsight>{};
    for (final AnalyticsInsight insight in insights) {
      uniqueByType[insight.type] ??= insight;
    }
    final List<AnalyticsInsight> uniqueInsights = uniqueByType.values.toList(
      growable: false,
    );

    uniqueInsights.sort((AnalyticsInsight left, AnalyticsInsight right) {
      final int leftPriority = left.priority ?? maxInsights + 1;
      final int rightPriority = right.priority ?? maxInsights + 1;
      return leftPriority.compareTo(rightPriority);
    });

    return uniqueInsights.take(maxInsights).toList(growable: false);
  }

  AnalyticsInsight? _buildRevenueInsight(RevenueDetailSummary? summary) {
    if (summary == null || summary.comparisonRevenueMinor <= 0) {
      return null;
    }
    if (summary.comparisonDeltaRevenueMinor == 0) {
      return null;
    }

    final int percent = _deltaPercent(
      deltaMinor: summary.comparisonDeltaRevenueMinor,
      baselineMinor: summary.comparisonRevenueMinor,
    );
    if (percent < _minimumMeaningfulDeltaPercent) {
      return null;
    }
    final bool isUp = summary.comparisonDeltaRevenueMinor > 0;
    return AnalyticsInsight(
      message: 'Revenue is ${isUp ? 'up' : 'down'} $percent% vs last period',
      type: AnalyticsInsightType.revenue,
      priority: 1,
    );
  }

  AnalyticsInsight? _buildTopCategoryInsight(
    List<CategoryProductAnalyticsSection> sections,
  ) {
    if (sections.isEmpty) {
      return null;
    }
    final CategoryProductAnalyticsSection topSection = sections.first;
    final String categoryName = topSection.categoryName.trim();
    if (categoryName.isEmpty || topSection.totalRevenueMinor <= 0) {
      return null;
    }
    final int totalRevenueMinor = sections.fold<int>(
      0,
      (int sum, CategoryProductAnalyticsSection section) =>
          sum + section.totalRevenueMinor,
    );
    if (totalRevenueMinor <= 0) {
      return null;
    }
    final double topCategoryShare =
        topSection.totalRevenueMinor / totalRevenueMinor;
    if (topCategoryShare < _topCategoryShareThreshold) {
      return null;
    }

    return AnalyticsInsight(
      message:
          '$categoryName led revenue (${(topCategoryShare * 100).round()}%)',
      type: AnalyticsInsightType.product,
      priority: 2,
    );
  }

  AnalyticsInsight? _buildPaymentInsight(PaymentSplitSummary summary) {
    if (summary.totalRevenueMinor <= 0) {
      return null;
    }

    final double cardShare = summary.cardRevenueShare ?? 0;
    final double cashShare = summary.cashRevenueShare ?? 0;
    if (cardShare >= _dominantPaymentShareThreshold) {
      return AnalyticsInsight(
        message: 'Card payments dominate (${(cardShare * 100).round()}%)',
        type: AnalyticsInsightType.payment,
        priority: 3,
      );
    }
    if (cashShare >= _dominantPaymentShareThreshold) {
      return AnalyticsInsight(
        message: 'Cash payments dominate (${(cashShare * 100).round()}%)',
        type: AnalyticsInsightType.payment,
        priority: 3,
      );
    }
    if (cardShare >= _balancedPaymentShareThreshold &&
        cashShare >= _balancedPaymentShareThreshold) {
      return const AnalyticsInsight(
        message: 'Payments are balanced between card and cash',
        type: AnalyticsInsightType.payment,
        priority: 3,
      );
    }
    final bool cashIsMinor = cashShare < _balancedPaymentShareThreshold;
    final double minorShare = cashIsMinor ? cashShare : cardShare;
    final String methodLabel = cashIsMinor ? 'Cash' : 'Card';
    return AnalyticsInsight(
      message: '$methodLabel usage is minor (${(minorShare * 100).round()}%)',
      type: AnalyticsInsightType.payment,
      priority: 3,
    );
  }

  AnalyticsInsight? _buildAovInsight(RevenueDetailSummary? summary) {
    if (summary == null ||
        summary.orderCount < _minimumAovOrderCount ||
        summary.comparisonAverageOrderValueMinor <= 0) {
      return null;
    }
    final int deltaMinor =
        summary.averageOrderValueMinor -
        summary.comparisonAverageOrderValueMinor;
    if (deltaMinor == 0) {
      return null;
    }

    final int percent = _deltaPercent(
      deltaMinor: deltaMinor,
      baselineMinor: summary.comparisonAverageOrderValueMinor,
    );
    if (percent < _minimumMeaningfulDeltaPercent) {
      return null;
    }
    final bool isUp = deltaMinor > 0;
    return AnalyticsInsight(
      message: 'AOV is ${isUp ? 'up' : 'down'} $percent% vs last period',
      type: AnalyticsInsightType.aov,
      priority: 4,
    );
  }

  int _deltaPercent({required int deltaMinor, required int baselineMinor}) {
    if (baselineMinor <= 0) {
      return 0;
    }
    return ((deltaMinor.abs() / baselineMinor) * 100).round();
  }
}
