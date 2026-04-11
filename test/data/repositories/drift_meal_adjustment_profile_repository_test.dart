import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/drift_meal_adjustment_profile_repository.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/repositories/meal_adjustment_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('DriftMealAdjustmentProfileRepository', () {
    test('duplicate component keys are rejected by schema', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _Fixture fixture = await _seedFixture(db);

      await db
          .into(db.mealAdjustmentProfileComponents)
          .insert(
            app_db.MealAdjustmentProfileComponentsCompanion.insert(
              profileId: fixture.profileId,
              componentKey: 'main',
              displayName: 'Main',
              defaultItemProductId: fixture.defaultProductId,
            ),
          );

      await expectLater(
        db
            .into(db.mealAdjustmentProfileComponents)
            .insert(
              app_db.MealAdjustmentProfileComponentsCompanion.insert(
                profileId: fixture.profileId,
                componentKey: 'main',
                displayName: 'Duplicate Main',
                defaultItemProductId: fixture.swapProductId,
              ),
            ),
        throwsException,
      );
    });

    test('invalid pricing rule conditions are rejected by schema', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _Fixture fixture = await _seedFixture(db);

      final int ruleId = await db
          .into(db.mealAdjustmentPricingRules)
          .insert(
            app_db.MealAdjustmentPricingRulesCompanion.insert(
              profileId: fixture.profileId,
              name: 'Broken remove rule',
              ruleType: 'remove_only',
              priceDeltaMinor: -100,
            ),
          );

      await expectLater(
        db
            .into(db.mealAdjustmentPricingRuleConditions)
            .insert(
              app_db.MealAdjustmentPricingRuleConditionsCompanion.insert(
                ruleId: ruleId,
                conditionType: 'removed_component',
                componentKey: const Value<String?>('main'),
                itemProductId: Value<int?>(fixture.swapProductId),
              ),
            ),
        throwsException,
      );
    });

    test(
      'getProfileById returns nested components, swaps, extras, and rules',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _Fixture fixture = await _seedFixture(db);
        final DriftMealAdjustmentProfileRepository repository =
            DriftMealAdjustmentProfileRepository(db);

        final int componentId = await db
            .into(db.mealAdjustmentProfileComponents)
            .insert(
              app_db.MealAdjustmentProfileComponentsCompanion.insert(
                profileId: fixture.profileId,
                componentKey: 'main',
                displayName: 'Main',
                defaultItemProductId: fixture.defaultProductId,
                quantity: const Value<int>(1),
                canRemove: const Value<bool>(true),
                sortOrder: const Value<int>(0),
              ),
            );
        await db
            .into(db.mealAdjustmentComponentOptions)
            .insert(
              app_db.MealAdjustmentComponentOptionsCompanion.insert(
                profileComponentId: componentId,
                optionItemProductId: fixture.swapProductId,
                optionType: 'swap',
                fixedPriceDeltaMinor: const Value<int?>(null),
                sortOrder: const Value<int>(0),
              ),
            );
        await db
            .into(db.mealAdjustmentProfileExtras)
            .insert(
              app_db.MealAdjustmentProfileExtrasCompanion.insert(
                profileId: fixture.profileId,
                itemProductId: fixture.extraProductId,
                fixedPriceDeltaMinor: 175,
                sortOrder: const Value<int>(0),
              ),
            );
        final int ruleId = await db
            .into(db.mealAdjustmentPricingRules)
            .insert(
              app_db.MealAdjustmentPricingRulesCompanion.insert(
                profileId: fixture.profileId,
                name: 'Combo Discount',
                ruleType: 'combo',
                priceDeltaMinor: -50,
                priority: const Value<int>(1),
              ),
            );
        await db
            .into(db.mealAdjustmentPricingRuleConditions)
            .insert(
              app_db.MealAdjustmentPricingRuleConditionsCompanion.insert(
                ruleId: ruleId,
                conditionType: 'swap_to_item',
                componentKey: const Value<String?>('main'),
                itemProductId: Value<int?>(fixture.swapProductId),
                quantity: const Value<int>(1),
              ),
            );

        final MealAdjustmentProfile? profile = await repository.getProfileById(
          fixture.profileId,
        );

        expect(profile, isNotNull);
        expect(profile!.components, hasLength(1));
        expect(profile.components.single.componentKey, 'main');
        expect(profile.components.single.swapOptions, hasLength(1));
        expect(
          profile.components.single.swapOptions.single.optionItemProductId,
          fixture.swapProductId,
        );
        expect(profile.extraOptions, hasLength(1));
        expect(
          profile.extraOptions.single.itemProductId,
          fixture.extraProductId,
        );
        expect(profile.pricingRules, hasLength(1));
        expect(
          profile.pricingRules.single.ruleType,
          MealAdjustmentPricingRuleType.combo,
        );
        expect(profile.pricingRules.single.conditions, hasLength(1));
        expect(
          profile.pricingRules.single.conditions.single.conditionType,
          MealAdjustmentPricingRuleConditionType.swapToItem,
        );
      },
    );

    test('assignProfileToProduct supports nullable clearing', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _Fixture fixture = await _seedFixture(db);
      final DriftMealAdjustmentProfileRepository repository =
          DriftMealAdjustmentProfileRepository(db);

      expect(
        await repository.assignProfileToProduct(
          productId: fixture.boundProductId,
          profileId: fixture.profileId,
        ),
        isTrue,
      );
      expect(
        (await repository.loadProductSummariesByIds(<int>[
          fixture.boundProductId,
        ]))[fixture.boundProductId]?.mealAdjustmentProfileId,
        fixture.profileId,
      );

      expect(
        await repository.assignProfileToProduct(
          productId: fixture.boundProductId,
          profileId: null,
        ),
        isTrue,
      );
      expect(
        (await repository.loadProductSummariesByIds(<int>[
          fixture.boundProductId,
        ]))[fixture.boundProductId]?.mealAdjustmentProfileId,
        isNull,
      );
    });

    test('loadProfileDraft returns nested draft structure', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _Fixture fixture = await _seedFixture(db);
      final DriftMealAdjustmentProfileRepository repository =
          DriftMealAdjustmentProfileRepository(db);

      await repository.saveProfileDraft(
        MealAdjustmentProfileDraft(
          id: fixture.profileId,
          name: 'Burger Meal Profile',
          description: 'Standard burger meal',
          freeSwapLimit: 1,
          isActive: true,
          components: <MealAdjustmentComponentDraft>[
            MealAdjustmentComponentDraft(
              componentKey: 'main',
              displayName: 'Main',
              defaultItemProductId: fixture.defaultProductId,
              quantity: 1,
              canRemove: true,
              sortOrder: 0,
              isActive: true,
              swapOptions: <MealAdjustmentComponentOptionDraft>[
                MealAdjustmentComponentOptionDraft(
                  optionItemProductId: fixture.swapProductId,
                  fixedPriceDeltaMinor: 25,
                  sortOrder: 0,
                  isActive: true,
                ),
              ],
            ),
          ],
          extraOptions: <MealAdjustmentExtraOptionDraft>[
            MealAdjustmentExtraOptionDraft(
              itemProductId: fixture.extraProductId,
              fixedPriceDeltaMinor: 175,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
      );

      final MealAdjustmentProfileDraft? draft = await repository
          .loadProfileDraft(fixture.profileId);

      expect(draft, isNotNull);
      expect(
        draft!.components.single.swapOptions.single.optionItemProductId,
        fixture.swapProductId,
      );
      expect(draft.extraOptions.single.itemProductId, fixture.extraProductId);
    });

    test('listProductsByProfile returns products using a profile', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _Fixture fixture = await _seedFixture(db);
      final DriftMealAdjustmentProfileRepository repository =
          DriftMealAdjustmentProfileRepository(db);

      await repository.assignProfileToProduct(
        productId: fixture.boundProductId,
        profileId: fixture.profileId,
      );

      final List<MealAdjustmentProductSummary> products = await repository
          .listProductsByProfile(fixture.profileId);

      expect(products, hasLength(1));
      expect(products.single.id, fixture.boundProductId);
    });

    test(
      'loadBreakfastSemanticRootProductIds returns only semantic root products',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final DriftMealAdjustmentProfileRepository repository =
            DriftMealAdjustmentProfileRepository(db);

        final int breakfastCategoryId = await insertCategory(
          db,
          name: 'Set Breakfast',
        );
        final int sandwichesCategoryId = await insertCategory(
          db,
          name: 'Sandwiches',
        );
        final int jacketCategoryId = await insertCategory(
          db,
          name: 'Jacket Potatoes',
        );
        final int breakfastRootId = await insertProduct(
          db,
          categoryId: breakfastCategoryId,
          name: 'Set Breakfast',
          priceMinor: 650,
        );
        final int breakfastMemberId = await insertProduct(
          db,
          categoryId: breakfastCategoryId,
          name: 'Tea',
          priceMinor: 0,
        );
        final int choiceMemberId = await insertProduct(
          db,
          categoryId: breakfastCategoryId,
          name: 'Coffee',
          priceMinor: 0,
        );
        final int sandwichItemId = await insertProduct(
          db,
          categoryId: sandwichesCategoryId,
          name: 'Cheese',
          priceMinor: 0,
        );
        final int unrelatedRootId = await insertProduct(
          db,
          categoryId: jacketCategoryId,
          name: 'Jacket Potato',
          priceMinor: 550,
        );

        await db
            .into(db.setItems)
            .insert(
              app_db.SetItemsCompanion.insert(
                productId: breakfastRootId,
                itemProductId: breakfastMemberId,
                sortOrder: const Value<int>(0),
              ),
            );
        final int groupId = await db
            .into(db.modifierGroups)
            .insert(
              app_db.ModifierGroupsCompanion.insert(
                productId: breakfastRootId,
                name: 'Drink',
                minSelect: const Value<int>(1),
                maxSelect: const Value<int>(1),
                includedQuantity: const Value<int>(1),
                sortOrder: const Value<int>(0),
              ),
            );
        await db
            .into(db.productModifiers)
            .insert(
              app_db.ProductModifiersCompanion.insert(
                productId: breakfastRootId,
                groupId: Value<int?>(groupId),
                itemProductId: Value<int?>(choiceMemberId),
                name: 'Coffee',
                type: 'choice',
                extraPriceMinor: const Value<int>(0),
                isActive: const Value<bool>(true),
              ),
            );
        await db
            .into(db.productModifiers)
            .insert(
              app_db.ProductModifiersCompanion.insert(
                productId: unrelatedRootId,
                itemProductId: Value<int?>(sandwichItemId),
                name: 'Cheese',
                type: 'extra',
                extraPriceMinor: const Value<int>(0),
                isActive: const Value<bool>(true),
              ),
            );

        final Set<int> semanticRootIds = await repository
            .loadBreakfastSemanticRootProductIds(<int>[
              breakfastRootId,
              breakfastMemberId,
              choiceMemberId,
              sandwichItemId,
            ]);

        expect(semanticRootIds, <int>{breakfastRootId});
      },
    );

    test('sandwich profile kind round-trips through repository', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _Fixture fixture = await _seedFixture(db);
      final DriftMealAdjustmentProfileRepository repository =
          DriftMealAdjustmentProfileRepository(db);

      await repository.saveProfileDraft(
        MealAdjustmentProfileDraft(
          id: fixture.profileId,
          name: 'Sandwich Profile',
          description: 'Sandwich flow',
          kind: MealAdjustmentProfileKind.sandwich,
          sandwichSettings: SandwichProfileSettings(
            sandwichSurchargeMinor: 125,
            baguetteSurchargeMinor: 215,
            sauceProductIds: <int>[
              fixture.mayoSauceProductId,
              fixture.chilliSauceProductId,
            ],
          ),
          freeSwapLimit: 0,
          isActive: true,
          extraOptions: <MealAdjustmentExtraOptionDraft>[
            MealAdjustmentExtraOptionDraft(
              itemProductId: fixture.extraProductId,
              fixedPriceDeltaMinor: 175,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
      );

      final MealAdjustmentProfile? profile = await repository.getProfileById(
        fixture.profileId,
      );
      final MealAdjustmentProfileDraft? draft = await repository
          .loadProfileDraft(fixture.profileId);

      expect(profile?.kind, MealAdjustmentProfileKind.sandwich);
      expect(profile?.sandwichSettings.sandwichSurchargeMinor, 125);
      expect(profile?.sandwichSettings.baguetteSurchargeMinor, 215);
      expect(profile?.sandwichSettings.sauceProductIds, <int>[
        fixture.mayoSauceProductId,
        fixture.chilliSauceProductId,
      ]);
      expect(draft?.kind, MealAdjustmentProfileKind.sandwich);
      expect(draft?.sandwichSettings.sandwichSurchargeMinor, 125);
      expect(draft?.sandwichSettings.baguetteSurchargeMinor, 215);
      expect(draft?.sandwichSettings.sauceProductIds, <int>[
        fixture.mayoSauceProductId,
        fixture.chilliSauceProductId,
      ]);
    });
  });
}

Future<_Fixture> _seedFixture(app_db.AppDatabase db) async {
  final int mainsCategoryId = await insertCategory(db, name: 'Mains');
  final int extrasCategoryId = await insertCategory(db, name: 'Sides');
  final int saucesCategoryId = await insertCategory(db, name: 'Sauces');

  final int defaultProductId = await insertProduct(
    db,
    categoryId: mainsCategoryId,
    name: 'Chicken',
    priceMinor: 900,
  );
  final int swapProductId = await insertProduct(
    db,
    categoryId: mainsCategoryId,
    name: 'Beef',
    priceMinor: 1050,
  );
  final int extraProductId = await insertProduct(
    db,
    categoryId: extrasCategoryId,
    name: 'Onion Rings',
    priceMinor: 175,
  );
  final int mayoSauceProductId = await insertProduct(
    db,
    categoryId: saucesCategoryId,
    name: 'Mayonnaise',
    priceMinor: 0,
  );
  final int chilliSauceProductId = await insertProduct(
    db,
    categoryId: saucesCategoryId,
    name: 'Chilli Sauce',
    priceMinor: 0,
  );
  final int boundProductId = await insertProduct(
    db,
    categoryId: mainsCategoryId,
    name: 'Burger Meal',
    priceMinor: 1295,
  );
  final int profileId = await db
      .into(db.mealAdjustmentProfiles)
      .insert(
        app_db.MealAdjustmentProfilesCompanion.insert(
          name: 'Burger Meal Profile',
          description: const Value<String?>('Standard burger meal'),
          freeSwapLimit: const Value<int>(1),
        ),
      );

  return _Fixture(
    profileId: profileId,
    boundProductId: boundProductId,
    defaultProductId: defaultProductId,
    swapProductId: swapProductId,
    extraProductId: extraProductId,
    mayoSauceProductId: mayoSauceProductId,
    chilliSauceProductId: chilliSauceProductId,
  );
}

class _Fixture {
  const _Fixture({
    required this.profileId,
    required this.boundProductId,
    required this.defaultProductId,
    required this.swapProductId,
    required this.extraProductId,
    required this.mayoSauceProductId,
    required this.chilliSauceProductId,
  });

  final int profileId;
  final int boundProductId;
  final int defaultProductId;
  final int swapProductId;
  final int extraProductId;
  final int mayoSauceProductId;
  final int chilliSauceProductId;
}
