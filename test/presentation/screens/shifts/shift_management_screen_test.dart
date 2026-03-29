import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/screens/shifts/shift_management_screen.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  group('ShiftManagementScreen', () {
    testWidgets(
      'cashier sees operational shift data without financial summary rows',
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
        final int shiftId = await insertShift(
          db,
          openedBy: cashierId,
          cashierPreviewedBy: cashierId,
          cashierPreviewedAt: DateTime(2026, 3, 28, 17, 45),
        );
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'cashier-shift-paid',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 1875,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertPayment(
          db,
          uuid: 'cashier-shift-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 1875,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertTransaction(
          db,
          uuid: 'cashier-shift-sent',
          shiftId: shiftId,
          userId: cashierId,
          status: 'sent',
          totalAmountMinor: 500,
          updatedAt: DateTime(2026, 3, 28, 18, 0),
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

        await tester.pumpWidget(_shiftManagementApp(container));
        await tester.pumpAndSettle();

        expect(find.byType(ShiftManagementScreen), findsOneWidget);
        expect(find.text('Current Shift Summary'), findsOneWidget);
        expect(find.text('Shift ID'), findsWidgets);
        expect(find.text('Status'), findsWidgets);
        expect(find.text('Opened'), findsWidgets);
        expect(find.text('Opened by'), findsWidgets);
        expect(find.text('Cashier Preview Time'), findsOneWidget);
        expect(find.text('Cashier Preview By'), findsOneWidget);
        expect(find.text('Sent Orders Blocking Close'), findsOneWidget);
        expect(find.text('Fresh Drafts Blocking Close'), findsOneWidget);
        expect(find.text('Stale Drafts Pending Cleanup'), findsOneWidget);
        expect(find.text('Expected Cash'), findsNothing);
        expect(find.text('Gross Sales'), findsNothing);
        expect(find.text('Refund Total'), findsNothing);
        expect(find.text('Net Sales'), findsNothing);
        expect(find.textContaining('Gross Cash'), findsNothing);
        expect(find.textContaining('Net Cash'), findsNothing);
        expect(find.textContaining('Gross Card'), findsNothing);
        expect(find.textContaining('Net Card'), findsNothing);
        expect(find.text('£18.75'), findsNothing);
      },
    );

    testWidgets('admin still sees shift financial summary rows', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int paidOrderId = await insertTransaction(
        db,
        uuid: 'admin-shift-paid',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 1875,
        paidAt: DateTime(2026, 3, 28, 12, 15),
      );
      await insertPayment(
        db,
        uuid: 'admin-shift-payment',
        transactionId: paidOrderId,
        method: 'cash',
        amountMinor: 1875,
        paidAt: DateTime(2026, 3, 28, 12, 15),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);

      await tester.pumpWidget(_shiftManagementApp(container));
      await tester.pumpAndSettle();

      expect(find.byType(ShiftManagementScreen), findsOneWidget);
      expect(find.text('Expected Cash'), findsOneWidget);
      expect(find.text('Gross Sales'), findsOneWidget);
      expect(find.text('Refund Total'), findsOneWidget);
      expect(find.text('Net Sales'), findsOneWidget);
      expect(find.textContaining('Gross Cash'), findsOneWidget);
      expect(find.textContaining('Net Cash'), findsOneWidget);
      expect(find.textContaining('Gross Card'), findsOneWidget);
      expect(find.textContaining('Net Card'), findsOneWidget);
      expect(find.text('Enter Counted Cash'), findsOneWidget);
      expect(find.text('£18.75'), findsWidgets);
    });

    testWidgets(
      'admin final close shows explicit blocker message instead of generic failure',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'admin-shift-paid-block-message',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 1875,
          paidAt: DateTime(2026, 3, 28, 12, 15),
        );
        await insertPayment(
          db,
          uuid: 'admin-shift-payment-block-message',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 1875,
          paidAt: DateTime(2026, 3, 28, 12, 15),
        );
        await insertTransaction(
          db,
          uuid: 'admin-shift-sent-block-message',
          shiftId: shiftId,
          userId: adminId,
          status: 'sent',
          totalAmountMinor: 500,
          updatedAt: DateTime(2026, 3, 28, 18, 0),
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
            .loadUserById(adminId);

        await tester.pumpWidget(_shiftManagementApp(container));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Enter Counted Cash'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enter Counted Cash'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '1875');
        await tester.tap(
          find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(AppStrings.shiftCloseBlockedSentOrders(1)),
          findsOneWidget,
        );
        expect(find.text(AppStrings.operationFailed), findsNothing);
      },
    );

    testWidgets(
      'admin final close shows recovery dialog when stale reconciliation exists',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'admin-shift-paid-stale-reconciliation',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 1875,
          paidAt: DateTime(2026, 3, 28, 12, 15),
        );
        await insertPayment(
          db,
          uuid: 'admin-shift-payment-stale-reconciliation',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 1875,
          paidAt: DateTime(2026, 3, 28, 12, 15),
        );
        await insertShiftReconciliation(
          db,
          uuid: 'admin-shift-existing-final-close-reconciliation',
          shiftId: shiftId,
          expectedCashMinor: 1875,
          countedCashMinor: 1875,
          varianceMinor: 0,
          countedBy: adminId,
          countedAt: DateTime(2026, 3, 28, 18, 0),
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
            .loadUserById(adminId);

        await tester.pumpWidget(_shiftManagementApp(container));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Enter Counted Cash'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enter Counted Cash'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '1875');
        await tester.tap(
          find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(AppStrings.previousFinalCloseAttemptDetected),
          findsOneWidget,
        );
        expect(find.text(AppStrings.resumeFinalCloseAction), findsOneWidget);
        expect(find.text(AppStrings.discardAndReenterAction), findsOneWidget);
        expect(find.text(AppStrings.cancel), findsOneWidget);
        expect(find.text('Shift ID'), findsWidgets);
        expect(find.text('Counted Cash'), findsWidgets);
        expect(find.text('Expected Cash'), findsWidgets);
        expect(find.text('Variance'), findsWidgets);
        expect(find.text('Counted At'), findsOneWidget);
        expect(find.text('Counted By'), findsOneWidget);
        expect(find.text('Admin (#1)'), findsOneWidget);
        expect(find.text(AppStrings.operationFailed), findsNothing);
      },
    );
  });
}

Widget _shiftManagementApp(ProviderContainer container) {
  final GoRouter router = GoRouter(
    initialLocation: '/shifts',
    routes: <RouteBase>[
      GoRoute(
        path: '/shifts',
        builder: (_, __) => const ShiftManagementScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/pos',
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
        path: '/admin',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/settings',
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
