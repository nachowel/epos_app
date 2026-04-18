import 'package:epos_app/data/sync/sync_transaction_graph.dart';
import 'package:epos_app/data/sync/trusted_mirror_boundary_contract.dart';
import 'package:flutter_test/flutter_test.dart';

const String _transactionUuid = '11111111-1111-1111-1111-111111111111';
const String _lineUuid = '22222222-2222-2222-2222-222222222222';
const String _modifierUuid = '33333333-3333-3333-3333-333333333333';
const String _paymentUuid = '44444444-4444-4444-4444-444444444444';

void main() {
  test(
    'builds a trusted mirror request from a finalized transaction graph',
    () {
      final TrustedMirrorWriteRequest request =
          TrustedMirrorWriteRequest.fromGraph(
            SyncTransactionGraph(
              transactionUuid: _transactionUuid,
              transactionIdempotencyKey: 'idem-1',
              records: <SyncGraphRecord>[
                const SyncGraphRecord(
                  tableName: 'transactions',
                  recordUuid: _transactionUuid,
                  payload: _transactionPayload,
                  idempotencyKey: 'idem-1',
                ),
                const SyncGraphRecord(
                  tableName: 'transaction_lines',
                  recordUuid: _lineUuid,
                  payload: _linePayload,
                  idempotencyKey: 'idem-1:line',
                ),
                const SyncGraphRecord(
                  tableName: 'order_modifiers',
                  recordUuid: _modifierUuid,
                  payload: _modifierPayload,
                  idempotencyKey: 'idem-1:modifier',
                ),
                const SyncGraphRecord(
                  tableName: 'payments',
                  recordUuid: _paymentUuid,
                  payload: _paymentPayload,
                  idempotencyKey: 'idem-1:payment',
                ),
              ],
            ),
          );

      expect(request.transactionUuid, _transactionUuid);
      expect(request.transaction['status'], 'paid');
      expect(request.transactionLines, hasLength(1));
      expect(request.orderModifiers, hasLength(1));
      expect(request.payments, hasLength(1));
      expect(request.payments.single['uuid'], _paymentUuid);
      expect(request.toJson().keys.toList(growable: false), <String>[
        'payload_version',
        'transaction_uuid',
        'transaction_idempotency_key',
        'generated_at',
        'transaction',
        'transaction_lines',
        'order_modifiers',
        'payments',
      ]);
      expect(request.toJson().containsKey('payment'), isFalse);
    },
  );

  test('rejects graph payloads without a transaction root', () {
    expect(
      () => TrustedMirrorWriteRequest.fromGraph(
        SyncTransactionGraph(
          transactionUuid: _transactionUuid,
          transactionIdempotencyKey: 'idem-1',
          records: const <SyncGraphRecord>[],
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'rejects non-UUID graph payloads that drift from the live mirror schema',
    () {
      expect(
        () => TrustedMirrorWriteRequest.fromGraph(
          SyncTransactionGraph(
            transactionUuid: 'tx-1',
            transactionIdempotencyKey: 'idem-1',
            records: <SyncGraphRecord>[
              SyncGraphRecord(
                tableName: 'transactions',
                recordUuid: 'tx-1',
                payload: <String, Object?>{
                  ..._transactionPayload,
                  'uuid': 'tx-1',
                },
                idempotencyKey: 'idem-1',
              ),
            ],
          ),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'parses table-level sync results from trusted boundary success payload',
    () {
      final TrustedMirrorWriteSuccess success =
          TrustedMirrorWriteSuccess.fromJson(<String, Object?>{
            'transaction_uuid': _transactionUuid,
            'transaction_status': 'paid',
            'mirrored_records': 4,
            'table_results': <Map<String, Object?>>[
              <String, Object?>{
                'table': 'transactions',
                'status': 'synced',
                'record_count': 1,
                'record_uuids': <String>[_transactionUuid],
              },
              <String, Object?>{
                'table': 'order_modifiers',
                'status': 'skipped',
                'record_count': 0,
                'record_uuids': const <String>[],
              },
            ],
          });

      expect(success.tableResults, hasLength(2));
      expect(success.tableResults.first.tableName, 'transactions');
      expect(
        success.tableResults.first.status,
        TrustedMirrorTableWriteStatus.synced,
      );
      expect(
        success.tableResults.last.status,
        TrustedMirrorTableWriteStatus.skipped,
      );
    },
  );
}

const Map<String, Object?> _transactionPayload = <String, Object?>{
  'uuid': _transactionUuid,
  'shift_local_id': 1,
  'user_local_id': 2,
  'table_number': 3,
  'status': 'paid',
  'subtotal_minor': 1200,
  'modifier_total_minor': 0,
  'discount_type': null,
  'discount_value_minor': 0,
  'discount_amount_minor': 0,
  'discount_reason': null,
  'discount_applied_by_local_id': null,
  'total_amount_minor': 1200,
  'created_at': '2026-04-18T09:50:00.000Z',
  'paid_at': '2026-04-18T10:00:00.000Z',
  'updated_at': '2026-04-18T10:00:00.000Z',
  'cancelled_at': null,
  'cancelled_by_local_id': null,
  'kitchen_printed': true,
  'receipt_printed': true,
};

const Map<String, Object?> _linePayload = <String, Object?>{
  'uuid': _lineUuid,
  'transaction_uuid': _transactionUuid,
  'product_local_id': 9,
  'product_name': 'Latte',
  'unit_price_minor': 1200,
  'quantity': 1,
  'pricing_mode': 'standard',
  'removal_discount_total_minor': 0,
  'line_total_minor': 1200,
};

const Map<String, Object?> _modifierPayload = <String, Object?>{
  'uuid': _modifierUuid,
  'transaction_line_uuid': _lineUuid,
  'action': 'add',
  'item_name': 'Extra Shot',
  'extra_price_minor': 50,
  'quantity': 1,
  'item_product_id': null,
  'charge_reason': null,
  'unit_price_minor': 50,
  'price_effect_minor': 50,
  'sort_key': 0,
  'price_behavior': null,
  'ui_section': null,
};

const Map<String, Object?> _paymentPayload = <String, Object?>{
  'uuid': _paymentUuid,
  'transaction_uuid': _transactionUuid,
  'method': 'card',
  'amount_minor': 1200,
  'paid_at': '2026-04-18T10:00:00.000Z',
};
