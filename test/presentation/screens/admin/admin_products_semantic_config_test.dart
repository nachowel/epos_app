import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:drift/drift.dart' show Value;
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
    'admin set builder uses tabs and saves included items, choices, and extras',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int breakfastCategoryId = await insertCategory(
        db,
        name: 'Breakfast',
      );
      final int drinksCategoryId = await insertCategory(db, name: 'Drinks');
      final int rootProductId = await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Set Breakfast',
        priceMinor: 500,
      );
      final int seedItemId = await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Beans',
        priceMinor: 90,
      );
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Egg',
        priceMinor: 120,
      );
      final int teaId = await insertProduct(
        db,
        categoryId: drinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
      );
      final int hashBrownId = await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Hash Brown',
        priceMinor: 130,
      );
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: rootProductId,
              itemProductId: seedItemId,
              sortOrder: const Value<int>(0),
            ),
          );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(_testPrefs),
        ],
      );
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
      await tester.ensureVisible(
        find.byKey(ValueKey<String>('product-set-builder-$rootProductId')),
      );
      await tester.tap(
        find.byKey(ValueKey<String>('product-set-builder-$rootProductId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Included Items'), findsWidgets);
      expect(find.text('Required Choices'), findsWidgets);
      expect(find.text('Extras'), findsWidgets);
      expect(find.text('Rules'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey<String>('semantic-add-item')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('semantic-product-picker-item-$eggId')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Required Choices').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-add-choice-group')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('semantic-choice-group-name-input')),
        'Drink Choice',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-choice-group-add-option')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('semantic-product-picker-item-$teaId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-choice-group-save')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Extras').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-add-extra-item')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-product-picker-item-$hashBrownId'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-builder-save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set configuration saved.'), findsOneWidget);

      final config = await BreakfastConfigurationRepository(
        db,
      ).loadAdminConfigurationDraft(rootProductId);
      expect(config.setItems, hasLength(2));
      expect(
        config.setItems.map((item) => item.itemName),
        containsAll(<String>['Beans', 'Egg']),
      );
      expect(config.choiceGroups, hasLength(1));
      expect(config.choiceGroups.single.name, 'Drink Choice');
      expect(config.choiceGroups.single.members.single.itemName, 'Tea');
      expect(config.extras, hasLength(1));
      expect(config.extras.single.itemName, 'Hash Brown');
      expect(find.byType(PosScreen), findsNothing);
    },
  );

  testWidgets(
    'admin set builder supports removing items and shows extra prices',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int breakfastCategoryId = await insertCategory(
        db,
        name: 'Breakfast',
      );
      final int drinksCategoryId = await insertCategory(db, name: 'Drinks');
      await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Set Breakfast',
        priceMinor: 500,
      );
      final int seedItemId = await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Beans',
        priceMinor: 90,
      );
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Egg',
        priceMinor: 120,
      );
      final int teaId = await insertProduct(
        db,
        categoryId: drinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
      );
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: 1,
              itemProductId: seedItemId,
              sortOrder: const Value<int>(0),
            ),
          );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(_testPrefs),
        ],
      );
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
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('product-set-builder-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('product-set-builder-1')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('semantic-add-item')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('semantic-product-picker-item-$eggId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('£1.20'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-set-item-delete-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('semantic-set-item-1')),
        findsNothing,
      );

      await tester.tap(find.text('Extras').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-add-extra-item')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('semantic-product-picker-item-$teaId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('£1.50'), findsOneWidget);
    },
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
  expect(find.byType(PosScreen), findsOneWidget);
}

void _setLargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
