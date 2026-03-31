import 'sync_failure_details.dart';
import 'sync_queue_item.dart';

enum SyncFailureGuidanceKind {
  retryable,
  maxRetryHit,
  localGraphDrift,
  validationFailure,
  authOrConfigFailure,
  networkUnreachable,
  remoteServerError,
  unknown,
}

class SyncFailureGuidance {
  const SyncFailureGuidance({
    required this.kind,
    required this.summaryLabel,
    required this.reason,
    required this.nextStep,
    required this.canManualRetry,
    required this.includedInRetryAll,
  });

  final SyncFailureGuidanceKind kind;
  final String summaryLabel;
  final String reason;
  final String nextStep;
  final bool canManualRetry;
  final bool includedInRetryAll;

  bool get isNonRetryable => !canManualRetry;
}

SyncFailureGuidance resolveSyncFailureGuidance(
  SyncQueueItem item, {
  required int maxRetryAttempts,
}) {
  final SyncFailureDetails? details = item.failureDetails;
  final bool hitMaxRetry = item.attemptCount >= maxRetryAttempts;

  if (details?.failureKind == SyncFailureKind.localGraphDrift) {
    return const SyncFailureGuidance(
      kind: SyncFailureGuidanceKind.localGraphDrift,
      summaryLabel: 'Drift blocked',
      reason:
          'This root event no longer matches the current local terminal graph, so replay is unsafe.',
      nextStep:
          'Create a fresh root snapshot from the current local transaction state instead of retrying this stale item.',
      canManualRetry: false,
      includedInRetryAll: false,
    );
  }

  if (hitMaxRetry && details?.retryable == true) {
    return const SyncFailureGuidance(
      kind: SyncFailureGuidanceKind.maxRetryHit,
      summaryLabel: 'Manual review required',
      reason:
          'Automatic retries already hit the configured limit for this retryable failure.',
      nextStep:
          'Inspect connectivity or remote logs, then use the item-level retry when the underlying issue is fixed.',
      canManualRetry: true,
      includedInRetryAll: false,
    );
  }

  switch (details?.failureKind) {
    case SyncFailureKind.localGraphDrift:
      return const SyncFailureGuidance(
        kind: SyncFailureGuidanceKind.localGraphDrift,
        summaryLabel: 'Drift blocked',
        reason:
            'This root event no longer matches the current local terminal graph, so replay is unsafe.',
        nextStep:
            'Create a fresh root snapshot from the current local transaction state instead of retrying this stale item.',
        canManualRetry: false,
        includedInRetryAll: false,
      );
    case SyncFailureKind.validationFailure:
      return const SyncFailureGuidance(
        kind: SyncFailureGuidanceKind.validationFailure,
        summaryLabel: 'Contract mismatch',
        reason:
            'The payload or schema contract is invalid, so retrying would repeat the same rejected write.',
        nextStep:
            'Fix the payload/schema mismatch first, then re-queue from a valid local snapshot.',
        canManualRetry: false,
        includedInRetryAll: false,
      );
    case SyncFailureKind.authOrConfigFailure:
      return const SyncFailureGuidance(
        kind: SyncFailureGuidanceKind.authOrConfigFailure,
        summaryLabel: 'Configuration blocked',
        reason:
            'The app or Supabase environment is misconfigured for this sync path.',
        nextStep:
            'Correct the auth/config issue before retrying any affected item.',
        canManualRetry: false,
        includedInRetryAll: false,
      );
    case SyncFailureKind.networkUnreachable:
      return const SyncFailureGuidance(
        kind: SyncFailureGuidanceKind.networkUnreachable,
        summaryLabel: 'Retryable',
        reason: 'The device could not reach the remote sync boundary.',
        nextStep:
            'Restore connectivity and retry. Retry all can safely pick this item up.',
        canManualRetry: true,
        includedInRetryAll: true,
      );
    case SyncFailureKind.remoteServerError:
      return const SyncFailureGuidance(
        kind: SyncFailureGuidanceKind.remoteServerError,
        summaryLabel: 'Retryable',
        reason:
            'The remote boundary failed at runtime after accepting the request shape.',
        nextStep:
            'Inspect remote logs, then retry when the transient issue is cleared.',
        canManualRetry: true,
        includedInRetryAll: true,
      );
    case SyncFailureKind.unknown:
    case null:
      return const SyncFailureGuidance(
        kind: SyncFailureGuidanceKind.unknown,
        summaryLabel: 'Manual review required',
        reason:
            'The failure could not be classified as safely retryable from the saved queue metadata.',
        nextStep:
            'Inspect logs first. Use item-level retry only after confirming the issue is cleared.',
        canManualRetry: true,
        includedInRetryAll: false,
      );
  }
}
