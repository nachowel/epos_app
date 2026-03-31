import 'sync_queue_item.dart';

class SyncMonitorSnapshot {
  const SyncMonitorSnapshot({
    required this.items,
    required this.pendingCount,
    required this.failedCount,
    required this.syncedCount,
    required this.stuckCount,
    required this.maxRetryAttempts,
    required this.retryableFailedCount,
    required this.nonRetryableFailedCount,
    required this.driftBlockedCount,
    required this.processingStuckCount,
    required this.exhaustedRetryCount,
    required this.stuckDefinition,
    required this.lastFailedItem,
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
  final int syncedCount;
  final int stuckCount;
  final int maxRetryAttempts;
  final int retryableFailedCount;
  final int nonRetryableFailedCount;
  final int driftBlockedCount;
  final int processingStuckCount;
  final int exhaustedRetryCount;
  final String stuckDefinition;
  final SyncQueueItem? lastFailedItem;
  final bool syncEnabled;
  final bool isSupabaseConfigured;
  final String supabaseConfigurationLabel;
  final String? supabaseConfigurationIssue;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final bool isOnline;
  final bool isRunning;
}
