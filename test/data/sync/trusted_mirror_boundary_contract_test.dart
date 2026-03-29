import 'package:epos_app/data/sync/sync_transaction_graph.dart';
import 'package:epos_app/data/sync/trusted_mirror_boundary_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a trusted mirror request from a finalized transaction graph', () {
    final TrustedMirrorWriteRequest request = TrustedMirrorWriteRequest.fromGraph(
      SyncTransactionGraph(
        transactionUuid: 'tx-1',
        transactionIdempotencyKey: 'idem-1',
        records: <SyncGraphRecord>[
          const SyncGraphRecord(
            tableName: 'transactions',
            recordUuid: 'tx-1',
            payload: <String, Object?>{'uuid': 'tx-1', 'status': 'paid'},
            idempotencyKey: 'idem-1',
          ),
          const SyncGraphRecord(
            tableName: 'transaction_lines',
            recordUuid: 'line-1',
            payload: <String, Object?>{
              'uuid': 'line-1',
              'transaction_uuid': 'tx-1',
            },
            idempotencyKey: 'idem-1:line-1',
          ),
          const SyncGraphRecord(
            tableName: 'order_modifiers',
            recordUuid: 'modifier-1',
            payload: <String, Object?>{
              'uuid': 'modifier-1',
              'transaction_line_uuid': 'line-1',
            },
            idempotencyKey: 'idem-1:modifier-1',
          ),
          const SyncGraphRecord(
            tableName: 'payments',
            recordUuid: 'payment-1',
            payload: <String, Object?>{
              'uuid': 'payment-1',
              'transaction_uuid': 'tx-1',
            },
            idempotencyKey: 'idem-1:payment-1',
          ),
        ],
      ),
    );

    expect(request.transactionUuid, 'tx-1');
    expect(request.transaction['status'], 'paid');
    expect(request.transactionLines, hasLength(1));
    expect(request.orderModifiers, hasLength(1));
    expect(request.payment?['uuid'], 'payment-1');
  });

  test('rejects graph payloads without a transaction root', () {
    expect(
      () => TrustedMirrorWriteRequest.fromGraph(
        SyncTransactionGraph(
          transactionUuid: 'tx-1',
          transactionIdempotencyKey: 'idem-1',
          records: const <SyncGraphRecord>[],
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}
