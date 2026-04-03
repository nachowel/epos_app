import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/cart_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:epos_app/presentation/screens/pos/widgets/modifier_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

late SharedPreferences _testPrefs;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _testPrefs = await SharedPreferences.getInstance();
  });

  group('Admin Set Builder terminology', () {
    testWidgets(
      'admin products screen shows Set Builder button and Set Product role chip',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = createTestDatabase();
        addTearDown(db.close);

        await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
        final int categoryId = await insertCategory(db, name: 'Breakfast');
        final int rootProductId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Set Breakfast',
          priceMinor: 500,
        );
        final int eggId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Egg',
          priceMinor: 120,
        );

        await db
            .into(db.setItems)
            .insert(
              SetItemsCompanion.insert(
                productId: rootProductId,
                itemProductId: eggId,
                sortOrder: const Value<int>(1),
                isRemovable: const Value<bool>(true),
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

        // Button should say "Set Builder", not "Configure Set"
        expect(
          find.byKey(ValueKey<String>('product-set-builder-$rootProductId')),
          findsOneWidget,
        );
        expect(find.text('Configure Set'), findsNothing);

        // Role chip should say "Set Product", not "Semantic Set"
        expect(find.text('Type: Set Product'), findsOneWidget);
        expect(find.textContaining('Semantic Set'), findsNothing);
      },
    );

    testWidgets(
      'set builder dialog shows tabbed Included Items, Required Choices, Extras, and Rules sections',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 3200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final db = createTestDatabase();
        addTearDown(db.close);

        await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
        final int categoryId = await insertCategory(db, name: 'Breakfast');
        await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Set Breakfast',
          priceMinor: 500,
        );
        await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Egg',
          priceMinor: 120,
        );
        await db
            .into(db.setItems)
            .insert(
              SetItemsCompanion.insert(
                productId: 1,
                itemProductId: 2,
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

        await tester.tap(
          find.byKey(const ValueKey<String>('product-set-builder-1')),
        );
        await tester.pumpAndSettle();

        // Dialog title
        expect(find.text('Set Builder'), findsAtLeastNWidgets(1));

        // Tabs use operator-friendly labels
        expect(find.text('Included Items'), findsWidgets);
        expect(find.text('Required Choices'), findsWidgets);
        expect(find.text('Extras'), findsWidgets);
        expect(find.text('Rules'), findsOneWidget);

        // Legacy jargon is NOT present
        expect(find.text('Set Items'), findsNothing);
        expect(find.text('Choice Groups'), findsNothing);
        expect(find.text('Semantic Menu Configuration'), findsNothing);

        expect(
          find.byKey(const ValueKey<String>('semantic-add-item')),
          findsOneWidget,
        );
        await tester.tap(find.text('Rules').last);
        await tester.pumpAndSettle();
        expect(find.text('Swap Rules'), findsOneWidget);
        expect(find.text('Free swaps allowed'), findsOneWidget);
      },
    );
  });

  group('POS Breakfast Builder terminology', () {
    testWidgets(
      'semantic product opens structured builder with Included Items, Required Choices, Extras, and Summary sections',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final _PosFixture fixture = await _seedPosFixture(db);
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            ordersNotifierProvider.overrideWith(
              (Ref ref) => _StaticOrdersNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(fixture.cashierId);
        await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

        await tester.pumpWidget(_testPosApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Breakfast'));
        await tester.pumpAndSettle();

        // Opens semantic editor, not flat modifier popup
        expect(
          find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
          findsOneWidget,
        );
        expect(find.byType(ModifierPopup), findsNothing);

        // Title shows product name and price
        expect(find.text('Set Breakfast'), findsWidgets);

        // Section headers use operator-friendly labels
        expect(find.text('Included Items'), findsOneWidget);
        expect(find.text('Required Choices'), findsOneWidget);
        expect(find.text('Extras'), findsWidgets);
        expect(find.text('Summary'), findsOneWidget);

        // Legacy jargon is NOT present
        expect(find.text('Configure Bundle'), findsNothing);
        expect(find.text('Set Items'), findsNothing);
        expect(find.text('Current Snapshot'), findsNothing);

        expect(find.text('Set Total'), findsOneWidget);
        expect(find.text('Add to Order'), findsOneWidget);

        // Choice group shows "Choose one" language
        expect(find.textContaining('Choose one'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets(
      'required choice group blocks add to cart with operator message',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final _PosFixture fixture = await _seedPosFixture(db);
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            ordersNotifierProvider.overrideWith(
              (Ref ref) => _StaticOrdersNotifier(ref),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(fixture.cashierId);
        await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

        await tester.pumpWidget(_testPosApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Set Breakfast'));
        await tester.pumpAndSettle();

        // Confirm button should be disabled
        final ElevatedButton confirmButton = tester.widget<ElevatedButton>(
          find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
        );
        expect(confirmButton.onPressed, isNull);

        expect(find.text('Choose an option for Drink choice.'), findsOneWidget);
      },
    );

    testWidgets('flat modifier product still uses legacy modifier popup path', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _PosFixture fixture = await _seedPosFixture(db);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith(
            (Ref ref) => _StaticOrdersNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(fixture.cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testPosApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Drinks').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Flat Tea'));
      await tester.pumpAndSettle();

      // Legacy flat product opens ModifierPopup, not semantic editor
      expect(find.byType(ModifierPopup), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
        findsNothing,
      );
    });
  });
}

Future<_PosFixture> _seedPosFixture(AppDatabase db) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: cashierId);

  final int breakfastCategoryId = await insertCategory(db, name: 'Breakfast');
  final int drinkCategoryId = await insertCategory(db, name: 'Drinks');

  final int rootProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set Breakfast',
    priceMinor: 600,
  );
  final int beansProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Beans',
    priceMinor: 80,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Egg',
    priceMinor: 120,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int coffeeProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Coffee',
    priceMinor: 170,
  );
  await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Flat Tea',
    priceMinor: 250,
    hasModifiers: true,
  );

  await db
      .into(db.setItems)
      .insert(
        SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: eggProductId,
          sortOrder: const Value<int>(1),
          isRemovable: const Value<bool>(false),
        ),
      );
  await db
      .into(db.setItems)
      .insert(
        SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: beansProductId,
          sortOrder: const Value<int>(2),
          isRemovable: const Value<bool>(true),
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
          sortOrder: const Value<int>(1),
        ),
      );

  Future<void> insertChoiceMember({
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          ProductModifiersCompanion.insert(
            productId: rootProductId,
            groupId: Value<int?>(drinkGroupId),
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'choice',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertChoiceMember(itemProductId: teaProductId, label: 'Tea');
  await insertChoiceMember(itemProductId: coffeeProductId, label: 'Coffee');

  // Add a legacy flat modifier for the "Flat Tea" product
  await db
      .into(db.productModifiers)
      .insert(
        ProductModifiersCompanion.insert(
          productId: 6, // Flat Tea
          name: 'Lemon',
          type: 'extra',
          extraPriceMinor: const Value<int>(20),
        ),
      );

  return _PosFixture(
    cashierId: cashierId,
    drinkGroupId: drinkGroupId,
    teaProductId: teaProductId,
    beansProductId: beansProductId,
  );
}

class _PosFixture {
  const _PosFixture({
    required this.cashierId,
    required this.drinkGroupId,
    required this.teaProductId,
    required this.beansProductId,
  });

  final int cashierId;
  final int drinkGroupId;
  final int teaProductId;
  final int beansProductId;
}

class _StaticOrdersNotifier extends OrdersNotifier {
  _StaticOrdersNotifier(super.ref);

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: false, errorMessage: null);
  }
}

Widget _testPosApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
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
