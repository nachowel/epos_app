import 'checkout_modifier.dart';
import 'breakfast_cart_selection.dart';
import 'custom_sale.dart';
import 'meal_customization.dart';

class CheckoutItem {
  const CheckoutItem({
    required this.productId,
    required this.quantity,
    required this.modifiers,
    this.breakfastSelection,
    this.mealCustomizationRequest,
    this.customSaleRequest,
  });

  final int productId;
  final int quantity;
  final List<CheckoutModifier> modifiers;
  final BreakfastCartSelection? breakfastSelection;
  final MealCustomizationRequest? mealCustomizationRequest;
  final CustomSaleWriteRequest? customSaleRequest;

  CheckoutItem copyWith({
    int? productId,
    int? quantity,
    List<CheckoutModifier>? modifiers,
    Object? breakfastSelection = _unsetBreakfastSelection,
    Object? mealCustomizationRequest = _unsetMealCustomizationRequest,
    Object? customSaleRequest = _unsetCustomSaleRequest,
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
      customSaleRequest: identical(customSaleRequest, _unsetCustomSaleRequest)
          ? this.customSaleRequest
          : customSaleRequest as CustomSaleWriteRequest?,
    );
  }
}

const Object _unsetBreakfastSelection = Object();
const Object _unsetMealCustomizationRequest = Object();
const Object _unsetCustomSaleRequest = Object();
