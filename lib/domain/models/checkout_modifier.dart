import 'order_modifier.dart';
import 'product_modifier.dart';

class CheckoutModifier {
  const CheckoutModifier({
    required this.action,
    required this.itemName,
    required this.extraPriceMinor,
    this.priceBehavior,
    this.uiSection,
  });

  final ModifierAction action;
  final String itemName;
  final int extraPriceMinor;
  final ModifierPriceBehavior? priceBehavior;
  final ModifierUiSection? uiSection;

  CheckoutModifier copyWith({
    ModifierAction? action,
    String? itemName,
    int? extraPriceMinor,
    Object? priceBehavior = _unsetField,
    Object? uiSection = _unsetField,
  }) {
    return CheckoutModifier(
      action: action ?? this.action,
      itemName: itemName ?? this.itemName,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
      priceBehavior: identical(priceBehavior, _unsetField)
          ? this.priceBehavior
          : priceBehavior as ModifierPriceBehavior?,
      uiSection: identical(uiSection, _unsetField)
          ? this.uiSection
          : uiSection as ModifierUiSection?,
    );
  }
}

const Object _unsetField = Object();
