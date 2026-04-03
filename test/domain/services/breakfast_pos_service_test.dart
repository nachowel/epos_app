import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/domain/models/breakfast_line_edit.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/domain/models/semantic_product_configuration.dart';
import 'package:epos_app/domain/services/breakfast_pos_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('BreakfastPosService', () {
    test(
      'required grouped choices must be completed before confirmation',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastPosFixture fixture = await _seedBreakfastPosFixture(db);
        final BreakfastPosService service = BreakfastPosService(
          breakfastConfigurationRepository: BreakfastConfigurationRepository(
            db,
          ),
        );

        final BreakfastPosEditorData initial = await service.loadEditorData(
          product: fixture.rootProduct,
        );

        expect(initial.profile.type, ProductMenuConfigType.semanticSet);
        expect(initial.preview.canConfirm, isFalse);
        expect(
          initial.preview.validationMessages,
          contains('Choose an option for Drink choice.'),
        );

        final BreakfastRequestedState requestedState =
            const BreakfastLineEdit.chooseGroup(
              groupId: 0,
              selectedItemProductId: 0,
              quantity: 0,
            ).copyWithGroup(
              groupId: fixture.drinkGroupId,
              selectedItemProductId: fixture.teaProductId,
              quantity: 1,
            );
        final BreakfastPosSelectionPreview nextPreview = service
            .previewSelection(
              product: fixture.rootProduct,
              configuration: initial.configuration,
              requestedState: requestedState,
            );

        expect(nextPreview.canConfirm, isTrue);
        expect(nextPreview.validationMessages, isEmpty);
      },
    );

    test('broken multi-select config is blocked before POS sale', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastPosFixture fixture = await _seedBreakfastPosFixture(
        db,
        groupMaxSelect: 2,
      );
      final BreakfastPosService service = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );

      await expectLater(
        () => service.loadEditorData(product: fixture.rootProduct),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            contains('POS currently supports one selection per group.'),
          ),
        ),
      );
    });

    test(
      'cart selection preserves grouped choice and removable item identity',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastPosFixture fixture = await _seedBreakfastPosFixture(db);
        final BreakfastPosService service = BreakfastPosService(
          breakfastConfigurationRepository: BreakfastConfigurationRepository(
            db,
          ),
        );

        final BreakfastRequestedState requestedState =
            BreakfastLineEdit.setRemovedQuantity(
              itemProductId: fixture.beansProductId,
              quantity: 1,
            ).applyTo(
              const BreakfastLineEdit.chooseGroup(
                groupId: 0,
                selectedItemProductId: 0,
                quantity: 0,
              ).copyWithGroup(
                groupId: fixture.drinkGroupId,
                selectedItemProductId: fixture.teaProductId,
                quantity: 1,
              ),
            );

        final selection = await service.buildCartSelection(
          product: fixture.rootProduct,
          requestedState: requestedState,
        );

        expect(
          selection.requestedState.removedSetItems.single.itemProductId,
          fixture.beansProductId,
        );
        expect(
          selection.requestedState.chosenGroups.single.groupId,
          fixture.drinkGroupId,
        );
        expect(
          selection.rebuildResult.classifiedModifiers.any(
            (BreakfastClassifiedModifier modifier) =>
                modifier.action.name == 'remove' &&
                modifier.itemProductId == fixture.beansProductId,
          ),
          isTrue,
        );
        expect(
          selection.rebuildResult.classifiedModifiers.any(
            (BreakfastClassifiedModifier modifier) =>
                modifier.action.name == 'choice' &&
                modifier.itemProductId == fixture.teaProductId,
          ),
          isTrue,
        );
      },
    );

    test('extras section only exposes explicit extras pool items', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastPosFixture fixture = await _seedBreakfastPosFixture(db);
      final BreakfastPosService service = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );

      final BreakfastPosEditorData editorData = await service.loadEditorData(
        product: fixture.rootProduct,
      );

      expect(
        editorData.preview.addableProducts.map(
          (BreakfastPosAddableProduct product) => product.id,
        ),
        <int>[fixture.hashBrownProductId],
      );
      expect(
        editorData.preview.addableProducts.single.priceMinor,
        fixture.hashBrownPriceMinor,
      );
    });

    test('requested extras outside the explicit pool are rejected', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastPosFixture fixture = await _seedBreakfastPosFixture(db);
      final BreakfastPosService service = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );

      final BreakfastPosEditorData editorData = await service.loadEditorData(
        product: fixture.rootProduct,
      );

      final BreakfastPosSelectionPreview preview = service.previewSelection(
        product: fixture.rootProduct,
        configuration: editorData.configuration,
        requestedState: BreakfastRequestedState(
          addedProducts: <BreakfastAddedProductRequest>[
            BreakfastAddedProductRequest(
              itemProductId: fixture.beansProductId,
              quantity: 1,
            ),
          ],
        ),
      );

      expect(preview.canConfirm, isFalse);
      expect(
        preview.validationMessages,
        contains('This extra is not available for this breakfast.'),
      );
    });
  });
}

extension on BreakfastLineEdit {
  BreakfastRequestedState copyWithGroup({
    required int groupId,
    required int selectedItemProductId,
    required int quantity,
  }) {
    return BreakfastLineEdit.chooseGroup(
      groupId: groupId,
      selectedItemProductId: selectedItemProductId,
      quantity: quantity,
    ).applyTo(const BreakfastRequestedState());
  }
}

Future<_BreakfastPosFixture> _seedBreakfastPosFixture(
  app_db.AppDatabase db, {
  int groupMaxSelect = 1,
}) async {
  final int breakfastCategoryId = await insertCategory(db, name: 'Breakfast');
  final int drinkCategoryId = await insertCategory(db, name: 'Drinks');

  final int rootProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set Breakfast',
    priceMinor: 600,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Egg',
    priceMinor: 120,
  );
  final int beansProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Beans',
    priceMinor: 80,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int coffeeProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Coffee',
    priceMinor: 170,
  );
  const int hashBrownPriceMinor = 130;
  final int hashBrownProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Hash Brown',
    priceMinor: hashBrownPriceMinor,
  );

  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: eggProductId,
          sortOrder: const Value<int>(1),
          isRemovable: const Value<bool>(false),
        ),
      );
  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: beansProductId,
          sortOrder: const Value<int>(2),
          isRemovable: const Value<bool>(true),
        ),
      );

  final int drinkGroupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: rootProductId,
          name: 'Drink choice',
          minSelect: const Value<int>(1),
          maxSelect: Value<int>(groupMaxSelect),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );

  Future<void> insertChoiceMember({
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          app_db.ProductModifiersCompanion.insert(
            productId: rootProductId,
            groupId: Value<int?>(drinkGroupId),
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'choice',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertChoiceMember(itemProductId: teaProductId, label: 'Tea');
  await insertChoiceMember(itemProductId: coffeeProductId, label: 'Coffee');
  await db
      .into(db.productModifiers)
      .insert(
        app_db.ProductModifiersCompanion.insert(
          productId: rootProductId,
          itemProductId: Value<int?>(hashBrownProductId),
          name: 'Hash Brown',
          type: 'extra',
          extraPriceMinor: const Value<int>(0),
        ),
      );

  return _BreakfastPosFixture(
    rootProduct: Product(
      id: rootProductId,
      categoryId: breakfastCategoryId,
      name: 'Set Breakfast',
      priceMinor: 600,
      imageUrl: null,
      hasModifiers: false,
      isActive: true,
      isVisibleOnPos: true,
      sortOrder: 0,
    ),
    beansProductId: beansProductId,
    hashBrownProductId: hashBrownProductId,
    hashBrownPriceMinor: hashBrownPriceMinor,
    teaProductId: teaProductId,
    drinkGroupId: drinkGroupId,
  );
}

class _BreakfastPosFixture {
  const _BreakfastPosFixture({
    required this.rootProduct,
    required this.beansProductId,
    required this.hashBrownProductId,
    required this.hashBrownPriceMinor,
    required this.teaProductId,
    required this.drinkGroupId,
  });

  final Product rootProduct;
  final int beansProductId;
  final int hashBrownProductId;
  final int hashBrownPriceMinor;
  final int teaProductId;
  final int drinkGroupId;
}
