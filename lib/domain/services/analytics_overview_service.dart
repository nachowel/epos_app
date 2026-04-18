import '../../data/repositories/analytics_repository.dart';
import '../models/analytics/analytics_date_range.dart';
import '../models/analytics/overview_metrics.dart';
import '../models/analytics/payment_split_summary.dart';
import '../models/analytics/top_product_summary.dart';

class AnalyticsOverviewService {
  const AnalyticsOverviewService({
    required AnalyticsRepository repository,
    this.defaultTopProductsLimit = 3,
  }) : _repository = repository,
       assert(defaultTopProductsLimit > 0);

  final AnalyticsRepository _repository;
  final int defaultTopProductsLimit;

  Future<OverviewMetrics> getOverviewMetrics(AnalyticsDateRange range) async {
    final OverviewMetrics metrics = _normalizeOverviewMetrics(
      await _repository.getOverviewMetrics(range),
    );

    return OverviewMetrics(
      totalRevenueMinor: metrics.totalRevenueMinor,
      orderCount: metrics.orderCount,
      averageOrderValueMinor: metrics.averageOrderValueMinor,
      topProductsPreview: metrics.topProductsPreview,
      paymentSplitSummary: metrics.paymentSplitSummary,
      customSalesRevenueMinor: metrics.customSalesRevenueMinor,
      customSalesCount: metrics.customSalesCount,
      customSalesAverageValueMinor: metrics.customSalesAverageValueMinor,
    );
  }

  OverviewMetrics _normalizeOverviewMetrics(OverviewMetrics metrics) {
    final int totalRevenueMinor = _normalizeRevenueMinor(
      metrics.totalRevenueMinor,
    );
    final int orderCount = _normalizeOrderCount(metrics.orderCount);

    return OverviewMetrics(
      totalRevenueMinor: totalRevenueMinor,
      orderCount: orderCount,
      averageOrderValueMinor: _normalizeAverageOrderValueMinor(
        rawAverageOrderValueMinor: metrics.averageOrderValueMinor,
        totalRevenueMinor: totalRevenueMinor,
        orderCount: orderCount,
      ),
      topProductsPreview: metrics.topProductsPreview
          .take(defaultTopProductsLimit)
          .map(_normalizeTopProduct)
          .where((TopProductSummary summary) => summary.hasSales)
          .toList(growable: false),
      paymentSplitSummary: _normalizePaymentSplit(metrics.paymentSplitSummary),
      customSalesRevenueMinor: _normalizeRevenueMinor(
        metrics.customSalesRevenueMinor,
      ),
      customSalesCount: _normalizeOrderCount(metrics.customSalesCount),
      customSalesAverageValueMinor: _normalizeAverageOrderValueMinor(
        rawAverageOrderValueMinor: metrics.customSalesAverageValueMinor,
        totalRevenueMinor: _normalizeRevenueMinor(
          metrics.customSalesRevenueMinor,
        ),
        orderCount: _normalizeOrderCount(metrics.customSalesCount),
      ),
    );
  }

  TopProductSummary _normalizeTopProduct(TopProductSummary summary) {
    return summary.copyWith(
      productName: summary.productName.trim(),
      revenueMinor: _normalizeRevenueMinor(summary.revenueMinor),
      quantityCount: summary.quantityCount == null
          ? null
          : _normalizeOrderCount(summary.quantityCount!),
    );
  }

  PaymentSplitSummary _normalizePaymentSplit(PaymentSplitSummary summary) {
    return PaymentSplitSummary(
      cashRevenueMinor: _normalizeRevenueMinor(summary.cashRevenueMinor),
      cardRevenueMinor: _normalizeRevenueMinor(summary.cardRevenueMinor),
      totalRevenueMinor: _normalizeRevenueMinor(summary.totalRevenueMinor),
      cashOrderCount: _normalizeOrderCount(summary.cashOrderCount),
      cardOrderCount: _normalizeOrderCount(summary.cardOrderCount),
    );
  }

  int _normalizeAverageOrderValueMinor({
    required int rawAverageOrderValueMinor,
    required int totalRevenueMinor,
    required int orderCount,
  }) {
    if (orderCount <= 0) {
      return 0;
    }
    final int rawClamped = _normalizeRevenueMinor(rawAverageOrderValueMinor);
    if (rawClamped > 0) {
      return rawClamped;
    }
    return totalRevenueMinor ~/ orderCount;
  }

  int _normalizeRevenueMinor(int value) => value < 0 ? 0 : value;

  int _normalizeOrderCount(int value) => value < 0 ? 0 : value;
}
