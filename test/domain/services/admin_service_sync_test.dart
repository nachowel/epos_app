import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/logging/app_logger.dart';
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
