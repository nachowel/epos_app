import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/providers/app_providers.dart';
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

import '../../../support/test_database.dart';

void main() {
  testWidgets(
    'semantic product opens semantic editor, enforces required choice, and stores structured cart state',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _PosSemanticFixture fixture = await _seedPosSemanticFixture(db);
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

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Breakfast'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
        findsOneWidget,
      );
      expect(find.byType(ModifierPopup), findsNothing);

      final ElevatedButton disabledConfirm = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      expect(disabledConfirm.onPressed, isNull);
      expect(
        find.textContaining('Choose an option for Drink choice.'),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(
          ValueKey<String>(
            'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
          ),
        ),
      );
      await tester.tap(
        find.byKey(
          ValueKey<String>(
            'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
          ),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(
          ValueKey<String>('semantic-include-${fixture.beansProductId}'),
        ),
      );
      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-include-${fixture.beansProductId}'),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey<String>('semantic-add-inc-${fixture.hashBrownProductId}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-add-inc-${fixture.teaProductId}'),
        ),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(
          ValueKey<String>('semantic-add-inc-${fixture.hashBrownProductId}'),
        ),
      );
      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-add-inc-${fixture.hashBrownProductId}'),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final ElevatedButton enabledConfirm = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      expect(enabledConfirm.onPressed, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      await tester.pumpAndSettle();

      final cartState = container.read(cartNotifierProvider);
      expect(cartState.items, hasLength(1));
      final item = cartState.items.single;
      expect(item.breakfastSelection, isNotNull);
      expect(
        item
            .breakfastSelection!
            .requestedState
            .chosenGroups
            .single
            .selectedItemProductId,
        fixture.teaProductId,
      );
      expect(
        item
            .breakfastSelection!
            .requestedState
            .removedSetItems
            .single
            .itemProductId,
        fixture.beansProductId,
      );
      expect(
        item
            .breakfastSelection!
            .requestedState
            .addedProducts
            .single
            .itemProductId,
        fixture.hashBrownProductId,
      );
    },
  );

  testWidgets('flat modifier products still use the legacy popup path', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final _PosSemanticFixture fixture = await _seedPosSemanticFixture(db);
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

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drinks').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flat Tea'));
    await tester.pumpAndSettle();

    expect(find.byType(ModifierPopup), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
      findsNothing,
    );
  });

  testWidgets('invalid semantic config blocks sale without opening dialog', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final _PosSemanticFixture fixture = await _seedPosSemanticFixture(
      db,
      groupMaxSelect: 2,
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
        .loadUserById(fixture.cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Breakfast'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
      findsNothing,
    );
    expect(find.byType(ModifierPopup), findsNothing);
    expect(
      find.textContaining('POS currently supports one selection per group.'),
      findsOneWidget,
    );
  });
}

Future<_PosSemanticFixture> _seedPosSemanticFixture(
  AppDatabase db, {
  int groupMaxSelect = 1,
}) async {
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
  final int flatProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Flat Tea',
    priceMinor: 250,
    hasModifiers: true,
  );
  final int hashBrownProductId = await insertProduct(
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
          maxSelect: Value<int>(groupMaxSelect),
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
  await db
      .into(db.productModifiers)
      .insert(
        ProductModifiersCompanion.insert(
          productId: rootProductId,
          itemProductId: Value<int?>(hashBrownProductId),
          name: 'Hash Brown',
          type: 'extra',
          extraPriceMinor: const Value<int>(0),
        ),
      );

  await db
      .into(db.productModifiers)
      .insert(
        ProductModifiersCompanion.insert(
          productId: flatProductId,
          name: 'Lemon',
          type: 'extra',
          extraPriceMinor: const Value<int>(20),
        ),
      );

  return _PosSemanticFixture(
    cashierId: cashierId,
    drinkGroupId: drinkGroupId,
    teaProductId: teaProductId,
    beansProductId: beansProductId,
    hashBrownProductId: hashBrownProductId,
  );
}

class _PosSemanticFixture {
  const _PosSemanticFixture({
    required this.cashierId,
    required this.drinkGroupId,
    required this.teaProductId,
    required this.beansProductId,
    required this.hashBrownProductId,
  });

  final int cashierId;
  final int drinkGroupId;
  final int teaProductId;
  final int beansProductId;
  final int hashBrownProductId;
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
