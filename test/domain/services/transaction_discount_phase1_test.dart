import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/transaction_discount.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Phase-1 transaction discount', () {
    test('amount discount reduces total and persists raw/applied values', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DiscountFixture fixture = await _createFixture(db, priceMinor: 1000);
      final order = await fixture.service.createPersistedEmptyDraftForTestingAccess(currentUser: fixture.user);
      await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.productId,
      );

      final updated = await fixture.service.applyDiscountToDraft(
        transactionId: order.id,
        currentUser: fixture.user,
        discount: const TransactionDiscountInput(
          type: TransactionDiscountType.amount,
          valueMinor: 250,
        ),
      );

      expect(updated.discountType, TransactionDiscountType.amount);
      expect(updated.discountValueMinor, 250);
      expect(updated.discountAmountMinor, 250);
      expect(updated.totalAmountMinor, 750);
    });

    test('percent discount uses integer round-half-up', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DiscountFixture fixture = await _createFixture(db, priceMinor: 995);
      final order = await fixture.service.createPersistedEmptyDraftForTestingAccess(currentUser: fixture.user);
      await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.productId,
      );

      final updated = await fixture.service.applyDiscountToDraft(
        transactionId: order.id,
        currentUser: fixture.user,
        discount: const TransactionDiscountInput(
          type: TransactionDiscountType.percent,
          valueMinor: 10,
        ),
      );

      expect(updated.discountAmountMinor, 100);
      expect(updated.totalAmountMinor, 895);
    });

    test('discount never drives total below zero', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DiscountFixture fixture = await _createFixture(db, priceMinor: 900);
      final order = await fixture.service.createPersistedEmptyDraftForTestingAccess(currentUser: fixture.user);
      await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.productId,
      );

      final updated = await fixture.service.applyDiscountToDraft(
        transactionId: order.id,
        currentUser: fixture.user,
        discount: const TransactionDiscountInput(
          type: TransactionDiscountType.amount,
          valueMinor: 2000,
        ),
      );

      expect(updated.discountAmountMinor, 900);
      expect(updated.totalAmountMinor, 0);
    });

    test('discount cannot be changed outside draft', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DiscountFixture fixture = await _createFixture(db, priceMinor: 800);
      final int sentTransactionId = await insertTransaction(
        db,
        uuid: 'sent-discount-locked',
        shiftId: fixture.shiftId,
        userId: fixture.user.id,
        status: 'sent',
        totalAmountMinor: 800,
      );

      await expectLater(
        fixture.service.applyDiscountToDraft(
          transactionId: sentTransactionId,
          currentUser: fixture.user,
          discount: const TransactionDiscountInput(
            type: TransactionDiscountType.amount,
            valueMinor: 100,
          ),
        ),
        throwsA(isA<InvalidStateTransitionException>()),
      );
    });

    test('payment amount matches post-discount total', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DiscountFixture fixture = await _createFixture(db, priceMinor: 1000);
      final order = await fixture.service.createPersistedEmptyDraftForTestingAccess(currentUser: fixture.user);
      await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.productId,
      );
      await fixture.service.applyDiscountToDraft(
        transactionId: order.id,
        currentUser: fixture.user,
        discount: const TransactionDiscountInput(
          type: TransactionDiscountType.amount,
          valueMinor: 250,
        ),
      );
      await fixture.service.sendOrder(
        transactionId: order.id,
        currentUser: fixture.user,
      );

      final Payment payment = await fixture.service.markOrderPaid(
        transactionId: order.id,
        method: PaymentMethod.cash,
        currentUser: fixture.user,
      );
      final persisted = await fixture.transactionRepository.getById(order.id);

      expect(payment.amountMinor, 750);
      expect(persisted, isNotNull);
      expect(persisted!.totalAmountMinor, 750);
      expect(persisted.status.name, 'paid');
    });
  });
}

class _DiscountFixture {
  const _DiscountFixture({
    required this.user,
    required this.shiftId,
    required this.productId,
    required this.service,
    required this.transactionRepository,
  });

  final User user;
  final int shiftId;
  final int productId;
  final OrderService service;
  final TransactionRepository transactionRepository;
}

Future<_DiscountFixture> _createFixture(
  dynamic db, {
  required int priceMinor,
}) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int shiftId = await insertShift(db, openedBy: cashierId);
  final int categoryId = await insertCategory(db, name: 'Discount Test');
  final int productId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Item',
    priceMinor: priceMinor,
  );
  final User user = User(
    id: cashierId,
    name: 'Cashier',
    pin: null,
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime.now(),
  );
  final TransactionRepository transactionRepository = TransactionRepository(db);
  return _DiscountFixture(
    user: user,
    shiftId: shiftId,
    productId: productId,
    transactionRepository: transactionRepository,
    service: OrderService(
      shiftSessionService: ShiftSessionService(ShiftRepository(db)),
      transactionRepository: transactionRepository,
      transactionStateRepository: TransactionStateRepository(db),
      paymentRepository: PaymentRepository(db),
    ),
  );
}
