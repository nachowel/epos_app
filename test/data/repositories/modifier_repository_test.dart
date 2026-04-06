import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/core/errors/exceptions.dart';
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
    rootProductId: rootProductId,
    choiceProductId: choiceProductId,
    groupId: groupId,
  );
}

class _ModifierFixture {
  const _ModifierFixture({
    required this.rootProductId,
    required this.choiceProductId,
    required this.groupId,
  });

  final int rootProductId;
  final int choiceProductId;
  final int groupId;
}
