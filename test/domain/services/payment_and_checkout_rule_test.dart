import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/print_job_repository.dart';
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
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Shift and payment rules', () {
    test(
      'OPEN order payment succeeds when the matching shift is active',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int userId = await insertUser(db, name: 'Admin', role: 'admin');
        final int openShiftId = await insertShift(db, openedBy: userId);
        final int categoryId = await insertCategory(db, name: 'Food');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Breakfast',
          priceMinor: 850,
        );
        final int transactionId = await insertTransaction(
          db,
          uuid: 'tx-open-shift',
          shiftId: openShiftId,
          userId: userId,
          status: 'draft',
          totalAmountMinor: 850,
        );
        await TransactionRepository(db).addLine(
          transactionId: transactionId,
          productId: productId,
          quantity: 1,
        );

        final shiftSessionService = ShiftSessionService(ShiftRepository(db));
        final orderService = OrderService(
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
        );
        await orderService.sendOrder(
          transactionId: transactionId,
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
        final paymentService = PaymentService(
          paymentRepository: PaymentRepository(db),
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          printerService: PrinterService(TransactionRepository(db)),
        );

        final Payment payment = await paymentService.payOrder(
          transactionId: transactionId,
          method: PaymentMethod.cash,
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
        final updatedTransaction = await TransactionRepository(
          db,
        ).getById(transactionId);

        expect(payment.amountMinor, 850);
        expect(updatedTransaction, isNotNull);
        expect(updatedTransaction!.status.name, 'paid');
        expect(
          await PrintJobRepository(db).getByTransactionIdAndTarget(
            transactionId: transactionId,
            target: PrintJobTarget.receipt,
          ),
          isNull,
        );
      },
    );

    test(
      'previous preview-locked shift does not block payment on current open shift',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int previousShiftId = await insertShift(
          db,
          openedBy: cashierId,
          status: 'closed',
          closedBy: cashierId,
          closedAt: DateTime.now(),
          cashierPreviewedBy: cashierId,
          cashierPreviewedAt: DateTime.now(),
        );
        final int currentShiftId = await insertShift(db, openedBy: cashierId);
        final int categoryId = await insertCategory(db, name: 'Food');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Soup',
          priceMinor: 950,
        );
        final int transactionId = await insertTransaction(
          db,
          uuid: 'tx-current-open-shift',
          shiftId: currentShiftId,
          userId: cashierId,
          status: 'draft',
          totalAmountMinor: 950,
        );
        await TransactionRepository(db).addLine(
          transactionId: transactionId,
          productId: productId,
          quantity: 1,
        );

        expect(previousShiftId, isNot(currentShiftId));

        final shiftSessionService = ShiftSessionService(ShiftRepository(db));
        await OrderService(
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
        ).sendOrder(
          transactionId: transactionId,
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

        final paymentService = PaymentService(
          paymentRepository: PaymentRepository(db),
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          printerService: PrinterService(TransactionRepository(db)),
        );

        final Payment payment = await paymentService.payOrder(
          transactionId: transactionId,
          method: PaymentMethod.card,
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
        final Transaction? updatedTransaction = await TransactionRepository(
          db,
        ).getById(transactionId);

        expect(payment.amountMinor, 950);
        expect(updatedTransaction, isNotNull);
        expect(updatedTransaction!.status, TransactionStatus.paid);
      },
    );

    test(
      'OPEN order payment is rejected when there is no active shift',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int userId = await insertUser(db, name: 'Admin', role: 'admin');
        final int closedShiftId = await insertShift(
          db,
          openedBy: userId,
          status: 'closed',
          closedBy: userId,
          closedAt: DateTime.now(),
        );
        final int transactionId = await insertTransaction(
          db,
          uuid: 'tx-closed-shift',
          shiftId: closedShiftId,
          userId: userId,
          status: 'sent',
          totalAmountMinor: 850,
        );

        final paymentService = PaymentService(
          paymentRepository: PaymentRepository(db),
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          printerService: PrinterService(TransactionRepository(db)),
        );

        await expectLater(
          paymentService.payOrder(
            transactionId: transactionId,
            method: PaymentMethod.cash,
            currentUser: User(
              id: userId,
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
      },
    );

    test(
      'checkout still requires an active shift for new order creation',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int userId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int categoryId = await insertCategory(db, name: 'Drinks');
        final int productId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 200,
        );

        final shiftSessionService = ShiftSessionService(ShiftRepository(db));
        final checkoutService = CheckoutService(
          database: db,
          shiftSessionService: shiftSessionService,
          orderService: OrderService(
            shiftSessionService: shiftSessionService,
            transactionRepository: TransactionRepository(db),
            transactionStateRepository: TransactionStateRepository(db),
          ),
          transactionRepository: TransactionRepository(db),
          printerService: PrinterService(TransactionRepository(db)),
        );

        expect(
          () => checkoutService.checkoutCart(
            currentUser: User(
              id: userId,
              name: 'Cashier',
              pin: null,
              password: null,
              role: UserRole.cashier,
              isActive: true,
              createdAt: DateTime.now(),
            ),
            cartItems: <CheckoutItem>[
              CheckoutItem(
                productId: productId,
                quantity: 1,
                modifiers: const [],
              ),
            ],
            idempotencyKey: 'checkout-no-shift',
          ),
          throwsA(isA<ShiftNotActiveException>()),
        );
      },
    );

    test('empty cart checkout does not persist a transaction', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int userId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: userId);

      final shiftSessionService = ShiftSessionService(ShiftRepository(db));
      final checkoutService = CheckoutService(
        database: db,
        shiftSessionService: shiftSessionService,
        orderService: OrderService(
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
        ),
        transactionRepository: TransactionRepository(db),
        printerService: PrinterService(TransactionRepository(db)),
      );

      await expectLater(
        checkoutService.checkoutCart(
          currentUser: User(
            id: userId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          cartItems: const <CheckoutItem>[],
          idempotencyKey: 'empty-cart-no-tx',
        ),
        throwsA(isA<EmptyCartException>()),
      );

      expect(await _countRows(db, 'transactions'), 0);
      expect(await _countRows(db, 'transaction_lines'), 0);
    });

    test('old createOrder production path is rejected and persists nothing', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int userId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: userId);

      final OrderService orderService = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
      );

      await expectLater(
        orderService.createOrder(
          currentUser: User(
            id: userId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _countRows(db, 'transactions'), 0);
      expect(await _countRows(db, 'transaction_lines'), 0);
    });

    test('test-only empty draft helper is blocked without testing access', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int userId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: userId);

      final OrderService orderService = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
      );

      await expectLater(
        orderService.createPersistedEmptyDraftForTesting(
          currentUser: User(
            id: userId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(await _countRows(db, 'transactions'), 0);
    });

    test('first successful checkout item creates transaction, line, and totals atomically', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Drinks');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Latte',
        priceMinor: 350,
      );

      final shiftSessionService = ShiftSessionService(ShiftRepository(db));
      final TransactionRepository transactionRepository = TransactionRepository(
        db,
      );
      final checkoutService = CheckoutService(
        database: db,
        shiftSessionService: shiftSessionService,
        orderService: OrderService(
          shiftSessionService: shiftSessionService,
          transactionRepository: transactionRepository,
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
        ),
        transactionRepository: transactionRepository,
        printerService: PrinterService(transactionRepository),
      );

      final Transaction transaction = await checkoutService.checkoutCart(
        currentUser: User(
          id: cashierId,
          name: 'Cashier',
          pin: null,
          password: null,
          role: UserRole.cashier,
          isActive: true,
          createdAt: DateTime.now(),
        ),
        cartItems: <CheckoutItem>[
          CheckoutItem(
            productId: productId,
            quantity: 1,
            modifiers: const <CheckoutModifier>[],
          ),
        ],
        idempotencyKey: 'first-item-atomic',
      );

      final Transaction? persisted = await transactionRepository.getById(
        transaction.id,
      );

      expect(await _countRows(db, 'transactions'), 1);
      expect(await _countRows(db, 'transaction_lines'), 1);
      expect(persisted, isNotNull);
      expect(persisted!.subtotalMinor, 350);
      expect(persisted.modifierTotalMinor, 0);
      expect(persisted.totalAmountMinor, 350);
      expect(persisted.status, TransactionStatus.sent);
    });

    test('failed first checkout item does not leave an abandoned empty draft', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);

      final shiftSessionService = ShiftSessionService(ShiftRepository(db));
      final checkoutService = CheckoutService(
        database: db,
        shiftSessionService: shiftSessionService,
        orderService: OrderService(
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
        ),
        transactionRepository: TransactionRepository(db),
        printerService: PrinterService(TransactionRepository(db)),
      );

      await expectLater(
        checkoutService.checkoutCart(
          currentUser: User(
            id: cashierId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          cartItems: <CheckoutItem>[
            const CheckoutItem(
              productId: 999999,
              quantity: 1,
              modifiers: <CheckoutModifier>[],
            ),
          ],
          idempotencyKey: 'invalid-first-item-no-draft',
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(await _countRows(db, 'transactions'), 0);
      expect(await _countRows(db, 'transaction_lines'), 0);
    });

    test('first item success plus later item failure rolls back the whole checkout', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Drinks');
      final int validProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Coffee',
        priceMinor: 300,
      );

      final shiftSessionService = ShiftSessionService(ShiftRepository(db));
      final checkoutService = CheckoutService(
        database: db,
        shiftSessionService: shiftSessionService,
        orderService: OrderService(
          shiftSessionService: shiftSessionService,
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
        ),
        transactionRepository: TransactionRepository(db),
        printerService: PrinterService(TransactionRepository(db)),
      );

      await expectLater(
        checkoutService.checkoutCart(
          currentUser: User(
            id: cashierId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          cartItems: <CheckoutItem>[
            CheckoutItem(
              productId: validProductId,
              quantity: 1,
              modifiers: const <CheckoutModifier>[],
            ),
            const CheckoutItem(
              productId: 999999,
              quantity: 1,
              modifiers: <CheckoutModifier>[],
            ),
          ],
          idempotencyKey: 'later-item-failure-rollback',
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(await _countRows(db, 'transactions'), 0);
      expect(await _countRows(db, 'transaction_lines'), 0);
    });

    test('PAID and OPEN orders can coexist in the same active shift', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      await insertTransaction(
        db,
        uuid: 'tx-open',
        shiftId: shiftId,
        userId: adminId,
        status: 'sent',
        totalAmountMinor: 500,
      );
      await insertTransaction(
        db,
        uuid: 'tx-paid',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 700,
      );

      final transactionRepository = TransactionRepository(db);

      final sentOrders = await transactionRepository.getByShiftAndStatus(
        shiftId,
        TransactionStatus.sent,
      );
      final paidOrders = await transactionRepository.getByShiftAndStatus(
        shiftId,
        TransactionStatus.paid,
      );

      expect(sentOrders, hasLength(1));
      expect(paidOrders, hasLength(1));
    });

    test(
      'pay now orchestration inserts payment and marks order paid atomically',
      () async {
        final db = createTestDatabase();
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
          priceMinor: 350,
        );

        final shiftSessionService = ShiftSessionService(ShiftRepository(db));
        final transactionRepository = TransactionRepository(db);
        final paymentRepository = PaymentRepository(db);
        final checkoutService = CheckoutService(
          database: db,
          shiftSessionService: shiftSessionService,
          orderService: OrderService(
            shiftSessionService: shiftSessionService,
            transactionRepository: transactionRepository,
            transactionStateRepository: TransactionStateRepository(db),
            paymentRepository: paymentRepository,
          ),
          transactionRepository: transactionRepository,
          printerService: PrinterService(transactionRepository),
        );

        final transaction = await checkoutService.checkoutCart(
          currentUser: User(
            id: cashierId,
            name: 'Cashier',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          cartItems: <CheckoutItem>[
            CheckoutItem(
              productId: productId,
              quantity: 1,
              modifiers: const <CheckoutModifier>[],
            ),
          ],
          idempotencyKey: 'pay-now-flow',
          immediatePaymentMethod: PaymentMethod.card,
        );

        final persisted = await transactionRepository.getById(transaction.id);
        final payment = await paymentRepository.getByTransactionId(
          transaction.id,
        );
        final sentOrders = await transactionRepository.getByShiftAndStatus(
          shiftId,
          TransactionStatus.sent,
        );
        final paidOrders = await transactionRepository.getByShiftAndStatus(
          shiftId,
          TransactionStatus.paid,
        );

        expect(persisted, isNotNull);
        expect(persisted!.status, TransactionStatus.paid);
        expect(payment, isNotNull);
        expect(payment!.amountMinor, 350);
        expect(sentOrders, isEmpty);
        expect(
          paidOrders.map((Transaction tx) => tx.id),
          contains(transaction.id),
        );
      },
    );

    test('print failure does not change paid state or print flags', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Hot Drinks');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Flat White',
        priceMinor: 420,
      );

      final shiftSessionService = ShiftSessionService(ShiftRepository(db));
      final transactionRepository = TransactionRepository(db);
      final checkoutService = CheckoutService(
        database: db,
        shiftSessionService: shiftSessionService,
        orderService: OrderService(
          shiftSessionService: shiftSessionService,
          transactionRepository: transactionRepository,
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
        ),
        transactionRepository: transactionRepository,
        printerService: _FailingPrinterService(transactionRepository),
      );

      final transaction = await checkoutService.checkoutCart(
        currentUser: User(
          id: cashierId,
          name: 'Cashier',
          pin: null,
          password: null,
          role: UserRole.cashier,
          isActive: true,
          createdAt: DateTime.now(),
        ),
        cartItems: <CheckoutItem>[
          CheckoutItem(
            productId: productId,
            quantity: 1,
            modifiers: const <CheckoutModifier>[],
          ),
        ],
        idempotencyKey: 'print-failure-stability',
        immediatePaymentMethod: PaymentMethod.card,
      );

      final persisted = await transactionRepository.getById(transaction.id);

      expect(persisted, isNotNull);
      expect(persisted!.status, TransactionStatus.paid);
      expect(persisted.kitchenPrinted, isFalse);
      expect(persisted.receiptPrinted, isFalse);
    });
  });
}

Future<int> _countRows(AppDatabase db, String tableName) async {
  final row = await db.customSelect(
    'SELECT COUNT(*) AS cnt FROM $tableName',
  ).getSingle();
  return row.read<int>('cnt');
}

class _FailingPrinterService extends PrinterService {
  _FailingPrinterService(super.transactionRepository);

  @override
  Future<PrintJob> printKitchenTicket(
    int transactionId, {
    bool allowReprint = false,
    int? actorUserId,
  }) async {
    throw PrinterException('Kitchen printer offline');
  }

  @override
  Future<PrintJob> printReceipt(
    int transactionId, {
    bool allowReprint = false,
    int? actorUserId,
  }) async {
    throw PrinterException('Receipt printer offline');
  }
}
