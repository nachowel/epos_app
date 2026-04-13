import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/presentation/providers/admin_products_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
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
    'sort draft moves locally and cancel restores original product order',
    () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int breakfastId = await insertCategory(
        db,
        name: 'Breakfast',
        sortOrder: 0,
      );
      await insertCategory(db, name: 'Lunch', sortOrder: 1);
      await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Tea',
        priceMinor: 150,
        sortOrder: 10,
      );
      await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Coffee',
        priceMinor: 200,
        sortOrder: 20,
      );
      await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Juice',
        priceMinor: 250,
        sortOrder: 30,
      );

      final ProviderContainer container = _makeContainer(db);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(adminProductsNotifierProvider.notifier).load();
      await container
          .read(adminProductsNotifierProvider.notifier)
          .selectCategory(breakfastId);

      final AdminProductsNotifier notifier = container.read(
        adminProductsNotifierProvider.notifier,
      );
      notifier.moveSortDraftDown(0);

      AdminProductsState state = container.read(adminProductsNotifierProvider);
      expect(state.sortDraft.map((Product product) => product.name), <String>[
        'Coffee',
        'Tea',
        'Juice',
      ]);
      expect(state.hasSortChanges, isTrue);

      notifier.discardSortChanges();

      state = container.read(adminProductsNotifierProvider);
      expect(state.sortDraft.map((Product product) => product.name), <String>[
        'Tea',
        'Coffee',
        'Juice',
      ]);
      expect(state.hasSortChanges, isFalse);

      final List<Product> persisted = await ProductRepository(
        db,
      ).getByCategory(breakfastId, activeOnly: false);
      expect(persisted.map((Product product) => product.name), <String>[
        'Tea',
        'Coffee',
        'Juice',
      ]);
    },
  );

  test(
    'save sort order persists sequential sort_order within selected category and refreshes catalog products',
    () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int breakfastId = await insertCategory(
        db,
        name: 'Breakfast',
        sortOrder: 0,
      );
      final int lunchId = await insertCategory(db, name: 'Lunch', sortOrder: 1);
      final int teaId = await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Tea',
        priceMinor: 150,
        sortOrder: 10,
      );
      final int coffeeId = await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Coffee',
        priceMinor: 200,
        sortOrder: 20,
      );
      final int juiceId = await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Juice',
        priceMinor: 250,
        sortOrder: 30,
      );
      await insertProduct(
        db,
        categoryId: lunchId,
        name: 'Soup',
        priceMinor: 500,
        sortOrder: 70,
      );
      await insertProduct(
        db,
        categoryId: lunchId,
        name: 'Wrap',
        priceMinor: 650,
        sortOrder: 80,
      );

      final ProviderContainer container = _makeContainer(db);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container.read(adminProductsNotifierProvider.notifier).load();
      await container
          .read(adminProductsNotifierProvider.notifier)
          .selectCategory(breakfastId);
      await container
          .read(productsNotifierProvider.notifier)
          .loadCatalog(preferredCategoryId: breakfastId);

      final AdminProductsNotifier notifier = container.read(
        adminProductsNotifierProvider.notifier,
      );
      notifier.moveSortDraftToTop(2);

      final bool saved = await notifier.saveSortOrder();
      expect(saved, isTrue);

      final List<Product> breakfastProducts = await ProductRepository(
        db,
      ).getByCategory(breakfastId, activeOnly: false);
      expect(breakfastProducts.map((Product product) => product.id), <int>[
        juiceId,
        teaId,
        coffeeId,
      ]);
      expect(
        breakfastProducts.map((Product product) => product.sortOrder),
        <int>[0, 1, 2],
      );

      final List<Product> lunchProducts = await ProductRepository(
        db,
      ).getByCategory(lunchId, activeOnly: false);
      expect(lunchProducts.map((Product product) => product.sortOrder), <int>[
        70,
        80,
      ]);

      final ProductsState refreshedCatalog = container.read(
        productsNotifierProvider,
      );
      expect(refreshedCatalog.selectedCategoryId, breakfastId);
      expect(
        refreshedCatalog.products.map((Product product) => product.id),
        <int>[juiceId, teaId, coffeeId],
      );
    },
  );

  test(
    'create and update product persist imageUrl through the existing product field',
    () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int breakfastId = await insertCategory(
        db,
        name: 'Breakfast',
        sortOrder: 0,
      );

      final ProviderContainer container = _makeContainer(db);
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);

      final AdminProductsNotifier notifier = container.read(
        adminProductsNotifierProvider.notifier,
      );

      final bool created = await notifier.createProduct(
        categoryId: breakfastId,
        name: 'Bagel',
        priceMinor: 450,
        imageUrl:
            'https://example.supabase.co/storage/v1/object/public/menu/bagel.jpg',
        hasModifiers: false,
        sortOrder: 0,
        isActive: true,
        isVisibleOnPos: true,
      );

      expect(created, isTrue);

      Product createdProduct = (await ProductRepository(
        db,
      ).getByCategory(breakfastId, activeOnly: false)).single;
      expect(
        createdProduct.imageUrl,
        'https://example.supabase.co/storage/v1/object/public/menu/bagel.jpg',
      );

      final bool updated = await notifier.updateProduct(
        id: createdProduct.id,
        categoryId: breakfastId,
        name: 'Bagel',
        priceMinor: 450,
        imageUrl: '',
        hasModifiers: false,
        sortOrder: 0,
        isActive: true,
        isVisibleOnPos: true,
      );

      expect(updated, isTrue);

      createdProduct = (await ProductRepository(
        db,
      ).getByCategory(breakfastId, activeOnly: false)).single;
      expect(createdProduct.imageUrl, isNull);
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
