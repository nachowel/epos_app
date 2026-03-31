class SyncOperationsSummary {
  const SyncOperationsSummary({
    required this.retryableFailedCount,
    required this.nonRetryableFailedCount,
    required this.driftBlockedCount,
    required this.processingStuckCount,
    required this.exhaustedRetryCount,
  });

  final int retryableFailedCount;
  final int nonRetryableFailedCount;
  final int driftBlockedCount;
  final int processingStuckCount;
  final int exhaustedRetryCount;

  int get stuckCount =>
      nonRetryableFailedCount + processingStuckCount + exhaustedRetryCount;

  String get stuckDefinition =>
      'Stuck = non-retryable failures, retryable failures that already hit the retry limit, or processing items older than the worker timeout.';
}
