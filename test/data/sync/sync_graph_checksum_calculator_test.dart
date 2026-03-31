import 'package:epos_app/data/sync/sync_graph_checksum_calculator.dart';
import 'package:epos_app/data/sync/sync_transaction_graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sync graph checksum determinism', () {
    const SyncGraphChecksumCalculator calculator =
        SyncGraphChecksumCalculator();

    test(
      'same terminal graph keeps the same checksum across record order, map key order, null placement, and timestamp normalization',
      () {
        final SyncTransactionGraph left = SyncTransactionGraph(
          transactionUuid: '00000000-0000-4000-8000-000000000001',
          transactionIdempotencyKey: 'idem-1',
          records: <SyncGraphRecord>[
            SyncGraphRecord(
              tableName: 'payments',
              recordUuid: '00000000-0000-4000-8000-000000000004',
              idempotencyKey: 'payment',
              payload: <String, Object?>{
                'paid_at': DateTime.parse('2026-03-31T10:00:00+02:00'),
                'transaction_uuid': '00000000-0000-4000-8000-000000000001',
                'amount_minor': 1025,
                'is_refund': false,
                'uuid': '00000000-0000-4000-8000-000000000004',
                'note': null,
              },
            ),
            SyncGraphRecord(
              tableName: 'order_modifiers',
              recordUuid: '00000000-0000-4000-8000-000000000003',
              idempotencyKey: 'modifier',
              payload: <String, Object?>{
                'item_name': 'Extra Shot',
                'uuid': '00000000-0000-4000-8000-000000000003',
                'transaction_line_uuid': '00000000-0000-4000-8000-000000000002',
                'extra_price_minor': 75,
                'action': 'add',
                'note': null,
              },
            ),
            SyncGraphRecord(
              tableName: 'transactions',
              recordUuid: '00000000-0000-4000-8000-000000000001',
              idempotencyKey: 'root',
              payload: <String, Object?>{
                'status': 'paid',
                'cancelled_at': null,
                'uuid': '00000000-0000-4000-8000-000000000001',
                'paid_at': DateTime.utc(2026, 3, 31, 8),
                'receipt_printed': false,
                'kitchen_printed': true,
              },
            ),
            SyncGraphRecord(
              tableName: 'transaction_lines',
              recordUuid: '00000000-0000-4000-8000-000000000002',
              idempotencyKey: 'line',
              payload: <String, Object?>{
                'quantity': 1,
                'uuid': '00000000-0000-4000-8000-000000000002',
                'transaction_uuid': '00000000-0000-4000-8000-000000000001',
                'line_total_minor': 1025,
                'product_name': 'Latte',
                'voided_at': null,
              },
            ),
          ],
        );

        final SyncTransactionGraph right = SyncTransactionGraph(
          transactionUuid: '00000000-0000-4000-8000-000000000001',
          transactionIdempotencyKey: 'idem-1',
          records: <SyncGraphRecord>[
            SyncGraphRecord(
              tableName: 'transaction_lines',
              recordUuid: '00000000-0000-4000-8000-000000000002',
              idempotencyKey: 'line',
              payload: <String, Object?>{
                'voided_at': null,
                'product_name': 'Latte',
                'line_total_minor': 1025,
                'transaction_uuid': '00000000-0000-4000-8000-000000000001',
                'uuid': '00000000-0000-4000-8000-000000000002',
                'quantity': 1,
              },
            ),
            SyncGraphRecord(
              tableName: 'transactions',
              recordUuid: '00000000-0000-4000-8000-000000000001',
              idempotencyKey: 'root',
              payload: <String, Object?>{
                'kitchen_printed': true,
                'receipt_printed': false,
                'paid_at': DateTime.parse('2026-03-31T08:00:00Z'),
                'uuid': '00000000-0000-4000-8000-000000000001',
                'cancelled_at': null,
                'status': 'paid',
              },
            ),
            SyncGraphRecord(
              tableName: 'payments',
              recordUuid: '00000000-0000-4000-8000-000000000004',
              idempotencyKey: 'payment',
              payload: <String, Object?>{
                'uuid': '00000000-0000-4000-8000-000000000004',
                'note': null,
                'is_refund': false,
                'amount_minor': 1025,
                'transaction_uuid': '00000000-0000-4000-8000-000000000001',
                'paid_at': DateTime.utc(2026, 3, 31, 8),
              },
            ),
            SyncGraphRecord(
              tableName: 'order_modifiers',
              recordUuid: '00000000-0000-4000-8000-000000000003',
              idempotencyKey: 'modifier',
              payload: <String, Object?>{
                'note': null,
                'action': 'add',
                'extra_price_minor': 75,
                'transaction_line_uuid': '00000000-0000-4000-8000-000000000002',
                'uuid': '00000000-0000-4000-8000-000000000003',
                'item_name': 'Extra Shot',
              },
            ),
          ],
        );

        expect(calculator.calculate(left), calculator.calculate(right));
      },
    );

    test(
      'line and modifier ordering is canonicalized by table rank then UUID',
      () {
        final SyncTransactionGraph left = SyncTransactionGraph(
          transactionUuid: '00000000-0000-4000-8000-000000000010',
          transactionIdempotencyKey: 'idem-2',
          records: <SyncGraphRecord>[
            _record(
              tableName: 'order_modifiers',
              recordUuid: '00000000-0000-4000-8000-000000000014',
            ),
            _record(
              tableName: 'transaction_lines',
              recordUuid: '00000000-0000-4000-8000-000000000013',
            ),
            _record(
              tableName: 'transactions',
              recordUuid: '00000000-0000-4000-8000-000000000010',
            ),
            _record(
              tableName: 'transaction_lines',
              recordUuid: '00000000-0000-4000-8000-000000000012',
            ),
            _record(
              tableName: 'order_modifiers',
              recordUuid: '00000000-0000-4000-8000-000000000011',
            ),
          ],
        );
        final SyncTransactionGraph right = SyncTransactionGraph(
          transactionUuid: '00000000-0000-4000-8000-000000000010',
          transactionIdempotencyKey: 'idem-2',
          records: <SyncGraphRecord>[
            _record(
              tableName: 'transactions',
              recordUuid: '00000000-0000-4000-8000-000000000010',
            ),
            _record(
              tableName: 'order_modifiers',
              recordUuid: '00000000-0000-4000-8000-000000000011',
            ),
            _record(
              tableName: 'transaction_lines',
              recordUuid: '00000000-0000-4000-8000-000000000012',
            ),
            _record(
              tableName: 'transaction_lines',
              recordUuid: '00000000-0000-4000-8000-000000000013',
            ),
            _record(
              tableName: 'order_modifiers',
              recordUuid: '00000000-0000-4000-8000-000000000014',
            ),
          ],
        );

        expect(calculator.calculate(left), calculator.calculate(right));
      },
    );

    test('checksum still changes when the logical payload changes', () {
      final SyncTransactionGraph paid = SyncTransactionGraph(
        transactionUuid: '00000000-0000-4000-8000-000000000020',
        transactionIdempotencyKey: 'idem-3',
        records: <SyncGraphRecord>[
          _record(
            tableName: 'transactions',
            recordUuid: '00000000-0000-4000-8000-000000000020',
            payload: <String, Object?>{'status': 'paid'},
          ),
        ],
      );
      final SyncTransactionGraph cancelled = SyncTransactionGraph(
        transactionUuid: '00000000-0000-4000-8000-000000000020',
        transactionIdempotencyKey: 'idem-3',
        records: <SyncGraphRecord>[
          _record(
            tableName: 'transactions',
            recordUuid: '00000000-0000-4000-8000-000000000020',
            payload: <String, Object?>{'status': 'cancelled'},
          ),
        ],
      );

      expect(
        calculator.calculate(paid),
        isNot(calculator.calculate(cancelled)),
      );
    });
  });
}

SyncGraphRecord _record({
  required String tableName,
  required String recordUuid,
  Map<String, Object?> payload = const <String, Object?>{},
}) {
  return SyncGraphRecord(
    tableName: tableName,
    recordUuid: recordUuid,
    idempotencyKey: '$tableName:$recordUuid',
    payload: <String, Object?>{'uuid': recordUuid, ...payload},
  );
}
