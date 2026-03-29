import 'checkout_modifier.dart';

class CheckoutItem {
  const CheckoutItem({
    required this.productId,
    required this.quantity,
    required this.modifiers,
  });

  final int productId;
  final int quantity;
  final List<CheckoutModifier> modifiers;

  CheckoutItem copyWith({
    int? productId,
    int? quantity,
    List<CheckoutModifier>? modifiers,
  }) {
    return CheckoutItem(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
    );
  }
}
