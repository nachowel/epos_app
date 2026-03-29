import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/errors/exceptions.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/checkout_item.dart';
import '../../domain/models/checkout_modifier.dart';
import '../../domain/models/open_order_summary.dart';
import '../../domain/models/order_modifier.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/payment_adjustment.dart';
import '../../domain/models/print_job.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/transaction_line.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';
import 'cart_models.dart';
import 'cart_provider.dart';

class OrderDetailLine {
  const OrderDetailLine({required this.line, required this.modifiers});

  final TransactionLine line;
  final List<OrderModifier> modifiers;
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
      final List<OrderDetailLine> detailLines = await Future.wait(
        lines.map((TransactionLine line) async {
          final List<OrderModifier> modifiers = await _ref
              .read(orderServiceProvider)
              .getLineModifiers(line.id);
          return OrderDetailLine(line: line, modifiers: modifiers);
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
    return items
        .map((CartItem item) {
          return CheckoutItem(
            productId: item.productId,
            quantity: item.quantity,
            modifiers: item.modifiers
                .map(
                  (CartModifier modifier) => CheckoutModifier(
                    action: modifier.action,
                    itemName: modifier.itemName,
                    extraPriceMinor: modifier.extraPriceMinor,
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }
}

final StateNotifierProvider<OrdersNotifier, OrdersState>
ordersNotifierProvider = StateNotifierProvider<OrdersNotifier, OrdersState>(
  (Ref ref) => OrdersNotifier(ref),
);

const Object _unset = Object();
