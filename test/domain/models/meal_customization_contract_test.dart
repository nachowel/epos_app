import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Meal customization contract models', () {
    test('request supports remove, swap, and extra intent construction', () {
      const MealCustomizationRequest request = MealCustomizationRequest(
        productId: 10,
        profileId: 5,
        removedComponentKeys: <String>['side'],
        swapSelections: <MealCustomizationComponentSelection>[
          MealCustomizationComponentSelection(
            componentKey: 'main',
            targetItemProductId: 22,
            quantity: 1,
          ),
        ],
        extraSelections: <MealCustomizationExtraSelection>[
          MealCustomizationExtraSelection(itemProductId: 33, quantity: 2),
        ],
      );

      expect(request.productId, 10);
      expect(request.profileId, 5);
      expect(request.removedComponentKeys, <String>['side']);
      expect(request.swapSelections.single.componentKey, 'main');
      expect(request.extraSelections.single.quantity, 2);
    });

    test('editor state carries explicit keep remove swap modes', () {
      const MealCustomizationEditorState editorState =
          MealCustomizationEditorState(
            componentSelections: <MealCustomizationComponentState>[
              MealCustomizationComponentState(
                componentKey: 'main',
                mode: MealComponentSelectionMode.swap,
                swapTargetItemProductId: 22,
              ),
              MealCustomizationComponentState(
                componentKey: 'side',
                mode: MealComponentSelectionMode.remove,
              ),
            ],
            extraSelections: <MealCustomizationExtraSelection>[
              MealCustomizationExtraSelection(itemProductId: 33, quantity: 2),
            ],
          );

      final MealCustomizationRequest request = editorState.toRequest(
        productId: 10,
        profileId: 5,
      );

      expect(
        editorState.selectionForComponent('drink').mode,
        MealComponentSelectionMode.keep,
      );
      expect(request.removedComponentKeys, <String>['side']);
      expect(
        request.swapSelections,
        const <MealCustomizationComponentSelection>[
          MealCustomizationComponentSelection(
            componentKey: 'main',
            targetItemProductId: 22,
            quantity: 1,
          ),
        ],
      );
    });

    test('resolved snapshot and persistence preview stay deterministic', () {
      const MealCustomizationResolvedSnapshot first =
          MealCustomizationResolvedSnapshot(
            productId: 10,
            profileId: 5,
            resolvedComponentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.swap,
                chargeReason: MealCustomizationChargeReason.freeSwap,
                componentKey: 'main',
                itemProductId: 22,
                quantity: 1,
                priceDeltaMinor: 0,
              ),
            ],
            resolvedExtraActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.extra,
                chargeReason: MealCustomizationChargeReason.extraAdd,
                itemProductId: 33,
                quantity: 1,
                priceDeltaMinor: 175,
              ),
            ],
            triggeredDiscounts: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.comboDiscount,
                quantity: 1,
                priceDeltaMinor: -25,
                appliedRuleIds: <int>[99],
              ),
            ],
            appliedRules: <MealCustomizationAppliedRule>[
              MealCustomizationAppliedRule(
                ruleId: 99,
                ruleType: MealAdjustmentPricingRuleType.combo,
                priceDeltaMinor: -25,
                specificityScore: 1001,
                priority: 1,
                conditionKeys: <String>['extraItem||33|1'],
              ),
            ],
            totalAdjustmentMinor: 150,
            freeSwapCountUsed: 1,
            paidSwapCountUsed: 0,
          );
      const MealCustomizationResolvedSnapshot second =
          MealCustomizationResolvedSnapshot(
            productId: 10,
            profileId: 5,
            resolvedComponentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.swap,
                chargeReason: MealCustomizationChargeReason.freeSwap,
                componentKey: 'main',
                itemProductId: 22,
                quantity: 1,
                priceDeltaMinor: 0,
              ),
            ],
            resolvedExtraActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.extra,
                chargeReason: MealCustomizationChargeReason.extraAdd,
                itemProductId: 33,
                quantity: 1,
                priceDeltaMinor: 175,
              ),
            ],
            triggeredDiscounts: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.discount,
                chargeReason: MealCustomizationChargeReason.comboDiscount,
                quantity: 1,
                priceDeltaMinor: -25,
                appliedRuleIds: <int>[99],
              ),
            ],
            appliedRules: <MealCustomizationAppliedRule>[
              MealCustomizationAppliedRule(
                ruleId: 99,
                ruleType: MealAdjustmentPricingRuleType.combo,
                priceDeltaMinor: -25,
                specificityScore: 1001,
                priority: 1,
                conditionKeys: <String>['extraItem||33|1'],
              ),
            ],
            totalAdjustmentMinor: 150,
            freeSwapCountUsed: 1,
            paidSwapCountUsed: 0,
          );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.toPersistencePreview(), second.toPersistencePreview());
      expect(first.toReportingSummary(), second.toReportingSummary());
      expect(first.appliedRuleIds, <int>[99]);
    });

    test('sandwich selection round-trips legacy and multi-sauce json', () {
      final SandwichCustomizationSelection multiSauce =
          SandwichCustomizationSelection.fromJson(<String, Object?>{
            'bread_type': 'sandwich',
            'sauce_product_ids': <int>[401, 402],
            'toast_option': 'toasted',
          });
      final SandwichCustomizationSelection legacySingleSauce =
          SandwichCustomizationSelection.fromJson(<String, Object?>{
            'bread_type': 'roll',
            'sauce_type': 'mayo',
          });

      expect(multiSauce.sauceProductIds, <int>[401, 402]);
      expect(legacySingleSauce.sauceProductIds, isEmpty);
      expect(legacySingleSauce.legacySauceLookupKeys, <String>['mayo']);
      expect(multiSauce.toJson()['sauce_product_ids'], <int>[401, 402]);
    });
  });
}
