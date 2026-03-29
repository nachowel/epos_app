import 'transaction.dart';

class DraftOrderPolicy {
  const DraftOrderPolicy._();

  // POS drafts that have been untouched for this long are treated as stale
  // cleanup items rather than current in-flight work.
  static const Duration staleThreshold = Duration(minutes: 45);

  static bool isStale(Transaction transaction, {DateTime? now}) {
    if (transaction.status != TransactionStatus.draft) {
      return false;
    }
    return isUpdatedAtStale(transaction.updatedAt, now: now);
  }

  static bool isUpdatedAtStale(DateTime updatedAt, {DateTime? now}) {
    final DateTime effectiveNow = now ?? DateTime.now();
    return !updatedAt.add(staleThreshold).isAfter(effectiveNow);
  }

  static bool isFresh(Transaction transaction, {DateTime? now}) {
    return transaction.status == TransactionStatus.draft &&
        !isStale(transaction, now: now);
  }
}
