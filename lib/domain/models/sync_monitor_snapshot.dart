import 'sync_queue_item.dart';

class SyncMonitorSnapshot {
  const SyncMonitorSnapshot({
    required this.items,
    required this.pendingCount,
    required this.failedCount,
    required this.stuckCount,
    required this.syncEnabled,
    required this.isSupabaseConfigured,
    required this.supabaseConfigurationLabel,
    required this.supabaseConfigurationIssue,
    required this.lastSyncedAt,
    required this.lastError,
    required this.isOnline,
    required this.isRunning,
  });

  final List<SyncQueueItem> items;
  final int pendingCount;
  final int failedCount;
  final int stuckCount;
  final bool syncEnabled;
  final bool isSupabaseConfigured;
  final String supabaseConfigurationLabel;
  final String? supabaseConfigurationIssue;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final bool isOnline;
  final bool isRunning;
}
