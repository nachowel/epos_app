import '../../core/constants/app_strings.dart';
import 'authorization_policy.dart';
import 'interaction_block_reason.dart';
import 'shift.dart';
import 'transaction.dart';
import 'user.dart';

class OrderPaymentEligibility {
  const OrderPaymentEligibility({
    required this.isAllowed,
    required this.blockedMessage,
  });

  final bool isAllowed;
  final String? blockedMessage;
}

class OrderPaymentPolicy {
  const OrderPaymentPolicy._();

  static OrderPaymentEligibility resolve({
    required User? user,
    required Transaction transaction,
    required Shift? activeShift,
    required bool paymentsLocked,
    required InteractionBlockReason? lockReason,
  }) {
    if (!AuthorizationPolicy.canPerform(user, OperatorPermission.takePayment)) {
      return OrderPaymentEligibility(
        isAllowed: false,
        blockedMessage: AppStrings.accessDenied,
      );
    }

    if (transaction.status != TransactionStatus.sent) {
      return OrderPaymentEligibility(
        isAllowed: false,
        blockedMessage: AppStrings.paymentUnavailable,
      );
    }

    if (activeShift == null) {
      return OrderPaymentEligibility(
        isAllowed: false,
        blockedMessage:
            lockReason?.operatorMessage ??
            AppStrings.shiftClosedOpenShiftRequired,
      );
    }

    if (activeShift.id != transaction.shiftId) {
      return OrderPaymentEligibility(
        isAllowed: false,
        blockedMessage: AppStrings.paymentUnavailable,
      );
    }

    if (paymentsLocked) {
      return OrderPaymentEligibility(
        isAllowed: false,
        blockedMessage:
            lockReason?.operatorMessage ??
            AppStrings.salesLockedAdminCloseRequired,
      );
    }

    return const OrderPaymentEligibility(isAllowed: true, blockedMessage: null);
  }
}
