import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/domain/models/category.dart';
import 'package:epos_app/presentation/providers/admin_categories_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/category_catalog_provider.dart';
import 'package:epos_app/presentation/providers/products_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

late SharedPreferences _testPrefs;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _testPrefs = await SharedPreferences.getInstance();
  });

  test(
    'sort draft move changes locally and cancel restores original order',
    () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      await insertCategory(db, name: 'Breakfast', sortOrder: 0);
      await insertCategory(db, name: 'Lunch', sortOrder: 1);
      await insertCategory(db, name: 'Drinks', sortOrder: 2);

      final ProviderContainer container = _makeContainer(db);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(adminCategoriesNotifierProvider.notifier).load();

      final AdminCategoriesNotifier notifier = container.read(
        adminCategoriesNotifierProvider.notifier,
      );

      notifier.moveDraftItemDown(0);

      AdminCategoriesState state = container.read(
        adminCategoriesNotifierProvider,
      );
      expect(state.reorderDraft.map((category) => category.name), <String>[
        'Lunch',
        'Breakfast',
        'Drinks',
      ]);
      expect(state.categories.map((category) => category.name), <String>[
        'Breakfast',
        'Lunch',
        'Drinks',
      ]);
      expect(state.hasReorderChanges, isTrue);

      notifier.discardReorderChanges();

      state = container.read(adminCategoriesNotifierProvider);
      expect(state.reorderDraft.map((category) => category.name), <String>[
        'Breakfast',
        'Lunch',
        'Drinks',
      ]);
      expect(state.hasReorderChanges, isFalse);

      final List categories = await CategoryRepository(
        db,
      ).getAll(activeOnly: false);
      expect(categories.map((category) => category.name), <String>[
        'Breakfast',
        'Lunch',
        'Drinks',
      ]);
    },
  );

  test(
    'save reorder persists sequential sort_order and shared catalog order',
    () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int breakfastId = await insertCategory(
        db,
        name: 'Breakfast',
        sortOrder: 10,
      );
      final int lunchId = await insertCategory(
        db,
        name: 'Lunch',
        sortOrder: 20,
      );
      final int drinksId = await insertCategory(
        db,
        name: 'Drinks',
        sortOrder: 30,
      );

      await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Omelette',
        priceMinor: 850,
      );
      await insertProduct(
        db,
        categoryId: lunchId,
        name: 'Panini',
        priceMinor: 950,
      );
      await insertProduct(
        db,
        categoryId: drinksId,
        name: 'Tea',
        priceMinor: 250,
      );

      final ProviderContainer container = _makeContainer(db);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(adminCategoriesNotifierProvider.notifier).load();

      final AdminCategoriesNotifier notifier = container.read(
        adminCategoriesNotifierProvider.notifier,
      );
      notifier.moveDraftItemToTop(2);

      final bool saved = await notifier.saveReorder();
      expect(saved, isTrue);

      final List categories = await CategoryRepository(
        db,
      ).getAll(activeOnly: false);
      expect(categories.map((category) => category.name), <String>[
        'Drinks',
        'Breakfast',
        'Lunch',
      ]);
      expect(categories.map((category) => category.sortOrder), <int>[0, 1, 2]);

      await container.read(productsNotifierProvider.notifier).loadCatalog();
      final productsState = container.read(productsNotifierProvider);
      expect(
        productsState.categories.map((category) => category.name),
        <String>['Drinks', 'Breakfast', 'Lunch'],
      );
    },
  );

  test(
    'update category refreshes shared category consumers for order and image changes',
    () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int breakfastId = await insertCategory(
        db,
        name: 'Breakfast',
        sortOrder: 0,
      );
      final int lunchId = await insertCategory(db, name: 'Lunch', sortOrder: 1);

      await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Omelette',
        priceMinor: 850,
      );
      await insertProduct(
        db,
        categoryId: lunchId,
        name: 'Panini',
        priceMinor: 950,
      );

      final ProviderContainer container = _makeContainer(db);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(adminCategoriesNotifierProvider.notifier).load();

      final List<Category> initialEntryCategories = await container.read(
        posEntryCategoriesProvider.future,
      );
      expect(
        initialEntryCategories.map((Category category) => category.name),
        <String>['Breakfast', 'Lunch'],
      );

      await container.read(productsNotifierProvider.notifier).loadCatalog();
      expect(
        container
            .read(productsNotifierProvider)
            .categories
            .map((Category category) => category.name),
        <String>['Breakfast', 'Lunch'],
      );

      final bool updated = await container
          .read(adminCategoriesNotifierProvider.notifier)
          .updateCategory(
            id: breakfastId,
            name: 'Breakfast',
            sortOrder: 5,
            isActive: true,
            imageUrl: 'https://cdn.example.com/breakfast.png',
          );

      expect(updated, isTrue);

      final List<Category> refreshedEntryCategories = await container.read(
        posEntryCategoriesProvider.future,
      );
      expect(
        refreshedEntryCategories.map((Category category) => category.name),
        <String>['Lunch', 'Breakfast'],
      );
      expect(
        refreshedEntryCategories
            .singleWhere((Category category) => category.id == breakfastId)
            .imageUrl,
        'https://cdn.example.com/breakfast.png',
      );

      final ProductsState refreshedProductsState = container.read(
        productsNotifierProvider,
      );
      expect(
        refreshedProductsState.categories.map(
          (Category category) => category.name,
        ),
        <String>['Lunch', 'Breakfast'],
      );
    },
  );

  test(
    'update category visibility refreshes shared category consumers',
    () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int breakfastId = await insertCategory(
        db,
        name: 'Breakfast',
        sortOrder: 0,
      );
      final int lunchId = await insertCategory(db, name: 'Lunch', sortOrder: 1);

      await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Omelette',
        priceMinor: 850,
      );
      await insertProduct(
        db,
        categoryId: lunchId,
        name: 'Panini',
        priceMinor: 950,
      );

      final ProviderContainer container = _makeContainer(db);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(adminCategoriesNotifierProvider.notifier).load();
      await container.read(posEntryCategoriesProvider.future);
      await container.read(productsNotifierProvider.notifier).loadCatalog();

      final bool updated = await container
          .read(adminCategoriesNotifierProvider.notifier)
          .updateCategory(
            id: breakfastId,
            name: 'Breakfast',
            sortOrder: 0,
            isActive: false,
          );

      expect(updated, isTrue);

      final List<Category> refreshedEntryCategories = await container.read(
        posEntryCategoriesProvider.future,
      );
      expect(
        refreshedEntryCategories.map((Category category) => category.name),
        <String>['Lunch'],
      );

      final ProductsState refreshedProductsState = container.read(
        productsNotifierProvider,
      );
      expect(
        refreshedProductsState.categories.map(
          (Category category) => category.name,
        ),
        <String>['Lunch'],
      );
      expect(refreshedProductsState.selectedCategoryId, lunchId);
    },
  );
}

ProviderContainer _makeContainer(AppDatabase db) {
  return ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
    ],
  );
}
