import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/domain/models/legacy_flat_modifier_view.dart';
import 'package:epos_app/domain/models/product_modifier.dart';
import 'package:epos_app/domain/services/catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('CatalogService modifiers', () {
    test(
      'legacy flat projection preserves included and extra modifiers',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _CatalogModifierFixture fixture = await _seedCatalogFixture(db);
        final CatalogService service = _createCatalogService(db);

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
                name: 'Hash Brown',
                type: 'extra',
                extraPriceMinor: const Value<int>(125),
              ),
            );

        final LegacyFlatModifierView flatView = await service
            .getLegacyFlatModifierView(fixture.rootProductId);

        expect(flatView.included, hasLength(1));
        expect(flatView.included.single.type, ModifierType.included);
        expect(flatView.extras, hasLength(1));
        expect(flatView.extras.single.type, ModifierType.extra);
        expect(flatView.omittedSemanticModifiers, isEmpty);
      },
    );

    test(
      'grouped choice rows stay semantic in catalog reads and are omitted from the legacy flat view',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _CatalogModifierFixture fixture = await _seedCatalogFixture(db);
        final CatalogService service = _createCatalogService(db);

        final int includedId = await db
            .into(db.productModifiers)
            .insert(
              app_db.ProductModifiersCompanion.insert(
                productId: fixture.rootProductId,
                name: 'Butter',
                type: 'included',
              ),
            );
        final int extraId = await db
            .into(db.productModifiers)
            .insert(
              app_db.ProductModifiersCompanion.insert(
                productId: fixture.rootProductId,
                name: 'Hash Brown',
                type: 'extra',
                extraPriceMinor: const Value<int>(125),
              ),
            );
        final int choiceId = await db
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

        final List<ProductModifier> modifiers = await service
            .getProductModifiers(fixture.rootProductId);
        final ProductModifier choiceModifier = modifiers.singleWhere(
          (ProductModifier modifier) => modifier.id == choiceId,
        );
        final LegacyFlatModifierView flatView = await service
            .getLegacyFlatModifierView(fixture.rootProductId);

        expect(choiceModifier.type, ModifierType.choice);
        expect(choiceModifier.groupId, fixture.groupId);
        expect(choiceModifier.itemProductId, fixture.choiceProductId);
        expect(
          flatView.included.map((ProductModifier modifier) => modifier.id),
          contains(includedId),
        );
        expect(
          flatView.extras.map((ProductModifier modifier) => modifier.id),
          contains(extraId),
        );
        expect(
          flatView.included.map((ProductModifier modifier) => modifier.id),
          isNot(contains(choiceId)),
        );
        expect(
          flatView.extras.map((ProductModifier modifier) => modifier.id),
          isNot(contains(choiceId)),
        );
        expect(flatView.omittedSemanticModifiers, hasLength(1));
        expect(flatView.omittedSemanticModifiers.single.id, choiceId);
        expect(
          flatView.omittedSemanticModifiers.single.type,
          ModifierType.choice,
        );
      },
    );
  });
}

CatalogService _createCatalogService(app_db.AppDatabase db) {
  return CatalogService(
    categoryRepository: CategoryRepository(db),
    productRepository: ProductRepository(db),
    modifierRepository: ModifierRepository(db),
  );
}

Future<_CatalogModifierFixture> _seedCatalogFixture(
  app_db.AppDatabase db,
) async {
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

  return _CatalogModifierFixture(
    rootProductId: rootProductId,
    choiceProductId: choiceProductId,
    groupId: groupId,
  );
}

class _CatalogModifierFixture {
  const _CatalogModifierFixture({
    required this.rootProductId,
    required this.choiceProductId,
    required this.groupId,
  });

  final int rootProductId;
  final int choiceProductId;
  final int groupId;
}
