import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/presentation/providers/admin_products_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

late SharedPreferences _testPrefs;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _testPrefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    'product sort mode uses explicit controls and cancel restores draft',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
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
        sortOrder: 0,
      );
      final int coffeeId = await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Coffee',
        priceMinor: 200,
        sortOrder: 1,
      );
      final int juiceId = await insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Juice',
        priceMinor: 250,
        sortOrder: 2,
      );
      await insertProduct(
        db,
        categoryId: lunchId,
        name: 'Soup',
        priceMinor: 500,
        sortOrder: 0,
      );

      final ProviderContainer container = _makeContainer(db);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestRouterApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _loginWithPin(tester, '9999');

      container.read(appRouterProvider).go('/admin/products');
      await tester.pumpAndSettle();

      expect(
        container.read(adminProductsNotifierProvider).selectedCategoryId,
        breakfastId,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('product-enter-sort-mode')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('product-sort-list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('product-sort-mode-banner')),
        findsOneWidget,
      );
      expect(
        container
            .read(adminProductsNotifierProvider)
            .sortDraft
            .every((Product product) => product.categoryId == breakfastId),
        isTrue,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(ValueKey<String>('sort-move-up-$teaId')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(ValueKey<String>('sort-move-down-$juiceId')),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(ValueKey<String>('sort-move-down-$teaId')));
      await tester.pumpAndSettle();

      expect(
        container.read(adminProductsNotifierProvider).sortDraft.first.id,
        coffeeId,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('product-sort-cancel')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('product-sort-list')),
        findsNothing,
      );
      expect(
        container.read(adminProductsNotifierProvider).sortDraft.first.id,
        teaId,
      );
    },
  );

  testWidgets(
    'product sort mode save persists order only within selected category',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
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

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestRouterApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _loginWithPin(tester, '9999');

      container.read(appRouterProvider).go('/admin/products');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('product-enter-sort-mode')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey<String>('sort-move-top-$juiceId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('product-sort-save')));
      await tester.pumpAndSettle();

      expect(find.text('Product order saved.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('product-sort-list')),
        findsNothing,
      );

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

class _TestRouterApp extends ConsumerWidget {
  const _TestRouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(routerConfig: ref.watch(appRouterProvider));
  }
}

Future<void> _loginWithPin(WidgetTester tester, String pin) async {
  await tester.enterText(find.byType(TextField), pin);
  await tester.tap(find.text(AppStrings.loginButton));
  await tester.pumpAndSettle();
  expect(find.text(AppStrings.loginButton), findsNothing);
}

void _setLargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
