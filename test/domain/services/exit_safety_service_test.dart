import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/exit_safety.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/services/exit_safety_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Test double: simulates an order-state verification failure by throwing
/// from getActiveOrders. Closing the DB isn't sufficient — Drift may still
/// return an empty result for a closed in-memory DB rather than throwing.
class _ThrowingOrderService extends OrderService {
  _ThrowingOrderService({
    required super.shiftSessionService,
    required super.transactionRepository,
    required super.transactionStateRepository,
  });

  @override
  Future<List<Transaction>> getActiveOrders({int? shiftId}) {
    throw StateError('simulated verification failure');
  }
}

void main() {
  group('DefaultExitSafetyService.evaluate', () {
    test('no shift, no orders → noRisk', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final service = DefaultExitSafetyService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        orderService: OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
        ),
      );

      final ExitSafetyEvaluation result = await service.evaluate();

      expect(result.level, ExitSafetyLevel.noRisk);
      expect(result.reasons, isEmpty);
      expect(result.openOrderCount, 0);
      expect(result.sentOrderCount, 0);
    });

    test('active shift, no orders → warnOnly with activeShift reason',
        () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int userId = await insertUser(db, name: 'Cashier', role: 'cashier');
      await insertShift(db, openedBy: userId);

      final service = DefaultExitSafetyService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        orderService: OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
        ),
      );

      final ExitSafetyEvaluation result = await service.evaluate();

      expect(result.level, ExitSafetyLevel.warnOnly);
      expect(result.hasActiveShift, isTrue);
      expect(result.hasOpenOrders, isFalse);
      expect(result.hasSentOrders, isFalse);
    });

    test('draft order exists → blocked with openOrders reason', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int userId = await insertUser(db, name: 'Cashier', role: 'cashier');
      final int shiftId = await insertShift(db, openedBy: userId);
      await insertTransaction(
        db,
        uuid: 'tx-draft-1',
        shiftId: shiftId,
        userId: userId,
        status: 'draft',
        totalAmountMinor: 500,
      );

      final service = DefaultExitSafetyService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        orderService: OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
        ),
      );

      final ExitSafetyEvaluation result = await service.evaluate();

      expect(result.level, ExitSafetyLevel.blocked);
      expect(result.hasOpenOrders, isTrue);
      expect(result.openOrderCount, 1);
    });

    test('sent order exists → blocked with sentOrders reason', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int userId = await insertUser(db, name: 'Cashier', role: 'cashier');
      final int shiftId = await insertShift(db, openedBy: userId);
      await insertTransaction(
        db,
        uuid: 'tx-sent-1',
        shiftId: shiftId,
        userId: userId,
        status: 'sent',
        totalAmountMinor: 500,
      );
      await insertTransaction(
        db,
        uuid: 'tx-sent-2',
        shiftId: shiftId,
        userId: userId,
        status: 'sent',
        totalAmountMinor: 700,
      );

      final service = DefaultExitSafetyService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        orderService: OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
        ),
      );

      final ExitSafetyEvaluation result = await service.evaluate();

      expect(result.level, ExitSafetyLevel.blocked);
      expect(result.hasSentOrders, isTrue);
      expect(result.sentOrderCount, 2);
    });

    test('paid/cancelled orders alone → noRisk (they are terminal)', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int userId = await insertUser(db, name: 'Cashier', role: 'cashier');
      final int shiftId = await insertShift(
        db,
        openedBy: userId,
        status: 'closed',
        closedBy: userId,
        closedAt: DateTime.now(),
      );
      await insertTransaction(
        db,
        uuid: 'tx-paid',
        shiftId: shiftId,
        userId: userId,
        status: 'paid',
        totalAmountMinor: 500,
      );
      await insertTransaction(
        db,
        uuid: 'tx-cancelled',
        shiftId: shiftId,
        userId: userId,
        status: 'cancelled',
        totalAmountMinor: 700,
      );

      final service = DefaultExitSafetyService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        orderService: OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
        ),
      );

      final ExitSafetyEvaluation result = await service.evaluate();

      expect(result.level, ExitSafetyLevel.noRisk);
      expect(result.openOrderCount, 0);
      expect(result.sentOrderCount, 0);
    });

    test(
        'order verification failure → blocked with verificationFailed reason '
        '(prefer false-positive block over silent exit)', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final service = DefaultExitSafetyService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        orderService: _ThrowingOrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
        ),
      );

      final ExitSafetyEvaluation result = await service.evaluate();

      expect(result.level, ExitSafetyLevel.blocked);
      expect(result.verificationFailed, isTrue);
    });
  });
}
