enum SyncQueueOperation { upsert }

enum SyncQueueStatus { pending, processing, synced, failed }

class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.tableName,
    required this.recordUuid,
    required this.operation,
    required this.createdAt,
    required this.status,
    required this.attemptCount,
    required this.lastAttemptAt,
    required this.syncedAt,
    required this.errorMessage,
  });

  final int id;
  final String tableName;
  final String recordUuid;
  final SyncQueueOperation operation;
  final DateTime createdAt;
  final SyncQueueStatus status;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime? syncedAt;
  final String? errorMessage;

  SyncQueueItem copyWith({
    int? id,
    String? tableName,
    String? recordUuid,
    SyncQueueOperation? operation,
    DateTime? createdAt,
    SyncQueueStatus? status,
    int? attemptCount,
    Object? lastAttemptAt = _unset,
    Object? syncedAt = _unset,
    Object? errorMessage = _unset,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      recordUuid: recordUuid ?? this.recordUuid,
      operation: operation ?? this.operation,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt == _unset
          ? this.lastAttemptAt
          : lastAttemptAt as DateTime?,
      syncedAt: syncedAt == _unset ? this.syncedAt : syncedAt as DateTime?,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SyncQueueItem &&
        other.id == id &&
        other.tableName == tableName &&
        other.recordUuid == recordUuid &&
        other.operation == operation &&
        other.createdAt == createdAt &&
        other.status == status &&
        other.attemptCount == attemptCount &&
        other.lastAttemptAt == lastAttemptAt &&
        other.syncedAt == syncedAt &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
    id,
    tableName,
    recordUuid,
    operation,
    createdAt,
    status,
    attemptCount,
    lastAttemptAt,
    syncedAt,
    errorMessage,
  );
}

const Object _unset = Object();
