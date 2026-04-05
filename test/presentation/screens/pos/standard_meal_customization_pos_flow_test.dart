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
  testWidgets('meal-profile standard product opens standard meal dialog',
      (WidgetTester tester) async {
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

  testWidgets('breakfast semantic product still opens breakfast dialog',
      (WidgetTester tester) async {
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
    await db.into(db.setItems).insert(
      SetItemsCompanion.insert(
        productId: rootProductId,
        itemProductId: eggId,
        sortOrder: const Value<int>(0),
      ),
    );
    await db.into(db.setItems).insert(
      SetItemsCompanion.insert(
        productId: rootProductId,
        itemProductId: beansId,
        sortOrder: const Value<int>(1),
      ),
    );
    await BreakfastConfigurationRepository(db).bootstrapBreakfastSetRoot(
      rootProductId,
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
