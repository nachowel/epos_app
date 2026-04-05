import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/services/meal_customization_persistence_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealCustomizationPersistenceMapper', () {
    const MealCustomizationPersistenceMapper mapper =
        MealCustomizationPersistenceMapper();

    test('maps semantic snapshot to deterministic order modifier rows', () {
      final MealCustomizationPersistenceProjection projection =
          mapper.mapSnapshot(
            transactionLineId: 77,
            snapshot: const MealCustomizationResolvedSnapshot(
              productId: 500,
              profileId: 10,
              resolvedComponentActions: <MealCustomizationSemanticAction>[
                MealCustomizationSemanticAction(
                  action: MealCustomizationAction.remove,
                  componentKey: 'side',
                  itemProductId: 203,
                  quantity: 1,
                ),
                MealCustomizationSemanticAction(
                  action: MealCustomizationAction.swap,
                  chargeReason: MealCustomizationChargeReason.paidSwap,
                  componentKey: 'main',
                  itemProductId: 202,
                  sourceItemProductId: 201,
                  quantity: 1,
                  priceDeltaMinor: 50,
                ),
              ],
              resolvedExtraActions: <MealCustomizationSemanticAction>[
                MealCustomizationSemanticAction(
                  action: MealCustomizationAction.extra,
                  chargeReason: MealCustomizationChargeReason.extraAdd,
                  itemProductId: 401,
                  quantity: 2,
                  priceDeltaMinor: 100,
                ),
              ],
              triggeredDiscounts: <MealCustomizationSemanticAction>[
                MealCustomizationSemanticAction(
                  action: MealCustomizationAction.discount,
                  chargeReason: MealCustomizationChargeReason.comboDiscount,
                  quantity: 1,
                  priceDeltaMinor: -75,
                  appliedRuleIds: <int>[900],
                ),
              ],
              appliedRules: <MealCustomizationAppliedRule>[
                MealCustomizationAppliedRule(
                  ruleId: 900,
                  ruleType: MealAdjustmentPricingRuleType.combo,
                  priceDeltaMinor: -75,
                  specificityScore: 2,
                  priority: 10,
                  conditionKeys: <String>[
                    'removed_component:side:1',
                    'extra_item:401:2',
                  ],
                ),
              ],
              totalAdjustmentMinor: 75,
              paidSwapCountUsed: 1,
            ),
            productNamesById: const <int, String>{
              201: 'Chicken Fillet',
              202: 'Beef Patty',
              203: 'Fries',
              401: 'Cheese',
            },
            createUuid: _UuidSequence().next,
          );

      expect(projection.modifierTotalMinor, 75);
      expect(projection.appliedRuleIds, <int>[900]);
      expect(projection.modifiers, hasLength(5));

      expect(
        projection.modifiers.map((OrderModifier row) => row.action),
        <ModifierAction>[
          ModifierAction.remove,
          ModifierAction.remove,
          ModifierAction.add,
          ModifierAction.add,
          ModifierAction.add,
        ],
      );
      expect(
        projection.modifiers.map((OrderModifier row) => row.itemName),
        <String>[
          'Fries',
          'Chicken Fillet',
          'Beef Patty',
          'Cheese',
          'Meal combo discount',
        ],
      );
      expect(
        projection.modifiers.map((OrderModifier row) => row.chargeReason),
        <ModifierChargeReason?>[
          null,
          null,
          ModifierChargeReason.paidSwap,
          ModifierChargeReason.extraAdd,
          ModifierChargeReason.comboDiscount,
        ],
      );
      expect(
        projection.modifiers.map((OrderModifier row) => row.priceEffectMinor),
        <int>[0, 0, 50, 100, -75],
      );
      expect(
        projection.modifiers.map((OrderModifier row) => row.sortKey),
        <int>[10, 20, 30, 40, 50],
      );
    });
  });
}

class _UuidSequence {
  int _value = 0;

  String next() {
    _value += 1;
    return 'uuid-$_value';
  }
}
