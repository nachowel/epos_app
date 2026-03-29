import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/cashier_projected_report.dart';
import 'package:epos_app/domain/models/shift_report.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/reports_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

void main() {
  group('ReportsNotifier', () {
    test(
      'cashier loadReportForOpenShift populates only cashier report state',
      () async {
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
        await container
            .read(reportsNotifierProvider.notifier)
            .loadReportForOpenShift();

        final ReportsState state = container.read(reportsNotifierProvider);
        expect(state.cashierReport, isNotNull);
        expect(state.adminReport, isNull);
        expect(state.currentShiftId, shiftId);
        expect(state.cashierReport!.shiftId, shiftId);
        expect(state.cashierReport!.visibleTotalMinor, 0);
      },
    );

    test(
      'admin loadReportForShift populates only admin report state',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'provider-admin-paid',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 990,
          paidAt: DateTime(2026, 3, 28, 9, 0),
        );
        await insertPayment(
          db,
          uuid: 'provider-admin-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 990,
          paidAt: DateTime(2026, 3, 28, 9, 0),
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
        await container
            .read(reportsNotifierProvider.notifier)
            .loadReportForShift(shiftId);

        final ReportsState state = container.read(reportsNotifierProvider);
        expect(state.adminReport, isNotNull);
        expect(state.cashierReport, isNull);
        expect(state.currentShiftId, shiftId);
        expect(state.adminReport!.shiftId, shiftId);
        expect(state.adminReport!.paidTotalMinor, 990);
      },
    );

    test(
      'cashier cannot resolve admin visible shift report provider',
      () async {
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

        await expectLater(
          container.read(adminVisibleShiftReportProvider(shiftId).future),
          throwsA(isA<UnauthorisedException>()),
        );
      },
    );

    test('cashier print uses projected report path only', () async {
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
      final _TrackingReportPrinterService printerService =
          _TrackingReportPrinterService(db);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          printerServiceProvider.overrideWithValue(printerService),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container
          .read(reportsNotifierProvider.notifier)
          .loadReportForOpenShift();

      final bool success = await container
          .read(reportsNotifierProvider.notifier)
          .printCashierReport();

      expect(success, isTrue);
      expect(printerService.cashierPrintCalls, 1);
      expect(printerService.adminPrintCalls, 0);
      expect(printerService.lastCashierReport, isA<CashierProjectedReport>());
      expect(printerService.lastCashierReport!.shiftId, shiftId);
    });

    test('admin print still uses real report path only', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int paidOrderId = await insertTransaction(
        db,
        uuid: 'provider-admin-print-paid',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 990,
        paidAt: DateTime(2026, 3, 28, 9, 0),
      );
      await insertPayment(
        db,
        uuid: 'provider-admin-print-payment',
        transactionId: paidOrderId,
        method: 'cash',
        amountMinor: 990,
        paidAt: DateTime(2026, 3, 28, 9, 0),
      );
      final _TrackingReportPrinterService printerService =
          _TrackingReportPrinterService(db);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          printerServiceProvider.overrideWithValue(printerService),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authNotifierProvider.notifier).loadUserById(adminId);
      await container
          .read(reportsNotifierProvider.notifier)
          .loadReportForShift(shiftId);

      final bool success = await container
          .read(reportsNotifierProvider.notifier)
          .printCurrentReport();

      expect(success, isTrue);
      expect(printerService.adminPrintCalls, 1);
      expect(printerService.cashierPrintCalls, 0);
      expect(printerService.lastAdminReport, isA<ShiftReport>());
      expect(printerService.lastAdminReport!.shiftId, shiftId);
    });

    test(
      'admin final close surfaces stale recovery details instead of generic failure',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'reports-provider-stale-final-close-paid',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 1200,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertPayment(
          db,
          uuid: 'reports-provider-stale-final-close-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 1200,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertShiftReconciliation(
          db,
          uuid: 'reports-provider-existing-final-close',
          shiftId: shiftId,
          expectedCashMinor: 1200,
          countedCashMinor: 1250,
          varianceMinor: 50,
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
        await container
            .read(reportsNotifierProvider.notifier)
            .loadReportForShift(shiftId);

        final bool success = await container
            .read(reportsNotifierProvider.notifier)
            .runAdminFinalClose(countedCashMinor: 1250);
        final ReportsState state = container.read(reportsNotifierProvider);

        expect(success, isFalse);
        expect(state.errorMessage, isNull);
        expect(state.staleFinalCloseRecovery, isNotNull);
        expect(state.staleFinalCloseRecovery!.shiftId, shiftId);
        expect(state.staleFinalCloseRecovery!.expectedCashMinor, 1200);
        expect(state.staleFinalCloseRecovery!.countedCashMinor, 1250);
        expect(state.staleFinalCloseRecovery!.varianceMinor, 50);
        expect(state.staleFinalCloseRecovery!.countedByName, 'Admin');
      },
    );
  });
}

class _TrackingReportPrinterService extends PrinterService {
  _TrackingReportPrinterService(AppDatabase db)
    : super(
        TransactionRepository(db),
        paymentRepository: PaymentRepository(db),
        settingsRepository: SettingsRepository(db),
      );

  int adminPrintCalls = 0;
  int cashierPrintCalls = 0;
  ShiftReport? lastAdminReport;
  CashierProjectedReport? lastCashierReport;

  @override
  Future<void> printZReport(ShiftReport report) async {
    adminPrintCalls += 1;
    lastAdminReport = report;
  }

  @override
  Future<void> printCashierZReport(CashierProjectedReport report) async {
    cashierPrintCalls += 1;
    lastCashierReport = report;
  }
}
