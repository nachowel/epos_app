import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import 'supabase_edge_function_invoker.dart';
import 'supabase_mirror_writer.dart';
import 'sync_transaction_graph.dart';
import 'trusted_mirror_boundary_contract.dart';

abstract class TrustedMirrorBoundaryInvoker {
  Future<TrustedMirrorWriteSuccess> invoke(TrustedMirrorWriteRequest request);
}

class SupabaseTrustedMirrorBoundaryInvoker
    implements TrustedMirrorBoundaryInvoker {
  SupabaseTrustedMirrorBoundaryInvoker({
    required SupabaseClient client,
    required AppConfig config,
    AppLogger logger = const NoopAppLogger(),
    SupabaseEdgeFunctionInvoker? functionInvoker,
  }) : _logger = logger,
       _functionInvoker =
           functionInvoker ??
           SupabaseEdgeFunctionInvoker(
             config: config,
             accessTokenProvider: () => _readAccessToken(client),
             diagnosticsSink: (SupabaseEdgeFunctionAuthDiagnostics diagnostics) {
               _logSyncAuthDiagnostics(logger, diagnostics);
             },
           );

  final AppLogger _logger;
  final SupabaseEdgeFunctionInvoker _functionInvoker;

  @override
  Future<TrustedMirrorWriteSuccess> invoke(
    TrustedMirrorWriteRequest request,
  ) async {
    try {
      final Map<String, Object?> payload = request.toJson();
      _logPayloadDiagnostics(_logger, payload);
      final SupabaseEdgeFunctionResponse response = await _functionInvoker
          .invoke(
            functionName: TrustedMirrorWriteRequest.functionName,
            body: payload,
            includeInternalKey: true,
            includeAuthorization: false,
          );
      final Object? data = response.data;
      if (data is! Map) {
        throw const MirrorWriteFailure(
          type: MirrorWriteFailureType.remoteServerError,
          message: 'Trusted boundary returned a non-JSON response.',
          retryable: true,
        );
      }

      return TrustedMirrorWriteSuccess.fromJson(
        Map<String, Object?>.from(data),
      );
    } on TimeoutException catch (error) {
      throw MirrorWriteFailure(
        type: MirrorWriteFailureType.networkUnreachable,
        message: 'Trusted mirror boundary timed out.',
        retryable: true,
        details: error,
      );
    } on SupabaseEdgeFunctionException catch (error) {
      throw _mapFunctionException(error);
    } catch (error) {
      final String lower = error.toString().toLowerCase();
      if (lower.contains('clientexception') ||
          lower.contains('socketexception') ||
          lower.contains('failed host lookup') ||
          lower.contains('network is unreachable')) {
        throw MirrorWriteFailure(
          type: MirrorWriteFailureType.networkUnreachable,
          message: 'Trusted mirror boundary is unreachable.',
          retryable: true,
          details: error,
        );
      }

      throw MirrorWriteFailure(
        type: MirrorWriteFailureType.remoteServerError,
        message: 'Trusted mirror boundary failed unexpectedly.',
        retryable: true,
        details: error,
      );
    }
  }

  MirrorWriteFailure _mapFunctionException(
    SupabaseEdgeFunctionException error,
  ) {
    final Object? details = error.details;
    final Map<String, Object?>? json = details is Map
        ? Map<String, Object?>.from(details)
        : null;
    final List<String> issues =
        (json?['issues'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const <String>[];
    final List<String> recordUuids =
        (json?['record_uuids'] as List?)?.whereType<String>().toList(
          growable: false,
        ) ??
        const <String>[];
    final String? tableName =
        (json?['table'] as String?) ?? _inferTableName(issues);
    final String? recordUuid = json?['record_uuid'] as String?;

    if (error.statusCode == 400 || error.statusCode == 422) {
      final String issueSummary = issues.take(3).join('; ');
      return MirrorWriteFailure(
        type: MirrorWriteFailureType.validationFailure,
        message: issueSummary.isEmpty
            ? ((json?['message'] as String?) ??
                  'Trusted mirror boundary rejected the payload.')
            : '${(json?['message'] as String?) ?? 'Trusted mirror boundary rejected the payload.'} Issues: $issueSummary',
        retryable: false,
        details: details,
        tableName: tableName,
        recordUuid: recordUuid,
        recordUuids: recordUuids,
        issues: issues,
      );
    }
    if (error.statusCode == 401 || error.statusCode == 403) {
      final String message = switch (error.failure) {
        'auth_header_malformed' =>
          'Trusted mirror boundary rejected a malformed Authorization header. Remove publishable/internal Bearer tokens.',
        'missing_internal_key' =>
          'Trusted mirror boundary internal key is missing from app configuration.',
        'blocked_internal_key_fallback' =>
          'Trusted mirror boundary internal key is still set to the blocked placeholder local-dev-key. Configure the real EPOS_INTERNAL_API_KEY.',
        'unauthorized_internal_key' =>
          'Trusted mirror boundary rejected the configured internal key.',
        _ =>
          (json?['message'] as String?) ??
              'Trusted mirror boundary rejected the client credentials.',
      };
      return MirrorWriteFailure(
        type: MirrorWriteFailureType.authOrConfigFailure,
        message: message,
        retryable: false,
        details: details,
        tableName: tableName,
        recordUuid: recordUuid,
        recordUuids: recordUuids,
        issues: issues,
      );
    }

    return MirrorWriteFailure(
      type: MirrorWriteFailureType.remoteServerError,
      message:
          (json?['message'] as String?) ??
          'Trusted mirror boundary failed on the server.',
      retryable: true,
      details: details,
      tableName: tableName,
      recordUuid: recordUuid,
      recordUuids: recordUuids,
      issues: issues,
    );
  }

  static Future<String?> _readAccessToken(SupabaseClient client) async {
    try {
      return client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  String? _inferTableName(List<String> issues) {
    for (final String issue in issues) {
      if (issue.startsWith('transaction_lines')) {
        return 'transaction_lines';
      }
      if (issue.startsWith('order_modifiers')) {
        return 'order_modifiers';
      }
      if (issue.startsWith('payment.')) {
        return 'payments';
      }
      if (issue.startsWith('payments')) {
        return 'payments';
      }
      if (issue.startsWith('transaction.')) {
        return 'transactions';
      }
    }
    return null;
  }

  static void _logSyncAuthDiagnostics(
    AppLogger logger,
    SupabaseEdgeFunctionAuthDiagnostics diagnostics,
  ) {
    final Map<String, Object?> metadata = <String, Object?>{
      'function_name': diagnostics.functionName,
      'auth_source': diagnostics.authSource,
      'authorization_exists': diagnostics.authorizationExists,
      'authorization_starts_with_bearer':
          diagnostics.authorizationStartsWithBearer,
      'token_length': diagnostics.tokenLength,
      'token_preview': diagnostics.tokenPreview,
      'include_authorization': diagnostics.includeAuthorization,
      'include_internal_key': diagnostics.includeInternalKey,
      'internal_key_exists': diagnostics.internalKeyExists,
      'internal_key_length': diagnostics.internalKeyLength,
      'internal_key_preview': diagnostics.internalKeyPreview,
      'internal_key_fallback_blocked': diagnostics.internalKeyFallbackBlocked,
    };
    if (diagnostics.internalKeyFallbackBlocked) {
      logger.warn(
        eventType: 'sync_internal_key_fallback_blocked',
        message:
            'Blocked the placeholder local-dev-key before calling the trusted mirror boundary.',
        metadata: metadata,
      );
      return;
    }
    if (diagnostics.authSource.startsWith('rejected_')) {
      logger.warn(
        eventType: 'sync_edge_function_auth_candidate_rejected',
        message:
            'Rejected a malformed or non-JWT Authorization candidate before calling the trusted mirror boundary.',
        metadata: metadata,
      );
      return;
    }
    logger.audit(
      eventType: 'sync_edge_function_auth_selected',
      message: 'Prepared trusted mirror boundary auth headers.',
      metadata: metadata,
    );
  }

  static void _logPayloadDiagnostics(
    AppLogger logger,
    Map<String, Object?> payload,
  ) {
    final List<Object?> transactionLines =
        (payload['transaction_lines'] as List<Object?>?) ?? const <Object?>[];
    final List<Object?> orderModifiers =
        (payload['order_modifiers'] as List<Object?>?) ?? const <Object?>[];
    final List<Object?> payments =
        (payload['payments'] as List<Object?>?) ?? const <Object?>[];
    logger.audit(
      eventType: 'sync_trusted_mirror_payload_prepared',
      message: 'Prepared trusted mirror boundary payload before dispatch.',
      metadata: <String, Object?>{
        'top_level_payload_keys': payload.keys.toList(growable: false),
        'payload_version': payload['payload_version'],
        'transaction_uuid_present':
            (payload['transaction_uuid'] as String?)?.trim().isNotEmpty ??
            false,
        'transaction_idempotency_key_present':
            (payload['transaction_idempotency_key'] as String?)
                ?.trim()
                .isNotEmpty ??
            false,
        'generated_at_present':
            (payload['generated_at'] as String?)?.trim().isNotEmpty ?? false,
        'transaction_present': payload['transaction'] is Map,
        'transaction_lines_count': transactionLines.length,
        'order_modifiers_count': orderModifiers.length,
        'payments_count': payments.length,
      },
    );
  }
}

/// Preferred mirror writer for hardened deployments.
///
/// The client still decides when finalized local state should be mirrored, but
/// the actual remote persistence happens behind a trusted server-side boundary.
class TrustedSupabaseMirrorWriter implements SupabaseMirrorWriter {
  const TrustedSupabaseMirrorWriter(this._invoker);

  final TrustedMirrorBoundaryInvoker _invoker;

  @override
  Future<void> writeTransactionGraph(SyncTransactionGraph graph) async {
    final TrustedMirrorWriteRequest request =
        TrustedMirrorWriteRequest.fromGraph(graph);
    await _invoker.invoke(request);
  }
}
