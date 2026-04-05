import 'checkout_modifier.dart';
import 'breakfast_cart_selection.dart';
import 'meal_customization.dart';

class CheckoutItem {
  const CheckoutItem({
    required this.productId,
    required this.quantity,
    required this.modifiers,
    this.breakfastSelection,
    this.mealCustomizationRequest,
  });

  final int productId;
  final int quantity;
  final List<CheckoutModifier> modifiers;
  final BreakfastCartSelection? breakfastSelection;
  final MealCustomizationRequest? mealCustomizationRequest;

  CheckoutItem copyWith({
    int? productId,
    int? quantity,
    List<CheckoutModifier>? modifiers,
    Object? breakfastSelection = _unsetBreakfastSelection,
    Object? mealCustomizationRequest = _unsetMealCustomizationRequest,
  }) {
    return CheckoutItem(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
      breakfastSelection:
          identical(breakfastSelection, _unsetBreakfastSelection)
          ? this.breakfastSelection
          : breakfastSelection as BreakfastCartSelection?,
      mealCustomizationRequest:
          identical(mealCustomizationRequest, _unsetMealCustomizationRequest)
          ? this.mealCustomizationRequest
          : mealCustomizationRequest as MealCustomizationRequest?,
    );
  }
}

const Object _unsetBreakfastSelection = Object();
const Object _unsetMealCustomizationRequest = Object();
