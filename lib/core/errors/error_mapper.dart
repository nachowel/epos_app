import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';
import '../constants/app_strings.dart';
import '../../domain/models/shift_close_readiness.dart';
import '../../domain/models/print_job.dart';
import 'exceptions.dart';

class ErrorMapper {
  const ErrorMapper._();

  static String toUserMessage(Object error) {
    if (error is ShiftNotActiveException) {
      return AppStrings.shiftNotActiveError;
    }
    if (error is ShiftClosedException) {
      return AppStrings.shiftClosedMessage;
    }
    if (error is ShiftMismatchException) {
      return AppStrings.paymentUnavailable;
    }
    if (error is OrderPaymentBlockedException) {
      switch (error.reason) {
        case PaymentBlockReason.alreadyPaid:
          return AppStrings.paymentAlreadyCompleted;
        case PaymentBlockReason.cancelled:
          return AppStrings.paymentCancelledOrderBlocked;
        case PaymentBlockReason.notSent:
          return AppStrings.paymentNotSentBlocked;
      }
    }
    if (error is CashierPreviewLockedException) {
      return AppStrings.salesLockedAdminCloseRequired;
    }
    if (error is CashierShiftClosedException) {
      return AppStrings.salesLockedAdminCloseRequired;
    }
    if (error is ShiftAlreadyOpenException) {
      return AppStrings.shiftOpened;
    }
    if (error is OpenOrdersExistException) {
      return '${AppStrings.openOrdersBlockTitle}: ${error.count}';
    }
    if (error is ShiftCloseBlockedException) {
      switch (error.readiness.blockingReason) {
        case ShiftCloseBlockReason.sentOrdersPending:
          return AppStrings.shiftCloseBlockedSentOrders(
            error.readiness.sentOrderCount,
          );
        case ShiftCloseBlockReason.freshDraftsPending:
          return AppStrings.shiftCloseBlockedFreshDrafts(
            error.readiness.freshDraftCount,
          );
        case ShiftCloseBlockReason.staleDraftsPendingCleanup:
          return AppStrings.shiftCloseBlockedStaleDrafts(
            error.readiness.staleDraftCount,
          );
        case null:
          return AppStrings.operationFailed;
      }
    }
    if (error is InvalidStateTransitionException) {
      return error.message;
    }
    if (error is StaleFinalCloseReconciliationException) {
      return error.message;
    }
    if (error is DuplicateShiftReconciliationException) {
      return error.message;
    }
    if (error is DuplicatePaymentException) {
      return AppStrings.paymentAlreadyCompleted;
    }
    if (error is DuplicatePaymentAdjustmentException) {
      return AppStrings.refundAlreadyProcessed;
    }
    if (error is PaymentRefundBlockedException) {
      switch (error.reason) {
        case RefundBlockReason.notPaid:
          return AppStrings.refundBlockedNotPaid;
        case RefundBlockReason.missingPayment:
          return AppStrings.refundBlockedPaymentMissing;
        case RefundBlockReason.cancelled:
          return AppStrings.refundBlockedCancelled;
        case RefundBlockReason.alreadyAdjusted:
          return AppStrings.refundAlreadyProcessed;
      }
    }
    if (error is PaymentAmountMismatchException) {
      return AppStrings.paymentFailedOrderOpen;
    }
    if (error is UnauthorisedException) {
      return AppStrings.accessDenied;
    }
    if (error is EmptyCartException) {
      return AppStrings.cartEmpty;
    }
    if (error is CheckoutFailedException) {
      return AppStrings.operationFailed;
    }
    if (error is PrintJobInProgressException) {
      return error.target == PrintJobTarget.kitchen
          ? AppStrings.kitchenPrintInProgress
          : AppStrings.receiptPrintInProgress;
    }
    if (error is PrinterException) {
      return error.operatorMessage ?? AppStrings.printRetryRecommended;
    }
    if (error is NotFoundException) {
      return AppStrings.notFound;
    }
    if (error is ValidationException) {
      if (error is BreakfastEditRejectedException) {
        return _breakfastEditRejectedMessage(error);
      }
      return error.message;
    }
    if (error is BreakfastLineNotEditableException) {
      switch (error.reason) {
        case BreakfastEditBlockedReason.notDraft:
          return 'Breakfast items can only be edited while the order is still a draft.';
        case BreakfastEditBlockedReason.sent:
          return 'Sent breakfast orders can no longer be edited.';
        case BreakfastEditBlockedReason.paid:
          return 'Paid breakfast orders can no longer be edited.';
        case BreakfastEditBlockedReason.cancelled:
          return 'Cancelled breakfast orders can no longer be edited.';
      }
    }
    if (error is AppException) {
      return error.message;
    }
    return AppStrings.errorGeneric;
  }

  static String toUserMessageAndLog(
    Object error, {
    required AppLogger logger,
    required String eventType,
    String? entityId,
    Map<String, Object?> metadata = const <String, Object?>{},
    StackTrace? stackTrace,
  }) {
    final String message = toUserMessage(error);
    if (kDebugMode) {
      debugPrint('[ErrorMapper][$eventType] ${error.runtimeType}: $error');
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final bool expected = error is AppException;
    if (expected) {
      logger.warn(
        eventType: eventType,
        message: error.toString(),
        entityId: entityId,
        metadata: metadata,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      logger.error(
        eventType: eventType,
        message: error.toString(),
        entityId: entityId,
        metadata: metadata,
        error: error,
        stackTrace: stackTrace,
      );
    }
    return message;
  }

  static String _breakfastEditRejectedMessage(
    BreakfastEditRejectedException error,
  ) {
    final Set<BreakfastEditErrorCode> codes = error.codes.toSet();
    if (codes.contains(BreakfastEditErrorCode.removeQuantityExceedsDefault)) {
      return 'Cannot remove more items than this breakfast includes.';
    }
    if (codes.contains(BreakfastEditErrorCode.choiceMemberNotAllowed) ||
        codes.contains(BreakfastEditErrorCode.invalidChoiceGroup) ||
        codes.contains(BreakfastEditErrorCode.invalidChoiceQuantity) ||
        codes.contains(BreakfastEditErrorCode.mixedToastBreadNotSupported)) {
      return 'That breakfast choice is not allowed.';
    }
    if (codes.contains(BreakfastEditErrorCode.unsupportedLineSplitState)) {
      return 'This breakfast line cannot be edited until it is split into single units.';
    }
    if (codes.contains(BreakfastEditErrorCode.rootNotSetProduct) ||
        codes.contains(BreakfastEditErrorCode.unknownProduct) ||
        codes.contains(BreakfastEditErrorCode.unknownRequestedEntity)) {
      return 'Breakfast configuration is unavailable for this item.';
    }
    if (codes.contains(BreakfastEditErrorCode.negativeQuantity)) {
      return 'Quantity must be zero or greater.';
    }
    return AppStrings.operationFailed;
  }
}
