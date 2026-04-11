import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/models/meal_pricing_explanation.dart';
import 'package:epos_app/domain/services/meal_pricing_explanation_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealPricingExplanationBuilder', () {
    const MealPricingExplanationBuilder builder =
        MealPricingExplanationBuilder();

    test('keeps remove lines for priced combo and emits single combo line', () {
      final List<PricingExplanationLine> lines = builder.build(
        snapshot: const MealCustomizationResolvedSnapshot(
          productId: 1,
          profileId: 10,
          resolvedComponentActions: <MealCustomizationSemanticAction>[
            MealCustomizationSemanticAction(
              action: MealCustomizationAction.remove,
              componentKey: 'beans',
              itemProductId: 101,
            ),
            MealCustomizationSemanticAction(
              action: MealCustomizationAction.remove,
              componentKey: 'chips',
              itemProductId: 102,
            ),
          ],
          appliedRules: <MealCustomizationAppliedRule>[
            MealCustomizationAppliedRule(
              ruleId: 9,
              ruleType: MealAdjustmentPricingRuleType.combo,
              priceDeltaMinor: -200,
              specificityScore: 2002,
              priority: 20,
              conditionKeys: <String>[
                'removedComponent|beans||1',
                'removedComponent|chips||1',
              ],
            ),
          ],
        ),
        productNamesById: const <int, String>{101: 'Beans', 102: 'Chips'},
      );

      expect(lines, const <PricingExplanationLine>[
        PricingExplanationLine(
          label: 'No Beans',
          priceEffectMinor: -200,
          type: 'remove',
        ),
        PricingExplanationLine(
          label: 'No Chips',
          priceEffectMinor: -200,
          type: 'remove',
        ),
        PricingExplanationLine(
          label: 'Beans + Chips removed (-£2.00)',
          priceEffectMinor: -200,
          type: 'combo',
        ),
      ]);
    });

    test('filters zero extra lines but keeps zero swap lines', () {
      final List<PricingExplanationLine> lines = builder.build(
        snapshot: const MealCustomizationResolvedSnapshot(
          productId: 1,
          profileId: 10,
          resolvedComponentActions: <MealCustomizationSemanticAction>[
            MealCustomizationSemanticAction(
              action: MealCustomizationAction.swap,
              componentKey: 'beans',
              itemProductId: 201,
              sourceItemProductId: 101,
              priceDeltaMinor: 0,
            ),
          ],
          resolvedExtraActions: <MealCustomizationSemanticAction>[
            MealCustomizationSemanticAction(
              action: MealCustomizationAction.extra,
              itemProductId: 301,
              priceDeltaMinor: 0,
            ),
          ],
        ),
        productNamesById: const <int, String>{
          101: 'Beans',
          201: 'Salad',
          301: 'Cheese',
        },
      );

      expect(lines, const <PricingExplanationLine>[
        PricingExplanationLine(
          label: 'Beans → Salad',
          priceEffectMinor: 0,
          type: 'swap',
        ),
      ]);
    });

    test(
      'falls back to zero-price remove line when it is the only explanation',
      () {
        final List<PricingExplanationLine> lines = builder.build(
          snapshot: const MealCustomizationResolvedSnapshot(
            productId: 1,
            profileId: 10,
            resolvedComponentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.remove,
                componentKey: 'beans',
                itemProductId: 101,
              ),
            ],
          ),
          productNamesById: const <int, String>{101: 'Beans'},
        );

        expect(lines, const <PricingExplanationLine>[
          PricingExplanationLine(
            label: 'No Beans',
            priceEffectMinor: 0,
            type: 'remove',
          ),
        ]);
      },
    );

    test(
      'cart summary keeps zero-price removes and zero-price extras visible',
      () {
        final List<PricingExplanationLine> lines = builder.buildCartSummary(
          snapshot: const MealCustomizationResolvedSnapshot(
            productId: 1,
            profileId: 10,
            resolvedComponentActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.remove,
                componentKey: 'chips',
                itemProductId: 102,
              ),
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.swap,
                componentKey: 'beans',
                itemProductId: 201,
                sourceItemProductId: 101,
                priceDeltaMinor: 0,
              ),
            ],
            resolvedExtraActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.extra,
                itemProductId: 301,
                priceDeltaMinor: 0,
              ),
            ],
          ),
          productNamesById: const <int, String>{
            101: 'Beans',
            102: 'Chips',
            201: 'Salad',
            301: 'Cheese',
          },
        );

        expect(lines, const <PricingExplanationLine>[
          PricingExplanationLine(
            label: 'No Chips',
            priceEffectMinor: 0,
            type: 'remove',
          ),
          PricingExplanationLine(
            label: 'Beans → Salad',
            priceEffectMinor: 0,
            type: 'swap',
          ),
          PricingExplanationLine(
            label: 'Extra Cheese',
            priceEffectMinor: 0,
            type: 'extra',
          ),
        ]);
      },
    );

    test(
      'sandwich cart summary lists multiple sauces before toast and add-ins',
      () {
        final List<PricingExplanationLine> lines = builder.buildCartSummary(
          snapshot: const MealCustomizationResolvedSnapshot(
            productId: 2,
            profileId: 20,
            sandwichSelection: SandwichCustomizationSelection(
              breadType: SandwichBreadType.sandwich,
              sauceProductIds: <int>[501, 502],
              toastOption: SandwichToastOption.toasted,
            ),
            resolvedExtraActions: <MealCustomizationSemanticAction>[
              MealCustomizationSemanticAction(
                action: MealCustomizationAction.extra,
                itemProductId: 301,
                priceDeltaMinor: 100,
              ),
            ],
            totalAdjustmentMinor: 200,
          ),
          productNamesById: const <int, String>{
            301: 'Cheese',
            501: 'Mayonnaise',
            502: 'Chilli Sauce',
          },
        );

        expect(lines, const <PricingExplanationLine>[
          PricingExplanationLine(
            label: 'Mayonnaise',
            priceEffectMinor: 0,
            type: 'choice',
          ),
          PricingExplanationLine(
            label: 'Chilli Sauce',
            priceEffectMinor: 0,
            type: 'choice',
          ),
          PricingExplanationLine(
            label: 'Toasted',
            priceEffectMinor: 0,
            type: 'choice',
          ),
          PricingExplanationLine(
            label: 'Extra Cheese +£1.00',
            priceEffectMinor: 100,
            type: 'extra',
          ),
        ]);
      },
    );
  });
}
