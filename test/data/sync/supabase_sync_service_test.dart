import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/data/sync/supabase_mirror_writer.dart';
import 'package:epos_app/data/sync/supabase_sync_service.dart';
import 'package:epos_app/data/sync/sync_transaction_graph.dart';
import 'package:epos_app/data/sync/trusted_mirror_boundary_contract.dart';
import 'package:epos_app/data/sync/trusted_supabase_mirror_writer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delegates finalized graph writes through the configured writer boundary', () async {
    final _RecordingMirrorWriter writer = _RecordingMirrorWriter();
    final SupabaseSyncService service = SupabaseSyncService(
      mirrorWriter: writer,
    );

    await service.syncTransactionGraph(_paidGraph());

    expect(writer.calls, hasLength(1));
    expect(writer.calls.single.transactionUuid, 'tx-1');
    expect(writer.calls.single.records.single.payload['status'], 'paid');
  });

  test('rejects non-finalized transaction graphs before remote write', () {
    final _RecordingMirrorWriter writer = _RecordingMirrorWriter();
    final SupabaseSyncService service = SupabaseSyncService(
      mirrorWriter: writer,
    );

    expect(
      () => service.syncTransactionGraph(
        SyncTransactionGraph(
          transactionUuid: 'tx-2',
          transactionIdempotencyKey: 'idem-2',
          records: <SyncGraphRecord>[
            const SyncGraphRecord(
              tableName: 'transactions',
              recordUuid: 'tx-2',
              payload: <String, Object?>{'uuid': 'tx-2', 'status': 'open'},
              idempotencyKey: 'idem-2',
            ),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(writer.calls, isEmpty);
  });

  test('propagates writer failures so retry flow can handle them upstream', () async {
    final SupabaseSyncService service = SupabaseSyncService(
      mirrorWriter: const _FailingMirrorWriter(),
    );

    expect(
      () => service.syncTransactionGraph(
        _paidGraph(
          extraRecords: <SyncGraphRecord>[
            const SyncGraphRecord(
              tableName: 'payments',
              recordUuid: 'payment-1',
              payload: <String, Object?>{
                'uuid': 'payment-1',
                'transaction_uuid': 'tx-1',
                'method': 'card',
                'amount_minor': 1200,
                'paid_at': '2026-01-01T12:00:00.000Z',
              },
              idempotencyKey: 'idem-2:payment',
            ),
          ],
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('trusted mode uses the trusted boundary writer and not the direct table writer', () async {
    final _RecordingTrustedInvoker invoker = _RecordingTrustedInvoker();
    final SupabaseSyncService service = SupabaseSyncService(
      client: SupabaseClient('https://example.supabase.co', 'anon-key'),
      config: AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        mirrorWriteMode: MirrorWriteMode.trustedSyncBoundary,
      ),
      trustedBoundaryInvoker: invoker,
    );

    await service.syncTransactionGraph(_paidGraph());

    expect(invoker.requests, hasLength(1));
    expect(invoker.requests.single.transactionUuid, 'tx-1');
  });

  test('default config path prefers the trusted boundary writer', () async {
    final _RecordingTrustedInvoker invoker = _RecordingTrustedInvoker();
    final SupabaseSyncService service = SupabaseSyncService(
      client: SupabaseClient('https://example.supabase.co', 'anon-key'),
      config: AppConfig.fromValues(
        environment: 'staging',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ),
      trustedBoundaryInvoker: invoker,
    );

    await service.syncTransactionGraph(_paidGraph());

    expect(invoker.requests, hasLength(1));
  });

  test('production rejects direct mirror write mode', () {
    final SupabaseSyncService service = SupabaseSyncService(
      client: SupabaseClient('https://example.supabase.co', 'anon-key'),
      config: AppConfig.fromValues(
        environment: 'prod',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        mirrorWriteMode: MirrorWriteMode.directMirrorWrite,
      ),
    );

    expect(service.isConfigured, isFalse);
    expect(
      service.configurationIssue,
      'Direct client mirror write is disabled in production. Use trusted_sync_boundary.',
    );
  });

  test('explicit direct mirror mode remains available for controlled non-production use', () {
    final SupabaseSyncService service = SupabaseSyncService(
      client: SupabaseClient('https://example.supabase.co', 'anon-key'),
      config: AppConfig.fromValues(
        environment: 'dev',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        mirrorWriteMode: MirrorWriteMode.directMirrorWrite,
      ),
    );

    expect(service.isConfigured, isTrue);
    expect(
      service.configurationIssue,
      'Direct client mirror write is enabled. This path is for controlled non-production use only.',
    );
  });
}

SyncTransactionGraph _paidGraph({List<SyncGraphRecord> extraRecords = const <SyncGraphRecord>[]}) {
  return SyncTransactionGraph(
    transactionUuid: 'tx-1',
    transactionIdempotencyKey: 'idem-1',
    records: <SyncGraphRecord>[
      const SyncGraphRecord(
        tableName: 'transactions',
        recordUuid: 'tx-1',
        payload: <String, Object?>{'uuid': 'tx-1', 'status': 'paid'},
        idempotencyKey: 'idem-1',
      ),
      ...extraRecords,
    ],
  );
}

class _MirrorWriteCall {
  const _MirrorWriteCall({required this.records, required this.transactionUuid});

  final List<SyncGraphRecord> records;
  final String transactionUuid;
}

class _RecordingMirrorWriter implements SupabaseMirrorWriter {
  final List<_MirrorWriteCall> calls = <_MirrorWriteCall>[];

  @override
  Future<void> writeTransactionGraph(SyncTransactionGraph graph) async {
    calls.add(
      _MirrorWriteCall(
        transactionUuid: graph.transactionUuid,
        records: graph.records
            .map(
              (SyncGraphRecord record) => SyncGraphRecord(
                tableName: record.tableName,
                recordUuid: record.recordUuid,
                payload: Map<String, Object?>.from(record.payload),
                idempotencyKey: record.idempotencyKey,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _FailingMirrorWriter implements SupabaseMirrorWriter {
  const _FailingMirrorWriter();

  @override
  Future<void> writeTransactionGraph(SyncTransactionGraph graph) {
    throw StateError('direct writer failed');
  }
}

class _RecordingTrustedInvoker implements TrustedMirrorBoundaryInvoker {
  final List<TrustedMirrorWriteRequest> requests = <TrustedMirrorWriteRequest>[];

  @override
  Future<TrustedMirrorWriteSuccess> invoke(TrustedMirrorWriteRequest request) async {
    requests.add(request);
    return TrustedMirrorWriteSuccess(
      transactionUuid: request.transactionUuid,
      transactionStatus: request.transaction['status']! as String,
      mirroredRecords: 1 +
          request.transactionLines.length +
          request.orderModifiers.length +
          (request.payment == null ? 0 : 1),
    );
  }
}
