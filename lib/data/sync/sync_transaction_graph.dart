class SyncTransactionGraph {
  const SyncTransactionGraph({
    required this.transactionUuid,
    required this.transactionIdempotencyKey,
    required this.records,
  });

  final String transactionUuid;
  final String transactionIdempotencyKey;
  final List<SyncGraphRecord> records;
}

class SyncGraphRecord {
  const SyncGraphRecord({
    required this.tableName,
    required this.recordUuid,
    required this.payload,
    required this.idempotencyKey,
  });

  final String tableName;
  final String recordUuid;
  final Map<String, Object?> payload;
  final String idempotencyKey;

  ({String tableName, String recordUuid}) get queueRef =>
      (tableName: tableName, recordUuid: recordUuid);
}
