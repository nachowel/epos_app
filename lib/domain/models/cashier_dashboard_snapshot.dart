import 'open_order_summary.dart';
import 'payment.dart';
import 'shift_session_snapshot.dart';
import 'user.dart';
import 'cash_movement.dart';

enum CashierDashboardActivityType {
  payment,
  cancellation,
  receiptReprint,
  cashierPreview,
  cashMovement,
}

enum OpenOrderLoadLevel { calm, normal, high }

enum DashboardWarningType { noShift, previewTaken, highLoad }

enum ShiftOperationalState { noShift, normal, previewTakenLocked }

class DashboardWarning {
  const DashboardWarning({required this.type, required this.message});

  final DashboardWarningType type;
  final String message;
}

class CashierDashboardActivityItem {
  const CashierDashboardActivityItem({
    required this.type,
    required this.occurredAt,
    this.transactionId,
    this.entityId,
    this.paymentMethod,
    this.cashMovementType,
    this.cashMovementCategory,
  });

  final CashierDashboardActivityType type;
  final DateTime occurredAt;
  final int? transactionId;
  final String? entityId;
  final PaymentMethod? paymentMethod;
  final CashMovementType? cashMovementType;
  final String? cashMovementCategory;
}

class CashierDashboardSnapshot {
  const CashierDashboardSnapshot({
    required this.shiftSession,
    required this.openedByUser,
    required this.cashierPreviewedByUser,
    required this.openOrderCount,
    required this.openOrders,
    required this.openOrderLoadLevel,
    required this.activity,
    required this.warnings,
    required this.operationalState,
  });

  final ShiftSessionSnapshot shiftSession;
  final User? openedByUser;
  final User? cashierPreviewedByUser;
  final int openOrderCount;
  final List<OpenOrderSummary> openOrders;
  final OpenOrderLoadLevel openOrderLoadLevel;
  final List<CashierDashboardActivityItem> activity;
  final List<DashboardWarning> warnings;
  final ShiftOperationalState operationalState;

  static OpenOrderLoadLevel computeLoadLevel(int count) {
    if (count == 0) return OpenOrderLoadLevel.calm;
    if (count <= 5) return OpenOrderLoadLevel.normal;
    return OpenOrderLoadLevel.high;
  }
}
