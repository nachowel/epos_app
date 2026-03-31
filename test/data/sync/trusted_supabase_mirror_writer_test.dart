import 'dart:convert';

import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/sync/supabase_edge_function_invoker.dart';
import 'package:epos_app/data/sync/trusted_mirror_boundary_contract.dart';
import 'package:epos_app/data/sync/trusted_supabase_mirror_writer.dart';
import 'package:epos_app/domain/models/app_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'validation failures stay classified as payload errors and payload diagnostics are logged',
    () async {
      final MemoryAppLogSink sink = MemoryAppLogSink();
      final StructuredAppLogger logger = StructuredAppLogger(
        sinks: <AppLogSink>[sink],
        enableInfoLogs: true,
      );
      addTearDown(logger.dispose);

      late http.Request capturedRequest;
      final MockClient client = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, Object?>{
            'ok': false,
            'failure': 'validation_failure',
            'message': 'Trusted mirror boundary rejected the payload',
            'issues': <String>['payments must be an array'],
          }),
          400,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final AppConfig config = AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        internalApiKey: 'internal-key',
      );
      final SupabaseTrustedMirrorBoundaryInvoker invoker =
          SupabaseTrustedMirrorBoundaryInvoker(
            client: SupabaseClient('https://example.supabase.co', 'anon-key'),
            config: config,
            logger: logger,
            functionInvoker: SupabaseEdgeFunctionInvoker(
              config: config,
              httpClient: client,
            ),
          );

      await expectLater(
        () => invoker.invoke(
          TrustedMirrorWriteRequest(
            transactionUuid: '11111111-1111-1111-1111-111111111111',
            transactionIdempotencyKey: 'idem-1',
            generatedAt: DateTime.parse('2026-04-01T10:00:00Z'),
            transaction: const <String, Object?>{
              'uuid': '11111111-1111-1111-1111-111111111111',
              'status': 'paid',
            },
            transactionLines: const <Map<String, Object?>>[],
            orderModifiers: const <Map<String, Object?>>[],
            payments: const <Map<String, Object?>>[
              <String, Object?>{
                'uuid': '22222222-2222-2222-2222-222222222222',
                'transaction_uuid': '11111111-1111-1111-1111-111111111111',
              },
            ],
          ),
        ),
        throwsA(
          isA<MirrorWriteFailure>()
              .having(
                (MirrorWriteFailure error) => error.type,
                'type',
                MirrorWriteFailureType.validationFailure,
              )
              .having(
                (MirrorWriteFailure error) => error.message,
                'message',
                allOf(
                  contains('Trusted mirror boundary rejected the payload'),
                  contains('payments must be an array'),
                  isNot(contains('configured internal key')),
                ),
              )
              .having(
                (MirrorWriteFailure error) => error.retryable,
                'retryable',
                isFalse,
              ),
        ),
      );

      final Map<String, Object?> requestJson = Map<String, Object?>.from(
        jsonDecode(capturedRequest.body) as Map,
      );
      expect(
        requestJson.keys.toList(growable: false),
        <String>[
          'payload_version',
          'transaction_uuid',
          'transaction_idempotency_key',
          'generated_at',
          'transaction',
          'transaction_lines',
          'order_modifiers',
          'payments',
        ],
      );
      expect(requestJson['payments'], isA<List>());

      final AppLogEntry payloadLog = sink.entries.lastWhere(
        (AppLogEntry entry) =>
            entry.eventType == 'sync_trusted_mirror_payload_prepared',
      );
      expect(
        payloadLog.metadata['top_level_payload_keys'],
        <String>[
          'payload_version',
          'transaction_uuid',
          'transaction_idempotency_key',
          'generated_at',
          'transaction',
          'transaction_lines',
          'order_modifiers',
          'payments',
        ],
      );
      expect(payloadLog.metadata['payload_version'], 1);
      expect(payloadLog.metadata['transaction_uuid_present'], isTrue);
      expect(
        payloadLog.metadata['transaction_idempotency_key_present'],
        isTrue,
      );
      expect(payloadLog.metadata['generated_at_present'], isTrue);
      expect(payloadLog.metadata['transaction_present'], isTrue);
      expect(payloadLog.metadata['transaction_lines_count'], 0);
      expect(payloadLog.metadata['order_modifiers_count'], 0);
      expect(payloadLog.metadata['payments_count'], 1);
    },
  );
}
