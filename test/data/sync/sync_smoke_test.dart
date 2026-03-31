import 'dart:async';

import 'package:epos_app/core/config/app_config.dart';
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
import 'package:epos_app/data/sync/trusted_mirror_boundary_contract.dart';
import 'package:epos_app/domain/models/app_log_entry.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/sync_failure_details.dart';
import 'package:epos_app/domain/models/sync_queue_item.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../support/test_database.dart';
import '../../support/trusted_mirror_smoke_harness.dart';

void main() {
  group('Sync smoke', () {
    test(
      'paid checkout syncs a full transaction graph into remote mirror tables in dependency order',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final _SeededOrderGraph seeded = await _seedPaidOrder(
          db,
          syncQueueRepository: queueRepository,
          lineSpecs: const <_LineSpec>[
            _LineSpec(
              productName: 'Latte',
              priceMinor: 450,
              modifiers: <_ModifierSpec>[
                _ModifierSpec(
                  action: ModifierAction.add,
                  itemName: 'Extra Shot',
                  extraPriceMinor: 75,
                ),
              ],
            ),
          ],
        );
        final List<SyncQueueItem> queuedBeforeSync = await queueRepository
            .getMonitorItems(limit: 10);
        expect(queuedBeforeSync, hasLength(1));
        expect(queuedBeforeSync.single.tableName, 'transactions');
        expect(queuedBeforeSync.single.recordUuid, seeded.transaction.uuid);

        final TrustedMirrorSmokeHarness remoteMirror =
            TrustedMirrorSmokeHarness();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _trustedRemoteGateway(remoteMirror),
          connectivityService: const _AlwaysOnlineConnectivityService(),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();

        expect(remoteMirror.invocationOrders.single, <String>[
          'transactions',
          'transaction_lines',
          'order_modifiers',
          'payments',
        ]);

        final TrustedMirrorWriteSuccess success =
            remoteMirror.lastSuccess ??
            (throw StateError('Expected a trusted mirror success result.'));
        expect(success.transactionUuid, seeded.transaction.uuid);
        expect(success.mirroredRecords, 4);
        expect(
          success.tableResults
              .map(
                (TrustedMirrorTableWriteResult result) =>
                    '${result.tableName}:${result.status.name}:${result.recordCount}',
              )
              .toList(growable: false),
          <String>[
            'transactions:synced:1',
            'transaction_lines:synced:1',
            'order_modifiers:synced:1',
            'payments:synced:1',
          ],
        );

        final Map<String, Object?> remoteTransaction =
            remoteMirror.transaction(seeded.transaction.uuid) ??
            (throw StateError('Transaction missing from remote mirror.'));
        final Map<String, Object?> remoteLine =
            remoteMirror.transactionLine(seeded.lines.single.uuid) ??
            (throw StateError('Transaction line missing from remote mirror.'));
        final Map<String, Object?> remoteModifier =
            remoteMirror.orderModifier(seeded.modifiers.single.uuid) ??
            (throw StateError('Order modifier missing from remote mirror.'));
        final Map<String, Object?> remotePayment =
            remoteMirror.payment(seeded.payment!.uuid) ??
            (throw StateError('Payment missing from remote mirror.'));

        expect(remoteTransaction['uuid'], seeded.transaction.uuid);
        expect(remoteTransaction.containsKey('id'), isFalse);
        expect(remoteTransaction['status'], 'paid');
        expect(remoteTransaction['shift_local_id'], seeded.transaction.shiftId);
        expect(remoteTransaction['user_local_id'], seeded.transaction.userId);

        expect(remoteLine['uuid'], seeded.lines.single.uuid);
        expect(remoteLine['transaction_uuid'], seeded.transaction.uuid);
        expect(remoteLine['product_local_id'], seeded.lines.single.productId);
        expect(remoteLine.containsKey('transaction_id'), isFalse);

        expect(remoteModifier['uuid'], seeded.modifiers.single.uuid);
        expect(
          remoteModifier['transaction_line_uuid'],
          seeded.lines.single.uuid,
        );

        expect(remotePayment['uuid'], seeded.payment!.uuid);
        expect(remotePayment['transaction_uuid'], seeded.transaction.uuid);
        expect(remotePayment.containsKey('transaction_id'), isFalse);

        final ({int pendingCount, int failedCount}) counts =
            await queueRepository.getMonitorCounts();
        expect(counts.pendingCount, 0);
        expect(counts.failedCount, 0);
      },
    );

    test(
      'brand new paid root transitions pending to processing to synced without inheriting stale failure metadata',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final MemoryAppLogSink sink = MemoryAppLogSink();
        final StructuredAppLogger logger = StructuredAppLogger(
          sinks: <AppLogSink>[sink],
          enableInfoLogs: true,
        );
        addTearDown(logger.dispose);

        await insertSyncQueueItem(
          db,
          tableName: 'transactions',
          recordUuid: 'historical-blocked-root',
          status: 'failed',
          attemptCount: 5,
          errorMessage:
              'failure_type=authOrConfigFailure|retryable=false|table=transactions|record_uuid=historical-blocked-root|record_uuids=-|issues=-|message=Trusted mirror boundary rejected the configured internal key.',
        );

        final _SeededOrderGraph seeded = await _seedPaidOrder(
          db,
          syncQueueRepository: queueRepository,
          logger: logger,
        );
        final SyncQueueItem queuedRoot =
            (await queueRepository.getLatestItemForRecord(
              tableName: 'transactions',
              recordUuid: seeded.transaction.uuid,
            )) ??
            (throw StateError('Expected queued root item.'));

        expect(queuedRoot.status, SyncQueueStatus.pending);
        expect(queuedRoot.attemptCount, 0);
        expect(queuedRoot.errorMessage, isNull);
        final SyncQueueItem staleFailedRoot =
            (await queueRepository.getLatestItemForRecord(
              tableName: 'transactions',
              recordUuid: 'historical-blocked-root',
            )) ??
            (throw StateError('Expected stale blocked root item.'));
        expect(staleFailedRoot.status, SyncQueueStatus.failed);

        final AppLogEntry enqueueLog = sink.entries.lastWhere(
          (AppLogEntry entry) =>
              entry.eventType == 'sync_queue_root_enqueued' &&
              entry.entityId == seeded.transaction.uuid,
        );
        expect(enqueueLog.metadata['queue_row_id'], queuedRoot.id);
        expect(enqueueLog.metadata['previous_status'], 'none');
        expect(enqueueLog.metadata['new_status'], 'pending');

        final TrustedMirrorSmokeHarness remoteMirror =
            TrustedMirrorSmokeHarness();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _trustedRemoteGateway(remoteMirror),
          connectivityService: const _AlwaysOnlineConnectivityService(),
          logger: logger,
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();

        final SyncQueueItem syncedRoot =
            (await queueRepository.getLatestItemForRecord(
              tableName: 'transactions',
              recordUuid: seeded.transaction.uuid,
            )) ??
            (throw StateError('Expected synced root item.'));
        expect(syncedRoot.id, queuedRoot.id);
        expect(syncedRoot.status, SyncQueueStatus.synced);
        expect(syncedRoot.errorMessage, isNull);
        expect(syncedRoot.syncedAt, isNotNull);

        final AppLogEntry claimLog = sink.entries.lastWhere(
          (AppLogEntry entry) =>
              entry.eventType == 'sync_queue_root_claimed' &&
              entry.entityId == seeded.transaction.uuid,
        );
        expect(claimLog.metadata['queue_row_id'], queuedRoot.id);
        expect(claimLog.metadata['previous_status'], 'pending');
        expect(claimLog.metadata['new_status'], 'processing');

        final AppLogEntry successLog = sink.entries.lastWhere(
          (AppLogEntry entry) =>
              entry.eventType == 'sync_graph_succeeded' &&
              entry.entityId == seeded.transaction.uuid,
        );
        expect(successLog.metadata['queue_row_id'], queuedRoot.id);
        expect(successLog.metadata['previous_status'], 'processing');
        expect(successLog.metadata['new_status'], 'synced');
      },
    );

    test(
      'duplicate replay is idempotent and keeps queue plus remote state stable',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final _SeededOrderGraph seeded = await _seedPaidOrder(
          db,
          syncQueueRepository: queueRepository,
        );
        final MemoryAppLogSink sink = MemoryAppLogSink();
        final StructuredAppLogger logger = StructuredAppLogger(
          sinks: <AppLogSink>[sink],
          enableInfoLogs: true,
        );
        addTearDown(logger.dispose);
        final TrustedMirrorSmokeHarness remoteMirror =
            TrustedMirrorSmokeHarness();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _trustedRemoteGateway(remoteMirror),
          connectivityService: const _AlwaysOnlineConnectivityService(),
          logger: logger,
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();
        await queueRepository.addToQueue(
          'transactions',
          seeded.transaction.uuid,
        );
        await worker.runOnce();
        await _waitUntil(
          () => sink.entries.where(_isSyncGraphSuccess).length >= 2,
        );

        expect(remoteMirror.invocationOrders, hasLength(2));
        expect(remoteMirror.transactionCount, 1);
        expect(remoteMirror.transactionLineCount, 1);
        expect(remoteMirror.orderModifierCount, 0);
        expect(remoteMirror.paymentCount, 1);

        final ({int pendingCount, int failedCount}) counts =
            await queueRepository.getMonitorCounts();
        expect(counts.pendingCount, 0);
        expect(counts.failedCount, 0);

        final List<AppLogEntry> successLogs = sink.entries
            .where(_isSyncGraphSuccess)
            .toList(growable: false);
        expect(successLogs, hasLength(2));
        expect(successLogs.last.metadata['tables_synced'], <String>[
          'transactions',
          'transaction_lines',
          'payments',
        ]);
        expect(successLogs.last.metadata['table_record_counts'], <String, int>{
          'transactions': 1,
          'transaction_lines': 1,
          'payments': 1,
        });
      },
    );

    test(
      'partial remote failure logs the failing table and retry completes the graph consistently',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final _SeededOrderGraph seeded = await _seedPaidOrder(
          db,
          syncQueueRepository: queueRepository,
          lineSpecs: const <_LineSpec>[
            _LineSpec(
              productName: 'Latte',
              priceMinor: 450,
              modifiers: <_ModifierSpec>[
                _ModifierSpec(
                  action: ModifierAction.add,
                  itemName: 'Extra Shot',
                  extraPriceMinor: 75,
                ),
              ],
            ),
          ],
        );
        final MemoryAppLogSink sink = MemoryAppLogSink();
        final StructuredAppLogger logger = StructuredAppLogger(
          sinks: <AppLogSink>[sink],
          enableInfoLogs: true,
        );
        addTearDown(logger.dispose);
        final TrustedMirrorSmokeHarness remoteMirror =
            TrustedMirrorSmokeHarness(
              transientFailuresBeforeSuccess: <String, int>{
                'payments:${seeded.payment!.uuid}': 1,
              },
            );
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _trustedRemoteGateway(remoteMirror),
          connectivityService: const _AlwaysOnlineConnectivityService(),
          logger: logger,
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();
        await _waitUntil(
          () => sink.entries.any(
            (AppLogEntry entry) => entry.eventType == 'sync_graph_failed',
          ),
        );

        expect(remoteMirror.transactionCount, 1);
        expect(remoteMirror.transactionLineCount, 1);
        expect(remoteMirror.orderModifierCount, 1);
        expect(remoteMirror.paymentCount, 0);

        final ({int pendingCount, int failedCount}) failedCounts =
            await queueRepository.getMonitorCounts();
        expect(failedCounts.pendingCount, 0);
        expect(failedCounts.failedCount, 1);

        final List<SyncQueueItem> failedItems = await queueRepository
            .getMonitorItems(limit: 10);
        expect(failedItems.single.errorMessage, contains('payments'));
        expect(failedItems.single.errorMessage, contains(seeded.payment!.uuid));
        expect(
          failedItems.single.errorMessage,
          contains('Transient remote failure before mirroring'),
        );
        expect(
          failedItems.single.failureDetails?.failureKind,
          SyncFailureKind.remoteServerError,
        );
        expect(
          failedItems.single.failureDetails?.failureKind,
          isNot(SyncFailureKind.localGraphDrift),
        );

        final AppLogEntry failureLog = sink.entries.lastWhere(
          (AppLogEntry entry) => entry.eventType == 'sync_graph_failed',
        );
        expect(failureLog.metadata['table_name'], 'payments');
        expect(failureLog.metadata['record_uuid'], seeded.payment!.uuid);
        expect(failureLog.metadata['failure_type'], 'remoteServerError');
        expect(failureLog.metadata['retryable'], isTrue);

        await worker.retryAllFailed();
        await _waitUntil(
          () => sink.entries.where(_isSyncGraphSuccess).isNotEmpty,
        );

        expect(remoteMirror.transactionCount, 1);
        expect(remoteMirror.transactionLineCount, 1);
        expect(remoteMirror.orderModifierCount, 1);
        expect(remoteMirror.paymentCount, 1);
        expect(remoteMirror.invocationOrders, hasLength(2));

        final ({int pendingCount, int failedCount}) finalCounts =
            await queueRepository.getMonitorCounts();
        expect(finalCounts.pendingCount, 0);
        expect(finalCounts.failedCount, 0);
      },
    );

    test(
      'graph drift blocks replay before any remote write and surfaces checksum metadata',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final _SeededOrderGraph seeded = await _seedPaidOrder(
          db,
          syncQueueRepository: queueRepository,
        );
        final MemoryAppLogSink sink = MemoryAppLogSink();
        final StructuredAppLogger logger = StructuredAppLogger(
          sinks: <AppLogSink>[sink],
          enableInfoLogs: true,
        );
        addTearDown(logger.dispose);
        final TrustedMirrorSmokeHarness remoteMirror =
            TrustedMirrorSmokeHarness();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _trustedRemoteGateway(remoteMirror),
          connectivityService: const _AlwaysOnlineConnectivityService(),
          logger: logger,
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await db.customStatement(
          '''
          UPDATE transaction_lines
          SET product_name = ?
          WHERE uuid = ?
          ''',
          <Object>['Corrupted Product', seeded.lines.single.uuid],
        );

        await worker.runOnce();
        await _waitUntil(
          () => sink.entries.any(
            (AppLogEntry entry) =>
                entry.eventType == 'sync_graph_max_retry_hit',
          ),
        );

        expect(remoteMirror.writeOrder, isEmpty);
        expect(remoteMirror.transactionCount, 0);
        expect(remoteMirror.transactionLineCount, 0);
        expect(remoteMirror.orderModifierCount, 0);
        expect(remoteMirror.paymentCount, 0);

        final List<SyncQueueItem> failedItems = await queueRepository
            .getMonitorItems(limit: 10);
        expect(failedItems, hasLength(1));
        expect(failedItems.single.attemptCount, 5);
        expect(
          failedItems.single.failureDetails?.failureKind,
          SyncFailureKind.localGraphDrift,
        );
        expect(failedItems.single.failureDetails?.retryable, isFalse);
        expect(
          failedItems.single.failureDetails?.recordUuid,
          seeded.transaction.uuid,
        );
        expect(
          failedItems.single.failureDetails?.issues,
          contains(startsWith('expected_checksum=')),
        );
        expect(
          failedItems.single.failureDetails?.issues,
          contains(startsWith('current_checksum=')),
        );

        final AppLogEntry failureLog = sink.entries.lastWhere(
          (AppLogEntry entry) => entry.eventType == 'sync_graph_max_retry_hit',
        );
        expect(failureLog.metadata['failure_type'], 'localGraphDrift');
        expect(failureLog.metadata['retryable'], isFalse);
        expect(failureLog.metadata['record_uuid'], seeded.transaction.uuid);
      },
    );

    test(
      'cancelled transaction syncs without payments and reports payments as skipped',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final _SeededOrderGraph seeded = await _seedCancelledOrder(
          db,
          syncQueueRepository: queueRepository,
        );
        final TrustedMirrorSmokeHarness remoteMirror =
            TrustedMirrorSmokeHarness();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _trustedRemoteGateway(remoteMirror),
          connectivityService: const _AlwaysOnlineConnectivityService(),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();

        final Map<String, Object?> remoteTransaction =
            remoteMirror.transaction(seeded.transaction.uuid) ??
            (throw StateError('Cancelled transaction missing from mirror.'));
        expect(remoteTransaction['status'], 'cancelled');
        expect(
          remoteTransaction['cancelled_by_local_id'],
          seeded.transaction.cancelledBy,
        );
        expect(remoteMirror.paymentCount, 0);
        expect(remoteMirror.payment('missing-payment'), isNull);
        expect(
          remoteMirror.lastSuccess?.tableResults
              .singleWhere(
                (TrustedMirrorTableWriteResult result) =>
                    result.tableName == 'payments',
              )
              .status,
          TrustedMirrorTableWriteStatus.skipped,
        );

        final ({int pendingCount, int failedCount}) counts =
            await queueRepository.getMonitorCounts();
        expect(counts.pendingCount, 0);
        expect(counts.failedCount, 0);
      },
    );

    test(
      'multi-line graph with mixed modifiers preserves UUID relationships and table counts',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        final _SeededOrderGraph seeded = await _seedPaidOrder(
          db,
          syncQueueRepository: queueRepository,
          lineSpecs: const <_LineSpec>[
            _LineSpec(
              productName: 'Latte',
              priceMinor: 450,
              modifiers: <_ModifierSpec>[
                _ModifierSpec(
                  action: ModifierAction.add,
                  itemName: 'Extra Shot',
                  extraPriceMinor: 75,
                ),
                _ModifierSpec(
                  action: ModifierAction.remove,
                  itemName: 'Foam',
                  extraPriceMinor: 0,
                ),
              ],
            ),
            _LineSpec(productName: 'Brownie', priceMinor: 325),
          ],
        );
        final TrustedMirrorSmokeHarness remoteMirror =
            TrustedMirrorSmokeHarness();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _trustedRemoteGateway(remoteMirror),
          connectivityService: const _AlwaysOnlineConnectivityService(),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();

        expect(remoteMirror.invocationOrders.single, <String>[
          'transactions',
          'transaction_lines',
          'order_modifiers',
          'payments',
        ]);
        expect(remoteMirror.transactionLineCount, 2);
        expect(remoteMirror.orderModifierCount, 2);
        expect(
          remoteMirror.lastSuccess?.tableResults
              .map((TrustedMirrorTableWriteResult result) => result.recordCount)
              .toList(growable: false),
          <int>[1, 2, 2, 1],
        );

        final Map<String, Object?> firstLine =
            remoteMirror.transactionLine(seeded.lines.first.uuid) ??
            (throw StateError('First line missing from remote mirror.'));
        final Map<String, Object?> secondLine =
            remoteMirror.transactionLine(seeded.lines.last.uuid) ??
            (throw StateError('Second line missing from remote mirror.'));
        expect(firstLine['transaction_uuid'], seeded.transaction.uuid);
        expect(secondLine['transaction_uuid'], seeded.transaction.uuid);

        final List<Map<String, Object?>> mirroredModifiers = seeded.modifiers
            .map(
              (OrderModifier modifier) =>
                  remoteMirror.orderModifier(modifier.uuid) ??
                  (throw StateError('Modifier missing from remote mirror.')),
            )
            .toList(growable: false);
        expect(
          mirroredModifiers
              .map(
                (Map<String, Object?> payload) =>
                    payload['transaction_line_uuid'],
              )
              .toSet(),
          <String>{seeded.lines.first.uuid},
        );
      },
    );

    test(
      'paid checkout without modifiers reports order_modifiers as skipped',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final SyncQueueRepository queueRepository = SyncQueueRepository(db);
        await _seedPaidOrder(db, syncQueueRepository: queueRepository);
        final TrustedMirrorSmokeHarness remoteMirror =
            TrustedMirrorSmokeHarness();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: queueRepository,
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: _trustedRemoteGateway(remoteMirror),
          connectivityService: const _AlwaysOnlineConnectivityService(),
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.runOnce();

        expect(
          remoteMirror.lastSuccess?.tableResults
              .singleWhere(
                (TrustedMirrorTableWriteResult result) =>
                    result.tableName == 'order_modifiers',
              )
              .status,
          TrustedMirrorTableWriteStatus.skipped,
        );
      },
    );
  });
}

class _SeededOrderGraph {
  const _SeededOrderGraph({
    required this.transaction,
    required this.lines,
    required this.modifiers,
    required this.payment,
  });

  final Transaction transaction;
  final List<TransactionLine> lines;
  final List<OrderModifier> modifiers;
  final Payment? payment;
}

class _LineSpec {
  const _LineSpec({
    required this.productName,
    required this.priceMinor,
    this.modifiers = const <_ModifierSpec>[],
  });

  final String productName;
  final int priceMinor;
  final List<_ModifierSpec> modifiers;
}

class _ModifierSpec {
  const _ModifierSpec({
    required this.action,
    required this.itemName,
    required this.extraPriceMinor,
  });

  final ModifierAction action;
  final String itemName;
  final int extraPriceMinor;
}

class _AlwaysOnlineConnectivityService implements SyncConnectivityService {
  const _AlwaysOnlineConnectivityService();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> watchOnlineStatus() => const Stream<bool>.empty();
}

SyncRemoteGateway _trustedRemoteGateway(TrustedMirrorSmokeHarness invoker) {
  return SupabaseSyncService(
    client: SupabaseClient('https://example.supabase.co', 'anon-key'),
    config: AppConfig.fromValues(
      environment: 'test',
      appVersion: 'test',
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      mirrorWriteMode: MirrorWriteMode.trustedSyncBoundary,
    ),
    trustedBoundaryInvoker: invoker,
  );
}

Future<_SeededOrderGraph> _seedPaidOrder(
  AppDatabase db, {
  required SyncQueueRepository syncQueueRepository,
  AppLogger logger = const NoopAppLogger(),
  List<_LineSpec> lineSpecs = const <_LineSpec>[
    _LineSpec(productName: 'Latte', priceMinor: 450),
  ],
}) async {
  final _FixtureContext fixture = await _createFixtureContext(
    db,
    syncQueueRepository: syncQueueRepository,
    lineSpecs: lineSpecs,
    logger: logger,
  );

  final List<OrderModifier> modifiers = <OrderModifier>[];
  for (int index = 0; index < fixture.lines.length; index += 1) {
    for (final _ModifierSpec modifierSpec in lineSpecs[index].modifiers) {
      modifiers.add(
        await fixture.orderService.addModifierToLine(
          transactionLineId: fixture.lines[index].id,
          action: modifierSpec.action,
          itemName: modifierSpec.itemName,
          extraPriceMinor: modifierSpec.extraPriceMinor,
        ),
      );
    }
  }
  await fixture.orderService.sendOrder(
    transactionId: fixture.createdTransaction.id,
    currentUser: fixture.cashierUser,
  );
  final Payment payment = await fixture.orderService.markOrderPaid(
    transactionId: fixture.createdTransaction.id,
    method: PaymentMethod.card,
    currentUser: fixture.cashierUser,
  );
  final Transaction paidTransaction =
      await fixture.transactionRepository.getById(
        fixture.createdTransaction.id,
      ) ??
      (throw StateError('Expected paid transaction.'));

  return _SeededOrderGraph(
    transaction: paidTransaction,
    lines: fixture.lines,
    modifiers: modifiers,
    payment: payment,
  );
}

Future<_SeededOrderGraph> _seedCancelledOrder(
  AppDatabase db, {
  required SyncQueueRepository syncQueueRepository,
}) async {
  final _FixtureContext fixture = await _createFixtureContext(
    db,
    syncQueueRepository: syncQueueRepository,
    lineSpecs: const <_LineSpec>[
      _LineSpec(productName: 'Latte', priceMinor: 450),
    ],
  );
  await fixture.orderService.sendOrder(
    transactionId: fixture.createdTransaction.id,
    currentUser: fixture.cashierUser,
  );
  await fixture.orderService.cancelOrder(
    transactionId: fixture.createdTransaction.id,
    currentUser: fixture.cashierUser,
  );
  final Transaction cancelledTransaction =
      await fixture.transactionRepository.getById(
        fixture.createdTransaction.id,
      ) ??
      (throw StateError('Expected cancelled transaction.'));

  return _SeededOrderGraph(
    transaction: cancelledTransaction,
    lines: fixture.lines,
    modifiers: const <OrderModifier>[],
    payment: null,
  );
}

Future<_FixtureContext> _createFixtureContext(
  AppDatabase db, {
  required SyncQueueRepository syncQueueRepository,
  required List<_LineSpec> lineSpecs,
  AppLogger logger = const NoopAppLogger(),
}) async {
  final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: adminId);
  final int categoryId = await insertCategory(db, name: 'Coffee');
  final List<int> productIds = <int>[];
  for (int index = 0; index < lineSpecs.length; index += 1) {
    productIds.add(
      await insertProduct(
        db,
        categoryId: categoryId,
        name: lineSpecs[index].productName,
        priceMinor: lineSpecs[index].priceMinor,
      ),
    );
  }

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
    logger: logger,
  );

  final Transaction createdTransaction = await orderService.createOrder(
    currentUser: cashierUser,
  );
  final List<TransactionLine> lines = <TransactionLine>[];
  for (int index = 0; index < productIds.length; index += 1) {
    lines.add(
      await orderService.addProductToOrder(
        transactionId: createdTransaction.id,
        productId: productIds[index],
      ),
    );
  }

  return _FixtureContext(
    cashierUser: cashierUser,
    createdTransaction: createdTransaction,
    lines: lines,
    orderService: orderService,
    transactionRepository: transactionRepository,
  );
}

class _FixtureContext {
  const _FixtureContext({
    required this.cashierUser,
    required this.createdTransaction,
    required this.lines,
    required this.orderService,
    required this.transactionRepository,
  });

  final User cashierUser;
  final Transaction createdTransaction;
  final List<TransactionLine> lines;
  final OrderService orderService;
  final TransactionRepository transactionRepository;
}

bool _isSyncGraphSuccess(AppLogEntry entry) =>
    entry.eventType == 'sync_graph_succeeded';

Future<void> _waitUntil(
  FutureOr<bool> Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!await condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Condition was not met before timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
