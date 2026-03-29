import 'package:epos_app/data/sync/phase1_sync_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps local in-progress statuses to remote open', () {
    expect(Phase1SyncContract.mapLocalTransactionStatusToRemote('open'), 'open');
    expect(
      Phase1SyncContract.mapLocalTransactionStatusToRemote('draft'),
      'open',
    );
    expect(
      Phase1SyncContract.mapLocalTransactionStatusToRemote('sent'),
      'open',
    );
  });

  test('keeps finalized statuses stable for the remote mirror', () {
    expect(Phase1SyncContract.mapLocalTransactionStatusToRemote('paid'), 'paid');
    expect(
      Phase1SyncContract.mapLocalTransactionStatusToRemote('cancelled'),
      'cancelled',
    );
  });

  test('terminal transaction rule remains paid/cancelled only', () {
    expect(Phase1SyncContract.isTerminalTransactionStatus('paid'), isTrue);
    expect(Phase1SyncContract.isTerminalTransactionStatus('cancelled'), isTrue);
    expect(Phase1SyncContract.isTerminalTransactionStatus('open'), isFalse);
    expect(Phase1SyncContract.isTerminalTransactionStatus('draft'), isFalse);
    expect(Phase1SyncContract.isTerminalTransactionStatus('sent'), isFalse);
  });
}
