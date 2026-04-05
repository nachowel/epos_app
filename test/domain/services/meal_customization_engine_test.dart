import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/services/meal_customization_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealCustomizationEngine', () {
    const MealCustomizationEngine engine = MealCustomizationEngine();

    test('classifies first two swaps as free then the next as paid', () {
      final MealCustomizationResolvedSnapshot snapshot = engine.evaluate(
        profile: _baseProfile(freeSwapLimit: 2),
        request: const MealCustomizationRequest(
          productId: 500,
          profileId: 10,
          swapSelections: <MealCustomizationComponentSelection>[
            MealCustomizationComponentSelection(
              componentKey: 'drink',
              targetItemProductId: 302,
            ),
            MealCustomizationComponentSelection(
              componentKey: 'main',
              targetItemProductId: 202,
            ),
            MealCustomizationComponentSelection(
              componentKey: 'side',
              targetItemProductId: 204,
            ),
          ],
        ),
      );

      final List<MealCustomizationSemanticAction> swaps = snapshot
          .resolvedComponentActions
          .where((MealCustomizationSemanticAction action) {
            return action.action == MealCustomizationAction.swap;
          })
          .toList(growable: false);

      expect(
        swaps.map(
          (MealCustomizationSemanticAction action) => action.componentKey,
        ),
        <String>['main', 'side', 'drink'],
      );
      expect(
        swaps.map(
          (MealCustomizationSemanticAction action) => action.chargeReason,
        ),
        <MealCustomizationChargeReason>[
          MealCustomizationChargeReason.freeSwap,
          MealCustomizationChargeReason.freeSwap,
          MealCustomizationChargeReason.paidSwap,
        ],
      );
      expect(snapshot.freeSwapCountUsed, 2);
      expect(snapshot.paidSwapCountUsed, 1);
    });

    test('applies additive remove-only discount', () {
      final MealCustomizationResolvedSnapshot snapshot = engine.evaluate(
        profile: _baseProfile(
          pricingRules: const <MealAdjustmentPricingRule>[
            MealAdjustmentPricingRule(
              id: 900,
              profileId: 10,
              name: 'No side discount',
              ruleType: MealAdjustmentPricingRuleType.removeOnly,
              priceDeltaMinor: -50,
              priority: 0,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleCondition>[
                MealAdjustmentPricingRuleCondition(
                  id: 1,
                  ruleId: 900,
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.removedComponent,
                  componentKey: 'side',
                  quantity: 1,
                ),
              ],
            ),
          ],
        ),
        request: const MealCustomizationRequest(
          productId: 500,
          profileId: 10,
          removedComponentKeys: <String>['side'],
        ),
      );

      expect(snapshot.totalAdjustmentMinor, -50);
      expect(snapshot.triggeredDiscounts, hasLength(1));
      expect(
        snapshot.triggeredDiscounts.single.chargeReason,
        MealCustomizationChargeReason.removalDiscount,
      );
    });

    test('exact combo rule overrides additive remove-only rules', () {
      final MealCustomizationResolvedSnapshot snapshot = engine.evaluate(
        profile: _baseProfile(
          pricingRules: const <MealAdjustmentPricingRule>[
            MealAdjustmentPricingRule(
              id: 901,
              profileId: 10,
              name: 'No side discount',
              ruleType: MealAdjustmentPricingRuleType.removeOnly,
              priceDeltaMinor: -50,
              priority: 0,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleCondition>[
                MealAdjustmentPricingRuleCondition(
                  id: 1,
                  ruleId: 901,
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.removedComponent,
                  componentKey: 'side',
                  quantity: 1,
                ),
              ],
            ),
            MealAdjustmentPricingRule(
              id: 902,
              profileId: 10,
              name: 'No side plus bacon combo',
              ruleType: MealAdjustmentPricingRuleType.combo,
              priceDeltaMinor: -100,
              priority: 10,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleCondition>[
                MealAdjustmentPricingRuleCondition(
                  id: 2,
                  ruleId: 902,
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.removedComponent,
                  componentKey: 'side',
                  quantity: 1,
                ),
                MealAdjustmentPricingRuleCondition(
                  id: 3,
                  ruleId: 902,
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.extraItem,
                  itemProductId: 401,
                  quantity: 1,
                ),
              ],
            ),
          ],
        ),
        request: const MealCustomizationRequest(
          productId: 500,
          profileId: 10,
          removedComponentKeys: <String>['side'],
          extraSelections: <MealCustomizationExtraSelection>[
            MealCustomizationExtraSelection(itemProductId: 401, quantity: 1),
          ],
        ),
      );

      expect(snapshot.totalAdjustmentMinor, 75);
      expect(snapshot.triggeredDiscounts, hasLength(1));
      expect(snapshot.triggeredDiscounts.single.appliedRuleIds, <int>[902]);
      expect(snapshot.appliedRuleIds, contains(902));
      expect(snapshot.appliedRuleIds, isNot(contains(901)));
    });

    test('keeps swap and extra semantics separate', () {
      final MealCustomizationResolvedSnapshot snapshot = engine.evaluate(
        profile: _baseProfile(),
        request: const MealCustomizationRequest(
          productId: 500,
          profileId: 10,
          swapSelections: <MealCustomizationComponentSelection>[
            MealCustomizationComponentSelection(
              componentKey: 'main',
              targetItemProductId: 202,
            ),
          ],
          extraSelections: <MealCustomizationExtraSelection>[
            MealCustomizationExtraSelection(itemProductId: 401, quantity: 1),
          ],
        ),
      );

      expect(snapshot.resolvedComponentActions, hasLength(1));
      expect(snapshot.resolvedExtraActions, hasLength(1));
      expect(
        snapshot.resolvedComponentActions.single.action,
        MealCustomizationAction.swap,
      );
      expect(
        snapshot.resolvedExtraActions.single.action,
        MealCustomizationAction.extra,
      );
    });

    test('exact swap rule overrides default swap fixed delta', () {
      final MealCustomizationResolvedSnapshot snapshot = engine.evaluate(
        profile: _baseProfile(
          freeSwapLimit: 0,
          pricingRules: const <MealAdjustmentPricingRule>[
            MealAdjustmentPricingRule(
              id: 903,
              profileId: 10,
              name: 'Premium beef swap',
              ruleType: MealAdjustmentPricingRuleType.swap,
              priceDeltaMinor: 80,
              priority: 0,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleCondition>[
                MealAdjustmentPricingRuleCondition(
                  id: 1,
                  ruleId: 903,
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.swapToItem,
                  componentKey: 'main',
                  itemProductId: 202,
                  quantity: 1,
                ),
              ],
            ),
          ],
        ),
        request: const MealCustomizationRequest(
          productId: 500,
          profileId: 10,
          swapSelections: <MealCustomizationComponentSelection>[
            MealCustomizationComponentSelection(
              componentKey: 'main',
              targetItemProductId: 202,
            ),
          ],
        ),
      );

      expect(snapshot.resolvedComponentActions.single.priceDeltaMinor, 80);
      expect(snapshot.appliedRuleIds, <int>[903]);
    });

    test('free swap limit forces free swap revenue to zero', () {
      final MealCustomizationResolvedSnapshot snapshot = engine.evaluate(
        profile: _baseProfile(freeSwapLimit: 1),
        request: const MealCustomizationRequest(
          productId: 500,
          profileId: 10,
          swapSelections: <MealCustomizationComponentSelection>[
            MealCustomizationComponentSelection(
              componentKey: 'main',
              targetItemProductId: 202,
            ),
          ],
        ),
      );

      expect(snapshot.resolvedComponentActions.single.chargeReason,
          MealCustomizationChargeReason.freeSwap);
      expect(snapshot.resolvedComponentActions.single.priceDeltaMinor, 0);
      expect(snapshot.totalAdjustmentMinor, 0);
    });

    test('exact extra rule overrides fixed extra price', () {
      final MealCustomizationResolvedSnapshot snapshot = engine.evaluate(
        profile: _baseProfile(
          pricingRules: const <MealAdjustmentPricingRule>[
            MealAdjustmentPricingRule(
              id: 904,
              profileId: 10,
              name: 'Cheese promo',
              ruleType: MealAdjustmentPricingRuleType.extra,
              priceDeltaMinor: 90,
              priority: 0,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleCondition>[
                MealAdjustmentPricingRuleCondition(
                  id: 1,
                  ruleId: 904,
                  conditionType:
                      MealAdjustmentPricingRuleConditionType.extraItem,
                  itemProductId: 401,
                  quantity: 1,
                ),
              ],
            ),
          ],
        ),
        request: const MealCustomizationRequest(
          productId: 500,
          profileId: 10,
          extraSelections: <MealCustomizationExtraSelection>[
            MealCustomizationExtraSelection(itemProductId: 401, quantity: 1),
          ],
        ),
      );

      expect(snapshot.resolvedExtraActions.single.priceDeltaMinor, 90);
      expect(snapshot.appliedRuleIds, <int>[904]);
    });

    test('output ordering is deterministic across request ordering', () {
      final MealAdjustmentProfile profile = _baseProfile(freeSwapLimit: 1);
      final MealCustomizationResolvedSnapshot first = engine.evaluate(
        profile: profile,
        request: const MealCustomizationRequest(
          productId: 500,
          profileId: 10,
          removedComponentKeys: <String>['side'],
          swapSelections: <MealCustomizationComponentSelection>[
            MealCustomizationComponentSelection(
              componentKey: 'drink',
              targetItemProductId: 302,
            ),
            MealCustomizationComponentSelection(
              componentKey: 'main',
              targetItemProductId: 202,
            ),
          ],
          extraSelections: <MealCustomizationExtraSelection>[
            MealCustomizationExtraSelection(itemProductId: 402, quantity: 1),
            MealCustomizationExtraSelection(itemProductId: 401, quantity: 1),
          ],
        ),
      );
      final MealCustomizationResolvedSnapshot second = engine.evaluate(
        profile: profile,
        request: const MealCustomizationRequest(
          productId: 500,
          profileId: 10,
          removedComponentKeys: <String>['side'],
          swapSelections: <MealCustomizationComponentSelection>[
            MealCustomizationComponentSelection(
              componentKey: 'main',
              targetItemProductId: 202,
            ),
            MealCustomizationComponentSelection(
              componentKey: 'drink',
              targetItemProductId: 302,
            ),
          ],
          extraSelections: <MealCustomizationExtraSelection>[
            MealCustomizationExtraSelection(itemProductId: 401, quantity: 1),
            MealCustomizationExtraSelection(itemProductId: 402, quantity: 1),
          ],
        ),
      );

      expect(first, second);
    });

    test('rejects invalid request input', () {
      expect(
        () => engine.evaluate(
          profile: _baseProfile(),
          request: const MealCustomizationRequest(
            productId: 500,
            profileId: 10,
            removedComponentKeys: <String>['unknown'],
          ),
        ),
        throwsA(isA<MealCustomizationRequestRejectedException>()),
      );
    });
  });
}

MealAdjustmentProfile _baseProfile({
  int freeSwapLimit = 1,
  List<MealAdjustmentPricingRule> pricingRules =
      const <MealAdjustmentPricingRule>[],
}) {
  return MealAdjustmentProfile(
    id: 10,
    name: 'Combo meal',
    description: 'Standard meal profile',
    freeSwapLimit: freeSwapLimit,
    isActive: true,
    components: const <MealAdjustmentComponent>[
      MealAdjustmentComponent(
        id: 1,
        profileId: 10,
        componentKey: 'main',
        displayName: 'Main',
        defaultItemProductId: 201,
        quantity: 1,
        canRemove: true,
        sortOrder: 0,
        isActive: true,
        swapOptions: <MealAdjustmentComponentOption>[
          MealAdjustmentComponentOption(
            id: 11,
            profileComponentId: 1,
            optionItemProductId: 202,
            fixedPriceDeltaMinor: 25,
            sortOrder: 0,
            isActive: true,
          ),
        ],
      ),
      MealAdjustmentComponent(
        id: 2,
        profileId: 10,
        componentKey: 'side',
        displayName: 'Side',
        defaultItemProductId: 203,
        quantity: 1,
        canRemove: true,
        sortOrder: 1,
        isActive: true,
        swapOptions: <MealAdjustmentComponentOption>[
          MealAdjustmentComponentOption(
            id: 12,
            profileComponentId: 2,
            optionItemProductId: 204,
            fixedPriceDeltaMinor: 0,
            sortOrder: 0,
            isActive: true,
          ),
          MealAdjustmentComponentOption(
            id: 13,
            profileComponentId: 2,
            optionItemProductId: 203,
            fixedPriceDeltaMinor: 0,
            sortOrder: 1,
            isActive: false,
          ),
        ],
      ),
      MealAdjustmentComponent(
        id: 3,
        profileId: 10,
        componentKey: 'drink',
        displayName: 'Drink',
        defaultItemProductId: 301,
        quantity: 1,
        canRemove: true,
        sortOrder: 2,
        isActive: true,
        swapOptions: <MealAdjustmentComponentOption>[
          MealAdjustmentComponentOption(
            id: 14,
            profileComponentId: 3,
            optionItemProductId: 302,
            fixedPriceDeltaMinor: 0,
            sortOrder: 0,
            isActive: true,
          ),
        ],
      ),
    ],
    extraOptions: const <MealAdjustmentExtraOption>[
      MealAdjustmentExtraOption(
        id: 21,
        profileId: 10,
        itemProductId: 401,
        fixedPriceDeltaMinor: 175,
        sortOrder: 0,
        isActive: true,
      ),
      MealAdjustmentExtraOption(
        id: 22,
        profileId: 10,
        itemProductId: 402,
        fixedPriceDeltaMinor: 120,
        sortOrder: 1,
        isActive: true,
      ),
    ],
    pricingRules: pricingRules,
  );
}
