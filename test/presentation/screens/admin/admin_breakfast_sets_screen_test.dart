import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart' hide Product;
import 'package:epos_app/domain/models/app_log_entry.dart';
import 'package:epos_app/domain/models/product.dart';
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
    'breakfast set list shows repository-backed valid, incomplete, and invalid roots',
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

      final int validRootId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 1',
        priceMinor: 850,
      );
      final int incompleteRootId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 2',
        priceMinor: 950,
      );
      final int invalidRootId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set 3',
        priceMinor: 1050,
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
      final int toastId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Toast',
        priceMinor: 90,
      );
      final int breadId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Bread',
        priceMinor: 90,
      );

      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: validRootId,
              itemProductId: eggId,
              defaultQuantity: const Value<int>(2),
              sortOrder: const Value<int>(0),
            ),
          );
      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: validRootId,
              itemProductId: baconId,
              defaultQuantity: const Value<int>(1),
              sortOrder: const Value<int>(1),
            ),
          );
      final int drinkGroupId = await db
          .into(db.modifierGroups)
          .insert(
            ModifierGroupsCompanion.insert(
              productId: validRootId,
              name: 'Tea or Coffee',
            ),
          );
      final int breadGroupId = await db
          .into(db.modifierGroups)
          .insert(
            ModifierGroupsCompanion.insert(
              productId: validRootId,
              name: 'Toast or Bread',
              minSelect: const Value<int>(0),
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: validRootId,
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
              productId: validRootId,
              groupId: Value<int?>(drinkGroupId),
              itemProductId: Value<int?>(coffeeId),
              name: 'Coffee',
              type: 'choice',
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: validRootId,
              groupId: Value<int?>(breadGroupId),
              itemProductId: Value<int?>(toastId),
              name: 'Toast',
              type: 'choice',
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: validRootId,
              groupId: Value<int?>(breadGroupId),
              itemProductId: Value<int?>(breadId),
              name: 'Bread',
              type: 'choice',
            ),
          );

      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: invalidRootId,
              itemProductId: validRootId,
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

      container.read(appRouterProvider).go('/admin/breakfast-sets');
      await tester.pumpAndSettle();

      expect(find.byType(AdminBreakfastSetsScreen), findsOneWidget);
      expect(find.text('Breakfast Set Configuration'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('breakfast-set-new')),
        findsOneWidget,
      );

      expect(
        find.byKey(ValueKey<String>('breakfast-set-card-$validRootId')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('breakfast-set-card-$validRootId')),
          matching: find.text('Valid'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('breakfast-set-card-$validRootId')),
          matching: find.text('Ready for editing.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('breakfast-set-card-$validRootId')),
          matching: find.text('Included Units'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('breakfast-set-card-$validRootId')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('breakfast-set-card-$validRootId')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byKey(
            ValueKey<String>('breakfast-set-card-$incompleteRootId'),
          ),
          matching: find.text('Incomplete'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey<String>('breakfast-set-card-$incompleteRootId'),
          ),
          matching: find.text('Configuration not started.'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('breakfast-set-card-$invalidRootId')),
          matching: find.text('Invalid'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('breakfast-set-card-$invalidRootId')),
          matching: find.text(
            'A semantic set root cannot be used as a set item.',
          ),
        ),
        findsOneWidget,
      );

      expect(find.text('Egg'), findsNothing);

      await tester.tap(
        find.byKey(ValueKey<String>('breakfast-set-edit-$validRootId')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AdminBreakfastSetEditorScreen), findsOneWidget);
      expect(find.text('Set Info'), findsOneWidget);
    },
  );

  testWidgets(
    'breakfast set new button opens a real create dialog with validation',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
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

      container.read(appRouterProvider).go('/admin/breakfast-sets');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('breakfast-set-new')));
      await tester.pumpAndSettle();

      expect(find.text('Create Breakfast Set'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('breakfast-set-create-name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('breakfast-set-create-price')),
        findsOneWidget,
      );
      expect(
        find.text('New breakfast set flow is not available yet.'),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-set-create-submit')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set name is required.'), findsOneWidget);
      expect(find.text('Enter a valid base price.'), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-set-create-name')),
        'Set New',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-set-create-price')),
        'abc',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-set-create-submit')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid base price.'), findsOneWidget);
      expect(find.text('Create Breakfast Set'), findsOneWidget);
    },
  );

  testWidgets(
    'breakfast set create success creates root product and opens editor',
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
      final int bakeryCategoryId = await insertCategory(db, name: 'Bakery');
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Egg',
        priceMinor: 120,
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

      container.read(appRouterProvider).go('/admin/breakfast-sets');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('breakfast-set-new')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-set-create-name')),
        'Set Fresh',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-set-create-price')),
        '9.50',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-set-create-submit')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminBreakfastSetEditorScreen), findsOneWidget);
      expect(
        find.text(
          'Breakfast set created. Configure included items and choices.',
        ),
        findsOneWidget,
      );

      final products = await ProductRepository(
        db,
      ).getByCategory(setBreakfastCategoryId, activeOnly: false);
      expect(products, hasLength(1));
      expect(products.single.name, 'Set Fresh');
      expect(products.single.priceMinor, 950);
      expect(products.single.isActive, isTrue);
      expect(products.single.isVisibleOnPos, isTrue);
      expect(products.single.hasModifiers, isFalse);

      final BreakfastConfigurationRepository breakfastRepository =
          BreakfastConfigurationRepository(db);
      final profiles = await breakfastRepository.loadConfigurationProfiles(
        <int>[products.single.id],
      );
      final draft = await breakfastRepository.loadAdminConfigurationDraft(
        products.single.id,
      );
      expect(profiles[products.single.id]?.hasSemanticSetConfig, isTrue);
      expect(draft.choiceGroups, hasLength(2));
      expect(draft.choiceGroups.map((group) => group.name), <String>[
        'Tea or Coffee',
        'Toast or Bread',
      ]);
      expect(draft.choiceGroups.first.minSelect, 1);
      expect(draft.choiceGroups.first.maxSelect, 1);
      expect(draft.choiceGroups.first.includedQuantity, 1);
      expect(
        draft.choiceGroups.first.members.map((member) => member.itemName),
        <String>['Tea', 'Latte'],
      );
      expect(
        draft.choiceGroups.last.members.map((member) => member.itemName),
        <String>['Toasts', 'Breads'],
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-editor-add-item')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey<String>('breakfast-editor-product-item-$eggId')),
        findsOneWidget,
      );
      expect(find.text('Egg'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AdminBreakfastSetsScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey<String>('breakfast-set-card-${products.single.id}'),
          ),
          matching: find.text('Set Fresh'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey<String>('breakfast-set-card-${products.single.id}'),
          ),
          matching: find.text('Invalid'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            ValueKey<String>('breakfast-set-card-${products.single.id}'),
          ),
          matching: find.textContaining(
            'Semantic set products must contain at least one set item.',
          ),
        ),
        findsOneWidget,
      );

      container.read(appRouterProvider).go('/admin/products');
      await tester.pumpAndSettle();

      final Finder productTile = find.byKey(
        ValueKey<String>('product-tile-${products.single.id}'),
      );
      expect(productTile, findsOneWidget);
      expect(
        find.descendant(
          of: productTile,
          matching: find.text('Type: Set Product'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: productTile,
          matching: find.byKey(
            ValueKey<String>('product-set-builder-${products.single.id}'),
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'breakfast set create succeeds even when default choice products are missing',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      await insertCategory(db, name: 'Set Breakfast');

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

      container.read(appRouterProvider).go('/admin/breakfast-sets');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('breakfast-set-new')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-set-create-name')),
        'Set Missing Defaults',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-set-create-price')),
        '8.50',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-set-create-submit')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminBreakfastSetEditorScreen), findsOneWidget);

      final products = await ProductRepository(db).getAll(activeOnly: false);
      final Product createdProduct = products.singleWhere(
        (Product product) => product.name == 'Set Missing Defaults',
      );
      final BreakfastConfigurationRepository breakfastRepository =
          BreakfastConfigurationRepository(db);
      final draft = await breakfastRepository.loadAdminConfigurationDraft(
        createdProduct.id,
      );

      expect(draft.choiceGroups.map((group) => group.name), <String>[
        'Tea or Coffee',
        'Toast or Bread',
      ]);
      expect(draft.choiceGroups.first.members, isEmpty);
      expect(draft.choiceGroups.last.members, isEmpty);
    },
  );

  testWidgets(
    'breakfast set create path logs an empty included-item pool when Breakfast Items has no active products',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final MemoryAppLogSink sink = MemoryAppLogSink();
      final StructuredAppLogger logger = StructuredAppLogger(
        sinks: <AppLogSink>[sink],
        enableInfoLogs: true,
      );
      addTearDown(logger.dispose);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Archived Egg',
        priceMinor: 120,
        isActive: false,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(_testPrefs),
          appLoggerProvider.overrideWithValue(logger),
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

      container.read(appRouterProvider).go('/admin/breakfast-sets');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('breakfast-set-new')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-set-create-name')),
        'Set Empty Pool',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('breakfast-set-create-price')),
        '8.50',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('breakfast-set-create-submit')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminBreakfastSetEditorScreen), findsOneWidget);

      final createdProducts = await ProductRepository(
        db,
      ).getByCategory(setBreakfastCategoryId, activeOnly: false);
      final createdProduct = createdProducts.singleWhere(
        (product) => product.name == 'Set Empty Pool',
      );

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

      final AppLogEntry poolEvent = sink.entries.lastWhere(
        (AppLogEntry entry) =>
            entry.eventType == 'breakfast_set_item_pool_resolved' &&
            entry.entityId == '${createdProduct.id}',
      );
      expect(poolEvent.metadata['matching_category_names'], <String>[
        'Breakfast Items',
      ]);
      expect(poolEvent.metadata['active_product_count_before_filter'], 0);
      expect(poolEvent.metadata['active_product_count_after_filter'], 0);
      expect(poolEvent.metadata['final_available_set_item_products_length'], 0);

      final AppLogEntry providerEvent = sink.entries.lastWhere(
        (AppLogEntry entry) =>
            entry.eventType == 'admin_breakfast_set_editor_data_received' &&
            entry.entityId == '${createdProduct.id}',
      );
      expect(
        providerEvent.metadata['editor_available_set_item_products_length'],
        0,
      );

      final AppLogEntry pickerEvent = sink.entries.lastWhere(
        (AppLogEntry entry) =>
            entry.eventType == 'admin_breakfast_set_item_picker_opened' &&
            entry.entityId == '${createdProduct.id}',
      );
      expect(
        pickerEvent.metadata['source_available_set_item_products_length'],
        0,
      );
      expect(pickerEvent.metadata['ui_picker_row_count'], 0);
    },
  );

  testWidgets('breakfast set create blocks duplicate names in Set Breakfast', (
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
    await insertProduct(
      db,
      categoryId: setBreakfastCategoryId,
      name: 'Set Existing',
      priceMinor: 800,
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

    container.read(appRouterProvider).go('/admin/breakfast-sets');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('breakfast-set-new')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('breakfast-set-create-name')),
      'Set Existing',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('breakfast-set-create-price')),
      '10.00',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('breakfast-set-create-submit')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdminBreakfastSetsScreen), findsOneWidget);
    expect(
      find.text(
        'A breakfast set with this name already exists in Set Breakfast.',
      ),
      findsWidgets,
    );

    final products = await ProductRepository(
      db,
    ).getByCategory(setBreakfastCategoryId, activeOnly: false);
    expect(products, hasLength(1));
  });

  testWidgets(
    'breakfast set list treats saved required choice groups the same way as the editor',
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
      final int drinksCategoryId = await insertCategory(db, name: 'Drinks');

      final int rootProductId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'Set Custom',
        priceMinor: 875,
      );
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
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
              productId: rootProductId,
              itemProductId: eggId,
              sortOrder: const Value<int>(0),
            ),
          );
      final int drinkGroupId = await db
          .into(db.modifierGroups)
          .insert(
            ModifierGroupsCompanion.insert(
              productId: rootProductId,
              name: 'Drink choice',
              minSelect: const Value<int>(1),
              maxSelect: const Value<int>(1),
              includedQuantity: const Value<int>(1),
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

      container.read(appRouterProvider).go('/admin/breakfast-sets');
      await tester.pumpAndSettle();

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
      expect(find.textContaining('required elements missing'), findsNothing);

      await tester.tap(
        find.byKey(ValueKey<String>('breakfast-set-edit-$rootProductId')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminBreakfastSetEditorScreen), findsOneWidget);
      expect(find.text('Valid'), findsOneWidget);
      expect(find.text('Draft is valid. Save is available.'), findsOneWidget);
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
