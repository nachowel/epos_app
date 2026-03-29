import 'dart:io';
import 'dart:ui';

import 'package:drift/drift.dart' show Variable;
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/data/database/app_database.dart' as db;
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
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/checkout_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/payment_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/test_database.dart';

void main() {
  setUp(() {
    AppLocalizationService.instance.setLocale(const Locale('en'));
  });

  group('Production resilience hardening', () {
    test(
      'payment retry after transactional failure does not create duplicates',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final _OrderFixture fixture = await _createSentOrderFixture(database);
        final PaymentRepository paymentRepository = PaymentRepository(database);
        final TransactionRepository transactionRepository =
            TransactionRepository(database);

        final OrderService flakyOrderService = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(database)),
          transactionRepository: transactionRepository,
          transactionStateRepository: _FailingOnceTransactionStateRepository(
            database,
          ),
          paymentRepository: paymentRepository,
          printJobRepository: PrintJobRepository(database),
        );

        await expectLater(
          flakyOrderService.markOrderPaid(
            transactionId: fixture.transactionId,
            method: PaymentMethod.card,
            currentUser: fixture.cashier,
          ),
          throwsA(isA<DatabaseException>()),
        );

        expect(
          await paymentRepository.getByTransactionId(fixture.transactionId),
          isNull,
        );
        expect(
          (await transactionRepository.getById(fixture.transactionId))!.status,
          TransactionStatus.sent,
        );

        final OrderService recoveredOrderService = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(database)),
          transactionRepository: transactionRepository,
          transactionStateRepository: TransactionStateRepository(database),
          paymentRepository: paymentRepository,
          printJobRepository: PrintJobRepository(database),
        );

        await recoveredOrderService.markOrderPaid(
          transactionId: fixture.transactionId,
          method: PaymentMethod.card,
          currentUser: fixture.cashier,
        );

        final Payment? payment = await paymentRepository.getByTransactionId(
          fixture.transactionId,
        );
        expect(payment, isNotNull);
        expect(
          (await transactionRepository.getById(fixture.transactionId))!.status,
          TransactionStatus.paid,
        );
      },
    );

    test(
      'concurrent payment submits cannot create duplicate payment rows',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final _OrderFixture fixture = await _createSentOrderFixture(
          database,
          uuidPrefix: 'concurrent-pay',
        );
        final PaymentRepository paymentRepository = PaymentRepository(database);

        final List<Object?> results =
            await Future.wait<Object?>(<Future<Object?>>[
              () async {
                try {
                  return await paymentRepository.createPayment(
                    transactionId: fixture.transactionId,
                    uuid: 'concurrent-payment-a',
                    method: PaymentMethod.card,
                    amountMinor: 450,
                  );
                } catch (error) {
                  return error;
                }
              }(),
              () async {
                try {
                  return await paymentRepository.createPayment(
                    transactionId: fixture.transactionId,
                    uuid: 'concurrent-payment-b',
                    method: PaymentMethod.card,
                    amountMinor: 450,
                  );
                } catch (error) {
                  return error;
                }
              }(),
            ]);

        final int paymentCount = await database
            .customSelect(
              'SELECT COUNT(*) AS payment_count FROM payments WHERE transaction_id = ?',
              variables: <Variable<Object>>[
                Variable<int>(fixture.transactionId),
              ],
            )
            .getSingle()
            .then((row) => row.read<int>('payment_count'));

        expect(results.whereType<Payment>().length, 1);
        expect(results.whereType<DuplicatePaymentException>().length, 1);
        expect(paymentCount, 1);
      },
    );

    test(
      'db payment uniqueness violation maps cleanly to duplicate payment',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final _OrderFixture fixture = await _createSentOrderFixture(
          database,
          uuidPrefix: 'duplicate-pay',
        );
        final PaymentRepository paymentRepository = PaymentRepository(database);

        await paymentRepository.createPayment(
          transactionId: fixture.transactionId,
          uuid: 'duplicate-payment-first',
          method: PaymentMethod.cash,
          amountMinor: 450,
        );

        await expectLater(
          paymentRepository.createPayment(
            transactionId: fixture.transactionId,
            uuid: 'duplicate-payment-second',
            method: PaymentMethod.cash,
            amountMinor: 450,
          ),
          throwsA(isA<DuplicatePaymentException>()),
        );
      },
    );

    test('paid and cancelled orders cannot be paid again', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);
      final _OrderFixture paidFixture = await _createPaidOrderFixture(database);
      final _OrderFixture cancelledFixture = await _createSentOrderFixture(
        database,
        uuidPrefix: 'cancel-target',
      );

      final OrderService orderService = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(database)),
        transactionRepository: TransactionRepository(database),
        transactionStateRepository: TransactionStateRepository(database),
        paymentRepository: PaymentRepository(database),
        printJobRepository: PrintJobRepository(database),
      );
      await orderService.cancelOrder(
        transactionId: cancelledFixture.transactionId,
        currentUser: cancelledFixture.cashier,
      );

      await expectLater(
        orderService.markOrderPaid(
          transactionId: paidFixture.transactionId,
          method: PaymentMethod.cash,
          currentUser: paidFixture.cashier,
        ),
        throwsA(
          isA<OrderPaymentBlockedException>().having(
            (OrderPaymentBlockedException error) => error.reason,
            'reason',
            PaymentBlockReason.alreadyPaid,
          ),
        ),
      );

      await expectLater(
        orderService.markOrderPaid(
          transactionId: cancelledFixture.transactionId,
          method: PaymentMethod.cash,
          currentUser: cancelledFixture.cashier,
        ),
        throwsA(
          isA<OrderPaymentBlockedException>().having(
            (OrderPaymentBlockedException error) => error.reason,
            'reason',
            PaymentBlockReason.cancelled,
          ),
        ),
      );
    });

    test(
      'failed receipt print is retryable without duplicating payment state',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final _CheckoutFixture fixture = await _createCheckoutFixture(database);
        final _DeterministicPrinterService printerService =
            _DeterministicPrinterService(
              transactionRepository: fixture.transactionRepository,
              printJobRepository: fixture.printJobRepository,
              failReceiptAttempts: 1,
            );

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
          idempotencyKey: 'checkout-print-retry',
          immediatePaymentMethod: PaymentMethod.card,
        );

        final Payment? paymentBeforeRetry = await fixture.paymentRepository
            .getByTransactionId(transaction.id);
        final PrintJob receiptJobBeforeRetry = (await fixture.printJobRepository
            .getByTransactionIdAndTarget(
              transactionId: transaction.id,
              target: PrintJobTarget.receipt,
            ))!;

        expect(paymentBeforeRetry, isNotNull);
        expect(
          (await fixture.transactionRepository.getById(transaction.id))!.status,
          TransactionStatus.paid,
        );
        expect(receiptJobBeforeRetry.status, PrintJobStatus.failed);

        await printerService.printReceipt(transaction.id, allowReprint: true);

        final Payment? paymentAfterRetry = await fixture.paymentRepository
            .getByTransactionId(transaction.id);
        final PrintJob receiptJobAfterRetry = (await fixture.printJobRepository
            .getByTransactionIdAndTarget(
              transactionId: transaction.id,
              target: PrintJobTarget.receipt,
            ))!;

        expect(paymentAfterRetry, isNotNull);
        expect(paymentAfterRetry!.uuid, paymentBeforeRetry!.uuid);
        expect(
          (await fixture.transactionRepository.getById(
            transaction.id,
          ))!.receiptPrinted,
          isTrue,
        );
        expect(receiptJobAfterRetry.status, PrintJobStatus.printed);
        expect(receiptJobAfterRetry.attemptCount, 2);
      },
    );

    test(
      'restart after sent order preserves pending kitchen print state',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos-recovery-sent',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final String dbPath = p.join(tempDir.path, 'epos.sqlite');

        final db.AppDatabase initialDb = createPersistentTestDatabase(dbPath);
        final _OrderFixture fixture = await _createSentOrderFixture(
          initialDb,
          uuidPrefix: 'restart-sent',
        );
        expect(
          (await PrintJobRepository(initialDb).getByTransactionIdAndTarget(
            transactionId: fixture.transactionId,
            target: PrintJobTarget.kitchen,
          ))!.status,
          PrintJobStatus.pending,
        );
        await initialDb.close();

        final db.AppDatabase reopenedDb = createPersistentTestDatabase(dbPath);
        addTearDown(reopenedDb.close);
        final Transaction? reopenedTransaction = await TransactionRepository(
          reopenedDb,
        ).getById(fixture.transactionId);
        final PrintJob? reopenedJob = await PrintJobRepository(reopenedDb)
            .getByTransactionIdAndTarget(
              transactionId: fixture.transactionId,
              target: PrintJobTarget.kitchen,
            );

        expect(reopenedTransaction, isNotNull);
        expect(reopenedTransaction!.status, TransactionStatus.sent);
        expect(reopenedJob, isNotNull);
        expect(reopenedJob!.status, PrintJobStatus.pending);
      },
    );

    test(
      'restart after persisted payment reflects paid state and pending receipt print',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos-recovery-paid',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final String dbPath = p.join(tempDir.path, 'epos.sqlite');

        final db.AppDatabase initialDb = createPersistentTestDatabase(dbPath);
        final _OrderFixture fixture = await _createSentOrderFixture(
          initialDb,
          uuidPrefix: 'restart-paid',
        );
        final OrderService orderService = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(initialDb)),
          transactionRepository: TransactionRepository(initialDb),
          transactionStateRepository: TransactionStateRepository(initialDb),
          paymentRepository: PaymentRepository(initialDb),
          printJobRepository: PrintJobRepository(initialDb),
        );
        await orderService.markOrderPaid(
          transactionId: fixture.transactionId,
          method: PaymentMethod.card,
          currentUser: fixture.cashier,
        );
        await initialDb.close();

        final db.AppDatabase reopenedDb = createPersistentTestDatabase(dbPath);
        addTearDown(reopenedDb.close);

        final Transaction? reopenedTransaction = await TransactionRepository(
          reopenedDb,
        ).getById(fixture.transactionId);
        final Payment? reopenedPayment = await PaymentRepository(
          reopenedDb,
        ).getByTransactionId(fixture.transactionId);
        final PrintJob? reopenedReceiptJob =
            await PrintJobRepository(reopenedDb).getByTransactionIdAndTarget(
              transactionId: fixture.transactionId,
              target: PrintJobTarget.receipt,
            );

        expect(reopenedTransaction, isNotNull);
        expect(reopenedTransaction!.status, TransactionStatus.paid);
        expect(reopenedPayment, isNotNull);
        expect(reopenedReceiptJob, isNotNull);
        expect(reopenedReceiptJob!.status, PrintJobStatus.pending);
      },
    );

    test(
      'end-to-end day flow stays consistent across print failure and retry',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);
        final _CheckoutFixture fixture = await _createCheckoutFixture(database);
        final _DeterministicPrinterService printerService =
            _DeterministicPrinterService(
              transactionRepository: fixture.transactionRepository,
              printJobRepository: fixture.printJobRepository,
              failReceiptAttempts: 1,
            );
        final CheckoutService checkoutService = CheckoutService(
          shiftSessionService: fixture.shiftSessionService,
          orderService: fixture.orderService,
          printerService: printerService,
        );
        final PaymentService paymentService = PaymentService(
          orderService: fixture.orderService,
          printerService: printerService,
        );
        final ReportService reportService = ReportService(
          shiftRepository: fixture.shiftRepository,
          shiftSessionService: fixture.shiftSessionService,
          transactionRepository: fixture.transactionRepository,
          paymentRepository: fixture.paymentRepository,
          settingsRepository: SettingsRepository(database),
          reportVisibilityService: const ReportVisibilityService(),
        );

        final Transaction paidOrder = await checkoutService.checkoutCart(
          currentUser: fixture.cashier,
          cartItems: <CheckoutItem>[
            CheckoutItem(
              productId: fixture.productId,
              quantity: 1,
              modifiers: const <CheckoutModifier>[],
            ),
          ],
          idempotencyKey: 'day-flow-paid',
          immediatePaymentMethod: PaymentMethod.card,
        );

        await printerService.printReceipt(paidOrder.id, allowReprint: true);

        final Transaction secondOrder = await fixture.orderService.createOrder(
          currentUser: fixture.cashier,
        );
        await fixture.orderService.addProductToOrder(
          transactionId: secondOrder.id,
          productId: fixture.productId,
        );
        await fixture.orderService.sendOrder(
          transactionId: secondOrder.id,
          currentUser: fixture.cashier,
        );
        await paymentService.payOrder(
          transactionId: secondOrder.id,
          method: PaymentMethod.cash,
          currentUser: fixture.cashier,
        );

        final User admin = User(
          id: fixture.adminId,
          name: 'Admin',
          pin: null,
          password: null,
          role: UserRole.admin,
          isActive: true,
          createdAt: DateTime.now(),
        );
        await reportService.takeCashierEndOfDayPreview(user: fixture.cashier);
        final int shiftId = fixture.shiftId;
        final int reportTotalBeforeClose = (await reportService.getShiftReport(
          shiftId,
        )).paidTotalMinor;
        await reportService.runAdminFinalCloseWithCountedCash(
          user: admin,
          countedCashMinor: 450,
        );

        expect(reportTotalBeforeClose, 900);
        expect(await fixture.shiftRepository.getOpenShift(), isNull);
        expect(
          (await fixture.transactionRepository.getById(paidOrder.id))!.status,
          TransactionStatus.paid,
        );
        expect(
          (await fixture.transactionRepository.getById(secondOrder.id))!.status,
          TransactionStatus.paid,
        );
        expect(
          (await fixture.printJobRepository.getByTransactionIdAndTarget(
            transactionId: paidOrder.id,
            target: PrintJobTarget.receipt,
          ))!.status,
          PrintJobStatus.printed,
        );
      },
    );
  });
}

class _FailingOnceTransactionStateRepository
    extends TransactionStateRepository {
  _FailingOnceTransactionStateRepository(super.database);

  bool _failed = false;

  @override
  Future<void> transitionSentOrderToPaid({
    required int transactionId,
    required DateTime paidAt,
  }) async {
    if (!_failed) {
      _failed = true;
      throw DatabaseException('Simulated transaction state failure.');
    }
    await super.transitionSentOrderToPaid(
      transactionId: transactionId,
      paidAt: paidAt,
    );
  }
}

class _DeterministicPrinterService extends PrinterService {
  _DeterministicPrinterService({
    required TransactionRepository transactionRepository,
    required PrintJobRepository printJobRepository,
    int failKitchenAttempts = 0,
    int failReceiptAttempts = 0,
  }) : _transactionRepository = transactionRepository,
       _printJobRepository = printJobRepository,
       _remainingKitchenFailures = failKitchenAttempts,
       _remainingReceiptFailures = failReceiptAttempts,
       super(transactionRepository, printJobRepository: printJobRepository);

  final TransactionRepository _transactionRepository;
  final PrintJobRepository _printJobRepository;
  int _remainingKitchenFailures;
  int _remainingReceiptFailures;

  @override
  Future<PrintJob> printKitchenTicket(
    int transactionId, {
    bool allowReprint = false,
  }) async {
    return _process(
      transactionId: transactionId,
      target: PrintJobTarget.kitchen,
      allowReprint: allowReprint,
      shouldFail: () => _consumeKitchenFailure(),
    );
  }

  @override
  Future<PrintJob> printReceipt(
    int transactionId, {
    bool allowReprint = false,
    int? actorUserId,
  }) async {
    return _process(
      transactionId: transactionId,
      target: PrintJobTarget.receipt,
      allowReprint: allowReprint,
      shouldFail: () => _consumeReceiptFailure(),
    );
  }

  Future<PrintJob> _process({
    required int transactionId,
    required PrintJobTarget target,
    required bool allowReprint,
    required bool Function() shouldFail,
  }) async {
    final PrintJob existing = await _printJobRepository.ensureQueued(
      transactionId: transactionId,
      target: target,
    );
    if (existing.isPrinted && !allowReprint) {
      return existing;
    }

    await _printJobRepository.markInProgress(
      transactionId: transactionId,
      target: target,
      allowReprint: allowReprint,
    );

    if (shouldFail()) {
      await _printJobRepository.markFailed(
        transactionId: transactionId,
        target: target,
        error: 'Simulated printer offline.',
      );
      throw PrinterException(
        'Simulated printer offline.',
        operatorMessage: target == PrintJobTarget.kitchen
            ? AppStrings.kitchenPrintRetryRequired
            : AppStrings.receiptPrintRetryRequired,
      );
    }

    await _transactionRepository.updatePrintFlag(
      transactionId: transactionId,
      kitchenPrinted: target == PrintJobTarget.kitchen ? true : null,
      receiptPrinted: target == PrintJobTarget.receipt ? true : null,
    );
    return _printJobRepository.markPrinted(
      transactionId: transactionId,
      target: target,
    );
  }

  bool _consumeKitchenFailure() {
    if (_remainingKitchenFailures <= 0) {
      return false;
    }
    _remainingKitchenFailures -= 1;
    return true;
  }

  bool _consumeReceiptFailure() {
    if (_remainingReceiptFailures <= 0) {
      return false;
    }
    _remainingReceiptFailures -= 1;
    return true;
  }
}

class _OrderFixture {
  const _OrderFixture({
    required this.adminId,
    required this.shiftId,
    required this.transactionId,
    required this.productId,
    required this.cashier,
  });

  final int adminId;
  final int shiftId;
  final int transactionId;
  final int productId;
  final User cashier;
}

class _CheckoutFixture {
  const _CheckoutFixture({
    required this.adminId,
    required this.shiftId,
    required this.productId,
    required this.cashier,
    required this.shiftRepository,
    required this.shiftSessionService,
    required this.transactionRepository,
    required this.paymentRepository,
    required this.printJobRepository,
    required this.orderService,
  });

  final int adminId;
  final int shiftId;
  final int productId;
  final User cashier;
  final ShiftRepository shiftRepository;
  final ShiftSessionService shiftSessionService;
  final TransactionRepository transactionRepository;
  final PaymentRepository paymentRepository;
  final PrintJobRepository printJobRepository;
  final OrderService orderService;
}

Future<_OrderFixture> _createSentOrderFixture(
  db.AppDatabase db, {
  String uuidPrefix = 'payment-resilience',
}) async {
  final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
  final int cashierId = await insertUser(
    db,
    name: 'Cashier $uuidPrefix',
    role: 'cashier',
  );
  final ShiftRepository shiftRepository = ShiftRepository(db);
  final int shiftId =
      (await shiftRepository.getOpenShift())?.id ??
      await insertShift(db, openedBy: cashierId);
  final int categoryId = await insertCategory(db, name: 'Meals');
  final int productId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Toastie',
    priceMinor: 450,
  );
  final User cashier = User(
    id: cashierId,
    name: 'Cashier $uuidPrefix',
    pin: null,
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime.now(),
  );
  final OrderService orderService = OrderService(
    shiftSessionService: ShiftSessionService(shiftRepository),
    transactionRepository: TransactionRepository(db),
    transactionStateRepository: TransactionStateRepository(db),
    paymentRepository: PaymentRepository(db),
    printJobRepository: PrintJobRepository(db),
  );
  final Transaction transaction = await orderService.createOrder(
    currentUser: cashier,
  );
  await orderService.addProductToOrder(
    transactionId: transaction.id,
    productId: productId,
  );
  await orderService.sendOrder(
    transactionId: transaction.id,
    currentUser: cashier,
  );
  return _OrderFixture(
    adminId: adminId,
    shiftId: shiftId,
    transactionId: transaction.id,
    productId: productId,
    cashier: cashier,
  );
}

Future<_OrderFixture> _createPaidOrderFixture(db.AppDatabase db) async {
  final _OrderFixture fixture = await _createSentOrderFixture(
    db,
    uuidPrefix: 'paid-resilience',
  );
  final OrderService orderService = OrderService(
    shiftSessionService: ShiftSessionService(ShiftRepository(db)),
    transactionRepository: TransactionRepository(db),
    transactionStateRepository: TransactionStateRepository(db),
    paymentRepository: PaymentRepository(db),
    printJobRepository: PrintJobRepository(db),
  );
  await orderService.markOrderPaid(
    transactionId: fixture.transactionId,
    method: PaymentMethod.card,
    currentUser: fixture.cashier,
  );
  return fixture;
}

Future<_CheckoutFixture> _createCheckoutFixture(db.AppDatabase db) async {
  final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int shiftId = await insertShift(db, openedBy: cashierId);
  final int categoryId = await insertCategory(db, name: 'Drinks');
  final int productId = await insertProduct(
    db,
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
  final ShiftRepository shiftRepository = ShiftRepository(db);
  final ShiftSessionService shiftSessionService = ShiftSessionService(
    shiftRepository,
  );
  final TransactionRepository transactionRepository = TransactionRepository(db);
  final PaymentRepository paymentRepository = PaymentRepository(db);
  final PrintJobRepository printJobRepository = PrintJobRepository(db);
  final OrderService orderService = OrderService(
    shiftSessionService: shiftSessionService,
    transactionRepository: transactionRepository,
    transactionStateRepository: TransactionStateRepository(db),
    paymentRepository: paymentRepository,
    printJobRepository: printJobRepository,
  );

  return _CheckoutFixture(
    adminId: adminId,
    shiftId: shiftId,
    productId: productId,
    cashier: cashier,
    shiftRepository: shiftRepository,
    shiftSessionService: shiftSessionService,
    transactionRepository: transactionRepository,
    paymentRepository: paymentRepository,
    printJobRepository: printJobRepository,
    orderService: orderService,
  );
}
