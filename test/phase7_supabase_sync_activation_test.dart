import 'dart:async';

import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/sync_queue_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/data/sync/supabase_sync_service.dart';
import 'package:epos_app/data/sync/sync_connectivity_service.dart';
import 'package:epos_app/data/sync/sync_payload_repository.dart';
import 'package:epos_app/data/sync/sync_remote_gateway.dart';
import 'package:epos_app/data/sync/sync_worker.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_database.dart';

void main() {
  group('Phase 7 Supabase sync activation', () {
    test(
      'missing Supabase config logs structured warning and does not crash',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final _SeededPaidOrder seeded = await _seedPaidOrder(
          db,
          syncQueueRepository: queueRepository,
          withModifier: false,
        );

        final MemoryAppLogSink sink = MemoryAppLogSink();
        final StructuredAppLogger logger = StructuredAppLogger(
          sinks: <AppLogSink>[sink],
          enableInfoLogs: true,
        );
        addTearDown(logger.dispose);

        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _UnconfiguredRemoteGateway(),
          connectivityService: _FakeConnectivityService(initialOnline: true),
          logger: logger,
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();
        await _waitUntil(() => sink.entries.isNotEmpty);

        expect(
          worker.currentState.lastRuntimeError,
          'Supabase sync is not configured.',
        );
        expect(
          sink.entries.map((entry) => entry.eventType),
          contains('sync_misconfigured'),
        );
        final ({int pendingCount, int failedCount}) counts =
            await queueRepository.getMonitorCounts();
        expect(counts.pendingCount, 1);
        expect(counts.failedCount, 0);
        expect(seeded.transaction.status, TransactionStatus.paid);
      },
    );

    test(
      'valid finalized graph maps to remote payload without leaking relational local ids',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final _SeededPaidOrder seeded = await _seedPaidOrder(
          db,
          syncQueueRepository: queueRepository,
          withModifier: true,
        );
        final _RecordingSupabaseSyncClient syncClient =
            _RecordingSupabaseSyncClient();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: SupabaseSyncService(syncClient: syncClient),
          connectivityService: _FakeConnectivityService(initialOnline: true),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();

        expect(syncClient.upserts, hasLength(4));

        final _RecordedUpsert transactionUpsert = syncClient.find(
          'transactions',
          seeded.transaction.uuid,
        );
        expect(transactionUpsert.onConflict, 'uuid');
        expect(
          transactionUpsert.payload,
          containsPair('shift_local_id', seeded.transaction.shiftId),
        );
        expect(
          transactionUpsert.payload,
          containsPair('user_local_id', seeded.transaction.userId),
        );
        expect(
          transactionUpsert.payload,
          containsPair('cancelled_by_local_id', isNull),
        );
        expect(transactionUpsert.payload.containsKey('id'), isFalse);
        expect(transactionUpsert.payload.containsKey('shift_id'), isFalse);
        expect(transactionUpsert.payload.containsKey('user_id'), isFalse);
        expect(
          transactionUpsert.payload.containsKey('idempotency_key'),
          isFalse,
        );

        final _RecordedUpsert lineUpsert = syncClient.find(
          'transaction_lines',
          seeded.line.uuid,
        );
        expect(
          lineUpsert.payload,
          containsPair('transaction_uuid', seeded.transaction.uuid),
        );
        expect(
          lineUpsert.payload,
          containsPair('product_local_id', seeded.line.productId),
        );
        expect(lineUpsert.payload.containsKey('transaction_id'), isFalse);
        expect(lineUpsert.payload.containsKey('product_id'), isFalse);

        final _RecordedUpsert modifierUpsert = syncClient.find(
          'order_modifiers',
          seeded.modifierUuid!,
        );
        expect(
          modifierUpsert.payload,
          containsPair('transaction_line_uuid', seeded.line.uuid),
        );

        final _RecordedUpsert paymentUpsert = syncClient.find(
          'payments',
          seeded.payment.uuid,
        );
        expect(
          paymentUpsert.payload,
          containsPair('transaction_uuid', seeded.transaction.uuid),
        );
        expect(paymentUpsert.payload.containsKey('transaction_id'), isFalse);
      },
    );

    test(
      'queued OPEN transaction is rejected before any remote write',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        await insertTransaction(
          db,
          uuid: 'open-should-not-sync',
          shiftId: shiftId,
          userId: adminId,
          status: 'sent',
          totalAmountMinor: 900,
        );
        await insertSyncQueueItem(
          db,
          tableName: 'transactions',
          recordUuid: 'open-should-not-sync',
        );

        final _RecordingSupabaseSyncClient syncClient =
            _RecordingSupabaseSyncClient();
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: SupabaseSyncService(syncClient: syncClient),
          connectivityService: _FakeConnectivityService(initialOnline: true),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();

        expect(syncClient.upserts, isEmpty);
        final ({int pendingCount, int failedCount}) counts =
            await queueRepository.getMonitorCounts();
        expect(counts.pendingCount, 0);
        expect(counts.failedCount, 1);
      },
    );

    test(
      'gateway reports configured only when a Supabase sync client exists',
      () async {
        expect(SupabaseSyncService().isConfigured, isFalse);
        expect(
          SupabaseSyncService(
            syncClient: _RecordingSupabaseSyncClient(),
          ).isConfigured,
          isTrue,
        );
      },
    );
  });
}

class _SeededPaidOrder {
  const _SeededPaidOrder({
    required this.transaction,
    required this.line,
    required this.payment,
    required this.modifierUuid,
  });

  final Transaction transaction;
  final TransactionLine line;
  final Payment payment;
  final String? modifierUuid;
}

class _FakeConnectivityService implements SyncConnectivityService {
  _FakeConnectivityService({required bool initialOnline})
    : _online = initialOnline;

  final bool _online;

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> watchOnlineStatus() => const Stream<bool>.empty();
}

class _UnconfiguredRemoteGateway implements SyncRemoteGateway {
  @override
  bool get isConfigured => false;

  @override
  Future<void> upsertRecord({
    required String tableName,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) {
    throw UnimplementedError(
      'Should never be called when gateway is unconfigured.',
    );
  }
}

class _RecordedUpsert {
  const _RecordedUpsert({
    required this.tableName,
    required this.payload,
    required this.onConflict,
  });

  final String tableName;
  final Map<String, Object?> payload;
  final String onConflict;
}

class _RecordingSupabaseSyncClient implements SupabaseSyncClient {
  final List<_RecordedUpsert> upserts = <_RecordedUpsert>[];

  @override
  Future<void> upsert({
    required String tableName,
    required Map<String, Object?> payload,
    required String onConflict,
  }) async {
    upserts.add(
      _RecordedUpsert(
        tableName: tableName,
        payload: Map<String, Object?>.from(payload),
        onConflict: onConflict,
      ),
    );
  }

  _RecordedUpsert find(String tableName, String uuid) {
    return upserts.singleWhere(
      (_RecordedUpsert upsert) =>
          upsert.tableName == tableName && upsert.payload['uuid'] == uuid,
    );
  }
}

Future<_SeededPaidOrder> _seedPaidOrder(
  AppDatabase db, {
  required SyncQueueRepository syncQueueRepository,
  required bool withModifier,
}) async {
  final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
  await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: adminId);
  final int categoryId = await insertCategory(db, name: 'Hot Drinks');
  final int productId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Latte',
    priceMinor: 450,
  );

  final OrderService orderService = OrderService(
    shiftSessionService: ShiftSessionService(ShiftRepository(db)),
    transactionRepository: TransactionRepository(
      db,
      syncQueueRepository: syncQueueRepository,
    ),
    transactionStateRepository: TransactionStateRepository(db),
    paymentRepository: PaymentRepository(db),
    syncQueueRepository: syncQueueRepository,
  );

  final User adminUser = User(
    id: adminId,
    name: 'Admin',
    pin: null,
    password: null,
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.now(),
  );

  final Transaction createdTransaction = await orderService.createOrder(
    currentUser: adminUser,
  );
  final TransactionLine line = await orderService.addProductToOrder(
    transactionId: createdTransaction.id,
    productId: productId,
  );
  String? modifierUuid;
  if (withModifier) {
    final OrderModifier modifier = await orderService.addModifierToLine(
      transactionLineId: line.id,
      action: ModifierAction.add,
      itemName: 'Extra Shot',
      extraPriceMinor: 75,
    );
    modifierUuid = modifier.uuid;
  }
  await orderService.sendOrder(
    transactionId: createdTransaction.id,
    currentUser: adminUser,
  );
  final Payment payment = await orderService.markOrderPaid(
    transactionId: createdTransaction.id,
    method: PaymentMethod.card,
    currentUser: adminUser,
  );
  final Transaction paidTransaction =
      await TransactionRepository(
        db,
        syncQueueRepository: syncQueueRepository,
      ).getById(createdTransaction.id) ??
      (throw StateError('Expected paid transaction.'));

  return _SeededPaidOrder(
    transaction: paidTransaction,
    line: line,
    payment: payment,
    modifierUuid: modifierUuid,
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met before timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
