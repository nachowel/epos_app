import '../../core/errors/exceptions.dart';
import 'transaction.dart';
import 'user.dart';

enum OperatorPermission {
  createDraftOrder,
  openShift,
  lockShiftForPreviewClose,
  finalCloseShift,
  refundPayment,
  performReconciliation,
  sendOrder,
  cancelOrder,
  discardDraft,
  takePayment,
  viewMaskedReports,
  viewFullReports,
  viewAuditLog,
}

class AuthorizationPolicy {
  const AuthorizationPolicy._();

  static bool canRolePerform(UserRole role, OperatorPermission permission) {
    switch (role) {
      case UserRole.admin:
        return permission != OperatorPermission.lockShiftForPreviewClose;
      case UserRole.cashier:
        switch (permission) {
          case OperatorPermission.createDraftOrder:
          case OperatorPermission.openShift:
          case OperatorPermission.lockShiftForPreviewClose:
          case OperatorPermission.sendOrder:
          case OperatorPermission.cancelOrder:
          case OperatorPermission.discardDraft:
          case OperatorPermission.takePayment:
          case OperatorPermission.viewMaskedReports:
            return true;
          case OperatorPermission.finalCloseShift:
          case OperatorPermission.refundPayment:
          case OperatorPermission.performReconciliation:
          case OperatorPermission.viewFullReports:
          case OperatorPermission.viewAuditLog:
            return false;
        }
    }
  }

  static bool canPerform(User? user, OperatorPermission permission) {
    if (user == null) {
      return false;
    }
    return canRolePerform(user.role, permission);
  }

  static void ensureAllowed(User user, OperatorPermission permission) {
    if (!canRolePerform(user.role, permission)) {
      throw UnauthorisedException(_defaultMessage(permission));
    }
  }

  static bool canCancelOrder({
    required User? user,
    required Transaction transaction,
  }) {
    if (user == null || !canPerform(user, OperatorPermission.cancelOrder)) {
      return false;
    }
    return user.role == UserRole.admin || transaction.userId == user.id;
  }

  static void ensureCanCancelOrder({
    required User user,
    required Transaction transaction,
  }) {
    ensureAllowed(user, OperatorPermission.cancelOrder);
    if (user.role == UserRole.cashier && transaction.userId != user.id) {
      throw UnauthorisedException(
        'Cashiers can cancel only their own sent orders.',
      );
    }
  }

  static bool canDiscardDraft({
    required User? user,
    required Transaction transaction,
  }) {
    if (user == null || !canPerform(user, OperatorPermission.discardDraft)) {
      return false;
    }
    return user.role == UserRole.admin || transaction.userId == user.id;
  }

  static void ensureCanDiscardDraft({
    required User user,
    required Transaction transaction,
  }) {
    ensureAllowed(user, OperatorPermission.discardDraft);
    if (user.role == UserRole.cashier && transaction.userId != user.id) {
      throw UnauthorisedException(
        'Cashiers can discard only their own draft orders.',
      );
    }
  }

  static String _defaultMessage(OperatorPermission permission) {
    switch (permission) {
      case OperatorPermission.openShift:
        return 'You are not allowed to open shifts.';
      case OperatorPermission.createDraftOrder:
        return 'You are not allowed to create draft orders.';
      case OperatorPermission.lockShiftForPreviewClose:
        return 'You are not allowed to start shift preview close.';
      case OperatorPermission.finalCloseShift:
        return 'Only admins can perform final close.';
      case OperatorPermission.refundPayment:
        return 'Only admins can refund or reverse payments.';
      case OperatorPermission.performReconciliation:
        return 'Only admins can perform cash reconciliation.';
      case OperatorPermission.sendOrder:
        return 'You are not allowed to send orders.';
      case OperatorPermission.cancelOrder:
        return 'You are not allowed to cancel orders.';
      case OperatorPermission.discardDraft:
        return 'You are not allowed to discard draft orders.';
      case OperatorPermission.takePayment:
        return 'You are not allowed to take payments.';
      case OperatorPermission.viewMaskedReports:
        return 'You are not allowed to view reports.';
      case OperatorPermission.viewFullReports:
        return 'Only admins can view full reports.';
      case OperatorPermission.viewAuditLog:
        return 'Only admins can view the audit log.';
    }
  }
}
