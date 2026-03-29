import 'dart:async';

import 'package:epos_app/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/auth_lockout_store.dart';
import '../../data/repositories/audit_log_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/cash_movement_repository.dart';
import '../../data/repositories/modifier_repository.dart';
import '../../data/repositories/payment_adjustment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/print_job_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/shift_reconciliation_repository.dart';
import '../../data/repositories/sync_queue_repository.dart';
import '../../data/repositories/system_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/transaction_state_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/sync/supabase_sync_service.dart';
import '../../data/sync/supabase_client_provider.dart';
import '../../data/sync/supabase_connection_service.dart';
import '../../data/sync/sync_connectivity_service.dart';
import '../../data/sync/sync_payload_repository.dart';
import '../../data/sync/sync_remote_gateway.dart';
import '../../data/sync/sync_worker.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/services/admin_service.dart';
import '../../domain/services/audit_log_service.dart';
import '../../domain/services/cash_movement_service.dart';
import '../../domain/services/cashier_dashboard_service.dart';
import '../../domain/services/cashier_report_projection_service.dart';
import '../../domain/services/cashier_report_service.dart';
import '../../domain/services/catalog_service.dart';
import '../../domain/services/checkout_service.dart';
import '../../domain/services/order_service.dart';
import '../../domain/services/payment_service.dart';
import '../../domain/services/printer_service.dart';
import '../../domain/services/report_service.dart';
import '../../domain/services/report_visibility_service.dart';
import '../../domain/services/shift_session_service.dart';
import '../../presentation/providers/app_locale_provider.dart';

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((_) {
  throw UnimplementedError('AppDatabase must be overridden at app bootstrap.');
});

final Provider<AppConfig> appConfigProvider = Provider<AppConfig>(
  (_) => AppConfig.fromEnvironment(),
);

final Provider<AppLogger> appLoggerProvider = Provider<AppLogger>((_) {
  return const NoopAppLogger();
});

final Provider<SharedPreferences> sharedPreferencesProvider =
    Provider<SharedPreferences>((_) {
      throw UnimplementedError(
        'SharedPreferences must be overridden at app bootstrap.',
      );
    });

final Provider<AppLocalizations> appLocalizationsProvider =
    Provider<AppLocalizations>(
      (Ref ref) => lookupAppLocalizations(ref.watch(appLocaleProvider)),
    );

final Provider<AuthLockoutStore> authLockoutStoreProvider =
    Provider<AuthLockoutStore>(
      (Ref ref) => AuthLockoutStore(ref.watch(sharedPreferencesProvider)),
    );

final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>(
      (Ref ref) => UserRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<CategoryRepository> categoryRepositoryProvider =
    Provider<CategoryRepository>(
      (Ref ref) => CategoryRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<CashMovementRepository> cashMovementRepositoryProvider =
    Provider<CashMovementRepository>(
      (Ref ref) => CashMovementRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ProductRepository> productRepositoryProvider =
    Provider<ProductRepository>(
      (Ref ref) => ProductRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ModifierRepository> modifierRepositoryProvider =
    Provider<ModifierRepository>(
      (Ref ref) => ModifierRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ShiftRepository> shiftRepositoryProvider =
    Provider<ShiftRepository>(
      (Ref ref) => ShiftRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<TransactionRepository> transactionRepositoryProvider =
    Provider<TransactionRepository>(
      (Ref ref) => TransactionRepository(
        ref.watch(appDatabaseProvider),
        syncQueueRepository: ref.watch(syncQueueRepositoryProvider),
      ),
    );

final Provider<TransactionStateRepository> transactionStateRepositoryProvider =
    Provider<TransactionStateRepository>(
      (Ref ref) => TransactionStateRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<PaymentRepository> paymentRepositoryProvider =
    Provider<PaymentRepository>(
      (Ref ref) => PaymentRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<PaymentAdjustmentRepository>
paymentAdjustmentRepositoryProvider = Provider<PaymentAdjustmentRepository>(
  (Ref ref) => PaymentAdjustmentRepository(ref.watch(appDatabaseProvider)),
);

final Provider<ShiftReconciliationRepository>
shiftReconciliationRepositoryProvider = Provider<ShiftReconciliationRepository>(
  (Ref ref) => ShiftReconciliationRepository(ref.watch(appDatabaseProvider)),
);

final Provider<AuditLogRepository> auditLogRepositoryProvider =
    Provider<AuditLogRepository>(
      (Ref ref) => AuditLogRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<PrintJobRepository> printJobRepositoryProvider =
    Provider<PrintJobRepository>(
      (Ref ref) => PrintJobRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<SyncQueueRepository> syncQueueRepositoryProvider =
    Provider<SyncQueueRepository>(
      (Ref ref) => SyncQueueRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<SystemRepository> systemRepositoryProvider =
    Provider<SystemRepository>(
      (Ref ref) => SystemRepository(
        ref.watch(appDatabaseProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<SyncPayloadRepository> syncPayloadRepositoryProvider =
    Provider<SyncPayloadRepository>(
      (Ref ref) => SyncPayloadRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<SyncConnectivityService> syncConnectivityServiceProvider =
    Provider<SyncConnectivityService>(
      (_) => ConnectivityPlusSyncConnectivityService(),
    );

final Provider<SyncRemoteGateway> syncRemoteGatewayProvider =
    Provider<SyncRemoteGateway>(
      (Ref ref) => SupabaseSyncService(
        client: ref.watch(supabaseClientProvider),
        config: ref.watch(appConfigProvider),
      ),
    );

final Provider<SupabaseConnectionService> supabaseConnectionServiceProvider =
    Provider<SupabaseConnectionService>(
      (Ref ref) => SupabaseConnectionService(
        config: ref.watch(appConfigProvider),
        probe: switch (ref.watch(supabaseClientProvider)) {
          final SupabaseClient client => SupabaseFlutterConnectionProbe(client),
          null => null,
        },
      ),
    );

final Provider<SyncWorker> syncWorkerProvider = Provider<SyncWorker>((Ref ref) {
  final AppConfig config = ref.watch(appConfigProvider);
  final SyncWorker worker = SyncWorker(
    syncQueueRepository: ref.watch(syncQueueRepositoryProvider),
    syncPayloadRepository: ref.watch(syncPayloadRepositoryProvider),
    remoteGateway: ref.watch(syncRemoteGatewayProvider),
    connectivityService: ref.watch(syncConnectivityServiceProvider),
    logger: ref.watch(appLoggerProvider),
    isEnabled: config.featureFlags.syncEnabled,
    pollInterval: config.syncInterval,
  );
  ref.onDispose(() {
    unawaited(worker.dispose());
  });
  return worker;
});

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
    );

final Provider<ShiftSessionService> shiftSessionServiceProvider =
    Provider<ShiftSessionService>(
      (Ref ref) => ShiftSessionService(
        ref.watch(shiftRepositoryProvider),
        auditLogService: ref.watch(auditLogServiceProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<AuditLogService> auditLogServiceProvider =
    Provider<AuditLogService>(
      (Ref ref) => PersistedAuditLogService(
        auditLogRepository: ref.watch(auditLogRepositoryProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (Ref ref) => AuthService(
    ref.watch(userRepositoryProvider),
    ref.watch(shiftSessionServiceProvider),
  ),
);

final Provider<CatalogService> catalogServiceProvider =
    Provider<CatalogService>(
      (Ref ref) => CatalogService(
        categoryRepository: ref.watch(categoryRepositoryProvider),
        productRepository: ref.watch(productRepositoryProvider),
        modifierRepository: ref.watch(modifierRepositoryProvider),
      ),
    );

final Provider<CashMovementService> cashMovementServiceProvider =
    Provider<CashMovementService>(
      (Ref ref) => CashMovementService(
        cashMovementRepository: ref.watch(cashMovementRepositoryProvider),
        shiftSessionService: ref.watch(shiftSessionServiceProvider),
        auditLogService: ref.watch(auditLogServiceProvider),
      ),
    );

final Provider<CashierDashboardService> cashierDashboardServiceProvider =
    Provider<CashierDashboardService>(
      (Ref ref) => CashierDashboardService(
        shiftSessionService: ref.watch(shiftSessionServiceProvider),
        userRepository: ref.watch(userRepositoryProvider),
        orderService: ref.watch(orderServiceProvider),
        paymentRepository: ref.watch(paymentRepositoryProvider),
        transactionRepository: ref.watch(transactionRepositoryProvider),
        auditLogRepository: ref.watch(auditLogRepositoryProvider),
      ),
    );

final Provider<CashierReportProjectionService>
cashierReportProjectionServiceProvider =
    Provider<CashierReportProjectionService>(
      (_) => const CashierReportProjectionService(),
    );

final Provider<CashierReportService> cashierReportServiceProvider =
    Provider<CashierReportService>(
      (Ref ref) => CashierReportService(
        shiftSessionService: ref.watch(shiftSessionServiceProvider),
        reportService: ref.watch(reportServiceProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
        projectionService: ref.watch(cashierReportProjectionServiceProvider),
        userRepository: ref.watch(userRepositoryProvider),
      ),
    );

final Provider<AdminService> adminServiceProvider = Provider<AdminService>(
  (Ref ref) => AdminService(
    categoryRepository: ref.watch(categoryRepositoryProvider),
    productRepository: ref.watch(productRepositoryProvider),
    modifierRepository: ref.watch(modifierRepositoryProvider),
    shiftRepository: ref.watch(shiftRepositoryProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    syncQueueRepository: ref.watch(syncQueueRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    systemRepository: ref.watch(systemRepositoryProvider),
    reportService: ref.watch(reportServiceProvider),
    shiftSessionService: ref.watch(shiftSessionServiceProvider),
    cashMovementService: ref.watch(cashMovementServiceProvider),
    printerService: ref.watch(printerServiceProvider),
    appConfig: ref.watch(appConfigProvider),
    auditLogService: ref.watch(auditLogServiceProvider),
  ),
);

final Provider<OrderService> orderServiceProvider = Provider<OrderService>(
  (Ref ref) => OrderService(
    shiftSessionService: ref.watch(shiftSessionServiceProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    transactionStateRepository: ref.watch(transactionStateRepositoryProvider),
    paymentRepository: ref.watch(paymentRepositoryProvider),
    printJobRepository: ref.watch(printJobRepositoryProvider),
    syncQueueRepository: ref.watch(syncQueueRepositoryProvider),
    auditLogService: ref.watch(auditLogServiceProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final Provider<PrinterService> printerServiceProvider =
    Provider<PrinterService>(
      (Ref ref) => PrinterService(
        ref.watch(transactionRepositoryProvider),
        paymentRepository: ref.watch(paymentRepositoryProvider),
        printJobRepository: ref.watch(printJobRepositoryProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
        auditLogService: ref.watch(auditLogServiceProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<PaymentService> paymentServiceProvider =
    Provider<PaymentService>(
      (Ref ref) => PaymentService(
        orderService: ref.watch(orderServiceProvider),
        paymentRepository: ref.watch(paymentRepositoryProvider),
        paymentAdjustmentRepository: ref.watch(
          paymentAdjustmentRepositoryProvider,
        ),
        transactionRepository: ref.watch(transactionRepositoryProvider),
        printerService: ref.watch(printerServiceProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<CheckoutService> checkoutServiceProvider =
    Provider<CheckoutService>(
      (Ref ref) => CheckoutService(
        shiftSessionService: ref.watch(shiftSessionServiceProvider),
        orderService: ref.watch(orderServiceProvider),
        printerService: ref.watch(printerServiceProvider),
        logger: ref.watch(appLoggerProvider),
      ),
    );

final Provider<ReportService> reportServiceProvider = Provider<ReportService>(
  (Ref ref) => ReportService(
    shiftRepository: ref.watch(shiftRepositoryProvider),
    shiftSessionService: ref.watch(shiftSessionServiceProvider),
    transactionRepository: ref.watch(transactionRepositoryProvider),
    paymentRepository: ref.watch(paymentRepositoryProvider),
    paymentAdjustmentRepository: ref.watch(paymentAdjustmentRepositoryProvider),
    shiftReconciliationRepository: ref.watch(
      shiftReconciliationRepositoryProvider,
    ),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    reportVisibilityService: ref.watch(reportVisibilityServiceProvider),
    auditLogService: ref.watch(auditLogServiceProvider),
    logger: ref.watch(appLoggerProvider),
  ),
);

final Provider<ReportVisibilityService> reportVisibilityServiceProvider =
    Provider<ReportVisibilityService>((_) => const ReportVisibilityService());
