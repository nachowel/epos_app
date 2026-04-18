import '../models/exit_safety.dart';
import '../models/shift.dart';
import '../models/shift_session_snapshot.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import 'order_service.dart';
import 'shift_session_service.dart';

/// Freshly evaluates exit/logout safety against authoritative sources
/// (shift repository + order repository) — never trusts cached UI state.
///
/// Contract:
///   * Any OPEN (draft) or SENT transaction → [ExitSafetyLevel.blocked].
///     These represent operator-in-progress work. Hard block, no confirm.
///   * No open/sent orders, but order-state verification failed →
///     [ExitSafetyLevel.blocked] as well. We prefer a false-positive block
///     over a false-negative unsafe logout.
///   * No blocking reasons, but active shift exists → [ExitSafetyLevel.warnOnly].
///   * Nothing active → [ExitSafetyLevel.noRisk].
abstract class ExitSafetyService {
  const ExitSafetyService();

  Future<ExitSafetyEvaluation> evaluate({User? currentUser});
}

class DefaultExitSafetyService extends ExitSafetyService {
  const DefaultExitSafetyService({
    required ShiftSessionService shiftSessionService,
    required OrderService orderService,
  })  : _shiftSessionService = shiftSessionService,
        _orderService = orderService;

  final ShiftSessionService _shiftSessionService;
  final OrderService _orderService;

  @override
  Future<ExitSafetyEvaluation> evaluate({User? currentUser}) async {
    bool shiftActive = false;
    try {
      final ShiftSessionSnapshot snapshot =
          await _shiftSessionService.getSnapshotForUser(currentUser);
      final Shift? openShift = snapshot.backendOpenShift;
      shiftActive = openShift != null && openShift.status == ShiftStatus.open;
    } catch (_) {
      // Shift verification failure is itself treated as verification failure
      // below — we roll it into the same signal instead of silently passing.
      return ExitSafetyEvaluation(
        level: ExitSafetyLevel.blocked,
        reasons: <ExitSafetyReason>{ExitSafetyReason.verificationFailed},
        openOrderCount: 0,
        sentOrderCount: 0,
      );
    }

    int openCount = 0;
    int sentCount = 0;
    bool orderVerificationFailed = false;
    try {
      // No shiftId filter → also catches orphan draft/sent orders that may
      // exist outside the current open shift.
      final List<Transaction> active = await _orderService.getActiveOrders();
      for (final Transaction tx in active) {
        switch (tx.status) {
          case TransactionStatus.draft:
            openCount++;
            break;
          case TransactionStatus.sent:
            sentCount++;
            break;
          case TransactionStatus.paid:
          case TransactionStatus.cancelled:
            break;
        }
      }
    } catch (_) {
      orderVerificationFailed = true;
    }

    final Set<ExitSafetyReason> reasons = <ExitSafetyReason>{};
    if (shiftActive) reasons.add(ExitSafetyReason.activeShift);
    if (openCount > 0) reasons.add(ExitSafetyReason.openOrders);
    if (sentCount > 0) reasons.add(ExitSafetyReason.sentOrders);
    if (orderVerificationFailed) {
      reasons.add(ExitSafetyReason.verificationFailed);
    }

    final ExitSafetyLevel level;
    if (openCount > 0 || sentCount > 0 || orderVerificationFailed) {
      level = ExitSafetyLevel.blocked;
    } else if (shiftActive) {
      level = ExitSafetyLevel.warnOnly;
    } else {
      level = ExitSafetyLevel.noRisk;
    }

    return ExitSafetyEvaluation(
      level: level,
      reasons: reasons,
      openOrderCount: openCount,
      sentOrderCount: sentCount,
    );
  }
}
