import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart'
    show TransactionLinesCompanion;
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'OrdersNotifier loads paid history even when there is no active shift',
    () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int closedShiftId = await insertShift(
        db,
        openedBy: cashierId,
        status: 'closed',
        closedBy: cashierId,
        closedAt: DateTime.now(),
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );
      final int categoryId = await insertCategory(db, name: 'Drinks');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Coffee',
        priceMinor: 250,
      );
      final int paidOrderId = await insertTransaction(
        db,
        uuid: 'orders-history-paid',
        shiftId: closedShiftId,
        userId: cashierId,
        status: 'paid',
        totalAmountMinor: 250,
      );
      await db
          .into(db.transactionLines)
          .insert(
            TransactionLinesCompanion.insert(
              uuid: 'orders-history-paid-line',
              transactionId: paidOrderId,
              productId: productId,
              productName: 'Coffee',
              unitPriceMinor: 250,
              quantity: const Value<int>(1),
              lineTotalMinor: 250,
            ),
          );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final OrdersNotifier notifier = container.read(
        ordersNotifierProvider.notifier,
      );
      await notifier.refreshOpenOrders();

      final OrdersState allState = container.read(ordersNotifierProvider);
      expect(allState.orderSummaries, hasLength(1));
      expect(allState.orderSummaries.single.transaction.id, paidOrderId);

      await notifier.setFilter(OrdersFilter.paid);
      final OrdersState paidState = container.read(ordersNotifierProvider);
      expect(paidState.orderSummaries, hasLength(1));
      expect(paidState.orderSummaries.single.transaction.status.name, 'paid');

      await notifier.setFilter(OrdersFilter.openSent);
      final OrdersState activeState = container.read(ordersNotifierProvider);
      expect(activeState.orderSummaries, isEmpty);
    },
  );

  test('OrdersNotifier paginates large order history', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
    final int shiftId = await insertShift(db, openedBy: cashierId);
    final int categoryId = await insertCategory(db, name: 'Food');
    final int productId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Toast',
      priceMinor: 200,
    );

    for (int index = 0; index < 55; index++) {
      final int transactionId = await insertTransaction(
        db,
        uuid: 'orders-history-page-$index',
        shiftId: shiftId,
        userId: cashierId,
        status: 'paid',
        totalAmountMinor: 200,
      );
      await _insertLine(db, transactionId: transactionId, productId: productId);
    }

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final OrdersNotifier notifier = container.read(
      ordersNotifierProvider.notifier,
    );
    await notifier.setDateFilter(OrdersDateFilter.allTime);
    await notifier.setFilter(OrdersFilter.paid);

    OrdersState state = container.read(ordersNotifierProvider);
    expect(state.orderSummaries, hasLength(50));
    expect(state.hasMore, isTrue);

    await notifier.loadMoreOrders();
    state = container.read(ordersNotifierProvider);

    expect(state.orderSummaries, hasLength(55));
    expect(state.hasMore, isFalse);
  });

  test('search by order number bypasses today filter for old paid order', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
    final int shiftId = await insertShift(db, openedBy: cashierId);
    final int categoryId = await insertCategory(db, name: 'Food');
    final int productId = await insertProduct(
      db,
      categoryId: categoryId,
      name: 'Sandwich',
      priceMinor: 450,
    );
    final int oldOrderId = await insertTransaction(
      db,
      uuid: 'orders-history-old-paid',
      shiftId: shiftId,
      userId: cashierId,
      status: 'paid',
      totalAmountMinor: 450,
    );
    await _insertLine(db, transactionId: oldOrderId, productId: productId);
    await db.customStatement(
      'UPDATE transactions SET created_at = ?, updated_at = ? WHERE id = ?',
      <Object?>[
        DateTime(2025, 1, 5).millisecondsSinceEpoch ~/ 1000,
        DateTime(2025, 1, 5).millisecondsSinceEpoch ~/ 1000,
        oldOrderId,
      ],
    );

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final OrdersNotifier notifier = container.read(
      ordersNotifierProvider.notifier,
    );
    await notifier.setFilter(OrdersFilter.paid);

    OrdersState state = container.read(ordersNotifierProvider);
    expect(state.orderSummaries, isEmpty);

    await notifier.setSearchQuery('$oldOrderId');
    state = container.read(ordersNotifierProvider);

    expect(state.orderSummaries, hasLength(1));
    expect(state.orderSummaries.single.transaction.id, oldOrderId);
  });
}

Future<void> _insertLine(
  dynamic db, {
  required int transactionId,
  required int productId,
}) {
  return db.into(db.transactionLines).insert(
    TransactionLinesCompanion.insert(
      uuid: 'line-$transactionId-$productId',
      transactionId: transactionId,
      productId: productId,
      productName: 'Item',
      unitPriceMinor: 200,
      quantity: const Value<int>(1),
      lineTotalMinor: 200,
    ),
  );
}
