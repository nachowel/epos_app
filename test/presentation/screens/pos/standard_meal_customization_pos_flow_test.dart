import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/drift_meal_adjustment_profile_repository.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets('meal-profile standard product opens standard meal dialog', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final int cashierId = await insertUser(
      db,
      name: 'Cashier',
      role: 'cashier',
    );
    await insertShift(db, openedBy: cashierId);
    final int categoryId = await insertCategory(db, name: 'Meals');
    final int mealProductId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Burger Meal',
      priceMinor: 1000,
    );
    final int defaultMainId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Chicken Fillet',
      priceMinor: 0,
    );
    final int swapItemId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Beef Patty',
      priceMinor: 0,
    );
    final int sideItemId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Fries',
      priceMinor: 0,
    );

    final DriftMealAdjustmentProfileRepository repository =
        DriftMealAdjustmentProfileRepository(db);
    final int profileId = await repository.saveProfileDraft(
      MealAdjustmentProfileDraft(
        name: 'POS meal profile',
        freeSwapLimit: 0,
        isActive: true,
        components: <MealAdjustmentComponentDraft>[
          MealAdjustmentComponentDraft(
            componentKey: 'main',
            displayName: 'Main',
            defaultItemProductId: defaultMainId,
            quantity: 1,
            canRemove: false,
            sortOrder: 0,
            isActive: true,
            swapOptions: <MealAdjustmentComponentOptionDraft>[
              MealAdjustmentComponentOptionDraft(
                optionItemProductId: swapItemId,
                fixedPriceDeltaMinor: 50,
                sortOrder: 0,
                isActive: true,
              ),
            ],
          ),
          MealAdjustmentComponentDraft(
            componentKey: 'side',
            displayName: 'Side',
            defaultItemProductId: sideItemId,
            quantity: 1,
            canRemove: true,
            sortOrder: 1,
            isActive: true,
          ),
        ],
      ),
    );
    await repository.assignProfileToProduct(
      productId: mealProductId,
      profileId: profileId,
    );

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

    await container.read(authNotifierProvider.notifier).loadUserById(cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Burger Meal').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('meal-customization-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
      findsNothing,
    );
  });

  testWidgets('breakfast semantic product still opens breakfast dialog', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final int cashierId = await insertUser(
      db,
      name: 'Cashier',
      role: 'cashier',
    );
    await insertShift(db, openedBy: cashierId);
    final int breakfastCategoryId = await insertCategory(
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
      categoryId: breakfastCategoryId,
      name: 'Set Breakfast',
      priceMinor: 600,
    );
    final int eggId = await insertProduct(
      db,
      categoryId: breakfastItemsCategoryId,
      name: 'Egg',
      priceMinor: 0,
    );
    final int beansId = await insertProduct(
      db,
      categoryId: breakfastItemsCategoryId,
      name: 'Beans',
      priceMinor: 0,
    );
    await insertProduct(
      db,
      categoryId: breakfastItemsCategoryId,
      name: 'Toast',
      priceMinor: 0,
    );
    await insertProduct(
      db,
      categoryId: breakfastItemsCategoryId,
      name: 'Bread',
      priceMinor: 0,
    );
    await insertProduct(
      db,
      categoryId: drinksCategoryId,
      name: 'Tea',
      priceMinor: 0,
    );
    await insertProduct(
      db,
      categoryId: drinksCategoryId,
      name: 'Coffee',
      priceMinor: 0,
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
            productId: rootProductId,
            itemProductId: beansId,
            sortOrder: const Value<int>(1),
          ),
        );
    await BreakfastConfigurationRepository(
      db,
    ).bootstrapBreakfastSetRoot(rootProductId);

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

    await container.read(authNotifierProvider.notifier).loadUserById(cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Breakfast').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('meal-customization-dialog')),
      findsNothing,
    );
  });

  testWidgets('sandwich profile product opens sandwich customization dialog', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final int cashierId = await insertUser(
      db,
      name: 'Cashier',
      role: 'cashier',
    );
    await insertShift(db, openedBy: cashierId);
    final int categoryId = await insertCategory(db, name: 'Sandwiches');
    final int sandwichProductId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Egg',
      priceMinor: 350,
    );
    final int extraItemId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Cheese',
      priceMinor: 0,
    );

    final DriftMealAdjustmentProfileRepository repository =
        DriftMealAdjustmentProfileRepository(db);
    final int profileId = await repository.saveProfileDraft(
      MealAdjustmentProfileDraft(
        name: 'Sandwich profile',
        kind: MealAdjustmentProfileKind.sandwich,
        freeSwapLimit: 0,
        isActive: true,
        extraOptions: <MealAdjustmentExtraOptionDraft>[
          MealAdjustmentExtraOptionDraft(
            itemProductId: extraItemId,
            fixedPriceDeltaMinor: 100,
            sortOrder: 0,
            isActive: true,
          ),
        ],
      ),
    );
    await repository.assignProfileToProduct(
      productId: sandwichProductId,
      profileId: profileId,
    );

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

    await container.read(authNotifierProvider.notifier).loadUserById(cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Egg').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('meal-customization-dialog')),
      findsOneWidget,
    );
    expect(find.text('Sandwich customization: Egg'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
      findsNothing,
    );
  });

  testWidgets(
    'sandwich profile product ignores unrelated legacy extra references on other products',
    (WidgetTester tester) async {
      _setLargeView(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int sandwichCategoryId = await insertCategory(
        db,
        name: 'Sandwiches',
      );
      final int jacketCategoryId = await insertCategory(
        db,
        name: 'Jacket Potatoes',
      );
      final int sandwichProductId = await insertProduct(
        db,
        categoryId: sandwichCategoryId,
        name: 'Cheese',
        priceMinor: 350,
      );
      final int extraItemId = await insertProduct(
        db,
        categoryId: sandwichCategoryId,
        name: 'Onion',
        priceMinor: 0,
      );
      final int unrelatedRootId = await insertProduct(
        db,
        categoryId: jacketCategoryId,
        name: 'Jacket Potato',
        priceMinor: 500,
      );

      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: unrelatedRootId,
              itemProductId: Value<int?>(sandwichProductId),
              name: 'Cheese',
              type: 'extra',
              extraPriceMinor: const Value<int>(0),
              isActive: const Value<bool>(true),
            ),
          );

      final DriftMealAdjustmentProfileRepository repository =
          DriftMealAdjustmentProfileRepository(db);
      final int profileId = await repository.saveProfileDraft(
        MealAdjustmentProfileDraft(
          name: 'Sandwich profile',
          kind: MealAdjustmentProfileKind.sandwich,
          freeSwapLimit: 0,
          isActive: true,
          extraOptions: <MealAdjustmentExtraOptionDraft>[
            MealAdjustmentExtraOptionDraft(
              itemProductId: extraItemId,
              fixedPriceDeltaMinor: 100,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
      );
      await repository.assignProfileToProduct(
        productId: sandwichProductId,
        profileId: profileId,
      );

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
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cheese').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('meal-customization-dialog')),
        findsOneWidget,
      );
      expect(find.text('Sandwich customization: Cheese'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'sandwich profile product can still open meal customization when used as a breakfast set item',
    (WidgetTester tester) async {
      _setLargeView(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int breakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int sandwichCategoryId = await insertCategory(
        db,
        name: 'Sandwiches',
      );
      final int breakfastRootId = await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Set Breakfast',
        priceMinor: 650,
      );
      final int sandwichProductId = await insertProduct(
        db,
        categoryId: sandwichCategoryId,
        name: 'Sausage',
        priceMinor: 350,
      );
      final int extraItemId = await insertProduct(
        db,
        categoryId: sandwichCategoryId,
        name: 'Onion',
        priceMinor: 0,
      );

      await db
          .into(db.setItems)
          .insert(
            SetItemsCompanion.insert(
              productId: breakfastRootId,
              itemProductId: sandwichProductId,
              sortOrder: const Value<int>(0),
            ),
          );

      final DriftMealAdjustmentProfileRepository repository =
          DriftMealAdjustmentProfileRepository(db);
      final int profileId = await repository.saveProfileDraft(
        MealAdjustmentProfileDraft(
          name: 'Sandwich profile',
          kind: MealAdjustmentProfileKind.sandwich,
          freeSwapLimit: 0,
          isActive: true,
          extraOptions: <MealAdjustmentExtraOptionDraft>[
            MealAdjustmentExtraOptionDraft(
              itemProductId: extraItemId,
              fixedPriceDeltaMinor: 100,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
      );
      await repository.assignProfileToProduct(
        productId: sandwichProductId,
        profileId: profileId,
      );

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
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sandwiches').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sausage').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('meal-customization-dialog')),
        findsOneWidget,
      );
      expect(find.text('Sandwich customization: Sausage'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'sandwich profile product can still open meal customization when used as a breakfast choice member',
    (WidgetTester tester) async {
      _setLargeView(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int breakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int sandwichCategoryId = await insertCategory(
        db,
        name: 'Sandwiches',
      );
      final int breakfastRootId = await insertProduct(
        db,
        categoryId: breakfastCategoryId,
        name: 'Set Breakfast',
        priceMinor: 650,
      );
      final int sandwichProductId = await insertProduct(
        db,
        categoryId: sandwichCategoryId,
        name: 'Ham',
        priceMinor: 350,
      );
      final int extraItemId = await insertProduct(
        db,
        categoryId: sandwichCategoryId,
        name: 'Cheese',
        priceMinor: 0,
      );
      final int groupId = await db
          .into(db.modifierGroups)
          .insert(
            ModifierGroupsCompanion.insert(
              productId: breakfastRootId,
              name: 'Drink',
              minSelect: const Value<int>(1),
              maxSelect: const Value<int>(1),
              includedQuantity: const Value<int>(1),
              sortOrder: const Value<int>(0),
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: breakfastRootId,
              groupId: Value<int?>(groupId),
              itemProductId: Value<int?>(sandwichProductId),
              name: 'Ham',
              type: 'choice',
              extraPriceMinor: const Value<int>(0),
              isActive: const Value<bool>(true),
            ),
          );

      final DriftMealAdjustmentProfileRepository repository =
          DriftMealAdjustmentProfileRepository(db);
      final int profileId = await repository.saveProfileDraft(
        MealAdjustmentProfileDraft(
          name: 'Sandwich profile',
          kind: MealAdjustmentProfileKind.sandwich,
          freeSwapLimit: 0,
          isActive: true,
          extraOptions: <MealAdjustmentExtraOptionDraft>[
            MealAdjustmentExtraOptionDraft(
              itemProductId: extraItemId,
              fixedPriceDeltaMinor: 100,
              sortOrder: 0,
              isActive: true,
            ),
          ],
        ),
      );
      await repository.assignProfileToProduct(
        productId: sandwichProductId,
        profileId: profileId,
      );

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
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sandwiches').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ham').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('meal-customization-dialog')),
        findsOneWidget,
      );
      expect(find.text('Sandwich customization: Ham'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'configured breakfast products in separate categories all open the same breakfast dialog',
    (WidgetTester tester) async {
      _setLargeView(tester);
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int drinksCategoryId = await insertCategory(db, name: 'Drinks');
      final int eggId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Egg',
        priceMinor: 0,
      );
      final int beansId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Beans',
        priceMinor: 0,
      );
      await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Toast',
        priceMinor: 0,
      );
      await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Bread',
        priceMinor: 0,
      );
      await insertProduct(
        db,
        categoryId: drinksCategoryId,
        name: 'Tea',
        priceMinor: 0,
      );
      await insertProduct(
        db,
        categoryId: drinksCategoryId,
        name: 'Coffee',
        priceMinor: 0,
      );

      final List<String> rootNames = <String>[
        'Big Breakfast',
        'Pancake Breakfast 1',
        'Eggs Benedict',
      ];
      final List<String> categoryNames = <String>[
        'Set Breakfast',
        'Pancake Breakfast',
        'Healthy Breakfast',
      ];
      for (int index = 0; index < rootNames.length; index += 1) {
        await _insertBreakfastSemanticRoot(
          db,
          categoryName: categoryNames[index],
          rootProductName: rootNames[index],
          eggId: eggId,
          beansId: beansId,
        );
      }

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
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      for (int index = 0; index < rootNames.length; index += 1) {
        await tester.tap(find.text(categoryNames[index]).first);
        await tester.pumpAndSettle();

        final String rootName = rootNames[index];
        await tester.tap(find.text(rootName).last);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('meal-customization-dialog')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('semantic-bundle-cancel')),
        );
        await tester.pumpAndSettle();
      }
    },
  );
}

class _StaticOrdersNotifier extends OrdersNotifier {
  _StaticOrdersNotifier(super.ref);

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: false, errorMessage: null);
  }
}

Widget _testApp(ProviderContainer container) {
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

Future<void> _insertBreakfastSemanticRoot(
  AppDatabase db, {
  required String categoryName,
  required String rootProductName,
  required int eggId,
  required int beansId,
}) async {
  final int categoryId = await insertCategory(db, name: categoryName);
  final int rootProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: rootProductName,
    priceMinor: 600,
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
          productId: rootProductId,
          itemProductId: beansId,
          sortOrder: const Value<int>(1),
        ),
      );
  await BreakfastConfigurationRepository(
    db,
  ).bootstrapBreakfastSetRoot(rootProductId);
}

void _setLargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
