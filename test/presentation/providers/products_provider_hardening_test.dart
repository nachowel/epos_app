import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/presentation/providers/products_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('ProductsNotifier route fallback hardening', () {
    test(
      'valid preferred category stays selected and products are filtered to it',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int breakfastId = await insertCategory(
          db,
          name: 'Breakfast',
          sortOrder: 0,
        );
        final int drinksId = await insertCategory(
          db,
          name: 'Drinks',
          sortOrder: 1,
        );
        await insertProduct(
          db,
          categoryId: breakfastId,
          name: 'Toast',
          priceMinor: 450,
        );
        await insertProduct(
          db,
          categoryId: drinksId,
          name: 'Tea',
          priceMinor: 250,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        await container
            .read(productsNotifierProvider.notifier)
            .loadCatalog(
              preferredCategoryId: drinksId,
              preserveVisibleSelection: false,
            );

        final ProductsState state = container.read(productsNotifierProvider);
        expect(state.selectedCategoryId, drinksId);
        expect(state.categories.map((category) => category.name), <String>[
          'Breakfast',
          'Drinks',
        ]);
        expect(state.products.map((product) => product.name), <String>['Tea']);
      },
    );

    test(
      'invalid preferred category falls back to the first ordered category',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int drinksId = await insertCategory(
          db,
          name: 'Drinks',
          sortOrder: 3,
        );
        final int breakfastId = await insertCategory(
          db,
          name: 'Breakfast',
          sortOrder: 0,
        );
        await insertProduct(
          db,
          categoryId: drinksId,
          name: 'Tea',
          priceMinor: 250,
        );
        await insertProduct(
          db,
          categoryId: breakfastId,
          name: 'Toast',
          priceMinor: 450,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        await container
            .read(productsNotifierProvider.notifier)
            .loadCatalog(
              preferredCategoryId: 9999,
              preserveVisibleSelection: false,
            );

        final ProductsState state = container.read(productsNotifierProvider);
        expect(state.selectedCategoryId, breakfastId);
        expect(state.products.map((product) => product.name), <String>[
          'Toast',
        ]);
      },
    );

    test(
      'missing route category fallback does not preserve a stale prior selection',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int breakfastId = await insertCategory(
          db,
          name: 'Breakfast',
          sortOrder: 0,
        );
        final int drinksId = await insertCategory(
          db,
          name: 'Drinks',
          sortOrder: 1,
        );
        await insertProduct(
          db,
          categoryId: breakfastId,
          name: 'Toast',
          priceMinor: 450,
        );
        await insertProduct(
          db,
          categoryId: drinksId,
          name: 'Tea',
          priceMinor: 250,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final ProductsNotifier notifier = container.read(
          productsNotifierProvider.notifier,
        );
        await notifier.loadCatalog(
          preferredCategoryId: drinksId,
          preserveVisibleSelection: false,
        );
        await notifier.loadCatalog(
          preferredCategoryId: null,
          preserveVisibleSelection: false,
        );

        final ProductsState state = container.read(productsNotifierProvider);
        expect(state.selectedCategoryId, breakfastId);
        expect(state.products.map((product) => product.name), <String>[
          'Toast',
        ]);
      },
    );

    test(
      'preferred category outside the visible catalog falls back safely',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int breakfastId = await insertCategory(
          db,
          name: 'Breakfast',
          sortOrder: 0,
        );
        final int hiddenId = await insertCategory(
          db,
          name: 'Hidden',
          sortOrder: 1,
        );
        await insertProduct(
          db,
          categoryId: breakfastId,
          name: 'Toast',
          priceMinor: 450,
        );
        await insertProduct(
          db,
          categoryId: hiddenId,
          name: 'Secret Item',
          priceMinor: 550,
          isVisibleOnPos: false,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        await container
            .read(productsNotifierProvider.notifier)
            .loadCatalog(
              preferredCategoryId: hiddenId,
              preserveVisibleSelection: false,
            );

        final ProductsState state = container.read(productsNotifierProvider);
        expect(state.selectedCategoryId, breakfastId);
        expect(state.categories.map((category) => category.name), <String>[
          'Breakfast',
        ]);
        expect(state.products.map((product) => product.name), <String>[
          'Toast',
        ]);
      },
    );

    test(
      'empty catalog resolves to no selected category and no products',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        await container
            .read(productsNotifierProvider.notifier)
            .loadCatalog(
              preferredCategoryId: 42,
              preserveVisibleSelection: false,
            );

        final ProductsState state = container.read(productsNotifierProvider);
        expect(state.selectedCategoryId, isNull);
        expect(state.categories, isEmpty);
        expect(state.products, isEmpty);
      },
    );
  });
}
