import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/drift_meal_adjustment_profile_repository.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/repositories/meal_adjustment_profile_repository.dart';
import 'package:epos_app/domain/services/meal_adjustment_admin_service.dart';
import 'package:epos_app/domain/services/meal_adjustment_profile_validation_service.dart';
import 'package:epos_app/domain/services/meal_customization_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('MealAdjustmentAdminService', () {
    test('computeHealthSummary reports invalid references', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _AdminFixture fixture = await _seedAdminFixture(db);
      final MealAdjustmentAdminService service = _createService(db);

      final MealAdjustmentProfileHealthSummary summary = await service
          .computeHealthSummary(
            MealAdjustmentProfileDraft(
              id: fixture.profileId,
              name: 'Broken profile',
              freeSwapLimit: 1,
              isActive: true,
              components: <MealAdjustmentComponentDraft>[
                MealAdjustmentComponentDraft(
                  componentKey: 'main',
                  displayName: 'Main',
                  defaultItemProductId: fixture.inactiveProductId,
                  quantity: 1,
                  canRemove: true,
                  sortOrder: 0,
                  isActive: true,
                ),
              ],
            ),
          );

      expect(summary.healthStatus, MealAdjustmentHealthStatus.invalid);
      expect(summary.brokenReferences, hasLength(1));
      expect(summary.affectedProducts.single.id, fixture.standardProductId);
    });

    test('listProductsUsingProfile returns assigned products', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _AdminFixture fixture = await _seedAdminFixture(db);
      final MealAdjustmentAdminService service = _createService(db);

      final List<MealAdjustmentProductSummary> products = await service
          .listProductsUsingProfile(fixture.profileId);

      expect(
        products.map((MealAdjustmentProductSummary product) => product.id),
        <int>[fixture.standardProductId],
      );
    });

    test('assign and unassign profile updates product binding', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _AdminFixture fixture = await _seedAdminFixture(db);
      final MealAdjustmentAdminService service = _createService(db);
      final DriftMealAdjustmentProfileRepository repository =
          DriftMealAdjustmentProfileRepository(db);

      await service.assignProfileToProduct(
        productId: fixture.unboundProductId,
        profileId: fixture.profileId,
      );
      expect(
        (await repository.loadProductSummariesByIds(<int>[
          fixture.unboundProductId,
        ]))[fixture.unboundProductId]?.mealAdjustmentProfileId,
        fixture.profileId,
      );

      await service.unassignProfileFromProduct(fixture.unboundProductId);
      expect(
        (await repository.loadProductSummariesByIds(<int>[
          fixture.unboundProductId,
        ]))[fixture.unboundProductId]?.mealAdjustmentProfileId,
        isNull,
      );
    });

    test('previewEvaluation returns persistence-ready snapshot', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _AdminFixture fixture = await _seedAdminFixture(db);
      final MealAdjustmentAdminService service = _createService(db);

      final MealAdjustmentProfileDraft draft = await service.loadProfileDraft(
        fixture.profileId,
      );
      final MealCustomizationResolvedSnapshot snapshot = await service
          .previewEvaluation(
            draft: draft,
            request: MealCustomizationRequest(
              productId: 500,
              swapSelections: <MealCustomizationComponentSelection>[
                MealCustomizationComponentSelection(
                  componentKey: 'main',
                  targetItemProductId: fixture.swapProductId,
                ),
              ],
            ),
          );

      expect(
        snapshot.resolvedComponentActions.single.action,
        MealCustomizationAction.swap,
      );
      expect(snapshot.toPersistencePreview().lines, hasLength(1));
    });
  });
}

MealAdjustmentAdminService _createService(app_db.AppDatabase db) {
  final DriftMealAdjustmentProfileRepository repository =
      DriftMealAdjustmentProfileRepository(db);
  final MealAdjustmentProfileValidationService validationService =
      MealAdjustmentProfileValidationService(repository: repository);
  return MealAdjustmentAdminService(
    repository: repository,
    validationService: validationService,
    engine: const MealCustomizationEngine(),
  );
}

Future<_AdminFixture> _seedAdminFixture(app_db.AppDatabase db) async {
  final int mainsCategoryId = await insertCategory(db, name: 'Mains');
  final int breakfastCategoryId = await insertCategory(
    db,
    name: 'Set Breakfast',
  );
  final int defaultProductId = await insertProduct(
    db,
    categoryId: mainsCategoryId,
    name: 'Chicken',
    priceMinor: 1000,
  );
  final int swapProductId = await insertProduct(
    db,
    categoryId: mainsCategoryId,
    name: 'Beef',
    priceMinor: 1100,
  );
  final int inactiveProductId = await insertProduct(
    db,
    categoryId: mainsCategoryId,
    name: 'Inactive item',
    priceMinor: 900,
    isActive: false,
  );
  final int standardProductId = await insertProduct(
    db,
    categoryId: mainsCategoryId,
    name: 'Burger Meal',
    priceMinor: 1250,
  );
  final int unboundProductId = await insertProduct(
    db,
    categoryId: mainsCategoryId,
    name: 'Wrap Meal',
    priceMinor: 1195,
  );
  final int breakfastProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set Breakfast',
    priceMinor: 1500,
  );

  final int breakfastItemId = await insertProduct(
    db,
    categoryId: mainsCategoryId,
    name: 'Breakfast Egg',
    priceMinor: 250,
  );
  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: breakfastProductId,
          itemProductId: breakfastItemId,
          sortOrder: const Value<int>(0),
        ),
      );

  final DriftMealAdjustmentProfileRepository repository =
      DriftMealAdjustmentProfileRepository(db);
  final int profileId = await repository.saveProfileDraft(
    MealAdjustmentProfileDraft(
      name: 'Burger Meal Profile',
      description: 'Admin profile',
      freeSwapLimit: 1,
      isActive: true,
      components: <MealAdjustmentComponentDraft>[
        MealAdjustmentComponentDraft(
          componentKey: 'main',
          displayName: 'Main',
          defaultItemProductId: defaultProductId,
          quantity: 1,
          canRemove: true,
          sortOrder: 0,
          isActive: true,
          swapOptions: <MealAdjustmentComponentOptionDraft>[
            MealAdjustmentComponentOptionDraft(
              optionItemProductId: swapProductId,
              fixedPriceDeltaMinor: 25,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
      ],
    ),
  );

  await repository.assignProfileToProduct(
    productId: standardProductId,
    profileId: profileId,
  );

  return _AdminFixture(
    profileId: profileId,
    defaultProductId: defaultProductId,
    swapProductId: swapProductId,
    inactiveProductId: inactiveProductId,
    standardProductId: standardProductId,
    unboundProductId: unboundProductId,
    breakfastProductId: breakfastProductId,
  );
}

class _AdminFixture {
  const _AdminFixture({
    required this.profileId,
    required this.defaultProductId,
    required this.swapProductId,
    required this.inactiveProductId,
    required this.standardProductId,
    required this.unboundProductId,
    required this.breakfastProductId,
  });

  final int profileId;
  final int defaultProductId;
  final int swapProductId;
  final int inactiveProductId;
  final int standardProductId;
  final int unboundProductId;
  final int breakfastProductId;
}
