import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_mirror_writer.dart';
import 'sync_transaction_graph.dart';
import 'trusted_mirror_boundary_contract.dart';

abstract class TrustedMirrorBoundaryInvoker {
  Future<TrustedMirrorWriteSuccess> invoke(
    TrustedMirrorWriteRequest request,
  );
}

class SupabaseTrustedMirrorBoundaryInvoker
    implements TrustedMirrorBoundaryInvoker {
  const SupabaseTrustedMirrorBoundaryInvoker(this._client);

  final SupabaseClient _client;

  @override
  Future<TrustedMirrorWriteSuccess> invoke(
    TrustedMirrorWriteRequest request,
  ) async {
    try {
      final FunctionResponse response = await _client.functions
          .invoke(
            TrustedMirrorWriteRequest.functionName,
            body: request.toJson(),
          )
          .timeout(const Duration(seconds: 20));
      final dynamic data = response.data;
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
    } on SocketException catch (error) {
      throw MirrorWriteFailure(
        type: MirrorWriteFailureType.networkUnreachable,
        message: 'Trusted mirror boundary is unreachable.',
        retryable: true,
        details: error,
      );
    } on FunctionException catch (error) {
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

  MirrorWriteFailure _mapFunctionException(FunctionException error) {
    final Object? details = error.details;
    final Map<String, Object?>? json = details is Map
        ? Map<String, Object?>.from(details)
        : null;

    if (error.status == 400 || error.status == 422) {
      return MirrorWriteFailure(
        type: MirrorWriteFailureType.validationFailure,
        message:
            (json?['message'] as String?) ??
            'Trusted mirror boundary rejected the payload.',
        retryable: false,
        details: details,
      );
    }
    if (error.status == 401 || error.status == 403) {
      return MirrorWriteFailure(
        type: MirrorWriteFailureType.authOrConfigFailure,
        message:
            (json?['message'] as String?) ??
            'Trusted mirror boundary rejected the client credentials.',
        retryable: false,
        details: details,
      );
    }

    return MirrorWriteFailure(
      type: MirrorWriteFailureType.remoteServerError,
      message:
          (json?['message'] as String?) ??
          'Trusted mirror boundary failed on the server.',
      retryable: true,
      details: details,
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
