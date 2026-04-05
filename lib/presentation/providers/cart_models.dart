import '../../domain/models/breakfast_cart_selection.dart';
import '../../domain/models/meal_customization.dart';
import '../../domain/models/order_modifier.dart';

class CartModifier {
  const CartModifier({
    required this.action,
    required this.itemName,
    required this.extraPriceMinor,
  });

  final ModifierAction action;
  final String itemName;
  final int extraPriceMinor;

  CartModifier copyWith({
    ModifierAction? action,
    String? itemName,
    int? extraPriceMinor,
  }) {
    return CartModifier(
      action: action ?? this.action,
      itemName: itemName ?? this.itemName,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
    );
  }
}

class CartItem {
  const CartItem({
    required this.localId,
    required this.productId,
    required this.productName,
    required this.unitPriceMinor,
    required this.hasModifiers,
    required this.quantity,
    required this.modifiers,
    this.breakfastSelection,
    this.mealCustomizationSelection,
  });

  final String localId;
  final int productId;
  final String productName;
  final int unitPriceMinor;
  final bool hasModifiers;
  final int quantity;
  final List<CartModifier> modifiers;
  final BreakfastCartSelection? breakfastSelection;
  final MealCustomizationCartSelection? mealCustomizationSelection;

  int get subtotalMinor => unitPriceMinor * quantity;
  int get modifierTotalMinor {
    final BreakfastCartSelection? selection = breakfastSelection;
    if (selection != null) {
      return selection.modifierTotalMinor * quantity;
    }
    final MealCustomizationCartSelection? mealSelection =
        mealCustomizationSelection;
    if (mealSelection != null) {
      return mealSelection.perUnitAdjustmentMinor * quantity;
    }
    return modifiers.fold<int>(
          0,
          (int sum, CartModifier m) => sum + m.extraPriceMinor,
        ) *
        quantity;
  }

  int get totalMinor {
    final BreakfastCartSelection? selection = breakfastSelection;
    if (selection != null) {
      return selection.lineTotalMinor * quantity;
    }
    final MealCustomizationCartSelection? mealSelection =
        mealCustomizationSelection;
    if (mealSelection != null) {
      return mealSelection.perUnitLineTotalMinor * quantity;
    }
    return subtotalMinor + modifierTotalMinor;
  }

  CartItem copyWith({
    String? localId,
    int? productId,
    String? productName,
    int? unitPriceMinor,
    bool? hasModifiers,
    int? quantity,
    List<CartModifier>? modifiers,
    Object? breakfastSelection = _unsetBreakfastSelection,
    Object? mealCustomizationSelection = _unsetMealCustomizationSelection,
  }) {
    return CartItem(
      localId: localId ?? this.localId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
      hasModifiers: hasModifiers ?? this.hasModifiers,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
      breakfastSelection:
          identical(breakfastSelection, _unsetBreakfastSelection)
          ? this.breakfastSelection
          : breakfastSelection as BreakfastCartSelection?,
      mealCustomizationSelection:
          identical(
            mealCustomizationSelection,
            _unsetMealCustomizationSelection,
          )
          ? this.mealCustomizationSelection
          : mealCustomizationSelection as MealCustomizationCartSelection?,
    );
  }
}

const Object _unsetBreakfastSelection = Object();
const Object _unsetMealCustomizationSelection = Object();
