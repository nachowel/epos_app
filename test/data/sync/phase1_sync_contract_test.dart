import 'package:epos_app/data/sync/phase1_sync_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps finalized statuses stable for the live remote mirror', () {
    expect(
      Phase1SyncContract.mapLocalTransactionStatusToRemote('paid'),
      'paid',
    );
    expect(
      Phase1SyncContract.mapLocalTransactionStatusToRemote('cancelled'),
      'cancelled',
    );
  });

  test(
    'rejects non-finalized statuses for the live remote mirror baseline',
    () {
      expect(
        () => Phase1SyncContract.mapLocalTransactionStatusToRemote('open'),
        throwsArgumentError,
      );
      expect(
        () => Phase1SyncContract.mapLocalTransactionStatusToRemote('draft'),
        throwsArgumentError,
      );
      expect(
        () => Phase1SyncContract.mapLocalTransactionStatusToRemote('sent'),
        throwsArgumentError,
      );
    },
  );

  test('terminal transaction rule remains paid/cancelled only', () {
    expect(Phase1SyncContract.isTerminalTransactionStatus('paid'), isTrue);
    expect(Phase1SyncContract.isTerminalTransactionStatus('cancelled'), isTrue);
    expect(Phase1SyncContract.isTerminalTransactionStatus('open'), isFalse);
    expect(Phase1SyncContract.isTerminalTransactionStatus('draft'), isFalse);
    expect(Phase1SyncContract.isTerminalTransactionStatus('sent'), isFalse);
  });

  test('recognises canonical UUID strings', () {
    expect(
      Phase1SyncContract.isCanonicalUuid(
        '11111111-1111-1111-1111-111111111111',
      ),
      isTrue,
    );
    expect(Phase1SyncContract.isCanonicalUuid('tx-1'), isFalse);
  });
}
