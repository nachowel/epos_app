import 'dart:ui';

import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/errors/error_mapper.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/domain/models/shift_close_readiness.dart';
import 'package:epos_app/domain/models/stale_final_close_recovery_details.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppLocalizationService.instance.setLocale(const Locale('en'));
  });

  group('ErrorMapper', () {
    test('maps refund blocked reason to operational refund message', () {
      final String message = ErrorMapper.toUserMessage(
        PaymentRefundBlockedException(
          reason: RefundBlockReason.notPaid,
          transactionId: 7,
        ),
      );

      expect(message, AppStrings.refundBlockedNotPaid);
    });

    test('maps missing payment refund reason to payment-not-found message', () {
      final String message = ErrorMapper.toUserMessage(
        PaymentRefundBlockedException(
          reason: RefundBlockReason.missingPayment,
          transactionId: 7,
        ),
      );

      expect(message, AppStrings.refundBlockedPaymentMissing);
    });

    test('maps final close blocked reason to precise operator message', () {
      final String message = ErrorMapper.toUserMessage(
        ShiftCloseBlockedException(
          const ShiftCloseReadiness(
            sentOrderCount: 2,
            freshDraftCount: 0,
            staleDraftCount: 0,
          ),
        ),
      );

      expect(message, AppStrings.shiftCloseBlockedSentOrders(2));
    });

    test('maps duplicate payment to payment already completed message', () {
      final String message = ErrorMapper.toUserMessage(
        DuplicatePaymentException(),
      );

      expect(message, AppStrings.paymentAlreadyCompleted);
    });

    test('maps invalid state transition to its typed exception message', () {
      final String message = ErrorMapper.toUserMessage(
        InvalidStateTransitionException('Shift is not open: 7'),
      );

      expect(message, 'Shift is not open: 7');
    });

    test('maps stale final close reconciliation to recovery message', () {
      final String message = ErrorMapper.toUserMessage(
        StaleFinalCloseReconciliationException(
          details: StaleFinalCloseRecoveryDetails(
            shiftId: 7,
            reconciliationId: 11,
            expectedCashMinor: 1000,
            countedCashMinor: 950,
            varianceMinor: -50,
            countedAt: DateTime(2026, 3, 28, 18),
            countedByUserId: 2,
          ),
        ),
      );

      expect(
        message,
        'A previous final close attempt already recorded counted cash for this shift, but the shift is still open. Refresh the shift and resolve the existing final close record before retrying.',
      );
    });

    test('maps printer failure to retry-required message', () {
      final String message = ErrorMapper.toUserMessage(
        PrinterException('Printer offline.'),
      );

      expect(message, AppStrings.printRetryRecommended);
    });

    test('maps localized messages after locale switch', () {
      AppLocalizationService.instance.setLocale(const Locale('tr'));

      final String message = ErrorMapper.toUserMessage(
        DuplicatePaymentException(),
      );

      expect(message, AppStrings.paymentAlreadyCompleted);
    });
  });
}
