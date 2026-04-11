class SyncGraphRequeueItem {
  const SyncGraphRequeueItem({
    required this.queueId,
    required this.tableName,
    required this.recordUuid,
  });

  final int queueId;
  final String tableName;
  final String recordUuid;
}

class SyncGraphRequeueResult {
  const SyncGraphRequeueResult({
    required this.rootRecordUuid,
    required this.rootQueueId,
    required this.transactionIdempotencyKey,
    required this.createdItems,
  });

  final String rootRecordUuid;
  final int rootQueueId;
  final String transactionIdempotencyKey;
  final List<SyncGraphRequeueItem> createdItems;
}
