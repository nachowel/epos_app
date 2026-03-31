import 'dart:convert';

import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/data/sync/supabase_edge_function_invoker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'uses x-epos-internal-key and does not send publishable key as Bearer token',
    () async {
      late http.Request capturedRequest;
      final MockClient client = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, Object?>{'ok': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final SupabaseEdgeFunctionInvoker invoker = SupabaseEdgeFunctionInvoker(
        config: _config(),
        accessTokenProvider: () async => 'sb_publishable_not_a_jwt',
        httpClient: client,
      );

      await invoker.invoke(
        functionName: 'owner-revenue-analytics',
        body: const <String, Object?>{},
        includeInternalKey: true,
      );

      expect(capturedRequest.headers['apikey'], 'anon-key');
      expect(capturedRequest.headers['x-epos-internal-key'], 'internal-key');
      expect(capturedRequest.headers.containsKey('authorization'), isFalse);
    },
  );

  test(
    'suppresses Authorization for sync contracts even when a JWT-shaped token exists',
    () async {
      late http.Request capturedRequest;
      final List<SupabaseEdgeFunctionAuthDiagnostics> diagnostics =
          <SupabaseEdgeFunctionAuthDiagnostics>[];
      final MockClient client = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, Object?>{'ok': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final SupabaseEdgeFunctionInvoker invoker = SupabaseEdgeFunctionInvoker(
        config: _config(),
        accessTokenProvider: () async => 'header.payload.signature',
        diagnosticsSink: diagnostics.add,
        httpClient: client,
      );

      await invoker.invoke(
        functionName: 'mirror-transaction-graph',
        body: const <String, Object?>{},
        includeInternalKey: true,
        includeAuthorization: false,
      );

      expect(capturedRequest.headers['apikey'], 'anon-key');
      expect(capturedRequest.headers['x-epos-internal-key'], 'internal-key');
      expect(capturedRequest.headers.containsKey('authorization'), isFalse);
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.authSource, 'suppressed_by_contract');
      expect(diagnostics.single.authorizationExists, isFalse);
      expect(diagnostics.single.tokenLength, 'header.payload.signature'.length);
      expect(diagnostics.single.tokenPreview, 'header.pay...nature');
    },
  );

  test(
    'sends Authorization only when a JWT-shaped access token exists',
    () async {
      late http.Request capturedRequest;
      final MockClient client = MockClient((http.Request request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode(<String, Object?>{'ok': true}),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });
      final SupabaseEdgeFunctionInvoker invoker = SupabaseEdgeFunctionInvoker(
        config: _config(),
        accessTokenProvider: () async => 'header.payload.signature',
        httpClient: client,
      );

      await invoker.invoke(
        functionName: 'mirror-health',
        body: const <String, Object?>{},
      );

      expect(
        capturedRequest.headers['authorization'],
        'Bearer header.payload.signature',
      );
    },
  );

  test('maps invalid token formatting responses explicitly', () async {
    final MockClient client = MockClient((http.Request request) async {
      return http.Response('Invalid Token or Protected Header formatting', 401);
    });
    final SupabaseEdgeFunctionInvoker invoker = SupabaseEdgeFunctionInvoker(
      config: _config(),
      httpClient: client,
    );

    await expectLater(
      () => invoker.invoke(
        functionName: 'mirror-health',
        body: const <String, Object?>{},
      ),
      throwsA(
        isA<SupabaseEdgeFunctionException>()
            .having(
              (SupabaseEdgeFunctionException error) =>
                  error.isAuthHeaderMalformed,
              'isAuthHeaderMalformed',
              isTrue,
            )
            .having(
              (SupabaseEdgeFunctionException error) => error.retryable,
              'retryable',
              isFalse,
            ),
      ),
    );
  });

  test('rejects bearer-prefixed token candidates before request headers are built',
      () async {
    final List<SupabaseEdgeFunctionAuthDiagnostics> diagnostics =
        <SupabaseEdgeFunctionAuthDiagnostics>[];
    late http.Request capturedRequest;
    final MockClient client = MockClient((http.Request request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode(<String, Object?>{'ok': true}),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });
    final SupabaseEdgeFunctionInvoker invoker = SupabaseEdgeFunctionInvoker(
      config: _config(),
      accessTokenProvider: () async => 'Bearer header.payload.signature',
      diagnosticsSink: diagnostics.add,
      httpClient: client,
    );

    await invoker.invoke(
      functionName: 'mirror-health',
      body: const <String, Object?>{},
    );

    expect(capturedRequest.headers.containsKey('authorization'), isFalse);
    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.authSource, 'rejected_malformed_token_candidate');
    expect(diagnostics.single.authorizationExists, isFalse);
  });

  test('blocks the placeholder local-dev-key instead of sending it', () async {
    final List<SupabaseEdgeFunctionAuthDiagnostics> diagnostics =
        <SupabaseEdgeFunctionAuthDiagnostics>[];
    final SupabaseEdgeFunctionInvoker invoker = SupabaseEdgeFunctionInvoker(
      config: AppConfig.fromValues(
        environment: 'test',
        appVersion: 'test',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        internalApiKey: 'local-dev-key',
      ),
      diagnosticsSink: diagnostics.add,
      httpClient: MockClient((http.Request _) async {
        throw StateError('HTTP client should not be reached.');
      }),
    );

    await expectLater(
      () => invoker.invoke(
        functionName: 'mirror-transaction-graph',
        body: const <String, Object?>{},
        includeInternalKey: true,
        includeAuthorization: false,
      ),
      throwsA(
        isA<SupabaseEdgeFunctionException>()
            .having(
              (SupabaseEdgeFunctionException error) => error.failure,
              'failure',
              'blocked_internal_key_fallback',
            )
            .having(
              (SupabaseEdgeFunctionException error) => error.retryable,
              'retryable',
              isFalse,
            ),
      ),
    );
    expect(diagnostics, hasLength(1));
    expect(diagnostics.single.internalKeyExists, isTrue);
    expect(diagnostics.single.internalKeyLength, 'local-dev-key'.length);
    expect(diagnostics.single.internalKeyPreview, 'local-...-key');
    expect(diagnostics.single.internalKeyFallbackBlocked, isTrue);
  });
}

AppConfig _config() {
  return AppConfig.fromValues(
    environment: 'test',
    appVersion: 'test',
    supabaseUrl: 'https://example.supabase.co',
    supabaseAnonKey: 'anon-key',
    internalApiKey: 'internal-key',
  );
}
