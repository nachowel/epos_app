import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('ProductRepository custom sale visibility', () {
    test(
      'excludes the system custom product from normal queries and resolves it by flag instead of name',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int categoryId = await db
            .into(db.categories)
            .insert(CategoriesCompanion.insert(name: 'Drinks'));
        await db
            .into(db.products)
            .insert(
              ProductsCompanion.insert(
                categoryId: categoryId,
                name: 'Custom Sale',
                priceMinor: 250,
                hasModifiers: const Value<bool>(false),
                isActive: const Value<bool>(true),
                isVisibleOnPos: const Value<bool>(true),
                sortOrder: const Value<int>(0),
              ),
            );
        final int systemCustomId = await db
            .into(db.products)
            .insert(
              ProductsCompanion.insert(
                categoryId: categoryId,
                name: 'Custom Sale',
                priceMinor: 0,
                hasModifiers: const Value<bool>(false),
                isActive: const Value<bool>(true),
                isVisibleOnPos: const Value<bool>(false),
                isCustom: const Value<bool>(true),
                sortOrder: const Value<int>(1),
              ),
            );

        final ProductRepository repository = ProductRepository(db);

        final allProducts = await repository.getAll(activeOnly: false);
        final byCategory = await repository.getByCategory(
          categoryId,
          activeOnly: false,
        );
        final catalogProducts = await repository.getActiveCatalogProducts(
          categoryId: categoryId,
        );
        final systemCustom = await repository.getSystemCustomSaleProduct();

        expect(allProducts, hasLength(1));
        expect(allProducts.single.isCustom, isFalse);
        expect(byCategory, hasLength(1));
        expect(byCategory.single.isCustom, isFalse);
        expect(catalogProducts, hasLength(1));
        expect(catalogProducts.single.name, 'Custom Sale');
        expect(catalogProducts.single.isCustom, isFalse);
        expect(systemCustom, isNotNull);
        expect(systemCustom!.id, systemCustomId);
        expect(systemCustom.isCustom, isTrue);
        expect(systemCustom.isVisibleOnPos, isFalse);
      },
    );
  });
}
