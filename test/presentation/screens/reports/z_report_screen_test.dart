import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/domain/models/business_identity_settings.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/screens/reports/z_report_screen.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  group('ZReportScreen', () {
    testWidgets(
      'opening cashier Z Report modal is side-effect free and closing leaves preview state unchanged',
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
          name: 'Latte',
          priceMinor: 2450,
        );
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'cashier-report-paid',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 2450,
          paidAt: DateTime(2026, 3, 28, 13, 30),
        );
        await insertPayment(
          db,
          uuid: 'cashier-report-payment',
          transactionId: paidOrderId,
          method: 'card',
          amountMinor: 2450,
          paidAt: DateTime(2026, 3, 28, 13, 30),
        );
        await db
            .into(db.transactionLines)
            .insert(
              TransactionLinesCompanion.insert(
                uuid: 'cashier-report-line',
                transactionId: paidOrderId,
                productId: productId,
                productName: 'Latte',
                unitPriceMinor: 2450,
                lineTotalMinor: 2450,
              ),
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

        await tester.pumpWidget(_reportsApp(container));
        await tester.pumpAndSettle();

        expect(find.byType(ZReportScreen), findsOneWidget);
        expect(find.byKey(const Key('cashier-z-report-open')), findsOneWidget);
        expect(find.text('Z Report'), findsOneWidget);
        expect(find.textContaining('Current Business Shift'), findsOneWidget);
        expect(find.text('Take Masked Z Report'), findsNothing);
        expect(find.text('Preview not yet taken'), findsNothing);
        expect(
          find.text('Final close requires counted cash and admin approval.'),
          findsNothing,
        );
        expect(find.textContaining('masked'), findsNothing);
        expect(find.textContaining('preview'), findsNothing);
        expect(find.textContaining('admin approval'), findsNothing);

        await tester.tap(find.byKey(const Key('cashier-z-report-open')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cashier-z-report-modal')), findsOneWidget);
        expect(find.text('Sales Summary'), findsOneWidget);
        expect(find.text('Payment Breakdown'), findsOneWidget);

        final shiftAfterOpen = await _readShiftRow(db, shiftId);
        expect(shiftAfterOpen.cashierPreviewedAt, isNull);
        expect(shiftAfterOpen.cashierPreviewedBy, isNull);
        expect(shiftAfterOpen.status, 'open');

        await tester.tap(find.byKey(const Key('cashier-z-report-close')));
        await tester.pumpAndSettle();

        final shiftAfterClose = await _readShiftRow(db, shiftId);
        expect(shiftAfterClose.cashierPreviewedAt, isNull);
        expect(shiftAfterClose.cashierPreviewedBy, isNull);
        expect(shiftAfterClose.status, 'open');
      },
    );

    testWidgets(
      'cashier preview lock is recorded only after pressing Confirm Z Report',
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
          name: 'Latte',
          priceMinor: 2450,
        );
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'cashier-confirm-paid',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 2450,
          paidAt: DateTime(2026, 3, 28, 13, 30),
        );
        await insertPayment(
          db,
          uuid: 'cashier-confirm-payment',
          transactionId: paidOrderId,
          method: 'card',
          amountMinor: 2450,
          paidAt: DateTime(2026, 3, 28, 13, 30),
        );
        await db
            .into(db.transactionLines)
            .insert(
              TransactionLinesCompanion.insert(
                uuid: 'cashier-confirm-line',
                transactionId: paidOrderId,
                productId: productId,
                productName: 'Latte',
                unitPriceMinor: 2450,
                lineTotalMinor: 2450,
              ),
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

        await tester.pumpWidget(_reportsApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('cashier-z-report-open')));
        await tester.pumpAndSettle();

        final shiftBeforeConfirm = await _readShiftRow(db, shiftId);
        expect(shiftBeforeConfirm.cashierPreviewedAt, isNull);

        await tester.tap(find.byKey(const Key('cashier-z-report-confirm')));
        await tester.pumpAndSettle();

        final shiftAfterConfirm = await _readShiftRow(db, shiftId);
        expect(shiftAfterConfirm.cashierPreviewedAt, isNotNull);
        expect(shiftAfterConfirm.cashierPreviewedBy, cashierId);
        expect(shiftAfterConfirm.status, 'open');
      },
    );

    testWidgets('admin still sees financial report actions and totals', (
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
        uuid: 'admin-report-paid',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 2450,
        paidAt: DateTime(2026, 3, 28, 14, 15),
      );
      await insertPayment(
        db,
        uuid: 'admin-report-payment',
        transactionId: paidOrderId,
        method: 'cash',
        amountMinor: 2450,
        paidAt: DateTime(2026, 3, 28, 14, 15),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);

      await tester.pumpWidget(_reportsApp(container));
      await tester.pumpAndSettle();

      expect(find.byType(ZReportScreen), findsOneWidget);
      expect(find.text('Print Z Report'), findsOneWidget);
      expect(find.text('Take Final Z Report and Close Shift'), findsOneWidget);
      expect(find.byKey(const Key('cashier-z-report-open')), findsNothing);
      expect(find.text('Gross Sales'), findsOneWidget);
      expect(find.text('Net Sales'), findsOneWidget);
      expect(find.text('Payment Breakdown'), findsOneWidget);
      expect(find.text('Gross Cash'), findsOneWidget);
      expect(find.text('Net Cash'), findsOneWidget);
      expect(find.text('Gross Card'), findsOneWidget);
      expect(find.text('Net Card'), findsOneWidget);
      expect(find.text('£24.50'), findsWidgets);
    });

    testWidgets(
      'cashier modal renders projected report details and excludes admin-only fields',
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
        final int drinksId = await insertCategory(db, name: 'İçecekler');
        final int dessertsId = await insertCategory(db, name: 'Tatlılar');
        final int latteId = await insertProduct(
          db,
          categoryId: drinksId,
          name: 'Latte',
          priceMinor: 1200,
        );
        final int cakeId = await insertProduct(
          db,
          categoryId: dessertsId,
          name: 'Cake',
          priceMinor: 1250,
        );
        final int cashOrderId = await insertTransaction(
          db,
          uuid: 'cashier-modal-cash-paid',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 1200,
          paidAt: DateTime(2026, 3, 28, 11, 0),
        );
        final int cardOrderId = await insertTransaction(
          db,
          uuid: 'cashier-modal-card-paid',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 1250,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await db
            .into(db.transactionLines)
            .insert(
              TransactionLinesCompanion.insert(
                uuid: 'cashier-modal-line-cash',
                transactionId: cashOrderId,
                productId: latteId,
                productName: 'Latte',
                unitPriceMinor: 1200,
                lineTotalMinor: 1200,
              ),
            );
        await db
            .into(db.transactionLines)
            .insert(
              TransactionLinesCompanion.insert(
                uuid: 'cashier-modal-line-card',
                transactionId: cardOrderId,
                productId: cakeId,
                productName: 'Cake',
                unitPriceMinor: 1250,
                lineTotalMinor: 1250,
              ),
            );
        await insertTransaction(
          db,
          uuid: 'cashier-modal-open',
          shiftId: shiftId,
          userId: cashierId,
          status: 'sent',
          totalAmountMinor: 800,
        );
        await insertPayment(
          db,
          uuid: 'cashier-modal-payment-cash',
          transactionId: cashOrderId,
          method: 'cash',
          amountMinor: 1200,
          paidAt: DateTime(2026, 3, 28, 11, 0),
        );
        await insertPayment(
          db,
          uuid: 'cashier-modal-payment-card',
          transactionId: cardOrderId,
          method: 'card',
          amountMinor: 1250,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await SettingsRepository(db).updateBusinessIdentitySettings(
          const BusinessIdentitySettings(
            businessName: 'Cafe Rialto',
            businessAddress: '123 Market Street',
          ),
          userId: cashierId,
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

        await tester.pumpWidget(_reportsApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('cashier-z-report-open')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('cashier-z-report-modal')), findsOneWidget);
        expect(find.text('Report Date'), findsOneWidget);
        expect(find.text('Report Time'), findsOneWidget);
        expect(find.text('Shift Number'), findsOneWidget);
        expect(find.text('Operator'), findsOneWidget);
        expect(find.text('Cafe Rialto'), findsOneWidget);
        expect(find.text('123 Market Street'), findsOneWidget);
        expect(find.text('$shiftId'), findsOneWidget);
        expect(find.text('Cashier'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is Text &&
                RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(widget.data ?? ''),
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is Text &&
                RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data ?? ''),
          ),
          findsOneWidget,
        );

        expect(find.text('Sales Summary'), findsOneWidget);
        expect(find.text('Gross Sales'), findsOneWidget);
        expect(find.text('Refund Total'), findsOneWidget);
        expect(find.text('Net Sales'), findsOneWidget);
        expect(find.text('Open Orders'), findsOneWidget);

        expect(find.text('Payment Breakdown'), findsOneWidget);
        expect(find.text('Gross Cash'), findsOneWidget);
        expect(find.text('Net Cash'), findsOneWidget);
        expect(find.text('Gross Card'), findsOneWidget);
        expect(find.text('Net Card'), findsOneWidget);
        expect(find.text('Total Orders'), findsOneWidget);
        expect(find.text('Total Amount'), findsOneWidget);

        expect(find.text('Category Breakdown'), findsOneWidget);
        expect(find.text('Drinks'), findsOneWidget);
        expect(find.text('Desserts'), findsOneWidget);
        expect(find.text('İçecekler'), findsNothing);
        expect(find.text('Tatlılar'), findsNothing);
        expect(find.text('£12.00'), findsWidgets);
        expect(find.text('£12.50'), findsWidgets);

        expect(find.text('Expected Cash'), findsNothing);
        expect(find.text('Counted Cash'), findsNothing);
        expect(find.text('Variance'), findsNothing);
        expect(find.textContaining('masked'), findsNothing);
        expect(find.textContaining('preview'), findsNothing);
        expect(find.textContaining('admin approval'), findsNothing);

        expect(
          find.widgetWithText(ElevatedButton, 'Confirm Z Report'),
          findsOneWidget,
        );
        expect(find.widgetWithText(OutlinedButton, 'Print'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('cashier-z-report-print')),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);
      },
    );

    testWidgets(
      'opening admin final close modal does not close shift and closing leaves state unchanged',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'admin-open-modal-paid',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 2450,
          paidAt: DateTime(2026, 3, 28, 14, 15),
        );
        await insertPayment(
          db,
          uuid: 'admin-open-modal-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 2450,
          paidAt: DateTime(2026, 3, 28, 14, 15),
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

        await tester.pumpWidget(_reportsApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.finalZReportAction));
        await tester.pumpAndSettle();

        final shiftAfterOpen = await _readShiftRow(db, shiftId);
        expect(shiftAfterOpen.status, 'open');
        expect(find.byType(TextField), findsOneWidget);

        await tester.tap(find.widgetWithText(TextButton, AppStrings.close));
        await tester.pumpAndSettle();

        final shiftAfterClose = await _readShiftRow(db, shiftId);
        expect(shiftAfterClose.status, 'open');
        expect(shiftAfterClose.closedAt, isNull);
        expect(shiftAfterClose.closedBy, isNull);
      },
    );

    testWidgets('shift closes only after pressing Confirm Final Close', (
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
        uuid: 'admin-confirm-close-paid',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 2450,
        paidAt: DateTime(2026, 3, 28, 14, 15),
      );
      await insertPayment(
        db,
        uuid: 'admin-confirm-close-payment',
        transactionId: paidOrderId,
        method: 'cash',
        amountMinor: 2450,
        paidAt: DateTime(2026, 3, 28, 14, 15),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);

      await tester.pumpWidget(_reportsApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.finalZReportAction));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '2450');

      final shiftBeforeConfirm = await _readShiftRow(db, shiftId);
      expect(shiftBeforeConfirm.status, 'open');

      await tester.tap(
        find.widgetWithText(ElevatedButton, AppStrings.confirmFinalCloseAction),
      );
      await tester.pumpAndSettle();

      final shiftAfterConfirm = await _readShiftRow(db, shiftId);
      expect(shiftAfterConfirm.status, 'closed');
      expect(shiftAfterConfirm.closedAt, isNotNull);
      expect(shiftAfterConfirm.closedBy, adminId);
    });

    testWidgets(
      'admin final close from report screen shows recovery dialog instead of generic failure',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'admin-report-stale-recovery-paid',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 2450,
          paidAt: DateTime(2026, 3, 28, 14, 15),
        );
        await insertPayment(
          db,
          uuid: 'admin-report-stale-recovery-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 2450,
          paidAt: DateTime(2026, 3, 28, 14, 15),
        );
        await insertShiftReconciliation(
          db,
          uuid: 'admin-report-existing-final-close',
          shiftId: shiftId,
          expectedCashMinor: 2450,
          countedCashMinor: 2450,
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

        await tester.pumpWidget(_reportsApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.finalZReportAction));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '2450');
        await tester.tap(
          find.widgetWithText(
            ElevatedButton,
            AppStrings.confirmFinalCloseAction,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(AppStrings.previousFinalCloseAttemptDetected),
          findsOneWidget,
        );
        expect(find.text(AppStrings.resumeFinalCloseAction), findsOneWidget);
        expect(find.text(AppStrings.discardAndReenterAction), findsOneWidget);
        expect(find.text(AppStrings.operationFailed), findsNothing);
      },
    );
  });
}

Widget _reportsApp(ProviderContainer container) {
  final GoRouter router = GoRouter(
    initialLocation: '/reports',
    routes: <RouteBase>[
      GoRoute(path: '/reports', builder: (_, __) => const ZReportScreen()),
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
        path: '/shifts',
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

Future<Shift> _readShiftRow(AppDatabase db, int shiftId) {
  return (db.select(
    db.shifts,
  )..where((tbl) => tbl.id.equals(shiftId))).getSingle();
}
