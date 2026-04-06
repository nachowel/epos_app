import 'package:drift/drift.dart' show QueryRow, Value, Variable;
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/sync_queue_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/data/sync/phase1_sync_contract.dart';
import 'package:epos_app/data/sync/sync_payload_repository.dart';
import 'package:epos_app/data/sync/sync_transaction_graph.dart';
import 'package:epos_app/domain/models/breakfast_line_edit.dart';
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
            'pricing_mode',
            'removal_discount_total_minor',
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
            'quantity',
            'item_product_id',
            'extra_price_minor',
            'charge_reason',
            'unit_price_minor',
            'price_effect_minor',
            'sort_key',
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
        expect(lineRecord.payload['pricing_mode'], 'standard');
        expect(lineRecord.payload['removal_discount_total_minor'], 0);
        expect(modifierRecord.payload['quantity'], 1);
        expect(modifierRecord.payload['item_product_id'], isNull);
        expect(modifierRecord.payload['charge_reason'], isNull);
        expect(modifierRecord.payload['unit_price_minor'], 75);
        expect(modifierRecord.payload['price_effect_minor'], 75);
        expect(modifierRecord.payload['sort_key'], 0);

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

    test(
      'true rebuilt breakfast snapshot payload preserves semantic fields, compatibility residue, and sync ordering',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastPayloadFixture fixture =
            await _createPaidBreakfastPayloadFixture(db);

        final SyncGraphRecord transactionRecord = _recordFor(
          fixture.graph,
          'transactions',
        );
        final SyncGraphRecord lineRecord = _recordFor(
          fixture.graph,
          'transaction_lines',
        );
        final List<SyncGraphRecord> modifierRecords = fixture.graph.records
            .where(
              (SyncGraphRecord record) => record.tableName == 'order_modifiers',
            )
            .toList(growable: false);

        expect(lineRecord.payload['pricing_mode'], 'set');
        expect(
          lineRecord.payload['removal_discount_total_minor'],
          fixture.line.removalDiscountTotalMinor,
        );
        expect(lineRecord.payload['removal_discount_total_minor'], 0);

        final SyncGraphRecord choiceRecord = modifierRecords.singleWhere(
          (SyncGraphRecord record) =>
              record.payload['charge_reason'] == 'included_choice',
        );
        expect(choiceRecord.payload['item_product_id'], fixture.toastProductId);
        expect(choiceRecord.payload['charge_reason'], 'included_choice');
        expect(choiceRecord.payload['unit_price_minor'], 100);
        expect(choiceRecord.payload['price_effect_minor'], 0);
        expect(choiceRecord.payload['sort_key'], isNonZero);
        expect(choiceRecord.payload.containsKey('extra_price_minor'), isTrue);
        expect(choiceRecord.payload['extra_price_minor'], 9999);

        expect(transactionRecord.payload['modifier_total_minor'], 0);
        expect(lineRecord.payload['line_total_minor'], 400);
        expect(
          choiceRecord.payload['price_effect_minor'],
          isNot(choiceRecord.payload['extra_price_minor']),
        );

        final List<String> payloadModifierUuids = modifierRecords
            .map((SyncGraphRecord record) => record.recordUuid)
            .toList(growable: false);
        expect(payloadModifierUuids, fixture.expectedModifierOrderUuids);
      },
    );
  });
}

class _PayloadFixture {
  const _PayloadFixture({required this.transaction, required this.line});

  final Transaction transaction;
  final TransactionLine line;
}

class _BreakfastPayloadFixture {
  const _BreakfastPayloadFixture({
    required this.transaction,
    required this.line,
    required this.graph,
    required this.toastProductId,
    required this.expectedModifierOrderUuids,
  });

  final Transaction transaction;
  final TransactionLine line;
  final SyncTransactionGraph graph;
  final int toastProductId;
  final List<String> expectedModifierOrderUuids;
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

Future<_BreakfastPayloadFixture> _createPaidBreakfastPayloadFixture(
  AppDatabase db,
) async {
  final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: cashierId);

  final int breakfastCategoryId = await insertCategory(
    db,
    name: 'Set Breakfast',
  );
  final int hotDrinkCategoryId = await insertCategory(db, name: 'Hot Drink');
  final int extrasCategoryId = await insertCategory(
    db,
    name: 'Breakfast Extras',
  );

  final int set4ProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set 4',
    priceMinor: 400,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Egg',
    priceMinor: 120,
  );
  final int baconProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Bacon',
    priceMinor: 150,
  );
  final int sausageProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Sausage',
    priceMinor: 180,
  );
  final int chipsProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Chips',
    priceMinor: 110,
  );
  final int beansProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Beans',
    priceMinor: 80,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: hotDrinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int coffeeProductId = await insertProduct(
    db,
    categoryId: hotDrinkCategoryId,
    name: 'Coffee',
    priceMinor: 160,
  );
  final int toastProductId = await insertProduct(
    db,
    categoryId: extrasCategoryId,
    name: 'Toast',
    priceMinor: 100,
  );
  final int breadProductId = await insertProduct(
    db,
    categoryId: extrasCategoryId,
    name: 'Bread',
    priceMinor: 90,
  );

  Future<void> insertSetItem({
    required int itemProductId,
    required int sortOrder,
  }) async {
    await db
        .into(db.setItems)
        .insert(
          app_db.SetItemsCompanion.insert(
            productId: set4ProductId,
            itemProductId: itemProductId,
            sortOrder: Value<int>(sortOrder),
          ),
        );
  }

  await insertSetItem(itemProductId: eggProductId, sortOrder: 1);
  await insertSetItem(itemProductId: baconProductId, sortOrder: 2);
  await insertSetItem(itemProductId: sausageProductId, sortOrder: 3);
  await insertSetItem(itemProductId: chipsProductId, sortOrder: 4);
  await insertSetItem(itemProductId: beansProductId, sortOrder: 5);

  final int hotDrinkGroupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: set4ProductId,
          name: 'Tea or Coffee',
          minSelect: const Value<int>(0),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );
  final int toastBreadGroupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: set4ProductId,
          name: 'Toast or Bread',
          minSelect: const Value<int>(1),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(2),
        ),
      );

  Future<void> insertChoiceMember({
    required int groupId,
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          app_db.ProductModifiersCompanion.insert(
            productId: set4ProductId,
            groupId: Value<int?>(groupId),
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'choice',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertChoiceMember(
    groupId: hotDrinkGroupId,
    itemProductId: teaProductId,
    label: 'Tea',
  );
  await insertChoiceMember(
    groupId: hotDrinkGroupId,
    itemProductId: coffeeProductId,
    label: 'Coffee',
  );
  await insertChoiceMember(
    groupId: toastBreadGroupId,
    itemProductId: toastProductId,
    label: 'Toast',
  );
  await insertChoiceMember(
    groupId: toastBreadGroupId,
    itemProductId: breadProductId,
    label: 'Bread',
  );

  Future<void> insertExtra({
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          app_db.ProductModifiersCompanion.insert(
            productId: set4ProductId,
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'extra',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertExtra(itemProductId: baconProductId, label: 'Bacon');
  await insertExtra(itemProductId: sausageProductId, label: 'Sausage');
  await insertExtra(itemProductId: beansProductId, label: 'Beans');

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
    breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
    paymentRepository: PaymentRepository(db),
    syncQueueRepository: syncQueueRepository,
  );

  final Transaction transaction = await orderService.createOrder(
    currentUser: cashierUser,
  );
  final TransactionLine line = await orderService.addProductToOrder(
    transactionId: transaction.id,
    productId: set4ProductId,
  );
  await orderService.editBreakfastLine(
    transactionLineId: line.id,
    edit: BreakfastLineEdit.chooseGroup(
      groupId: toastBreadGroupId,
      selectedItemProductId: toastProductId,
      quantity: 1,
    ),
  );

  final List<QueryRow> semanticRows = await db
      .customSelect(
        '''
    SELECT id, uuid, charge_reason, sort_key
    FROM order_modifiers
    WHERE transaction_line_id = ?
    ORDER BY sort_key ASC, id ASC
    ''',
        variables: <Variable<Object>>[Variable<int>(line.id)],
      )
      .get();

  final int extraAddId = semanticRows
      .singleWhere(
        (QueryRow row) =>
            row.read<String>('charge_reason') == 'included_choice',
      )
      .read<int>('id');
  await db.customStatement(
    '''
    UPDATE order_modifiers
    SET extra_price_minor = 9999
    WHERE id = ?
    ''',
    <Object>[extraAddId],
  );

  await orderService.sendOrder(
    transactionId: transaction.id,
    currentUser: cashierUser,
  );
  await orderService.markOrderPaid(
    transactionId: transaction.id,
    method: PaymentMethod.card,
    currentUser: cashierUser,
  );

  final Transaction paid =
      await transactionRepository.getById(transaction.id) ??
      (throw StateError('Expected paid transaction.'));
  final TransactionLine paidLine =
      await transactionRepository.getLineById(line.id) ??
      (throw StateError('Expected breakfast line.'));
  final SyncTransactionGraph graph =
      await SyncPayloadRepository(db).buildTransactionGraph(paid.uuid) ??
      (throw StateError('Expected breakfast graph payload.'));

  return _BreakfastPayloadFixture(
    transaction: paid,
    line: paidLine,
    graph: graph,
    toastProductId: toastProductId,
    expectedModifierOrderUuids: semanticRows
        .map((QueryRow row) => row.read<String>('uuid'))
        .toList(growable: false),
  );
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
