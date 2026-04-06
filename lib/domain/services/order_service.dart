import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/breakfast_configuration_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/print_job_repository.dart';
import '../../data/repositories/sync_queue_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transaction_state_repository.dart';
import '../models/breakfast_line_edit.dart';
import '../models/breakfast_cooking_instruction.dart';
import '../models/breakfast_cart_selection.dart';
import '../models/breakfast_rebuild.dart';
import '../models/meal_adjustment_profile.dart';
import '../models/meal_customization.dart';
import '../models/open_order_summary.dart';
import '../models/authorization_policy.dart';
import '../models/checkout_item.dart';
import '../models/order_lifecycle_policy.dart';
import '../models/order_modifier.dart';
import '../models/payment.dart';
import '../models/print_job.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../models/transaction_line.dart';
import '../models/user.dart';
import '../repositories/meal_adjustment_profile_repository.dart';
import 'audit_log_service.dart';
import 'breakfast_cooking_instruction_service.dart';
import 'breakfast_rebuild_engine.dart';
import 'breakfast_requested_state_mapper.dart';
import 'breakfast_requested_state_transformer.dart';
import 'meal_adjustment_profile_validation_service.dart';
import 'meal_customization_engine.dart';
import 'shift_session_service.dart';

class OrderService {
  OrderService({
    required ShiftSessionService shiftSessionService,
    required TransactionRepository transactionRepository,
    required TransactionStateRepository transactionStateRepository,
    ProductRepository? productRepository,
    BreakfastConfigurationRepository? breakfastConfigurationRepository,
    MealAdjustmentProfileRepository? mealAdjustmentProfileRepository,
    MealAdjustmentProfileValidationService?
    mealAdjustmentProfileValidationService,
    PaymentRepository? paymentRepository,
    PrintJobRepository? printJobRepository,
    SyncQueueRepository? syncQueueRepository,
    BreakfastRebuildEngine breakfastRebuildEngine =
        const BreakfastRebuildEngine(),
    MealCustomizationEngine mealCustomizationEngine =
        const MealCustomizationEngine(),
    BreakfastCookingInstructionService breakfastCookingInstructionService =
        const BreakfastCookingInstructionService(),
    Uuid? uuidGenerator,
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _shiftSessionService = shiftSessionService,
       _transactionRepository = transactionRepository,
       _transactionStateRepository = transactionStateRepository,
       _productRepository = productRepository,
       _breakfastConfigurationRepository = breakfastConfigurationRepository,
       _mealAdjustmentProfileRepository = mealAdjustmentProfileRepository,
       _mealAdjustmentProfileValidationService =
           mealAdjustmentProfileValidationService,
       _paymentRepository = paymentRepository,
       _printJobRepository = printJobRepository,
       _syncQueueRepository = syncQueueRepository,
       _breakfastRebuildEngine = breakfastRebuildEngine,
       _mealCustomizationEngine = mealCustomizationEngine,
       _breakfastCookingInstructionService = breakfastCookingInstructionService,
       _uuidGenerator = uuidGenerator ?? const Uuid(),
       _auditLogService = auditLogService,
       _logger = logger;

  final ShiftSessionService _shiftSessionService;
  final TransactionRepository _transactionRepository;
  final TransactionStateRepository _transactionStateRepository;
  final ProductRepository? _productRepository;
  final BreakfastConfigurationRepository? _breakfastConfigurationRepository;
  final MealAdjustmentProfileRepository? _mealAdjustmentProfileRepository;
  final MealAdjustmentProfileValidationService?
  _mealAdjustmentProfileValidationService;
  final PaymentRepository? _paymentRepository;
  final PrintJobRepository? _printJobRepository;
  final SyncQueueRepository? _syncQueueRepository;
  final BreakfastRebuildEngine _breakfastRebuildEngine;
  final MealCustomizationEngine _mealCustomizationEngine;
  final BreakfastCookingInstructionService _breakfastCookingInstructionService;
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
    MealCustomizationRequest? mealCustomizationRequest,
  }) async {
    final _StandardProductFlowDecision flowDecision =
        await _decideStandardProductFlow(
          productId: productId,
          mealCustomizationRequest: mealCustomizationRequest,
        );
    if (flowDecision.kind == _StandardProductFlowKind.mealCustomization) {
      return _addMealCustomizationToOrder(
        transactionId: transactionId,
        context: flowDecision.mealContext!,
        request: mealCustomizationRequest,
        quantity: quantity,
      );
    }

    await _ensureProductAvailableForSale(productId);
    final TransactionLine line = await _transactionRepository.addLine(
      transactionId: transactionId,
      productId: productId,
      quantity: quantity,
    );
    await recalculateOrderTotals(transactionId);
    return line;
  }

  Future<TransactionLine> addBreakfastSelectionToOrder({
    required int transactionId,
    required int productId,
    required BreakfastCartSelection selection,
  }) async {
    await _ensureProductAvailableForSale(productId);
    if (selection.rebuildResult.validationErrors.isNotEmpty) {
      throw BreakfastEditRejectedException(
        codes: selection.rebuildResult.validationErrors,
      );
    }

    return _transactionRepository.runInTransaction(() async {
      final BreakfastConfigurationRepository configurationRepository =
          _requiredBreakfastConfigurationRepository;
      final BreakfastSetConfiguration? baseConfiguration =
          await configurationRepository.loadSetConfiguration(productId);
      if (baseConfiguration == null) {
        throw ValidationException('Breakfast configuration is unavailable.');
      }
      final BreakfastSetConfiguration configuration =
          await _augmentConfiguration(
            configurationRepository: configurationRepository,
            baseConfiguration: baseConfiguration,
            requestedState: selection.requestedState,
          );
      final BreakfastRequestedState normalizedRequestedState =
          _breakfastCookingInstructionService.sanitizeRequestedState(
            configuration: configuration,
            requestedState: selection.requestedState,
          );

      final TransactionLine line = await _transactionRepository.addLine(
        transactionId: transactionId,
        productId: productId,
        quantity: 1,
      );
      await _transactionRepository.replaceBreakfastLineSnapshot(
        transactionLineId: line.id,
        rebuildResult: selection.rebuildResult,
        cookingInstructions: _breakfastCookingInstructionService
            .buildPersistedRecords(
              transactionLineId: line.id,
              configuration: configuration,
              requestedState: normalizedRequestedState,
              createUuid: _uuidGenerator.v4,
            ),
      );
      final TransactionLine? persisted = await _transactionRepository
          .getLineById(line.id);
      if (persisted == null) {
        throw NotFoundException('Transaction line not found: ${line.id}');
      }
      return persisted;
    });
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
    DateTime? expectedTransactionUpdatedAt,
  }) async {
    final BreakfastConfigurationRepository configurationRepository =
        _requiredBreakfastConfigurationRepository;

    return _transactionRepository.runInTransaction(() async {
      final ({
        TransactionLine line,
        TransactionStatus status,
        DateTime transactionUpdatedAt,
      })?
      initialContext = await _transactionRepository.getLineContext(
        transactionLineId,
      );
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
      try {
        _ensureBreakfastEditNotStale(
          expectedTransactionUpdatedAt: expectedTransactionUpdatedAt,
          actualTransactionUpdatedAt: initialContext.transactionUpdatedAt,
          line: initialContext.line,
        );
      } on StaleBreakfastEditException catch (e) {
        _logger.warn(
          eventType: 'breakfast_edit_stale',
          entityId: initialContext.line.uuid,
          message: 'Breakfast line edit rejected: stale transaction snapshot.',
          metadata: <String, Object?>{
            'transaction_line_id': transactionLineId,
            'transaction_id': initialContext.line.transactionId,
            'expected_updated_at': e.expectedUpdatedAt.toIso8601String(),
            'actual_updated_at': e.actualUpdatedAt.toIso8601String(),
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
          await configurationRepository.loadSetConfiguration(
            workingLine.productId,
          );
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
      final List<BreakfastCookingInstructionRecord> currentCookingInstructions =
          await _transactionRepository.getBreakfastCookingInstructionsByLine(
            workingLine.id,
          );
      if (_hasLegacyModifierSnapshot(currentModifiers) ||
          _hasUnsupportedStrictRequestedStateSnapshot(currentModifiers)) {
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
          BreakfastRequestedStateTransformer.assertInvariant(
            BreakfastRequestedStateMapper.fromPersistedSnapshot(
              modifiers: currentModifiers,
              cookingInstructions: currentCookingInstructions
                  .map(
                    (BreakfastCookingInstructionRecord instruction) =>
                        BreakfastCookingInstructionRequest(
                          itemProductId: instruction.itemProductId,
                          instructionCode: instruction.instructionCode,
                          instructionLabel: instruction.instructionLabel,
                        ),
                  )
                  .toList(growable: false),
            ),
            source: 'OrderService.currentRequestedState',
          );
      final BreakfastRequestedState nextRequestedState =
          BreakfastRequestedStateTransformer.assertInvariant(
            edit.applyTo(currentRequestedState),
            source: 'OrderService.nextRequestedState',
          );
      final List<BreakfastEditErrorCode> invalidExtraCodes =
          _validateRequestedExtras(
            configuration: baseConfiguration,
            currentRequestedState: currentRequestedState,
            nextRequestedState: nextRequestedState,
          );
      if (invalidExtraCodes.isNotEmpty) {
        _logBreakfastEditRejected(
          lineUuid: workingLine.uuid,
          transactionLineId: workingLine.id,
          codes: invalidExtraCodes,
        );
        throw BreakfastEditRejectedException(
          codes: invalidExtraCodes,
          transactionLineId: workingLine.id,
        );
      }
      final BreakfastSetConfiguration configuration =
          await _augmentConfiguration(
            configurationRepository: configurationRepository,
            baseConfiguration: baseConfiguration,
            requestedState: nextRequestedState,
          );
      final BreakfastRequestedState normalizedRequestedState =
          _breakfastCookingInstructionService.sanitizeRequestedState(
            configuration: configuration,
            requestedState: nextRequestedState,
          );
      final List<BreakfastEditErrorCode> invalidChoiceTransitionCodes =
          _validateRequiredChoiceTransitions(
            configuration: configuration,
            currentRequestedState: currentRequestedState,
            nextRequestedState: normalizedRequestedState,
          );
      if (invalidChoiceTransitionCodes.isNotEmpty) {
        _logBreakfastEditRejected(
          lineUuid: workingLine.uuid,
          transactionLineId: workingLine.id,
          codes: invalidChoiceTransitionCodes,
        );
        throw BreakfastEditRejectedException(
          codes: invalidChoiceTransitionCodes,
          transactionLineId: workingLine.id,
        );
      }

      final BreakfastRebuildResult rebuildResult = _breakfastRebuildEngine
          .rebuild(
            BreakfastRebuildInput(
              transactionLine: BreakfastTransactionLineInput(
                lineId: workingLine.id,
                lineUuid: workingLine.uuid,
                rootProductId: workingLine.productId,
                rootProductName: workingLine.productName,
                baseUnitPriceMinor: workingLine.unitPriceMinor,
                lineQuantity: workingLine.quantity,
                pricingMode: TransactionLinePricingMode.set,
              ),
              setConfiguration: configuration,
              requestedState: normalizedRequestedState,
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
        cookingInstructions: _breakfastCookingInstructionService
            .buildPersistedRecords(
              transactionLineId: workingLine.id,
              configuration: configuration,
              requestedState: normalizedRequestedState,
              createUuid: _uuidGenerator.v4,
            ),
      );

      final TransactionLine? refreshedLine = await _transactionRepository
          .getLineById(workingLine.id);
      if (refreshedLine == null) {
        throw NotFoundException(
          'Transaction line not found: ${workingLine.id}',
        );
      }

      // Audit successful breakfast edit.
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

  Future<TransactionLine> editMealCustomizationLine({
    required int transactionLineId,
    required MealCustomizationRequest request,
    int? actorUserId,
    DateTime? expectedTransactionUpdatedAt,
  }) async {
    return _transactionRepository.runInTransaction(() async {
      final ({
        TransactionLine line,
        TransactionStatus status,
        DateTime transactionUpdatedAt,
      })?
      initialContext = await _transactionRepository.getLineContext(
        transactionLineId,
      );
      if (initialContext == null) {
        throw NotFoundException(
          'Transaction line not found: $transactionLineId',
        );
      }

      try {
        _ensureMealCustomizationLineEditable(
          status: initialContext.status,
          line: initialContext.line,
        );
      } on MealCustomizationLineNotEditableException catch (error) {
        _logger.warn(
          eventType: 'meal_customization_edit_blocked',
          entityId: initialContext.line.uuid,
          message: 'Meal customization line edit rejected: not editable.',
          metadata: <String, Object?>{
            'transaction_line_id': transactionLineId,
            'transaction_id': initialContext.line.transactionId,
            'reason': error.reason.name,
          },
        );
        rethrow;
      }
      try {
        _ensureMealCustomizationEditNotStale(
          expectedTransactionUpdatedAt: expectedTransactionUpdatedAt,
          actualTransactionUpdatedAt: initialContext.transactionUpdatedAt,
          line: initialContext.line,
        );
      } on StaleMealCustomizationEditException catch (error) {
        _logger.warn(
          eventType: 'meal_customization_edit_stale',
          entityId: initialContext.line.uuid,
          message:
              'Meal customization line edit rejected: stale transaction snapshot.',
          metadata: <String, Object?>{
            'transaction_line_id': transactionLineId,
            'transaction_id': initialContext.line.transactionId,
            'expected_updated_at': error.expectedUpdatedAt.toIso8601String(),
            'actual_updated_at': error.actualUpdatedAt.toIso8601String(),
          },
        );
        rethrow;
      }

      final MealCustomizationPersistedSnapshotRecord? currentSnapshotRecord =
          await _transactionRepository.getMealCustomizationSnapshotByLine(
            transactionLineId,
          );
      if (currentSnapshotRecord == null) {
        final MealCustomizationLineNotEditableException error =
            MealCustomizationLineNotEditableException(
              reason: MealCustomizationEditBlockedReason.legacySnapshotMissing,
              transactionLineId: transactionLineId,
              transactionId: initialContext.line.transactionId,
            );
        _logger.warn(
          eventType: 'meal_customization_edit_blocked',
          entityId: initialContext.line.uuid,
          message:
              'Meal customization line edit rejected: snapshot is unavailable.',
          metadata: <String, Object?>{
            'transaction_line_id': transactionLineId,
            'transaction_id': initialContext.line.transactionId,
            'is_legacy_line': await _transactionRepository
                .isLegacyMealCustomizationLine(transactionLineId),
            'reason': error.reason.name,
          },
        );
        throw error;
      }

      final Product product =
          await _requiredProductRepository.getById(
            initialContext.line.productId,
          ) ??
          (throw NotFoundException(
            'Product not found: ${initialContext.line.productId}',
          ));
      final _MealCustomizationRuntimeContext context =
          await _resolveMealCustomizationRuntimeContextForProfile(
            product,
            profileId: currentSnapshotRecord.profileId,
            enforceCurrentProductBinding: false,
            enforceBreakfastCompatibility: false,
          );
      final MealCustomizationRequest normalizedRequest = request.copyWith(
        productId: initialContext.line.productId,
        profileId: currentSnapshotRecord.profileId,
      );
      final MealCustomizationResolvedSnapshot nextSnapshot =
          _mealCustomizationEngine.evaluate(
            profile: context.profile,
            request: normalizedRequest,
          );

      final int previousLineId = initialContext.line.id;
      final int previousQuantity = initialContext.line.quantity;
      final int oldLineTotalMinor = initialContext.line.lineTotalMinor;
      final String previousIdentity = currentSnapshotRecord.customizationKey;
      final String nextIdentity = nextSnapshot.stableIdentityKey;
      final bool identityChanged = nextIdentity != previousIdentity;

      TransactionLine? persistedLine;
      bool mergedIntoExistingLine = false;
      int? mergedTargetLineId;
      if (!identityChanged) {
        await _transactionRepository.replaceMealCustomizationLineSnapshot(
          transactionLineId: previousLineId,
          snapshot: nextSnapshot,
        );
        persistedLine = await _transactionRepository.getLineById(
          previousLineId,
        );
      } else {
        final TransactionLine? existingLine = await _transactionRepository
            .findDraftMealCustomizationLineByIdentity(
              transactionId: initialContext.line.transactionId,
              productId: initialContext.line.productId,
              customizationKey: nextIdentity,
              excludeTransactionLineId: previousLineId,
            );
        if (existingLine != null) {
          await _transactionRepository.incrementLineQuantity(
            transactionLineId: existingLine.id,
            incrementBy: previousQuantity,
          );
          await _transactionRepository.deleteDraftLineCompletely(
            previousLineId,
          );
          persistedLine = await _transactionRepository.getLineById(
            existingLine.id,
          );
          mergedIntoExistingLine = true;
          mergedTargetLineId = existingLine.id;
        } else {
          await _transactionRepository.replaceMealCustomizationLineSnapshot(
            transactionLineId: previousLineId,
            snapshot: nextSnapshot,
          );
          persistedLine = await _transactionRepository.getLineById(
            previousLineId,
          );
        }
      }

      if (persistedLine == null) {
        throw DatabaseException(
          'Meal customization edit did not produce a persisted transaction line.',
        );
      }

      _logger.audit(
        eventType: 'meal_customization_line_edited',
        entityId: initialContext.line.uuid,
        message: mergedIntoExistingLine
            ? 'Meal customization line merged into an existing grouped line after edit.'
            : 'Meal customization line snapshot replaced.',
        metadata: <String, Object?>{
          'transaction_id': initialContext.line.transactionId,
          'transaction_line_id': previousLineId,
          'result_line_id': persistedLine.id,
          'root_product_id': initialContext.line.productId,
          'line_quantity': previousQuantity,
          'old_line_total_minor': oldLineTotalMinor,
          'new_line_total_minor': persistedLine.lineTotalMinor,
          'identity_changed': identityChanged,
          'merged_into_existing_line': mergedIntoExistingLine,
          'previous_identity': previousIdentity,
          'next_identity': nextIdentity,
          if (mergedTargetLineId != null)
            'merged_target_line_id': mergedTargetLineId,
          if (actorUserId != null) 'actor_user_id': actorUserId,
        },
      );

      return persistedLine;
    });
  }

  /// Splits one unit from a grouped meal customization line, applies the new
  /// customization to it, and merges the result into an existing identical line
  /// when possible. The original line's quantity is decremented by one.
  ///
  /// Commit-on-confirm: the caller is responsible for only invoking this method
  /// after the user has confirmed the edit. No optimistic split is performed.
  Future<TransactionLine> editOneMealCustomizationLine({
    required int transactionLineId,
    required MealCustomizationRequest request,
    int? actorUserId,
    DateTime? expectedTransactionUpdatedAt,
  }) async {
    return _transactionRepository.runInTransaction(() async {
      final ({
        TransactionLine line,
        TransactionStatus status,
        DateTime transactionUpdatedAt,
      })?
      initialContext = await _transactionRepository.getLineContext(
        transactionLineId,
      );
      if (initialContext == null) {
        throw NotFoundException(
          'Transaction line not found: $transactionLineId',
        );
      }

      _ensureMealCustomizationLineEditable(
        status: initialContext.status,
        line: initialContext.line,
      );
      _ensureMealCustomizationEditNotStale(
        expectedTransactionUpdatedAt: expectedTransactionUpdatedAt,
        actualTransactionUpdatedAt: initialContext.transactionUpdatedAt,
        line: initialContext.line,
      );

      if (initialContext.line.quantity < 2) {
        throw ValidationException(
          'editOneMealCustomizationLine requires a grouped line with quantity >= 2. '
          'Use editMealCustomizationLine for single-quantity lines.',
        );
      }

      final MealCustomizationPersistedSnapshotRecord? currentSnapshotRecord =
          await _transactionRepository.getMealCustomizationSnapshotByLine(
            transactionLineId,
          );
      if (currentSnapshotRecord == null) {
        throw MealCustomizationLineNotEditableException(
          reason: MealCustomizationEditBlockedReason.legacySnapshotMissing,
          transactionLineId: transactionLineId,
          transactionId: initialContext.line.transactionId,
        );
      }

      final Product product =
          await _requiredProductRepository.getById(
            initialContext.line.productId,
          ) ??
          (throw NotFoundException(
            'Product not found: ${initialContext.line.productId}',
          ));
      final _MealCustomizationRuntimeContext context =
          await _resolveMealCustomizationRuntimeContextForProfile(
            product,
            profileId: currentSnapshotRecord.profileId,
            enforceCurrentProductBinding: false,
            enforceBreakfastCompatibility: false,
          );
      final MealCustomizationRequest normalizedRequest = request.copyWith(
        productId: initialContext.line.productId,
        profileId: currentSnapshotRecord.profileId,
      );
      final MealCustomizationResolvedSnapshot nextSnapshot =
          _mealCustomizationEngine.evaluate(
            profile: context.profile,
            request: normalizedRequest,
          );

      final int previousLineId = initialContext.line.id;
      final int transactionId = initialContext.line.transactionId;
      final String previousIdentity = currentSnapshotRecord.customizationKey;
      final String nextIdentity = nextSnapshot.stableIdentityKey;

      // Step 1: Decrement the original grouped line by 1.
      // Precondition guarantees qty >= 2, so this leaves qty >= 1.
      await _transactionRepository.decrementLineQuantityOrDelete(
        previousLineId,
      );

      // Step 2: Determine where the split unit lands.
      TransactionLine? resultLine;
      bool mergedIntoExistingLine = false;
      int? mergeTargetLineId;

      if (nextIdentity == previousIdentity) {
        // The edit produced the same identity as the original line.
        // The unit should merge back into the (now decremented) original.
        await _transactionRepository.incrementLineQuantity(
          transactionLineId: previousLineId,
          incrementBy: 1,
        );
        // However the snapshot may have changed in-place (e.g. re-evaluation
        // with updated pricing rules). Replace snapshot to stay current.
        await _transactionRepository.replaceMealCustomizationLineSnapshot(
          transactionLineId: previousLineId,
          snapshot: nextSnapshot,
        );
        resultLine = await _transactionRepository.getLineById(previousLineId);
      } else {
        // Check for an existing line with the new identity.
        final TransactionLine? existingLine = await _transactionRepository
            .findDraftMealCustomizationLineByIdentity(
              transactionId: transactionId,
              productId: initialContext.line.productId,
              customizationKey: nextIdentity,
              excludeTransactionLineId: previousLineId,
            );
        if (existingLine != null) {
          // Merge into the existing line with matching identity.
          await _transactionRepository.incrementLineQuantity(
            transactionLineId: existingLine.id,
            incrementBy: 1,
          );
          resultLine = await _transactionRepository.getLineById(
            existingLine.id,
          );
          mergedIntoExistingLine = true;
          mergeTargetLineId = existingLine.id;
        } else {
          // Create a new qty=1 line with the new snapshot.
          final TransactionLine newLine = await _transactionRepository.addLine(
            transactionId: transactionId,
            productId: initialContext.line.productId,
            quantity: 1,
          );
          await _transactionRepository.replaceMealCustomizationLineSnapshot(
            transactionLineId: newLine.id,
            snapshot: nextSnapshot,
          );
          resultLine = await _transactionRepository.getLineById(newLine.id);
        }
      }

      if (resultLine == null) {
        throw DatabaseException(
          'Edit-one meal customization did not produce a persisted transaction line.',
        );
      }

      _logger.audit(
        eventType: 'meal_customization_line_edit_one',
        entityId: initialContext.line.uuid,
        message: mergedIntoExistingLine
            ? 'Single unit split from grouped line and merged into an existing line.'
            : nextIdentity == previousIdentity
            ? 'Single unit edit produced same identity; re-merged into original line.'
            : 'Single unit split from grouped line and created as new line.',
        metadata: <String, Object?>{
          'transaction_id': transactionId,
          'source_line_id': previousLineId,
          'result_line_id': resultLine.id,
          'source_qty_before': initialContext.line.quantity,
          'source_qty_after': initialContext.line.quantity - 1,
          'identity_changed': nextIdentity != previousIdentity,
          'merged_into_existing_line': mergedIntoExistingLine,
          'previous_identity': previousIdentity,
          'next_identity': nextIdentity,
          if (mergeTargetLineId != null)
            'merge_target_line_id': mergeTargetLineId,
          if (actorUserId != null) 'actor_user_id': actorUserId,
        },
      );

      return resultLine;
    });
  }

  /// Recreates a legacy meal customization line using the new snapshot-backed
  /// system. The legacy line is decremented (or deleted if qty=1) and a new
  /// snapshot-backed line is created through the standard meal customization
  /// path. The legacy line is never mutated in-place.
  Future<TransactionLine> recreateLegacyMealLine({
    required int transactionLineId,
    required MealCustomizationRequest request,
    int? actorUserId,
  }) async {
    return _transactionRepository.runInTransaction(() async {
      final ({
        TransactionLine line,
        TransactionStatus status,
        DateTime transactionUpdatedAt,
      })?
      initialContext = await _transactionRepository.getLineContext(
        transactionLineId,
      );
      if (initialContext == null) {
        throw NotFoundException(
          'Transaction line not found: $transactionLineId',
        );
      }

      if (initialContext.status != TransactionStatus.draft) {
        throw MealCustomizationLineNotEditableException(
          reason: MealCustomizationEditBlockedReason.notDraft,
          transactionLineId: transactionLineId,
          transactionId: initialContext.line.transactionId,
        );
      }

      // Verify this is actually a legacy line.
      final bool isLegacy = await _transactionRepository
          .isLegacyMealCustomizationLine(transactionLineId);
      if (!isLegacy) {
        throw ValidationException(
          'Transaction line $transactionLineId is not a legacy meal customization line. '
          'Use editMealCustomizationLine for snapshot-backed lines.',
        );
      }

      final Product product =
          await _requiredProductRepository.getById(
            initialContext.line.productId,
          ) ??
          (throw NotFoundException(
            'Product not found: ${initialContext.line.productId}',
          ));
      final _MealCustomizationRuntimeContext context =
          await _resolveMealCustomizationRuntimeContext(product);
      final MealCustomizationRequest normalizedRequest = request.copyWith(
        productId: product.id,
        profileId: context.profile.id,
      );
      final MealCustomizationResolvedSnapshot snapshot =
          _mealCustomizationEngine.evaluate(
            profile: context.profile,
            request: normalizedRequest,
          );

      final int transactionId = initialContext.line.transactionId;
      final int legacyLineId = initialContext.line.id;
      final int legacyQuantity = initialContext.line.quantity;

      // Step 1: Decrement or delete the legacy line.
      await _transactionRepository.decrementLineQuantityOrDelete(legacyLineId);

      // Step 2: Create the new snapshot-backed line (or merge).
      final TransactionLine? existingLine = await _transactionRepository
          .findDraftMealCustomizationLineByIdentity(
            transactionId: transactionId,
            productId: product.id,
            customizationKey: snapshot.stableIdentityKey,
          );
      TransactionLine? resultLine;
      bool mergedIntoExistingLine = false;
      if (existingLine != null) {
        await _transactionRepository.incrementLineQuantity(
          transactionLineId: existingLine.id,
          incrementBy: 1,
        );
        resultLine = await _transactionRepository.getLineById(existingLine.id);
        mergedIntoExistingLine = true;
      } else {
        final TransactionLine newLine = await _transactionRepository.addLine(
          transactionId: transactionId,
          productId: product.id,
          quantity: 1,
        );
        await _transactionRepository.replaceMealCustomizationLineSnapshot(
          transactionLineId: newLine.id,
          snapshot: snapshot,
        );
        resultLine = await _transactionRepository.getLineById(newLine.id);
      }

      if (resultLine == null) {
        throw DatabaseException(
          'Legacy meal line recreation did not produce a persisted transaction line.',
        );
      }

      _logger.audit(
        eventType: 'meal_customization_legacy_recreated',
        entityId: initialContext.line.uuid,
        message: mergedIntoExistingLine
            ? 'Legacy meal line recreated and merged into existing snapshot-backed line.'
            : 'Legacy meal line recreated as new snapshot-backed line.',
        metadata: <String, Object?>{
          'transaction_id': transactionId,
          'legacy_line_id': legacyLineId,
          'legacy_quantity_before': legacyQuantity,
          'result_line_id': resultLine.id,
          'merged_into_existing': mergedIntoExistingLine,
          'new_identity': snapshot.stableIdentityKey,
          if (actorUserId != null) 'actor_user_id': actorUserId,
        },
      );

      return resultLine;
    });
  }

  Map<String, int> _buildReasonCounts(
    List<BreakfastClassifiedModifier> modifiers,
  ) {
    final Map<String, int> counts = <String, int>{};
    for (final BreakfastClassifiedModifier modifier in modifiers) {
      if (modifier.chargeReason == ModifierChargeReason.includedChoice &&
          modifier.itemProductId == null) {
        continue;
      }
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

  ProductRepository get _requiredProductRepository {
    final ProductRepository? repository = _productRepository;
    if (repository == null) {
      throw StateError(
        'ProductRepository is required for meal customization order operations.',
      );
    }
    return repository;
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

  MealAdjustmentProfileRepository get _requiredMealAdjustmentProfileRepository {
    final MealAdjustmentProfileRepository? repository =
        _mealAdjustmentProfileRepository;
    if (repository == null) {
      throw StateError(
        'MealAdjustmentProfileRepository is required for meal customization order operations.',
      );
    }
    return repository;
  }

  MealAdjustmentProfileValidationService
  get _requiredMealAdjustmentProfileValidationService {
    final MealAdjustmentProfileValidationService? service =
        _mealAdjustmentProfileValidationService;
    if (service == null) {
      throw StateError(
        'MealAdjustmentProfileValidationService is required for meal customization order operations.',
      );
    }
    return service;
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
        final BreakfastCartSelection? breakfastSelection =
            item.breakfastSelection;
        if (breakfastSelection != null) {
          await addBreakfastSelectionToOrder(
            transactionId: createdTransaction.id,
            productId: item.productId,
            selection: breakfastSelection,
          );
          continue;
        }

        final _StandardProductFlowDecision flowDecision =
            await _decideStandardProductFlow(
              productId: item.productId,
              mealCustomizationRequest: item.mealCustomizationRequest,
            );

        if (flowDecision.kind == _StandardProductFlowKind.mealCustomization) {
          if (item.modifiers.isNotEmpty) {
            throw ValidationException(
              'Flat modifiers cannot be combined with meal customization.',
            );
          }
          await _addMealCustomizationToOrder(
            transactionId: createdTransaction.id,
            context: flowDecision.mealContext!,
            request: item.mealCustomizationRequest,
            quantity: item.quantity,
          );
          continue;
        }

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

  Future<List<BreakfastCookingInstructionRecord>> getLineCookingInstructions(
    int transactionLineId,
  ) {
    return _transactionRepository.getBreakfastCookingInstructionsByLine(
      transactionLineId,
    );
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

  void _ensureBreakfastEditNotStale({
    required DateTime? expectedTransactionUpdatedAt,
    required DateTime actualTransactionUpdatedAt,
    required TransactionLine line,
  }) {
    if (expectedTransactionUpdatedAt == null) {
      return;
    }
    if (!actualTransactionUpdatedAt.isAtSameMomentAs(
      expectedTransactionUpdatedAt,
    )) {
      throw StaleBreakfastEditException(
        transactionLineId: line.id,
        transactionId: line.transactionId,
        expectedUpdatedAt: expectedTransactionUpdatedAt,
        actualUpdatedAt: actualTransactionUpdatedAt,
      );
    }
  }

  void _ensureMealCustomizationLineEditable({
    required TransactionStatus status,
    required TransactionLine line,
  }) {
    switch (status) {
      case TransactionStatus.draft:
        return;
      case TransactionStatus.sent:
        throw MealCustomizationLineNotEditableException(
          reason: MealCustomizationEditBlockedReason.sent,
          transactionLineId: line.id,
          transactionId: line.transactionId,
        );
      case TransactionStatus.paid:
        throw MealCustomizationLineNotEditableException(
          reason: MealCustomizationEditBlockedReason.paid,
          transactionLineId: line.id,
          transactionId: line.transactionId,
        );
      case TransactionStatus.cancelled:
        throw MealCustomizationLineNotEditableException(
          reason: MealCustomizationEditBlockedReason.cancelled,
          transactionLineId: line.id,
          transactionId: line.transactionId,
        );
    }
  }

  void _ensureMealCustomizationEditNotStale({
    required DateTime? expectedTransactionUpdatedAt,
    required DateTime actualTransactionUpdatedAt,
    required TransactionLine line,
  }) {
    if (expectedTransactionUpdatedAt == null) {
      return;
    }
    if (!actualTransactionUpdatedAt.isAtSameMomentAs(
      expectedTransactionUpdatedAt,
    )) {
      throw StaleMealCustomizationEditException(
        transactionLineId: line.id,
        transactionId: line.transactionId,
        expectedUpdatedAt: expectedTransactionUpdatedAt,
        actualUpdatedAt: actualTransactionUpdatedAt,
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

  bool _hasUnsupportedStrictRequestedStateSnapshot(
    List<OrderModifier> modifiers,
  ) {
    for (final OrderModifier modifier in modifiers) {
      if (modifier.action == ModifierAction.choice &&
          modifier.chargeReason == ModifierChargeReason.includedChoice &&
          modifier.itemProductId != null &&
          modifier.sourceGroupId == null) {
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
    for (final BreakfastAddedProductRequest add
        in requestedState.addedProducts) {
      if (baseConfiguration.findCatalogProduct(add.itemProductId) == null) {
        missingProductIds.add(add.itemProductId);
      }
    }
    for (final BreakfastChosenGroupRequest choice
        in requestedState.chosenGroups) {
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
        await configurationRepository.loadCatalogProductsByIds(
          missingProductIds,
        );
    return baseConfiguration.copyWith(
      catalogProductsById: <int, BreakfastCatalogProduct>{
        ...baseConfiguration.catalogProductsById,
        ...extraProducts,
      },
    );
  }

  List<BreakfastEditErrorCode> _validateRequestedExtras({
    required BreakfastSetConfiguration configuration,
    required BreakfastRequestedState currentRequestedState,
    required BreakfastRequestedState nextRequestedState,
  }) {
    final Map<int, int> currentQuantities = <int, int>{
      for (final BreakfastAddedProductRequest add
          in currentRequestedState.addedProducts)
        add.itemProductId: add.quantity,
    };
    final List<BreakfastEditErrorCode> codes = <BreakfastEditErrorCode>[];
    for (final BreakfastAddedProductRequest add
        in nextRequestedState.addedProducts) {
      final int previousQuantity = currentQuantities[add.itemProductId] ?? 0;
      if (add.quantity <= previousQuantity) {
        continue;
      }
      if (!configuration.isExplicitExtraProduct(add.itemProductId)) {
        codes.add(BreakfastEditErrorCode.swapCandidateNotSwapEligible);
      }
    }
    return codes;
  }

  List<BreakfastEditErrorCode> _validateRequiredChoiceTransitions({
    required BreakfastSetConfiguration configuration,
    required BreakfastRequestedState currentRequestedState,
    required BreakfastRequestedState nextRequestedState,
  }) {
    final Map<int, BreakfastChosenGroupRequest> currentChoicesByGroupId =
        <int, BreakfastChosenGroupRequest>{
          for (final BreakfastChosenGroupRequest choice
              in currentRequestedState.chosenGroups)
            choice.groupId: choice,
        };
    final Map<int, BreakfastChosenGroupRequest> nextChoicesByGroupId =
        <int, BreakfastChosenGroupRequest>{
          for (final BreakfastChosenGroupRequest choice
              in nextRequestedState.chosenGroups)
            choice.groupId: choice,
        };
    final Set<BreakfastEditErrorCode> codes = <BreakfastEditErrorCode>{};

    for (final BreakfastChoiceGroupConfig group in configuration.choiceGroups) {
      if (group.minSelect <= 0) {
        continue;
      }
      final BreakfastChosenGroupRequest? currentChoice =
          currentChoicesByGroupId[group.groupId];
      final BreakfastChosenGroupRequest? nextChoice =
          nextChoicesByGroupId[group.groupId];
      final bool hadConcreteSelection =
          currentChoice != null &&
          currentChoice.requestedQuantity > 0 &&
          currentChoice.selectedItemProductId != null;
      final bool removedConcreteSelection =
          nextChoice == null ||
          nextChoice.requestedQuantity <= 0 ||
          nextChoice.selectedItemProductId == null;
      final bool nextIsExplicitNone =
          nextChoice != null &&
          nextChoice.requestedQuantity > 0 &&
          nextChoice.selectedItemProductId == null;
      if (nextIsExplicitNone ||
          (hadConcreteSelection && removedConcreteSelection)) {
        codes.add(BreakfastEditErrorCode.invalidChoiceQuantity);
      }
    }

    return codes.toList(growable: false);
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

  Future<_StandardProductFlowDecision> _decideStandardProductFlow({
    required int productId,
    MealCustomizationRequest? mealCustomizationRequest,
  }) async {
    final ProductRepository? productRepository = _productRepository;
    if (productRepository == null) {
      if (mealCustomizationRequest != null) {
        throw StateError(
          'ProductRepository is required for meal customization checkout requests.',
        );
      }
      return const _StandardProductFlowDecision.plain();
    }

    final Product? product = await productRepository.getById(productId);
    if (product == null) {
      if (mealCustomizationRequest != null) {
        throw NotFoundException('Product not found: $productId');
      }
      return const _StandardProductFlowDecision.plain();
    }

    final int? profileId = product.mealAdjustmentProfileId;
    if (profileId == null) {
      if (mealCustomizationRequest != null) {
        throw ValidationException(
          'Meal customization request requires an assigned meal-adjustment profile.',
        );
      }
      return const _StandardProductFlowDecision.plain();
    }

    final _MealCustomizationRuntimeContext context =
        await _resolveMealCustomizationRuntimeContext(product);
    return _StandardProductFlowDecision.mealCustomization(context);
  }

  Future<_MealCustomizationRuntimeContext>
  _resolveMealCustomizationRuntimeContext(Product product) async {
    return _resolveMealCustomizationRuntimeContextForProfile(
      product,
      profileId: product.mealAdjustmentProfileId!,
    );
  }

  Future<_MealCustomizationRuntimeContext>
  _resolveMealCustomizationRuntimeContextForProfile(
    Product product, {
    required int profileId,
    bool enforceCurrentProductBinding = true,
    bool enforceBreakfastCompatibility = true,
  }) async {
    if (enforceCurrentProductBinding &&
        product.mealAdjustmentProfileId != profileId) {
      throw MealCustomizationRuntimeConfigurationException(
        productId: product.id,
        profileId: profileId,
        detail: 'Assigned meal-adjustment profile does not match the product.',
      );
    }
    final MealAdjustmentProfileRepository repository =
        _requiredMealAdjustmentProfileRepository;
    final MealAdjustmentProfileDraft? draft = await repository.loadProfileDraft(
      profileId,
    );
    if (draft == null) {
      throw MealCustomizationRuntimeConfigurationException(
        productId: product.id,
        profileId: profileId,
        detail: 'Assigned meal-adjustment profile is missing.',
      );
    }
    if (!draft.isActive) {
      throw MealCustomizationRuntimeConfigurationException(
        productId: product.id,
        profileId: profileId,
        detail: 'Assigned meal-adjustment profile is inactive.',
      );
    }

    final MealAdjustmentValidationResult validationResult =
        await _requiredMealAdjustmentProfileValidationService.validateDraft(
          draft,
        );
    if (!validationResult.canSave) {
      throw MealCustomizationRuntimeConfigurationException(
        productId: product.id,
        profileId: profileId,
        detail: validationResult.message,
      );
    }

    if (enforceBreakfastCompatibility) {
      final Set<int> breakfastProductIds = await repository
          .loadBreakfastSemanticProductIds(<int>[product.id]);
      if (breakfastProductIds.contains(product.id)) {
        throw MealCustomizationRuntimeConfigurationException(
          productId: product.id,
          profileId: profileId,
          detail:
              'Breakfast semantic products cannot carry a meal-adjustment profile.',
        );
      }
    }

    return _MealCustomizationRuntimeContext(
      product: product,
      profile: draft.toRuntimeProfile(profileId: profileId),
    );
  }

  Future<TransactionLine> _addMealCustomizationToOrder({
    required int transactionId,
    required _MealCustomizationRuntimeContext context,
    required int quantity,
    MealCustomizationRequest? request,
  }) async {
    if (quantity <= 0) {
      throw ValidationException('Quantity must be greater than zero.');
    }

    final MealCustomizationRequest normalizedRequest =
        (request ??
                MealCustomizationRequest(
                  productId: context.product.id,
                  profileId: context.profile.id,
                ))
            .copyWith(
              productId: context.product.id,
              profileId: context.profile.id,
            );
    if (normalizedRequest.productId != context.product.id) {
      throw ValidationException(
        'Meal customization request product does not match the target product.',
      );
    }

    await _ensureProductAvailableForSale(context.product.id);
    final MealCustomizationResolvedSnapshot snapshot = _mealCustomizationEngine
        .evaluate(profile: context.profile, request: normalizedRequest);
    final TransactionLine? persistedLine = await _transactionRepository
        .runInTransaction(() async {
          final TransactionLine? existingLine = await _transactionRepository
              .findDraftMealCustomizationLineByIdentity(
                transactionId: transactionId,
                productId: context.product.id,
                customizationKey: snapshot.stableIdentityKey,
              );
          if (existingLine != null) {
            await _transactionRepository.incrementLineQuantity(
              transactionLineId: existingLine.id,
              incrementBy: quantity,
            );
            return _transactionRepository.getLineById(existingLine.id);
          }

          final TransactionLine line = await _transactionRepository.addLine(
            transactionId: transactionId,
            productId: context.product.id,
            quantity: quantity,
          );
          await _transactionRepository.replaceMealCustomizationLineSnapshot(
            transactionLineId: line.id,
            snapshot: snapshot,
          );
          return _transactionRepository.getLineById(line.id);
        });

    if (persistedLine == null) {
      throw DatabaseException(
        'Meal customization line persistence did not produce a transaction line.',
      );
    }
    return persistedLine;
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

enum _StandardProductFlowKind { plain, mealCustomization }

class _StandardProductFlowDecision {
  const _StandardProductFlowDecision.plain()
    : kind = _StandardProductFlowKind.plain,
      mealContext = null;

  const _StandardProductFlowDecision.mealCustomization(this.mealContext)
    : kind = _StandardProductFlowKind.mealCustomization;

  final _StandardProductFlowKind kind;
  final _MealCustomizationRuntimeContext? mealContext;
}

class _MealCustomizationRuntimeContext {
  const _MealCustomizationRuntimeContext({
    required this.product,
    required this.profile,
  });

  final Product product;
  final MealAdjustmentProfile profile;
}
