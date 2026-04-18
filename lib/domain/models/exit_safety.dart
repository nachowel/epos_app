import 'transaction.dart';

/// Outcome of evaluating whether it is safe to log out / exit the app.
///
/// Authority order:
///   blocked      → any OPEN or SENT orders exist. Exit is not permitted.
///   warnOnly     → no open/sent orders, but some soft risk (active shift, or
///                  verification failure). User must confirm deliberately.
///   noRisk       → nothing active. Simple confirmation is sufficient.
enum ExitSafetyLevel { noRisk, warnOnly, blocked }

/// Specific reasons that contribute to the evaluation. A single evaluation may
/// produce multiple reasons (e.g. active shift + verification failure).
enum ExitSafetyReason {
  activeShift,
  openOrders,
  sentOrders,
  verificationFailed,
}

class ExitSafetyEvaluation {
  const ExitSafetyEvaluation({
    required this.level,
    required this.reasons,
    required this.openOrderCount,
    required this.sentOrderCount,
  });

  final ExitSafetyLevel level;
  final Set<ExitSafetyReason> reasons;
  final int openOrderCount;
  final int sentOrderCount;

  bool get hasReason => reasons.isNotEmpty;
  bool get hasActiveShift => reasons.contains(ExitSafetyReason.activeShift);
  bool get hasOpenOrders => reasons.contains(ExitSafetyReason.openOrders);
  bool get hasSentOrders => reasons.contains(ExitSafetyReason.sentOrders);
  bool get verificationFailed =>
      reasons.contains(ExitSafetyReason.verificationFailed);

  /// Count the operationally-risky orders (OPEN + SENT) — the statuses that
  /// represent interrupted workflow if the operator walks away.
  static int countActiveOrders(Iterable<Transaction> orders) {
    int n = 0;
    for (final Transaction order in orders) {
      if (order.status == TransactionStatus.draft ||
          order.status == TransactionStatus.sent) {
        n++;
      }
    }
    return n;
  }
}
