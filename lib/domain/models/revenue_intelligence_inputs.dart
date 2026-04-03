import 'revenue_comparison.dart';

class RevenueIntelligenceInputs {
  const RevenueIntelligenceInputs({
    required this.todayOrderCount,
    required this.monthOrderCount,
    required this.averageOrderValueThisWeek,
    required this.averageOrderValueThisMonth,
    required this.thisWeekPaymentMix,
    required this.thisMonthPaymentMix,
    required this.thisWeekCancelledOrderCount,
    required this.thisMonthCancelledOrderCount,
    required this.daypartDistribution,
    required this.topProductsCurrentPeriod,
    required this.topProductsPreviousPeriod,
    required this.dataQualityNotes,
  });

  final RevenueComparison todayOrderCount;
  final RevenueComparison monthOrderCount;
  final RevenueComparison averageOrderValueThisWeek;
  final RevenueComparison averageOrderValueThisMonth;
  final RevenuePaymentMixComparison thisWeekPaymentMix;
  final RevenuePaymentMixComparison thisMonthPaymentMix;
  final RevenueComparison thisWeekCancelledOrderCount;
  final RevenueComparison thisMonthCancelledOrderCount;
  final List<RevenueDaypartPoint> daypartDistribution;
  final List<RevenueProductMover> topProductsCurrentPeriod;
  final List<RevenueProductMover> topProductsPreviousPeriod;
  final List<String> dataQualityNotes;
}

class RevenuePaymentMixComparison {
  const RevenuePaymentMixComparison({
    required this.cashRevenue,
    required this.cardRevenue,
  });

  final RevenueComparison cashRevenue;
  final RevenueComparison cardRevenue;
}

class RevenueDaypartPoint {
  const RevenueDaypartPoint({
    required this.daypart,
    required this.orderCount,
    required this.revenueMinor,
  });

  final String daypart;
  final int orderCount;
  final int revenueMinor;
}

class RevenueProductMover {
  const RevenueProductMover({
    required this.productKey,
    required this.productName,
    required this.quantitySold,
    required this.revenueMinor,
  });

  final String productKey;
  final String productName;
  final int quantitySold;
  final int revenueMinor;
}
