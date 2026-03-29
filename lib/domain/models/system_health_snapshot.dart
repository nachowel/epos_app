import 'database_export_result.dart';
import 'migration_log_entry.dart';
import 'shift.dart';

class SystemHealthSnapshot {
  const SystemHealthSnapshot({
    required this.syncEnabled,
    required this.isSupabaseConfigured,
    required this.supabaseConfigurationLabel,
    required this.supabaseConfigurationIssue,
    required this.debugLoggingEnabled,
    required this.environment,
    required this.appVersion,
    required this.schemaVersion,
    required this.activeShift,
    required this.pendingCount,
    required this.failedCount,
    required this.stuckCount,
    required this.lastSyncedAt,
    required this.lastError,
    required this.isOnline,
    required this.isWorkerRunning,
    required this.migrationHistory,
    required this.lastMigrationFailure,
    required this.lastBackup,
  });

  final bool syncEnabled;
  final bool isSupabaseConfigured;
  final String supabaseConfigurationLabel;
  final String? supabaseConfigurationIssue;
  final bool debugLoggingEnabled;
  final String environment;
  final String appVersion;
  final int schemaVersion;
  final Shift? activeShift;
  final int pendingCount;
  final int failedCount;
  final int stuckCount;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final bool isOnline;
  final bool isWorkerRunning;
  final List<MigrationLogEntry> migrationHistory;
  final MigrationLogEntry? lastMigrationFailure;
  final DatabaseExportResult? lastBackup;
}
