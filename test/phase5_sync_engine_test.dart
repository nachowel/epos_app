import 'dart:async';
import 'dart:io';

import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/sync_queue_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/data/sync/sync_connectivity_service.dart';
import 'package:epos_app/data/sync/sync_payload_repository.dart';
import 'package:epos_app/data/sync/sync_remote_gateway.dart';
import 'package:epos_app/data/sync/sync_transaction_graph.dart';
import 'package:epos_app/data/sync/sync_worker.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/sync_queue_item.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/test_database.dart';

void main() {
  group('Phase 5.1 sync correctness hardening', () {
    test(
      'markOrderPaid tek transaction-root event yazar ve worker full graph sync eder',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
        final _SeededPaidOrder seededOrder = await _seedPaidOrder(
          db,
          syncQueueRepository: syncQueueRepository,
          withModifier: true,
        );
        final _DeterministicFakeRemoteGateway remoteGateway =
            _DeterministicFakeRemoteGateway();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: syncQueueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: remoteGateway,
          connectivityService: _FakeConnectivityService(initialOnline: true),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        final List<SyncQueueItem> initialItems = await syncQueueRepository
            .getMonitorItems(limit: 10);
        expect(initialItems, hasLength(1));
        expect(initialItems.single.tableName, 'transactions');
        expect(initialItems.single.recordUuid, seededOrder.transaction.uuid);

        await worker.runOnce();

        expect(remoteGateway.records.length, 4);
        expect(
          remoteGateway.records.keys,
          containsAll(<String>[
            'transactions:${seededOrder.transaction.uuid}',
            'transaction_lines:${seededOrder.line.uuid}',
            'order_modifiers:${seededOrder.modifierUuid!}',
            'payments:${seededOrder.payment.uuid}',
          ]),
        );

        final ({int pendingCount, int failedCount}) counts =
            await syncQueueRepository.getMonitorCounts();
        expect(counts.pendingCount, 0);
        expect(counts.failedCount, 0);
      },
    );

    test('iki worker ayni queue setinde duplicate claim yapmaz', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final SyncQueueRepository seedQueueRepository = SyncQueueRepository(db);
      final _SeededPaidOrder seededOrder = await _seedPaidOrder(
        db,
        syncQueueRepository: seedQueueRepository,
        withModifier: true,
      );
      final _DeterministicFakeRemoteGateway remoteGateway =
          _DeterministicFakeRemoteGateway();

      final SyncWorker workerA = SyncWorker(
        syncQueueRepository: SyncQueueRepository(db),
        syncPayloadRepository: SyncPayloadRepository(db),
        remoteGateway: remoteGateway,
        connectivityService: _FakeConnectivityService(initialOnline: true),
        pollInterval: const Duration(days: 1),
      );
      final SyncWorker workerB = SyncWorker(
        syncQueueRepository: SyncQueueRepository(db),
        syncPayloadRepository: SyncPayloadRepository(db),
        remoteGateway: remoteGateway,
        connectivityService: _FakeConnectivityService(initialOnline: true),
        pollInterval: const Duration(days: 1),
      );
      addTearDown(workerA.dispose);
      addTearDown(workerB.dispose);

      await Future.wait(<Future<void>>[workerA.runOnce(), workerB.runOnce()]);

      expect(remoteGateway.callCount, 4);
      expect(remoteGateway.records.length, 4);
      expect(
        remoteGateway.records.keys,
        contains('transactions:${seededOrder.transaction.uuid}'),
      );

      final ({int pendingCount, int failedCount}) counts =
          await SyncQueueRepository(db).getMonitorCounts();
      expect(counts.pendingCount, 0);
      expect(counts.failedCount, 0);
    });

    test(
      'aynı logical event tekrar gönderilince remote snapshot deterministic kalir',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
        final _SeededPaidOrder seededOrder = await _seedPaidOrder(
          db,
          syncQueueRepository: syncQueueRepository,
          withModifier: true,
        );
        final _DeterministicFakeRemoteGateway remoteGateway =
            _DeterministicFakeRemoteGateway();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: syncQueueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: remoteGateway,
          connectivityService: _FakeConnectivityService(initialOnline: true),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();
        final Map<String, Object?> firstSnapshot = remoteGateway.snapshotFor(
          'transactions',
          seededOrder.transaction.uuid,
        )!;

        await syncQueueRepository.addToQueue(
          'transactions',
          seededOrder.transaction.uuid,
        );
        await worker.runOnce();

        expect(remoteGateway.records.length, 4);
        expect(
          remoteGateway.snapshotFor(
            'transactions',
            seededOrder.transaction.uuid,
          ),
          firstSnapshot,
        );
        expect(
          remoteGateway.receivedIdempotencyKeys
              .where(
                (String key) => key == seededOrder.transaction.idempotencyKey,
              )
              .length,
          2,
        );
      },
    );

    test(
      'aynı payment tekrar queue edilince remote payment snapshot duplicate write üretmez',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
        final _SeededPaidOrder seededOrder = await _seedPaidOrder(
          db,
          syncQueueRepository: syncQueueRepository,
        );
        final _DeterministicFakeRemoteGateway remoteGateway =
            _DeterministicFakeRemoteGateway();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: syncQueueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: remoteGateway,
          connectivityService: _FakeConnectivityService(initialOnline: true),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();
        final Map<String, Object?> firstSnapshot = remoteGateway.snapshotFor(
          'payments',
          seededOrder.payment.uuid,
        )!;
        final int firstApplyCount = remoteGateway.applyCount;

        await syncQueueRepository.addToQueue(
          'payments',
          seededOrder.payment.uuid,
        );
        await worker.runOnce();

        expect(remoteGateway.records.length, 3);
        expect(
          remoteGateway.snapshotFor('payments', seededOrder.payment.uuid),
          firstSnapshot,
        );
        expect(remoteGateway.applyCount, firstApplyCount);
        expect(
          remoteGateway.receivedIdempotencyKeys
              .where(
                (String key) =>
                    key ==
                    '${seededOrder.transaction.idempotencyKey}:payment:${seededOrder.payment.uuid}',
              )
              .length,
          2,
        );
      },
    );

    test('stale print payload yeni revisioni ezemez', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
      final TransactionRepository transactionRepository = TransactionRepository(
        db,
        syncQueueRepository: syncQueueRepository,
      );
      final _SeededPaidOrder seededOrder = await _seedPaidOrder(
        db,
        syncQueueRepository: syncQueueRepository,
      );
      final Completer<void> transactionStarted = Completer<void>();
      final Completer<void> releaseOldPayload = Completer<void>();
      bool blockedFirstTransaction = false;
      final _DeterministicFakeRemoteGateway remoteGateway =
          _DeterministicFakeRemoteGateway(
            beforeApply:
                (
                  String key,
                  Map<String, Object?> payload,
                  String idempotencyKey,
                ) async {
                  if (key == 'transactions:${seededOrder.transaction.uuid}' &&
                      !blockedFirstTransaction) {
                    blockedFirstTransaction = true;
                    transactionStarted.complete();
                    await releaseOldPayload.future;
                  }
                },
          );
      final SyncWorker worker = SyncWorker(
        syncQueueRepository: syncQueueRepository,
        syncPayloadRepository: SyncPayloadRepository(db),
        remoteGateway: remoteGateway,
        connectivityService: _FakeConnectivityService(initialOnline: true),
        pollInterval: const Duration(days: 1),
      );
      addTearDown(worker.dispose);

      final Future<void> firstRun = worker.runOnce();
      await transactionStarted.future;

      await transactionRepository.updatePrintFlag(
        transactionId: seededOrder.transaction.id,
        receiptPrinted: true,
      );

      final List<SyncQueueItem> duringRace = await syncQueueRepository
          .getMonitorItems(limit: 10);
      expect(
        duringRace.map((SyncQueueItem item) => item.status).toSet(),
        <SyncQueueStatus>{SyncQueueStatus.processing, SyncQueueStatus.pending},
      );

      releaseOldPayload.complete();
      await firstRun;

      final ({int pendingCount, int failedCount}) postFirstCounts =
          await syncQueueRepository.getMonitorCounts();
      expect(postFirstCounts.pendingCount, 1);
      expect(postFirstCounts.failedCount, 0);

      await worker.runOnce();

      final Map<String, Object?> transactionSnapshot = remoteGateway
          .snapshotFor('transactions', seededOrder.transaction.uuid)!;
      final ({int pendingCount, int failedCount}) finalCounts =
          await syncQueueRepository.getMonitorCounts();

      expect(transactionSnapshot['receipt_printed'], true);
      expect(finalCounts.pendingCount, 0);
      expect(finalCounts.failedCount, 0);
    });

    test('graph fail olursa retry sonunda remote graph tamamlanir', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
      final _SeededPaidOrder seededOrder = await _seedPaidOrder(
        db,
        syncQueueRepository: syncQueueRepository,
        withModifier: true,
      );
      final _DeterministicFakeRemoteGateway remoteGateway =
          _DeterministicFakeRemoteGateway(
            failuresBeforeApply: <String, int>{
              'payments:${seededOrder.payment.uuid}': 1,
            },
          );
      final SyncWorker worker = SyncWorker(
        syncQueueRepository: syncQueueRepository,
        syncPayloadRepository: SyncPayloadRepository(db),
        remoteGateway: remoteGateway,
        connectivityService: _FakeConnectivityService(initialOnline: true),
        pollInterval: const Duration(days: 1),
      );
      addTearDown(worker.dispose);

      await worker.runOnce();

      final ({int pendingCount, int failedCount}) failedCounts =
          await syncQueueRepository.getMonitorCounts();
      expect(failedCounts.pendingCount, 0);
      expect(failedCounts.failedCount, 1);
      expect(remoteGateway.records.length, 3);
      expect(
        remoteGateway.records.keys,
        isNot(contains('payments:${seededOrder.payment.uuid}')),
      );

      await worker.retryAllFailed();

      final ({int pendingCount, int failedCount}) finalCounts =
          await syncQueueRepository.getMonitorCounts();
      expect(finalCounts.pendingCount, 0);
      expect(finalCounts.failedCount, 0);
      expect(remoteGateway.records.length, 4);
      expect(
        remoteGateway.records.keys,
        contains('payments:${seededOrder.payment.uuid}'),
      );
    });

    test(
      'remote success ile local ack arasi crash replay sonrasi regression üretmez',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
        final _SeededPaidOrder seededOrder = await _seedPaidOrder(
          db,
          syncQueueRepository: syncQueueRepository,
        );
        final _DeterministicFakeRemoteGateway remoteGateway =
            _DeterministicFakeRemoteGateway(
              failuresAfterApply: <String, int>{
                'payments:${seededOrder.payment.uuid}': 1,
              },
            );
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: syncQueueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: remoteGateway,
          connectivityService: _FakeConnectivityService(initialOnline: true),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();

        final Map<String, Object?> firstTransactionSnapshot = remoteGateway
            .snapshotFor('transactions', seededOrder.transaction.uuid)!;
        final ({int pendingCount, int failedCount}) failedCounts =
            await syncQueueRepository.getMonitorCounts();
        expect(failedCounts.failedCount, 1);

        await worker.retryAllFailed();

        expect(
          remoteGateway.snapshotFor(
            'transactions',
            seededOrder.transaction.uuid,
          ),
          firstTransactionSnapshot,
        );
        expect(remoteGateway.records.length, 3);
        final ({int pendingCount, int failedCount}) finalCounts =
            await syncQueueRepository.getMonitorCounts();
        expect(finalCounts.pendingCount, 0);
        expect(finalCounts.failedCount, 0);
      },
    );

    test(
      'startup recovery processing itemi pendinge cevirip tamamlar',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'epos-phase5-recovery',
        );
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });
        final String dbPath = p.join(tempDir.path, 'sync.sqlite');

        final AppDatabase initialDb = createPersistentTestDatabase(dbPath);
        final int adminId = await insertUser(
          initialDb,
          name: 'Admin',
          role: 'admin',
        );
        final int shiftId = await insertShift(initialDb, openedBy: adminId);
        final int transactionId = await insertTransaction(
          initialDb,
          uuid: 'restart-recovery-tx',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 1000,
        );
        await insertPayment(
          initialDb,
          uuid: 'restart-recovery-payment',
          transactionId: transactionId,
          method: 'card',
          amountMinor: 1000,
        );
        await insertSyncQueueItem(
          initialDb,
          tableName: 'transactions',
          recordUuid: 'restart-recovery-tx',
          status: 'processing',
          attemptCount: 2,
        );
        await initialDb.close();

        final AppDatabase reopenedDb = createPersistentTestDatabase(dbPath);
        addTearDown(reopenedDb.close);
        final SyncQueueRepository syncQueueRepository = SyncQueueRepository(
          reopenedDb,
        );
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: syncQueueRepository,
          syncPayloadRepository: SyncPayloadRepository(reopenedDb),
          remoteGateway: _DeterministicFakeRemoteGateway(),
          connectivityService: _FakeConnectivityService(initialOnline: true),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.start();
        await _waitUntil(() async {
          final ({int pendingCount, int failedCount}) counts =
              await syncQueueRepository.getMonitorCounts();
          return counts.pendingCount == 0 && counts.failedCount == 0;
        });

        expect(await syncQueueRepository.getLastSyncedAt(), isNotNull);
      },
    );

    test(
      'network toggle workeri manual UI tetigi olmadan resume ettirir',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
        final _SeededPaidOrder seededOrder = await _seedPaidOrder(
          db,
          syncQueueRepository: syncQueueRepository,
        );
        final _FakeConnectivityService connectivityService =
            _FakeConnectivityService(initialOnline: false);
        final _DeterministicFakeRemoteGateway remoteGateway =
            _DeterministicFakeRemoteGateway();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: syncQueueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: remoteGateway,
          connectivityService: connectivityService,
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.start();
        expect(remoteGateway.callCount, 0);

        await connectivityService.setOnline(true);
        await _waitUntil(() => remoteGateway.records.length == 3);

        expect(
          remoteGateway.records.keys,
          contains('transactions:${seededOrder.transaction.uuid}'),
        );
      },
    );

    test('max retry limiti asilan failed item otomatik islenmez', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      await insertTransaction(
        db,
        uuid: 'max-retry-tx',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 750,
      );
      await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'max-retry-tx',
        status: 'failed',
        attemptCount: 5,
        errorMessage: 'permanent failure',
      );

      final _DeterministicFakeRemoteGateway remoteGateway =
          _DeterministicFakeRemoteGateway();
      final SyncWorker worker = SyncWorker(
        syncQueueRepository: SyncQueueRepository(db),
        syncPayloadRepository: SyncPayloadRepository(db),
        remoteGateway: remoteGateway,
        connectivityService: _FakeConnectivityService(initialOnline: true),
        pollInterval: const Duration(days: 1),
      );
      addTearDown(worker.dispose);

      await worker.runOnce();

      final List<SyncQueueItem> items = await SyncQueueRepository(
        db,
      ).getMonitorItems(limit: 10);
      expect(items.single.status, SyncQueueStatus.failed);
      expect(items.single.attemptCount, 5);
      expect(remoteGateway.callCount, 0);
    });
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

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _online;

  @override
  Future<bool> isOnline() async => _online;

  @override
  Stream<bool> watchOnlineStatus() => _controller.stream;

  Future<void> setOnline(bool online) async {
    _online = online;
    _controller.add(online);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _DeterministicFakeRemoteGateway implements SyncRemoteGateway {
  _DeterministicFakeRemoteGateway({
    Map<String, int>? failuresBeforeApply,
    Map<String, int>? failuresAfterApply,
    this.beforeApply,
  }) : _failuresBeforeApply = failuresBeforeApply ?? <String, int>{},
       _failuresAfterApply = failuresAfterApply ?? <String, int>{};

  final Map<String, int> _failuresBeforeApply;
  final Map<String, int> _failuresAfterApply;
  final Future<void> Function(
    String key,
    Map<String, Object?> payload,
    String idempotencyKey,
  )?
  beforeApply;

  final Map<String, Map<String, Object?>> records =
      <String, Map<String, Object?>>{};
  final List<String> receivedIdempotencyKeys = <String>[];
  int callCount = 0;
  int applyCount = 0;

  @override
  bool get isConfigured => true;

  @override
  String? get configurationIssue => null;

  Map<String, Object?>? snapshotFor(String tableName, String uuid) {
    final Map<String, Object?>? record = records['$tableName:$uuid'];
    if (record == null) {
      return null;
    }
    return Map<String, Object?>.from(record);
  }

  @override
  Future<void> syncTransactionGraph(SyncTransactionGraph graph) async {
    for (final SyncGraphRecord record in graph.records) {
      callCount += 1;
      receivedIdempotencyKeys.add(record.idempotencyKey);

      final String uuid = record.payload['uuid']! as String;
      final String key = '${record.tableName}:$uuid';

      final Future<void> Function(
        String key,
        Map<String, Object?> payload,
        String idempotencyKey,
      )?
      callback = beforeApply;
      if (callback != null) {
        await callback(
          key,
          Map<String, Object?>.from(record.payload),
          record.idempotencyKey,
        );
      }

      if (_consumeFailure(_failuresBeforeApply, key)) {
        throw StateError('Simulated remote failure before apply for $key');
      }

      final bool changed = record.tableName == 'transactions'
          ? _applyTransactionSnapshot(key, record.payload)
          : _applyImmutableSnapshot(key, record.payload);
      if (changed) {
        applyCount += 1;
      }

      if (_consumeFailure(_failuresAfterApply, key)) {
        throw StateError('Simulated remote failure after apply for $key');
      }
    }
  }

  bool _applyImmutableSnapshot(String key, Map<String, Object?> payload) {
    final Map<String, Object?> next = Map<String, Object?>.from(payload);
    final Map<String, Object?>? current = records[key];
    if (current != null && mapEquals(current, next)) {
      return false;
    }
    records[key] = next;
    return true;
  }

  bool _applyTransactionSnapshot(String key, Map<String, Object?> payload) {
    final Map<String, Object?> next = Map<String, Object?>.from(payload);
    final Map<String, Object?>? current = records[key];
    if (current == null) {
      records[key] = next;
      return true;
    }

    final DateTime currentUpdatedAt = DateTime.parse(
      current['updated_at']! as String,
    );
    final DateTime nextUpdatedAt = DateTime.parse(
      next['updated_at']! as String,
    );
    if (currentUpdatedAt.isAfter(nextUpdatedAt)) {
      return false;
    }
    if (currentUpdatedAt.isAtSameMomentAs(nextUpdatedAt)) {
      next['kitchen_printed'] =
          (current['kitchen_printed'] as bool? ?? false) ||
          (next['kitchen_printed'] as bool? ?? false);
      next['receipt_printed'] =
          (current['receipt_printed'] as bool? ?? false) ||
          (next['receipt_printed'] as bool? ?? false);
    }

    if (mapEquals(current, next)) {
      return false;
    }

    records[key] = next;
    return true;
  }

  bool _consumeFailure(Map<String, int> failures, String key) {
    final int remaining = failures[key] ?? 0;
    if (remaining <= 0) {
      return false;
    }
    failures[key] = remaining - 1;
    return true;
  }
}

Future<_SeededPaidOrder> _seedPaidOrder(
  AppDatabase db, {
  required SyncQueueRepository syncQueueRepository,
  bool withModifier = false,
}) async {
  final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
  await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: adminId);
  final int categoryId = await insertCategory(db, name: 'Drinks');
  final int productId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Latte',
    priceMinor: 450,
  );

  final ShiftRepository shiftRepository = ShiftRepository(db);
  final TransactionRepository transactionRepository = TransactionRepository(
    db,
    syncQueueRepository: syncQueueRepository,
  );
  final OrderService orderService = OrderService(
    shiftSessionService: ShiftSessionService(shiftRepository),
    transactionRepository: transactionRepository,
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
      await transactionRepository.getById(createdTransaction.id) ??
      (throw StateError('Expected paid transaction.'));

  return _SeededPaidOrder(
    transaction: paidTransaction,
    line: line,
    payment: payment,
    modifierUuid: modifierUuid,
  );
}

Future<void> _waitUntil(FutureOr<bool> Function() condition) async {
  for (int index = 0; index < 100; index += 1) {
    if (await condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('Condition not met within timeout.');
}
