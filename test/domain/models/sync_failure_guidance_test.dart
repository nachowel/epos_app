import 'package:epos_app/domain/models/sync_failure_guidance.dart';
import 'package:epos_app/domain/models/sync_queue_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sync failure guidance', () {
    test('localGraphDrift is non-retryable and explains fresh requeue', () {
      final SyncFailureGuidance guidance = resolveSyncFailureGuidance(
        _failedItem(
          errorMessage:
              'failure_type=localGraphDrift|retryable=false|table=transactions|record_uuid=root-uuid|record_uuids=-|issues=expected_checksum=a,current_checksum=b|message=drift',
          attemptCount: 5,
        ),
        maxRetryAttempts: 5,
      );

      expect(guidance.kind, SyncFailureGuidanceKind.localGraphDrift);
      expect(guidance.canManualRetry, isFalse);
      expect(guidance.includedInRetryAll, isFalse);
      expect(guidance.nextStep, contains('fresh root snapshot'));
    });

    test('validation failure is non-retryable and points to contract fix', () {
      final SyncFailureGuidance guidance = resolveSyncFailureGuidance(
        _failedItem(
          errorMessage:
              'failure_type=validationFailure|retryable=false|table=payments|record_uuid=payment-uuid|record_uuids=-|issues=payments.method|message=bad payload',
        ),
        maxRetryAttempts: 5,
      );

      expect(guidance.kind, SyncFailureGuidanceKind.validationFailure);
      expect(guidance.canManualRetry, isFalse);
      expect(guidance.nextStep, contains('payload/schema mismatch'));
    });

    test(
      'max retry hit requires manual item retry but is skipped by retry all',
      () {
        final SyncFailureGuidance guidance = resolveSyncFailureGuidance(
          _failedItem(
            errorMessage:
                'failure_type=remoteServerError|retryable=true|table=payments|record_uuid=payment-uuid|record_uuids=-|issues=-|message=timeout',
            attemptCount: 5,
          ),
          maxRetryAttempts: 5,
        );

        expect(guidance.kind, SyncFailureGuidanceKind.maxRetryHit);
        expect(guidance.canManualRetry, isTrue);
        expect(guidance.includedInRetryAll, isFalse);
        expect(guidance.nextStep, contains('item-level retry'));
      },
    );
  });
}

SyncQueueItem _failedItem({
  required String errorMessage,
  int attemptCount = 1,
}) {
  return SyncQueueItem(
    id: 1,
    tableName: 'transactions',
    recordUuid: 'root-uuid',
    operation: SyncQueueOperation.upsert,
    createdAt: DateTime.utc(2026, 3, 31, 10),
    status: SyncQueueStatus.failed,
    attemptCount: attemptCount,
    lastAttemptAt: DateTime.utc(2026, 3, 31, 10, 1),
    syncedAt: null,
    errorMessage: errorMessage,
  );
}
