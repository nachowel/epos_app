import 'dart:ui';

import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/domain/models/interaction_block_reason.dart';
import 'package:epos_app/domain/models/order_payment_policy.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppLocalizationService.instance.setLocale(const Locale('en'));
  });

  group('OrderPaymentPolicy', () {
    test(
      'allows payment for current-shift sent unpaid order on open shift',
      () {
        final OrderPaymentEligibility eligibility = OrderPaymentPolicy.resolve(
          user: _cashier(),
          transaction: _transaction(shiftId: 2, status: TransactionStatus.sent),
          activeShift: _shift(id: 2),
          paymentsLocked: false,
          lockReason: null,
        );

        expect(eligibility.isAllowed, isTrue);
        expect(eligibility.blockedMessage, isNull);
      },
    );

    test('blocks payment when current shift is locked', () {
      final OrderPaymentEligibility eligibility = OrderPaymentPolicy.resolve(
        user: _cashier(),
        transaction: _transaction(status: TransactionStatus.sent),
        activeShift: _shift(),
        paymentsLocked: true,
        lockReason: InteractionBlockReason.adminFinalCloseRequired,
      );

      expect(eligibility.isAllowed, isFalse);
      expect(
        eligibility.blockedMessage,
        AppStrings.salesLockedAdminCloseRequired,
      );
    });

    test('blocks payment for paid order', () {
      final OrderPaymentEligibility eligibility = OrderPaymentPolicy.resolve(
        user: _cashier(),
        transaction: _transaction(status: TransactionStatus.paid),
        activeShift: _shift(),
        paymentsLocked: false,
        lockReason: null,
      );

      expect(eligibility.isAllowed, isFalse);
      expect(eligibility.blockedMessage, AppStrings.paymentUnavailable);
    });

    test('blocks payment for cancelled order', () {
      final OrderPaymentEligibility eligibility = OrderPaymentPolicy.resolve(
        user: _cashier(),
        transaction: _transaction(status: TransactionStatus.cancelled),
        activeShift: _shift(),
        paymentsLocked: false,
        lockReason: null,
      );

      expect(eligibility.isAllowed, isFalse);
      expect(eligibility.blockedMessage, AppStrings.paymentUnavailable);
    });

    test('stale lock reason alone does not block current-shift payment', () {
      final OrderPaymentEligibility eligibility = OrderPaymentPolicy.resolve(
        user: _cashier(),
        transaction: _transaction(shiftId: 7, status: TransactionStatus.sent),
        activeShift: _shift(id: 7),
        paymentsLocked: false,
        lockReason: InteractionBlockReason.adminFinalCloseRequired,
      );

      expect(eligibility.isAllowed, isTrue);
      expect(eligibility.blockedMessage, isNull);
    });
  });
}

User _cashier() {
  return User(
    id: 10,
    name: 'Cashier',
    pin: null,
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime(2026, 3, 27),
  );
}

Shift _shift({int id = 1}) {
  return Shift(
    id: id,
    openedBy: 10,
    openedAt: DateTime(2026, 3, 27),
    closedBy: null,
    closedAt: null,
    cashierPreviewedBy: null,
    cashierPreviewedAt: null,
    status: ShiftStatus.open,
  );
}

Transaction _transaction({
  int shiftId = 1,
  TransactionStatus status = TransactionStatus.sent,
}) {
  return Transaction(
    id: 99,
    uuid: 'order-payment-policy',
    shiftId: shiftId,
    userId: 10,
    tableNumber: 4,
    status: status,
    subtotalMinor: 1200,
    modifierTotalMinor: 0,
    totalAmountMinor: 1200,
    createdAt: DateTime(2026, 3, 27),
    paidAt: status == TransactionStatus.paid ? DateTime(2026, 3, 27) : null,
    updatedAt: DateTime(2026, 3, 27),
    cancelledAt: status == TransactionStatus.cancelled
        ? DateTime(2026, 3, 27)
        : null,
    cancelledBy: status == TransactionStatus.cancelled ? 10 : null,
    idempotencyKey: 'order-payment-policy-key',
    kitchenPrinted: false,
    receiptPrinted: false,
  );
}
