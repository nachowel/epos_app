import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/domain/models/product_modifier.dart';
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
    'product tile opens a product-scoped modifiers modal and keeps legacy rows visible',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int categoryId = await insertCategory(db, name: 'Burgers');
      final int burgerId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Burger',
        priceMinor: 700,
        hasModifiers: true,
      );
      final int wrapId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Wrap',
        priceMinor: 650,
        hasModifiers: true,
      );

      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: burgerId,
              name: 'Fried Onion',
              type: 'extra',
              extraPriceMinor: const Value<int>(0),
              priceBehavior: const Value<String?>('free'),
              uiSection: const Value<String?>('toppings'),
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: burgerId,
              name: 'Burger Sauce',
              type: 'extra',
              extraPriceMinor: const Value<int>(0),
              priceBehavior: const Value<String?>('free'),
              uiSection: const Value<String?>('sauces'),
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: burgerId,
              name: 'Chips',
              type: 'extra',
              extraPriceMinor: const Value<int>(150),
              priceBehavior: const Value<String?>('paid'),
              uiSection: const Value<String?>('add_ins'),
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: wrapId,
              name: 'Other Extra',
              type: 'extra',
              extraPriceMinor: const Value<int>(100),
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: burgerId,
              name: 'Legacy Butter',
              type: 'included',
              extraPriceMinor: const Value<int>(0),
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
        find.byKey(ValueKey<String>('product-modifiers-$burgerId')),
      );
      await tester.tap(
        find.byKey(ValueKey<String>('product-modifiers-$burgerId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Modifiers: Burger'), findsOneWidget);
      expect(find.text('Fried Onion'), findsOneWidget);
      expect(find.text('Burger Sauce'), findsOneWidget);
      expect(find.text('Chips'), findsOneWidget);
      expect(find.text('Legacy Butter'), findsOneWidget);
      expect(find.text('Other Extra'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('modifier-section-free')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('modifier-section-sauces')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('modifier-section-addIns')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'single-add existing product selection creates a linked modifier row',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int categoryId = await insertCategory(db, name: 'Burgers');
      final int burgerId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Burger',
        priceMinor: 700,
        hasModifiers: true,
      );
      final int beansProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Beans',
        priceMinor: 120,
        isVisibleOnPos: false,
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
        find.byKey(ValueKey<String>('product-modifiers-$burgerId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-add-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('modifier-product-search')),
        'Beans',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('modifier-product-option-$beansProductId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-type-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.extraModifiers).last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-price-behavior-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paid').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-ui-section-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add-ins').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.saveSettings));
      await tester.pumpAndSettle();

      expect(find.text('Modifier created.'), findsOneWidget);
      final ModifierRepository repository = ModifierRepository(db);
      ProductModifier beans = (await repository.getByProductId(
        burgerId,
        activeOnly: false,
      )).single;
      expect(beans.name, 'Beans');
      expect(beans.itemProductId, beansProductId);
      expect(beans.priceBehavior, ModifierPriceBehavior.paid);
      expect(beans.uiSection, ModifierUiSection.addIns);
      expect(beans.extraPriceMinor, 120);
    },
  );

  testWidgets(
    'bulk add from category adds missing active products, skips duplicates, and applies selected settings',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int burgersCategoryId = await insertCategory(db, name: 'Burgers');
      final int saucesCategoryId = await insertCategory(db, name: 'Sauces');
      final int burgerId = await insertProduct(
        db,
        categoryId: burgersCategoryId,
        name: 'Burger',
        priceMinor: 700,
        hasModifiers: true,
      );
      final int ketchupId = await insertProduct(
        db,
        categoryId: saucesCategoryId,
        name: 'Ketchup',
        priceMinor: 40,
      );
      final int mayoId = await insertProduct(
        db,
        categoryId: saucesCategoryId,
        name: 'Mayo',
        priceMinor: 55,
      );
      final int bbqId = await insertProduct(
        db,
        categoryId: saucesCategoryId,
        name: 'BBQ',
        priceMinor: 65,
      );
      await insertProduct(
        db,
        categoryId: saucesCategoryId,
        name: 'Archived Sauce',
        priceMinor: 90,
        isActive: false,
      );

      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: burgerId,
              itemProductId: Value<int?>(ketchupId),
              name: 'Ketchup',
              type: 'extra',
              extraPriceMinor: const Value<int>(40),
              priceBehavior: const Value<String?>('paid'),
              uiSection: const Value<String?>('sauces'),
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

      await tester.tap(
        find.byKey(ValueKey<String>('product-modifiers-$burgerId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-add-button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-mode-bulk')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Select a source category to preview the bulk add.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-bulk-category-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sauces').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Will add 2 product(s). Skip 1 already linked.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-type-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.extraModifiers).last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-price-behavior-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paid').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-ui-section-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sauces').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-submit-button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Bulk add complete. Added 2 product(s). Skipped 1 already linked.',
        ),
        findsOneWidget,
      );

      final ModifierRepository repository = ModifierRepository(db);
      final List<ProductModifier> modifiers = await repository.getByProductId(
        burgerId,
        activeOnly: false,
      );

      expect(modifiers, hasLength(3));
      expect(
        modifiers.where(
          (ProductModifier modifier) => modifier.itemProductId == ketchupId,
        ),
        hasLength(1),
      );
      expect(
        modifiers.where(
          (ProductModifier modifier) => modifier.itemProductId == mayoId,
        ),
        hasLength(1),
      );
      expect(
        modifiers.where(
          (ProductModifier modifier) => modifier.itemProductId == bbqId,
        ),
        hasLength(1),
      );

      final ProductModifier mayoModifier = modifiers.singleWhere(
        (ProductModifier modifier) => modifier.itemProductId == mayoId,
      );
      final ProductModifier bbqModifier = modifiers.singleWhere(
        (ProductModifier modifier) => modifier.itemProductId == bbqId,
      );

      expect(mayoModifier.type, ModifierType.extra);
      expect(mayoModifier.priceBehavior, ModifierPriceBehavior.paid);
      expect(mayoModifier.uiSection, ModifierUiSection.sauces);
      expect(mayoModifier.isActive, isFalse);
      expect(mayoModifier.extraPriceMinor, 55);

      expect(bbqModifier.type, ModifierType.extra);
      expect(bbqModifier.priceBehavior, ModifierPriceBehavior.paid);
      expect(bbqModifier.uiSection, ModifierUiSection.sauces);
      expect(bbqModifier.isActive, isFalse);
      expect(bbqModifier.extraPriceMinor, 65);
    },
  );

  testWidgets('bulk mode without category fails validation', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final app_db.AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final int burgersCategoryId = await insertCategory(db, name: 'Burgers');
    final int burgerId = await insertProduct(
      db,
      categoryId: burgersCategoryId,
      name: 'Burger',
      priceMinor: 700,
      hasModifiers: true,
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
      find.byKey(ValueKey<String>('product-modifiers-$burgerId')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('modifier-add-button')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('modifier-mode-bulk')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('modifier-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Select a source category before bulk add.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'selection state and validation share the same linked product source of truth',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int categoryId = await insertCategory(db, name: 'Burgers');
      final int burgerId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Burger',
        priceMinor: 700,
        hasModifiers: true,
      );
      final int chipsProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Chips',
        priceMinor: 150,
        isVisibleOnPos: false,
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
        find.byKey(ValueKey<String>('product-modifiers-$burgerId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-add-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('modifier-product-search')),
        'Chips',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.saveSettings).last);
      await tester.pumpAndSettle();

      expect(
        find.text('Select a product before saving the modifier.'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('modifier-product-option-$chipsProductId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Select a product before saving the modifier.'),
        findsNothing,
      );
      expect(find.textContaining('Linked product: Chips'), findsOneWidget);

      await tester.tap(find.text(AppStrings.saveSettings).last);
      await tester.pumpAndSettle();

      final ModifierRepository repository = ModifierRepository(db);
      ProductModifier modifier = (await repository.getByProductId(
        burgerId,
        activeOnly: false,
      )).single;
      expect(modifier.itemProductId, chipsProductId);
      expect(modifier.name, 'Chips');

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-add-button')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('modifier-product-search')),
        'Chips',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('modifier-product-option-$chipsProductId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Linked product: Chips'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey<String>('modifier-product-search')),
        '',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Linked product: Chips'), findsNothing);

      await tester.tap(find.text(AppStrings.saveSettings).last);
      await tester.pumpAndSettle();

      expect(
        find.text('Select a product before saving the modifier.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'quick-created product is auto-selected and stays off the POS catalog by default',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int categoryId = await insertCategory(db, name: 'Burgers');
      final int burgerId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Burger',
        priceMinor: 700,
        hasModifiers: true,
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
        find.byKey(ValueKey<String>('product-modifiers-$burgerId')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-add-button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-new-product-button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('quick-product-name')),
        'Sauce Pot',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('quick-product-price')),
        '90',
      );
      await tester.tap(find.text(AppStrings.saveSettings).last);
      await tester.pumpAndSettle();

      expect(
        find.text('Product created and selected for modifier linking.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog).last,
          matching: find.text('Sauce Pot'),
        ),
        findsWidgets,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-type-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.extraModifiers).last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-price-behavior-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paid').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('modifier-ui-section-field')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add-ins').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.saveSettings));
      await tester.pumpAndSettle();

      final ModifierRepository modifierRepository = ModifierRepository(db);
      final ProductRepository productRepository = ProductRepository(db);
      final ProductModifier modifier = (await modifierRepository.getByProductId(
        burgerId,
        activeOnly: false,
      )).single;
      final app_db.Product? linkedProductRow =
          await (db.select(db.products)..where(
                (app_db.$ProductsTable t) =>
                    t.id.equals(modifier.itemProductId!),
              ))
              .getSingleOrNull();

      expect(linkedProductRow, isNotNull);
      expect(linkedProductRow!.name, 'Sauce Pot');
      expect(modifier.itemProductId, linkedProductRow.id);
      expect(modifier.name, 'Sauce Pot');
      expect(modifier.extraPriceMinor, 90);
      expect(
        (await productRepository.getActiveCatalogProducts()).any(
          (product) => product.id == linkedProductRow.id,
        ),
        isFalse,
      );
    },
  );
}

ProviderContainer _makeContainer(app_db.AppDatabase db) {
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
