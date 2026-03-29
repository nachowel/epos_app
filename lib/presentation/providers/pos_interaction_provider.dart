import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/interaction_block_reason.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/product.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';
import 'cart_provider.dart';
import 'cart_models.dart';
import 'orders_provider.dart';
import 'shift_provider.dart';

class PosInteractionPolicy {
  const PosInteractionPolicy({
    required this.effectiveShiftStatus,
    required this.blockReason,
    required this.canInteractWithPos,
    required this.canMutateCart,
    required this.canOpenModifierDialog,
    required this.isSalesLocked,
    required this.lockMessage,
    required this.canCreateOrder,
    required this.canTakePayment,
    required this.canClearCart,
    required this.isCheckoutBusy,
  });

  final ShiftStatus effectiveShiftStatus;
  final InteractionBlockReason? blockReason;
  final bool canInteractWithPos;
  final bool canMutateCart;
  final bool canOpenModifierDialog;
  final bool isSalesLocked;
  final String? lockMessage;
  final bool canCreateOrder;
  final bool canTakePayment;
  final bool canClearCart;
  final bool isCheckoutBusy;

  bool get isInteractionLocked => !canInteractWithPos;
}

final Provider<PosInteractionPolicy> posInteractionProvider =
    Provider<PosInteractionPolicy>((Ref ref) {
      final AuthState authState = ref.watch(authNotifierProvider);
      final ShiftState shiftState = ref.watch(shiftNotifierProvider);
      final CartState cartState = ref.watch(cartNotifierProvider);
      final OrdersState ordersState = ref.watch(ordersNotifierProvider);

      final InteractionBlockReason? blockReason;
      if (authState.currentUser == null) {
        blockReason = InteractionBlockReason.unauthenticated;
      } else {
        switch (shiftState.effectiveShiftStatus) {
          case ShiftStatus.open:
            blockReason = null;
          case ShiftStatus.closed:
            blockReason = InteractionBlockReason.noOpenShift;
          case ShiftStatus.locked:
            blockReason = InteractionBlockReason.adminFinalCloseRequired;
        }
      }

      final bool canInteractWithPos = blockReason == null;
      final bool hasItems = !cartState.isEmpty;
      final bool isCheckoutBusy =
          ordersState.isCheckoutLoading || ordersState.isPaymentLoading;

      return PosInteractionPolicy(
        effectiveShiftStatus: shiftState.effectiveShiftStatus,
        blockReason: blockReason,
        canInteractWithPos: canInteractWithPos,
        canMutateCart: canInteractWithPos,
        canOpenModifierDialog: canInteractWithPos,
        isSalesLocked:
            blockReason == InteractionBlockReason.adminFinalCloseRequired,
        lockMessage: blockReason?.operatorMessage,
        canCreateOrder: canInteractWithPos && hasItems && !ordersState.isBusy,
        canTakePayment: canInteractWithPos && hasItems && !ordersState.isBusy,
        canClearCart: canInteractWithPos && hasItems && !isCheckoutBusy,
        isCheckoutBusy: isCheckoutBusy,
      );
    });

/// Existing cart contents remain visible but frozen when the shift closes
/// or an admin final close is required. We intentionally do not clear the
/// cart automatically to avoid silent data loss during runtime transitions.
class PosInteractionController {
  const PosInteractionController(this._ref);

  final Ref _ref;

  PosInteractionPolicy get _policy => _ref.read(posInteractionProvider);

  String? get currentBlockMessage => _policy.lockMessage;

  bool addProduct(
    Product product, {
    int quantity = 1,
    List<CartModifier> modifiers = const <CartModifier>[],
  }) {
    if (!_policy.canMutateCart) {
      return false;
    }

    _ref
        .read(cartNotifierProvider.notifier)
        .addProduct(product, quantity: quantity, modifiers: modifiers);
    return true;
  }

  bool increaseQuantity(String localId) {
    if (!_policy.canMutateCart) {
      return false;
    }

    _ref.read(cartNotifierProvider.notifier).increaseQuantity(localId);
    return true;
  }

  bool decreaseQuantity(String localId) {
    if (!_policy.canMutateCart) {
      return false;
    }

    _ref.read(cartNotifierProvider.notifier).decreaseQuantity(localId);
    return true;
  }

  bool removeItem(String localId) {
    if (!_policy.canMutateCart) {
      return false;
    }

    _ref.read(cartNotifierProvider.notifier).removeItem(localId);
    return true;
  }

  bool replaceModifiers({
    required String localId,
    required List<CartModifier> modifiers,
  }) {
    if (!_policy.canMutateCart) {
      return false;
    }

    _ref
        .read(cartNotifierProvider.notifier)
        .replaceModifiers(localId: localId, modifiers: modifiers);
    return true;
  }

  bool clearCart() {
    if (!_policy.canMutateCart) {
      return false;
    }

    _ref.read(cartNotifierProvider.notifier).clearCart();
    return true;
  }

  Future<Transaction?> createOrderFromCart({
    required User currentUser,
    int? tableNumber,
  }) async {
    if (!_policy.canCreateOrder) {
      return null;
    }

    return _ref
        .read(ordersNotifierProvider.notifier)
        .createOrderFromCart(
          currentUser: currentUser,
          tableNumber: tableNumber,
        );
  }

  Future<Transaction?> payNowFromCart({
    required User currentUser,
    required PaymentMethod method,
  }) async {
    if (!_policy.canTakePayment) {
      return null;
    }

    return _ref
        .read(ordersNotifierProvider.notifier)
        .createOrderFromCart(
          currentUser: currentUser,
          immediatePaymentMethod: method,
        );
  }
}

final Provider<PosInteractionController> posInteractionControllerProvider =
    Provider<PosInteractionController>(
      (Ref ref) => PosInteractionController(ref),
    );
