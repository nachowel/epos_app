import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/presentation/screens/admin/admin_breakfast_set_editor_screen.dart';
import 'package:epos_app/presentation/screens/admin/admin_breakfast_sets_screen.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
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
    'breakfast set editor shell shows repository-backed sections and enables save for a valid draft',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int hotDrinksCategoryId = await insertCategory(
        db,
        name: 'Hot Drinks',
      );
      final int rootProductId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 4',
        priceMinor: 950,
      );
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Egg',
        priceMinor: 120,
      );
      final int baconId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Bacon',
        priceMinor: 180,
      );
      final int teaId = await insertProduct(
        db,
        categoryId: hotDrinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
      );
      final int coffeeId = await insertProduct(
        db,
        categoryId: hotDrinksCategoryId,
        name: 'Coffee',
        priceMinor: 180,
      );

      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: rootProductId,
              itemProductId: eggId,
              defaultQuantity: const Value<int>(2),
              sortOrder: const Value<int>(0),
            ),
          );
      final int drinkGroupId = await db
          .into(db.modifierGroups)
          .insert(
            ModifierGroupsCompanion.insert(
              productId: rootProductId,
              name: 'Tea or Coffee',
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: rootProductId,
              groupId: Value<int?>(drinkGroupId),
              itemProductId: Value<int?>(teaId),
              name: 'Tea',
              type: 'choice',
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: rootProductId,
              groupId: Value<int?>(drinkGroupId),
              itemProductId: Value<int?>(coffeeId),
              name: 'Coffee',
              type: 'choice',
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

      container
          .read(appRouterProvider)
          .go('/admin/breakfast-sets/$rootProductId');
      await tester.pumpAndSettle();

      expect(find.byType(AdminBreakfastSetEditorScreen), findsOneWidget);
      expect(find.text('Set Info'), findsOneWidget);
      expect(find.text('Set Items'), findsOneWidget);
      expect(find.text('Choice Groups'), findsOneWidget);
      expect(find.text('Extras Pool'), findsOneWidget);
      expect(find.text('Validation Summary'), findsOneWidget);

      expect(find.text('Set 4'), findsOneWidget);
      expect(find.text('Set Breakfast'), findsOneWidget);
      expect(find.text('Included Units'), findsOneWidget);
      expect(find.text('Item Rows'), findsOneWidget);
      expect(find.text('Egg'), findsOneWidget);
      expect(find.text('Tea or Coffee'), findsOneWidget);
      expect(find.text('Tea'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);
      expect(find.text('Draft is valid. Save is available.'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('breakfast-editor-qty-0-2')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-add-item')),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 items selected'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey<String>('breakfast-editor-product-item-$baconId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 item selected'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-product-submit')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bacon'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('breakfast-editor-qty-1-1')),
        findsOneWidget,
      );

      final ElevatedButton saveButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('breakfast-editor-save')),
      );
      expect(saveButton.onPressed, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-save')),
      );
      await tester.pump();

      expect(find.text('Breakfast set configuration saved.'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminBreakfastSetsScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('breakfast-set-card-$rootProductId')),
          matching: find.text('Valid'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('breakfast-set-card-$rootProductId')),
          matching: find.text('Ready for editing.'),
        ),
        findsOneWidget,
      );

      container
          .read(appRouterProvider)
          .go('/admin/breakfast-sets/$rootProductId');
      await tester.pumpAndSettle();

      expect(find.text('Bacon'), findsOneWidget);
    },
  );

  testWidgets(
    'breakfast set editor keeps save disabled for an incomplete draft',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int hotDrinksCategoryId = await insertCategory(
        db,
        name: 'Hot Drinks',
      );
      final int rootProductId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 7',
        priceMinor: 1050,
      );
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Egg',
        priceMinor: 120,
      );
      final int sausageId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Sausage',
        priceMinor: 180,
      );
      final int teaId = await insertProduct(
        db,
        categoryId: hotDrinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
      );
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: rootProductId,
              itemProductId: eggId,
              sortOrder: const Value<int>(0),
            ),
          );
      final int optionalDrinkGroupId = await db
          .into(db.modifierGroups)
          .insert(
            ModifierGroupsCompanion.insert(
              productId: rootProductId,
              name: 'Optional Drink',
              minSelect: const Value<int>(0),
              maxSelect: const Value<int>(1),
              includedQuantity: const Value<int>(1),
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: rootProductId,
              groupId: Value<int?>(optionalDrinkGroupId),
              itemProductId: Value<int?>(teaId),
              name: 'Tea',
              type: 'choice',
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

      container
          .read(appRouterProvider)
          .go('/admin/breakfast-sets/$rootProductId');
      await tester.pumpAndSettle();

      expect(find.text('Incomplete'), findsOneWidget);
      expect(
        find.text('Draft is incomplete: 1 warning(s) need attention.'),
        findsOneWidget,
      );
      expect(
        find.text('This set has no required choice groups defined.'),
        findsOneWidget,
      );

      final ElevatedButton saveButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('breakfast-editor-save')),
      );
      expect(saveButton.onPressed, isNull);
    },
  );

  testWidgets('bootstrapped default choice groups are editable and removable', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int setBreakfastCategoryId = await insertCategory(
      db,
      name: 'Set Breakfast',
    );
    final int hotDrinksCategoryId = await insertCategory(
      db,
      name: 'Hot Drinks',
    );
    final int bakeryCategoryId = await insertCategory(db, name: 'Bakery');
    final int rootProductId = await insertProduct(
      db,
      categoryId: setBreakfastCategoryId,
      name: 'Set Bootstrapped',
      priceMinor: 1100,
    );
    await insertProduct(
      db,
      categoryId: hotDrinksCategoryId,
      name: 'Tea',
      priceMinor: 150,
    );
    await insertProduct(
      db,
      categoryId: hotDrinksCategoryId,
      name: 'Latte',
      priceMinor: 180,
    );
    await insertProduct(
      db,
      categoryId: bakeryCategoryId,
      name: 'Toasts',
      priceMinor: 100,
    );
    await insertProduct(
      db,
      categoryId: bakeryCategoryId,
      name: 'Breads',
      priceMinor: 90,
    );

    await BreakfastConfigurationRepository(
      db,
    ).bootstrapBreakfastSetRoot(rootProductId);

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

    container
        .read(appRouterProvider)
        .go('/admin/breakfast-sets/$rootProductId');
    await tester.pumpAndSettle();

    expect(find.text('Tea or Coffee'), findsOneWidget);
    expect(find.text('Toast or Bread'), findsOneWidget);
    expect(find.text('Tea'), findsOneWidget);
    expect(find.text('Latte'), findsOneWidget);
    expect(find.text('Toasts'), findsOneWidget);
    expect(find.text('Breads'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('breakfast-editor-choice-name-0')),
      'Hot Drink',
    );
    await tester.pumpAndSettle();
    expect(find.text('Hot Drink'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('breakfast-editor-choice-remove-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Toast or Bread'), findsNothing);
    expect(find.text('Toasts'), findsNothing);
    expect(find.text('Breads'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('breakfast-editor-choice-group-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('breakfast-editor-choice-group-1')),
      findsNothing,
    );
  });

  testWidgets(
    'set item picker shows active Breakfast Items products even when hidden from POS',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
        isActive: false,
      );
      final int hotDrinksCategoryId = await insertCategory(
        db,
        name: 'Hot Drinks',
      );
      final int rootProductId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set Picker',
        priceMinor: 1100,
      );
      await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Hidden Active Egg',
        priceMinor: 120,
        isVisibleOnPos: false,
      );
      await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Hidden Inactive Bacon',
        priceMinor: 180,
        isActive: false,
        isVisibleOnPos: false,
      );
      await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Inactive Sausage',
        priceMinor: 190,
        isActive: false,
      );
      await insertProduct(
        db,
        categoryId: hotDrinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
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

      container
          .read(appRouterProvider)
          .go('/admin/breakfast-sets/$rootProductId');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-add-item')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hidden Active Egg'), findsOneWidget);
      expect(find.text('Hidden Inactive Bacon'), findsNothing);
      expect(find.text('Inactive Sausage'), findsNothing);
      expect(find.text('Tea'), findsNothing);
      expect(find.text('0 items selected'), findsOneWidget);
    },
  );

  testWidgets('set item picker carries selected quantities into the draft', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int setBreakfastCategoryId = await insertCategory(
      db,
      name: 'Set Breakfast',
    );
    final int breakfastItemsCategoryId = await insertCategory(
      db,
      name: 'Breakfast Items',
    );
    final int rootProductId = await insertProduct(
      db,
      categoryId: setBreakfastCategoryId,
      name: 'Set Multi Select',
      priceMinor: 1200,
    );
    final int eggId = await insertProduct(
      db,
      categoryId: breakfastItemsCategoryId,
      name: 'Egg',
      priceMinor: 120,
    );
    final int sausageId = await insertProduct(
      db,
      categoryId: breakfastItemsCategoryId,
      name: 'Sausage',
      priceMinor: 180,
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

    container
        .read(appRouterProvider)
        .go('/admin/breakfast-sets/$rootProductId');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('breakfast-editor-add-item')),
    );
    await tester.pumpAndSettle();

    final FilledButton addSelectedButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey<String>('breakfast-editor-product-submit')),
    );
    expect(addSelectedButton.onPressed, isNull);

    await tester.tap(
      find.byKey(ValueKey<String>('breakfast-editor-product-item-$eggId')),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 item selected'), findsOneWidget);
    expect(find.text('Add Set Item'), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey<String>('breakfast-editor-product-qty-inc-$eggId')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey<String>('breakfast-editor-product-qty-$eggId-2')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(ValueKey<String>('breakfast-editor-product-item-$sausageId')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 items selected'), findsOneWidget);
    expect(find.text('Add Set Item'), findsOneWidget);
    await tester.tap(
      find.byKey(
        ValueKey<String>('breakfast-editor-product-qty-inc-$sausageId'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey<String>('breakfast-editor-product-qty-$sausageId-2')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('breakfast-editor-product-submit')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Egg'), findsOneWidget);
    expect(find.text('Sausage'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('breakfast-editor-qty-0-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('breakfast-editor-qty-1-2')),
      findsOneWidget,
    );
    expect(find.text('Add Set Item'), findsNothing);
  });

  testWidgets(
    'set item picker disables already-added products and avoids duplicate rows',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int rootProductId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set Existing Item',
        priceMinor: 1200,
      );
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Egg',
        priceMinor: 120,
      );
      final int sausageId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Sausage',
        priceMinor: 180,
      );
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: rootProductId,
              itemProductId: eggId,
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

      container
          .read(appRouterProvider)
          .go('/admin/breakfast-sets/$rootProductId');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-add-item')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Already added. Edit quantity in the set items list.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(ValueKey<String>('breakfast-editor-product-item-$eggId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 items selected'), findsOneWidget);

      await tester.tap(
        find.byKey(
          ValueKey<String>('breakfast-editor-product-item-$sausageId'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>('breakfast-editor-product-qty-inc-$sausageId'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-product-submit')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('breakfast-editor-set-item-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('breakfast-editor-set-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('breakfast-editor-set-item-2')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('breakfast-editor-qty-0-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('breakfast-editor-qty-1-2')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'set item picker uses the same active Breakfast Items pool for Set 1 and Set 3',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      await insertCategory(db, name: 'Breakfast Items', isActive: false);
      final int activeBreakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int hotDrinksCategoryId = await insertCategory(
        db,
        name: 'Hot Drinks',
      );
      final int set1Id = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 1',
        priceMinor: 1100,
      );
      await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 2',
        priceMinor: 1200,
      );
      final int set3Id = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 3',
        priceMinor: 1300,
      );
      final int eggId = await insertProduct(
        db,
        categoryId: activeBreakfastItemsCategoryId,
        name: 'Egg',
        priceMinor: 120,
      );
      final int baconId = await insertProduct(
        db,
        categoryId: activeBreakfastItemsCategoryId,
        name: 'Bacon',
        priceMinor: 180,
      );
      await insertProduct(
        db,
        categoryId: hotDrinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
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

      for (final int rootProductId in <int>[set1Id, set3Id]) {
        container
            .read(appRouterProvider)
            .go('/admin/breakfast-sets/$rootProductId');
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('breakfast-editor-add-item')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(ValueKey<String>('breakfast-editor-product-item-$eggId')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            ValueKey<String>('breakfast-editor-product-item-$baconId'),
          ),
          findsOneWidget,
        );
        expect(find.text('Tea'), findsNothing);

        await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'set item picker shows empty state when no active breakfast products exist',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int hotDrinksCategoryId = await insertCategory(
        db,
        name: 'Hot Drinks',
      );
      final int rootProductId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set Empty Picker',
        priceMinor: 1100,
      );
      await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Archived Egg',
        priceMinor: 120,
        isActive: false,
      );
      await insertProduct(
        db,
        categoryId: hotDrinksCategoryId,
        name: 'Visible Tea',
        priceMinor: 150,
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

      container
          .read(appRouterProvider)
          .go('/admin/breakfast-sets/$rootProductId');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-add-item')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No available included items to add. Included Items come from the set-item pool only; Choice Members can reuse existing active products from other POS categories.',
        ),
        findsOneWidget,
      );
      expect(find.text('Archived Egg'), findsNothing);
      expect(find.text('Visible Tea'), findsNothing);
    },
  );

  testWidgets('breakfast set editor can create and apply an extras preset', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int setBreakfastCategoryId = await insertCategory(
      db,
      name: 'Set Breakfast',
    );
    final int breakfastItemsCategoryId = await insertCategory(
      db,
      name: 'Breakfast Items',
    );
    final int rootProductId = await insertProduct(
      db,
      categoryId: setBreakfastCategoryId,
      name: 'Set Extras Preset',
      priceMinor: 1150,
    );
    await insertProduct(
      db,
      categoryId: breakfastItemsCategoryId,
      name: 'Egg',
      priceMinor: 120,
    );
    final int extraBaconId = await insertProduct(
      db,
      categoryId: breakfastItemsCategoryId,
      name: 'Extra Bacon',
      priceMinor: 180,
    );
    final int extraMushroomId = await insertProduct(
      db,
      categoryId: breakfastItemsCategoryId,
      name: 'Extra Mushroom',
      priceMinor: 170,
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

    container
        .read(appRouterProvider)
        .go('/admin/breakfast-sets/$rootProductId');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>('breakfast-editor-extra-create-preset'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('breakfast-editor-extra-preset-name')),
      'Standard Breakfast Extras',
    );
    await tester.tap(
      find.byKey(
        ValueKey<String>('breakfast-editor-extra-preset-product-$extraBaconId'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'breakfast-editor-extra-preset-product-$extraMushroomId',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('breakfast-editor-extra-preset-save')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Breakfast extras preset saved.'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('breakfast-editor-extra-apply-preset')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('breakfast-editor-extra-preset-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Extra Bacon'), findsOneWidget);
    expect(find.text('Extra Mushroom'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('breakfast-editor-extra-remove-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Extra Bacon'), findsOneWidget);
    expect(find.text('Extra Mushroom'), findsNothing);
  });

  testWidgets(
    'breakfast set editor set items update local draft with inline validation',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int hotDrinksCategoryId = await insertCategory(
        db,
        name: 'Hot Drinks',
      );
      final int rootProductId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 9',
        priceMinor: 1250,
      );
      final int otherRootId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 12',
        priceMinor: 1350,
      );
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Egg',
        priceMinor: 120,
      );
      final int sausageId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Sausage',
        priceMinor: 180,
      );
      final int teaId = await insertProduct(
        db,
        categoryId: hotDrinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
      );

      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: rootProductId,
              itemProductId: eggId,
              sortOrder: const Value<int>(0),
            ),
          );
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: otherRootId,
              itemProductId: eggId,
              sortOrder: const Value<int>(0),
            ),
          );
      final int drinkGroupId = await db
          .into(db.modifierGroups)
          .insert(
            ModifierGroupsCompanion.insert(
              productId: rootProductId,
              name: 'Tea or Coffee',
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: rootProductId,
              groupId: Value<int?>(drinkGroupId),
              itemProductId: Value<int?>(teaId),
              name: 'Tea',
              type: 'choice',
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

      container
          .read(appRouterProvider)
          .go('/admin/breakfast-sets/$rootProductId');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-add-item')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Already added. Edit quantity in the set items list.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          ValueKey<String>('breakfast-editor-product-item-$sausageId'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-product-submit')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-editor-qty-1-1')),
        '0',
      );
      await tester.pumpAndSettle();

      expect(find.text('Quantity must be greater than zero.'), findsOneWidget);
      expect(find.textContaining('Draft is invalid:'), findsOneWidget);
      expect(find.text('Blocking Errors'), findsOneWidget);
      expect(find.text('Set Items'), findsWidgets);

      final ElevatedButton saveButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('breakfast-editor-save')),
      );
      expect(saveButton.onPressed, isNull);
    },
  );

  testWidgets(
    'breakfast set editor choice groups update local draft with inline validation',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int hotDrinksCategoryId = await insertCategory(
        db,
        name: 'Hot Drinks',
      );
      final int rootProductId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 14',
        priceMinor: 1450,
      );
      final int otherRootId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 15',
        priceMinor: 1550,
      );
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Egg',
        priceMinor: 120,
      );
      final int teaId = await insertProduct(
        db,
        categoryId: hotDrinksCategoryId,
        name: 'Tea',
        priceMinor: 150,
      );

      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: rootProductId,
              itemProductId: eggId,
              sortOrder: const Value<int>(0),
            ),
          );
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: otherRootId,
              itemProductId: eggId,
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

      container
          .read(appRouterProvider)
          .go('/admin/breakfast-sets/$rootProductId');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-choice-add-group')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-editor-choice-name-0')),
        'Drink Choice',
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-editor-choice-min-0-0')),
        '2',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-editor-choice-max-0-1')),
        '1',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('breakfast-editor-choice-included-0-1'),
        ),
        '2',
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Minimum selection cannot be greater than maximum selection.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Included quantity cannot be greater than maximum selection.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Choice groups must contain at least one member.'),
        findsNWidgets(2),
      );
      expect(find.textContaining('Draft is invalid:'), findsOneWidget);
      expect(find.text('Blocking Errors'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('breakfast-editor-choice-add-member-0'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('breakfast-editor-product-item-$teaId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tea'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>('breakfast-editor-choice-add-member-0'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('breakfast-editor-product-item-$teaId')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Duplicate members are not allowed in the same group.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('breakfast-editor-choice-add-member-0'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>('breakfast-editor-product-item-$rootProductId'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The set root cannot be selected as a choice member.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey<String>('breakfast-editor-choice-member-remove-0-2'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('The set root cannot be selected as a choice member.'),
        findsNothing,
      );
      expect(find.text('Choice Groups'), findsWidgets);

      final ElevatedButton saveButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('breakfast-editor-save')),
      );
      expect(saveButton.onPressed, isNull);
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
