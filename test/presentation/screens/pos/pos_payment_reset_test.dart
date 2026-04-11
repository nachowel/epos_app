import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/cart_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/products_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/pos/category_entry_screen.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  group('POS payment reset flow', () {
    testWidgets(
      'navbar Categories entry navigates directly when no order is active',
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1800, 1200);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int categoryId = await insertCategory(
          db,
          name: 'Drinks',
          sortOrder: 0,
        );
        await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 250,
        );
        await insertShift(db, openedBy: cashierId);

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
          _routerApp(container, initialLocation: '/pos?categoryId=$categoryId'),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('section_app_bar_inline_nav_/pos/categories'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CategoryEntryScreen), findsOneWidget);
        expect(find.text('Start new order?'), findsNothing);
      },
    );

    testWidgets(
      'navbar Categories entry confirms before clearing an active cart',
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1800, 1200);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int categoryId = await insertCategory(
          db,
          name: 'Drinks',
          sortOrder: 0,
        );
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 250,
        );
        await insertShift(db, openedBy: cashierId);

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
        container
            .read(cartNotifierProvider.notifier)
            .addProduct(_product(productId, categoryId));

        await tester.pumpWidget(
          _routerApp(container, initialLocation: '/pos?categoryId=$categoryId'),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(
            const ValueKey<String>('section_app_bar_inline_nav_/pos/categories'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Start new order?'), findsOneWidget);
        expect(find.text('Current order will be cleared.'), findsOneWidget);

        await tester.tap(find.text(AppStrings.cancel));
        await tester.pumpAndSettle();

        expect(find.byType(PosScreen), findsOneWidget);
        expect(container.read(cartNotifierProvider).items, hasLength(1));
        expect(
          container.read(productsNotifierProvider).selectedCategoryId,
          categoryId,
        );

        await tester.tap(
          find.byKey(
            const ValueKey<String>('section_app_bar_inline_nav_/pos/categories'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        expect(find.byType(CategoryEntryScreen), findsOneWidget);
        expect(container.read(cartNotifierProvider).items, isEmpty);
        expect(
          container.read(productsNotifierProvider).selectedCategoryId,
          isNull,
        );
        expect(container.read(productsNotifierProvider).products, isEmpty);
        expect(container.read(ordersNotifierProvider).selectedOrderId, isNull);
      },
    );

    testWidgets(
      'successful payment clears POS state and returns to Category Entry',
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1800, 1200);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int categoryId = await insertCategory(
          db,
          name: 'Drinks',
          sortOrder: 0,
        );
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 250,
        );
        await insertShift(db, openedBy: cashierId);

        late _SuccessfulPayNowOrdersNotifier ordersNotifier;
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            ordersNotifierProvider.overrideWith((Ref ref) {
              ordersNotifier = _SuccessfulPayNowOrdersNotifier(ref);
              return ordersNotifier;
            }),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(cashierId);
        await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
        container
            .read(cartNotifierProvider.notifier)
            .addProduct(_product(productId, categoryId));

        await tester.pumpWidget(
          _routerApp(container, initialLocation: '/pos?categoryId=$categoryId'),
        );
        await tester.pumpAndSettle();

        expect(
          container.read(productsNotifierProvider).selectedCategoryId,
          categoryId,
        );

        await tester.tap(
          find.widgetWithText(ElevatedButton, AppStrings.checkout),
        );
        await _pumpOverlayTransition(tester);
        await tester.tap(
          find.widgetWithText(ElevatedButton, '${AppStrings.payAction} £2.50'),
        );
        await _pumpOverlayTransition(tester);
        await tester.tap(find.byKey(const ValueKey<String>('payment-submit')));
        await _pumpOverlayTransition(tester, steps: 16);

        expect(find.byType(CategoryEntryScreen), findsOneWidget);
        expect(container.read(cartNotifierProvider).items, isEmpty);
        expect(
          container.read(productsNotifierProvider).selectedCategoryId,
          isNull,
        );
        expect(container.read(productsNotifierProvider).products, isEmpty);
        expect(container.read(ordersNotifierProvider).selectedOrderId, isNull);
        expect(container.read(ordersNotifierProvider).errorMessage, isNull);
        expect(ordersNotifier.createOrderCalls, 1);
      },
    );

    testWidgets('cancelled payment keeps POS state intact', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1800, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int categoryId = await insertCategory(
        db,
        name: 'Drinks',
        sortOrder: 0,
      );
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Tea',
        priceMinor: 250,
      );
      await insertShift(db, openedBy: cashierId);

      late _SuccessfulPayNowOrdersNotifier ordersNotifier;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith((Ref ref) {
            ordersNotifier = _SuccessfulPayNowOrdersNotifier(ref);
            return ordersNotifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
      container
          .read(cartNotifierProvider.notifier)
          .addProduct(_product(productId, categoryId));

      await tester.pumpWidget(
        _routerApp(container, initialLocation: '/pos?categoryId=$categoryId'),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(ElevatedButton, AppStrings.checkout),
      );
      await _pumpOverlayTransition(tester);
      await tester.tap(
        find.widgetWithText(ElevatedButton, '${AppStrings.payAction} £2.50'),
      );
      await _pumpOverlayTransition(tester);
      await tester.tap(find.byKey(const ValueKey<String>('payment-cancel')));
      await _pumpOverlayTransition(tester);

      expect(find.byType(PosScreen), findsOneWidget);
      expect(find.byType(CategoryEntryScreen), findsNothing);
      expect(container.read(cartNotifierProvider).items, hasLength(1));
      expect(
        container.read(productsNotifierProvider).selectedCategoryId,
        categoryId,
      );
      expect(ordersNotifier.createOrderCalls, 0);
    });

    testWidgets('failed payment keeps POS state intact and does not navigate', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1800, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int categoryId = await insertCategory(
        db,
        name: 'Drinks',
        sortOrder: 0,
      );
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Tea',
        priceMinor: 250,
      );
      await insertShift(db, openedBy: cashierId);

      late _FailedPayNowOrdersNotifier ordersNotifier;
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith((Ref ref) {
            ordersNotifier = _FailedPayNowOrdersNotifier(ref);
            return ordersNotifier;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
      container
          .read(cartNotifierProvider.notifier)
          .addProduct(_product(productId, categoryId));

      await tester.pumpWidget(
        _routerApp(container, initialLocation: '/pos?categoryId=$categoryId'),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(ElevatedButton, AppStrings.checkout),
      );
      await _pumpOverlayTransition(tester);
      await tester.tap(
        find.widgetWithText(ElevatedButton, '${AppStrings.payAction} £2.50'),
      );
      await _pumpOverlayTransition(tester);
      await tester.tap(find.byKey(const ValueKey<String>('payment-submit')));
      await _pumpOverlayTransition(tester);

      expect(find.byType(PosScreen), findsOneWidget);
      expect(find.byType(CategoryEntryScreen), findsNothing);
      expect(
        find.text(_FailedPayNowOrdersNotifier.failureMessage),
        findsOneWidget,
      );
      expect(container.read(cartNotifierProvider).items, hasLength(1));
      expect(
        container.read(productsNotifierProvider).selectedCategoryId,
        categoryId,
      );
      expect(container.read(ordersNotifierProvider).selectedOrderId, isNull);
      expect(ordersNotifier.createOrderCalls, 1);
    });
  });
}

Widget _routerApp(
  ProviderContainer container, {
  required String initialLocation,
}) {
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/pos',
        builder: (_, GoRouterState state) => PosScreen(
          initialCategoryId: int.tryParse(
            state.uri.queryParameters['categoryId'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/pos/categories',
        builder: (_, __) => const CategoryEntryScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/orders',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/shifts',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

Product _product(int productId, int categoryId) {
  return Product(
    id: productId,
    categoryId: categoryId,
    name: 'Tea',
    priceMinor: 250,
    imageUrl: null,
    hasModifiers: false,
    isActive: true,
    sortOrder: 0,
  );
}

Future<void> _pumpOverlayTransition(
  WidgetTester tester, {
  int steps = 8,
}) async {
  for (int index = 0; index < steps; index += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _SuccessfulPayNowOrdersNotifier extends OrdersNotifier {
  _SuccessfulPayNowOrdersNotifier(super.ref);

  int createOrderCalls = 0;

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(
      openOrders: const <Transaction>[],
      lineCountByOrderId: const <int, int>{},
      selectedOrderId: null,
      isRefreshing: false,
      errorMessage: null,
    );
  }

  @override
  Future<Transaction?> createOrderFromCart({
    required User currentUser,
    int? tableNumber,
    PaymentMethod? immediatePaymentMethod,
  }) async {
    createOrderCalls += 1;
    state = state.copyWith(
      selectedOrderId: 9001,
      errorMessage: 'stale paid order context',
    );
    final DateTime now = DateTime(2026, 4, 10, 12, 0);
    return Transaction(
      id: 9001,
      uuid: 'paid-transaction',
      shiftId: 1,
      userId: currentUser.id,
      tableNumber: tableNumber,
      status: TransactionStatus.paid,
      subtotalMinor: 250,
      modifierTotalMinor: 0,
      totalAmountMinor: 250,
      createdAt: now,
      paidAt: now,
      updatedAt: now,
      cancelledAt: null,
      cancelledBy: null,
      idempotencyKey: 'paid-idempotency-key',
      kitchenPrinted: true,
      receiptPrinted: true,
    );
  }
}

class _FailedPayNowOrdersNotifier extends OrdersNotifier {
  _FailedPayNowOrdersNotifier(super.ref);

  static const String failureMessage = 'Test payment failed.';
  int createOrderCalls = 0;

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: false, errorMessage: null);
  }

  @override
  Future<Transaction?> createOrderFromCart({
    required User currentUser,
    int? tableNumber,
    PaymentMethod? immediatePaymentMethod,
  }) async {
    createOrderCalls += 1;
    state = state.copyWith(errorMessage: failureMessage);
    return null;
  }
}
