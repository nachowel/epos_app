import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/data/repositories/cash_movement_repository.dart';
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/sync_queue_repository.dart';
import 'package:epos_app/data/repositories/system_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/sync_failure_details.dart';
import 'package:epos_app/domain/models/sync_graph_requeue_result.dart';
import 'package:epos_app/domain/models/sync_queue_item.dart';
import 'package:epos_app/domain/models/sync_runtime_state.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/admin_service.dart';
import 'package:epos_app/domain/services/cash_movement_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'getLatestFailedItem prefers the transaction root row for a shared graph failure batch',
    () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      const String transactionUuid = 'tx-root-shared-failure';
      const String paymentUuid = 'payment-shared-failure';
      const String failureMessage =
          'failure_type=remoteServerError|retryable=true|table=order_modifiers|record_uuid=-|record_uuids=modifier-a,modifier-b|issues=-|message=Failed to mirror order modifier snapshots';
      final DateTime createdAt = DateTime(2026, 4, 8, 17, 56);
      final DateTime lastAttemptAt = DateTime(2026, 4, 8, 17, 56, 45);

      final int transactionRowId = await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: transactionUuid,
        status: 'failed',
        attemptCount: 5,
        errorMessage: failureMessage,
      );
      final int lineRowId = await insertSyncQueueItem(
        db,
        tableName: 'transaction_lines',
        recordUuid: 'line-shared-failure',
        status: 'failed',
        attemptCount: 5,
        errorMessage: failureMessage,
      );
      final int modifierRowId = await insertSyncQueueItem(
        db,
        tableName: 'order_modifiers',
        recordUuid: 'modifier-shared-failure',
        status: 'failed',
        attemptCount: 5,
        errorMessage: failureMessage,
      );
      final int paymentRowId = await insertSyncQueueItem(
        db,
        tableName: 'payments',
        recordUuid: paymentUuid,
        status: 'failed',
        attemptCount: 5,
        errorMessage: failureMessage,
      );

      await (db.update(db.syncQueue)..where((table) => table.id.isIn(<int>[
            transactionRowId,
            lineRowId,
            modifierRowId,
            paymentRowId,
          ]))).write(
        app_db.SyncQueueCompanion(
          createdAt: Value<DateTime>(createdAt),
          lastAttemptAt: Value<DateTime>(lastAttemptAt),
        ),
      );

      final SyncQueueItem? item = await SyncQueueRepository(
        db,
      ).getLatestFailedItem();

      expect(item, isNotNull);
      expect(item!.tableName, 'transactions');
      expect(item.recordUuid, transactionUuid);
    },
  );

  test('getMonitorItems returns newest queue rows first', () async {
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final int olderId = await insertSyncQueueItem(
      db,
      tableName: 'transactions',
      recordUuid: 'older-root',
      status: 'failed',
      attemptCount: 1,
      errorMessage:
          'failure_type=remoteServerError|retryable=true|table=transactions|record_uuid=older-root|record_uuids=-|issues=-|message=timeout',
    );
    final int newerId = await insertSyncQueueItem(
      db,
      tableName: 'transactions',
      recordUuid: 'newer-root',
      status: 'failed',
      attemptCount: 1,
      errorMessage:
          'failure_type=remoteServerError|retryable=true|table=transactions|record_uuid=newer-root|record_uuids=-|issues=-|message=timeout',
    );

    await (db.update(
      db.syncQueue,
    )..where((table) => table.id.equals(olderId))).write(
      app_db.SyncQueueCompanion(
        createdAt: Value<DateTime>(DateTime(2026, 4, 6, 20, 52)),
      ),
    );
    await (db.update(
      db.syncQueue,
    )..where((table) => table.id.equals(newerId))).write(
      app_db.SyncQueueCompanion(
        createdAt: Value<DateTime>(DateTime(2026, 4, 8, 17, 56)),
      ),
    );

    final List<SyncQueueItem> items = await SyncQueueRepository(
      db,
    ).getMonitorItems(limit: 10);

    expect(items, hasLength(2));
    expect(items.first.recordUuid, 'newer-root');
    expect(items.last.recordUuid, 'older-root');
  });

  test(
    'sync monitor snapshot keeps runtime error separate from historical failed queue rows',
    () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'historical-auth-failure',
        status: 'failed',
        attemptCount: 5,
        errorMessage:
            'failure_type=authOrConfigFailure|retryable=false|table=transactions|record_uuid=historical-auth-failure|record_uuids=-|issues=-|message=Trusted mirror boundary rejected the configured internal key.',
      );

      final AdminService service = _makeAdminService(db);
      final snapshot = await service.getSyncMonitorSnapshot(
        user: _adminUser(adminId),
        runtimeState: const SyncRuntimeState.initial(),
      );

      expect(snapshot.lastError, isNull);
      expect(snapshot.lastFailedItem?.recordUuid, 'historical-auth-failure');
      expect(
        snapshot.lastFailedItem?.failureDetails?.failureKind,
        SyncFailureKind.authOrConfigFailure,
      );
    },
  );

  test(
    'resetBlockedTrustedSyncFailures resets only auth/config and validation rows',
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
      final int authId = await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'auth-blocked',
        status: 'failed',
        attemptCount: 5,
        errorMessage:
            'failure_type=authOrConfigFailure|retryable=false|table=transactions|record_uuid=auth-blocked|record_uuids=-|issues=-|message=key rejected',
      );
      final int validationId = await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'validation-blocked',
        status: 'failed',
        attemptCount: 5,
        errorMessage:
            'failure_type=validationFailure|retryable=false|table=transactions|record_uuid=validation-blocked|record_uuids=-|issues=payments.method|message=bad payload',
      );
      final int retryableId = await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'retryable-failure',
        status: 'failed',
        attemptCount: 2,
        errorMessage:
            'failure_type=remoteServerError|retryable=true|table=transactions|record_uuid=retryable-failure|record_uuids=-|issues=-|message=timeout',
      );

      final AdminService service = _makeAdminService(db, logger: logger);
      final result = await service.resetBlockedTrustedSyncFailures(
        user: _adminUser(adminId),
      );

      expect(result.resetCount, 2);
      expect(result.skippedCount, 1);

      final SyncQueueRepository queueRepository = SyncQueueRepository(db);
      final authItem = await queueRepository.getLatestItemForRecord(
        tableName: 'transactions',
        recordUuid: 'auth-blocked',
      );
      final validationItem = await queueRepository.getLatestItemForRecord(
        tableName: 'transactions',
        recordUuid: 'validation-blocked',
      );
      final retryableItem = await queueRepository.getLatestItemForRecord(
        tableName: 'transactions',
        recordUuid: 'retryable-failure',
      );

      expect(authItem?.id, authId);
      expect(authItem?.status.name, 'pending');
      expect(authItem?.attemptCount, 0);
      expect(authItem?.errorMessage, isNull);

      expect(validationItem?.id, validationId);
      expect(validationItem?.status.name, 'pending');
      expect(validationItem?.attemptCount, 0);
      expect(validationItem?.errorMessage, isNull);

      expect(retryableItem?.id, retryableId);
      expect(retryableItem?.status.name, 'failed');
      expect(retryableItem?.attemptCount, 2);

      final resetEvents = sink.entries
          .where(
            (entry) =>
                entry.eventType == 'admin_sync_blocked_failure_evaluated',
          )
          .toList(growable: false);
      expect(resetEvents, hasLength(3));
      expect(
        resetEvents.where(
          (entry) => entry.metadata['reset_for_retest'] == true,
        ),
        hasLength(2),
      );
    },
  );

  test(
    'retryAllSyncItems keeps blocked failures skipped and logs the decision',
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
      await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'blocked-auth',
        status: 'failed',
        attemptCount: 5,
        errorMessage:
            'failure_type=authOrConfigFailure|retryable=false|table=transactions|record_uuid=blocked-auth|record_uuids=-|issues=-|message=key rejected',
      );
      await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: 'retryable-remote',
        status: 'failed',
        attemptCount: 1,
        errorMessage:
            'failure_type=remoteServerError|retryable=true|table=transactions|record_uuid=retryable-remote|record_uuids=-|issues=-|message=timeout',
      );

      final AdminService service = _makeAdminService(db, logger: logger);
      final result = await service.retryAllSyncItems(user: _adminUser(adminId));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(result.retriedCount, 1);
      expect(result.skippedCount, 1);
      expect(result.skippedNonRetryableCount, 1);

      final decisionEvents = sink.entries
          .where(
            (entry) => entry.eventType == 'admin_sync_retry_all_item_evaluated',
          )
          .toList(growable: false);
      expect(decisionEvents, hasLength(2));
      expect(
        decisionEvents
            .firstWhere((entry) => entry.entityId == 'blocked-auth')
            .metadata['retry_all_action'],
        'skip',
      );
      expect(
        decisionEvents
            .firstWhere((entry) => entry.entityId == 'retryable-remote')
            .metadata['retry_all_action'],
        'reset',
      );
    },
  );

  test(
    'requeueTransactionGraphFromCurrentSnapshot creates fresh pending rows and leaves stale failed root untouched',
    () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final _TerminalSyncFixture fixture = await _createTerminalSyncFixture(
        db,
        transactionUuid: 'tx-requeue-root',
        userId: adminId,
      );
      final int staleRootId = await insertSyncQueueItem(
        db,
        tableName: 'transactions',
        recordUuid: fixture.transactionUuid,
        status: 'failed',
        attemptCount: 5,
        errorMessage:
            'failure_type=localGraphDrift|retryable=false|table=transactions|record_uuid=tx-requeue-root|record_uuids=-|issues=expected_checksum=a,current_checksum=b|message=drift',
      );

      final AdminService service = _makeAdminService(db);
      final SyncGraphRequeueResult result = await service
          .requeueTransactionGraphFromCurrentSnapshot(
            user: _adminUser(adminId),
            transactionUuid: fixture.transactionUuid,
          );

      expect(result.rootRecordUuid, fixture.transactionUuid);
      expect(result.rootQueueId, greaterThan(staleRootId));
      expect(
        result.transactionIdempotencyKey,
        'idem-${fixture.transactionUuid}',
      );
      expect(result.createdItems, hasLength(4));

      final app_db.SyncQueueData staleRoot =
          await (db.select(db.syncQueue)
                ..where((app_db.$SyncQueueTable t) => t.id.equals(staleRootId)))
              .getSingle();
      expect(staleRoot.status, 'failed');
      expect(staleRoot.attemptCount, 5);

      final SyncQueueRepository queueRepository = SyncQueueRepository(db);
      final SyncQueueItem? latestRoot = await queueRepository
          .getLatestItemForRecord(
            tableName: 'transactions',
            recordUuid: fixture.transactionUuid,
          );
      expect(latestRoot, isNotNull);
      expect(latestRoot!.id, result.rootQueueId);
      expect(latestRoot.status.name, 'pending');
      expect(latestRoot.attemptCount, 0);

      final Set<String> createdRefs = result.createdItems
          .map((item) => '${item.tableName}:${item.recordUuid}')
          .toSet();
      expect(
        createdRefs,
        containsAll(<String>{
          'transactions:${fixture.transactionUuid}',
          'transaction_lines:${fixture.lineUuid}',
          'order_modifiers:${fixture.modifierUuid}',
          'payments:${fixture.paymentUuid}',
        }),
      );

      final String? checksum = await queueRepository.getTransactionRootChecksum(
        result.rootQueueId,
      );
      expect(checksum, isNotNull);
      expect(checksum, isNotEmpty);
    },
  );

  test(
    'requeueTransactionGraphFromCurrentSnapshot blocks when active queue items already exist for the graph',
    () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final _TerminalSyncFixture fixture = await _createTerminalSyncFixture(
        db,
        transactionUuid: 'tx-requeue-blocked',
        userId: adminId,
      );
      await insertSyncQueueItem(
        db,
        tableName: 'transaction_lines',
        recordUuid: fixture.lineUuid,
        status: 'pending',
      );

      final AdminService service = _makeAdminService(db);

      await expectLater(
        service.requeueTransactionGraphFromCurrentSnapshot(
          user: _adminUser(adminId),
          transactionUuid: fixture.transactionUuid,
        ),
        throwsA(isA<ValidationException>()),
      );
    },
  );
}

AdminService _makeAdminService(AppDatabase db, {AppLogger? logger}) {
  final ShiftRepository shiftRepository = ShiftRepository(db);
  final TransactionRepository transactionRepository = TransactionRepository(db);
  final SettingsRepository settingsRepository = SettingsRepository(db);
  final ShiftSessionService shiftSessionService = ShiftSessionService(
    shiftRepository,
  );
  return AdminService(
    categoryRepository: CategoryRepository(db),
    productRepository: ProductRepository(db),
    breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
    modifierRepository: ModifierRepository(db),
    shiftRepository: shiftRepository,
    transactionRepository: transactionRepository,
    syncQueueRepository: SyncQueueRepository(db),
    settingsRepository: settingsRepository,
    systemRepository: SystemRepository(
      db,
      databaseFileResolver: () async =>
          throw UnsupportedError('No file export in this test.'),
    ),
    reportService: ReportService(
      shiftRepository: shiftRepository,
      shiftSessionService: shiftSessionService,
      transactionRepository: transactionRepository,
      paymentRepository: PaymentRepository(db),
      settingsRepository: settingsRepository,
      reportVisibilityService: const ReportVisibilityService(),
    ),
    shiftSessionService: shiftSessionService,
    cashMovementService: CashMovementService(
      cashMovementRepository: CashMovementRepository(db),
      shiftSessionService: shiftSessionService,
    ),
    printerService: PrinterService(
      transactionRepository,
      paymentRepository: PaymentRepository(db),
      settingsRepository: settingsRepository,
    ),
    appConfig: AppConfig.fromValues(environment: 'test', appVersion: 'test'),
    logger: logger ?? const NoopAppLogger(),
  );
}

User _adminUser(int id) {
  return User(
    id: id,
    name: 'Admin',
    pin: null,
    password: null,
    role: UserRole.admin,
    isActive: true,
    createdAt: DateTime.now(),
  );
}

class _TerminalSyncFixture {
  const _TerminalSyncFixture({
    required this.transactionUuid,
    required this.lineUuid,
    required this.modifierUuid,
    required this.paymentUuid,
  });

  final String transactionUuid;
  final String lineUuid;
  final String modifierUuid;
  final String paymentUuid;
}

Future<_TerminalSyncFixture> _createTerminalSyncFixture(
  AppDatabase db, {
  required String transactionUuid,
  required int userId,
}) async {
  final int shiftId = await insertShift(db, openedBy: userId);
  final int categoryId = await insertCategory(db, name: 'Mains');
  final int productId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Burger',
    priceMinor: 1000,
    hasModifiers: true,
  );
  final int transactionId = await insertTransaction(
    db,
    uuid: transactionUuid,
    shiftId: shiftId,
    userId: userId,
    status: 'paid',
    totalAmountMinor: 1100,
    paidAt: DateTime.now(),
  );

  const String lineUuid = 'line-sync-requeue';
  const String modifierUuid = 'modifier-sync-requeue';
  const String paymentUuid = 'payment-sync-requeue';

  final int lineId = await db
      .into(db.transactionLines)
      .insert(
        app_db.TransactionLinesCompanion.insert(
          uuid: lineUuid,
          transactionId: transactionId,
          productId: productId,
          productName: 'Burger',
          unitPriceMinor: 1000,
          quantity: const Value<int>(1),
          lineTotalMinor: 1100,
        ),
      );

  await db
      .into(db.orderModifiers)
      .insert(
        app_db.OrderModifiersCompanion.insert(
          uuid: modifierUuid,
          transactionLineId: lineId,
          action: 'add',
          itemName: 'Chips',
          quantity: const Value<int>(1),
          itemProductId: const Value<int?>(null),
          sourceGroupId: const Value<int?>(null),
          extraPriceMinor: const Value<int>(100),
          chargeReason: const Value<String?>(null),
          unitPriceMinor: const Value<int>(100),
          priceEffectMinor: const Value<int>(100),
          sortKey: const Value<int>(0),
        ),
      );

  await insertPayment(
    db,
    uuid: paymentUuid,
    transactionId: transactionId,
    method: 'cash',
    amountMinor: 1100,
  );

  return _TerminalSyncFixture(
    transactionUuid: transactionUuid,
    lineUuid: lineUuid,
    modifierUuid: modifierUuid,
    paymentUuid: paymentUuid,
  );
}
