import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart' as db;
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/print_job_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/checkout_item.dart';
import 'package:epos_app/domain/models/checkout_modifier.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/print_job.dart';
import 'package:epos_app/domain/models/printer_settings.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/checkout_service.dart';
import 'package:epos_app/domain/services/audit_log_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrinterService print job state', () {
    test(
      'existing printed job early exit reuses row without printing',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final int transactionId = await _seedTransaction(
          database,
          status: 'sent',
        );
        final int existingId = await insertPrintJob(
          database,
          transactionId: transactionId,
          target: PrintJobTarget.kitchen,
          status: 'printed',
          attemptCount: 1,
          completedAt: DateTime(2026, 1, 1, 12, 0, 0),
        );

        int socketCalls = 0;
        final PrinterService service = _createPrinterService(
          database,
          socketConnector: (String host, int port, Duration timeout) async {
            socketCalls += 1;
            throw StateError('socket should not be used on early exit');
          },
        );

        final PrintJob job = await service.printKitchenTicket(transactionId);

        expect(job.id, existingId);
        expect(job.status, PrintJobStatus.printed);
        expect(socketCalls, 0);
        expect(
          await _countPrintJobs(database, transactionId: transactionId),
          1,
        );
      },
    );

    test(
      'existing printing job is skipped without duplicate execution',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final int transactionId = await _seedTransaction(
          database,
          status: 'sent',
        );
        final int existingId = await insertPrintJob(
          database,
          transactionId: transactionId,
          target: PrintJobTarget.kitchen,
          status: 'printing',
          attemptCount: 1,
          lastAttemptAt: DateTime(2026, 1, 1, 12, 0, 0),
        );

        int socketCalls = 0;
        final PrinterService service = _createPrinterService(
          database,
          socketConnector: (String host, int port, Duration timeout) async {
            socketCalls += 1;
            throw StateError(
              'socket should not be used while already printing',
            );
          },
        );

        final PrintJob job = await service.printKitchenTicket(transactionId);

        expect(job.id, existingId);
        expect(job.status, PrintJobStatus.printing);
        expect(socketCalls, 0);
        expect(
          await _countPrintJobs(database, transactionId: transactionId),
          1,
        );
      },
    );

    test(
      'existing failed job reprint path reuses row and marks printed',
      () async {
        final _TcpCaptureServer server = await _TcpCaptureServer.start();
        addTearDown(server.close);

        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final int transactionId = await _seedTransaction(
          database,
          status: 'paid',
        );
        await insertPayment(
          database,
          uuid: 'payment-$transactionId',
          transactionId: transactionId,
          method: 'card',
          amountMinor: 450,
        );
        await _saveEthernetPrinter(database, port: server.port);

        final int existingId = await insertPrintJob(
          database,
          transactionId: transactionId,
          target: PrintJobTarget.receipt,
          status: 'failed',
          attemptCount: 1,
          lastAttemptAt: DateTime(2026, 1, 1, 11, 0, 0),
          lastError: 'Printer offline',
        );

        final PrinterService service = _createPrinterService(database);
        final PrintJob printed = await service.printReceipt(
          transactionId,
          allowReprint: true,
          actorUserId: 1,
        );

        expect(printed.id, existingId);
        expect(printed.status, PrintJobStatus.printed);
        expect(printed.attemptCount, 2);
        expect(
          await _countPrintJobs(database, transactionId: transactionId),
          1,
        );
        expect(server.connectionCount, 1);
      },
    );

    test(
      'existing printed job can be reprinted when override is requested',
      () async {
        final _TcpCaptureServer server = await _TcpCaptureServer.start();
        addTearDown(server.close);

        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final int transactionId = await _seedTransaction(
          database,
          status: 'paid',
        );
        await insertPayment(
          database,
          uuid: 'payment-reprint-$transactionId',
          transactionId: transactionId,
          method: 'card',
          amountMinor: 450,
        );
        await _saveEthernetPrinter(database, port: server.port);

        final int existingId = await insertPrintJob(
          database,
          transactionId: transactionId,
          target: PrintJobTarget.receipt,
          status: 'printed',
          completedAt: DateTime(2026, 1, 1, 11, 0, 0),
        );

        final PrinterService service = _createPrinterService(database);
        final PrintJob printed = await service.printReceipt(
          transactionId,
          allowReprint: true,
          actorUserId: 1,
        );

        expect(printed.id, existingId);
        expect(printed.status, PrintJobStatus.printed);
        expect(printed.attemptCount, 1);
        expect(server.connectionCount, 1);
      },
    );

    test('manual receipt reprint requires actor user id', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);
      final int transactionId = await _seedTransaction(database, status: 'paid');
      await insertPayment(
        database,
        uuid: 'payment-manual-actor-$transactionId',
        transactionId: transactionId,
        method: 'card',
        amountMinor: 450,
      );
      await insertPrintJob(
        database,
        transactionId: transactionId,
        target: PrintJobTarget.receipt,
        status: 'printed',
      );

      final PrinterService service = _createPrinterService(database);

      await expectLater(
        service.printReceipt(transactionId, allowReprint: true),
        throwsA(isA<ValidationException>()),
      );
    });

    test('paid order without payment record cannot reprint receipt', () async {
      final _TcpCaptureServer server = await _TcpCaptureServer.start();
      addTearDown(server.close);

      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);
      final int transactionId = await _seedTransaction(database, status: 'paid');
      await _saveEthernetPrinter(database, port: server.port);
      await insertPrintJob(
        database,
        transactionId: transactionId,
        target: PrintJobTarget.receipt,
        status: 'printed',
      );

      final PrinterService service = _createPrinterService(database);

      await expectLater(
        service.printReceipt(
          transactionId,
          allowReprint: true,
          actorUserId: 1,
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('cancelled order with payment still cannot reprint receipt', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);
      final int transactionId = await _seedTransaction(
        database,
        status: 'cancelled',
      );
      await insertPayment(
        database,
        uuid: 'payment-cancelled-$transactionId',
        transactionId: transactionId,
        method: 'card',
        amountMinor: 450,
      );
      await insertPrintJob(
        database,
        transactionId: transactionId,
        target: PrintJobTarget.receipt,
        status: 'pending',
      );

      final PrinterService service = _createPrinterService(database);

      await expectLater(
        service.printReceipt(
          transactionId,
          allowReprint: true,
          actorUserId: 1,
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('manual kitchen reprint writes audit log entry', () async {
      final _TcpCaptureServer server = await _TcpCaptureServer.start();
      addTearDown(server.close);

      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);
      final int actorUserId = await insertUser(
        database,
        name: 'Supervisor',
        role: 'cashier',
      );
      final int transactionId = await _seedTransaction(database, status: 'sent');
      await _saveEthernetPrinter(database, port: server.port);
      await insertPrintJob(
        database,
        transactionId: transactionId,
        target: PrintJobTarget.kitchen,
        status: 'printed',
      );
      final AuditLogRepository auditLogRepository = AuditLogRepository(database);
      final AuditLogService auditLogService = PersistedAuditLogService(
        auditLogRepository: auditLogRepository,
        logger: const NoopAppLogger(),
      );

      final PrinterService service = _createPrinterService(
        database,
        auditLogService: auditLogService,
      );

      await service.printKitchenTicket(
        transactionId,
        allowReprint: true,
        actorUserId: actorUserId,
      );

      final logs = await auditLogRepository.listRecent(limit: 10);
      expect(
        logs.any((record) => record.action == 'kitchen_ticket_reprinted'),
        isTrue,
      );
    });

    test(
      'kitchen and receipt paths do not violate unique constraint',
      () async {
        final _TcpCaptureServer server = await _TcpCaptureServer.start();
        addTearDown(server.close);

        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final int transactionId = await _seedTransaction(
          database,
          status: 'paid',
        );
        await insertPayment(
          database,
          uuid: 'payment-both-$transactionId',
          transactionId: transactionId,
          method: 'card',
          amountMinor: 450,
        );
        await _saveEthernetPrinter(database, port: server.port);

        final int kitchenId = await insertPrintJob(
          database,
          transactionId: transactionId,
          target: PrintJobTarget.kitchen,
          status: 'pending',
        );
        final int receiptId = await insertPrintJob(
          database,
          transactionId: transactionId,
          target: PrintJobTarget.receipt,
          status: 'pending',
        );

        final PrinterService service = _createPrinterService(database);
        final PrintJob kitchen = await service.printKitchenTicket(
          transactionId,
        );
        final PrintJob receipt = await service.printReceipt(transactionId);

        expect(kitchen.id, kitchenId);
        expect(kitchen.status, PrintJobStatus.printed);
        expect(receipt.id, receiptId);
        expect(receipt.status, PrintJobStatus.printed);
        expect(
          await _countPrintJobs(database, transactionId: transactionId),
          2,
        );
        expect(
          await _countPrintJobs(
            database,
            transactionId: transactionId,
            target: PrintJobTarget.kitchen,
          ),
          1,
        );
        expect(
          await _countPrintJobs(
            database,
            transactionId: transactionId,
            target: PrintJobTarget.receipt,
          ),
          1,
        );
        expect(server.connectionCount, 2);
      },
    );

    test(
      'pay-now checkout only auto-prints kitchen and does not create receipt job',
      () async {
        final _TcpCaptureServer server = await _TcpCaptureServer.start();
        addTearDown(server.close);

        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        await _saveEthernetPrinter(database, port: server.port);

        final _CheckoutFixture fixture = await _createCheckoutFixture(database);
        final PrinterService printerService = _createPrinterService(database);
        final CheckoutService checkoutService = CheckoutService(
          shiftSessionService: fixture.shiftSessionService,
          orderService: fixture.orderService,
          printerService: printerService,
        );

        final Transaction transaction = await checkoutService.checkoutCart(
          currentUser: fixture.cashier,
          cartItems: <CheckoutItem>[
            CheckoutItem(
              productId: fixture.productId,
              quantity: 1,
              modifiers: const <CheckoutModifier>[],
            ),
          ],
          idempotencyKey: 'checkout-existing-pending-print-job',
          immediatePaymentMethod: PaymentMethod.card,
        );

        final List<PrintJob> jobs = await PrintJobRepository(
          database,
        ).getByTransactionId(transaction.id);

        expect(transaction.status, TransactionStatus.paid);
        expect(jobs, hasLength(1));
        expect(jobs.single.target, PrintJobTarget.kitchen);
        expect(jobs.single.status, PrintJobStatus.printed);
        expect(
          await _countPrintJobs(database, transactionId: transaction.id),
          1,
        );
        expect(
          await _countPrintJobs(
            database,
            transactionId: transaction.id,
            target: PrintJobTarget.receipt,
          ),
          0,
        );
        expect(server.connectionCount, 1);
      },
    );

    test('printer service missing job fails without creating a row', () async {
      final _TcpCaptureServer server = await _TcpCaptureServer.start();
      addTearDown(server.close);

      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);
      final int transactionId = await _seedTransaction(
        database,
        status: 'sent',
      );
      await _saveEthernetPrinter(database, port: server.port);

      final PrinterService service = _createPrinterService(database);

      await expectLater(
        service.printKitchenTicket(transactionId),
        throwsA(isA<DatabaseException>()),
      );
      expect(await _countPrintJobs(database, transactionId: transactionId), 0);
      expect(server.connectionCount, 0);
    });
  });
}

PrinterService _createPrinterService(
  db.AppDatabase database, {
  AuditLogService auditLogService = const NoopAuditLogService(),
  SocketConnector? socketConnector,
}) {
  return PrinterService(
    TransactionRepository(database),
    paymentRepository: PaymentRepository(database),
    printJobRepository: PrintJobRepository(database),
    settingsRepository: SettingsRepository(database),
    auditLogService: auditLogService,
    socketConnector: socketConnector,
  );
}

Future<void> _saveEthernetPrinter(
  db.AppDatabase database, {
  required int port,
}) {
  return SettingsRepository(database).savePrinterSettings(
    deviceName: 'Kitchen Ethernet',
    deviceAddress: '127.0.0.1',
    paperWidth: 80,
    connectionType: PrinterConnectionType.ethernet,
    ipAddress: '127.0.0.1',
    port: port,
  );
}

Future<int> _seedTransaction(
  db.AppDatabase database, {
  required String status,
}) async {
  final int userId = await insertUser(
    database,
    name: 'Cashier $status',
    role: 'cashier',
  );
  final int shiftId = await insertShift(database, openedBy: userId);
  return insertTransaction(
    database,
    uuid: 'tx-$status-${DateTime.now().microsecondsSinceEpoch}',
    shiftId: shiftId,
    userId: userId,
    status: status,
    totalAmountMinor: 450,
  );
}

Future<int> _countPrintJobs(
  db.AppDatabase database, {
  required int transactionId,
  PrintJobTarget? target,
}) {
  final StringBuffer sql = StringBuffer('''
    SELECT COUNT(*) AS row_count
    FROM print_jobs
    WHERE transaction_id = ?
  ''');
  final List<Variable<Object>> variables = <Variable<Object>>[
    Variable<int>(transactionId),
  ];
  if (target != null) {
    sql.write(' AND target = ?');
    variables.add(
      Variable<String>(
        target == PrintJobTarget.kitchen ? 'kitchen' : 'receipt',
      ),
    );
  }
  return database
      .customSelect(sql.toString(), variables: variables)
      .getSingle()
      .then((row) => row.read<int>('row_count'));
}

Future<_CheckoutFixture> _createCheckoutFixture(db.AppDatabase database) async {
  final int cashierId = await insertUser(
    database,
    name: 'Cashier',
    role: 'cashier',
  );
  await insertShift(database, openedBy: cashierId);
  final int categoryId = await insertCategory(database, name: 'Drinks');
  final int productId = await insertProduct(
    database,
    categoryId: categoryId,
    name: 'Coffee',
    priceMinor: 450,
  );
  final User cashier = User(
    id: cashierId,
    name: 'Cashier',
    pin: null,
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime.now(),
  );
  final ShiftRepository shiftRepository = ShiftRepository(database);
  final ShiftSessionService shiftSessionService = ShiftSessionService(
    shiftRepository,
  );
  final OrderService orderService = OrderService(
    shiftSessionService: shiftSessionService,
    transactionRepository: TransactionRepository(database),
    transactionStateRepository: TransactionStateRepository(database),
    paymentRepository: PaymentRepository(database),
    printJobRepository: PrintJobRepository(database),
  );

  return _CheckoutFixture(
    productId: productId,
    cashier: cashier,
    shiftSessionService: shiftSessionService,
    orderService: orderService,
  );
}

class _CheckoutFixture {
  const _CheckoutFixture({
    required this.productId,
    required this.cashier,
    required this.shiftSessionService,
    required this.orderService,
  });

  final int productId;
  final User cashier;
  final ShiftSessionService shiftSessionService;
  final OrderService orderService;
}

class _TcpCaptureServer {
  _TcpCaptureServer._(this._server) {
    unawaited(
      _server.listen((Socket client) {
        _connectionCount += 1;
        client.listen(
          (_) {},
          onDone: () => client.destroy(),
          onError: (_, __) => client.destroy(),
          cancelOnError: true,
        );
      }).asFuture<void>(),
    );
  }

  final ServerSocket _server;
  int _connectionCount = 0;

  int get connectionCount => _connectionCount;

  int get port => _server.port;

  static Future<_TcpCaptureServer> start() async {
    final ServerSocket server = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    return _TcpCaptureServer._(server);
  }

  Future<void> close() => _server.close();
}
