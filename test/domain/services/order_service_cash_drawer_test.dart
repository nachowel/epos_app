import 'dart:async';
import 'dart:collection';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/user.dart' as domain;
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:epos_app/data/database/app_database.dart' as db;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

class MockPrinterService implements PrinterService {
  int openCashDrawerCalls = 0;
  bool shouldThrow = false;
  int _completedOpenCashDrawerCalls = 0;

  final StreamController<int> _openCashDrawerCallController =
      StreamController<int>.broadcast();
  final StreamController<int> _openCashDrawerCompletionController =
      StreamController<int>.broadcast();
  final Queue<Completer<void>> _pendingOpenCashDrawerCompletions =
      Queue<Completer<void>>();
  final Queue<Completer<void>> _activeOpenCashDrawerCompletions =
      Queue<Completer<void>>();

  @override
  Future<void> openCashDrawer() async {
    openCashDrawerCalls++;
    _openCashDrawerCallController.add(openCashDrawerCalls);

    final Completer<void>? pendingCompletion =
        _pendingOpenCashDrawerCompletions.isNotEmpty
        ? _pendingOpenCashDrawerCompletions.removeFirst()
        : null;
    if (pendingCompletion != null) {
      _activeOpenCashDrawerCompletions.add(pendingCompletion);
    }

    try {
      if (pendingCompletion != null) {
        await pendingCompletion.future;
      }
      if (shouldThrow) {
        throw Exception('Printer disconnected');
      }
    } finally {
      _completedOpenCashDrawerCalls++;
      _openCashDrawerCompletionController.add(_completedOpenCashDrawerCalls);
    }
  }

  void blockNextOpenCashDrawerCompletion() {
    _pendingOpenCashDrawerCompletions.add(Completer<void>());
  }

  void releaseBlockedOpenCashDrawerCompletions() {
    while (_pendingOpenCashDrawerCompletions.isNotEmpty) {
      final Completer<void> completer = _pendingOpenCashDrawerCompletions
          .removeFirst();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    while (_activeOpenCashDrawerCompletions.isNotEmpty) {
      final Completer<void> completer = _activeOpenCashDrawerCompletions
          .removeFirst();
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
  }

  Future<void> waitForOpenCashDrawerCompletions(int expectedCompletions) async {
    if (_completedOpenCashDrawerCalls >= expectedCompletions) {
      return;
    }
    await _openCashDrawerCompletionController.stream.firstWhere(
      (int completions) => completions >= expectedCompletions,
    );
  }

  Future<void> dispose() async {
    releaseBlockedOpenCashDrawerCompletions();
    await _openCashDrawerCallController.close();
    await _openCashDrawerCompletionController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Cash Drawer Integration', () {
    late _Fixture fixture;

    setUp(() async {
      fixture = await _Fixture.create();
    });

    tearDown(() async {
      await fixture.dispose();
    });

    test(
      'opens cash drawer exactly once for a successful cash payment',
      () async {
        await fixture.orderService.markOrderPaid(
          transactionId: fixture.transactionId,
          method: PaymentMethod.cash,
          currentUser: fixture.admin,
        );

        await fixture.mockPrinterService.waitForOpenCashDrawerCompletions(1);

        expect(fixture.mockPrinterService.openCashDrawerCalls, 1);
      },
    );

    test('does not open cash drawer for card payments', () async {
      await fixture.orderService.markOrderPaid(
        transactionId: fixture.transactionId,
        method: PaymentMethod.card,
        currentUser: fixture.admin,
      );

      expect(fixture.mockPrinterService.openCashDrawerCalls, 0);
    });

    test('payment success is not blocked if drawer opening fails', () async {
      fixture.mockPrinterService.shouldThrow = true;

      final payment = await fixture.orderService.markOrderPaid(
        transactionId: fixture.transactionId,
        method: PaymentMethod.cash,
        currentUser: fixture.admin,
      );

      await fixture.mockPrinterService.waitForOpenCashDrawerCompletions(1);

      expect(payment, isNotNull);
      expect(fixture.mockPrinterService.openCashDrawerCalls, 1);
    });

    test(
      'calling markOrderPaid twice on the same transaction does not trigger the drawer twice',
      () async {
        fixture.mockPrinterService.blockNextOpenCashDrawerCompletion();

        await fixture.orderService.markOrderPaid(
          transactionId: fixture.transactionId,
          method: PaymentMethod.cash,
          currentUser: fixture.admin,
        );

        expect(fixture.mockPrinterService.openCashDrawerCalls, 1);

        await expectLater(
          fixture.orderService.markOrderPaid(
            transactionId: fixture.transactionId,
            method: PaymentMethod.cash,
            currentUser: fixture.admin,
          ),
          throwsA(
            isA<OrderPaymentBlockedException>().having(
              (OrderPaymentBlockedException error) => error.reason,
              'reason',
              PaymentBlockReason.alreadyPaid,
            ),
          ),
        );

        fixture.mockPrinterService.releaseBlockedOpenCashDrawerCompletions();
        await fixture.mockPrinterService.waitForOpenCashDrawerCompletions(1);

        final Transaction transaction = await fixture.getTransaction();

        expect(fixture.mockPrinterService.openCashDrawerCalls, 1);
        expect(await fixture.countPaymentsForTransaction(), 1);
        expect(transaction.status, TransactionStatus.paid);
        expect(transaction.paidAt, isNotNull);
        expect(transaction.cancelledAt, isNull);
      },
    );

    test(
      'rapid repeated payment attempts concurrently still open the drawer only once',
      () async {
        fixture.mockPrinterService.blockNextOpenCashDrawerCompletion();

        // Start all attempts before awaiting any of them so they contend on the
        // same sent transaction concurrently.
        final List<Future<Object?>> attempts = List<Future<Object?>>.generate(
          8,
          (_) async {
            try {
              return await fixture.orderService.markOrderPaid(
                transactionId: fixture.transactionId,
                method: PaymentMethod.cash,
                currentUser: fixture.admin,
              );
            } catch (error) {
              return error;
            }
          },
        );

        final List<Object?> results = await Future.wait<Object?>(attempts);

        expect(results.whereType<Payment>().length, 1);
        expect(fixture.mockPrinterService.openCashDrawerCalls, 1);

        fixture.mockPrinterService.releaseBlockedOpenCashDrawerCompletions();
        await fixture.mockPrinterService.waitForOpenCashDrawerCompletions(1);

        final Transaction transaction = await fixture.getTransaction();

        expect(fixture.mockPrinterService.openCashDrawerCalls, 1);
        expect(await fixture.countPaymentsForTransaction(), 1);
        expect(transaction.status, TransactionStatus.paid);
        expect(transaction.paidAt, isNotNull);
        expect(transaction.cancelledAt, isNull);
      },
    );
  });
}

class _Fixture {
  _Fixture({
    required this.database,
    required this.orderService,
    required this.mockPrinterService,
    required this.transactionRepository,
    required this.transactionId,
    required this.admin,
  });

  final db.AppDatabase database;
  final OrderService orderService;
  final MockPrinterService mockPrinterService;
  final TransactionRepository transactionRepository;
  final int transactionId;
  final domain.User admin;

  Future<Transaction> getTransaction() async {
    return await transactionRepository.getById(transactionId) ??
        (throw StateError('Transaction not found: $transactionId'));
  }

  Future<int> countPaymentsForTransaction() async {
    final row = await database
        .customSelect(
          'SELECT COUNT(*) AS payment_count FROM payments WHERE transaction_id = ?',
          variables: <Variable<Object>>[Variable<int>(transactionId)],
        )
        .getSingle();
    return row.read<int>('payment_count');
  }

  Future<void> dispose() async {
    await mockPrinterService.dispose();
    await database.close();
  }

  static Future<_Fixture> create() async {
    final database = createTestDatabase();
    final int adminId = await insertUser(
      database,
      name: 'Admin',
      role: 'admin',
    );
    final admin = domain.User(
      id: adminId,
      name: 'Admin',
      pin: null,
      password: null,
      role: domain.UserRole.admin,
      isActive: true,
      createdAt: DateTime.now(),
    );

    final int categoryId = await insertCategory(database, name: 'Food');
    final int productId = await insertProduct(
      database,
      categoryId: categoryId,
      name: 'Burger',
      priceMinor: 1000,
    );

    final int shiftId = await insertShift(database, openedBy: adminId);
    final int transactionId = await insertTransaction(
      database,
      uuid: 'drawer-test-tx',
      shiftId: shiftId,
      userId: adminId,
      status: 'draft',
      totalAmountMinor: 1000,
    );

    final transactionRepository = TransactionRepository(database);
    await transactionRepository.addLine(
      transactionId: transactionId,
      productId: productId,
      quantity: 1,
    );

    final transactionStateRepository = TransactionStateRepository(database);
    await transactionStateRepository.transitionDraftOrderToSent(
      transactionId: transactionId,
    );

    final mockPrinterService = MockPrinterService();
    final orderService = OrderService(
      shiftSessionService: ShiftSessionService(ShiftRepository(database)),
      transactionRepository: transactionRepository,
      transactionStateRepository: transactionStateRepository,
      paymentRepository: PaymentRepository(database),
      printerService: mockPrinterService,
    );

    return _Fixture(
      database: database,
      orderService: orderService,
      mockPrinterService: mockPrinterService,
      transactionRepository: transactionRepository,
      transactionId: transactionId,
      admin: admin,
    );
  }
}
