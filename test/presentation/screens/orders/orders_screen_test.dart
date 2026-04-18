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

  testWidgets('cashier orders screen shows active queue plus paid reprints', (
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
      paidAt: DateTime.now(),
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

    await container.read(authNotifierProvider.notifier).loadUserById(cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_ordersApp(container));
    await tester.pumpAndSettle();

    expect(find.byType(OrdersScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('orders-search-field')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('orders-filter-all')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('orders-date-filter-today')),
      findsNothing,
    );
    expect(find.text('Pay'), findsOneWidget);
    expect(find.byKey(Key('orders-kitchen-$orderId')), findsOneWidget);
    expect(find.byKey(Key('orders-receipt-$orderId')), findsOneWidget);
    expect(find.byKey(Key('orders-kitchen-$paidOrderId')), findsOneWidget);
    expect(find.byKey(Key('orders-receipt-$paidOrderId')), findsOneWidget);
    final Finder metadataFinder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text &&
          widget.data != null &&
          widget.data!.contains('SE5 Breakfast, Latte, Cappuccino'),
    );
    expect(metadataFinder, findsOneWidget);
    expect(find.text('Order #$paidOrderId'), findsOneWidget);
    expect(find.text('Order #$orderId'), findsOneWidget);

    final ElevatedButton sentPayButton = tester.widget<ElevatedButton>(
      find.byKey(Key('orders-pay-$orderId')),
    );
    expect(sentPayButton.onPressed, isNotNull);

    final OutlinedButton paidReceiptButton = tester.widget<OutlinedButton>(
      find.byKey(Key('orders-receipt-$paidOrderId')),
    );
    expect(paidReceiptButton.onPressed, isNotNull);
    final ElevatedButton paidKitchenButton = tester.widget<ElevatedButton>(
      find.byKey(Key('orders-kitchen-$paidOrderId')),
    );
    expect(paidKitchenButton.onPressed, isNotNull);
  });

  testWidgets(
    'cashier orders screen limits recent paid history to five newest today while keeping active queue',
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
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Drinks');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Flat White',
        priceMinor: 350,
      );
      final List<int> todayOrderIds = <int>[];
      final DateTime now = DateTime.now();
      final DateTime todayBase = DateTime(now.year, now.month, now.day, 9);
      for (int index = 0; index < 6; index++) {
        final int transactionId = await insertTransaction(
          db,
          uuid: 'orders-screen-today-$index',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 350,
          paidAt: todayBase.add(Duration(hours: index)),
        );
        todayOrderIds.add(transactionId);
        await _insertOrderLine(
          db,
          uuid: 'orders-screen-today-line-$index',
          transactionId: transactionId,
          productId: productId,
          productName: 'Flat White',
          unitPriceMinor: 350,
          lineTotalMinor: 350,
        );
      }
      final int yesterdayOrderId = await insertTransaction(
        db,
        uuid: 'orders-screen-yesterday',
        shiftId: shiftId,
        userId: cashierId,
        status: 'paid',
        totalAmountMinor: 350,
        paidAt: todayBase.subtract(const Duration(minutes: 15)),
      );
      await _insertOrderLine(
        db,
        uuid: 'orders-screen-yesterday-line',
        transactionId: yesterdayOrderId,
        productId: productId,
        productName: 'Flat White',
        unitPriceMinor: 350,
        lineTotalMinor: 350,
      );
      final int sentOrderId = await insertTransaction(
        db,
        uuid: 'orders-screen-sent',
        shiftId: shiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 350,
      );
      await _insertOrderLine(
        db,
        uuid: 'orders-screen-sent-line',
        transactionId: sentOrderId,
        productId: productId,
        productName: 'Flat White',
        unitPriceMinor: 350,
        lineTotalMinor: 350,
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

      expect(
        find.byKey(const ValueKey<String>('orders-search-field')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('orders-load-more')),
        findsNothing,
      );
      expect(find.text('Order #${todayOrderIds[0]}'), findsNothing);
      for (final int orderId in todayOrderIds.skip(1)) {
        expect(find.text('Order #$orderId'), findsOneWidget);
      }
      expect(find.text('Order #$yesterdayOrderId'), findsNothing);
      expect(find.text('Order #$sentOrderId'), findsOneWidget);
    },
  );

  testWidgets('cashier row tap does not open the order detail route', (
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
      status: 'paid',
      totalAmountMinor: 250,
      paidAt: DateTime.now(),
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

    await tester.tap(
      find.byKey(Key('orders-row-$orderId')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(find.text('detail-$orderId'), findsNothing);
    expect(find.byType(OrdersScreen), findsOneWidget);
  });

  testWidgets(
    'cashier orders screen disables kitchen reprint for custom-only paid orders',
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
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Misc');
      final int customProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Custom Sale',
        priceMinor: 0,
        isVisibleOnPos: false,
        isCustom: true,
      );
      final int orderId = await insertTransaction(
        db,
        uuid: 'orders-screen-custom-only',
        shiftId: shiftId,
        userId: cashierId,
        status: 'paid',
        totalAmountMinor: 650,
        paidAt: DateTime.now(),
      );

      await _insertOrderLine(
        db,
        uuid: 'orders-screen-custom-only-line',
        transactionId: orderId,
        productId: customProductId,
        productName: 'Custom Sale',
        unitPriceMinor: 650,
        lineTotalMinor: 650,
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

      final OutlinedButton receiptButton = tester.widget<OutlinedButton>(
        find.byKey(Key('orders-receipt-$orderId')),
      );
      final ElevatedButton kitchenButton = tester.widget<ElevatedButton>(
        find.byKey(Key('orders-kitchen-$orderId')),
      );

      expect(receiptButton.onPressed, isNotNull);
      expect(kitchenButton.onPressed, isNull);
    },
  );
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
