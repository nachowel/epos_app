import 'payment_split_summary.dart';
import 'top_product_summary.dart';

class OverviewMetrics {
  const OverviewMetrics({
    required this.totalRevenueMinor,
    required this.orderCount,
    required this.averageOrderValueMinor,
    required this.topProductsPreview,
    required this.paymentSplitSummary,
    this.customSalesRevenueMinor = 0,
    this.customSalesCount = 0,
    this.customSalesAverageValueMinor = 0,
  });

  const OverviewMetrics.empty()
    : totalRevenueMinor = 0,
      orderCount = 0,
      averageOrderValueMinor = 0,
      topProductsPreview = const <TopProductSummary>[],
      paymentSplitSummary = const PaymentSplitSummary.empty(),
      customSalesRevenueMinor = 0,
      customSalesCount = 0,
      customSalesAverageValueMinor = 0;

  final int totalRevenueMinor;
  final int orderCount;
  final int averageOrderValueMinor;
  final List<TopProductSummary> topProductsPreview;
  final PaymentSplitSummary paymentSplitSummary;
  final int customSalesRevenueMinor;
  final int customSalesCount;
  final int customSalesAverageValueMinor;

  bool get hasData => totalRevenueMinor > 0 || orderCount > 0;

  OverviewMetrics copyWith({
    int? totalRevenueMinor,
    int? orderCount,
    int? averageOrderValueMinor,
    List<TopProductSummary>? topProductsPreview,
    PaymentSplitSummary? paymentSplitSummary,
    int? customSalesRevenueMinor,
    int? customSalesCount,
    int? customSalesAverageValueMinor,
  }) {
    return OverviewMetrics(
      totalRevenueMinor: totalRevenueMinor ?? this.totalRevenueMinor,
      orderCount: orderCount ?? this.orderCount,
      averageOrderValueMinor:
          averageOrderValueMinor ?? this.averageOrderValueMinor,
      topProductsPreview: topProductsPreview ?? this.topProductsPreview,
      paymentSplitSummary: paymentSplitSummary ?? this.paymentSplitSummary,
      customSalesRevenueMinor:
          customSalesRevenueMinor ?? this.customSalesRevenueMinor,
      customSalesCount: customSalesCount ?? this.customSalesCount,
      customSalesAverageValueMinor:
          customSalesAverageValueMinor ?? this.customSalesAverageValueMinor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OverviewMetrics &&
        other.totalRevenueMinor == totalRevenueMinor &&
        other.orderCount == orderCount &&
        other.averageOrderValueMinor == averageOrderValueMinor &&
        _listEquals(other.topProductsPreview, topProductsPreview) &&
        other.paymentSplitSummary == paymentSplitSummary &&
        other.customSalesRevenueMinor == customSalesRevenueMinor &&
        other.customSalesCount == customSalesCount &&
        other.customSalesAverageValueMinor == customSalesAverageValueMinor;
  }

  @override
  int get hashCode => Object.hash(
    totalRevenueMinor,
    orderCount,
    averageOrderValueMinor,
    Object.hashAll(topProductsPreview),
    paymentSplitSummary,
    customSalesRevenueMinor,
    customSalesCount,
    customSalesAverageValueMinor,
  );

  bool _listEquals(
    List<TopProductSummary> left,
    List<TopProductSummary> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }
}
