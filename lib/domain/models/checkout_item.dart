import 'checkout_modifier.dart';
import 'breakfast_cart_selection.dart';

class CheckoutItem {
  const CheckoutItem({
    required this.productId,
    required this.quantity,
    required this.modifiers,
    this.breakfastSelection,
  });

  final int productId;
  final int quantity;
  final List<CheckoutModifier> modifiers;
  final BreakfastCartSelection? breakfastSelection;

  CheckoutItem copyWith({
    int? productId,
    int? quantity,
    List<CheckoutModifier>? modifiers,
    Object? breakfastSelection = _unsetBreakfastSelection,
  }) {
    return CheckoutItem(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
      breakfastSelection:
          identical(breakfastSelection, _unsetBreakfastSelection)
          ? this.breakfastSelection
          : breakfastSelection as BreakfastCartSelection?,
    );
  }
}

const Object _unsetBreakfastSelection = Object();
