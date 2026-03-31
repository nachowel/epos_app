import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart'
    show AppDatabase, TransactionLinesCompanion;
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/orders/open_orders_screen.dart';
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

  testWidgets('open orders rows show count metadata and direct pay action', (
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

    expect(find.byType(OpenOrdersScreen), findsOneWidget);
    expect(find.text('Pay £15.80'), findsOneWidget);
    final Finder metadataFinder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is Text &&
          widget.data != null &&
          widget.data!.contains('3 items · SE5 Breakfast, Latte, Cappuccino'),
    );
    expect(metadataFinder, findsOneWidget);

    final Text metadataText = tester.widget<Text>(metadataFinder);
    expect(metadataText.maxLines, 1);
    expect(metadataText.overflow, TextOverflow.ellipsis);
    expect(
      find.text('18:28 · 3 items · SE5 Breakfast, Latte, Cappuccino'),
      findsNothing,
    );

    await tester.tap(find.byKey(Key('open-order-pay-$orderId')));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentDialog), findsOneWidget);
    expect(find.text('detail-$orderId'), findsNothing);
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

    await tester.tap(find.byKey(Key('open-order-row-$orderId')));
    await tester.pumpAndSettle();

    expect(find.text('detail-$orderId'), findsOneWidget);
    expect(find.byType(OpenOrdersScreen), findsNothing);
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
      GoRoute(path: '/orders', builder: (_, __) => const OpenOrdersScreen()),
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
