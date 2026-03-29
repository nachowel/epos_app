import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/repositories/audit_log_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/audit_log_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('OrderService', () {
    test(
      'open order summary uses order no, time flow, and short content',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int cashierId = await insertUser(
          db,
          name: 'Cashier',
          role: 'cashier',
        );
        final int shiftId = await insertShift(db, openedBy: cashierId);
        final int categoryId = await insertCategory(db, name: 'Breakfast');
        final int teaId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 200,
        );
        final int breakfastId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Breakfast',
          priceMinor: 700,
        );

        final service = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
        );

        final transactionRepository = TransactionRepository(db);
        final int orderId = await insertTransaction(
          db,
          uuid: 'open-order-summary',
          shiftId: shiftId,
          userId: cashierId,
          status: 'draft',
          totalAmountMinor: 1100,
        );
        await transactionRepository.addLine(
          transactionId: orderId,
          productId: teaId,
          quantity: 2,
        );
        await transactionRepository.addLine(
          transactionId: orderId,
          productId: breakfastId,
          quantity: 1,
        );

        final summaries = await service.getOrderSummariesByShift(shiftId);

        expect(summaries, hasLength(1));
        expect(summaries.single.transaction.id, orderId);
        expect(summaries.single.itemCount, 3);
        expect(summaries.single.shortContent, '2 Tea, 1 Breakfast');
      },
    );

    test('table number is nullable and can be updated later', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'table-number-order',
        shiftId: shiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 600,
      );

      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
      );

      await service.updateTableNumber(
        transactionId: transactionId,
        tableNumber: 12,
      );
      final withTable = await service.getOrderById(transactionId);

      await service.updateTableNumber(
        transactionId: transactionId,
        tableNumber: null,
      );
      final withoutTable = await service.getOrderById(transactionId);

      expect(withTable, isNotNull);
      expect(withTable!.tableNumber, 12);
      expect(withoutTable, isNotNull);
      expect(withoutTable!.tableNumber, isNull);
    });

    test('cashier can cancel only their own open orders', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int firstCashierId = await insertUser(
        db,
        name: 'Cashier One',
        role: 'cashier',
      );
      final int secondCashierId = await insertUser(
        db,
        name: 'Cashier Two',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: firstCashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'cashier-cancel',
        shiftId: shiftId,
        userId: firstCashierId,
        status: 'sent',
        totalAmountMinor: 600,
      );

      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
      );

      await expectLater(
        service.cancelOrder(
          transactionId: transactionId,
          currentUser: User(
            id: secondCashierId,
            name: 'Cashier Two',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<UnauthorisedException>()),
      );
    });

    test('transaction_cancelled audit log is written', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'cancel-audit',
        shiftId: shiftId,
        userId: adminId,
        status: 'sent',
        totalAmountMinor: 600,
      );
      final AuditLogRepository auditLogRepository = AuditLogRepository(db);
      final AuditLogService auditLogService = PersistedAuditLogService(
        auditLogRepository: auditLogRepository,
        logger: const NoopAppLogger(),
      );
      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
        auditLogService: auditLogService,
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

      await service.cancelOrder(
        transactionId: transactionId,
        currentUser: admin,
      );

      final logs = await auditLogRepository.listAuditLogsByEntity(
        entityType: 'transaction',
        entityId: 'cancel-audit',
      );

      expect(logs, hasLength(1));
      expect(logs.single.action, 'transaction_cancelled');
      expect(logs.single.actorUserId, adminId);
      expect(logs.single.metadata['transaction_id'], transactionId);
      expect(logs.single.metadata['shift_id'], shiftId);
    });

    test('modifier totals stay consistent with quantity', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Mains');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Burger',
        priceMinor: 500,
        hasModifiers: true,
      );

      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
        paymentRepository: PaymentRepository(db),
      );
      final user = User(
        id: cashierId,
        name: 'Cashier',
        pin: null,
        password: null,
        role: UserRole.cashier,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final order = await service.createOrder(currentUser: user);
      final line = await service.addProductToOrder(
        transactionId: order.id,
        productId: productId,
        quantity: 2,
      );
      await service.addModifierToLine(
        transactionLineId: line.id,
        action: ModifierAction.add,
        itemName: 'Cheese',
        extraPriceMinor: 150,
      );

      final refreshed = await service.getOrderById(order.id);
      final lines = await service.getOrderLines(order.id);

      expect(refreshed, isNotNull);
      expect(refreshed!.subtotalMinor, 1000);
      expect(refreshed.modifierTotalMinor, 300);
      expect(refreshed.totalAmountMinor, 1300);
      expect(lines.single.lineTotalMinor, 1300);
    });

    test('Hidden product cannot be added to new order', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Snacks');
      final int hiddenProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Hidden Cookie',
        priceMinor: 300,
        isVisibleOnPos: false,
      );
      final int inactiveProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Inactive Cookie',
        priceMinor: 320,
        isActive: false,
      );

      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
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
      final order = await service.createOrder(currentUser: cashier);

      await expectLater(
        service.addProductToOrder(
          transactionId: order.id,
          productId: hiddenProductId,
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Product is not available for sale.',
          ),
        ),
      );
      await expectLater(
        service.addProductToOrder(
          transactionId: order.id,
          productId: inactiveProductId,
        ),
        throwsA(
          isA<ValidationException>().having(
            (ValidationException error) => error.message,
            'message',
            'Product is not available for sale.',
          ),
        ),
      );

      expect(await service.getOrderLines(order.id), isEmpty);
    });

    test(
      'state transitions flow through OrderService while repository no longer exposes state mutators',
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
          name: 'Tea',
          priceMinor: 250,
        );

        final transactionRepository = TransactionRepository(db);
        final service = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: transactionRepository,
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
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

        final dynamic repositoryAsDynamic = transactionRepository;

        expect(
          () => repositoryAsDynamic.markTransactionPaid(
            transactionId: 1,
            paidAt: DateTime.now(),
          ),
          throwsA(isA<NoSuchMethodError>()),
        );
        expect(
          () => repositoryAsDynamic.markTransactionCancelled(
            transactionId: 1,
            cancelledByUserId: cashierId,
          ),
          throwsA(isA<NoSuchMethodError>()),
        );

        final paidOrder = await service.createOrder(currentUser: cashier);
        await service.addProductToOrder(
          transactionId: paidOrder.id,
          productId: productId,
        );
        await service.sendOrder(
          transactionId: paidOrder.id,
          currentUser: cashier,
        );
        await service.markOrderPaid(
          transactionId: paidOrder.id,
          method: PaymentMethod.cash,
          currentUser: cashier,
        );

        final persistedPaid = await transactionRepository.getById(paidOrder.id);
        final payment = await PaymentRepository(
          db,
        ).getByTransactionId(paidOrder.id);

        expect(persistedPaid, isNotNull);
        expect(persistedPaid!.shiftId, shiftId);
        expect(persistedPaid.status, TransactionStatus.paid);
        expect(payment, isNotNull);
        expect(payment!.amountMinor, persistedPaid.totalAmountMinor);
        await expectLater(
          service.cancelOrder(
            transactionId: paidOrder.id,
            currentUser: cashier,
          ),
          throwsA(isA<InvalidStateTransitionException>()),
        );

        final cancellableOrder = await service.createOrder(
          currentUser: cashier,
        );
        await service.addProductToOrder(
          transactionId: cancellableOrder.id,
          productId: productId,
        );
        await service.sendOrder(
          transactionId: cancellableOrder.id,
          currentUser: cashier,
        );
        await service.cancelOrder(
          transactionId: cancellableOrder.id,
          currentUser: cashier,
        );

        final cancelled = await transactionRepository.getById(
          cancellableOrder.id,
        );
        expect(cancelled, isNotNull);
        expect(cancelled!.status, TransactionStatus.cancelled);
        expect(cancelled.cancelledBy, cashierId);
      },
    );

    test('draft can be discarded without becoming a cancelled sale', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Dessert');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Cake',
        priceMinor: 450,
      );

      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
        paymentRepository: PaymentRepository(db),
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

      final draft = await service.createOrder(currentUser: cashier);
      await service.addProductToOrder(
        transactionId: draft.id,
        productId: productId,
      );

      await service.discardDraft(transactionId: draft.id, currentUser: cashier);

      expect(await TransactionRepository(db).getById(draft.id), isNull);
      expect(
        await TransactionRepository(
          db,
        ).getByShiftAndStatus(1, TransactionStatus.cancelled),
        isEmpty,
      );
    });

    test(
      'sent, paid, and cancelled orders cannot be discarded as drafts',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final service = OrderService(
          shiftSessionService: ShiftSessionService(ShiftRepository(db)),
          transactionRepository: TransactionRepository(db),
          transactionStateRepository: TransactionStateRepository(db),
          paymentRepository: PaymentRepository(db),
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

        final int sentId = await insertTransaction(
          db,
          uuid: 'sent-discard-invalid',
          shiftId: shiftId,
          userId: adminId,
          status: 'sent',
          totalAmountMinor: 500,
        );
        final int paidId = await insertTransaction(
          db,
          uuid: 'paid-discard-invalid',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 600,
          paidAt: DateTime.now(),
        );
        final int cancelledId = await insertTransaction(
          db,
          uuid: 'cancelled-discard-invalid',
          shiftId: shiftId,
          userId: adminId,
          status: 'cancelled',
          totalAmountMinor: 700,
          cancelledAt: DateTime.now(),
          cancelledBy: adminId,
        );

        await expectLater(
          service.discardDraft(transactionId: sentId, currentUser: admin),
          throwsA(isA<InvalidStateTransitionException>()),
        );
        await expectLater(
          service.discardDraft(transactionId: paidId, currentUser: admin),
          throwsA(isA<InvalidStateTransitionException>()),
        );
        await expectLater(
          service.discardDraft(transactionId: cancelledId, currentUser: admin),
          throwsA(isA<InvalidStateTransitionException>()),
        );
      },
    );

    test('cashier can discard only their own draft orders', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int firstCashierId = await insertUser(
        db,
        name: 'Cashier One',
        role: 'cashier',
      );
      final int secondCashierId = await insertUser(
        db,
        name: 'Cashier Two',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: firstCashierId);
      final int draftId = await insertTransaction(
        db,
        uuid: 'foreign-draft-discard',
        shiftId: shiftId,
        userId: firstCashierId,
        status: 'draft',
        totalAmountMinor: 0,
      );

      final service = OrderService(
        shiftSessionService: ShiftSessionService(ShiftRepository(db)),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
      );

      await expectLater(
        service.discardDraft(
          transactionId: draftId,
          currentUser: User(
            id: secondCashierId,
            name: 'Cashier Two',
            pin: null,
            password: null,
            role: UserRole.cashier,
            isActive: true,
            createdAt: DateTime.now(),
          ),
        ),
        throwsA(isA<UnauthorisedException>()),
      );
    });
  });
}
