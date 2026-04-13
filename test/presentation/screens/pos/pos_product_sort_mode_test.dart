import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/products_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets(
    'POS product sort mode keeps a draft for the current category and cancel restores it',
    (WidgetTester tester) async {
      final _PosSortTestContext context = await _buildSortTestContext();
      addTearDown(context.dispose);

      await tester.pumpWidget(_localizedTestApp(context.container));
      await tester.pumpAndSettle();

      final ProductsNotifier notifier = context.container.read(
        productsNotifierProvider.notifier,
      );

      expect(
        context.container.read(productsNotifierProvider).selectedCategoryId,
        context.sandwichesCategoryId,
      );
      expect(find.text('Tea'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('pos-product-enter-sort-mode')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('pos-product-sort-list')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('pos-product-sort-mode-banner')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('sort-move-down-${context.espressoId}')),
      );
      await tester.pumpAndSettle();

      expect(
        context.container
            .read(productsNotifierProvider)
            .sortDraft
            .map((product) => product.id),
        <int>[context.bagelId, context.espressoId, context.toastieId],
      );

      await tester.tap(find.text('Drink').first);
      await tester.pumpAndSettle();

      expect(
        context.container.read(productsNotifierProvider).selectedCategoryId,
        context.sandwichesCategoryId,
      );
      expect(
        find.text(
          'Ürün sıralamasını değiştirmeden önce Kaydet veya İptal seçin.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('pos-product-sort-cancel')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('pos-product-sort-list')),
        findsNothing,
      );
      expect(
        context.container.read(productsNotifierProvider).isSortMode,
        isFalse,
      );
      expect(
        context.container
            .read(productsNotifierProvider)
            .products
            .map((product) => product.id),
        <int>[context.espressoId, context.bagelId, context.toastieId],
      );

      await notifier.selectCategory(context.drinkCategoryId);
      expect(
        context.container.read(productsNotifierProvider).products.first.name,
        'Tea',
      );
    },
  );

  testWidgets(
    'POS product sort mode saves category-specific order and leaves other categories unchanged',
    (WidgetTester tester) async {
      final _PosSortTestContext context = await _buildSortTestContext();
      addTearDown(context.dispose);

      await tester.pumpWidget(_localizedTestApp(context.container));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('pos-product-enter-sort-mode')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('sort-move-bottom-${context.espressoId}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('pos-product-sort-save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ürün sırası kaydedildi.'), findsOneWidget);
      expect(
        context.container.read(productsNotifierProvider).isSortMode,
        isFalse,
      );
      expect(
        context.container
            .read(productsNotifierProvider)
            .products
            .map((product) => product.id),
        <int>[context.bagelId, context.toastieId, context.espressoId],
      );

      final ProductRepository repository = ProductRepository(context.db);
      final List<int> sandwichesOrder = (await repository.getByCategory(
        context.sandwichesCategoryId,
        activeOnly: false,
      )).map((product) => product.id).toList(growable: false);
      expect(sandwichesOrder, <int>[
        context.bagelId,
        context.toastieId,
        context.espressoId,
      ]);

      final List<int> drinkSortOrders = (await repository.getByCategory(
        context.drinkCategoryId,
        activeOnly: false,
      )).map((product) => product.sortOrder).toList(growable: false);
      expect(drinkSortOrders, <int>[0, 1]);

      await tester.tap(find.text('Drink').first);
      await tester.pumpAndSettle();
      expect(
        context.container
            .read(productsNotifierProvider)
            .products
            .map((product) => product.name),
        <String>['Tea', 'Orange Juice'],
      );

      await tester.tap(find.text('Sandwiches').first);
      await tester.pumpAndSettle();
      expect(
        context.container
            .read(productsNotifierProvider)
            .products
            .map((product) => product.id),
        <int>[context.bagelId, context.toastieId, context.espressoId],
      );
    },
  );
}

Future<_PosSortTestContext> _buildSortTestContext() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final db = createTestDatabase();

  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int sandwichesCategoryId = await insertCategory(
    db,
    name: 'Sandwiches',
    sortOrder: 0,
  );
  final int drinkCategoryId = await insertCategory(
    db,
    name: 'Drink',
    sortOrder: 1,
  );
  final int espressoId = await insertProduct(
    db,
    categoryId: sandwichesCategoryId,
    name: 'Espresso Panini',
    priceMinor: 650,
    sortOrder: 0,
  );
  final int bagelId = await insertProduct(
    db,
    categoryId: sandwichesCategoryId,
    name: 'Salmon Bagel',
    priceMinor: 725,
    sortOrder: 1,
  );
  final int toastieId = await insertProduct(
    db,
    categoryId: sandwichesCategoryId,
    name: 'Ham Toastie',
    priceMinor: 695,
    sortOrder: 2,
  );
  await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Tea',
    priceMinor: 250,
    sortOrder: 0,
  );
  await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Orange Juice',
    priceMinor: 300,
    sortOrder: 1,
  );
  await insertShift(db, openedBy: cashierId);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      ordersNotifierProvider.overrideWith(
        (Ref ref) => _StaticOrdersNotifier(ref),
      ),
    ],
  );

  await container.read(authNotifierProvider.notifier).loadUserById(cashierId);
  await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

  return _PosSortTestContext(
    container: container,
    db: db,
    sandwichesCategoryId: sandwichesCategoryId,
    drinkCategoryId: drinkCategoryId,
    espressoId: espressoId,
    bagelId: bagelId,
    toastieId: toastieId,
  );
}

Widget _localizedTestApp(ProviderContainer container) {
  AppLocalizationService.instance.setLocale(const Locale('en'));
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const PosScreen(),
    ),
  );
}

class _StaticOrdersNotifier extends OrdersNotifier {
  _StaticOrdersNotifier(super.ref);

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: false, errorMessage: null);
  }
}

class _PosSortTestContext {
  const _PosSortTestContext({
    required this.container,
    required this.db,
    required this.sandwichesCategoryId,
    required this.drinkCategoryId,
    required this.espressoId,
    required this.bagelId,
    required this.toastieId,
  });

  final ProviderContainer container;
  final AppDatabase db;
  final int sandwichesCategoryId;
  final int drinkCategoryId;
  final int espressoId;
  final int bagelId;
  final int toastieId;

  void dispose() {
    container.dispose();
    db.close();
  }
}
