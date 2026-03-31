import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

typedef SupabaseAccessTokenProvider = Future<String?> Function();
typedef SupabaseEdgeFunctionAuthDiagnosticsSink =
    void Function(SupabaseEdgeFunctionAuthDiagnostics diagnostics);

class SupabaseEdgeFunctionAuthDiagnostics {
  const SupabaseEdgeFunctionAuthDiagnostics({
    required this.functionName,
    required this.authSource,
    required this.authorizationExists,
    required this.authorizationStartsWithBearer,
    required this.tokenLength,
    required this.tokenPreview,
    required this.includeAuthorization,
    required this.includeInternalKey,
    required this.internalKeyExists,
    required this.internalKeyLength,
    required this.internalKeyPreview,
    required this.internalKeyFallbackBlocked,
  });

  final String functionName;
  final String authSource;
  final bool authorizationExists;
  final bool authorizationStartsWithBearer;
  final int tokenLength;
  final String tokenPreview;
  final bool includeAuthorization;
  final bool includeInternalKey;
  final bool internalKeyExists;
  final int internalKeyLength;
  final String internalKeyPreview;
  final bool internalKeyFallbackBlocked;
}

class SupabaseEdgeFunctionResponse {
  const SupabaseEdgeFunctionResponse({
    required this.statusCode,
    required this.data,
    required this.headers,
  });

  final int statusCode;
  final Object? data;
  final Map<String, String> headers;
}

class SupabaseEdgeFunctionException implements Exception {
  const SupabaseEdgeFunctionException({
    required this.statusCode,
    required this.failure,
    required this.message,
    required this.retryable,
    this.details,
  });

  final int statusCode;
  final String failure;
  final String message;
  final bool retryable;
  final Object? details;

  bool get isAuthHeaderMalformed => failure == 'auth_header_malformed';
  bool get isMissingInternalKey => failure == 'missing_internal_key';
  bool get isUnauthorizedInternalKey => failure == 'unauthorized_internal_key';

  @override
  String toString() {
    return 'SupabaseEdgeFunctionException(statusCode: $statusCode, failure: $failure, retryable: $retryable, message: $message, details: $details)';
  }
}

class SupabaseEdgeFunctionInvoker {
  SupabaseEdgeFunctionInvoker({
    required AppConfig config,
    SupabaseAccessTokenProvider? accessTokenProvider,
    SupabaseEdgeFunctionAuthDiagnosticsSink? diagnosticsSink,
    http.Client? httpClient,
  }) : _config = config,
       _accessTokenProvider = accessTokenProvider,
       _diagnosticsSink = diagnosticsSink,
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  static const String _internalKeyHeader = 'x-epos-internal-key';

  final AppConfig _config;
  final SupabaseAccessTokenProvider? _accessTokenProvider;
  final SupabaseEdgeFunctionAuthDiagnosticsSink? _diagnosticsSink;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  Future<void> close() async {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<SupabaseEdgeFunctionResponse> invoke({
    required String functionName,
    required Object? body,
    Map<String, String> headers = const <String, String>{},
    bool includeInternalKey = false,
    bool includeAuthorization = true,
  }) async {
    _assertNoManualAuthorization(headers);
    final Uri url = _buildFunctionUri(functionName);
    final Map<String, String> requestHeaders = await _buildHeaders(
      functionName: functionName,
      headers: headers,
      includeInternalKey: includeInternalKey,
      includeAuthorization: includeAuthorization,
    );

    try {
      final http.Response response = await _httpClient
          .post(url, headers: requestHeaders, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
      final Object? responseBody = _decodeResponseBody(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return SupabaseEdgeFunctionResponse(
          statusCode: response.statusCode,
          data: responseBody,
          headers: response.headers,
        );
      }

      throw _mapHttpError(response, responseBody);
    } on TimeoutException {
      throw const SupabaseEdgeFunctionException(
        statusCode: 408,
        failure: 'network_timeout',
        message: 'Supabase edge function request timed out.',
        retryable: true,
      );
    } on SocketException {
      throw const SupabaseEdgeFunctionException(
        statusCode: 503,
        failure: 'network_unreachable',
        message: 'Supabase edge function service is unreachable.',
        retryable: true,
      );
    }
  }

  Uri _buildFunctionUri(String functionName) {
    final String? supabaseUrl = _config.supabaseUrl?.trim();
    final String? anonKey = _config.supabaseAnonKey?.trim();
    if (supabaseUrl == null ||
        supabaseUrl.isEmpty ||
        anonKey == null ||
        anonKey.isEmpty) {
      throw const SupabaseEdgeFunctionException(
        statusCode: 500,
        failure: 'missing_supabase_config',
        message:
            'Supabase edge function invoke requires SUPABASE_URL and SUPABASE_ANON_KEY.',
        retryable: false,
      );
    }
    return Uri.parse('$supabaseUrl/functions/v1/$functionName');
  }

  Future<Map<String, String>> _buildHeaders({
    required String functionName,
    required Map<String, String> headers,
    required bool includeInternalKey,
    required bool includeAuthorization,
  }) async {
    final String? anonKey = _config.supabaseAnonKey?.trim();
    if (anonKey == null || anonKey.isEmpty) {
      throw const SupabaseEdgeFunctionException(
        statusCode: 500,
        failure: 'missing_supabase_config',
        message:
            'Supabase edge function invoke requires SUPABASE_URL and SUPABASE_ANON_KEY.',
        retryable: false,
      );
    }

    final Map<String, String> requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      'apikey': anonKey,
      ...headers,
    };

    final _ResolvedInternalKey resolvedInternalKey = _resolveInternalKey(
      includeInternalKey,
    );
    final _ResolvedAuthorization resolvedAuthorization =
        await _resolveAuthorization(includeAuthorization);
    if (resolvedAuthorization.token case final String token) {
      requestHeaders['Authorization'] = 'Bearer $token';
    }

    _diagnosticsSink?.call(
      SupabaseEdgeFunctionAuthDiagnostics(
        functionName: functionName,
        authSource: resolvedAuthorization.source,
        authorizationExists: requestHeaders.containsKey('Authorization'),
        authorizationStartsWithBearer:
            requestHeaders['Authorization']?.startsWith('Bearer ') ?? false,
        tokenLength: resolvedAuthorization.token?.length ??
            resolvedAuthorization.candidateLength,
        tokenPreview: resolvedAuthorization.tokenPreview,
        includeAuthorization: includeAuthorization,
        includeInternalKey: includeInternalKey,
        internalKeyExists: resolvedInternalKey.exists,
        internalKeyLength: resolvedInternalKey.length,
        internalKeyPreview: resolvedInternalKey.preview,
        internalKeyFallbackBlocked: resolvedInternalKey.fallbackBlocked,
      ),
    );

    if (includeInternalKey) {
      if (resolvedInternalKey.value == null) {
        throw SupabaseEdgeFunctionException(
          statusCode: 401,
          failure: resolvedInternalKey.fallbackBlocked
              ? 'blocked_internal_key_fallback'
              : 'missing_internal_key',
          message: resolvedInternalKey.fallbackBlocked
              ? 'EPOS_INTERNAL_API_KEY is still set to the blocked placeholder local-dev-key. Configure the real trusted boundary key.'
              : 'EPOS_INTERNAL_API_KEY is missing. Secure edge function calls require x-epos-internal-key.',
          retryable: false,
        );
      }
      requestHeaders[_internalKeyHeader] = resolvedInternalKey.value!;
    }

    return requestHeaders;
  }

  _ResolvedInternalKey _resolveInternalKey(bool includeInternalKey) {
    if (!includeInternalKey) {
      return const _ResolvedInternalKey(
        exists: false,
        value: null,
        length: 0,
        preview: '-',
        fallbackBlocked: false,
      );
    }
    final String? trimmed = _config.internalApiKey?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return const _ResolvedInternalKey(
        exists: false,
        value: null,
        length: 0,
        preview: '-',
        fallbackBlocked: false,
      );
    }
    final bool fallbackBlocked = trimmed == AppConfig.blockedDevInternalApiKey;
    return _ResolvedInternalKey(
      exists: true,
      value: fallbackBlocked ? null : trimmed,
      length: trimmed.length,
      preview: _maskInternalKey(trimmed),
      fallbackBlocked: fallbackBlocked,
    );
  }

  Future<_ResolvedAuthorization> _resolveAuthorization(
    bool includeAuthorization,
  ) async {
    final String? candidate = await _accessTokenProvider?.call();
    final String? trimmedCandidate = candidate?.trim();
    final int candidateLength = trimmedCandidate?.length ?? 0;
    final String tokenPreview = _maskToken(trimmedCandidate);

    if (!includeAuthorization) {
      return _ResolvedAuthorization(
        source: trimmedCandidate == null || trimmedCandidate.isEmpty
            ? 'suppressed_no_token_required'
            : 'suppressed_by_contract',
        token: null,
        candidateLength: candidateLength,
        tokenPreview: tokenPreview,
      );
    }
    if (trimmedCandidate == null || trimmedCandidate.isEmpty) {
      return const _ResolvedAuthorization(
        source: 'no_access_token_available',
        token: null,
        candidateLength: 0,
        tokenPreview: '-',
      );
    }
    if (_hasForbiddenTokenFormatting(trimmedCandidate)) {
      return _ResolvedAuthorization(
        source: 'rejected_malformed_token_candidate',
        token: null,
        candidateLength: candidateLength,
        tokenPreview: tokenPreview,
      );
    }
    if (_looksLikeJwt(trimmedCandidate)) {
      return _ResolvedAuthorization(
        source: 'session_access_token',
        token: trimmedCandidate,
        candidateLength: candidateLength,
        tokenPreview: tokenPreview,
      );
    }
    return _ResolvedAuthorization(
      source: 'rejected_non_jwt_candidate',
      token: null,
      candidateLength: candidateLength,
      tokenPreview: tokenPreview,
    );
  }

  void _assertNoManualAuthorization(Map<String, String> headers) {
    final bool hasAuthorizationHeader = headers.keys.any(
      (String key) => key.toLowerCase() == 'authorization',
    );
    if (!hasAuthorizationHeader) {
      return;
    }
    throw const SupabaseEdgeFunctionException(
      statusCode: 400,
      failure: 'auth_header_malformed',
      message:
          'Authorization header is managed automatically. Do not send publishable keys or internal keys as Bearer tokens.',
      retryable: false,
    );
  }

  Object? _decodeResponseBody(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    final String rawBody = utf8.decode(response.bodyBytes).trim();
    if (rawBody.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(rawBody);
    } catch (_) {
      return rawBody;
    }
  }

  SupabaseEdgeFunctionException _mapHttpError(
    http.Response response,
    Object? responseBody,
  ) {
    if (responseBody is Map) {
      final Map<String, Object?> json = Map<String, Object?>.from(responseBody);
      return SupabaseEdgeFunctionException(
        statusCode: response.statusCode,
        failure: (json['failure'] as String?) ?? 'edge_function_error',
        message:
            (json['message'] as String?) ??
            'Supabase edge function request failed.',
        retryable: (json['retryable'] as bool?) ?? false,
        details: json,
      );
    }

    final String rawMessage = responseBody?.toString().trim() ?? '';
    final String lowerMessage = rawMessage.toLowerCase();
    if (response.statusCode == 401 &&
        lowerMessage.contains('invalid token or protected header formatting')) {
      return const SupabaseEdgeFunctionException(
        statusCode: 401,
        failure: 'auth_header_malformed',
        message:
            'Supabase rejected a malformed Authorization header. Do not send publishable keys or internal keys as Bearer tokens.',
        retryable: false,
      );
    }

    return SupabaseEdgeFunctionException(
      statusCode: response.statusCode,
      failure: 'edge_function_error',
      message: rawMessage.isEmpty
          ? 'Supabase edge function request failed.'
          : rawMessage,
      retryable: response.statusCode >= 500,
      details: responseBody,
    );
  }

  bool _looksLikeJwt(String? token) {
    if (token == null) {
      return false;
    }
    final String trimmed = token.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final List<String> parts = trimmed.split('.');
    return parts.length == 3 &&
        parts.every(
          (String part) =>
              part.trim().isNotEmpty &&
              RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(part),
        );
  }

  bool _hasForbiddenTokenFormatting(String token) {
    return token.toLowerCase().startsWith('bearer ') ||
        token.contains('\n') ||
        token.contains('\r') ||
        token.contains('"') ||
        token.contains("'") ||
        token.contains(' ');
  }

  String _maskToken(String? token) {
    if (token == null || token.isEmpty) {
      return '-';
    }
    if (token.length <= 16) {
      return '${token.substring(0, token.length.clamp(0, 4))}...';
    }
    return '${token.substring(0, 10)}...${token.substring(token.length - 6)}';
  }

  String _maskInternalKey(String? key) {
    if (key == null || key.isEmpty) {
      return '-';
    }
    if (key.length <= 10) {
      return '${key.substring(0, key.length.clamp(0, 3))}...';
    }
    return '${key.substring(0, 6)}...${key.substring(key.length - 4)}';
  }
}

class _ResolvedAuthorization {
  const _ResolvedAuthorization({
    required this.source,
    required this.token,
    required this.candidateLength,
    required this.tokenPreview,
  });

  final String source;
  final String? token;
  final int candidateLength;
  final String tokenPreview;
}

class _ResolvedInternalKey {
  const _ResolvedInternalKey({
    required this.exists,
    required this.value,
    required this.length,
    required this.preview,
    required this.fallbackBlocked,
  });

  final bool exists;
  final String? value;
  final int length;
  final String preview;
  final bool fallbackBlocked;
}
