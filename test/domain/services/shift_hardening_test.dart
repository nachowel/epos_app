import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/interaction_block_reason.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/shift_report.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  // ────────────────────────────────────────────────
  // EXCEPTION DIFFERENTIATION
  // ────────────────────────────────────────────────
  group('Exception differentiation', () {
    test('no active shift throws ShiftNotActiveException', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Cashier', role: 'cashier');
      // No shift opened

      final service = ShiftSessionService(ShiftRepository(db));

      expect(
        () => service.requireBackendOpenShift(),
        throwsA(isA<ShiftNotActiveException>()),
      );
    });

    test('shift mismatch throws ShiftMismatchException', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int userId = await insertUser(db, name: 'Admin', role: 'admin');
      // Create shift 1, close it, then open shift 2
      final int shift1Id = await insertShift(db, openedBy: userId);
      // Insert a transaction on shift 1
      final int txId = await insertTransaction(
        db,
        uuid: 'tx-shift-1',
        shiftId: shift1Id,
        userId: userId,
        status: 'sent',
        totalAmountMinor: 500,
      );

      // Close shift 1 manually — cancel the open order first
      await OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
      ).cancelOrder(
        transactionId: txId,
        currentUser: User(
          id: userId,
          name: 'Admin',
          pin: null,
          password: null,
          role: UserRole.admin,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );
      await ShiftRepository(db).closeShift(shift1Id, userId);

      // Open shift 2
      await insertShift(db, openedBy: userId);

      // Create a new OPEN transaction on shift 1 (simulating stale data)
      final int staleTxId = await insertTransaction(
        db,
        uuid: 'tx-stale',
        shiftId: shift1Id,
        userId: userId,
        status: 'sent',
        totalAmountMinor: 300,
      );

      final service = ShiftSessionService(ShiftRepository(db));
      final staleTx = await TransactionRepository(db).getById(staleTxId);

      await expectLater(
        service.ensurePaymentAllowed(
          user: User(
            id: userId,
            name: 'Admin',
            pin: null,
            password: null,
            role: UserRole.admin,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          transaction: staleTx!,
        ),
        throwsA(isA<ShiftMismatchException>()),
      );
    });

    test('cashier preview lock throws CashierPreviewLockedException', () async {
      final db = createTestDatabase();
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
        cashierPreviewedAt: DateTime.now(),
      );

      final service = ShiftSessionService(ShiftRepository(db));
      final cashier = User(
        id: cashierId,
        name: 'Cashier',
        pin: null,
        password: null,
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime.now(),
      );

      expect(
        () => service.ensureOrderCreationAllowed(cashier),
        throwsA(isA<CashierPreviewLockedException>()),
      );
    });
  });

  // ────────────────────────────────────────────────
  // SHIFT-LEVEL CASHIER LOCK
  // ────────────────────────────────────────────────
  group('Shift-level cashier lock', () {
    test(
      'cashier A previews → cashier B is also locked on same shift',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierAId = await insertUser(
          db,
          name: 'Cashier A',
          role: 'cashier',
        );
        final int cashierBId = await insertUser(
          db,
          name: 'Cashier B',
          role: 'cashier',
        );
        final int shiftId = await insertShift(db, openedBy: cashierAId);

        final shiftRepo = ShiftRepository(db);
        final service = ShiftSessionService(shiftRepo);

        // Cashier A takes preview
        await shiftRepo.markCashierPreview(
          shiftId: shiftId,
          userId: cashierAId,
        );

        final cashierB = User(
          id: cashierBId,
          name: 'Cashier B',
          pin: null,
          password: null,
          role: UserRole.cashier,
          isActive: true,
          createdAt: DateTime.now(),
        );

        // Cashier B is also locked from order creation
        expect(
          () => service.ensureOrderCreationAllowed(cashierB),
          throwsA(isA<CashierPreviewLockedException>()),
        );

        // Cashier B is also locked from payment
        final int txId = await insertTransaction(
          db,
          uuid: 'tx-cashierB-locked',
          shiftId: shiftId,
          userId: cashierBId,
          status: 'sent',
          totalAmountMinor: 600,
        );
        final tx = await TransactionRepository(db).getById(txId);

        expect(
          () => service.ensurePaymentAllowed(user: cashierB, transaction: tx!),
          throwsA(isA<CashierPreviewLockedException>()),
        );
      },
    );

    test('cashier preview lock applies to order creation', () async {
      final db = createTestDatabase();
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
        cashierPreviewedAt: DateTime.now(),
      );

      final service = ShiftSessionService(ShiftRepository(db));
      final cashier = User(
        id: cashierId,
        name: 'Cashier',
        pin: null,
        password: null,
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime.now(),
      );

      expect(
        () => service.ensureOrderCreationAllowed(cashier),
        throwsA(isA<CashierPreviewLockedException>()),
      );
    });

    test('cashier preview lock applies to payment on open orders', () async {
      final db = createTestDatabase();
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
        cashierPreviewedAt: DateTime.now(),
      );
      final int txId = await insertTransaction(
        db,
        uuid: 'tx-preview-payment',
        shiftId: shiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 800,
      );

      final service = ShiftSessionService(ShiftRepository(db));
      final cashier = User(
        id: cashierId,
        name: 'Cashier',
        pin: null,
        password: null,
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime.now(),
      );
      final tx = await TransactionRepository(db).getById(txId);

      expect(
        () => service.ensurePaymentAllowed(user: cashier, transaction: tx!),
        throwsA(isA<CashierPreviewLockedException>()),
      );
    });

    test('snapshot reflects cashier lock for cashier user', () async {
      final db = createTestDatabase();
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
        cashierPreviewedAt: DateTime.now(),
      );

      final service = ShiftSessionService(ShiftRepository(db));
      final cashier = User(
        id: cashierId,
        name: 'Cashier',
        pin: null,
        password: null,
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final snapshot = await service.getSnapshotForUser(cashier);

      expect(snapshot.cashierPreviewActive, isTrue);
      expect(snapshot.salesLocked, isTrue);
      expect(snapshot.paymentsLocked, isTrue);
      expect(
        snapshot.lockReason,
        InteractionBlockReason.adminFinalCloseRequired,
      );
      expect(snapshot.visibleShift, isNotNull);
    });
  });

  // ────────────────────────────────────────────────
  // ADMIN OVERRIDE
  // ────────────────────────────────────────────────
  group('Admin override', () {
    test('admin can see open shift even after cashier preview', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      await insertShift(
        db,
        openedBy: cashierId,
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );

      final service = ShiftSessionService(ShiftRepository(db));
      final admin = User(
        id: adminId,
        name: 'Admin',
        pin: null,
        password: null,
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final snapshot = await service.getSnapshotForUser(admin);

      expect(snapshot.backendOpenShift, isNotNull);
      expect(snapshot.visibleShift, isNotNull);
      expect(snapshot.salesLocked, isFalse);
      expect(snapshot.paymentsLocked, isFalse);
      expect(snapshot.lockReason, isNull);
      expect(snapshot.cashierPreviewActive, isTrue);
    });

    test('admin can create orders after cashier preview', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      await insertShift(
        db,
        openedBy: cashierId,
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );

      final service = ShiftSessionService(ShiftRepository(db));
      final admin = User(
        id: adminId,
        name: 'Admin',
        pin: null,
        password: null,
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Should not throw
      await service.ensureOrderCreationAllowed(admin);
    });

    test('admin can take payment after cashier preview', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(
        db,
        openedBy: cashierId,
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );
      final int txId = await insertTransaction(
        db,
        uuid: 'tx-admin-payment',
        shiftId: shiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 900,
      );

      final service = ShiftSessionService(ShiftRepository(db));
      final admin = User(
        id: adminId,
        name: 'Admin',
        pin: null,
        password: null,
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
      );
      final tx = await TransactionRepository(db).getById(txId);

      // Should not throw
      await service.ensurePaymentAllowed(user: admin, transaction: tx!);
    });

    test('admin can perform final close after cashier preview', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      await insertShift(
        db,
        openedBy: cashierId,
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );

      final shiftRepo = ShiftRepository(db);
      final reportService = ReportService(
        shiftRepository: shiftRepo,
        shiftSessionService: ShiftSessionService(shiftRepo),
        transactionRepository: TransactionRepository(db),
        paymentRepository: PaymentRepository(db),
        settingsRepository: SettingsRepository(db),
        reportVisibilityService: const ReportVisibilityService(),
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

      final result = await reportService.runAdminFinalCloseWithCountedCash(
        user: admin,
        countedCashMinor: 0,
      );

      expect(result.finalCloseCompleted, isTrue);
      expect(result.cashierPreviewRecorded, isTrue);
      final openShift = await shiftRepo.getOpenShift();
      expect(openShift, isNull);
    });

    test('admin gets real (unmasked) report data', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int txId = await insertTransaction(
        db,
        uuid: 'tx-admin-real',
        shiftId: shiftId,
        userId: adminId,
        status: 'draft',
        totalAmountMinor: 2000,
      );
      final int categoryId = await insertCategory(db, name: 'Report Food');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Stew',
        priceMinor: 2000,
      );
      await TransactionRepository(
        db,
      ).addLine(transactionId: txId, productId: productId, quantity: 1);
      final admin = User(
        id: adminId,
        name: 'Admin',
        pin: null,
        password: null,
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime.now(),
      );
      await OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
        paymentRepository: PaymentRepository(db),
      ).sendOrder(transactionId: txId, currentUser: admin);
      await OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
        paymentRepository: PaymentRepository(db),
      ).markOrderPaid(
        transactionId: txId,
        method: PaymentMethod.cash,
        currentUser: admin,
      );

      final shiftRepo = ShiftRepository(db);
      await SettingsRepository(db).updateVisibilityRatio(0.3, userId: adminId);

      final reportService = ReportService(
        shiftRepository: shiftRepo,
        shiftSessionService: ShiftSessionService(shiftRepo),
        transactionRepository: TransactionRepository(db),
        paymentRepository: PaymentRepository(db),
        settingsRepository: SettingsRepository(db),
        reportVisibilityService: const ReportVisibilityService(),
      );

      final report = await reportService.getVisibleShiftReport(
        shiftId: shiftId,
        user: admin,
      );

      expect(report.paidTotalMinor, 2000);
    });
  });

  // ────────────────────────────────────────────────
  // MASKED VS REAL REPORT PIPELINE
  // ────────────────────────────────────────────────
  group('Masked vs real report pipeline', () {
    test(
      'cashier gets masked amounts, admin gets real amounts for same shift',
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
        final int txId = await insertTransaction(
          db,
          uuid: 'tx-visibility',
          shiftId: shiftId,
          userId: cashierId,
          status: 'draft',
          totalAmountMinor: 1000,
        );
        final int categoryId = await insertCategory(
          db,
          name: 'Visibility Food',
        );
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Cake',
          priceMinor: 1000,
        );
        await TransactionRepository(
          db,
        ).addLine(transactionId: txId, productId: productId, quantity: 1);
        final admin = User(
          id: adminId,
          name: 'Admin',
          pin: null,
          password: null,
          role: UserRole.admin,
          isActive: true,
          createdAt: DateTime.now(),
        );
        await OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
        ).sendOrder(transactionId: txId, currentUser: admin);
        await OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
        ).markOrderPaid(
          transactionId: txId,
          method: PaymentMethod.cash,
          currentUser: admin,
        );

        await SettingsRepository(
          db,
        ).updateVisibilityRatio(0.5, userId: adminId);

        final shiftRepo = ShiftRepository(db);
        final reportService = ReportService(
          shiftRepository: shiftRepo,
          shiftSessionService: ShiftSessionService(shiftRepo),
          transactionRepository: TransactionRepository(db),
          paymentRepository: PaymentRepository(db),
          settingsRepository: SettingsRepository(db),
          reportVisibilityService: const ReportVisibilityService(),
        );

        final cashier = User(
          id: cashierId,
          name: 'Cashier',
          pin: null,
          password: null,
          role: UserRole.cashier,
          isActive: true,
          createdAt: DateTime.now(),
        );
        final maskedReport = await reportService.getVisibleShiftReport(
          shiftId: shiftId,
          user: cashier,
        );
        final realReport = await reportService.getVisibleShiftReport(
          shiftId: shiftId,
          user: admin,
        );

        expect(maskedReport.paidTotalMinor, 500);
        expect(realReport.paidTotalMinor, 1000);
      },
    );

    test('printZReport requires configured printer settings', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final printerService = PrinterService(TransactionRepository(db));

      const maskedReport = ShiftReport(
        shiftId: 1,
        paidCount: 5,
        paidTotalMinor: 250,
        openCount: 0,
        openTotalMinor: 0,
        cancelledCount: 0,
        cashCount: 3,
        cashTotalMinor: 150,
        cardCount: 2,
        cardTotalMinor: 100,
      );

      await expectLater(
        printerService.printZReport(maskedReport),
        throwsA(isA<PrinterException>()),
      );
    });
  });

  // ────────────────────────────────────────────────
  // NO ACTIVE SHIFT SCENARIOS
  // ────────────────────────────────────────────────
  group('No active shift', () {
    test('snapshot with no shift shows closed state', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Cashier', role: 'cashier');

      final service = ShiftSessionService(ShiftRepository(db));
      final snapshot = await service.getSnapshotForUser(
        User(
          id: 1,
          name: 'Cashier',
          pin: null,
          password: null,
          role: UserRole.cashier,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      expect(snapshot.backendOpenShift, isNull);
      expect(snapshot.effectiveShiftStatus, ShiftStatus.closed);
      expect(snapshot.salesLocked, isFalse);
      expect(snapshot.paymentsLocked, isFalse);
      expect(snapshot.lockReason, InteractionBlockReason.noOpenShift);
    });

    test(
      'order creation without shift throws ShiftNotActiveException',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        await insertUser(db, name: 'Cashier', role: 'cashier');

        final service = ShiftSessionService(ShiftRepository(db));

        expect(
          () => service.ensureOrderCreationAllowed(
            User(
              id: 1,
              name: 'Cashier',
              pin: null,
              password: null,
              role: UserRole.cashier,
              isActive: true,
              createdAt: DateTime.now(),
            ),
          ),
          throwsA(isA<ShiftNotActiveException>()),
        );
      },
    );
  });
}
