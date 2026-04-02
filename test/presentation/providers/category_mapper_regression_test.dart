import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/presentation/providers/admin_categories_provider.dart';
import 'package:epos_app/presentation/providers/admin_products_provider.dart';
import 'package:epos_app/presentation/providers/products_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'catalog and admin category/product providers load without category mapper crashes',
    () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int breakfastCategoryId = await insertCategory(
        db,
        name: 'Breakfast',
        sortOrder: 0,
      );
      final int drinksCategoryId = await insertCategory(
        db,
        name: 'Hot Drinks',
        sortOrder: 1,
      );
      await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Set 4',
        priceMinor: 400,
      );
      await insertProduct(
        db,
        categoryId: drinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await container.read(productsNotifierProvider.notifier).loadCatalog();
      await container.read(adminCategoriesNotifierProvider.notifier).load();
      await container.read(adminProductsNotifierProvider.notifier).load();

      final productsState = container.read(productsNotifierProvider);
      final adminCategoriesState = container.read(
        adminCategoriesNotifierProvider,
      );
      final adminProductsState = container.read(adminProductsNotifierProvider);

      expect(productsState.errorMessage, isNull);
      expect(
        productsState.categories.map((category) => category.name),
        <String>['Breakfast', 'Hot Drinks'],
      );
      expect(productsState.products.map((product) => product.name), <String>[
        'Set 4',
      ]);

      expect(adminCategoriesState.errorMessage, isNull);
      expect(
        adminCategoriesState.categories.map((category) => category.name),
        <String>['Breakfast', 'Hot Drinks'],
      );

      expect(adminProductsState.errorMessage, isNull);
      expect(
        adminProductsState.categories.map((category) => category.name),
        <String>['Breakfast', 'Hot Drinks'],
      );
      expect(
        adminProductsState.products.map((product) => product.name),
        <String>['Set 4'],
      );
    },
  );
}
