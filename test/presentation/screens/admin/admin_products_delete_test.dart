import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/presentation/providers/products_provider.dart';
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

  testWidgets('delete unused product removes it from admin and database', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int categoryId = await insertCategory(db, name: 'Breakfast');
    final int productId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Unused Bagel',
      priceMinor: 450,
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

    await tester.ensureVisible(
      find.byKey(ValueKey<String>('product-delete-$productId')),
    );
    await tester.tap(
      find.byKey(ValueKey<String>('product-delete-$productId')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete product?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to delete this product?'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey<String>('product-delete-confirm-$productId')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Product deleted.'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('product-tile-$productId')),
      findsNothing,
    );
    expect(await ProductRepository(db).getById(productId), isNull);
    expect(await CategoryRepository(db).hasProducts(categoryId), isFalse);
  });

  testWidgets('delete used product deactivates it instead of removing it', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final int adminId = await insertUser(
      db,
      name: 'Admin',
      role: 'admin',
      pin: '9999',
    );
    final int categoryId = await insertCategory(db, name: 'Breakfast');
    final int productId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Historic Muffin',
      priceMinor: 500,
    );
    final int activeProductId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Fresh Bagel',
      priceMinor: 350,
    );
    final int shiftId = await insertShift(db, openedBy: adminId);
    final int transactionId = await insertTransaction(
      db,
      uuid: 'historic-order',
      shiftId: shiftId,
      userId: adminId,
      status: 'paid',
      totalAmountMinor: 500,
      paidAt: DateTime.now(),
    );
    await db
        .into(db.transactionLines)
        .insert(
          TransactionLinesCompanion.insert(
            uuid: 'historic-line',
            transactionId: transactionId,
            productId: productId,
            productName: 'Historic Muffin',
            unitPriceMinor: 500,
            lineTotalMinor: 500,
          ),
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

    await tester.ensureVisible(
      find.byKey(ValueKey<String>('product-delete-$productId')),
    );
    await tester.tap(
      find.byKey(ValueKey<String>('product-delete-$productId')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey<String>('product-delete-confirm-$productId')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Product cannot be deleted because it exists in past orders. It has been archived instead.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('product-tile-$productId')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('product-tile-$activeProductId')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('product-filter-archived')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey<String>('product-tile-$productId')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey<String>('product-tile-$productId')),
        matching: find.text('Archived'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('product-tile-$activeProductId')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey<String>('product-filter-all')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey<String>('product-tile-$productId')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('product-tile-$activeProductId')),
      findsOneWidget,
    );

    final product = await ProductRepository(db).getById(productId);
    expect(product, isNotNull);
    expect(product!.isActive, isFalse);

    await container.read(productsNotifierProvider.notifier).loadCatalog();
    final productsState = container.read(productsNotifierProvider);
    expect(
      productsState.products.any((product) => product.id == productId),
      isFalse,
    );
    expect(
      productsState.products.any((product) => product.id == activeProductId),
      isTrue,
    );
    expect(
      productsState.categories.any((category) => category.id == categoryId),
      isTrue,
    );
  });

  testWidgets(
    'standard products show delete impact warning and set builder is only shown for set products',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int categoryId = await insertCategory(db, name: 'Breakfast');
      final int setProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Set Breakfast',
        priceMinor: 850,
      );
      final int baconId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Bacon',
        priceMinor: 200,
      );
      final int teaId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Tea',
        priceMinor: 150,
      );

      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: setProductId,
              itemProductId: baconId,
            ),
          );
      final int groupId = await db
          .into(db.modifierGroups)
          .insert(
            ModifierGroupsCompanion.insert(
              productId: setProductId,
              name: 'Drink',
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: setProductId,
              groupId: Value<int?>(groupId),
              itemProductId: Value<int?>(teaId),
              name: 'Tea',
              type: 'choice',
            ),
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

      expect(find.text('Set Products'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
      expect(
        find.byKey(ValueKey<String>('product-set-builder-$setProductId')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('product-set-builder-$baconId')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('set-products-section')),
          matching: find.byKey(
            ValueKey<String>('product-set-builder-$setProductId'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('normal-products-section')),
          matching: find.byKey(
            ValueKey<String>('product-set-builder-$baconId'),
          ),
        ),
        findsNothing,
      );

      await tester.ensureVisible(
        find.byKey(ValueKey<String>('product-delete-$baconId')),
      );
      await tester.tap(
        find.byKey(ValueKey<String>('product-delete-$baconId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete product?'), findsOneWidget);
      expect(
        find.textContaining(
          'This product is used by other set configurations.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Used in 1 set configurations'),
        findsOneWidget,
      );
      expect(find.textContaining('Used in 0 required choices'), findsOneWidget);
      expect(find.textContaining('Used in 0 extras pools'), findsOneWidget);

      await tester.tap(find.text(AppStrings.cancel));
      await tester.pumpAndSettle();
      expect(await ProductRepository(db).getById(baconId), isNotNull);
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
