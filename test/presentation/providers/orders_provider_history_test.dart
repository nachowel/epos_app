import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart'
    show TransactionLinesCompanion;
import 'package:epos_app/domain/models/open_order_summary.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'cashier OrdersNotifier loads only today paid history even when there is no active shift',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
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
        paidAt: DateTime.now(),
      );
      final int sentOrderId = await insertTransaction(
        db,
        uuid: 'orders-history-sent',
        shiftId: closedShiftId,
        userId: cashierId,
        status: 'sent',
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
      await _insertLine(db, transactionId: sentOrderId, productId: productId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);

      final OrdersNotifier notifier = container.read(
        ordersNotifierProvider.notifier,
      );
      await notifier.refreshOpenOrders();

      final OrdersState allState = container.read(ordersNotifierProvider);
      expect(allState.orderSummaries, hasLength(1));
      expect(allState.orderSummaries.single.transaction.id, paidOrderId);
      expect(allState.orderSummaries.single.transaction.status.name, 'paid');
      expect(allState.searchQuery, isEmpty);
      expect(allState.hasMore, isFalse);
    },
  );

  test(
    'cashier OrdersNotifier shows only the five newest paid orders today',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Food');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Toast',
        priceMinor: 200,
      );

      final List<int> paidOrderIds = <int>[];
      for (int index = 0; index < 6; index++) {
        final int transactionId = await insertTransaction(
          db,
          uuid: 'orders-history-page-$index',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 200,
          paidAt: DateTime(2026, 4, 14, 8 + index),
        );
        paidOrderIds.add(transactionId);
        await _insertLine(
          db,
          transactionId: transactionId,
          productId: productId,
        );
      }
      final int yesterdayOrderId = await insertTransaction(
        db,
        uuid: 'orders-history-yesterday',
        shiftId: shiftId,
        userId: cashierId,
        status: 'paid',
        totalAmountMinor: 200,
        paidAt: DateTime(2026, 4, 13, 23, 0),
      );
      await _insertLine(
        db,
        transactionId: yesterdayOrderId,
        productId: productId,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);

      final OrdersNotifier notifier = container.read(
        ordersNotifierProvider.notifier,
      );
      await notifier.refreshOpenOrders();

      OrdersState state = container.read(ordersNotifierProvider);
      expect(state.orderSummaries, hasLength(5));
      expect(
        state.orderSummaries.map(
          (OpenOrderSummary summary) => summary.transaction.id,
        ),
        orderedEquals(paidOrderIds.reversed.take(5).toList(growable: false)),
      );
      expect(state.hasMore, isFalse);
    },
  );
}

Future<void> _insertLine(
  dynamic db, {
  required int transactionId,
  required int productId,
}) {
  return db
      .into(db.transactionLines)
      .insert(
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
