import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/domain/services/admin_service.dart';
import 'package:epos_app/presentation/providers/admin_products_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
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

  testWidgets('selected category deleted resets dropdown safely', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int breakfastCategoryId = await insertCategory(
      db,
      name: 'Breakfast',
      sortOrder: 0,
    );
    final int deletedCategoryId = await insertCategory(
      db,
      name: 'Lunch',
      sortOrder: 1,
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

    await container
        .read(adminProductsNotifierProvider.notifier)
        .selectCategory(deletedCategoryId);
    await tester.pumpAndSettle();
    expect(
      container.read(adminProductsNotifierProvider).selectedCategoryId,
      deletedCategoryId,
    );

    await CategoryRepository(db).deleteCategory(deletedCategoryId);
    await container.read(adminProductsNotifierProvider.notifier).load();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      container.read(adminProductsNotifierProvider).selectedCategoryId,
      breakfastCategoryId,
    );
    expect(
      find.byKey(const ValueKey<String>('product-category-filter')),
      findsOneWidget,
    );
  });

  testWidgets('empty category list does not crash and clears selection', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final AppDatabase db = createTestDatabase();
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

    container.read(appRouterProvider).go('/admin/products');
    await tester.pumpAndSettle();
    expect(
      container.read(adminProductsNotifierProvider).selectedCategoryId,
      categoryId,
    );

    await CategoryRepository(db).deleteCategory(categoryId);
    await container.read(adminProductsNotifierProvider.notifier).load();
    await container.read(adminProductsNotifierProvider.notifier).load();
    await tester.pumpAndSettle();

    final state = container.read(adminProductsNotifierProvider);
    expect(tester.takeException(), isNull);
    expect(state.categories, isEmpty);
    expect(state.selectedCategoryId, isNull);
    expect(
      find.byKey(const ValueKey<String>('product-category-filter')),
      findsOneWidget,
    );
    expect(find.text(AppStrings.noProductsForSelection), findsOneWidget);
  });

  testWidgets(
    'fallback category insertion does not crash stale dropdown state',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int breakfastCategoryId = await insertCategory(
        db,
        name: 'Breakfast',
        sortOrder: 0,
      );
      final int archivedSourceCategoryId = await insertCategory(
        db,
        name: 'Old Specials',
        sortOrder: 1,
      );
      await insertProduct(
        db,
        categoryId: archivedSourceCategoryId,
        name: 'Old Muffin',
        priceMinor: 300,
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

      container.read(appRouterProvider).go('/admin/products');
      await tester.pumpAndSettle();

      await container
          .read(adminProductsNotifierProvider.notifier)
          .selectCategory(archivedSourceCategoryId);
      await tester.pumpAndSettle();

      final currentUser = container.read(authNotifierProvider).currentUser!;
      await container
          .read(adminServiceProvider)
          .deleteCategory(user: currentUser, id: archivedSourceCategoryId);
      await container.read(adminProductsNotifierProvider.notifier).load();
      await tester.pumpAndSettle();

      final state = container.read(adminProductsNotifierProvider);
      expect(tester.takeException(), isNull);
      expect(state.selectedCategoryId, breakfastCategoryId);
      expect(
        state.categories.any(
          (category) => category.name == AdminService.archivedCategoryName,
        ),
        isTrue,
      );
      expect(
        find.byKey(const ValueKey<String>('product-category-filter')),
        findsOneWidget,
      );
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
