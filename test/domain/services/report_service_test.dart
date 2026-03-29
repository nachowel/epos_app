import 'package:drift/drift.dart' show Variable;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart'
    hide User, ShiftReconciliation;
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_reconciliation_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/shift_close_readiness.dart';
import 'package:epos_app/domain/models/shift_reconciliation.dart';
import 'package:epos_app/domain/models/stale_final_close_recovery_details.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/models/z_report_action_result.dart';
import 'package:epos_app/domain/services/audit_log_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('ReportService', () {
    test(
      'cashier can take masked Z report without closing the real shift',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: cashierId);
        final int paidTransactionId = await insertTransaction(
          db,
          uuid: 'paid-report-tx',
          shiftId: shiftId,
          userId: cashierId,
          status: 'draft',
          totalAmountMinor: 1000,
        );
        final int openTransactionId = await insertTransaction(
          db,
          uuid: 'open-report-tx',
          shiftId: shiftId,
          userId: cashierId,
          status: 'sent',
          totalAmountMinor: 400,
        );

        final PaymentRepository paymentRepository = PaymentRepository(db);
        final int categoryId = await insertCategory(db, name: 'Report Items');
        final int paidProductId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Meal',
          priceMinor: 1000,
        );
        await TransactionRepository(db).addLine(
          transactionId: paidTransactionId,
          productId: paidProductId,
          quantity: 1,
        );

        final ShiftRepository shiftRepository = ShiftRepository(db);
        final TransactionRepository transactionRepository =
            TransactionRepository(db);
        final OrderService orderService = OrderService(
          shiftSessionService: ShiftSessionService(shiftRepository),
          transactionRepository: transactionRepository,
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: paymentRepository,
        );
        await orderService.sendOrder(
          transactionId: paidTransactionId,
          currentUser: User(
            id: cashierId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        await orderService.markOrderPaid(
          transactionId: paidTransactionId,
          method: PaymentMethod.cash,
          currentUser: User(
            id: cashierId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        final ShiftSessionService shiftSessionService = ShiftSessionService(
          shiftRepository,
        );
        final ReportService reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: shiftSessionService,
          transactionRepository: transactionRepository,
          paymentRepository: paymentRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
        );

        await SettingsRepository(
          db,
        ).updateVisibilityRatio(0.25, userId: adminId);

        final cashier = User(
          id: cashierId,
          name: 'Cashier',
          pin: null,
          password: null,
          role: UserRole.cashier,
          isActive: true,
          createdAt: DateTime.now(),
        );
        final admin = User(
          id: adminId,
          name: 'Admin',
          pin: null,
          password: null,
          role: UserRole.admin,
          isActive: true,
          createdAt: DateTime.now(),
        );

        final maskedPreview = await reportService.takeCashierEndOfDayPreview(
          user: cashier,
        );
        final maskedPrintedReport = await reportService.getVisibleShiftReport(
          shiftId: shiftId,
          user: cashier,
        );
        final realPrintedReport = await reportService.getVisibleShiftReport(
          shiftId: shiftId,
          user: admin,
        );
        final openShiftAfterPreview = await shiftRepository.getOpenShift();
        final openTransaction = await transactionRepository.getById(
          openTransactionId,
        );

        expect(maskedPreview.finalCloseCompleted, isFalse);
        expect(maskedPreview.report.paidTotalMinor, 250);
        expect(maskedPreview.report.openTotalMinor, 100);
        expect(maskedPrintedReport, maskedPreview.report);
        expect(realPrintedReport.paidTotalMinor, 1000);
        expect(realPrintedReport.openTotalMinor, 400);
        expect(openShiftAfterPreview, isNotNull);
        expect(openShiftAfterPreview!.id, shiftId);
        expect(openShiftAfterPreview.hasCashierPreview, isTrue);

        await expectLater(
          shiftSessionService.ensureOrderCreationAllowed(cashier),
          throwsA(isA<CashierPreviewLockedException>()),
        );
        await expectLater(
          shiftSessionService.ensurePaymentAllowed(
            user: cashier,
            transaction: openTransaction!,
          ),
          throwsA(isA<CashierPreviewLockedException>()),
        );

        final adminSnapshot = await shiftSessionService.getSnapshotForUser(
          admin,
        );
        expect(adminSnapshot.backendOpenShift, isNotNull);
        expect(adminSnapshot.visibleShift, isNotNull);
        expect(adminSnapshot.salesLocked, isFalse);
      },
    );

    test(
      'admin final Z report closes the real shift with real totals',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidTransactionId = await insertTransaction(
          db,
          uuid: 'paid-final-close',
          shiftId: shiftId,
          userId: adminId,
          status: 'draft',
          totalAmountMinor: 1600,
        );

        final PaymentRepository paymentRepository = PaymentRepository(db);
        final int categoryId = await insertCategory(db, name: 'Final Close');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Roast',
          priceMinor: 1600,
        );
        await TransactionRepository(db).addLine(
          transactionId: paidTransactionId,
          productId: productId,
          quantity: 1,
        );
        final OrderService orderService = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: paymentRepository,
        );
        await orderService.sendOrder(
          transactionId: paidTransactionId,
          currentUser: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        await orderService.markOrderPaid(
          transactionId: paidTransactionId,
          method: PaymentMethod.card,
          currentUser: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );

        final ShiftRepository shiftRepository = ShiftRepository(db);
        final ReportService reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: ShiftSessionService(shiftRepository),
          transactionRepository: TransactionRepository(db),
          paymentRepository: paymentRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
        );

        final result = await reportService.runAdminFinalCloseWithCountedCash(
          user: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          countedCashMinor: 0,
        );

        final openShiftAfterClose = await shiftRepository.getOpenShift();

        expect(result.finalCloseCompleted, isTrue);
        expect(result.report.paidTotalMinor, 1600);
        expect(openShiftAfterClose, isNull);
      },
    );

    test('final close is rejected while open orders still exist', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      await insertTransaction(
        db,
        uuid: 'still-open-before-close',
        shiftId: shiftId,
        userId: adminId,
        status: 'sent',
        totalAmountMinor: 500,
      );

      final ShiftRepository shiftRepository = ShiftRepository(db);
      final ReportService reportService = ReportService(
        shiftRepository: shiftRepository,
        shiftSessionService: ShiftSessionService(shiftRepository),
        transactionRepository: TransactionRepository(db),
        paymentRepository: PaymentRepository(db),
        settingsRepository: SettingsRepository(db),
        reportVisibilityService: const ReportVisibilityService(),
      );

      await expectLater(
        reportService.runAdminFinalCloseWithCountedCash(
          user: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          countedCashMinor: 0,
        ),
        throwsA(
          isA<ShiftCloseBlockedException>()
              .having(
                (ShiftCloseBlockedException error) =>
                    error.readiness.blockingReason,
                'blockingReason',
                ShiftCloseBlockReason.sentOrdersPending,
              )
              .having(
                (ShiftCloseBlockedException error) => error.suggestedAction,
                'suggestedAction',
                ShiftCloseSuggestedAction.completeOrCancelActiveOrders,
              ),
        ),
      );
    });

    test(
      'blocked final close does not persist reconciliation before readiness passes',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        await insertTransaction(
          db,
          uuid: 'blocked-close-no-reconciliation',
          shiftId: shiftId,
          userId: adminId,
          status: 'sent',
          totalAmountMinor: 500,
        );

        final ShiftRepository shiftRepository = ShiftRepository(db);
        final ShiftReconciliationRepository shiftReconciliationRepository =
            ShiftReconciliationRepository(db);
        final ReportService reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: ShiftSessionService(shiftRepository),
          transactionRepository: TransactionRepository(db),
          paymentRepository: PaymentRepository(db),
          shiftReconciliationRepository: shiftReconciliationRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
        );

        await expectLater(
          reportService.runAdminFinalCloseWithCountedCash(
            user: User(
              id: adminId,
              name: 'Admin',
              pin: null,
              password: null,
              role: UserRole.admin,
              isActive: true,
              createdAt: DateTime.now(),
            ),
            countedCashMinor: 0,
          ),
          throwsA(
            isA<ShiftCloseBlockedException>().having(
              (ShiftCloseBlockedException error) =>
                  error.readiness.blockingReason,
              'blockingReason',
              ShiftCloseBlockReason.sentOrdersPending,
            ),
          ),
        );

        final ShiftReconciliation? reconciliation =
            await shiftReconciliationRepository.getByShiftAndKind(
              shiftId: shiftId,
              kind: ShiftReconciliationKind.finalClose,
            );

        expect(reconciliation, isNull);
      },
    );

    test(
      'open shift with existing final close reconciliation fails cleanly without a second insert',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'stale-final-close-paid-order',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 1200,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertPayment(
          db,
          uuid: 'stale-final-close-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 1200,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertShiftReconciliation(
          db,
          uuid: 'existing-final-close-reconciliation',
          shiftId: shiftId,
          expectedCashMinor: 1200,
          countedCashMinor: 1200,
          varianceMinor: 0,
          countedBy: adminId,
          countedAt: DateTime(2026, 3, 28, 18, 0),
        );

        final ShiftRepository shiftRepository = ShiftRepository(db);
        final ShiftReconciliationRepository shiftReconciliationRepository =
            ShiftReconciliationRepository(db);
        final ReportService reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: ShiftSessionService(shiftRepository),
          transactionRepository: TransactionRepository(db),
          paymentRepository: PaymentRepository(db),
          shiftReconciliationRepository: shiftReconciliationRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
        );

        await expectLater(
          reportService.runAdminFinalCloseWithCountedCash(
            user: User(
              id: adminId,
              name: 'Admin',
              pin: null,
              password: null,
              role: UserRole.admin,
              isActive: true,
              createdAt: DateTime.now(),
            ),
            countedCashMinor: 1200,
          ),
          throwsA(
            isA<StaleFinalCloseReconciliationException>()
                .having(
                  (StaleFinalCloseReconciliationException error) =>
                      error.shiftId,
                  'shiftId',
                  shiftId,
                )
                .having(
                  (StaleFinalCloseReconciliationException error) =>
                      error.details.countedByName,
                  'countedByName',
                  'Admin',
                )
                .having(
                  (StaleFinalCloseReconciliationException error) =>
                      error.details.expectedCashMinor,
                  'expectedCashMinor',
                  1200,
                ),
          ),
        );

        final ShiftReconciliation? reconciliation =
            await shiftReconciliationRepository.getByShiftAndKind(
              shiftId: shiftId,
              kind: ShiftReconciliationKind.finalClose,
            );
        final int reconciliationCount = await _countFinalCloseReconciliations(
          db,
          shiftId,
        );

        expect(reconciliation, isNotNull);
        expect(reconciliation!.uuid, 'existing-final-close-reconciliation');
        expect(reconciliationCount, 1);
        expect(await shiftRepository.getOpenShift(), isNotNull);
      },
    );

    test(
      'resume stale final close completes close without a second insert and writes audit logs',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'resume-stale-final-close-paid-order',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 1500,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertPayment(
          db,
          uuid: 'resume-stale-final-close-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 1500,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertShiftReconciliation(
          db,
          uuid: 'resume-stale-final-close-reconciliation',
          shiftId: shiftId,
          expectedCashMinor: 1500,
          countedCashMinor: 1450,
          varianceMinor: -50,
          countedBy: adminId,
          countedAt: DateTime(2026, 3, 28, 18, 0),
        );

        final ShiftRepository shiftRepository = ShiftRepository(db);
        final ShiftReconciliationRepository shiftReconciliationRepository =
            ShiftReconciliationRepository(db);
        final AuditLogRepository auditLogRepository = AuditLogRepository(db);
        final AuditLogService auditLogService = PersistedAuditLogService(
          auditLogRepository: auditLogRepository,
          logger: const NoopAppLogger(),
        );
        final ReportService reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: ShiftSessionService(
            shiftRepository,
            auditLogService: auditLogService,
          ),
          transactionRepository: TransactionRepository(db),
          paymentRepository: PaymentRepository(db),
          shiftReconciliationRepository: shiftReconciliationRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
          auditLogService: auditLogService,
        );

        final StaleFinalCloseRecoveryDetails recovery =
            (await shiftReconciliationRepository
                .getStaleFinalCloseRecoveryDetails(shiftId: shiftId))!;

        final ZReportActionResult result = await reportService
            .resumeStaleAdminFinalClose(
              user: User(
                id: adminId,
                name: 'Admin',
                pin: null,
                password: null,
                role: UserRole.admin,
                isActive: true,
                createdAt: DateTime.now(),
              ),
              recovery: recovery,
            );

        final int reconciliationCount = await _countFinalCloseReconciliations(
          db,
          shiftId,
        );
        final logs = await auditLogRepository.listAuditLogsByEntity(
          entityType: 'shift',
          entityId: '$shiftId',
        );

        expect(result.finalCloseCompleted, isTrue);
        expect(await shiftRepository.getOpenShift(), isNull);
        expect(reconciliationCount, 1);
        expect(
          logs.map((log) => log.action),
          containsAll(<String>[
            'stale_final_close_resumed',
            'shift_closed',
            'day_end_finalized',
          ]),
        );
      },
    );

    test(
      'discard stale final close removes stale reconciliation and writes audit log',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int paidOrderId = await insertTransaction(
          db,
          uuid: 'discard-stale-final-close-paid-order',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 1000,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertPayment(
          db,
          uuid: 'discard-stale-final-close-payment',
          transactionId: paidOrderId,
          method: 'cash',
          amountMinor: 1000,
          paidAt: DateTime(2026, 3, 28, 12, 0),
        );
        await insertShiftReconciliation(
          db,
          uuid: 'discard-stale-final-close-reconciliation',
          shiftId: shiftId,
          expectedCashMinor: 1000,
          countedCashMinor: 990,
          varianceMinor: -10,
          countedBy: adminId,
          countedAt: DateTime(2026, 3, 28, 18, 0),
        );

        final ShiftRepository shiftRepository = ShiftRepository(db);
        final ShiftReconciliationRepository shiftReconciliationRepository =
            ShiftReconciliationRepository(db);
        final AuditLogRepository auditLogRepository = AuditLogRepository(db);
        final AuditLogService auditLogService = PersistedAuditLogService(
          auditLogRepository: auditLogRepository,
          logger: const NoopAppLogger(),
        );
        final ReportService reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: ShiftSessionService(
            shiftRepository,
            auditLogService: auditLogService,
          ),
          transactionRepository: TransactionRepository(db),
          paymentRepository: PaymentRepository(db),
          shiftReconciliationRepository: shiftReconciliationRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
          auditLogService: auditLogService,
        );

        final StaleFinalCloseRecoveryDetails recovery =
            (await shiftReconciliationRepository
                .getStaleFinalCloseRecoveryDetails(shiftId: shiftId))!;

        await reportService.discardStaleAdminFinalClose(
          user: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          recovery: recovery,
        );

        final ShiftReconciliation? reconciliation =
            await shiftReconciliationRepository.getByShiftAndKind(
              shiftId: shiftId,
              kind: ShiftReconciliationKind.finalClose,
            );
        final logs = await auditLogRepository.listAuditLogsByEntity(
          entityType: 'shift',
          entityId: '$shiftId',
        );

        expect(await shiftRepository.getOpenShift(), isNotNull);
        expect(reconciliation, isNull);
        expect(
          logs.map((log) => log.action),
          contains('stale_final_close_discarded'),
        );
      },
    );

    test('closed shift rejects stale final close recovery', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(
        db,
        openedBy: adminId,
        status: 'closed',
        closedBy: adminId,
        closedAt: DateTime(2026, 3, 28, 19, 0),
      );
      await insertShiftReconciliation(
        db,
        uuid: 'closed-shift-stale-final-close-reconciliation',
        shiftId: shiftId,
        expectedCashMinor: 0,
        countedCashMinor: 0,
        varianceMinor: 0,
        countedBy: adminId,
        countedAt: DateTime(2026, 3, 28, 18, 0),
      );

      final ShiftRepository shiftRepository = ShiftRepository(db);
      final ShiftReconciliationRepository shiftReconciliationRepository =
          ShiftReconciliationRepository(db);
      final ReportService reportService = ReportService(
        shiftRepository: shiftRepository,
        shiftSessionService: ShiftSessionService(shiftRepository),
        transactionRepository: TransactionRepository(db),
        paymentRepository: PaymentRepository(db),
        shiftReconciliationRepository: shiftReconciliationRepository,
        settingsRepository: SettingsRepository(db),
        reportVisibilityService: const ReportVisibilityService(),
      );

      final StaleFinalCloseRecoveryDetails recovery =
          (await shiftReconciliationRepository
              .getStaleFinalCloseRecoveryDetails(shiftId: shiftId))!;

      await expectLater(
        reportService.resumeStaleAdminFinalClose(
          user: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          recovery: recovery,
        ),
        throwsA(isA<ShiftClosedException>()),
      );
    });

    test(
      'final close leaves sales and payments blocked until next login opens shift',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int transactionId = await insertTransaction(
          db,
          uuid: 'final-close-blocks',
          shiftId: shiftId,
          userId: adminId,
          status: 'draft',
          totalAmountMinor: 900,
        );

        final paymentRepository = PaymentRepository(db);
        final int categoryId = await insertCategory(db, name: 'Close Lock');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Coffee Pot',
          priceMinor: 900,
        );
        await TransactionRepository(db).addLine(
          transactionId: transactionId,
          productId: productId,
          quantity: 1,
        );
        final OrderService orderService = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: paymentRepository,
        );
        await orderService.sendOrder(
          transactionId: transactionId,
          currentUser: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );
        await orderService.markOrderPaid(
          transactionId: transactionId,
          method: PaymentMethod.cash,
          currentUser: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        );

        final shiftRepository = ShiftRepository(db);
        final shiftSessionService = ShiftSessionService(shiftRepository);
        final reportService = ReportService(
          shiftRepository: shiftRepository,
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          paymentRepository: paymentRepository,
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
        );

        await reportService.runAdminFinalCloseWithCountedCash(
          user: User(
            id: adminId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          countedCashMinor: 900,
        );

        final closedTransaction = await TransactionRepository(
          db,
        ).getById(transactionId);

        await expectLater(
          shiftSessionService.ensureOrderCreationAllowed(
            User(
              id: adminId,
              name: 'Admin',
              pin: null,
              password: null,
              role: UserRole.admin,
              isActive: true,
              createdAt: DateTime.now(),
            ),
          ),
          throwsA(isA<ShiftNotActiveException>()),
        );
        await expectLater(
          shiftSessionService.ensurePaymentAllowed(
            user: User(
              id: adminId,
              name: 'Admin',
              pin: null,
              password: null,
              role: UserRole.admin,
              isActive: true,
              createdAt: DateTime.now(),
            ),
            transaction: closedTransaction!,
          ),
          throwsA(isA<ShiftNotActiveException>()),
        );
      },
    );
  });
}

Future<int> _countFinalCloseReconciliations(AppDatabase db, int shiftId) async {
  final row = await db
      .customSelect(
        '''
      SELECT COUNT(*) AS reconciliation_count
      FROM shift_reconciliations
      WHERE shift_id = ? AND kind = 'final_close'
    ''',
        variables: <Variable<Object>>[Variable<int>(shiftId)],
      )
      .getSingle();

  return row.read<int>('reconciliation_count');
}
