import 'shift_report_category_line.dart';
import 'semantic_sales_analytics.dart';

class ShiftReport {
  const ShiftReport({
    required this.shiftId,
    required this.paidCount,
    required this.paidTotalMinor,
    this.refundCount = 0,
    this.refundTotalMinor = 0,
    this.netSalesMinor = 0,
    required this.openCount,
    required this.openTotalMinor,
    required this.cancelledCount,
    this.refundedOrderCount = 0,
    required this.cashCount,
    this.cashGrossTotalMinor = 0,
    required this.cashTotalMinor,
    required this.cardCount,
    this.cardGrossTotalMinor = 0,
    required this.cardTotalMinor,
    this.categoryBreakdown = const <ShiftReportCategoryLine>[],
    this.semanticSalesAnalytics = const SemanticSalesAnalytics.empty(),
  });

  final int shiftId;
  final int paidCount;
  final int paidTotalMinor;
  final int refundCount;
  final int refundTotalMinor;
  final int netSalesMinor;
  final int openCount;
  final int openTotalMinor;
  final int cancelledCount;
  final int refundedOrderCount;
  final int cashCount;
  final int cashGrossTotalMinor;
  final int cashTotalMinor;
  final int cardCount;
  final int cardGrossTotalMinor;
  final int cardTotalMinor;
  final List<ShiftReportCategoryLine> categoryBreakdown;
  final SemanticSalesAnalytics semanticSalesAnalytics;

  ShiftReport copyWith({
    int? shiftId,
    int? paidCount,
    int? paidTotalMinor,
    int? refundCount,
    int? refundTotalMinor,
    int? netSalesMinor,
    int? openCount,
    int? openTotalMinor,
    int? cancelledCount,
    int? refundedOrderCount,
    int? cashCount,
    int? cashGrossTotalMinor,
    int? cashTotalMinor,
    int? cardCount,
    int? cardGrossTotalMinor,
    int? cardTotalMinor,
    List<ShiftReportCategoryLine>? categoryBreakdown,
    SemanticSalesAnalytics? semanticSalesAnalytics,
  }) {
    return ShiftReport(
      shiftId: shiftId ?? this.shiftId,
      paidCount: paidCount ?? this.paidCount,
      paidTotalMinor: paidTotalMinor ?? this.paidTotalMinor,
      refundCount: refundCount ?? this.refundCount,
      refundTotalMinor: refundTotalMinor ?? this.refundTotalMinor,
      netSalesMinor: netSalesMinor ?? this.netSalesMinor,
      openCount: openCount ?? this.openCount,
      openTotalMinor: openTotalMinor ?? this.openTotalMinor,
      cancelledCount: cancelledCount ?? this.cancelledCount,
      refundedOrderCount: refundedOrderCount ?? this.refundedOrderCount,
      cashCount: cashCount ?? this.cashCount,
      cashGrossTotalMinor: cashGrossTotalMinor ?? this.cashGrossTotalMinor,
      cashTotalMinor: cashTotalMinor ?? this.cashTotalMinor,
      cardCount: cardCount ?? this.cardCount,
      cardGrossTotalMinor: cardGrossTotalMinor ?? this.cardGrossTotalMinor,
      cardTotalMinor: cardTotalMinor ?? this.cardTotalMinor,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
      semanticSalesAnalytics:
          semanticSalesAnalytics ?? this.semanticSalesAnalytics,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShiftReport &&
        other.shiftId == shiftId &&
        other.paidCount == paidCount &&
        other.paidTotalMinor == paidTotalMinor &&
        other.refundCount == refundCount &&
        other.refundTotalMinor == refundTotalMinor &&
        other.netSalesMinor == netSalesMinor &&
        other.openCount == openCount &&
        other.openTotalMinor == openTotalMinor &&
        other.cancelledCount == cancelledCount &&
        other.refundedOrderCount == refundedOrderCount &&
        other.cashCount == cashCount &&
        other.cashGrossTotalMinor == cashGrossTotalMinor &&
        other.cashTotalMinor == cashTotalMinor &&
        other.cardCount == cardCount &&
        other.cardGrossTotalMinor == cardGrossTotalMinor &&
        other.cardTotalMinor == cardTotalMinor &&
        _listEquals(other.categoryBreakdown, categoryBreakdown) &&
        other.semanticSalesAnalytics == semanticSalesAnalytics;
  }

  @override
  int get hashCode => Object.hash(
    shiftId,
    paidCount,
    paidTotalMinor,
    refundCount,
    refundTotalMinor,
    netSalesMinor,
    openCount,
    openTotalMinor,
    cancelledCount,
    refundedOrderCount,
    cashCount,
    cashGrossTotalMinor,
    cashTotalMinor,
    cardCount,
    cardGrossTotalMinor,
    cardTotalMinor,
    Object.hashAll(categoryBreakdown),
    semanticSalesAnalytics,
  );

  bool _listEquals(
    List<ShiftReportCategoryLine> a,
    List<ShiftReportCategoryLine> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}
