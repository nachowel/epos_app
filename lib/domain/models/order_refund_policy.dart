import '../../core/constants/app_strings.dart';
import 'authorization_policy.dart';
import 'payment.dart';
import 'payment_adjustment.dart';
import 'transaction.dart';
import 'user.dart';

class OrderRefundEligibility {
  const OrderRefundEligibility({
    required this.isAllowed,
    required this.blockedMessage,
  });

  final bool isAllowed;
  final String? blockedMessage;
}

class OrderRefundPolicy {
  const OrderRefundPolicy._();

  static OrderRefundEligibility resolve({
    required User? user,
    required Transaction transaction,
    required Payment? payment,
    required PaymentAdjustment? adjustment,
  }) {
    if (user == null ||
        !AuthorizationPolicy.canPerform(user, OperatorPermission.refundPayment)) {
      return OrderRefundEligibility(
        isAllowed: false,
        blockedMessage: AppStrings.refundAdminOnly,
      );
    }
    if (adjustment != null) {
      return OrderRefundEligibility(
        isAllowed: false,
        blockedMessage: AppStrings.refundAlreadyProcessed,
      );
    }
    if (transaction.status == TransactionStatus.cancelled) {
      return OrderRefundEligibility(
        isAllowed: false,
        blockedMessage: AppStrings.refundBlockedCancelled,
      );
    }
    if (transaction.status != TransactionStatus.paid || payment == null) {
      return OrderRefundEligibility(
        isAllowed: false,
        blockedMessage: AppStrings.refundBlockedNotPaid,
      );
    }
    return const OrderRefundEligibility(isAllowed: true, blockedMessage: null);
  }
}
