import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/order_modifier.dart';
import '../../domain/models/product.dart';
import 'cart_models.dart';

class CartState {
  const CartState({required this.items});

  const CartState.initial() : items = const <CartItem>[];

  final List<CartItem> items;

  int get subtotalMinor =>
      items.fold<int>(0, (int sum, CartItem item) => sum + item.subtotalMinor);
  int get modifierTotalMinor => items.fold<int>(
    0,
    (int sum, CartItem item) => sum + item.modifierTotalMinor,
  );
  int get totalMinor => subtotalMinor + modifierTotalMinor;
  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItem>? items}) {
    return CartState(items: items ?? this.items);
  }
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier({Uuid? uuidGenerator})
    : _uuidGenerator = uuidGenerator ?? const Uuid(),
      super(const CartState.initial());

  final Uuid _uuidGenerator;

  void addProduct(
    Product product, {
    int quantity = 1,
    List<CartModifier> modifiers = const <CartModifier>[],
  }) {
    if (quantity <= 0) {
      return;
    }
    _ensureProductAvailableForSale(product);
    final newItem = CartItem(
      localId: _uuidGenerator.v4(),
      productId: product.id,
      productName: product.name,
      unitPriceMinor: product.priceMinor,
      hasModifiers: product.hasModifiers,
      quantity: quantity,
      modifiers: modifiers,
    );
    state = state.copyWith(items: <CartItem>[...state.items, newItem]);
  }

  void removeItem(String localId) {
    state = state.copyWith(
      items: state.items
          .where((CartItem item) => item.localId != localId)
          .toList(),
    );
  }

  void increaseQuantity(String localId) {
    state = state.copyWith(
      items: state.items.map((CartItem item) {
        if (item.localId != localId) {
          return item;
        }
        return item.copyWith(quantity: item.quantity + 1);
      }).toList(),
    );
  }

  void decreaseQuantity(String localId) {
    final List<CartItem> updatedItems = <CartItem>[];
    for (final CartItem item in state.items) {
      if (item.localId != localId) {
        updatedItems.add(item);
        continue;
      }
      final int nextQuantity = item.quantity - 1;
      if (nextQuantity > 0) {
        updatedItems.add(item.copyWith(quantity: nextQuantity));
      }
    }
    state = state.copyWith(items: updatedItems);
  }

  void addModifierToCartLine({
    required String localId,
    required ModifierAction action,
    required String itemName,
    required int extraPriceMinor,
  }) {
    if (extraPriceMinor < 0) {
      return;
    }
    state = state.copyWith(
      items: state.items.map((CartItem item) {
        if (item.localId != localId) {
          return item;
        }
        final CartModifier modifier = CartModifier(
          action: action,
          itemName: itemName,
          extraPriceMinor: extraPriceMinor,
        );
        return item.copyWith(
          modifiers: <CartModifier>[...item.modifiers, modifier],
        );
      }).toList(),
    );
  }

  void replaceModifiers({
    required String localId,
    required List<CartModifier> modifiers,
  }) {
    state = state.copyWith(
      items: state.items
          .map((CartItem item) {
            if (item.localId != localId) {
              return item;
            }
            return item.copyWith(modifiers: modifiers);
          })
          .toList(growable: false),
    );
  }

  void clearCart() {
    state = const CartState.initial();
  }

  void _ensureProductAvailableForSale(Product product) {
    if (!product.isActive || !product.isVisibleOnPos) {
      throw ValidationException('Product is not available for sale.');
    }
  }
}

final StateNotifierProvider<CartNotifier, CartState> cartNotifierProvider =
    StateNotifierProvider<CartNotifier, CartState>((_) => CartNotifier());
