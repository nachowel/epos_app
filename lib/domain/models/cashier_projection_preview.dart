import 'cashier_projected_category_line.dart';

class CashierProjectionPreview {
  const CashierProjectionPreview({
    required this.hasSourceReport,
    required this.shiftId,
    required this.realTotalMinor,
    required this.cashierVisibleTotalMinor,
    required this.realCashMinor,
    required this.cashierVisibleCashMinor,
    required this.realCardMinor,
    required this.cashierVisibleCardMinor,
    required this.categoryBreakdown,
  });

  const CashierProjectionPreview.unavailable()
    : hasSourceReport = false,
      shiftId = null,
      realTotalMinor = 0,
      cashierVisibleTotalMinor = 0,
      realCashMinor = 0,
      cashierVisibleCashMinor = 0,
      realCardMinor = 0,
      cashierVisibleCardMinor = 0,
      categoryBreakdown = const <CashierProjectedCategoryLine>[];

  final bool hasSourceReport;
  final int? shiftId;
  final int realTotalMinor;
  final int cashierVisibleTotalMinor;
  final int realCashMinor;
  final int cashierVisibleCashMinor;
  final int realCardMinor;
  final int cashierVisibleCardMinor;
  final List<CashierProjectedCategoryLine> categoryBreakdown;
}
