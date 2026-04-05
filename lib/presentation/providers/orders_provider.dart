import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/errors/exceptions.dart';
import '../../core/providers/app_providers.dart';
import '../../data/repositories/breakfast_configuration_repository.dart';
import '../../domain/models/breakfast_line_edit.dart';
import '../../domain/models/breakfast_cooking_instruction.dart';
import '../../domain/models/breakfast_rebuild.dart';
import '../../domain/models/checkout_item.dart';
import '../../domain/models/checkout_modifier.dart';
import '../../domain/models/meal_customization.dart';
import '../../domain/models/open_order_summary.dart';
import '../../domain/models/order_modifier.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/payment_adjustment.dart';
import '../../domain/models/print_job.dart';
import '../../domain/models/product.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/transaction_line.dart';
import '../../domain/models/user.dart';
import '../../domain/services/breakfast_requested_state_mapper.dart';
import '../../domain/services/meal_customization_pos_service.dart';
import '../../domain/services/order_service.dart';
import 'auth_provider.dart';
import 'cart_models.dart';
import 'cart_provider.dart';

class OrderDetailLine {
  const OrderDetailLine({
    required this.line,
    required this.modifiers,
    this.isBreakfastConfigurable = false,
    this.isMealCustomizationConfigurable = false,
    this.isLegacyMealCustomizationLine = false,
    this.mealCustomizationLegacyMessage,
  });

  final TransactionLine line;
  final List<OrderModifier> modifiers;
  final bool isBreakfastConfigurable;
  final bool isMealCustomizationConfigurable;
  final bool isLegacyMealCustomizationLine;
  final String? mealCustomizationLegacyMessage;
}

class OrderDetails {
  const OrderDetails({
    required this.transaction,
    required this.payment,
    required this.paymentAdjustment,
    required this.lines,
    required this.kitchenPrintJob,
    required this.receiptPrintJob,
  });

  final Transaction transaction;
  final Payment? payment;
  final PaymentAdjustment? paymentAdjustment;
  final List<OrderDetailLine> lines;
  final PrintJob? kitchenPrintJob;
  final PrintJob? receiptPrintJob;
}

class BreakfastAddableProduct {
  const BreakfastAddableProduct({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.sortKey,
    required this.isChoiceCapable,
    required this.isSwapEligible,
  });

  final int id;
  final String name;
  final int priceMinor;
  final int sortKey;
  final bool isChoiceCapable;
  final bool isSwapEligible;
}

class BreakfastEditorData {
  const BreakfastEditorData({
    required this.transaction,
    required this.line,
    required this.modifiers,
    required this.configuration,
    required this.requestedState,
    required this.addableProducts,
  });

  final Transaction transaction;
  final TransactionLine line;
  final List<OrderModifier> modifiers;
  final BreakfastSetConfiguration configuration;
  final BreakfastRequestedState requestedState;
  final List<BreakfastAddableProduct> addableProducts;
}

class MealCustomizationOrderEditorData {
  const MealCustomizationOrderEditorData({
    required this.transaction,
    required this.line,
    required this.product,
    required this.rehydration,
    required this.editorData,
  });

  final Transaction transaction;
  final TransactionLine line;
  final Product product;
  final MealCustomizationRehydrationResult rehydration;
  final MealCustomizationPosEditorData editorData;
}

class OrdersState {
  const OrdersState({
    required this.openOrders,
    required this.openOrderSummaries,
    required this.lineCountByOrderId,
    required this.selectedOrderId,
    required this.isRefreshing,
    required this.isCheckoutLoading,
    required this.isPaymentLoading,
    required this.isCancelLoading,
    required this.isPrintLoading,
    required this.isTableUpdateLoading,
    required this.errorMessage,
  });

  const OrdersState.initial()
    : openOrders = const <Transaction>[],
      openOrderSummaries = const <OpenOrderSummary>[],
      lineCountByOrderId = const <int, int>{},
      selectedOrderId = null,
      isRefreshing = false,
      isCheckoutLoading = false,
      isPaymentLoading = false,
      isCancelLoading = false,
      isPrintLoading = false,
      isTableUpdateLoading = false,
      errorMessage = null;

  final List<Transaction> openOrders;
  final List<OpenOrderSummary> openOrderSummaries;
  final Map<int, int> lineCountByOrderId;
  final int? selectedOrderId;
  final bool isRefreshing;
  final bool isCheckoutLoading;
  final bool isPaymentLoading;
  final bool isCancelLoading;
  final bool isPrintLoading;
  final bool isTableUpdateLoading;
  final String? errorMessage;

  bool get isBusy =>
      isRefreshing ||
      isCheckoutLoading ||
      isPaymentLoading ||
      isCancelLoading ||
      isPrintLoading ||
      isTableUpdateLoading;

  OrdersState copyWith({
    List<Transaction>? openOrders,
    List<OpenOrderSummary>? openOrderSummaries,
    Map<int, int>? lineCountByOrderId,
    Object? selectedOrderId = _unset,
    bool? isRefreshing,
    bool? isCheckoutLoading,
    bool? isPaymentLoading,
    bool? isCancelLoading,
    bool? isPrintLoading,
    bool? isTableUpdateLoading,
    Object? errorMessage = _unset,
  }) {
    return OrdersState(
      openOrders: openOrders ?? this.openOrders,
      openOrderSummaries: openOrderSummaries ?? this.openOrderSummaries,
      lineCountByOrderId: lineCountByOrderId ?? this.lineCountByOrderId,
      selectedOrderId: selectedOrderId == _unset
          ? this.selectedOrderId
          : selectedOrderId as int?,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCheckoutLoading: isCheckoutLoading ?? this.isCheckoutLoading,
      isPaymentLoading: isPaymentLoading ?? this.isPaymentLoading,
      isCancelLoading: isCancelLoading ?? this.isCancelLoading,
      isPrintLoading: isPrintLoading ?? this.isPrintLoading,
      isTableUpdateLoading: isTableUpdateLoading ?? this.isTableUpdateLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier(this._ref, {Uuid? uuidGenerator})
    : _uuidGenerator = uuidGenerator ?? const Uuid(),
      super(const OrdersState.initial()) {
    refreshOpenOrders();
  }

  final Ref _ref;
  final Uuid _uuidGenerator;
  String? _pendingIdempotencyKey;

  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: true, errorMessage: null);
    try {
      final activeShift = await _ref
          .read(shiftSessionServiceProvider)
          .getBackendOpenShift();
      if (activeShift == null) {
        state = state.copyWith(
          openOrders: const <Transaction>[],
          openOrderSummaries: const <OpenOrderSummary>[],
          lineCountByOrderId: const <int, int>{},
          selectedOrderId: null,
          isRefreshing: false,
          errorMessage: null,
        );
        return;
      }

      final List<OpenOrderSummary> openOrderSummaries = await _ref
          .read(orderServiceProvider)
          .getOrderSummariesByShift(activeShift.id);
      final List<Transaction> openOrders = openOrderSummaries
          .map((OpenOrderSummary summary) => summary.transaction)
          .toList(growable: false);
      final Map<int, int> lineCountByOrderId = <int, int>{
        for (final OpenOrderSummary summary in openOrderSummaries)
          summary.transaction.id: summary.itemCount,
      };

      final int? selected = state.selectedOrderId;
      state = state.copyWith(
        openOrders: openOrders,
        openOrderSummaries: openOrderSummaries,
        lineCountByOrderId: lineCountByOrderId,
        selectedOrderId:
            selected == null ||
                !openOrders.any((Transaction t) => t.id == selected)
            ? (openOrders.isEmpty ? null : openOrders.first.id)
            : selected,
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'orders_refresh_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void selectOrder(int? transactionId) {
    state = state.copyWith(selectedOrderId: transactionId);
  }

  Future<Transaction?> createOrderFromCart({
    required User currentUser,
    int? tableNumber,
    PaymentMethod? immediatePaymentMethod,
  }) async {
    if (state.isCheckoutLoading) {
      return null;
    }

    final List<CartItem> cartItems = _ref.read(cartNotifierProvider).items;
    if (cartItems.isEmpty) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessage(EmptyCartException()),
      );
      return null;
    }

    state = state.copyWith(isCheckoutLoading: true, errorMessage: null);
    _pendingIdempotencyKey ??= _uuidGenerator.v4();
    try {
      final Transaction transaction = await _ref
          .read(checkoutServiceProvider)
          .checkoutCart(
            currentUser: currentUser,
            tableNumber: tableNumber,
            cartItems: _toCheckoutItems(cartItems),
            idempotencyKey: _pendingIdempotencyKey!,
            immediatePaymentMethod: immediatePaymentMethod,
          );

      _pendingIdempotencyKey = null;
      _ref.read(cartNotifierProvider.notifier).clearCart();
      _ref.read(mealInsightsServiceProvider).invalidateSuggestionCache();
      await refreshOpenOrders();
      state = state.copyWith(
        selectedOrderId: transaction.id,
        isCheckoutLoading: false,
        errorMessage: null,
      );
      return transaction;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isCheckoutLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'order_checkout_failed',
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  Future<bool> payOrder({
    required int transactionId,
    required PaymentMethod method,
    required User currentUser,
  }) async {
    if (state.isPaymentLoading) {
      return false;
    }
    state = state.copyWith(isPaymentLoading: true, errorMessage: null);
    try {
      await _ref
          .read(paymentServiceProvider)
          .payOrder(
            transactionId: transactionId,
            method: method,
            currentUser: currentUser,
          );
      await refreshOpenOrders();
      state = state.copyWith(isPaymentLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isPaymentLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'order_payment_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> sendOrder({
    required int transactionId,
    required User currentUser,
  }) async {
    if (state.isCheckoutLoading) {
      return false;
    }
    state = state.copyWith(isCheckoutLoading: true, errorMessage: null);
    try {
      await _ref
          .read(orderServiceProvider)
          .sendOrder(transactionId: transactionId, currentUser: currentUser);
      await refreshOpenOrders();
      state = state.copyWith(isCheckoutLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isCheckoutLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'order_send_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> cancelOrder({
    required int transactionId,
    required User currentUser,
  }) async {
    if (state.isCancelLoading) {
      return false;
    }
    state = state.copyWith(isCancelLoading: true, errorMessage: null);
    try {
      await _ref
          .read(orderServiceProvider)
          .cancelOrder(transactionId: transactionId, currentUser: currentUser);
      await refreshOpenOrders();
      state = state.copyWith(isCancelLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isCancelLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'order_cancel_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> discardDraft({
    required int transactionId,
    required User currentUser,
  }) async {
    if (state.isCancelLoading) {
      return false;
    }
    state = state.copyWith(isCancelLoading: true, errorMessage: null);
    try {
      await _ref
          .read(orderServiceProvider)
          .discardDraft(transactionId: transactionId, currentUser: currentUser);
      await refreshOpenOrders();
      state = state.copyWith(isCancelLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isCancelLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'order_discard_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> reprintKitchen(int transactionId) async {
    if (state.isPrintLoading) {
      return false;
    }
    state = state.copyWith(isPrintLoading: true, errorMessage: null);
    try {
      await _ref
          .read(printerServiceProvider)
          .printKitchenTicket(transactionId, allowReprint: true);
      await refreshOpenOrders();
      state = state.copyWith(isPrintLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isPrintLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'kitchen_reprint_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> reprintReceipt(int transactionId) async {
    if (state.isPrintLoading) {
      return false;
    }
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }
    state = state.copyWith(isPrintLoading: true, errorMessage: null);
    try {
      await _ref
          .read(printerServiceProvider)
          .printReceipt(
            transactionId,
            allowReprint: true,
            actorUserId: currentUser.id,
          );
      await refreshOpenOrders();
      state = state.copyWith(isPrintLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isPrintLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'receipt_reprint_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<OrderDetails?> getOrderDetails(int transactionId) async {
    try {
      final BreakfastConfigurationRepository breakfastConfigurationRepository =
          _ref.read(breakfastConfigurationRepositoryProvider);
      final Transaction? transaction = await _ref
          .read(orderServiceProvider)
          .getOrderById(transactionId);
      if (transaction == null) {
        state = state.copyWith(
          errorMessage: ErrorMapper.toUserMessage(
            NotFoundException('Transaction not found: $transactionId'),
          ),
        );
        return null;
      }

      final List<TransactionLine> lines = await _ref
          .read(orderServiceProvider)
          .getOrderLines(transactionId);
      final transactionRepository = _ref.read(transactionRepositoryProvider);
      final List<OrderDetailLine> detailLines = await Future.wait(
        lines.map((TransactionLine line) async {
          final List<OrderModifier> modifiers = await _ref
              .read(orderServiceProvider)
              .getLineModifiers(line.id);
          final MealCustomizationPersistedSnapshotRecord? mealSnapshot =
              await transactionRepository.getMealCustomizationSnapshotByLine(
                line.id,
              );
          final bool isLegacyMealCustomizationLine =
              mealSnapshot == null &&
              await transactionRepository.isLegacyMealCustomizationLine(line.id);
          final bool isBreakfastConfigurable =
              transaction.status == TransactionStatus.draft &&
              await breakfastConfigurationRepository.hasSetConfiguration(
                line.productId,
              );
          final bool isMealCustomizationConfigurable =
              transaction.status == TransactionStatus.draft &&
              mealSnapshot != null;
          return OrderDetailLine(
            line: line,
            modifiers: modifiers,
            isBreakfastConfigurable: isBreakfastConfigurable,
            isMealCustomizationConfigurable: isMealCustomizationConfigurable,
            isLegacyMealCustomizationLine: isLegacyMealCustomizationLine,
            mealCustomizationLegacyMessage: isLegacyMealCustomizationLine
                ? 'This item was created before the new system and cannot be edited.'
                : null,
          );
        }),
      );
      final List<PrintJob> printJobs = await _ref
          .read(printJobRepositoryProvider)
          .getByTransactionId(transactionId);
      final Payment? payment = await _ref
          .read(paymentRepositoryProvider)
          .getByTransactionId(transactionId);
      final PaymentAdjustment? paymentAdjustment = payment == null
          ? null
          : await _ref
                .read(paymentAdjustmentRepositoryProvider)
                .getByPaymentId(payment.id);
      PrintJob? kitchenPrintJob;
      PrintJob? receiptPrintJob;
      for (final PrintJob job in printJobs) {
        if (job.target == PrintJobTarget.kitchen) {
          kitchenPrintJob = job;
        } else if (job.target == PrintJobTarget.receipt) {
          receiptPrintJob = job;
        }
      }

      return OrderDetails(
        transaction: transaction,
        payment: payment,
        paymentAdjustment: paymentAdjustment,
        lines: detailLines,
        kitchenPrintJob: kitchenPrintJob,
        receiptPrintJob: receiptPrintJob,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'order_detail_load_failed',
          stackTrace: stackTrace,
        ),
      );
      return null;
    }
  }

  Future<bool> updateTableNumber({
    required int transactionId,
    required int? tableNumber,
  }) async {
    if (state.isTableUpdateLoading) {
      return false;
    }

    state = state.copyWith(isTableUpdateLoading: true, errorMessage: null);
    try {
      await _ref
          .read(orderServiceProvider)
          .updateTableNumber(
            transactionId: transactionId,
            tableNumber: tableNumber,
          );
      await refreshOpenOrders();
      state = state.copyWith(isTableUpdateLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isTableUpdateLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'order_table_update_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  Future<BreakfastEditorData?> loadBreakfastEditorData({
    required int transactionId,
    required int transactionLineId,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      return await _buildBreakfastEditorData(
        transactionId: transactionId,
        transactionLineId: transactionLineId,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'breakfast_editor_load_failed',
          stackTrace: stackTrace,
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'transaction_line_id': transactionLineId,
          },
        ),
      );
      return null;
    }
  }

  Future<BreakfastEditorData?> editBreakfastLine({
    required int transactionId,
    required int transactionLineId,
    required BreakfastLineEdit edit,
    required DateTime expectedTransactionUpdatedAt,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      final TransactionLine updatedLine = await _ref
          .read(orderServiceProvider)
          .editBreakfastLine(
            transactionLineId: transactionLineId,
            edit: edit,
            expectedTransactionUpdatedAt: expectedTransactionUpdatedAt,
          );
      return await _buildBreakfastEditorData(
        transactionId: transactionId,
        transactionLineId: updatedLine.id,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'breakfast_editor_apply_failed',
          stackTrace: stackTrace,
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'transaction_line_id': transactionLineId,
            'edit_type': edit.type.name,
            'item_product_id': edit.itemProductId,
            'group_id': edit.groupId,
            'selected_item_product_id': edit.selectedItemProductId,
            'quantity': edit.quantity,
          },
        ),
      );
      return null;
    }
  }

  Future<MealCustomizationOrderEditorData?> loadMealCustomizationEditorData({
    required int transactionId,
    required int transactionLineId,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      final orderService = _ref.read(orderServiceProvider);
      final Transaction? transaction = await orderService.getOrderById(
        transactionId,
      );
      if (transaction == null) {
        throw NotFoundException('Transaction not found: $transactionId');
      }
      final TransactionLine line = await _requireOrderLine(
        orderService: orderService,
        transactionId: transactionId,
        transactionLineId: transactionLineId,
      );
      final transactionRepository = _ref.read(transactionRepositoryProvider);
      final MealCustomizationPersistedSnapshotRecord? snapshotRecord =
          await transactionRepository.getMealCustomizationSnapshotByLine(
            line.id,
          );
      if (snapshotRecord == null) {
        throw MealCustomizationLineNotEditableException(
          reason: MealCustomizationEditBlockedReason.legacySnapshotMissing,
          transactionLineId: line.id,
          transactionId: transaction.id,
        );
      }

      final Product product =
          await _ref.read(productRepositoryProvider).getById(line.productId) ??
          (throw NotFoundException('Product not found: ${line.productId}'));
      final MealCustomizationPosService posService = _ref.read(
        mealCustomizationPosServiceProvider,
      );
      final MealCustomizationRehydrationResult rehydration = posService
          .rehydrateSnapshot(
            snapshot: snapshotRecord.snapshot,
            lineQuantity: line.quantity,
          );
      final MealCustomizationPosEditorData editorData =
          await posService.loadEditorDataForPersistedProfile(
            product: product,
            profileId: snapshotRecord.profileId,
            initialState: rehydration.editorState,
          );
      return MealCustomizationOrderEditorData(
        transaction: transaction,
        line: line,
        product: product,
        rehydration: rehydration,
        editorData: editorData,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'meal_customization_editor_load_failed',
          stackTrace: stackTrace,
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'transaction_line_id': transactionLineId,
          },
        ),
      );
      return null;
    }
  }

  Future<TransactionLine?> editMealCustomizationLine({
    required int transactionId,
    required int transactionLineId,
    required MealCustomizationRequest request,
    required DateTime expectedTransactionUpdatedAt,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      return await _ref
          .read(orderServiceProvider)
          .editMealCustomizationLine(
            transactionLineId: transactionLineId,
            request: request,
            expectedTransactionUpdatedAt: expectedTransactionUpdatedAt,
          );
    } on StaleMealCustomizationEditException {
      rethrow;
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'meal_customization_editor_apply_failed',
          stackTrace: stackTrace,
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'transaction_line_id': transactionLineId,
            'product_id': request.productId,
            'profile_id': request.profileId,
          },
        ),
      );
      return null;
    }
  }

  Future<TransactionLine?> editOneMealCustomizationLine({
    required int transactionId,
    required int transactionLineId,
    required MealCustomizationRequest request,
    required DateTime expectedTransactionUpdatedAt,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      return await _ref
          .read(orderServiceProvider)
          .editOneMealCustomizationLine(
            transactionLineId: transactionLineId,
            request: request,
            expectedTransactionUpdatedAt: expectedTransactionUpdatedAt,
          );
    } on StaleMealCustomizationEditException {
      rethrow;
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'meal_customization_edit_one_failed',
          stackTrace: stackTrace,
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'transaction_line_id': transactionLineId,
            'product_id': request.productId,
            'profile_id': request.profileId,
          },
        ),
      );
      return null;
    }
  }

  Future<TransactionLine?> recreateLegacyMealLine({
    required int transactionId,
    required int transactionLineId,
    required MealCustomizationRequest request,
  }) async {
    state = state.copyWith(errorMessage: null);
    try {
      return await _ref
          .read(orderServiceProvider)
          .recreateLegacyMealLine(
            transactionLineId: transactionLineId,
            request: request,
          );
    } catch (error, stackTrace) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'meal_customization_legacy_recreate_failed',
          stackTrace: stackTrace,
          metadata: <String, Object?>{
            'transaction_id': transactionId,
            'transaction_line_id': transactionLineId,
            'product_id': request.productId,
          },
        ),
      );
      return null;
    }
  }

  Future<Product?> loadProductForRecreate(int productId) async {
    try {
      return await _ref.read(productRepositoryProvider).getById(productId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> refundOrder({
    required int transactionId,
    required String reason,
    required User currentUser,
  }) async {
    if (state.isPaymentLoading) {
      return false;
    }
    state = state.copyWith(isPaymentLoading: true, errorMessage: null);
    try {
      await _ref
          .read(paymentServiceProvider)
          .refundOrder(
            transactionId: transactionId,
            reason: reason,
            currentUser: currentUser,
          );
      await refreshOpenOrders();
      state = state.copyWith(isPaymentLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isPaymentLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'order_refund_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  List<CheckoutItem> _toCheckoutItems(List<CartItem> items) {
    final List<CheckoutItem> checkoutItems = <CheckoutItem>[];
    for (final CartItem item in items) {
      final CheckoutItem baseItem = CheckoutItem(
        productId: item.productId,
        quantity: 1,
        modifiers: item.modifiers
            .map(
              (CartModifier modifier) => CheckoutModifier(
                action: modifier.action,
                itemName: modifier.itemName,
                extraPriceMinor: modifier.extraPriceMinor,
              ),
            )
            .toList(growable: false),
        breakfastSelection: item.breakfastSelection,
        mealCustomizationRequest: item.mealCustomizationSelection?.request,
      );
      if (item.breakfastSelection != null) {
        for (int index = 0; index < item.quantity; index += 1) {
          checkoutItems.add(baseItem);
        }
        continue;
      }
      checkoutItems.add(baseItem.copyWith(quantity: item.quantity));
    }
    return checkoutItems;
  }

  Future<BreakfastEditorData> _buildBreakfastEditorData({
    required int transactionId,
    required int transactionLineId,
  }) async {
    final orderService = _ref.read(orderServiceProvider);
    final Transaction? transaction = await orderService.getOrderById(
      transactionId,
    );
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }

    TransactionLine? line;
    final List<TransactionLine> lines = await orderService.getOrderLines(
      transactionId,
    );
    for (final TransactionLine candidate in lines) {
      if (candidate.id == transactionLineId) {
        line = candidate;
        break;
      }
    }
    if (line == null) {
      throw NotFoundException('Transaction line not found: $transactionLineId');
    }

    final BreakfastConfigurationRepository configurationRepository = _ref.read(
      breakfastConfigurationRepositoryProvider,
    );
    final BreakfastSetConfiguration? baseConfiguration =
        await configurationRepository.loadSetConfiguration(line.productId);
    if (baseConfiguration == null) {
      throw ValidationException('Breakfast configuration is unavailable.');
    }

    final List<OrderModifier> modifiers = await orderService.getLineModifiers(
      line.id,
    );
    final List<BreakfastCookingInstructionRecord> cookingInstructions =
        await orderService.getLineCookingInstructions(line.id);
    final BreakfastSetConfiguration configuration =
        await _augmentBreakfastConfiguration(
          configurationRepository: configurationRepository,
          baseConfiguration: baseConfiguration,
          modifiers: modifiers,
        );
    final BreakfastRequestedState requestedState =
        BreakfastRequestedStateMapper.fromPersistedSnapshot(
          modifiers: modifiers,
          cookingInstructions: cookingInstructions
              .map(
                (BreakfastCookingInstructionRecord instruction) =>
                    BreakfastCookingInstructionRequest(
                      itemProductId: instruction.itemProductId,
                      instructionCode: instruction.instructionCode,
                      instructionLabel: instruction.instructionLabel,
                    ),
              )
              .toList(growable: false),
        );

    return BreakfastEditorData(
      transaction: transaction,
      line: line,
      modifiers: modifiers,
      configuration: configuration,
      requestedState: requestedState,
      addableProducts: _buildBreakfastAddableProducts(
        configuration: configuration,
      ),
    );
  }

  Future<TransactionLine> _requireOrderLine({
    required OrderService orderService,
    required int transactionId,
    required int transactionLineId,
  }) async {
    final List<TransactionLine> lines = await orderService.getOrderLines(
      transactionId,
    );
    for (final TransactionLine candidate in lines) {
      if (candidate.id == transactionLineId) {
        return candidate;
      }
    }
    throw NotFoundException('Transaction line not found: $transactionLineId');
  }

  Future<BreakfastSetConfiguration> _augmentBreakfastConfiguration({
    required BreakfastConfigurationRepository configurationRepository,
    required BreakfastSetConfiguration baseConfiguration,
    required List<OrderModifier> modifiers,
  }) async {
    final Set<int> missingProductIds = <int>{};
    for (final OrderModifier modifier in modifiers) {
      final int? itemProductId = modifier.itemProductId;
      if (itemProductId != null &&
          baseConfiguration.findCatalogProduct(itemProductId) == null) {
        missingProductIds.add(itemProductId);
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

  List<BreakfastAddableProduct> _buildBreakfastAddableProducts({
    required BreakfastSetConfiguration configuration,
  }) {
    final List<BreakfastAddableProduct> products = configuration.extras
        .map((BreakfastExtraItemConfig extra) {
          final BreakfastCatalogProduct? product = configuration
              .findCatalogProduct(extra.itemProductId);
          if (product == null) {
            return null;
          }
          return BreakfastAddableProduct(
            id: product.id,
            name: product.name,
            priceMinor: product.priceMinor,
            sortKey: extra.sortOrder,
            isChoiceCapable: configuration.choiceCapableProductIds.contains(
              product.id,
            ),
            isSwapEligible: configuration.swapEligibleProductIds.contains(
              product.id,
            ),
          );
        })
        .whereType<BreakfastAddableProduct>()
        .toList(growable: true);

    products.sort((BreakfastAddableProduct a, BreakfastAddableProduct b) {
      final int sortCompare = a.sortKey.compareTo(b.sortKey);
      if (sortCompare != 0) {
        return sortCompare;
      }
      return a.name.compareTo(b.name);
    });
    return products;
  }
}

final StateNotifierProvider<OrdersNotifier, OrdersState>
ordersNotifierProvider = StateNotifierProvider<OrdersNotifier, OrdersState>(
  (Ref ref) => OrdersNotifier(ref),
);

const Object _unset = Object();
