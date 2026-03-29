import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/print_job_repository.dart';
import '../../data/repositories/sync_queue_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transaction_state_repository.dart';
import '../models/open_order_summary.dart';
import '../models/authorization_policy.dart';
import '../models/checkout_item.dart';
import '../models/order_lifecycle_policy.dart';
import '../models/order_modifier.dart';
import '../models/payment.dart';
import '../models/print_job.dart';
import '../models/transaction.dart';
import '../models/transaction_line.dart';
import '../models/user.dart';
import 'audit_log_service.dart';
import 'shift_session_service.dart';

class OrderService {
  OrderService({
    required ShiftSessionService shiftSessionService,
    required TransactionRepository transactionRepository,
    required TransactionStateRepository transactionStateRepository,
    PaymentRepository? paymentRepository,
    PrintJobRepository? printJobRepository,
    SyncQueueRepository? syncQueueRepository,
    Uuid? uuidGenerator,
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _shiftSessionService = shiftSessionService,
       _transactionRepository = transactionRepository,
       _transactionStateRepository = transactionStateRepository,
       _paymentRepository = paymentRepository,
       _printJobRepository = printJobRepository,
       _syncQueueRepository = syncQueueRepository,
       _uuidGenerator = uuidGenerator ?? const Uuid(),
       _auditLogService = auditLogService,
       _logger = logger;

  final ShiftSessionService _shiftSessionService;
  final TransactionRepository _transactionRepository;
  final TransactionStateRepository _transactionStateRepository;
  final PaymentRepository? _paymentRepository;
  final PrintJobRepository? _printJobRepository;
  final SyncQueueRepository? _syncQueueRepository;
  final Uuid _uuidGenerator;
  final AuditLogService _auditLogService;
  final AppLogger _logger;

  Future<Transaction> createOrder({
    required User currentUser,
    int? tableNumber,
    String? requestIdempotencyKey,
  }) async {
    await _shiftSessionService.ensureOrderCreationAllowed(currentUser);
    final openShift = await _shiftSessionService.requireBackendOpenShift();

    final String orderUuid = _uuidGenerator.v4();
    final String idempotencyKey = requestIdempotencyKey ?? _uuidGenerator.v4();

    final Transaction transaction = await _transactionRepository
        .createTransaction(
          shiftId: openShift.id,
          userId: currentUser.id,
          tableNumber: tableNumber,
          uuid: orderUuid,
          idempotencyKey: idempotencyKey,
        );
    _logger.audit(
      eventType: 'order_created',
      entityId: transaction.uuid,
      message: 'Order created.',
      metadata: <String, Object?>{
        'shift_id': transaction.shiftId,
        'user_id': currentUser.id,
        'table_number': transaction.tableNumber,
      },
    );
    return transaction;
  }

  Future<TransactionLine> addProductToOrder({
    required int transactionId,
    required int productId,
    int quantity = 1,
  }) async {
    await _ensureProductAvailableForSale(productId);
    final TransactionLine line = await _transactionRepository.addLine(
      transactionId: transactionId,
      productId: productId,
      quantity: quantity,
    );
    await recalculateOrderTotals(transactionId);
    return line;
  }

  Future<OrderModifier> addModifierToLine({
    required int transactionLineId,
    required ModifierAction action,
    required String itemName,
    required int extraPriceMinor,
  }) async {
    final OrderModifier modifier = await _transactionRepository.addModifier(
      transactionLineId: transactionLineId,
      action: action,
      itemName: itemName,
      extraPriceMinor: extraPriceMinor,
    );
    final int transactionId = await _transactionRepository
        .getTransactionIdByLine(transactionLineId);
    await recalculateOrderTotals(transactionId);
    return modifier;
  }

  Future<void> recalculateOrderTotals(int transactionId) async {
    final ({int subtotalMinor, int modifierTotalMinor, int totalAmountMinor})
    totals = await _transactionRepository.calculateTotals(transactionId);
    await _transactionRepository.updateTotals(
      transactionId: transactionId,
      subtotalMinor: totals.subtotalMinor,
      modifierTotalMinor: totals.modifierTotalMinor,
      totalAmountMinor: totals.totalAmountMinor,
    );
  }

  Future<Payment> markOrderPaid({
    required int transactionId,
    required PaymentMethod method,
    required User currentUser,
  }) async {
    final Transaction? transaction = await _transactionRepository.getById(
      transactionId,
    );
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
    _ensureTransactionCanBePaid(transaction);
    await _shiftSessionService.ensurePaymentAllowed(
      user: currentUser,
      transaction: transaction,
    );

    return _transactionRepository.runInTransaction(() async {
      await recalculateOrderTotals(transactionId);

      final Transaction? refreshedTransaction = await _transactionRepository
          .getById(transactionId);
      if (refreshedTransaction == null) {
        throw NotFoundException('Transaction not found: $transactionId');
      }
      _ensureTransactionCanBePaid(refreshedTransaction);

      final DateTime paidAt = DateTime.now();
      final Payment payment = await _requiredPaymentRepository.createPayment(
        transactionId: transactionId,
        uuid: _uuidGenerator.v4(),
        method: method,
        amountMinor: refreshedTransaction.totalAmountMinor,
        paidAt: paidAt,
      );
      await _transactionStateRepository.transitionSentOrderToPaid(
        transactionId: transactionId,
        paidAt: paidAt,
      );
      await _printJobRepository?.ensureQueued(
        transactionId: transactionId,
        target: PrintJobTarget.receipt,
        now: paidAt,
      );
      await _enqueueSyncGraph(transactionUuid: refreshedTransaction.uuid);
      _logger.audit(
        eventType: 'order_paid',
        entityId: refreshedTransaction.uuid,
        message: 'Order paid successfully.',
        metadata: <String, Object?>{
          'payment_uuid': payment.uuid,
          'amount_minor': refreshedTransaction.totalAmountMinor,
          'method': method.name,
          'user_id': currentUser.id,
        },
      );

      return payment;
    });
  }

  PaymentRepository get _requiredPaymentRepository {
    final PaymentRepository? paymentRepository = _paymentRepository;
    if (paymentRepository == null) {
      throw StateError('PaymentRepository is required for payment operations.');
    }
    return paymentRepository;
  }

  Future<Transaction> markOrderPaidInCheckoutIfNeeded({
    required User currentUser,
    int? tableNumber,
    required List<CheckoutItem> cartItems,
    required String idempotencyKey,
    required PaymentMethod? immediatePaymentMethod,
  }) async {
    return _transactionRepository.runInTransaction(() async {
      final Transaction createdTransaction = await createOrder(
        currentUser: currentUser,
        tableNumber: tableNumber,
        requestIdempotencyKey: idempotencyKey,
      );

      for (final CheckoutItem item in cartItems) {
        final TransactionLine line = await addProductToOrder(
          transactionId: createdTransaction.id,
          productId: item.productId,
          quantity: item.quantity,
        );

        for (final modifier in item.modifiers) {
          await addModifierToLine(
            transactionLineId: line.id,
            action: modifier.action,
            itemName: modifier.itemName,
            extraPriceMinor: modifier.extraPriceMinor,
          );
        }
      }

      await recalculateOrderTotals(createdTransaction.id);

      await sendOrder(
        transactionId: createdTransaction.id,
        currentUser: currentUser,
      );

      if (immediatePaymentMethod != null) {
        await markOrderPaid(
          transactionId: createdTransaction.id,
          method: immediatePaymentMethod,
          currentUser: currentUser,
        );
      }

      final Transaction? finalTransaction = await _transactionRepository
          .getById(createdTransaction.id);
      if (finalTransaction == null) {
        throw NotFoundException(
          'Transaction missing after checkout commit: ${createdTransaction.id}',
        );
      }
      return finalTransaction;
    });
  }

  Future<void> sendOrder({
    required int transactionId,
    required User currentUser,
  }) async {
    AuthorizationPolicy.ensureAllowed(
      currentUser,
      OperatorPermission.sendOrder,
    );
    final Transaction? transaction = await _transactionRepository.getById(
      transactionId,
    );
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
    OrderLifecyclePolicy.ensureCanTransition(
      from: transaction.status,
      to: TransactionStatus.sent,
    );
    await _shiftSessionService.ensureOrderMutationAllowed(
      user: currentUser,
      transaction: transaction,
    );

    await _transactionRepository.runInTransaction(() async {
      await recalculateOrderTotals(transactionId);
      final List<TransactionLine> lines = await _transactionRepository.getLines(
        transactionId,
      );
      if (lines.isEmpty) {
        throw ValidationException('Draft order cannot be sent without items.');
      }
      await _transactionStateRepository.transitionDraftOrderToSent(
        transactionId: transactionId,
      );
      await _printJobRepository?.ensureQueued(
        transactionId: transactionId,
        target: PrintJobTarget.kitchen,
      );
      _logger.audit(
        eventType: 'order_sent',
        entityId: transaction.uuid,
        message: 'Draft order sent.',
        metadata: <String, Object?>{'user_id': currentUser.id},
      );
    });
  }

  Future<void> cancelOrder({
    required int transactionId,
    required User currentUser,
  }) async {
    final Transaction? transaction = await _transactionRepository.getById(
      transactionId,
    );
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
    OrderLifecyclePolicy.ensureCanTransition(
      from: transaction.status,
      to: TransactionStatus.cancelled,
    );

    AuthorizationPolicy.ensureCanCancelOrder(
      user: currentUser,
      transaction: transaction,
    );
    await _shiftSessionService.ensureOrderMutationAllowed(
      user: currentUser,
      transaction: transaction,
    );

    await _transactionRepository.runInTransaction(() async {
      await _transactionStateRepository.transitionSentOrderToCancelled(
        transactionId: transactionId,
        cancelledByUserId: currentUser.id,
      );
      await _enqueueSyncGraph(transactionUuid: transaction.uuid);
      _logger.warn(
        eventType: 'order_cancelled',
        entityId: transaction.uuid,
        message: 'Open order cancelled.',
        metadata: <String, Object?>{'cancelled_by': currentUser.id},
      );
    });
    await _auditLogService.logActionSafely(
      actorUserId: currentUser.id,
      action: 'transaction_cancelled',
      entityType: 'transaction',
      entityId: transaction.uuid,
      metadata: <String, Object?>{
        'transaction_id': transactionId,
        'shift_id': transaction.shiftId,
      },
    );
  }

  Future<void> discardDraft({
    required int transactionId,
    required User currentUser,
  }) async {
    final Transaction? transaction = await _transactionRepository.getById(
      transactionId,
    );
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
    if (!OrderLifecyclePolicy.canDiscardDraft(transaction.status)) {
      throw InvalidStateTransitionException(
        'Only draft orders can be discarded.',
      );
    }

    AuthorizationPolicy.ensureCanDiscardDraft(
      user: currentUser,
      transaction: transaction,
    );
    await _shiftSessionService.ensureOrderMutationAllowed(
      user: currentUser,
      transaction: transaction,
    );

    await _transactionRepository.deleteDraft(transactionId);
    _logger.audit(
      eventType: 'draft_discarded',
      entityId: transaction.uuid,
      message: 'Draft order discarded.',
      metadata: <String, Object?>{'discarded_by': currentUser.id},
    );
  }

  Future<List<TransactionLine>> getOrderLines(int transactionId) {
    return _transactionRepository.getLines(transactionId);
  }

  Future<List<OrderModifier>> getLineModifiers(int transactionLineId) {
    return _transactionRepository.getModifiersByLine(transactionLineId);
  }

  Future<List<Transaction>> getActiveOrders({int? shiftId}) {
    return _transactionRepository.getActiveOrders(shiftId: shiftId);
  }

  Future<List<Transaction>> getOrdersByShift(int shiftId) {
    return _transactionRepository.getByShift(shiftId);
  }

  Future<List<OpenOrderSummary>> getOrderSummariesByShift(int shiftId) async {
    final List<Transaction> orders = await getActiveOrders(shiftId: shiftId);

    return Future.wait(
      orders.map((Transaction transaction) async {
        final List<TransactionLine> lines = await getOrderLines(transaction.id);
        return OpenOrderSummary(
          transaction: transaction,
          itemCount: lines.fold<int>(
            0,
            (int sum, TransactionLine line) => sum + line.quantity,
          ),
          shortContent: _buildShortContent(lines),
        );
      }),
    );
  }

  Future<Transaction?> getOrderById(int transactionId) {
    return _transactionRepository.getById(transactionId);
  }

  Future<void> updateTableNumber({
    required int transactionId,
    required int? tableNumber,
  }) {
    return _transactionRepository.updateTableNumber(
      transactionId: transactionId,
      tableNumber: tableNumber,
    );
  }

  String _buildShortContent(List<TransactionLine> lines) {
    if (lines.isEmpty) {
      return 'No items';
    }

    final Map<String, int> quantityByProduct = <String, int>{};
    for (final TransactionLine line in lines) {
      quantityByProduct.update(
        line.productName,
        (int quantity) => quantity + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    return quantityByProduct.entries
        .map((MapEntry<String, int> entry) => '${entry.value} ${entry.key}')
        .join(', ');
  }

  Future<void> _enqueueSyncGraph({required String transactionUuid}) async {
    final SyncQueueRepository? syncQueueRepository = _syncQueueRepository;
    if (syncQueueRepository == null) {
      return;
    }

    // A terminal transaction is synced as a full graph rooted at the
    // transaction snapshot. Child rows remain immutable and are rebuilt from
    // local DB during sync, so one queue event is enough to recover the graph.
    await syncQueueRepository.addToQueue('transactions', transactionUuid);
  }

  Future<void> _ensureProductAvailableForSale(int productId) async {
    final ({bool isActive, bool isVisibleOnPos})? saleAvailability =
        await _transactionRepository.getProductSaleAvailability(productId);
    if (saleAvailability == null ||
        !saleAvailability.isActive ||
        !saleAvailability.isVisibleOnPos) {
      throw ValidationException('Product is not available for sale.');
    }
  }

  void _ensureTransactionCanBePaid(Transaction transaction) {
    switch (transaction.status) {
      case TransactionStatus.sent:
        return;
      case TransactionStatus.paid:
        throw OrderPaymentBlockedException(
          reason: PaymentBlockReason.alreadyPaid,
          transactionId: transaction.id,
        );
      case TransactionStatus.cancelled:
        throw OrderPaymentBlockedException(
          reason: PaymentBlockReason.cancelled,
          transactionId: transaction.id,
        );
      case TransactionStatus.draft:
        throw OrderPaymentBlockedException(
          reason: PaymentBlockReason.notSent,
          transactionId: transaction.id,
        );
    }
  }
}
