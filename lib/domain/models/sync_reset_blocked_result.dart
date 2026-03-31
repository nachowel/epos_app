class SyncResetBlockedResult {
  const SyncResetBlockedResult({
    required this.resetCount,
    required this.skippedCount,
  });

  final int resetCount;
  final int skippedCount;
}
