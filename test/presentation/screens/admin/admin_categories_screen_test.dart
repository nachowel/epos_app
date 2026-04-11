import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/presentation/providers/admin_categories_provider.dart';
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

  testWidgets('cannot delete category with products', (
    WidgetTester tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int categoryId = await insertCategory(db, name: 'Breakfast');
    await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Set Breakfast',
      priceMinor: 850,
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

    container.read(appRouterProvider).go('/admin/categories');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey<String>('category-delete-$categoryId')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete category?'), findsNothing);
    expect(
      find.text(
        'This category contains active products. Move, archive, or delete them first.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('category-tile-$categoryId')),
      findsOneWidget,
    );
  });

  testWidgets('can delete empty category with confirmation', (
    WidgetTester tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int categoryId = await insertCategory(db, name: 'Breakfast');

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

    container.read(appRouterProvider).go('/admin/categories');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey<String>('category-delete-$categoryId')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Delete category?'), findsOneWidget);
    expect(find.text('This action cannot be undone.'), findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey<String>('category-delete-confirm-$categoryId')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Category deleted.'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('category-tile-$categoryId')),
      findsNothing,
    );
    expect(await CategoryRepository(db).getById(categoryId), isNull);
  });

  testWidgets('can delete category with only archived products', (
    WidgetTester tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int categoryId = await insertCategory(db, name: 'Old Breakfast');
    await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Old Set',
      priceMinor: 500,
      isActive: false,
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

    container.read(appRouterProvider).go('/admin/categories');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey<String>('category-delete-$categoryId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey<String>('category-delete-confirm-$categoryId')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Category deleted.'), findsOneWidget);
    expect(await CategoryRepository(db).getById(categoryId), isNull);
    final archivedFallback = await CategoryRepository(
      db,
    ).findByNameIgnoreCase('Archived Products');
    expect(archivedFallback, isNotNull);
  });

  testWidgets('Archived Products is hidden from the normal categories list', (
    WidgetTester tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int breakfastCategoryId = await insertCategory(db, name: 'Breakfast');
    final int archivedCategoryId = await insertCategory(
      db,
      name: 'Archived Products',
      sortOrder: 9999,
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

    container.read(appRouterProvider).go('/admin/categories');
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey<String>('category-tile-$breakfastCategoryId')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('category-tile-$archivedCategoryId')),
      findsNothing,
    );
    expect(find.text('Archived Products'), findsNothing);
    expect(
      find.byKey(ValueKey<String>('category-edit-$archivedCategoryId')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('category-delete-$archivedCategoryId')),
      findsNothing,
    );
  });

  testWidgets('only system fallback category shows empty normal list', (
    WidgetTester tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    await insertCategory(db, name: 'Archived Products', sortOrder: 9999);

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

    container.read(appRouterProvider).go('/admin/categories');
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.noCategoriesDefined), findsOneWidget);
    expect(find.text('Archived Products'), findsNothing);
  });

  testWidgets(
    'duplicate category name is blocked case-insensitively when editing',
    (WidgetTester tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      await insertCategory(db, name: 'Breakfast');
      final int secondCategoryId = await insertCategory(db, name: 'Drinks');

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

      container.read(appRouterProvider).go('/admin/categories');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(ValueKey<String>('category-edit-$secondCategoryId')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('category-name-field')),
        'breakfast',
      );
      await tester.tap(find.byKey(const ValueKey<String>('category-save')));
      await tester.pumpAndSettle();

      expect(
        find.text('Category with this name already exists'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('category-name-field')),
        findsOneWidget,
      );
    },
  );

  testWidgets('create category persists optional image URL', (
    WidgetTester tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');

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

    container.read(appRouterProvider).go('/admin/categories');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.addCategory));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('category-name-field')),
      'Bakery',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('category-image-url-field')),
      'https://cdn.example.com/bakery.png',
    );
    await tester.tap(find.byKey(const ValueKey<String>('category-save')));
    await tester.pumpAndSettle();

    final categories = await CategoryRepository(db).getAll(activeOnly: false);
    final created = categories.singleWhere((category) => category.name == 'Bakery');
    expect(created.imageUrl, 'https://cdn.example.com/bakery.png');
  });

  testWidgets('edit category preloads and can clear image URL', (
    WidgetTester tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int categoryId = await insertCategory(
      db,
      name: 'Breakfast',
      imageUrl: 'https://cdn.example.com/breakfast.png',
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

    container.read(appRouterProvider).go('/admin/categories');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey<String>('category-edit-$categoryId')));
    await tester.pumpAndSettle();

    final TextField imageField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('category-image-url-field')),
    );
    expect(imageField.controller?.text, 'https://cdn.example.com/breakfast.png');
    expect(find.byKey(const ValueKey<String>('category-image-preview')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('category-image-url-field')),
      '',
    );
    await tester.tap(find.byKey(const ValueKey<String>('category-save')));
    await tester.pumpAndSettle();

    final updated = await CategoryRepository(db).getById(categoryId);
    expect(updated?.imageUrl, isNull);
  });

  testWidgets('visibility toggle hides category from POS', (
    WidgetTester tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int categoryId = await insertCategory(db, name: 'Breakfast');
    await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Set Breakfast',
      priceMinor: 850,
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

    await container.read(productsNotifierProvider.notifier).loadCatalog();
    var productsState = container.read(productsNotifierProvider);
    expect(
      productsState.categories.any((category) => category.id == categoryId),
      isTrue,
    );

    container.read(appRouterProvider).go('/admin/categories');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(ValueKey<String>('category-visible-switch-$categoryId')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hidden'), findsOneWidget);

    await container.read(productsNotifierProvider.notifier).loadCatalog();
    productsState = container.read(productsNotifierProvider);
    expect(
      productsState.categories.any((category) => category.id == categoryId),
      isFalse,
    );
    expect(productsState.products, isEmpty);
  });

  testWidgets(
    'reorder mode shows drag handles for all categories and saves persisted order',
    (WidgetTester tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int breakfastId = await insertCategory(
        db,
        name: 'Breakfast',
        sortOrder: 0,
      );
      final int lunchId = await insertCategory(db, name: 'Lunch', sortOrder: 1);
      final int drinksId = await insertCategory(db, name: 'Drinks', sortOrder: 2);
      final int bakeryId = await insertCategory(db, name: 'Bakery', sortOrder: 3);
      final int archivedId = await insertCategory(
        db,
        name: 'Archived Products',
        sortOrder: 4,
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

      container.read(appRouterProvider).go('/admin/categories');
      await tester.pumpAndSettle();

      expect(find.text('Archived Products'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('category-enter-reorder-mode')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('category-reorder-list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('category-reorder-primary-zone')),
        findsOneWidget,
      );
      expect(find.text('Category Entry large'), findsWidgets);
      expect(
        find.byKey(ValueKey<String>('category-reorder-drag-handle-$breakfastId')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('category-reorder-drag-handle-$lunchId')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('category-reorder-drag-handle-$drinksId')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('category-reorder-drag-handle-$bakeryId')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(ValueKey<String>('category-reorder-drag-handle-$archivedId')),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Archived Products'), findsOneWidget);
      expect(find.text('Standard grid'), findsWidgets);
      expect(
        find.byKey(ValueKey<String>('category-reorder-drag-handle-$archivedId')),
        findsOneWidget,
      );

      container.read(adminCategoriesNotifierProvider.notifier).reorderDraft(4, 0);
      await tester.pump();
      expect(find.text('Row 1 | ID $archivedId'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('category-reorder-save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Category order saved.'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('category-reorder-save')),
        findsNothing,
      );
      expect(find.text('Archived Products'), findsNothing);

      final reordered = await CategoryRepository(db).getAll(activeOnly: false);
      expect(reordered.first.id, archivedId);
      expect(reordered.map((category) => category.sortOrder), <int>[
        0,
        1,
        2,
        3,
        4,
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
