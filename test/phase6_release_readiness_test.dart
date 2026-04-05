import 'dart:async';
import 'dart:io';

import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/errors/error_mapper.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/core/ops/app_crash_guard.dart';
import 'package:epos_app/data/database/app_database.dart' hide User;
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
import 'package:epos_app/data/sync/sync_connectivity_service.dart';
import 'package:epos_app/data/sync/sync_payload_repository.dart';
import 'package:epos_app/data/sync/sync_remote_gateway.dart';
import 'package:epos_app/data/sync/sync_transaction_graph.dart';
import 'package:epos_app/data/sync/sync_worker.dart';
import 'package:epos_app/domain/models/app_log_entry.dart';
import 'package:epos_app/domain/models/sync_runtime_state.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/admin_service.dart';
import 'package:epos_app/domain/services/cash_movement_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/report_service.dart';
import 'package:epos_app/domain/services/report_visibility_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_database.dart';

void main() {
  group('Phase 6 release readiness', () {
    test(
      'structured logger writes structured entries and respects info flag',
      () async {
        final MemoryAppLogSink infoSink = MemoryAppLogSink();
        final StructuredAppLogger infoLogger = StructuredAppLogger(
          sinks: <AppLogSink>[infoSink],
          enableInfoLogs: true,
        );
        addTearDown(infoLogger.dispose);

        infoLogger.info(
          eventType: 'order_paid',
          entityId: 'tx-1',
          message: 'Payment captured.',
          metadata: <String, Object?>{'amount_minor': 1200},
        );
        infoLogger.warn(
          eventType: 'print_failure',
          entityId: 'tx-1',
          error: PrinterException('Paper jam'),
        );
        await _waitUntil(() => infoSink.entries.length == 2);

        expect(infoSink.entries[0].toJson()['event_type'], 'order_paid');
        expect(infoSink.entries[0].toJson()['entity_id'], 'tx-1');
        expect(infoSink.entries[0].toJson()['metadata'], <String, Object?>{
          'amount_minor': 1200,
        });
        expect(infoSink.entries[1].toJson()['level'], 'WARN');

        final MemoryAppLogSink silentSink = MemoryAppLogSink();
        final StructuredAppLogger silentLogger = StructuredAppLogger(
          sinks: <AppLogSink>[silentSink],
          enableInfoLogs: false,
        );
        addTearDown(silentLogger.dispose);

        silentLogger.info(eventType: 'ignored_info');
        silentLogger.error(eventType: 'error_kept', message: 'still logged');
        await _waitUntil(() => silentSink.entries.length == 1);

        expect(silentSink.entries.single.eventType, 'error_kept');
      },
    );

    test(
      'error mapper returns user message and logs expected vs unexpected errors',
      () async {
        final MemoryAppLogSink sink = MemoryAppLogSink();
        final StructuredAppLogger logger = StructuredAppLogger(
          sinks: <AppLogSink>[sink],
          enableInfoLogs: true,
        );
        addTearDown(logger.dispose);

        final String validationMessage = ErrorMapper.toUserMessageAndLog(
          ValidationException('Visible validation message'),
          logger: logger,
          eventType: 'validation_failed',
        );
        final String genericMessage = ErrorMapper.toUserMessageAndLog(
          StateError('boom'),
          logger: logger,
          eventType: 'unexpected_failed',
        );
        await _waitUntil(() => sink.entries.length == 2);

        expect(validationMessage, 'Visible validation message');
        expect(genericMessage, AppStrings.errorGeneric);
        expect(sink.entries[0].level, AppLogLevel.warn);
        expect(sink.entries[1].level, AppLogLevel.error);
      },
    );

    test('crash guard logs zone and flutter errors', () async {
      final FlutterExceptionHandler? originalHandler = FlutterError.onError;
      final FlutterExceptionHandler originalPresenter =
          FlutterError.presentError;
      addTearDown(() {
        FlutterError.onError = originalHandler;
        FlutterError.presentError = originalPresenter;
      });

      final MemoryAppLogSink sink = MemoryAppLogSink();
      final StructuredAppLogger logger = StructuredAppLogger(
        sinks: <AppLogSink>[sink],
        enableInfoLogs: true,
      );
      addTearDown(logger.dispose);

      FlutterError.presentError = (_) {};
      AppCrashGuard.installFlutterErrorHandler(logger);
      FlutterError.onError!(
        FlutterErrorDetails(
          exception: StateError('flutter boom'),
          stack: StackTrace.current,
          library: 'phase6_test',
        ),
      );
      await expectLater(
        AppCrashGuard.runGuarded(
          logger: () => logger,
          body: () async {
            throw StateError('zone boom');
          },
        ),
        throwsStateError,
      );
      await _waitUntil(() => sink.entries.length == 2);

      expect(
        sink.entries.map((AppLogEntry e) => e.eventType),
        containsAll(<String>['flutter_error', 'zone_error']),
      );
    });

    test(
      'config exposes environment, version, feature flags and sync interval',
      () {
        const AppConfig config = AppConfig(
          environment: 'staging',
          appVersion: '6.0.0+4',
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
          syncIntervalSeconds: 17,
          featureFlags: FeatureFlags(
            syncEnabled: false,
            debugLoggingEnabled: true,
            backupExportEnabled: false,
          ),
        );

        expect(config.environment, 'staging');
        expect(config.appVersion, '6.0.0+4');
        expect(config.hasSupabaseConfig, isTrue);
        expect(config.isSupabaseReadyForSync, isFalse);
        expect(config.supabaseConfigurationLabel, 'Sync disabled');
        expect(config.syncInterval, const Duration(seconds: 17));
        expect(config.featureFlags.syncEnabled, isFalse);
        expect(config.featureFlags.debugLoggingEnabled, isTrue);
        expect(config.featureFlags.backupExportEnabled, isFalse);
      },
    );

    test('service role style Supabase key is rejected for client sync', () {
      const AppConfig config = AppConfig(
        environment: 'prod',
        appVersion: '7.0.0+1',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'sb_secret_do_not_use_on_client',
        syncIntervalSeconds: 30,
        featureFlags: FeatureFlags(
          syncEnabled: true,
          debugLoggingEnabled: false,
          backupExportEnabled: true,
        ),
      );

      expect(config.hasSupabaseConfig, isTrue);
      expect(config.isSupabaseReadyForSync, isFalse);
      expect(
        config.supabaseConfigurationStatus,
        SupabaseConfigurationStatus.rejectedServiceRoleKey,
      );
      expect(
        config.supabaseConfigurationIssue,
        'Client builds may use only publishable/anon Supabase keys.',
      );
    });

    test(
      'sync worker disabled flag blocks processing and exposes disabled runtime state',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        await insertTransaction(
          db,
          uuid: 'disabled-sync-tx',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 500,
        );
        await insertSyncQueueItem(
          db,
          tableName: 'transactions',
          recordUuid: 'disabled-sync-tx',
        );

        final _RecordingRemoteGateway remoteGateway = _RecordingRemoteGateway();
        final SyncWorker worker = SyncWorker(
          syncQueueRepository: SyncQueueRepository(db),
          syncPayloadRepository: SyncPayloadRepository(db),
          remoteGateway: remoteGateway,
          connectivityService: _FakeConnectivityService(initialOnline: true),
          isEnabled: false,
          pollInterval: const Duration(days: 1),
        );
        addTearDown(worker.dispose);

        await worker.start();
        await worker.runOnce();

        final ({int pendingCount, int failedCount}) counts =
            await SyncQueueRepository(db).getMonitorCounts();
        expect(counts.pendingCount, 1);
        expect(counts.failedCount, 0);
        expect(worker.currentState.isEnabled, isFalse);
        expect(remoteGateway.callCount, 0);
      },
    );

    test('system repository exposes current schema version contract', () async {
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final SystemRepository repository = SystemRepository(
        db,
        databaseFileResolver: () async => throw UnsupportedError('Unused'),
      );

      expect(repository.schemaVersion, AppDatabase.currentSchemaVersion);
    });

    test(
      'system health snapshot returns real runtime and queue data',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        await insertTransaction(
          db,
          uuid: 'health-pending',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 1200,
        );
        await insertTransaction(
          db,
          uuid: 'health-failed',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 900,
        );
        await insertSyncQueueItem(
          db,
          tableName: 'transactions',
          recordUuid: 'health-pending',
          status: 'pending',
        );
        await insertSyncQueueItem(
          db,
          tableName: 'transactions',
          recordUuid: 'health-failed',
          status: 'failed',
          attemptCount: 5,
          errorMessage: 'sync failed',
        );

        final AdminService adminService = _makeAdminService(
          db,
          appConfig: AppConfig.fromValues(
            environment: 'staging',
            appVersion: '6.1.0+2',
            featureFlags: const FeatureFlags(
              syncEnabled: true,
              debugLoggingEnabled: true,
              backupExportEnabled: true,
            ),
          ),
        );

        final snapshot = await adminService.getSystemHealthSnapshot(
          user: _adminUser(adminId),
          runtimeState: const SyncRuntimeState(
            isEnabled: true,
            isOnline: true,
            isRunning: false,
            lastRunStartedAt: null,
            lastRunCompletedAt: null,
            lastRuntimeError: 'runtime-failure',
          ),
        );

        expect(snapshot.environment, 'staging');
        expect(snapshot.appVersion, '6.1.0+2');
        expect(snapshot.schemaVersion, AppDatabase.currentSchemaVersion);
        expect(snapshot.activeShift?.id, shiftId);
        expect(snapshot.pendingCount, 1);
        expect(snapshot.failedCount, 1);
        expect(snapshot.stuckCount, 1);
        expect(snapshot.isSupabaseConfigured, isFalse);
        expect(snapshot.supabaseConfigurationLabel, 'Supabase config missing');
        expect(snapshot.isOnline, isTrue);
        expect(snapshot.isWorkerRunning, isFalse);
        expect(snapshot.lastError, 'runtime-failure');
        expect(snapshot.debugLoggingEnabled, isTrue);
      },
    );

    test(
      'backup export obeys feature flag and rejects when disabled',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');

        final AdminService adminService = _makeAdminService(
          db,
          appConfig: AppConfig.fromValues(
            environment: 'prod',
            appVersion: '6.0.0+1',
            featureFlags: const FeatureFlags(
              syncEnabled: true,
              debugLoggingEnabled: false,
              backupExportEnabled: false,
            ),
          ),
        );

        await expectLater(
          adminService.exportLocalDatabase(user: _adminUser(adminId)),
          throwsA(isA<ValidationException>()),
        );
      },
    );
  });
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

class _RecordingRemoteGateway implements SyncRemoteGateway {
  int callCount = 0;

  @override
  bool get isConfigured => true;

  @override
  String? get configurationIssue => null;

  @override
  Future<void> syncTransactionGraph(SyncTransactionGraph graph) async {
    callCount += graph.records.length;
  }
}

AdminService _makeAdminService(AppDatabase db, {required AppConfig appConfig}) {
  final SyncQueueRepository syncQueueRepository = SyncQueueRepository(db);
  final ShiftSessionService shiftSessionService = ShiftSessionService(
    ShiftRepository(db),
  );
  final ReportService reportService = ReportService(
    shiftRepository: ShiftRepository(db),
    shiftSessionService: shiftSessionService,
    transactionRepository: TransactionRepository(
      db,
      syncQueueRepository: syncQueueRepository,
    ),
    paymentRepository: PaymentRepository(db),
    settingsRepository: SettingsRepository(db),
    reportVisibilityService: const ReportVisibilityService(),
  );

  return AdminService(
    categoryRepository: CategoryRepository(db),
    productRepository: ProductRepository(db),
    breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
    modifierRepository: ModifierRepository(db),
    shiftRepository: ShiftRepository(db),
    transactionRepository: TransactionRepository(
      db,
      syncQueueRepository: syncQueueRepository,
    ),
    syncQueueRepository: syncQueueRepository,
    settingsRepository: SettingsRepository(db),
    systemRepository: SystemRepository(
      db,
      databaseFileResolver: () async =>
          throw UnsupportedError('Not used in this test'),
      backupDirectoryResolver: () async =>
          Directory.systemTemp.createTemp('epos_test_backup_'),
    ),
    reportService: reportService,
    shiftSessionService: shiftSessionService,
    cashMovementService: CashMovementService(
      cashMovementRepository: CashMovementRepository(db),
      shiftSessionService: shiftSessionService,
    ),
    printerService: PrinterService(
      TransactionRepository(db, syncQueueRepository: syncQueueRepository),
      paymentRepository: PaymentRepository(db),
      settingsRepository: SettingsRepository(db),
    ),
    appConfig: appConfig,
  );
}

User _adminUser(int id) => User(
  id: id,
  name: 'Admin',
  pin: '0000',
  password: null,
  role: UserRole.admin,
  isActive: true,
  createdAt: DateTime.now(),
);

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
