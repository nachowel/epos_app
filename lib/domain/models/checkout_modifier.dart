import 'order_modifier.dart';

class CheckoutModifier {
  const CheckoutModifier({
    required this.action,
    required this.itemName,
    required this.extraPriceMinor,
  });

  final ModifierAction action;
  final String itemName;
  final int extraPriceMinor;

  CheckoutModifier copyWith({
    ModifierAction? action,
    String? itemName,
    int? extraPriceMinor,
  }) {
    return CheckoutModifier(
      action: action ?? this.action,
      itemName: itemName ?? this.itemName,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
    );
  }
}
