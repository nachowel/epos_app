import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/cashier_dashboard_snapshot.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/cashier_dashboard_provider.dart';
import 'package:epos_app/presentation/screens/dashboard/cashier_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  group('CashierDashboardScreen', () {
    testWidgets(
      'no active shift renders locked state and disables quick actions',
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
        await container.read(cashierDashboardNotifierProvider.notifier).load();

        await tester.pumpWidget(_routerApp(container));
        await tester.pumpAndSettle();

        expect(find.byType(CashierDashboardScreen), findsOneWidget);
        expect(find.textContaining('Shift closed'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const Key('cashier-dashboard-pos-action')),
          400,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const Key('cashier-dashboard-pos-action')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const Key('cashier-dashboard-orders-action')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(const Key('cashier-dashboard-preview-action')),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'open orders, preview status, and quick actions render',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int shiftId = await insertShift(db, openedBy: cashierId);
        await SettingsRepository(db).updateVisibilityRatio(0.5, userId: adminId);

        final int categoryId = await insertCategory(db, name: 'Drinks');
        final int teaId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 250,
        );
        final int breakfastId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Breakfast',
          priceMinor: 700,
        );

        final TransactionRepository transactionRepository = TransactionRepository(
          db,
        );
        final int openOrderId = await insertTransaction(
          db,
          uuid: 'dashboard-open-order',
          shiftId: shiftId,
          userId: cashierId,
          status: 'draft',
          totalAmountMinor: 1200,
        );
        await transactionRepository.addLine(
          transactionId: openOrderId,
          productId: teaId,
          quantity: 2,
        );
        await transactionRepository.addLine(
          transactionId: openOrderId,
          productId: breakfastId,
          quantity: 1,
        );

        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'dashboard-paid-order',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 1000,
          paidAt: DateTime(2026, 3, 28, 11, 0),
        );
        await insertPayment(
          db,
          uuid: 'dashboard-paid-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 1000,
          paidAt: DateTime(2026, 3, 28, 11, 0),
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
        await container.read(cashierDashboardNotifierProvider.notifier).load();

        await tester.pumpWidget(_routerApp(container));
        await tester.pumpAndSettle();

        expect(find.byType(CashierDashboardScreen), findsOneWidget);
        expect(find.textContaining('2 Tea, 1 Breakfast'), findsOneWidget);
        expect(find.text('Preview not yet taken'), findsOneWidget);
        expect(find.textContaining('Total Sales'), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const Key('cashier-dashboard-pos-action')),
          400,
        );
        await tester.ensureVisible(
          find.byKey(const Key('cashier-dashboard-pos-action')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('cashier-dashboard-pos-action')));
        await tester.pumpAndSettle();
        expect(find.text('POS TARGET'), findsOneWidget);

        final GoRouter router = GoRouter.of(
          tester.element(find.text('POS TARGET')),
        );
        router.go('/dashboard');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('cashier-dashboard-orders-action')),
          400,
        );
        await tester.ensureVisible(
          find.byKey(const Key('cashier-dashboard-orders-action')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('cashier-dashboard-orders-action')),
        );
        await tester.pumpAndSettle();
        expect(find.text('ORDERS TARGET'), findsOneWidget);

        router.go('/dashboard');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('cashier-dashboard-preview-action')),
          400,
        );
        await tester.ensureVisible(
          find.byKey(const Key('cashier-dashboard-preview-action')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('cashier-dashboard-preview-action')),
        );
        await tester.pumpAndSettle();
        expect(find.text('REPORTS TARGET'), findsOneWidget);
      },
    );

    testWidgets(
      'cashier dashboard omits monetary widgets and values',
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

        final int paidId = await insertTransaction(
          db,
          uuid: 'masked-test-order',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 2000,
          paidAt: DateTime(2026, 3, 28, 10, 0),
        );
        await insertPayment(
          db,
          uuid: 'masked-test-payment',
          transactionId: paidId,
          method: 'card',
          amountMinor: 2000,
          paidAt: DateTime(2026, 3, 28, 10, 0),
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
        await container.read(cashierDashboardNotifierProvider.notifier).load();
        await tester.pumpWidget(_routerApp(container));
        await tester.pumpAndSettle();

        expect(find.text('£20.00'), findsNothing);
        expect(find.textContaining('Total Sales'), findsNothing);
        expect(find.textContaining('Cash Total'), findsNothing);
        expect(find.textContaining('Card Total'), findsNothing);
        expect(find.textContaining('Cash Awareness'), findsNothing);
        expect(find.textContaining('Expected Cash'), findsNothing);
      },
    );

    testWidgets(
      'dashboard does not expose admin-only financial data',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int shiftId = await insertShift(db, openedBy: cashierId);
        await SettingsRepository(db).updateVisibilityRatio(0.5, userId: adminId);

        final int paidId = await insertTransaction(
          db,
          uuid: 'admin-only-test',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 1000,
          paidAt: DateTime(2026, 3, 28, 10, 0),
        );
        await insertPayment(
          db,
          uuid: 'admin-only-payment',
          transactionId: paidId,
          method: 'cash',
          amountMinor: 1000,
          paidAt: DateTime(2026, 3, 28, 10, 0),
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
        await container.read(cashierDashboardNotifierProvider.notifier).load();

        await tester.pumpWidget(_routerApp(container));
        await tester.pumpAndSettle();

        expect(find.text('£10.00'), findsNothing);
        expect(find.textContaining('Total Sales'), findsNothing);
        expect(find.textContaining('Cash Total'), findsNothing);
        expect(find.textContaining('Card Total'), findsNothing);
      },
    );

    testWidgets(
      'last activity shows newest-first operational items via provider',
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

        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'activity-older',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 400,
          paidAt: DateTime(2026, 3, 28, 9, 0),
        );
        await insertPayment(
          db,
          uuid: 'activity-older-pay',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 400,
          paidAt: DateTime(2026, 3, 28, 9, 0),
        );

        await insertTransaction(
          db,
          uuid: 'activity-newer',
          shiftId: shiftId,
          userId: cashierId,
          status: 'cancelled',
          totalAmountMinor: 200,
          cancelledAt: DateTime(2026, 3, 28, 10, 0),
          cancelledBy: cashierId,
        );

        await AuditLogRepository(db).createAuditLog(
          actorUserId: cashierId,
          action: 'receipt_reprinted',
          entityType: 'transaction',
          entityId: 'activity-older',
          metadataJson: '{}',
          createdAt: DateTime(2026, 3, 28, 11, 0),
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
        await container.read(cashierDashboardNotifierProvider.notifier).load();

        final CashierDashboardSnapshot? snapshot = container
            .read(cashierDashboardNotifierProvider)
            .snapshot;

        expect(snapshot, isNotNull);
        expect(snapshot!.activity.length, greaterThanOrEqualTo(3));
        // Newest first: reprint (11:00), cancellation (10:00), payment (9:00)
        expect(
          snapshot.activity[0].type,
          CashierDashboardActivityType.receiptReprint,
        );
        expect(
          snapshot.activity[1].type,
          CashierDashboardActivityType.cancellation,
        );
        expect(
          snapshot.activity[2].type,
          CashierDashboardActivityType.payment,
        );
      },
    );

    testWidgets(
      'open orders count and list are shown correctly via provider',
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

        final int categoryId = await insertCategory(db, name: 'Food');
        final int coffeeId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Coffee',
          priceMinor: 350,
        );

        final TransactionRepository transactionRepository = TransactionRepository(
          db,
        );
        final int order1 = await insertTransaction(
          db,
          uuid: 'open-list-1',
          shiftId: shiftId,
          userId: cashierId,
          status: 'draft',
          totalAmountMinor: 350,
        );
        await transactionRepository.addLine(
          transactionId: order1,
          productId: coffeeId,
          quantity: 1,
        );
        final int order2 = await insertTransaction(
          db,
          uuid: 'open-list-2',
          shiftId: shiftId,
          userId: cashierId,
          status: 'draft',
          totalAmountMinor: 700,
        );
        await transactionRepository.addLine(
          transactionId: order2,
          productId: coffeeId,
          quantity: 2,
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
        await container.read(cashierDashboardNotifierProvider.notifier).load();

        final CashierDashboardSnapshot? snapshot = container
            .read(cashierDashboardNotifierProvider)
            .snapshot;

        expect(snapshot, isNotNull);
        expect(snapshot!.openOrderCount, 2);
        expect(snapshot.openOrders.length, 2);
        expect(snapshot.openOrders[0].shortContent, contains('Coffee'));
        expect(snapshot.openOrders[1].shortContent, contains('Coffee'));
      },
    );

    testWidgets(
      'no active shift shows no-shift warning banner',
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
        await container.read(cashierDashboardNotifierProvider.notifier).load();

        await tester.pumpWidget(_routerApp(container));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('warning-no-shift')), findsOneWidget);
      },
    );

    testWidgets(
      'cashier preview taken shows preview warning banner',
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
        await insertShift(
          db,
          openedBy: cashierId,
          cashierPreviewedBy: cashierId,
          cashierPreviewedAt: DateTime(2026, 3, 28, 16, 0),
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
        await container.read(cashierDashboardNotifierProvider.notifier).load();

        await tester.pumpWidget(_routerApp(container));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('warning-preview-taken')), findsOneWidget);
      },
    );

    testWidgets(
      'open order count 6+ shows high load warning',
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
        final int teaId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 200,
        );

        final TransactionRepository transactionRepository = TransactionRepository(
          db,
        );
        for (int i = 0; i < 7; i++) {
          final int txId = await insertTransaction(
            db,
            uuid: 'high-load-$i',
            shiftId: shiftId,
            userId: cashierId,
            status: 'draft',
            totalAmountMinor: 200,
          );
          await transactionRepository.addLine(
            transactionId: txId,
            productId: teaId,
            quantity: 1,
          );
        }

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
        await container.read(cashierDashboardNotifierProvider.notifier).load();

        await tester.pumpWidget(_routerApp(container));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('warning-high-load')), findsOneWidget);
      },
    );

  });
}

Widget _routerApp(ProviderContainer container) {
  final GoRouter router = GoRouter(
    initialLocation: '/dashboard',
    routes: <RouteBase>[
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const CashierDashboardScreen(),
      ),
      GoRoute(
        path: '/pos',
        builder: (_, __) => const Scaffold(body: Center(child: Text('POS TARGET'))),
      ),
      GoRoute(
        path: '/orders',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('ORDERS TARGET'))),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('REPORTS TARGET'))),
      ),
      GoRoute(
        path: '/shifts',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/login',
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
