import 'package:flutter/foundation.dart';

import '../../core/errors/exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/repositories/transaction_repository.dart';
import '../models/checkout_item.dart';
import '../models/payment.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import 'order_service.dart';
import 'printer_service.dart';
import 'shift_session_service.dart';

class CheckoutService {
  CheckoutService({
    db.AppDatabase? database,
    required ShiftSessionService shiftSessionService,
    required OrderService orderService,
    TransactionRepository? transactionRepository,
    required PrinterService printerService,
    AppLogger logger = const NoopAppLogger(),
  }) : _shiftSessionService = shiftSessionService,
       _orderService = orderService,
       _printerService = printerService,
       _logger = logger;

  final ShiftSessionService _shiftSessionService;
  final OrderService _orderService;
  final PrinterService _printerService;
  final AppLogger _logger;

  Future<Transaction> checkoutCart({
    required User currentUser,
    int? tableNumber,
    required List<CheckoutItem> cartItems,
    required String idempotencyKey,
    PaymentMethod? immediatePaymentMethod,
  }) async {
    final String flow = immediatePaymentMethod != null ? 'PAY_NOW' : 'THEN_PAY';
    if (cartItems.isEmpty) {
      throw EmptyCartException();
    }
    await _shiftSessionService.ensureOrderCreationAllowed(currentUser);

    try {
      debugPrint(
        '[KITCHEN_PRINT][$flow] CheckoutService.checkoutCart'
        ' starting items=${cartItems.length}',
      );
      final Transaction persistedTransaction = await _orderService
          .markOrderPaidInCheckoutIfNeeded(
            currentUser: currentUser,
            tableNumber: tableNumber,
            cartItems: cartItems,
            idempotencyKey: idempotencyKey,
            immediatePaymentMethod: immediatePaymentMethod,
          );
      debugPrint(
        '[KITCHEN_PRINT][$flow] CheckoutService.checkoutCart'
        ' order committed tx=${persistedTransaction.id}'
        ' status=${persistedTransaction.status.name}',
      );
      _logger.audit(
        eventType: 'checkout_completed',
        entityId: persistedTransaction.uuid,
        message: 'Checkout completed.',
        metadata: <String, Object?>{
          'transaction_id': persistedTransaction.id,
          'status': persistedTransaction.status.name,
          'immediate_payment': immediatePaymentMethod?.name,
        },
      );

      await _runPostCommitPrints(
        transactionId: persistedTransaction.id,
        status: persistedTransaction.status,
        flow: flow,
      );

      return persistedTransaction;
    } on AppException {
      rethrow;
    } catch (error) {
      debugPrint(
        '[KITCHEN_PRINT][$flow] CheckoutService.checkoutCart'
        ' FAILED: $error',
      );
      _logger.error(
        eventType: 'checkout_failed',
        message: 'Checkout failed.',
        error: error,
      );
      throw CheckoutFailedException('Checkout failed: $error');
    }
  }

  Future<void> _runPostCommitPrints({
    required int transactionId,
    required TransactionStatus status,
    required String flow,
  }) async {
    debugPrint(
      '[KITCHEN_PRINT][$flow] _runPostCommitPrints'
      ' tx=$transactionId status=${status.name}',
    );
    if (status == TransactionStatus.cancelled) {
      debugPrint('[KITCHEN_PRINT][$flow] skipped — cancelled');
      return;
    }

    try {
      debugPrint(
        '[KITCHEN_PRINT][$flow] calling printKitchenTicket'
        ' tx=$transactionId',
      );
      await _printerService.printKitchenTicket(transactionId);
      debugPrint(
        '[KITCHEN_PRINT][$flow] printKitchenTicket returned ok'
        ' tx=$transactionId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '[KITCHEN_PRINT][$flow] printKitchenTicket FAILED'
        ' tx=$transactionId error=$error',
      );
      _logger.warn(
        eventType: 'checkout_kitchen_print_failed',
        entityId: '$transactionId',
        message: 'Post-commit kitchen print failed.',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (status != TransactionStatus.paid) {
      debugPrint(
        '[KITCHEN_PRINT][$flow] receipt skipped — manual only'
        ' tx=$transactionId status=${status.name}',
      );
      return;
    }
    debugPrint(
      '[KITCHEN_PRINT][$flow] receipt skipped — manual only'
      ' tx=$transactionId status=${status.name}',
    );
  }
}
