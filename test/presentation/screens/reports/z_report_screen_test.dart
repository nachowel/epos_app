import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/cashier_projected_report.dart';
import 'package:epos_app/domain/models/shift_report.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/models/business_identity_settings.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/reports_provider.dart';
import 'package:epos_app/presentation/screens/reports/z_report_screen.dart';
import 'package:epos_app/presentation/screens/reports/widgets/cashier_z_report_dialog.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:drift/drift.dart' show Value;
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
        expect(find.text('Z REPORT'), findsOneWidget);
        expect(find.text('Halfway Cafe'), findsOneWidget);
        expect(find.text('176 Halfway St, Sidcup DA15 8DJ'), findsOneWidget);
        expect(find.text('02033435303'), findsOneWidget);
        expect(find.text('Date'), findsOneWidget);
        expect(find.text('Time'), findsOneWidget);
        expect(find.text('Shift #'), findsOneWidget);
        expect(find.text('Total Orders'), findsOneWidget);
        expect(find.text('Refunds'), findsOneWidget);
        expect(find.text('Open Orders'), findsOneWidget);
        expect(find.text('TOTAL SALES'), findsOneWidget);
        expect(find.text('Payment Breakdown'), findsNothing);
        expect(find.text('Gross Sales'), findsNothing);
        expect(find.text('Net Sales'), findsNothing);
        expect(find.byKey(const Key('cashier-z-report-confirm')), findsNothing);

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
      'cashier Z Report modal is view-only and does not record preview',
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

        expect(find.byKey(const Key('cashier-z-report-confirm')), findsNothing);
        expect(find.widgetWithText(TextButton, 'Close'), findsOneWidget);

        await tester.tap(find.byKey(const Key('cashier-z-report-close')));
        await tester.pumpAndSettle();

        final shiftAfterConfirm = await _readShiftRow(db, shiftId);
        expect(shiftAfterConfirm.cashierPreviewedAt, isNull);
        expect(shiftAfterConfirm.cashierPreviewedBy, isNull);
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
      final int categoryId = await insertCategory(db, name: 'Misc');
      final int customSaleProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Custom Sale',
        priceMinor: 2450,
        isCustom: true,
      );
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
      await db
          .into(db.transactionLines)
          .insert(
            TransactionLinesCompanion.insert(
              uuid: 'admin-report-custom-line',
              transactionId: paidOrderId,
              productId: customSaleProductId,
              productName: 'Custom Sale',
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
      expect(find.text('Custom Sales'), findsOneWidget);
      expect(find.text('Custom Sale Revenue'), findsOneWidget);
      expect(find.text('Custom Sale Count'), findsOneWidget);
      expect(find.text('Custom Sale Average Value'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
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
        expect(find.text('Z REPORT'), findsOneWidget);
        expect(find.text('Halfway Cafe'), findsOneWidget);
        expect(find.text('176 Halfway St, Sidcup DA15 8DJ'), findsOneWidget);
        expect(find.text('02033435303'), findsOneWidget);
        expect(find.text('Date'), findsOneWidget);
        expect(find.text('Time'), findsOneWidget);
        expect(find.text('Shift #'), findsOneWidget);
        expect(find.text('Operator'), findsNothing);
        expect(find.text('Cafe Rialto'), findsNothing);
        expect(find.text('123 Market Street'), findsNothing);
        expect(find.text('$shiftId'), findsWidgets);
        expect(find.text('Cashier'), findsNothing);
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

        expect(find.text('SUMMARY'), findsOneWidget);
        expect(find.text('Total Orders'), findsOneWidget);
        expect(find.text('Refunds'), findsOneWidget);
        expect(find.text('Open Orders'), findsOneWidget);
        expect(find.text('1'), findsWidgets);
        expect(find.text('TOTAL SALES'), findsOneWidget);
        expect(find.text('£25'), findsOneWidget);

        expect(find.text('Gross Sales'), findsNothing);
        expect(find.text('Net Sales'), findsNothing);
        expect(find.text('Refund Total'), findsNothing);
        expect(find.text('Payment Breakdown'), findsNothing);
        expect(find.text('Gross Cash'), findsNothing);
        expect(find.text('Net Cash'), findsNothing);
        expect(find.text('Gross Card'), findsNothing);
        expect(find.text('Net Card'), findsNothing);
        expect(find.text('Total Amount'), findsNothing);
        expect(find.text('Category Breakdown'), findsNothing);
        expect(find.text('Drinks'), findsNothing);
        expect(find.text('Desserts'), findsNothing);
        expect(find.text('İçecekler'), findsNothing);
        expect(find.text('Tatlılar'), findsNothing);
        expect(find.text('£12.00'), findsNothing);
        expect(find.text('£12.50'), findsNothing);
        expect(find.text('Cancelled Orders'), findsNothing);
        expect(find.text('Custom Sales'), findsNothing);
        expect(find.text('Average Values'), findsNothing);

        expect(find.text('Expected Cash'), findsNothing);
        expect(find.text('Counted Cash'), findsNothing);
        expect(find.text('Variance'), findsNothing);
        expect(find.textContaining('masked'), findsNothing);
        expect(find.textContaining('preview'), findsNothing);
        expect(find.textContaining('admin approval'), findsNothing);

        expect(
          find.widgetWithText(ElevatedButton, 'Confirm Z Report'),
          findsNothing,
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

    testWidgets('cashier modal rounds displayed total sales to whole pounds', (
      WidgetTester tester,
    ) async {
      Future<void> pumpReport(int totalMinor) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CashierZReportDialog(
                report: CashierProjectedReport.empty().copyWith(
                  hasOpenShift: true,
                  shiftId: 9,
                  generatedAt: DateTime(2026, 3, 28, 13, 30),
                  visibleTotalMinor: totalMinor,
                  totalOrdersCount: 1,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpReport(406415);
      expect(find.text('£4,064'), findsOneWidget);

      await pumpReport(325955);
      expect(find.text('£3,260'), findsOneWidget);

      await pumpReport(8046);
      expect(find.text('£80'), findsOneWidget);

      await pumpReport(8060);
      expect(find.text('£81'), findsOneWidget);
    });

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
      await _enterCountedCashViaKeypad(tester, '24.50');

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
        await _enterCountedCashViaKeypad(tester, '24.50');
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

    testWidgets('closed shift report remains visible when Z report print fails', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      for (int index = 0; index < 8; index += 1) {
        await insertShift(
          db,
          openedBy: adminId,
          status: 'closed',
          closedBy: adminId,
          closedAt: DateTime(2026, 3, 27, 17, index),
        );
      }
      final int shiftId = await insertShift(
        db,
        openedBy: adminId,
        status: 'closed',
        closedBy: adminId,
        closedAt: DateTime(2026, 3, 28, 18),
      );
      expect(shiftId, 9);
      await (db.update(
        db.shifts,
      )..where((tbl) => tbl.id.equals(shiftId))).write(
        ShiftsCompanion(openedAt: Value<DateTime>(DateTime(2026, 7, 4))),
      );

      final int categoryId = await insertCategory(db, name: 'Drinks');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Latte',
        priceMinor: 2450,
      );
      final int paidOrderId = await insertTransaction(
        db,
        uuid: 'closed-report-print-failure-paid',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 2450,
        paidAt: DateTime(2026, 3, 28, 14, 15),
      );
      await db
          .into(db.transactionLines)
          .insert(
            TransactionLinesCompanion.insert(
              uuid: 'closed-report-print-failure-line',
              transactionId: paidOrderId,
              productId: productId,
              productName: 'Latte',
              unitPriceMinor: 2450,
              lineTotalMinor: 2450,
            ),
          );
      await insertPayment(
        db,
        uuid: 'closed-report-print-failure-payment',
        transactionId: paidOrderId,
        method: 'cash',
        amountMinor: 2450,
        paidAt: DateTime(2026, 3, 28, 14, 15),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          printerServiceProvider.overrideWithValue(
            _ThrowingReportPrinterService(db),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);

      await tester.pumpWidget(_reportsApp(container));
      await tester.pumpAndSettle();

      expect(container.read(reportsNotifierProvider).currentShiftId, 9);
      expect(find.textContaining('Shift #9'), findsWidgets);
      expect(find.text('Gross Sales'), findsOneWidget);
      expect(find.text('Net Sales'), findsOneWidget);
      expect(find.text('Payment Breakdown'), findsOneWidget);
      expect(find.text('£24.50'), findsWidgets);

      await tester.tap(find.text(AppStrings.printZReportAction));
      await tester.pumpAndSettle();

      const String expectedMessage =
          'Yazıcı bağlantısı kurulamadı. Rapor ekranda kalır; yazıcı bağlandıktan sonra tekrar yazdırabilirsiniz.';
      expect(find.text(expectedMessage), findsOneWidget);
      expect(find.textContaining('Shift #9'), findsWidgets);
      expect(find.text('Gross Sales'), findsOneWidget);
      expect(find.text('Net Sales'), findsOneWidget);
      expect(find.text('Payment Breakdown'), findsOneWidget);
      expect(find.text('£24.50'), findsWidgets);

      final reportsState = container.read(reportsNotifierProvider);
      expect(reportsState.currentShiftId, 9);
      expect(reportsState.adminReport?.shiftId, 9);
    });
  });
}

Future<void> _enterCountedCashViaKeypad(
  WidgetTester tester,
  String editableMajorValue,
) async {
  final TextField field = tester.widget<TextField>(find.byType(TextField));
  expect(field.readOnly, isTrue);

  await tester.tap(find.byType(TextField));
  await tester.pumpAndSettle();
  for (final String character in editableMajorValue.split('')) {
    final String key = switch (character) {
      '.' => 'app-numeric-keypad-decimal',
      _ => 'app-numeric-keypad-digit-$character',
    };
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pump();
  }
  await tester.tap(
    find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
  );
  await tester.pumpAndSettle();
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

class _ThrowingReportPrinterService extends PrinterService {
  _ThrowingReportPrinterService(AppDatabase db)
    : super(
        TransactionRepository(db),
        paymentRepository: PaymentRepository(db),
        settingsRepository: SettingsRepository(db),
      );

  @override
  Future<void> printZReport(ShiftReport report) async {
    throw PrinterException('Printer unavailable.');
  }

  @override
  Future<void> printCashierZReport(CashierProjectedReport report) async {
    throw PrinterException('Printer unavailable.');
  }
}
