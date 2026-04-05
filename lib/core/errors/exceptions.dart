import '../../domain/models/shift_close_readiness.dart';
import '../../domain/models/print_job.dart';
import '../../domain/models/stale_final_close_recovery_details.dart';

abstract class AppException implements Exception {
  AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum PaymentBlockReason { alreadyPaid, cancelled, notSent }

enum RefundBlockReason { notPaid, cancelled, alreadyAdjusted, missingPayment }

class DatabaseException extends AppException {
  DatabaseException(super.message);
}

class ValidationException extends AppException {
  ValidationException(super.message);
}

enum BreakfastEditBlockedReason { notDraft, sent, paid, cancelled }
enum MealCustomizationEditBlockedReason {
  notDraft,
  sent,
  paid,
  cancelled,
  legacySnapshotMissing,
}

enum BreakfastEditErrorCode {
  rootNotSetProduct,
  invalidPricingMode,
  invalidChoiceGroup,
  choiceMemberNotAllowed,
  mixedToastBreadNotSupported,
  removeQuantityExceedsDefault,
  swapCandidateNotSwapEligible,
  negativeQuantity,
  invalidChoiceQuantity,
  unknownProduct,
  unknownRequestedEntity,
  unsupportedLineSplitState,
}

enum BreakfastConfigurationErrorCode {
  invalidSetRoot,
  invalidChoiceGroup,
  missingItemProductId,
  invalidChoiceBounds,
  invalidIncludedQuantity,
  wrongProductRoleAssignment,
  choiceCapableProductInSetItems,
}

class BreakfastConfigurationIssue {
  const BreakfastConfigurationIssue({
    required this.code,
    this.groupId,
    this.itemProductId,
    this.productModifierId,
  });

  final BreakfastConfigurationErrorCode code;
  final int? groupId;
  final int? itemProductId;
  final int? productModifierId;

  String get dedupeKey =>
      '${code.name}|g:${groupId ?? ''}|i:${itemProductId ?? ''}|m:${productModifierId ?? ''}';
}

class BreakfastConfigurationInvalidException extends ValidationException {
  BreakfastConfigurationInvalidException({
    required this.rootProductId,
    required List<BreakfastConfigurationIssue> issues,
  }) : issues = List<BreakfastConfigurationIssue>.unmodifiable(
         _dedupeIssues(issues),
       ),
       super(
         'Breakfast configuration invalid for product $rootProductId: ${_dedupeIssues(issues).map((BreakfastConfigurationIssue issue) => issue.code.name).join(', ')}',
       );

  final int rootProductId;
  final List<BreakfastConfigurationIssue> issues;

  List<BreakfastConfigurationErrorCode> get codes => issues
      .map((BreakfastConfigurationIssue issue) => issue.code)
      .toSet()
      .toList(growable: false);

  static List<BreakfastConfigurationIssue> _dedupeIssues(
    List<BreakfastConfigurationIssue> issues,
  ) {
    final Map<String, BreakfastConfigurationIssue> deduped =
        <String, BreakfastConfigurationIssue>{};
    for (final BreakfastConfigurationIssue issue in issues) {
      deduped[issue.dedupeKey] = issue;
    }
    return deduped.values.toList(growable: false);
  }
}

class BreakfastEditRejectedException extends ValidationException {
  BreakfastEditRejectedException({required this.codes, this.transactionLineId})
    : super(
        'Breakfast edit rejected: ${codes.map((BreakfastEditErrorCode code) => code.name).join(', ')}',
      );

  final List<BreakfastEditErrorCode> codes;
  final int? transactionLineId;
}

class MealCustomizationRuntimeConfigurationException
    extends ValidationException {
  MealCustomizationRuntimeConfigurationException({
    required this.productId,
    required this.profileId,
    required String detail,
  }) : super(
         'Meal customization configuration invalid for product $productId and profile $profileId: $detail',
       );

  final int productId;
  final int profileId;
}

class BreakfastLineNotEditableException
    extends InvalidStateTransitionException {
  BreakfastLineNotEditableException({
    required this.reason,
    required this.transactionLineId,
    required this.transactionId,
  }) : super(_buildMessage(reason, transactionLineId, transactionId));

  final BreakfastEditBlockedReason reason;
  final int transactionLineId;
  final int transactionId;

  static String _buildMessage(
    BreakfastEditBlockedReason reason,
    int transactionLineId,
    int transactionId,
  ) {
    switch (reason) {
      case BreakfastEditBlockedReason.notDraft:
        return 'Breakfast line $transactionLineId in transaction $transactionId is not editable.';
      case BreakfastEditBlockedReason.sent:
        return 'Breakfast line $transactionLineId in transaction $transactionId belongs to a sent order and is not editable.';
      case BreakfastEditBlockedReason.paid:
        return 'Breakfast line $transactionLineId in transaction $transactionId belongs to a paid order and is not editable.';
      case BreakfastEditBlockedReason.cancelled:
        return 'Breakfast line $transactionLineId in transaction $transactionId belongs to a cancelled order and is not editable.';
    }
  }
}

class StaleBreakfastEditException extends AppException {
  StaleBreakfastEditException({
    required this.transactionLineId,
    required this.transactionId,
    required this.expectedUpdatedAt,
    required this.actualUpdatedAt,
  }) : super(
         'Breakfast line $transactionLineId in transaction $transactionId is stale. expected_updated_at=${expectedUpdatedAt.toIso8601String()} actual_updated_at=${actualUpdatedAt.toIso8601String()}',
       );

  final int transactionLineId;
  final int transactionId;
  final DateTime expectedUpdatedAt;
  final DateTime actualUpdatedAt;
}

class MealCustomizationLineNotEditableException
    extends InvalidStateTransitionException {
  MealCustomizationLineNotEditableException({
    required this.reason,
    required this.transactionLineId,
    required this.transactionId,
  }) : super(_buildMessage(reason, transactionLineId, transactionId));

  final MealCustomizationEditBlockedReason reason;
  final int transactionLineId;
  final int transactionId;

  static String _buildMessage(
    MealCustomizationEditBlockedReason reason,
    int transactionLineId,
    int transactionId,
  ) {
    switch (reason) {
      case MealCustomizationEditBlockedReason.notDraft:
        return 'Meal customization line $transactionLineId in transaction $transactionId is not editable.';
      case MealCustomizationEditBlockedReason.sent:
        return 'Meal customization line $transactionLineId in transaction $transactionId belongs to a sent order and is not editable.';
      case MealCustomizationEditBlockedReason.paid:
        return 'Meal customization line $transactionLineId in transaction $transactionId belongs to a paid order and is not editable.';
      case MealCustomizationEditBlockedReason.cancelled:
        return 'Meal customization line $transactionLineId in transaction $transactionId belongs to a cancelled order and is not editable.';
      case MealCustomizationEditBlockedReason.legacySnapshotMissing:
        return 'Meal customization line $transactionLineId in transaction $transactionId was created before snapshot persistence and cannot be edited.';
    }
  }
}

class StaleMealCustomizationEditException extends AppException {
  StaleMealCustomizationEditException({
    required this.transactionLineId,
    required this.transactionId,
    required this.expectedUpdatedAt,
    required this.actualUpdatedAt,
  }) : super(
         'Meal customization line $transactionLineId in transaction $transactionId is stale. expected_updated_at=${expectedUpdatedAt.toIso8601String()} actual_updated_at=${actualUpdatedAt.toIso8601String()}',
       );

  final int transactionLineId;
  final int transactionId;
  final DateTime expectedUpdatedAt;
  final DateTime actualUpdatedAt;
}

class NotFoundException extends AppException {
  NotFoundException(super.message);
}

class MealAdjustmentProfileInUseException extends AppException {
  MealAdjustmentProfileInUseException({
    required this.profileId,
    required this.productCount,
  }) : super(
         'Meal adjustment profile $profileId is still assigned to $productCount product(s). Unassign all products first.',
       );

  final int profileId;
  final int productCount;
}

class ShiftAlreadyOpenException extends AppException {
  ShiftAlreadyOpenException()
    : super('A shift is already open. Close it before opening a new one.');
}

class ShiftNotActiveException extends AppException {
  ShiftNotActiveException()
    : super('No active shift. The next successful login starts a new shift.');
}

class ShiftClosedException extends AppException {
  ShiftClosedException() : super('Shift is already closed.');
}

class ShiftMismatchException extends AppException {
  ShiftMismatchException({
    required this.transactionShiftId,
    required this.activeShiftId,
  }) : super(
         'Transaction belongs to shift $transactionShiftId but active shift is $activeShiftId.',
       );

  final int transactionShiftId;
  final int activeShiftId;
}

class CashierPreviewLockedException extends AppException {
  CashierPreviewLockedException()
    : super(
        'Cashier masked end-of-day preview is already taken. Sales and payments are locked for all cashiers. Admin final close is required.',
      );
}

class CashierShiftClosedException extends AppException {
  CashierShiftClosedException()
    : super(
        'Cashier masked end-of-day preview is already taken. Admin final close is required.',
      );
}

class OpenOrdersExistException extends AppException {
  OpenOrdersExistException(this.count)
    : super(
        '$count open order(s) exist. Close or cancel them before shift close.',
      );

  final int count;
}

class ShiftCloseBlockedException extends AppException {
  ShiftCloseBlockedException(this.readiness) : super(_buildMessage(readiness));

  final ShiftCloseReadiness readiness;

  ShiftCloseBlockReason? get blockReason => readiness.blockingReason;

  ShiftCloseSuggestedAction? get suggestedAction => readiness.suggestedAction;

  static String _buildMessage(ShiftCloseReadiness readiness) {
    switch (readiness.blockingReason) {
      case ShiftCloseBlockReason.sentOrdersPending:
        return '${readiness.sentOrderCount} sent order(s) still need payment or cancellation before final close.';
      case ShiftCloseBlockReason.freshDraftsPending:
        return '${readiness.freshDraftCount} fresh draft(s) still need to be sent or discarded before final close.';
      case ShiftCloseBlockReason.staleDraftsPendingCleanup:
        return '${readiness.staleDraftCount} stale draft(s) must be discarded before final close.';
      case null:
        return 'Shift close is blocked.';
    }
  }
}

class InvalidStateTransitionException extends AppException {
  InvalidStateTransitionException(super.message);
}

class UnauthorisedException extends AppException {
  UnauthorisedException(super.message);
}

class DuplicatePaymentException extends AppException {
  DuplicatePaymentException()
    : super('A payment already exists for this transaction.');
}

class DuplicatePaymentAdjustmentException extends AppException {
  DuplicatePaymentAdjustmentException()
    : super('A refund or reversal already exists for this payment.');
}

class DuplicateShiftReconciliationException extends AppException {
  DuplicateShiftReconciliationException()
    : super(
        'A final close reconciliation already exists for this shift. Refresh the shift before retrying final close.',
      );
}

class StaleFinalCloseReconciliationException extends AppException {
  StaleFinalCloseReconciliationException({required this.details})
    : super(
        'A previous final close attempt already recorded counted cash for this shift, but the shift is still open. Refresh the shift and resolve the existing final close record before retrying.',
      );

  final StaleFinalCloseRecoveryDetails details;

  int get shiftId => details.shiftId;
}

class StaleFinalCloseRecoveryUnavailableException extends AppException {
  StaleFinalCloseRecoveryUnavailableException()
    : super(
        'The previous final close attempt is no longer available to recover. Refresh the shift and start final close again.',
      );
}

class PaymentRefundBlockedException extends AppException {
  PaymentRefundBlockedException({
    required this.reason,
    required this.transactionId,
  }) : super(_buildMessage(reason, transactionId));

  final RefundBlockReason reason;
  final int transactionId;

  static String _buildMessage(RefundBlockReason reason, int transactionId) {
    switch (reason) {
      case RefundBlockReason.notPaid:
        return 'Transaction $transactionId is not paid and cannot be refunded.';
      case RefundBlockReason.cancelled:
        return 'Transaction $transactionId is cancelled and cannot be refunded.';
      case RefundBlockReason.alreadyAdjusted:
        return 'Transaction $transactionId already has a refund or reversal.';
      case RefundBlockReason.missingPayment:
        return 'Transaction $transactionId has no payment record to refund.';
    }
  }
}

class OrderPaymentBlockedException extends AppException {
  OrderPaymentBlockedException({
    required this.reason,
    required this.transactionId,
  }) : super(_buildMessage(reason, transactionId));

  final PaymentBlockReason reason;
  final int transactionId;

  static String _buildMessage(PaymentBlockReason reason, int transactionId) {
    switch (reason) {
      case PaymentBlockReason.alreadyPaid:
        return 'Transaction $transactionId is already paid.';
      case PaymentBlockReason.cancelled:
        return 'Transaction $transactionId is cancelled and cannot be paid.';
      case PaymentBlockReason.notSent:
        return 'Transaction $transactionId is not in sent state.';
    }
  }
}

class PaymentAmountMismatchException extends AppException {
  PaymentAmountMismatchException({
    required this.expectedMinor,
    required this.actualMinor,
  }) : super(
         'Payment amount mismatch. expected=$expectedMinor actual=$actualMinor',
       );

  final int expectedMinor;
  final int actualMinor;
}

class EmptyCartException extends AppException {
  EmptyCartException() : super('Cart is empty.');
}

class CheckoutFailedException extends AppException {
  CheckoutFailedException(super.message);
}

class PrintJobInProgressException extends AppException {
  PrintJobInProgressException({required this.target})
    : super('A ${target.name} print attempt is already in progress.');

  final PrintJobTarget target;
}

class PrinterException extends AppException {
  PrinterException(super.message, {this.operatorMessage});

  final String? operatorMessage;
}
