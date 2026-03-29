import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

enum SupabaseConnectionState { notConfigured, available, unreachable, misconfigured }

class SupabaseConnectionStatus {
  const SupabaseConnectionStatus({
    required this.state,
    required this.checkedAt,
    required this.message,
  });

  final SupabaseConnectionState state;
  final DateTime checkedAt;
  final String message;

  bool get isAvailable => state == SupabaseConnectionState.available;
}

abstract class SupabaseConnectionProbe {
  Future<void> run();
}

class SupabaseFlutterConnectionProbe implements SupabaseConnectionProbe {
  const SupabaseFlutterConnectionProbe(this._client);

  final SupabaseClient _client;

  @override
  Future<void> run() async {
    await _client
        .from('transactions')
        .select('uuid')
        .limit(1)
        .timeout(const Duration(seconds: 5));
  }
}

class SupabaseConnectionService {
  const SupabaseConnectionService({
    required AppConfig config,
    SupabaseConnectionProbe? probe,
  }) : _config = config,
       _probe = probe;

  final AppConfig _config;
  final SupabaseConnectionProbe? _probe;

  bool get isConfigured =>
      _config.supabaseConfigurationStatus ==
      SupabaseConfigurationStatus.valid;

  Future<SupabaseConnectionStatus> checkHealth() async {
    final DateTime checkedAt = DateTime.now().toUtc();

    switch (_config.supabaseConfigurationStatus) {
      case SupabaseConfigurationStatus.disabled:
      case SupabaseConfigurationStatus.missing:
        return SupabaseConnectionStatus(
          state: SupabaseConnectionState.notConfigured,
          checkedAt: checkedAt,
          message:
              _config.supabaseConfigurationIssue ??
              'Supabase is not configured for this build.',
        );
      case SupabaseConfigurationStatus.invalidUrl:
      case SupabaseConfigurationStatus.rejectedServiceRoleKey:
        return SupabaseConnectionStatus(
          state: SupabaseConnectionState.misconfigured,
          checkedAt: checkedAt,
          message:
              _config.supabaseConfigurationIssue ??
              'Supabase configuration is invalid.',
        );
      case SupabaseConfigurationStatus.valid:
        break;
    }

    final SupabaseConnectionProbe? probe = _probe;
    if (probe == null) {
      return SupabaseConnectionStatus(
        state: SupabaseConnectionState.unreachable,
        checkedAt: checkedAt,
        message:
            'Supabase is configured, but the client is unavailable in this runtime.',
      );
    }

    try {
      await probe.run();
      return SupabaseConnectionStatus(
        state: SupabaseConnectionState.available,
        checkedAt: checkedAt,
        message: 'Supabase connection check succeeded.',
      );
    } on TimeoutException {
      return SupabaseConnectionStatus(
        state: SupabaseConnectionState.unreachable,
        checkedAt: checkedAt,
        message: 'Supabase connection check timed out.',
      );
    } catch (error) {
      final String lower = error.toString().toLowerCase();
      if (_looksLikeConnectivityIssue(lower)) {
        return SupabaseConnectionStatus(
          state: SupabaseConnectionState.unreachable,
          checkedAt: checkedAt,
          message: 'Supabase is configured but currently unreachable.',
        );
      }
      return SupabaseConnectionStatus(
        state: SupabaseConnectionState.misconfigured,
        checkedAt: checkedAt,
        message: 'Supabase health check failed: $error',
      );
    }
  }

  static bool _looksLikeConnectivityIssue(String value) {
    return value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused') ||
        value.contains('network is unreachable') ||
        value.contains('timed out') ||
        value.contains('clientexception');
  }
}
