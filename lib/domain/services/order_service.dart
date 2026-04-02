import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/breakfast_configuration_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/print_job_repository.dart';
import '../../data/repositories/sync_queue_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transaction_state_repository.dart';
import '../models/breakfast_line_edit.dart';
import '../models/breakfast_rebuild.dart';
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
import 'breakfast_rebuild_engine.dart';
import 'breakfast_requested_state_mapper.dart';
import 'shift_session_service.dart';

class OrderService {
  OrderService({
    required ShiftSessionService shiftSessionService,
    required TransactionRepository transactionRepository,
    required TransactionStateRepository transactionStateRepository,
    BreakfastConfigurationRepository? breakfastConfigurationRepository,
    PaymentRepository? paymentRepository,
    PrintJobRepository? printJobRepository,
    SyncQueueRepository? syncQueueRepository,
    BreakfastRebuildEngine breakfastRebuildEngine =
        const BreakfastRebuildEngine(),
    Uuid? uuidGenerator,
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _shiftSessionService = shiftSessionService,
       _transactionRepository = transactionRepository,
       _transactionStateRepository = transactionStateRepository,
       _breakfastConfigurationRepository = breakfastConfigurationRepository,
       _paymentRepository = paymentRepository,
       _printJobRepository = printJobRepository,
       _syncQueueRepository = syncQueueRepository,
       _breakfastRebuildEngine = breakfastRebuildEngine,
       _uuidGenerator = uuidGenerator ?? const Uuid(),
       _auditLogService = auditLogService,
       _logger = logger;

  final ShiftSessionService _shiftSessionService;
  final TransactionRepository _transactionRepository;
  final TransactionStateRepository _transactionStateRepository;
  final BreakfastConfigurationRepository? _breakfastConfigurationRepository;
  final PaymentRepository? _paymentRepository;
  final PrintJobRepository? _printJobRepository;
  final SyncQueueRepository? _syncQueueRepository;
  final BreakfastRebuildEngine _breakfastRebuildEngine;
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

  Future<TransactionLine> editBreakfastLine({
    required int transactionLineId,
    required BreakfastLineEdit edit,
    int? actorUserId,
  }) async {
    final BreakfastConfigurationRepository configurationRepository =
        _requiredBreakfastConfigurationRepository;

    return _transactionRepository.runInTransaction(() async {
      final ({TransactionLine line, TransactionStatus status})? initialContext =
          await _transactionRepository.getLineContext(transactionLineId);
      if (initialContext == null) {
        throw NotFoundException(
          'Transaction line not found: $transactionLineId',
        );
      }

      try {
        _ensureBreakfastLineEditable(
          status: initialContext.status,
          line: initialContext.line,
        );
      } on BreakfastLineNotEditableException catch (e) {
        _logger.warn(
          eventType: 'breakfast_edit_blocked',
          entityId: initialContext.line.uuid,
          message: 'Breakfast line edit rejected: not editable.',
          metadata: <String, Object?>{
            'transaction_line_id': transactionLineId,
            'transaction_id': initialContext.line.transactionId,
            'reason': e.reason.name,
          },
        );
        rethrow;
      }

      TransactionLine workingLine = initialContext.line;
      final int oldLineTotalMinor = workingLine.lineTotalMinor;
      bool didSplit = false;
      if (workingLine.quantity > 1) {
        workingLine = await _transactionRepository.splitLineForIndependentEdit(
          workingLine.id,
        );
        didSplit = true;
      }

      final BreakfastSetConfiguration? baseConfiguration =
          await configurationRepository.loadSetConfiguration(workingLine.productId);
      if (baseConfiguration == null) {
        _logBreakfastEditRejected(
          lineUuid: workingLine.uuid,
          transactionLineId: workingLine.id,
          codes: const <BreakfastEditErrorCode>[
            BreakfastEditErrorCode.rootNotSetProduct,
          ],
        );
        throw BreakfastEditRejectedException(
          codes: const <BreakfastEditErrorCode>[
            BreakfastEditErrorCode.rootNotSetProduct,
          ],
          transactionLineId: workingLine.id,
        );
      }

      final List<OrderModifier> currentModifiers = await _transactionRepository
          .getModifiersByLine(workingLine.id);
      if (_hasLegacyModifierSnapshot(currentModifiers)) {
        _logBreakfastEditRejected(
          lineUuid: workingLine.uuid,
          transactionLineId: workingLine.id,
          codes: const <BreakfastEditErrorCode>[
            BreakfastEditErrorCode.unsupportedLineSplitState,
          ],
        );
        throw BreakfastEditRejectedException(
          codes: const <BreakfastEditErrorCode>[
            BreakfastEditErrorCode.unsupportedLineSplitState,
          ],
          transactionLineId: workingLine.id,
        );
      }

      final BreakfastRequestedState currentRequestedState =
          BreakfastRequestedStateMapper.reconstruct(
            modifiers: currentModifiers,
            configuration: baseConfiguration,
          );
      final BreakfastRequestedState nextRequestedState = edit.applyTo(
        currentRequestedState,
      );
      final BreakfastSetConfiguration configuration = await _augmentConfiguration(
        configurationRepository: configurationRepository,
        baseConfiguration: baseConfiguration,
        requestedState: nextRequestedState,
      );

      final BreakfastRebuildResult rebuildResult = _breakfastRebuildEngine.rebuild(
        BreakfastRebuildInput(
          transactionLine: BreakfastTransactionLineInput(
            lineId: workingLine.id,
            lineUuid: workingLine.uuid,
            rootProductId: workingLine.productId,
            rootProductName: workingLine.productName,
            baseUnitPriceMinor: workingLine.unitPriceMinor,
            lineQuantity: workingLine.quantity,
          ),
          setConfiguration: configuration,
          requestedState: nextRequestedState,
        ),
      );
      if (rebuildResult.validationErrors.isNotEmpty) {
        _logBreakfastEditRejected(
          lineUuid: workingLine.uuid,
          transactionLineId: workingLine.id,
          codes: rebuildResult.validationErrors,
        );
        throw BreakfastEditRejectedException(
          codes: rebuildResult.validationErrors,
          transactionLineId: workingLine.id,
        );
      }

      await _transactionRepository.replaceBreakfastLineSnapshot(
        transactionLineId: workingLine.id,
        rebuildResult: rebuildResult,
      );
      await recalculateOrderTotals(workingLine.transactionId);

      final TransactionLine? refreshedLine = await _transactionRepository.getLineById(
        workingLine.id,
      );
      if (refreshedLine == null) {
        throw NotFoundException('Transaction line not found: ${workingLine.id}');
      }

      // ── Audit: successful breakfast edit ──
      final Map<String, int> reasonCounts = _buildReasonCounts(
        rebuildResult.classifiedModifiers,
      );
      _logger.audit(
        eventType: 'breakfast_line_edited',
        entityId: workingLine.uuid,
        message: 'Breakfast line snapshot replaced.',
        metadata: <String, Object?>{
          'transaction_id': workingLine.transactionId,
          'transaction_line_id': workingLine.id,
          'root_product_id': workingLine.productId,
          'old_line_total_minor': oldLineTotalMinor,
          'new_line_total_minor': refreshedLine.lineTotalMinor,
          'did_split': didSplit,
          'reason_counts': reasonCounts,
          if (actorUserId != null) 'actor_user_id': actorUserId,
        },
      );

      if (didSplit) {
        _logger.audit(
          eventType: 'breakfast_line_split',
          entityId: workingLine.uuid,
          message: 'Breakfast line was split for independent edit.',
          metadata: <String, Object?>{
            'transaction_id': workingLine.transactionId,
            'original_line_id': initialContext.line.id,
            'new_line_id': workingLine.id,
            'root_product_id': workingLine.productId,
          },
        );
      }

      return refreshedLine;
    });
  }

  Map<String, int> _buildReasonCounts(
    List<BreakfastClassifiedModifier> modifiers,
  ) {
    final Map<String, int> counts = <String, int>{};
    for (final BreakfastClassifiedModifier modifier in modifiers) {
      final String key = modifier.chargeReason?.name ?? modifier.action.name;
      counts[key] = (counts[key] ?? 0) + modifier.quantity;
    }
    return counts;
  }

  void _logBreakfastEditRejected({
    required String lineUuid,
    required int transactionLineId,
    required List<BreakfastEditErrorCode> codes,
  }) {
    _logger.warn(
      eventType: 'breakfast_edit_rejected',
      entityId: lineUuid,
      message: 'Breakfast edit validation failed.',
      metadata: <String, Object?>{
        'transaction_line_id': transactionLineId,
        'error_codes': codes.map((BreakfastEditErrorCode c) => c.name).toList(),
      },
    );
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

  BreakfastConfigurationRepository
  get _requiredBreakfastConfigurationRepository {
    final BreakfastConfigurationRepository? repository =
        _breakfastConfigurationRepository;
    if (repository == null) {
      throw StateError(
        'BreakfastConfigurationRepository is required for breakfast edit operations.',
      );
    }
    return repository;
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

  void _ensureBreakfastLineEditable({
    required TransactionStatus status,
    required TransactionLine line,
  }) {
    switch (status) {
      case TransactionStatus.draft:
        return;
      case TransactionStatus.sent:
        throw BreakfastLineNotEditableException(
          reason: BreakfastEditBlockedReason.sent,
          transactionLineId: line.id,
          transactionId: line.transactionId,
        );
      case TransactionStatus.paid:
        throw BreakfastLineNotEditableException(
          reason: BreakfastEditBlockedReason.paid,
          transactionLineId: line.id,
          transactionId: line.transactionId,
        );
      case TransactionStatus.cancelled:
        throw BreakfastLineNotEditableException(
          reason: BreakfastEditBlockedReason.cancelled,
          transactionLineId: line.id,
          transactionId: line.transactionId,
        );
    }
  }

  bool _hasLegacyModifierSnapshot(List<OrderModifier> modifiers) {
    for (final OrderModifier modifier in modifiers) {
      if (modifier.chargeReason == null &&
          modifier.itemProductId == null &&
          modifier.action != ModifierAction.choice &&
          modifier.sortKey == 0) {
        return true;
      }
    }
    return false;
  }

  Future<BreakfastSetConfiguration> _augmentConfiguration({
    required BreakfastConfigurationRepository configurationRepository,
    required BreakfastSetConfiguration baseConfiguration,
    required BreakfastRequestedState requestedState,
  }) async {
    final Set<int> missingProductIds = <int>{};
    for (final BreakfastAddedProductRequest add in requestedState.addedProducts) {
      if (baseConfiguration.findCatalogProduct(add.itemProductId) == null) {
        missingProductIds.add(add.itemProductId);
      }
    }
    for (final BreakfastChosenGroupRequest choice in requestedState.chosenGroups) {
      final int? selectedItemProductId = choice.selectedItemProductId;
      if (selectedItemProductId != null &&
          baseConfiguration.findCatalogProduct(selectedItemProductId) == null) {
        missingProductIds.add(selectedItemProductId);
      }
    }
    if (missingProductIds.isEmpty) {
      return baseConfiguration;
    }

    final Map<int, BreakfastCatalogProduct> extraProducts =
        await configurationRepository.loadCatalogProductsByIds(missingProductIds);
    return baseConfiguration.copyWith(
      catalogProductsById: <int, BreakfastCatalogProduct>{
        ...baseConfiguration.catalogProductsById,
        ...extraProducts,
      },
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
    final enqueueResult = await syncQueueRepository.addTransactionRootToQueue(
      transactionUuid,
    );
    _logger.audit(
      eventType: 'sync_queue_root_enqueued',
      entityId: transactionUuid,
      message: 'Terminal transaction root queued for sync replay.',
      metadata: <String, Object?>{
        'queue_row_id': enqueueResult.queueId,
        'previous_status': enqueueResult.previousStatus?.name ?? 'none',
        'new_status': enqueueResult.newStatus.name,
        'created_new_row': enqueueResult.createdNewRow,
      },
    );
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
