import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/data/repositories/user_repository.dart';
import 'package:epos_app/domain/models/cashier_dashboard_snapshot.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/cashier_dashboard_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('CashierDashboardSnapshot.computeLoadLevel', () {
    test('returns calm for 0', () {
      expect(
        CashierDashboardSnapshot.computeLoadLevel(0),
        OpenOrderLoadLevel.calm,
      );
    });

    test('returns normal for 1-5', () {
      expect(
        CashierDashboardSnapshot.computeLoadLevel(1),
        OpenOrderLoadLevel.normal,
      );
      expect(
        CashierDashboardSnapshot.computeLoadLevel(5),
        OpenOrderLoadLevel.normal,
      );
    });

    test('returns high for 6+', () {
      expect(
        CashierDashboardSnapshot.computeLoadLevel(6),
        OpenOrderLoadLevel.high,
      );
      expect(
        CashierDashboardSnapshot.computeLoadLevel(20),
        OpenOrderLoadLevel.high,
      );
    });
  });

  group('CashierDashboardService', () {
    test('no active shift returns locked empty operational snapshot', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );

      final CashierDashboardSnapshot snapshot = await _makeService(
        db,
      ).getSnapshot(user: _cashier(cashierId));

      expect(snapshot.shiftSession.backendOpenShift, isNull);
      expect(snapshot.openOrderCount, 0);
      expect(snapshot.openOrders, isEmpty);
      expect(snapshot.activity, isEmpty);
      expect(snapshot.operationalState, ShiftOperationalState.noShift);
      expect(
        snapshot.warnings.map((DashboardWarning w) => w.type),
        contains(DashboardWarningType.noShift),
      );
    });

    test('last activity is ordered newest-first', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);

      final int paidOrderId = await insertTransaction(
        db,
        uuid: 'activity-paid',
        shiftId: shiftId,
        userId: cashierId,
        status: 'paid',
        totalAmountMinor: 400,
        paidAt: DateTime(2026, 3, 28, 9, 0),
      );
      await insertPayment(
        db,
        uuid: 'activity-paid-payment',
        transactionId: paidOrderId,
        method: 'cash',
        amountMinor: 400,
        paidAt: DateTime(2026, 3, 28, 9, 0),
      );

      final int cancelledOrderId = await insertTransaction(
        db,
        uuid: 'activity-cancelled',
        shiftId: shiftId,
        userId: cashierId,
        status: 'cancelled',
        totalAmountMinor: 300,
        cancelledAt: DateTime(2026, 3, 28, 10, 0),
        cancelledBy: cashierId,
      );

      await AuditLogRepository(db).createAuditLog(
        actorUserId: cashierId,
        action: 'receipt_reprinted',
        entityType: 'transaction',
        entityId: 'activity-paid',
        metadataJson: '{}',
        createdAt: DateTime(2026, 3, 28, 11, 0),
      );

      final CashierDashboardSnapshot snapshot = await _makeService(
        db,
      ).getSnapshot(user: _cashier(cashierId));

      expect(snapshot.activity, hasLength(3));
      expect(
        snapshot.activity.map((CashierDashboardActivityItem item) => item.type),
        <CashierDashboardActivityType>[
          CashierDashboardActivityType.receiptReprint,
          CashierDashboardActivityType.cancellation,
          CashierDashboardActivityType.payment,
        ],
      );
      expect(snapshot.activity[1].transactionId, cancelledOrderId);
      expect(snapshot.activity[2].transactionId, paidOrderId);
    });

    test('admin cannot access cashier dashboard', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');

      await expectLater(
        () => _makeService(db).getSnapshot(user: _admin(adminId)),
        throwsA(isA<UnauthorisedException>()),
      );
    });

    test('open order count 6+ yields high load level', () async {
      final db = createTestDatabase();
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
          uuid: 'load-test-$i',
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

      final CashierDashboardSnapshot snapshot = await _makeService(
        db,
      ).getSnapshot(user: _cashier(cashierId));

      expect(snapshot.openOrderCount, 7);
      expect(snapshot.openOrderLoadLevel, OpenOrderLoadLevel.high);
    });

    test('open order count 0 yields calm load level', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);

      final CashierDashboardSnapshot snapshot = await _makeService(
        db,
      ).getSnapshot(user: _cashier(cashierId));

      expect(snapshot.openOrderCount, 0);
      expect(snapshot.openOrderLoadLevel, OpenOrderLoadLevel.calm);
    });

    test('open order count 1-5 yields normal load level', () async {
      final db = createTestDatabase();
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
      for (int i = 0; i < 3; i++) {
        final int txId = await insertTransaction(
          db,
          uuid: 'normal-load-$i',
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

      final CashierDashboardSnapshot snapshot = await _makeService(
        db,
      ).getSnapshot(user: _cashier(cashierId));

      expect(snapshot.openOrderCount, 3);
      expect(snapshot.openOrderLoadLevel, OpenOrderLoadLevel.normal);
    });

    test(
      'activity deduplicates cancellations from both transaction and audit log',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int shiftId = await insertShift(db, openedBy: cashierId);

        // Create a cancelled transaction (primary source)
        final int cancelledId = await insertTransaction(
          db,
          uuid: 'dedup-cancelled',
          shiftId: shiftId,
          userId: cashierId,
          status: 'cancelled',
          totalAmountMinor: 500,
          cancelledAt: DateTime(2026, 3, 28, 14, 0),
          cancelledBy: cashierId,
        );

        // Also create an audit log for the same cancellation (secondary source)
        await AuditLogRepository(db).createAuditLog(
          actorUserId: cashierId,
          action: 'transaction_cancelled',
          entityType: 'transaction',
          entityId: 'dedup-cancelled',
          metadataJson: '{}',
          createdAt: DateTime(2026, 3, 28, 14, 0),
        );

        final CashierDashboardSnapshot snapshot = await _makeService(
          db,
        ).getSnapshot(user: _cashier(cashierId));

        // Only one cancellation should appear (primary wins, audit deduped)
        final List<CashierDashboardActivityItem> cancellations = snapshot
            .activity
            .where(
              (CashierDashboardActivityItem item) =>
                  item.type == CashierDashboardActivityType.cancellation,
            )
            .toList();
        expect(cancellations, hasLength(1));
        expect(cancellations[0].transactionId, cancelledId);
      },
    );

    test('no active shift snapshot has calm load level', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );

      final CashierDashboardSnapshot snapshot = await _makeService(
        db,
      ).getSnapshot(user: _cashier(cashierId));

      expect(snapshot.openOrderLoadLevel, OpenOrderLoadLevel.calm);
    });

    test(
      'snapshot warnings include previewTaken when cashier preview is active',
      () async {
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
          cashierPreviewedAt: DateTime(2026, 3, 28, 16, 0),
        );

        final CashierDashboardSnapshot snapshot = await _makeService(
          db,
        ).getSnapshot(user: _cashier(cashierId));

        expect(
          snapshot.warnings.map((DashboardWarning w) => w.type),
          contains(DashboardWarningType.previewTaken),
        );
        expect(
          snapshot.warnings.map((DashboardWarning w) => w.type),
          isNot(contains(DashboardWarningType.noShift)),
        );
      },
    );

    test('snapshot warnings include highLoad when open orders >= 6', () async {
      final db = createTestDatabase();
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
          uuid: 'warning-load-$i',
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

      final CashierDashboardSnapshot snapshot = await _makeService(
        db,
      ).getSnapshot(user: _cashier(cashierId));

      expect(
        snapshot.warnings.map((DashboardWarning w) => w.type),
        contains(DashboardWarningType.highLoad),
      );
    });

    test(
      'snapshot warnings are empty for normal open shift with low load',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        await insertShift(db, openedBy: cashierId);

        final CashierDashboardSnapshot snapshot = await _makeService(
          db,
        ).getSnapshot(user: _cashier(cashierId));

        expect(snapshot.warnings, isEmpty);
      },
    );

    test('operationalState is normal for open shift without preview', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);

      final CashierDashboardSnapshot snapshot = await _makeService(
        db,
      ).getSnapshot(user: _cashier(cashierId));

      expect(snapshot.operationalState, ShiftOperationalState.normal);
    });

    test(
      'operationalState is previewTakenLocked when cashier preview is active',
      () async {
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
          cashierPreviewedAt: DateTime(2026, 3, 28, 16, 0),
        );

        final CashierDashboardSnapshot snapshot = await _makeService(
          db,
        ).getSnapshot(user: _cashier(cashierId));

        expect(
          snapshot.operationalState,
          ShiftOperationalState.previewTakenLocked,
        );
      },
    );
  });
}

CashierDashboardService _makeService(AppDatabase db) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  final ShiftSessionService shiftSessionService = ShiftSessionService(
    shiftRepository,
  );

  return CashierDashboardService(
    shiftSessionService: shiftSessionService,
    userRepository: UserRepository(db),
    orderService: OrderService(
      shiftSessionService: shiftSessionService,
      transactionRepository: TransactionRepository(db),
      transactionStateRepository: TransactionStateRepository(db),
      paymentRepository: PaymentRepository(db),
    ),
    paymentRepository: PaymentRepository(db),
    transactionRepository: TransactionRepository(db),
    auditLogRepository: AuditLogRepository(db),
  );
}

User _cashier(int id) {
  return User(
    id: id,
    name: 'Cashier',
    pin: null,
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime.now(),
  );
}

User _admin(int id) {
  return User(
    id: id,
    name: 'Admin',
    pin: null,
    password: null,
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.now(),
  );
}
