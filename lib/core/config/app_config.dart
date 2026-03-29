import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'env.dart';

enum SupabaseConfigurationStatus {
  disabled,
  missing,
  invalidUrl,
  rejectedServiceRoleKey,
  valid,
}

enum MirrorWriteMode {
  directMirrorWrite('direct_mirror_write'),
  trustedSyncBoundary('trusted_sync_boundary');

  const MirrorWriteMode(this.value);

  final String value;

  static MirrorWriteMode fromRaw(String rawValue) {
    switch (rawValue.trim()) {
      case '':
      case 'trusted_sync_boundary':
        return MirrorWriteMode.trustedSyncBoundary;
      case 'direct_mirror_write':
        return MirrorWriteMode.directMirrorWrite;
      default:
        return MirrorWriteMode.trustedSyncBoundary;
    }
  }
}

class FeatureFlags {
  const FeatureFlags({
    required this.syncEnabled,
    required this.debugLoggingEnabled,
    required this.backupExportEnabled,
  });

  final bool syncEnabled;
  final bool debugLoggingEnabled;
  final bool backupExportEnabled;
}

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appVersion,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    this.mirrorWriteMode = MirrorWriteMode.directMirrorWrite,
    required this.syncIntervalSeconds,
    required this.featureFlags,
  });

  factory AppConfig.fromEnvironment({Env? env}) {
    final Env resolvedEnv = env ?? Env.fromEnvironment();

    return AppConfig(
      environment: resolvedEnv.resolvedEnvironment(),
      appVersion: resolvedEnv.appVersion.trim().isEmpty
          ? '1.0.0+1'
          : resolvedEnv.appVersion,
      supabaseUrl: resolvedEnv.supabaseUrl.trim().isEmpty
          ? null
          : resolvedEnv.supabaseUrl,
      supabaseAnonKey: resolvedEnv.supabaseAnonKey.trim().isEmpty
          ? null
          : resolvedEnv.supabaseAnonKey,
      mirrorWriteMode: MirrorWriteMode.fromRaw(
        resolvedEnv.syncMirrorWriteMode,
      ),
      syncIntervalSeconds: int.tryParse(resolvedEnv.syncIntervalSeconds) ?? 10,
      featureFlags: FeatureFlags(
        syncEnabled: _readBoolFlag(resolvedEnv.syncEnabled, fallback: true),
        debugLoggingEnabled: _readBoolFlag(
          resolvedEnv.debugLoggingEnabled,
          fallback: kDebugMode,
        ),
        backupExportEnabled: _readBoolFlag(
          resolvedEnv.backupExportEnabled,
          fallback: true,
        ),
      ),
    );
  }

  static AppConfig fromValues({
    required String environment,
    required String appVersion,
    String? supabaseUrl,
    String? supabaseAnonKey,
    MirrorWriteMode mirrorWriteMode = MirrorWriteMode.trustedSyncBoundary,
    int syncIntervalSeconds = 10,
    FeatureFlags featureFlags = const FeatureFlags(
      syncEnabled: true,
      debugLoggingEnabled: false,
      backupExportEnabled: true,
    ),
  }) {
    return AppConfig(
      environment: environment,
      appVersion: appVersion,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      mirrorWriteMode: mirrorWriteMode,
      syncIntervalSeconds: syncIntervalSeconds,
      featureFlags: featureFlags,
    );
  }

  final String environment;
  final String appVersion;
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final MirrorWriteMode mirrorWriteMode;
  final int syncIntervalSeconds;
  final FeatureFlags featureFlags;

  bool get isProductionEnvironment => environment.trim().toLowerCase() == 'prod';

  bool get allowsDirectMirrorWrite => !isProductionEnvironment;

  String? get mirrorWriteModeIssue {
    if (mirrorWriteMode == MirrorWriteMode.directMirrorWrite &&
        !allowsDirectMirrorWrite) {
      return 'Direct client mirror write is disabled in production. Use trusted_sync_boundary.';
    }
    return null;
  }

  bool get hasSupabaseConfig =>
      (supabaseUrl?.trim().isNotEmpty ?? false) &&
      (supabaseAnonKey?.trim().isNotEmpty ?? false);

  SupabaseConfigurationStatus get supabaseConfigurationStatus {
    if (!featureFlags.syncEnabled) {
      return SupabaseConfigurationStatus.disabled;
    }
    if (!hasSupabaseConfig) {
      return SupabaseConfigurationStatus.missing;
    }
    if (!_hasValidHttpsUrl(supabaseUrl!)) {
      return SupabaseConfigurationStatus.invalidUrl;
    }
    if (_looksLikeServiceRoleKey(supabaseAnonKey!)) {
      return SupabaseConfigurationStatus.rejectedServiceRoleKey;
    }
    return SupabaseConfigurationStatus.valid;
  }

  bool get isSupabaseReadyForSync =>
      supabaseConfigurationStatus == SupabaseConfigurationStatus.valid &&
      mirrorWriteModeIssue == null;

  String get supabaseConfigurationLabel {
    switch (supabaseConfigurationStatus) {
      case SupabaseConfigurationStatus.disabled:
        return 'Sync disabled';
      case SupabaseConfigurationStatus.missing:
        return 'Supabase config missing';
      case SupabaseConfigurationStatus.invalidUrl:
        return 'Supabase URL invalid';
      case SupabaseConfigurationStatus.rejectedServiceRoleKey:
        return 'Unsafe Supabase key rejected';
      case SupabaseConfigurationStatus.valid:
        return 'Supabase configured';
    }
  }

  String? get supabaseConfigurationIssue {
    switch (supabaseConfigurationStatus) {
      case SupabaseConfigurationStatus.disabled:
      case SupabaseConfigurationStatus.valid:
        return null;
      case SupabaseConfigurationStatus.missing:
        return 'Set SUPABASE_URL and SUPABASE_ANON_KEY to enable sync.';
      case SupabaseConfigurationStatus.invalidUrl:
        return 'SUPABASE_URL must be a valid HTTPS URL.';
      case SupabaseConfigurationStatus.rejectedServiceRoleKey:
        return 'Client builds may use only publishable/anon Supabase keys.';
    }
  }

  Duration get syncInterval => Duration(seconds: syncIntervalSeconds);

  static bool _readBoolFlag(String rawValue, {required bool fallback}) {
    if (rawValue.trim().isEmpty) {
      return fallback;
    }
    return rawValue.toLowerCase() == 'true';
  }

  static bool _hasValidHttpsUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasScheme &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty;
  }

  static bool _looksLikeServiceRoleKey(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.startsWith('sb_secret_')) {
      return true;
    }
    if (trimmed.toLowerCase().contains('service_role')) {
      return true;
    }

    final List<String> parts = trimmed.split('.');
    if (parts.length != 3) {
      return false;
    }

    try {
      final String normalized = base64Url.normalize(parts[1]);
      final Object? decoded = jsonDecode(
        utf8.decode(base64Url.decode(normalized)),
      );
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      return decoded['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}
