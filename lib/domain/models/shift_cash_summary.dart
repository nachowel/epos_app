import 'shift_reconciliation.dart';

class ShiftCashSummary {
  const ShiftCashSummary({
    required this.shiftId,
    required this.expectedCashMinor,
    required this.latestFinalCloseReconciliation,
  });

  final int shiftId;
  final int expectedCashMinor;
  final ShiftReconciliation? latestFinalCloseReconciliation;

  int? get countedCashMinor => latestFinalCloseReconciliation?.countedCashMinor;

  int? get varianceMinor => latestFinalCloseReconciliation?.varianceMinor;

  bool? get wasCountedCashEntered =>
      latestFinalCloseReconciliation?.wasOperatorEntered;

  ShiftCashSummary copyWith({
    int? shiftId,
    int? expectedCashMinor,
    Object? latestFinalCloseReconciliation = _unsetCashSummary,
  }) {
    return ShiftCashSummary(
      shiftId: shiftId ?? this.shiftId,
      expectedCashMinor: expectedCashMinor ?? this.expectedCashMinor,
      latestFinalCloseReconciliation:
          latestFinalCloseReconciliation == _unsetCashSummary
          ? this.latestFinalCloseReconciliation
          : latestFinalCloseReconciliation as ShiftReconciliation?,
    );
  }
}

const Object _unsetCashSummary = Object();
