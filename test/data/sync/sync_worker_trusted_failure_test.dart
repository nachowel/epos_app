import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/sync_queue_repository.dart';
import 'package:epos_app/data/sync/sync_connectivity_service.dart';
import 'package:epos_app/data/sync/sync_payload_repository.dart';
import 'package:epos_app/data/sync/sync_remote_gateway.dart';
import 'package:epos_app/data/sync/sync_transaction_graph.dart';
import 'package:epos_app/data/sync/sync_worker.dart';
import 'package:epos_app/data/sync/trusted_mirror_boundary_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'non-retryable trusted boundary failures are marked permanently failed',
    () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final MemoryAppLogSink sink = MemoryAppLogSink();
      final StructuredAppLogger logger = StructuredAppLogger(
        sinks: <AppLogSink>[sink],
        enableInfoLogs: true,
      );
      addTearDown(logger.dispose);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'trusted-failure-tx',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 1200,
      );
      await insertPayment(
        db,
        uuid: 'trusted-failure-payment',
        transactionId: transactionId,
        method: 'card',
        amountMinor: 1200,
      );
      await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'trusted-failure-tx',
      );

      final SyncQueueRepository queueRepository = SyncQueueRepository(db);
      final SyncWorker worker = SyncWorker(
        syncQueueRepository: queueRepository,
        syncPayloadRepository: SyncPayloadRepository(db),
        remoteGateway: const _ValidationFailingRemoteGateway(),
        connectivityService: const _AlwaysOnlineConnectivityService(),
        logger: logger,
        pollInterval: const Duration(days: 1),
      );
      addTearDown(worker.dispose);

      await worker.runOnce();

      final items = await queueRepository.getMonitorItems(limit: 10);
      expect(items, hasLength(1));
      expect(items.single.attemptCount, 5);
      expect(
        items.single.errorMessage,
        contains('Payload rejected by trusted boundary'),
      );
      final entry = sink.entries.lastWhere(
        (entry) => entry.eventType == 'sync_graph_max_retry_hit',
      );
      expect(entry.metadata['failure_type'], 'validationFailure');
      expect(entry.metadata['retryable'], isFalse);
    },
  );

  test(
    'malformed auth header failures are classified as non-retryable auth/config errors',
    () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final MemoryAppLogSink sink = MemoryAppLogSink();
      final StructuredAppLogger logger = StructuredAppLogger(
        sinks: <AppLogSink>[sink],
        enableInfoLogs: true,
      );
      addTearDown(logger.dispose);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'trusted-auth-header-tx',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 900,
      );
      await insertPayment(
        db,
        uuid: 'trusted-auth-header-payment',
        transactionId: transactionId,
        method: 'card',
        amountMinor: 900,
      );
      await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'trusted-auth-header-tx',
      );

      final SyncQueueRepository queueRepository = SyncQueueRepository(db);
      final SyncWorker worker = SyncWorker(
        syncQueueRepository: queueRepository,
        syncPayloadRepository: SyncPayloadRepository(db),
        remoteGateway: const _MalformedAuthRemoteGateway(),
        connectivityService: const _AlwaysOnlineConnectivityService(),
        logger: logger,
        pollInterval: const Duration(days: 1),
      );
      addTearDown(worker.dispose);

      await worker.runOnce();

      final items = await queueRepository.getMonitorItems(limit: 10);
      expect(items, hasLength(1));
      expect(items.single.attemptCount, 5);
      expect(
        items.single.errorMessage,
        contains('failure_type=authOrConfigFailure'),
      );
      final entry = sink.entries.lastWhere(
        (entry) => entry.eventType == 'sync_graph_max_retry_hit',
      );
      expect(entry.metadata['failure_type'], 'authOrConfigFailure');
      expect(entry.metadata['retryable'], isFalse);
    },
  );
}

class _AlwaysOnlineConnectivityService implements SyncConnectivityService {
  const _AlwaysOnlineConnectivityService();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> watchOnlineStatus() => const Stream<bool>.empty();
}

class _ValidationFailingRemoteGateway implements SyncRemoteGateway {
  const _ValidationFailingRemoteGateway();

  @override
  bool get isConfigured => true;

  @override
  String? get configurationIssue => null;

  @override
  Future<void> syncTransactionGraph(SyncTransactionGraph graph) {
    throw const MirrorWriteFailure(
      type: MirrorWriteFailureType.validationFailure,
      message: 'Payload rejected by trusted boundary',
      retryable: false,
    );
  }
}

class _MalformedAuthRemoteGateway implements SyncRemoteGateway {
  const _MalformedAuthRemoteGateway();

  @override
  bool get isConfigured => true;

  @override
  String? get configurationIssue => null;

  @override
  Future<void> syncTransactionGraph(SyncTransactionGraph graph) {
    throw const MirrorWriteFailure(
      type: MirrorWriteFailureType.authOrConfigFailure,
      message:
          'Trusted mirror boundary rejected a malformed Authorization header. Remove publishable/internal Bearer tokens.',
      retryable: false,
    );
  }
}
