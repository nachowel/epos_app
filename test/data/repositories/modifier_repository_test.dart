import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/domain/models/product_modifier.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('ModifierRepository', () {
    test('maps included modifier rows into the unified model', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _ModifierFixture fixture = await _seedModifierFixture(db);
      final ModifierRepository repository = ModifierRepository(db);

      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: fixture.rootProductId,
              name: 'Butter',
              type: 'included',
              extraPriceMinor: const Value<int>(0),
            ),
          );

      final ProductModifier modifier = (await repository.getByProductId(
        fixture.rootProductId,
        activeOnly: false,
      )).single;

      expect(modifier.type, ModifierType.included);
      expect(modifier.groupId, isNull);
      expect(modifier.itemProductId, isNull);
      expect(modifier.isLegacyFlat, isTrue);
    });

    test('maps extra modifier rows into the unified model', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _ModifierFixture fixture = await _seedModifierFixture(db);
      final ModifierRepository repository = ModifierRepository(db);

      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: fixture.rootProductId,
              name: 'Hash Brown',
              type: 'extra',
              extraPriceMinor: const Value<int>(125),
            ),
          );

      final ProductModifier modifier = (await repository.getByProductId(
        fixture.rootProductId,
        activeOnly: false,
      )).single;

      expect(modifier.type, ModifierType.extra);
      expect(modifier.extraPriceMinor, 125);
      expect(modifier.groupId, isNull);
      expect(modifier.itemProductId, isNull);
      expect(modifier.isLegacyFlat, isTrue);
    });

    test(
      'maps choice modifier rows with group and item product identity',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _ModifierFixture fixture = await _seedModifierFixture(db);
        final ModifierRepository repository = ModifierRepository(db);

        await db
            .into(db.productModifiers)
            .insert(
              app_db.ProductModifiersCompanion.insert(
                productId: fixture.rootProductId,
                groupId: Value<int?>(fixture.groupId),
                itemProductId: Value<int?>(fixture.choiceProductId),
                name: 'Tea',
                type: 'choice',
                extraPriceMinor: const Value<int>(0),
              ),
            );

        final ProductModifier modifier = (await repository.getByProductId(
          fixture.rootProductId,
          activeOnly: false,
        )).single;

        expect(modifier.type, ModifierType.choice);
        expect(modifier.groupId, fixture.groupId);
        expect(modifier.itemProductId, fixture.choiceProductId);
        expect(modifier.isChoice, isTrue);
        expect(modifier.isLegacyFlat, isFalse);
      },
    );

    test(
      'does not throw when loading products that include choice rows',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _ModifierFixture fixture = await _seedModifierFixture(db);
        final ModifierRepository repository = ModifierRepository(db);

        await db
            .into(db.productModifiers)
            .insert(
              app_db.ProductModifiersCompanion.insert(
                productId: fixture.rootProductId,
                name: 'Butter',
                type: 'included',
              ),
            );
        await db
            .into(db.productModifiers)
            .insert(
              app_db.ProductModifiersCompanion.insert(
                productId: fixture.rootProductId,
                groupId: Value<int?>(fixture.groupId),
                itemProductId: Value<int?>(fixture.choiceProductId),
                name: 'Tea',
                type: 'choice',
              ),
            );

        final List<ProductModifier> modifiers = await repository.getByProductId(
          fixture.rootProductId,
          activeOnly: false,
        );

        expect(modifiers, hasLength(2));
        expect(
          modifiers.map((ProductModifier modifier) => modifier.type),
          containsAll(<ModifierType>[
            ModifierType.included,
            ModifierType.choice,
          ]),
        );
      },
    );

    test('maps structured burger metadata on additive extra rows', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _ModifierFixture fixture = await _seedModifierFixture(db);
      final ModifierRepository repository = ModifierRepository(db);

      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: fixture.rootProductId,
              name: 'Ketchup',
              type: 'extra',
              extraPriceMinor: const Value<int>(0),
              priceBehavior: const Value<String?>('free'),
              uiSection: const Value<String?>('sauces'),
            ),
          );

      final ProductModifier modifier = (await repository.getByProductId(
        fixture.rootProductId,
        activeOnly: false,
      )).single;

      expect(modifier.type, ModifierType.extra);
      expect(modifier.priceBehavior, ModifierPriceBehavior.free);
      expect(modifier.uiSection, ModifierUiSection.sauces);
      expect(modifier.hasStructuredUi, isTrue);
      expect(modifier.isLegacyFlat, isFalse);
    });

    test(
      'rejects grouped choice writes through the generic repository',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _ModifierFixture fixture = await _seedModifierFixture(db);
        final ModifierRepository repository = ModifierRepository(db);

        await expectLater(
          () => repository.insert(
            productId: fixture.rootProductId,
            name: 'Tea',
            type: ModifierType.choice,
            groupId: fixture.groupId,
            itemProductId: fixture.choiceProductId,
          ),
          throwsA(
            isA<ValidationException>().having(
              (ValidationException error) => error.message,
              'message',
              contains('breakfast set configuration'),
            ),
          ),
        );
      },
    );

    test(
      'bulk linked insert skips existing linked products and applies selected settings',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _ModifierFixture fixture = await _seedModifierFixture(db);
        final ModifierRepository repository = ModifierRepository(db);
        final int ketchupId = await insertProduct(
          db,
          categoryId: fixture.categoryId,
          name: 'Ketchup',
          priceMinor: 40,
        );
        final int mayoId = await insertProduct(
          db,
          categoryId: fixture.categoryId,
          name: 'Mayo',
          priceMinor: 55,
        );
        final int archivedId = await insertProduct(
          db,
          categoryId: fixture.categoryId,
          name: 'Archived Sauce',
          priceMinor: 65,
          isActive: false,
        );

        await repository.insert(
          productId: fixture.rootProductId,
          name: 'Ketchup',
          type: ModifierType.extra,
          extraPriceMinor: 40,
          itemProductId: ketchupId,
          priceBehavior: ModifierPriceBehavior.paid,
          uiSection: ModifierUiSection.sauces,
        );

        final BulkModifierInsertResult result = await repository
            .insertBulkLinkedProducts(
              productId: fixture.rootProductId,
              linkedProducts: <Product>[
                Product(
                  id: ketchupId,
                  categoryId: fixture.categoryId,
                  mealAdjustmentProfileId: null,
                  name: 'Ketchup',
                  priceMinor: 40,
                  imageUrl: null,
                  hasModifiers: false,
                  isActive: true,
                  isVisibleOnPos: true,
                  sortOrder: 0,
                ),
                Product(
                  id: mayoId,
                  categoryId: fixture.categoryId,
                  mealAdjustmentProfileId: null,
                  name: 'Mayo',
                  priceMinor: 55,
                  imageUrl: null,
                  hasModifiers: false,
                  isActive: true,
                  isVisibleOnPos: true,
                  sortOrder: 0,
                ),
                Product(
                  id: archivedId,
                  categoryId: fixture.categoryId,
                  mealAdjustmentProfileId: null,
                  name: 'Archived Sauce',
                  priceMinor: 65,
                  imageUrl: null,
                  hasModifiers: false,
                  isActive: false,
                  isVisibleOnPos: true,
                  sortOrder: 0,
                ),
              ],
              type: ModifierType.extra,
              isActive: false,
              priceBehavior: ModifierPriceBehavior.paid,
              uiSection: ModifierUiSection.sauces,
            );

        expect(result.createdCount, 1);
        expect(result.skippedCount, 1);

        final List<ProductModifier> modifiers = await repository.getByProductId(
          fixture.rootProductId,
          activeOnly: false,
        );
        expect(modifiers, hasLength(2));

        final ProductModifier mayoModifier = modifiers.singleWhere(
          (ProductModifier modifier) => modifier.itemProductId == mayoId,
        );
        expect(mayoModifier.name, 'Mayo');
        expect(mayoModifier.type, ModifierType.extra);
        expect(mayoModifier.extraPriceMinor, 55);
        expect(mayoModifier.priceBehavior, ModifierPriceBehavior.paid);
        expect(mayoModifier.uiSection, ModifierUiSection.sauces);
        expect(mayoModifier.isActive, isFalse);
        expect(
          modifiers.where(
            (ProductModifier modifier) => modifier.itemProductId == archivedId,
          ),
          isEmpty,
        );
      },
    );

    test('deletes modifier rows by id', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _ModifierFixture fixture = await _seedModifierFixture(db);
      final ModifierRepository repository = ModifierRepository(db);

      final int modifierId = await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: fixture.rootProductId,
              name: 'Beans',
              type: 'extra',
              extraPriceMinor: const Value<int>(80),
            ),
          );

      final bool deleted = await repository.deleteModifier(modifierId);

      expect(deleted, isTrue);
      expect(
        await repository.getByProductId(
          fixture.rootProductId,
          activeOnly: false,
        ),
        isEmpty,
      );
    });
  });
}

Future<_ModifierFixture> _seedModifierFixture(app_db.AppDatabase db) async {
  final int categoryId = await insertCategory(db, name: 'Breakfast');
  final int rootProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Set Breakfast',
    priceMinor: 500,
  );
  final int choiceProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int groupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: rootProductId,
          name: 'Drink Choice',
          minSelect: const Value<int>(0),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(0),
        ),
      );

  return _ModifierFixture(
    categoryId: categoryId,
    rootProductId: rootProductId,
    choiceProductId: choiceProductId,
    groupId: groupId,
  );
}

class _ModifierFixture {
  const _ModifierFixture({
    required this.categoryId,
    required this.rootProductId,
    required this.choiceProductId,
    required this.groupId,
  });

  final int categoryId;
  final int rootProductId;
  final int choiceProductId;
  final int groupId;
}
