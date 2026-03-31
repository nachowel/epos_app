class SyncRetryAllResult {
  const SyncRetryAllResult({
    required this.retriedCount,
    required this.skippedCount,
    required this.skippedNonRetryableCount,
    required this.skippedManualReviewCount,
  });

  final int retriedCount;
  final int skippedCount;
  final int skippedNonRetryableCount;
  final int skippedManualReviewCount;
}
