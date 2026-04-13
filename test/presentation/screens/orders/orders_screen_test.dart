import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart'
    show AppDatabase, TransactionLinesCompanion;
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/orders/orders_screen.dart';
import 'package:epos_app/presentation/screens/pos/widgets/payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  setUp(() {
    AppLocalizationService.instance.setLocale(const Locale('en'));
  });

  testWidgets(
    'orders screen shows history with filters and direct pay action',
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
      final int closedShiftId = await insertShift(
        db,
        openedBy: cashierId,
        status: 'closed',
        closedBy: cashierId,
        closedAt: DateTime.now(),
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Breakfast');
      final int breakfastId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'SE5 Breakfast',
        priceMinor: 850,
      );
      final int latteId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Latte',
        priceMinor: 350,
      );
      final int cappuccinoId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Cappuccino',
        priceMinor: 380,
      );
      final int orderId = await insertTransaction(
        db,
        uuid: 'open-orders-screen-order',
        shiftId: shiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 1580,
      );
      final int paidOrderId = await insertTransaction(
        db,
        uuid: 'orders-screen-paid-history',
        shiftId: closedShiftId,
        userId: cashierId,
        status: 'paid',
        totalAmountMinor: 420,
      );

      await _insertOrderLine(
        db,
        uuid: 'open-orders-screen-line-1',
        transactionId: orderId,
        productId: breakfastId,
        productName: 'SE5 Breakfast',
        unitPriceMinor: 850,
        lineTotalMinor: 850,
      );
      await _insertOrderLine(
        db,
        uuid: 'open-orders-screen-line-2',
        transactionId: orderId,
        productId: latteId,
        productName: 'Latte',
        unitPriceMinor: 350,
        lineTotalMinor: 350,
      );
      await _insertOrderLine(
        db,
        uuid: 'open-orders-screen-line-3',
        transactionId: orderId,
        productId: cappuccinoId,
        productName: 'Cappuccino',
        unitPriceMinor: 380,
        lineTotalMinor: 380,
      );
      await _insertOrderLine(
        db,
        uuid: 'orders-screen-history-line',
        transactionId: paidOrderId,
        productId: latteId,
        productName: 'Latte',
        unitPriceMinor: 420,
        lineTotalMinor: 420,
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

      await tester.pumpWidget(_ordersApp(container));
      await tester.pumpAndSettle();

      expect(find.byType(OrdersScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('orders-filter-all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('orders-filter-paid')),
        findsOneWidget,
      );
      expect(find.text('Pay'), findsOneWidget);
      final Finder metadataFinder = find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text &&
            widget.data != null &&
            widget.data!.contains('SE5 Breakfast, Latte, Cappuccino'),
      );
      expect(metadataFinder, findsOneWidget);
      expect(find.text('Order #$paidOrderId'), findsOneWidget);

      final Text metadataText = tester.widget<Text>(metadataFinder);
      expect(metadataText.maxLines, 2);
      expect(metadataText.overflow, TextOverflow.ellipsis);

      await tester.tap(find.byKey(Key('orders-pay-$orderId')));
      await tester.pumpAndSettle();

      expect(find.byType(PaymentDialog), findsOneWidget);
      expect(find.text('detail-$orderId'), findsNothing);

      final Finder cancelFinder = find.byKey(
        const ValueKey<String>('payment-cancel'),
        skipOffstage: false,
      );
      await tester.ensureVisible(cancelFinder);
      await tester.pumpAndSettle();
      await tester.tap(cancelFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('orders-filter-paid')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order #$paidOrderId'), findsOneWidget);
      expect(find.text('Order #$orderId'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('orders-filter-openSent')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order #$orderId'), findsOneWidget);
      expect(find.text('Order #$paidOrderId'), findsNothing);
    },
  );

  testWidgets('orders screen supports quick date filter and order search', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
    final int shiftId = await insertShift(db, openedBy: cashierId);
    final int categoryId = await insertCategory(db, name: 'Drinks');
    final int productId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Flat White',
      priceMinor: 350,
    );
    final int todayOrderId = await insertTransaction(
      db,
      uuid: 'orders-screen-today',
      shiftId: shiftId,
      userId: cashierId,
      status: 'paid',
      totalAmountMinor: 350,
    );
    final int oldOrderId = await insertTransaction(
      db,
      uuid: 'orders-screen-old',
      shiftId: shiftId,
      userId: cashierId,
      status: 'paid',
      totalAmountMinor: 350,
    );
    await _insertOrderLine(
      db,
      uuid: 'orders-screen-today-line',
      transactionId: todayOrderId,
      productId: productId,
      productName: 'Flat White',
      unitPriceMinor: 350,
      lineTotalMinor: 350,
    );
    await _insertOrderLine(
      db,
      uuid: 'orders-screen-old-line',
      transactionId: oldOrderId,
      productId: productId,
      productName: 'Flat White',
      unitPriceMinor: 350,
      lineTotalMinor: 350,
    );
    await db.customStatement(
      'UPDATE transactions SET created_at = ?, updated_at = ? WHERE id = ?',
      <Object?>[
        DateTime(2025, 1, 5).millisecondsSinceEpoch ~/ 1000,
        DateTime(2025, 1, 5).millisecondsSinceEpoch ~/ 1000,
        oldOrderId,
      ],
    );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.notifier).loadUserById(cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_ordersApp(container));
    await tester.pumpAndSettle();

    expect(find.text('Order #$todayOrderId'), findsOneWidget);
    expect(find.text('Order #$oldOrderId'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('orders-date-filter-allTime')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order #$todayOrderId'), findsOneWidget);
    expect(find.text('Order #$oldOrderId'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('orders-search-field')),
      '$oldOrderId',
    );
    await tester.tap(find.byKey(const ValueKey<String>('orders-search-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Order #$oldOrderId'), findsOneWidget);
    expect(find.text('Order #$todayOrderId'), findsNothing);
  });

  testWidgets('tapping the row opens the order detail route', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final int cashierId = await insertUser(
      db,
      name: 'Cashier',
      role: 'cashier',
    );
    final int shiftId = await insertShift(db, openedBy: cashierId);
    final int categoryId = await insertCategory(db, name: 'Drinks');
    final int coffeeId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Americano',
      priceMinor: 250,
    );
    final int orderId = await insertTransaction(
      db,
      uuid: 'open-orders-screen-route-order',
      shiftId: shiftId,
      userId: cashierId,
      status: 'sent',
      totalAmountMinor: 250,
    );

    await _insertOrderLine(
      db,
      uuid: 'open-orders-screen-route-line',
      transactionId: orderId,
      productId: coffeeId,
      productName: 'Americano',
      unitPriceMinor: 250,
      lineTotalMinor: 250,
    );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.notifier).loadUserById(cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_ordersApp(container));
    await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('orders-row-$orderId')));
    await tester.pumpAndSettle();

    expect(find.text('detail-$orderId'), findsOneWidget);
    expect(find.byType(OrdersScreen), findsNothing);
  });
}

Future<void> _insertOrderLine(
  AppDatabase db, {
  required String uuid,
  required int transactionId,
  required int productId,
  required String productName,
  required int unitPriceMinor,
  required int lineTotalMinor,
}) async {
  await db
      .into(db.transactionLines)
      .insert(
        TransactionLinesCompanion.insert(
          uuid: uuid,
          transactionId: transactionId,
          productId: productId,
          productName: productName,
          unitPriceMinor: unitPriceMinor,
          lineTotalMinor: lineTotalMinor,
        ),
      );
}

Widget _ordersApp(ProviderContainer container) {
  final GoRouter router = GoRouter(
    initialLocation: '/orders',
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(
        path: '/orders/:transactionId',
        builder: (_, GoRouterState state) => Scaffold(
          body: Center(
            child: Text('detail-${state.pathParameters['transactionId']}'),
          ),
        ),
      ),
      GoRoute(path: '/pos', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(path: '/reports', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(path: '/shifts', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(path: '/dashboard', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(path: '/admin', builder: (_, __) => const SizedBox.shrink()),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}
