import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/sync_queue_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/data/sync/phase1_sync_contract.dart';
import 'package:epos_app/data/sync/sync_payload_repository.dart';
import 'package:epos_app/data/sync/sync_transaction_graph.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Phase 1 payload contract', () {
    test(
      'paid transaction graph exposes required fields and UUID-only remote relationships',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _PayloadFixture fixture = await _createPaidFixture(
          db,
          withModifier: true,
        );
        final SyncTransactionGraph graph =
            await SyncPayloadRepository(
              db,
            ).buildTransactionGraph(fixture.transaction.uuid) ??
            (throw StateError('Expected a paid graph payload.'));

        final SyncGraphRecord transactionRecord = _recordFor(
          graph,
          'transactions',
        );
        expect(
          transactionRecord.payload.keys.toSet(),
          containsAll(<String>{
            'uuid',
            'shift_local_id',
            'user_local_id',
            'table_number',
            'status',
            'subtotal_minor',
            'modifier_total_minor',
            'total_amount_minor',
            'created_at',
            'paid_at',
            'updated_at',
            'cancelled_at',
            'cancelled_by_local_id',
            'kitchen_printed',
            'receipt_printed',
          }),
        );
        expect(transactionRecord.payload.containsKey('id'), isFalse);
        expect(transactionRecord.payload.containsKey('shift_id'), isFalse);
        expect(transactionRecord.payload.containsKey('user_id'), isFalse);

        final SyncGraphRecord lineRecord = _recordFor(
          graph,
          'transaction_lines',
        );
        expect(
          lineRecord.payload.keys.toSet(),
          containsAll(<String>{
            'uuid',
            'transaction_uuid',
            'product_local_id',
            'product_name',
            'unit_price_minor',
            'quantity',
            'line_total_minor',
          }),
        );
        expect(lineRecord.payload.containsKey('id'), isFalse);
        expect(lineRecord.payload.containsKey('transaction_id'), isFalse);
        expect(lineRecord.payload.containsKey('product_id'), isFalse);
        expect(
          lineRecord.payload['transaction_uuid'],
          fixture.transaction.uuid,
        );
        expect(
          Phase1SyncContract.isCanonicalUuid(
            lineRecord.payload['transaction_uuid']! as String,
          ),
          isTrue,
        );

        final SyncGraphRecord modifierRecord = _recordFor(
          graph,
          'order_modifiers',
        );
        expect(
          modifierRecord.payload.keys.toSet(),
          containsAll(<String>{
            'uuid',
            'transaction_line_uuid',
            'action',
            'item_name',
            'extra_price_minor',
          }),
        );
        expect(modifierRecord.payload.containsKey('id'), isFalse);
        expect(
          modifierRecord.payload.containsKey('transaction_line_id'),
          isFalse,
        );
        expect(
          modifierRecord.payload['transaction_line_uuid'],
          fixture.line.uuid,
        );

        final SyncGraphRecord paymentRecord = _recordFor(graph, 'payments');
        expect(
          paymentRecord.payload.keys.toSet(),
          containsAll(<String>{
            'uuid',
            'transaction_uuid',
            'method',
            'amount_minor',
            'paid_at',
          }),
        );
        expect(paymentRecord.payload.containsKey('id'), isFalse);
        expect(paymentRecord.payload.containsKey('transaction_id'), isFalse);
        expect(
          paymentRecord.payload['transaction_uuid'],
          fixture.transaction.uuid,
        );
      },
    );

    test(
      'cancelled transaction graph keeps cancelled metadata and omits payments',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _PayloadFixture fixture = await _createCancelledFixture(db);
        final SyncTransactionGraph graph =
            await SyncPayloadRepository(
              db,
            ).buildTransactionGraph(fixture.transaction.uuid) ??
            (throw StateError('Expected a cancelled graph payload.'));

        final SyncGraphRecord transactionRecord = _recordFor(
          graph,
          'transactions',
        );
        expect(transactionRecord.payload['status'], 'cancelled');
        expect(
          transactionRecord.payload['cancelled_by_local_id'],
          fixture.transaction.cancelledBy,
        );
        expect(
          graph.records.where(
            (SyncGraphRecord record) => record.tableName == 'payments',
          ),
          isEmpty,
        );
      },
    );
  });
}

class _PayloadFixture {
  const _PayloadFixture({required this.transaction, required this.line});

  final Transaction transaction;
  final TransactionLine line;
}

Future<_PayloadFixture> _createPaidFixture(
  AppDatabase db, {
  required bool withModifier,
}) async {
  final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
  final _FixtureContext fixture = await _createFixtureContext(
    db,
    syncQueueRepository: syncQueueRepository,
  );
  if (withModifier) {
    await fixture.orderService.addModifierToLine(
      transactionLineId: fixture.line.id,
      action: ModifierAction.add,
      itemName: 'Extra Shot',
      extraPriceMinor: 75,
    );
  }
  await fixture.orderService.sendOrder(
    transactionId: fixture.transaction.id,
    currentUser: fixture.cashierUser,
  );
  await fixture.orderService.markOrderPaid(
    transactionId: fixture.transaction.id,
    method: PaymentMethod.card,
    currentUser: fixture.cashierUser,
  );
  final Transaction paid =
      await fixture.transactionRepository.getById(fixture.transaction.id) ??
      (throw StateError('Expected paid transaction.'));
  return _PayloadFixture(transaction: paid, line: fixture.line);
}

Future<_PayloadFixture> _createCancelledFixture(AppDatabase db) async {
  final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
  final _FixtureContext fixture = await _createFixtureContext(
    db,
    syncQueueRepository: syncQueueRepository,
  );
  await fixture.orderService.sendOrder(
    transactionId: fixture.transaction.id,
    currentUser: fixture.cashierUser,
  );
  await fixture.orderService.cancelOrder(
    transactionId: fixture.transaction.id,
    currentUser: fixture.cashierUser,
  );
  final Transaction cancelled =
      await fixture.transactionRepository.getById(fixture.transaction.id) ??
      (throw StateError('Expected cancelled transaction.'));
  return _PayloadFixture(transaction: cancelled, line: fixture.line);
}

Future<_FixtureContext> _createFixtureContext(
  AppDatabase db, {
  required SyncQueueRepository syncQueueRepository,
}) async {
  final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: adminId);
  final int categoryId = await insertCategory(db, name: 'Coffee');
  final int productId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Latte',
    priceMinor: 450,
  );

  final User cashierUser = User(
    id: cashierId,
    name: 'Cashier',
    pin: null,
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime.now(),
  );
  final TransactionRepository transactionRepository = TransactionRepository(
    db,
    syncQueueRepository: syncQueueRepository,
  );
  final OrderService orderService = OrderService(
    shiftSessionService: ShiftSessionService(ShiftRepository(db)),
    transactionRepository: transactionRepository,
    transactionStateRepository: TransactionStateRepository(db),
    paymentRepository: PaymentRepository(db),
    syncQueueRepository: syncQueueRepository,
  );

  final Transaction transaction = await orderService.createOrder(
    currentUser: cashierUser,
  );
  final TransactionLine line = await orderService.addProductToOrder(
    transactionId: transaction.id,
    productId: productId,
  );

  return _FixtureContext(
    cashierUser: cashierUser,
    transaction: transaction,
    line: line,
    orderService: orderService,
    transactionRepository: transactionRepository,
  );
}

class _FixtureContext {
  const _FixtureContext({
    required this.cashierUser,
    required this.transaction,
    required this.line,
    required this.orderService,
    required this.transactionRepository,
  });

  final User cashierUser;
  final Transaction transaction;
  final TransactionLine line;
  final OrderService orderService;
  final TransactionRepository transactionRepository;
}

SyncGraphRecord _recordFor(SyncTransactionGraph graph, String tableName) {
  return graph.records.singleWhere(
    (SyncGraphRecord record) => record.tableName == tableName,
  );
}
