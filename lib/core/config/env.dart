import 'package:flutter/foundation.dart';

class Env {
  const Env({
    required this.environment,
    required this.appVersion,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.syncMirrorWriteMode,
    required this.syncIntervalSeconds,
    required this.syncEnabled,
    required this.debugLoggingEnabled,
    required this.backupExportEnabled,
  });

  factory Env.fromEnvironment() {
    return Env(
      environment: const String.fromEnvironment('APP_ENV'),
      appVersion: const String.fromEnvironment('APP_VERSION'),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
      syncMirrorWriteMode: const String.fromEnvironment(
        'SYNC_MIRROR_WRITE_MODE',
      ),
      syncIntervalSeconds: const String.fromEnvironment('SYNC_INTERVAL_SECONDS'),
      syncEnabled: const String.fromEnvironment('FEATURE_SYNC_ENABLED'),
      debugLoggingEnabled: const String.fromEnvironment(
        'FEATURE_DEBUG_LOGGING',
      ),
      backupExportEnabled: const String.fromEnvironment(
        'FEATURE_BACKUP_EXPORT_ENABLED',
      ),
    );
  }

  final String environment;
  final String appVersion;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String syncMirrorWriteMode;
  final String syncIntervalSeconds;
  final String syncEnabled;
  final String debugLoggingEnabled;
  final String backupExportEnabled;

  String resolvedEnvironment() {
    final String trimmed = environment.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return kReleaseMode ? 'prod' : 'dev';
  }
}
