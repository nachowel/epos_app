import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/utils/currency_formatter.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/drift_meal_adjustment_profile_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/orders/order_detail_screen.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets(
    'draft order detail shows send and discard but blocks pay and cancel',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'draft-detail-ui',
        shiftId: shiftId,
        userId: cashierId,
        status: 'draft',
        totalAmountMinor: 500,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(
        _localizedTestApp(
          container,
          child: OrderDetailScreen(transactionId: transactionId),
        ),
      );
      await tester.pumpAndSettle();

      final OutlinedButton sendButton = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('detail-send')),
          matching: find.byType(OutlinedButton),
        ),
      );
      final OutlinedButton discardButton = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('detail-discard-draft')),
          matching: find.byType(OutlinedButton),
        ),
      );
      final ElevatedButton payButton = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('detail-pay')),
          matching: find.byType(ElevatedButton),
        ),
      );
      final OutlinedButton cancelButton = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('detail-cancel')),
          matching: find.byType(OutlinedButton),
        ),
      );

      expect(sendButton.onPressed, isNotNull);
      expect(discardButton.onPressed, isNotNull);
      expect(payButton.onPressed, isNull);
      expect(cancelButton.onPressed, isNull);
    },
  );

  testWidgets(
    'sent order detail shows pay and cancel but blocks send and discard',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'sent-detail-ui',
        shiftId: shiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 500,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(
        _localizedTestApp(
          container,
          child: OrderDetailScreen(transactionId: transactionId),
        ),
      );
      await tester.pumpAndSettle();

      final OutlinedButton sendButton = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('detail-send')),
          matching: find.byType(OutlinedButton),
        ),
      );
      final OutlinedButton discardButton = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('detail-discard-draft')),
          matching: find.byType(OutlinedButton),
        ),
      );
      final ElevatedButton payButton = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('detail-pay')),
          matching: find.byType(ElevatedButton),
        ),
      );
      final OutlinedButton cancelButton = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('detail-cancel')),
          matching: find.byType(OutlinedButton),
        ),
      );

      expect(sendButton.onPressed, isNull);
      expect(discardButton.onPressed, isNull);
      expect(payButton.onPressed, isNotNull);
      expect(cancelButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'payment dialog keeps submit enabled for valid current-shift sent unpaid order',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(
        db,
        openedBy: cashierId,
        status: 'closed',
        closedBy: cashierId,
        closedAt: DateTime.now(),
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );
      final int currentShiftId = await insertShift(db, openedBy: cashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'sent-detail-payment-dialog',
        shiftId: currentShiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 500,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(
        _localizedTestApp(
          container,
          child: OrderDetailScreen(transactionId: transactionId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(
          ElevatedButton,
          '${AppStrings.payAction} ${CurrencyFormatter.fromMinor(500)}',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.salesLockedAdminCloseRequired), findsNothing);

      final String dialogPayLabel =
          '${AppStrings.payAction} ${CurrencyFormatter.fromMinor(500)}';
      final ElevatedButton dialogPayButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('payment-submit')),
      );

      expect(find.text(dialogPayLabel), findsWidgets);
      expect(dialogPayButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'draft grouped meal line opens standard meal dialog in edit mode',
    (WidgetTester tester) async {
      final _MealUiFixture fixture = await _pumpMealOrderDetail(
        tester,
        lineQuantity: 2,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('detail-edit-meal-${fixture.lineId}')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit meal: Burger Meal'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('meal-customization-edit-all-notice'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Editing applies to all 2 items'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    },
  );

  testWidgets('legacy meal lines show disabled edit and explicit message', (
    WidgetTester tester,
  ) async {
    final _MealUiFixture fixture = await _pumpMealOrderDetail(
      tester,
      makeLegacy: true,
    );

    final OutlinedButton editButton = tester.widget<OutlinedButton>(
      find.byKey(ValueKey<String>('detail-edit-meal-${fixture.lineId}')),
    );

    expect(editButton.onPressed, isNull);
    expect(find.text('Legacy meal line'), findsOneWidget);
    expect(
      find.text('This item was created before the new system and cannot be edited.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'breakfast remove action updates popup and persisted detail labels',
    (WidgetTester tester) async {
      final _BreakfastUiFixture fixture = await _pumpBreakfastOrderDetail(
        tester,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('detail-edit-breakfast-${fixture.lineId}')),
      );
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.byKey(
          ValueKey<String>('breakfast-remove-inc-${fixture.beansProductId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('- Beans'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('breakfast-line-total')),
            )
            .data,
        CurrencyFormatter.fromMinor(400),
      );

      await tester.tap(find.byKey(const ValueKey<String>('breakfast-close')));
      await tester.pumpAndSettle();

      expect(find.text('- Beans'), findsOneWidget);
    },
  );

  testWidgets('third replacement shows paid swap label and updated total', (
    WidgetTester tester,
  ) async {
    final _BreakfastUiFixture fixture = await _pumpBreakfastOrderDetail(tester);

    await tester.tap(
      find.byKey(ValueKey<String>('detail-edit-breakfast-${fixture.lineId}')),
    );
    await tester.pumpAndSettle();

    for (final int productId in <int>[
      fixture.eggProductId,
      fixture.baconProductId,
      fixture.sausageProductId,
    ]) {
      await _tapVisible(
        tester,
        find.byKey(ValueKey<String>('breakfast-remove-inc-$productId')),
      );
      await tester.pumpAndSettle();
    }
    for (final int productId in <int>[
      fixture.baconProductId,
      fixture.sausageProductId,
      fixture.beansProductId,
    ]) {
      await _tapVisible(
        tester,
        find.byKey(ValueKey<String>('breakfast-add-inc-$productId')),
      );
      await tester.pumpAndSettle();
    }

    expect(find.text('+ Bacon (swap)'), findsOneWidget);
    expect(find.text('+ Sausage (swap)'), findsOneWidget);
    expect(find.text('+ Beans (swap +£0.80)'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('breakfast-line-total')),
          )
          .data,
      CurrencyFormatter.fromMinor(480),
    );
  });

  testWidgets('choice product extra add never renders as swap', (
    WidgetTester tester,
  ) async {
    final _BreakfastUiFixture fixture = await _pumpBreakfastOrderDetail(tester);

    await tester.tap(
      find.byKey(ValueKey<String>('detail-edit-breakfast-${fixture.lineId}')),
    );
    await tester.pumpAndSettle();

    await _tapVisible(
      tester,
      find.byKey(
        ValueKey<String>('breakfast-remove-inc-${fixture.eggProductId}'),
      ),
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(
        ValueKey<String>(
          'breakfast-choice-select-${fixture.hotDrinkGroupId}-${fixture.teaProductId}',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapVisible(
      tester,
      find.byKey(
        ValueKey<String>('breakfast-choice-inc-${fixture.hotDrinkGroupId}'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('breakfast-snapshot')),
        matching: find.text('Tea'),
      ),
      findsOneWidget,
    );
    expect(find.text('+ Tea (+£1.50)'), findsOneWidget);
    expect(find.text('+ Tea (swap +£1.50)'), findsNothing);
  });

  testWidgets(
    'invalid runtime breakfast edit shows error and keeps previous snapshot',
    (WidgetTester tester) async {
      final _BreakfastUiFixture fixture = await _pumpBreakfastOrderDetail(
        tester,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('detail-edit-breakfast-${fixture.lineId}')),
      );
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.byKey(
          ValueKey<String>(
            'breakfast-choice-select-${fixture.hotDrinkGroupId}-${fixture.teaProductId}',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('breakfast-snapshot')),
          matching: find.text('Tea'),
        ),
        findsOneWidget,
      );

      await fixture.database.customStatement('''
        DELETE FROM product_modifiers
        WHERE product_id = ${fixture.set4ProductId}
          AND group_id = ${fixture.hotDrinkGroupId}
          AND item_product_id = ${fixture.teaProductId}
      ''');

      await _tapVisible(
        tester,
        find.byKey(
          ValueKey<String>('breakfast-choice-inc-${fixture.hotDrinkGroupId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('That breakfast choice is not allowed.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('breakfast-snapshot')),
          matching: find.text('Tea'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('breakfast-line-total')),
            )
            .data,
        CurrencyFormatter.fromMinor(400),
      );
    },
  );

  testWidgets(
    'runtime popup edit fails safely when the persisted transaction token is stale',
    (WidgetTester tester) async {
      final _BreakfastUiFixture fixture = await _pumpBreakfastOrderDetail(
        tester,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('detail-edit-breakfast-${fixture.lineId}')),
      );
      await tester.pumpAndSettle();

      final DateTime newerUpdatedAt = DateTime(2026, 1, 1, 12, 5, 0);
      await fixture.database.customStatement(
        'UPDATE transactions SET updated_at = ? WHERE id = ?',
        <Object?>[
          newerUpdatedAt.millisecondsSinceEpoch ~/ 1000,
          fixture.transactionId,
        ],
      );

      await _tapVisible(
        tester,
        find.byKey(
          ValueKey<String>(
            'breakfast-choice-select-${fixture.hotDrinkGroupId}-${fixture.teaProductId}',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('is stale'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('breakfast-snapshot')),
          matching: find.text('Tea'),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey<String>('breakfast-line-total')),
            )
            .data,
        CurrencyFormatter.fromMinor(400),
      );
    },
  );

  testWidgets(
    'editing one unit of a quantity-two breakfast line splits the detail view',
    (WidgetTester tester) async {
      final _BreakfastUiFixture fixture = await _pumpBreakfastOrderDetail(
        tester,
        lineQuantity: 2,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('detail-edit-breakfast-${fixture.lineId}')),
      );
      await tester.pumpAndSettle();

      await _tapVisible(
        tester,
        find.byKey(
          ValueKey<String>(
            'breakfast-choice-select-${fixture.hotDrinkGroupId}-${fixture.teaProductId}',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('breakfast-close')));
      await tester.pumpAndSettle();

      expect(find.text('1x Set 4'), findsNWidgets(2));
      expect(find.text('Tea'), findsOneWidget);
    },
  );

  testWidgets(
    'breakfast modifier popup shows None for each required group and persists a second-group None selection',
    (WidgetTester tester) async {
      final _BreakfastUiFixture fixture = await _pumpBreakfastOrderDetail(
        tester,
        includeBreadGroup: true,
        requiredChoices: true,
      );

      await tester.tap(
        find.byKey(ValueKey<String>('detail-edit-breakfast-${fixture.lineId}')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('breakfast-popup')),
        findsOneWidget,
      );
      expect(find.text('Tea or Coffee'), findsOneWidget);
      expect(find.text('Toast or Bread'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey<String>('breakfast-choice-none-${fixture.hotDrinkGroupId}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>(
            'breakfast-choice-none-${fixture.toastBreadGroupId!}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Tea'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Toast'), findsOneWidget);
      expect(find.text('Bread'), findsOneWidget);

      await _tapVisible(
        tester,
        find.byKey(
          ValueKey<String>(
            'breakfast-choice-none-${fixture.toastBreadGroupId!}',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        await _countExplicitNoneRows(
          fixture.database,
          lineId: fixture.lineId,
          groupId: fixture.toastBreadGroupId!,
        ),
        1,
      );
    },
  );
}

Widget _localizedTestApp(
  ProviderContainer container, {
  required Widget child,
  Locale locale = const Locale('en'),
}) {
  AppLocalizationService.instance.setLocale(locale);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

Future<_BreakfastUiFixture> _pumpBreakfastOrderDetail(
  WidgetTester tester, {
  int lineQuantity = 1,
  bool includeBreadGroup = false,
  bool requiredChoices = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final app_db.AppDatabase db = createTestDatabase();
  final _BreakfastUiFixture fixture = await _seedBreakfastUiFixture(
    db,
    lineQuantity: lineQuantity,
    includeBreadGroup: includeBreadGroup,
    requiredChoices: requiredChoices,
  );
  addTearDown(db.close);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);

  await container
      .read(authNotifierProvider.notifier)
      .loadUserById(fixture.cashierId);
  await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

  await tester.pumpWidget(
    _localizedTestApp(
      container,
      child: OrderDetailScreen(transactionId: fixture.transactionId),
    ),
  );
  await tester.pumpAndSettle();

  return fixture;
}

Future<_MealUiFixture> _pumpMealOrderDetail(
  WidgetTester tester, {
  int lineQuantity = 1,
  bool makeLegacy = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final app_db.AppDatabase db = createTestDatabase();
  final _MealUiFixture fixture = await _seedMealUiFixture(
    db,
    lineQuantity: lineQuantity,
    makeLegacy: makeLegacy,
  );
  addTearDown(db.close);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);

  await container
      .read(authNotifierProvider.notifier)
      .loadUserById(fixture.cashierId);
  await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

  await tester.pumpWidget(
    _localizedTestApp(
      container,
      child: OrderDetailScreen(transactionId: fixture.transactionId),
    ),
  );
  await tester.pumpAndSettle();

  return fixture;
}

Future<_BreakfastUiFixture> _seedBreakfastUiFixture(
  app_db.AppDatabase db, {
  int lineQuantity = 1,
  bool includeBreadGroup = false,
  bool requiredChoices = false,
}) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int shiftId = await insertShift(db, openedBy: cashierId);

  final int breakfastCategoryId = await insertCategory(
    db,
    name: 'Set Breakfast',
  );
  final int hotDrinkCategoryId = await insertCategory(db, name: 'Hot Drink');
  final int extrasCategoryId = await insertCategory(
    db,
    name: 'Breakfast Extras',
  );

  final int set4ProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set 4',
    priceMinor: 400,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Egg',
    priceMinor: 120,
  );
  final int baconProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Bacon',
    priceMinor: 150,
  );
  final int sausageProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Sausage',
    priceMinor: 180,
  );
  final int chipsProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Chips',
    priceMinor: 110,
  );
  final int beansProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Beans',
    priceMinor: 80,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: hotDrinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int coffeeProductId = await insertProduct(
    db,
    categoryId: hotDrinkCategoryId,
    name: 'Coffee',
    priceMinor: 160,
  );
  final int toastProductId = await insertProduct(
    db,
    categoryId: extrasCategoryId,
    name: 'Toast',
    priceMinor: 100,
  );
  final int breadProductId = await insertProduct(
    db,
    categoryId: extrasCategoryId,
    name: 'Bread',
    priceMinor: 90,
  );

  Future<void> addSetItem({
    required int itemProductId,
    required int sortOrder,
  }) async {
    await db
        .into(db.setItems)
        .insert(
          app_db.SetItemsCompanion.insert(
            productId: set4ProductId,
            itemProductId: itemProductId,
            sortOrder: Value<int>(sortOrder),
          ),
        );
  }

  await addSetItem(itemProductId: eggProductId, sortOrder: 1);
  await addSetItem(itemProductId: baconProductId, sortOrder: 2);
  await addSetItem(itemProductId: sausageProductId, sortOrder: 3);
  await addSetItem(itemProductId: chipsProductId, sortOrder: 4);
  await addSetItem(itemProductId: beansProductId, sortOrder: 5);

  final int hotDrinkGroupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: set4ProductId,
          name: 'Tea or Coffee',
          minSelect: Value<int>(requiredChoices ? 1 : 0),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );
  int? toastBreadGroupId;
  if (includeBreadGroup) {
    toastBreadGroupId = await db
        .into(db.modifierGroups)
        .insert(
          app_db.ModifierGroupsCompanion.insert(
            productId: set4ProductId,
            name: 'Toast or Bread',
            minSelect: Value<int>(requiredChoices ? 1 : 0),
            maxSelect: const Value<int>(1),
            includedQuantity: const Value<int>(1),
            sortOrder: const Value<int>(2),
          ),
        );
  }

  Future<void> insertChoice({
    required int groupId,
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          app_db.ProductModifiersCompanion.insert(
            productId: set4ProductId,
            groupId: Value<int?>(groupId),
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'choice',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertChoice(
    groupId: hotDrinkGroupId,
    itemProductId: teaProductId,
    label: 'Tea',
  );
  await insertChoice(
    groupId: hotDrinkGroupId,
    itemProductId: coffeeProductId,
    label: 'Coffee',
  );
  if (toastBreadGroupId != null) {
    await insertChoice(
      groupId: toastBreadGroupId,
      itemProductId: toastProductId,
      label: 'Toast',
    );
    await insertChoice(
      groupId: toastBreadGroupId,
      itemProductId: breadProductId,
      label: 'Bread',
    );
  }

  Future<void> insertExtra({
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          app_db.ProductModifiersCompanion.insert(
            productId: set4ProductId,
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'extra',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertExtra(itemProductId: baconProductId, label: 'Bacon');
  await insertExtra(itemProductId: sausageProductId, label: 'Sausage');
  await insertExtra(itemProductId: beansProductId, label: 'Beans');

  final int transactionId = await insertTransaction(
    db,
    uuid: 'breakfast-detail-order',
    shiftId: shiftId,
    userId: cashierId,
    status: 'draft',
    totalAmountMinor: 400 * lineQuantity,
  );
  final int lineId = await db
      .into(db.transactionLines)
      .insert(
        app_db.TransactionLinesCompanion.insert(
          uuid: 'breakfast-line',
          transactionId: transactionId,
          productId: set4ProductId,
          productName: 'Set 4',
          unitPriceMinor: 400,
          quantity: Value<int>(lineQuantity),
          lineTotalMinor: 400 * lineQuantity,
        ),
      );

  return _BreakfastUiFixture(
    database: db,
    cashierId: cashierId,
    transactionId: transactionId,
    lineId: lineId,
    set4ProductId: set4ProductId,
    eggProductId: eggProductId,
    baconProductId: baconProductId,
    sausageProductId: sausageProductId,
    beansProductId: beansProductId,
    teaProductId: teaProductId,
    hotDrinkGroupId: hotDrinkGroupId,
    toastBreadGroupId: toastBreadGroupId,
  );
}

Future<_MealUiFixture> _seedMealUiFixture(
  app_db.AppDatabase db, {
  required int lineQuantity,
  required bool makeLegacy,
}) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int shiftId = await insertShift(db, openedBy: cashierId);
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
  final int sideItemId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Fries',
    priceMinor: 0,
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
      name: 'Order detail meal profile',
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
      extraOptions: <MealAdjustmentExtraOptionDraft>[
        MealAdjustmentExtraOptionDraft(
          itemProductId: extraItemId,
          fixedPriceDeltaMinor: 100,
          sortOrder: 0,
          isActive: true,
        ),
      ],
      pricingRules: <MealAdjustmentPricingRuleDraft>[
        MealAdjustmentPricingRuleDraft(
          name: 'No side discount',
          ruleType: MealAdjustmentPricingRuleType.removeOnly,
          priceDeltaMinor: -50,
          priority: 0,
          isActive: true,
          conditions: const <MealAdjustmentPricingRuleConditionDraft>[
            MealAdjustmentPricingRuleConditionDraft(
              conditionType:
                  MealAdjustmentPricingRuleConditionType.removedComponent,
              componentKey: 'side',
              quantity: 1,
            ),
          ],
        ),
      ],
    ),
  );
  await repository.assignProfileToProduct(
    productId: mealProductId,
    profileId: profileId,
  );

  final int transactionId = await insertTransaction(
    db,
    uuid: 'meal-detail-order',
    shiftId: shiftId,
    userId: cashierId,
    status: 'draft',
    totalAmountMinor: 1000 * lineQuantity,
  );
  final int lineId = await db.into(db.transactionLines).insert(
    app_db.TransactionLinesCompanion.insert(
      uuid: 'meal-detail-line',
      transactionId: transactionId,
      productId: mealProductId,
      productName: 'Burger Meal',
      unitPriceMinor: 1000,
      quantity: Value<int>(lineQuantity),
      lineTotalMinor: 1000 * lineQuantity,
    ),
  );

  final TransactionRepository transactionRepository = TransactionRepository(db);
  await transactionRepository.replaceMealCustomizationLineSnapshot(
    transactionLineId: lineId,
    snapshot: MealCustomizationResolvedSnapshot(
      productId: mealProductId,
      profileId: profileId,
      resolvedComponentActions: <MealCustomizationSemanticAction>[
        MealCustomizationSemanticAction(
          action: MealCustomizationAction.remove,
          componentKey: 'side',
          itemProductId: sideItemId,
        ),
      ],
      resolvedExtraActions: <MealCustomizationSemanticAction>[
        MealCustomizationSemanticAction(
          action: MealCustomizationAction.extra,
          chargeReason: MealCustomizationChargeReason.extraAdd,
          itemProductId: extraItemId,
          quantity: 1,
          priceDeltaMinor: 100,
        ),
      ],
      triggeredDiscounts: <MealCustomizationSemanticAction>[
        MealCustomizationSemanticAction(
          action: MealCustomizationAction.discount,
          chargeReason: MealCustomizationChargeReason.removalDiscount,
          componentKey: 'side',
          quantity: 1,
          priceDeltaMinor: -50,
          appliedRuleIds: const <int>[1],
        ),
      ],
      appliedRules: const <MealCustomizationAppliedRule>[
        MealCustomizationAppliedRule(
          ruleId: 1,
          ruleType: MealAdjustmentPricingRuleType.removeOnly,
          priceDeltaMinor: -50,
          specificityScore: 0,
          priority: 0,
          conditionKeys: <String>['removed:side'],
        ),
      ],
      totalAdjustmentMinor: 50,
    ),
  );

  if (makeLegacy) {
    await db.customStatement(
      'DELETE FROM meal_customization_line_snapshots WHERE transaction_line_id = ?',
      <Object?>[lineId],
    );
  }

  return _MealUiFixture(
    cashierId: cashierId,
    transactionId: transactionId,
    lineId: lineId,
  );
}

class _BreakfastUiFixture {
  const _BreakfastUiFixture({
    required this.database,
    required this.cashierId,
    required this.transactionId,
    required this.lineId,
    required this.set4ProductId,
    required this.eggProductId,
    required this.baconProductId,
    required this.sausageProductId,
    required this.beansProductId,
    required this.teaProductId,
    required this.hotDrinkGroupId,
    required this.toastBreadGroupId,
  });

  final app_db.AppDatabase database;
  final int cashierId;
  final int transactionId;
  final int lineId;
  final int set4ProductId;
  final int eggProductId;
  final int baconProductId;
  final int sausageProductId;
  final int beansProductId;
  final int teaProductId;
  final int hotDrinkGroupId;
  final int? toastBreadGroupId;
}

class _MealUiFixture {
  const _MealUiFixture({
    required this.cashierId,
    required this.transactionId,
    required this.lineId,
  });

  final int cashierId;
  final int transactionId;
  final int lineId;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
}

Future<int> _countExplicitNoneRows(
  app_db.AppDatabase database, {
  required int lineId,
  required int groupId,
}) async {
  final List<app_db.OrderModifier> rows =
      await (database.select(database.orderModifiers)
            ..where((tbl) => tbl.transactionLineId.equals(lineId))
            ..where((tbl) => tbl.sourceGroupId.equals(groupId))
            ..where((tbl) => tbl.action.equals('choice'))
            ..where((tbl) => tbl.chargeReason.equals('included_choice')))
          .get();
  return rows.where((row) => row.itemProductId == null).length;
}
