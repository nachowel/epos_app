import 'payment_split_summary.dart';
import 'top_product_summary.dart';

class OverviewMetrics {
  const OverviewMetrics({
    required this.totalRevenueMinor,
    required this.orderCount,
    required this.averageOrderValueMinor,
    required this.topProductsPreview,
    required this.paymentSplitSummary,
  });

  const OverviewMetrics.empty()
    : totalRevenueMinor = 0,
      orderCount = 0,
      averageOrderValueMinor = 0,
      topProductsPreview = const <TopProductSummary>[],
      paymentSplitSummary = const PaymentSplitSummary.empty();

  final int totalRevenueMinor;
  final int orderCount;
  final int averageOrderValueMinor;
  final List<TopProductSummary> topProductsPreview;
  final PaymentSplitSummary paymentSplitSummary;

  bool get hasData => totalRevenueMinor > 0 || orderCount > 0;

  OverviewMetrics copyWith({
    int? totalRevenueMinor,
    int? orderCount,
    int? averageOrderValueMinor,
    List<TopProductSummary>? topProductsPreview,
    PaymentSplitSummary? paymentSplitSummary,
  }) {
    return OverviewMetrics(
      totalRevenueMinor: totalRevenueMinor ?? this.totalRevenueMinor,
      orderCount: orderCount ?? this.orderCount,
      averageOrderValueMinor:
          averageOrderValueMinor ?? this.averageOrderValueMinor,
      topProductsPreview: topProductsPreview ?? this.topProductsPreview,
      paymentSplitSummary: paymentSplitSummary ?? this.paymentSplitSummary,
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
        other.paymentSplitSummary == paymentSplitSummary;
  }

  @override
  int get hashCode => Object.hash(
    totalRevenueMinor,
    orderCount,
    averageOrderValueMinor,
    Object.hashAll(topProductsPreview),
    paymentSplitSummary,
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
