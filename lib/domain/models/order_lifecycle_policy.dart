import '../../core/errors/exceptions.dart';
import 'transaction.dart';

enum OrderLifecycleAction { send, pay, cancel, discardDraft }

class OrderLifecyclePolicy {
  const OrderLifecyclePolicy._();

  static bool canTransition({
    required TransactionStatus from,
    required TransactionStatus to,
  }) {
    switch (from) {
      case TransactionStatus.draft:
        return to == TransactionStatus.sent;
      case TransactionStatus.sent:
        return to == TransactionStatus.paid ||
            to == TransactionStatus.cancelled;
      case TransactionStatus.paid:
      case TransactionStatus.cancelled:
        return false;
    }
  }

  static void ensureCanTransition({
    required TransactionStatus from,
    required TransactionStatus to,
  }) {
    if (!canTransition(from: from, to: to)) {
      throw InvalidStateTransitionException(
        'Transition not allowed: ${from.name} -> ${to.name}',
      );
    }
  }

  static Set<OrderLifecycleAction> allowedActions(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.draft:
        return <OrderLifecycleAction>{
          OrderLifecycleAction.send,
          OrderLifecycleAction.discardDraft,
        };
      case TransactionStatus.sent:
        return <OrderLifecycleAction>{
          OrderLifecycleAction.pay,
          OrderLifecycleAction.cancel,
        };
      case TransactionStatus.paid:
      case TransactionStatus.cancelled:
        return const <OrderLifecycleAction>{};
    }
  }

  static bool canMutateLineItems(TransactionStatus status) {
    return status == TransactionStatus.draft;
  }

  static bool canUpdateTableNumber(TransactionStatus status) {
    return status == TransactionStatus.draft ||
        status == TransactionStatus.sent;
  }

  static bool canDiscardDraft(TransactionStatus status) {
    return status == TransactionStatus.draft;
  }

  static bool canPrintKitchenTicket(TransactionStatus status) {
    return status == TransactionStatus.sent || status == TransactionStatus.paid;
  }

  static bool canPrintReceipt(TransactionStatus status) {
    return status == TransactionStatus.paid;
  }

  static bool isActive(TransactionStatus status) {
    return status == TransactionStatus.draft ||
        status == TransactionStatus.sent;
  }

  static bool isTerminal(TransactionStatus status) {
    return status == TransactionStatus.paid ||
        status == TransactionStatus.cancelled;
  }
}
