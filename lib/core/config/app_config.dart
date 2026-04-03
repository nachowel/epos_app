import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

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
    this.internalApiKey,
    String analyticsEmail = '',
    String analyticsPassword = '',
    this.mirrorWriteMode = MirrorWriteMode.directMirrorWrite,
    required this.syncIntervalSeconds,
    required this.featureFlags,
    this.envFileName = defaultEnvFileName,
    this.envLoadIssue,
  }) : _analyticsEmail = analyticsEmail,
       _analyticsPassword = analyticsPassword;

  static const String defaultEnvFileName = '.env';
  static const String _environmentKey = 'APP_ENV';
  static const String _appVersionKey = 'APP_VERSION';
  static const String _supabaseUrlKey = 'SUPABASE_URL';
  static const String _supabaseAnonKeyKey = 'SUPABASE_ANON_KEY';
  static const String _internalApiKeyKey = 'EPOS_INTERNAL_API_KEY';
  static const String _analyticsEmailKey = 'ANALYTICS_EMAIL';
  static const String _analyticsPasswordKey = 'ANALYTICS_PASSWORD';
  static const String blockedDevInternalApiKey = 'local-dev-key';
  static const String _syncMirrorWriteModeKey = 'SYNC_MIRROR_WRITE_MODE';
  static const String _syncIntervalSecondsKey = 'SYNC_INTERVAL_SECONDS';
  static const String _syncEnabledKey = 'FEATURE_SYNC_ENABLED';
  static const String _debugLoggingEnabledKey = 'FEATURE_DEBUG_LOGGING';
  static const String _backupExportEnabledKey = 'FEATURE_BACKUP_EXPORT_ENABLED';

  static Future<AppConfig> load({
    DotEnv? dotenv,
    String fileName = defaultEnvFileName,
  }) async {
    final DotEnv resolvedDotEnv = dotenv ?? DotEnv();
    String? envLoadIssue;

    try {
      await resolvedDotEnv.load(fileName: fileName);
    } on FileNotFoundError {
      envLoadIssue =
          'Environment file $fileName was not found. Create it from .env.example before running flutter run.';
    } on EmptyEnvFileError {
      envLoadIssue =
          'Environment file $fileName is empty. Populate it before running flutter run.';
    }

    return AppConfig.fromDotEnv(
      resolvedDotEnv,
      envFileName: fileName,
      envLoadIssue: envLoadIssue,
    );
  }

  static AppConfig fallback({
    String issue =
        'AppConfig was not bootstrapped. Override appConfigProvider at app startup.',
  }) {
    return AppConfig.fromValues(
      environment: 'dev',
      appVersion: '1.0.0+1',
      featureFlags: const FeatureFlags(
        syncEnabled: true,
        debugLoggingEnabled: false,
        backupExportEnabled: true,
      ),
      envLoadIssue: issue,
    );
  }

  static AppConfig fromDotEnv(
    DotEnv dotenv, {
    String envFileName = defaultEnvFileName,
    String? envLoadIssue,
  }) {
    final Map<String, String> values = dotenv.isInitialized
        ? Map<String, String>.from(dotenv.env)
        : const <String, String>{};
    return AppConfig.fromMap(
      values,
      envFileName: envFileName,
      envLoadIssue: envLoadIssue,
    );
  }

  static AppConfig fromMap(
    Map<String, String> values, {
    String envFileName = defaultEnvFileName,
    String? envLoadIssue,
  }) {
    return AppConfig(
      environment:
          _readString(values, _environmentKey) ??
          (kReleaseMode ? 'prod' : 'dev'),
      appVersion: _readString(values, _appVersionKey) ?? '1.0.0+1',
      supabaseUrl: _readString(values, _supabaseUrlKey),
      supabaseAnonKey: _readString(values, _supabaseAnonKeyKey),
      internalApiKey: _readString(values, _internalApiKeyKey),
      analyticsEmail: _readString(values, _analyticsEmailKey) ?? '',
      analyticsPassword: _readString(values, _analyticsPasswordKey) ?? '',
      mirrorWriteMode: MirrorWriteMode.fromRaw(
        values[_syncMirrorWriteModeKey] ?? '',
      ),
      syncIntervalSeconds:
          int.tryParse(values[_syncIntervalSecondsKey]?.trim() ?? '') ?? 10,
      featureFlags: FeatureFlags(
        syncEnabled: _readBoolFlag(values[_syncEnabledKey], fallback: true),
        debugLoggingEnabled: _readBoolFlag(
          values[_debugLoggingEnabledKey],
          fallback: kDebugMode,
        ),
        backupExportEnabled: _readBoolFlag(
          values[_backupExportEnabledKey],
          fallback: true,
        ),
      ),
      envFileName: envFileName,
      envLoadIssue: envLoadIssue,
    );
  }

  static AppConfig fromValues({
    required String environment,
    required String appVersion,
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? internalApiKey,
    String analyticsEmail = '',
    String analyticsPassword = '',
    MirrorWriteMode mirrorWriteMode = MirrorWriteMode.trustedSyncBoundary,
    int syncIntervalSeconds = 10,
    FeatureFlags featureFlags = const FeatureFlags(
      syncEnabled: true,
      debugLoggingEnabled: false,
      backupExportEnabled: true,
    ),
    String envFileName = defaultEnvFileName,
    String? envLoadIssue,
  }) {
    return AppConfig(
      environment: environment,
      appVersion: appVersion,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      internalApiKey: internalApiKey,
      analyticsEmail: analyticsEmail,
      analyticsPassword: analyticsPassword,
      mirrorWriteMode: mirrorWriteMode,
      syncIntervalSeconds: syncIntervalSeconds,
      featureFlags: featureFlags,
      envFileName: envFileName,
      envLoadIssue: envLoadIssue,
    );
  }

  final String environment;
  final String appVersion;
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final String? internalApiKey;
  final String _analyticsEmail;
  final String _analyticsPassword;
  final MirrorWriteMode mirrorWriteMode;
  final int syncIntervalSeconds;
  final FeatureFlags featureFlags;
  final String envFileName;
  final String? envLoadIssue;

  bool get isProductionEnvironment =>
      environment.trim().toLowerCase() == 'prod';

  bool get allowsDirectMirrorWrite => !isProductionEnvironment;

  String get analyticsEmail => _analyticsEmail;

  String get analyticsPassword => _analyticsPassword;

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

  bool get hasConfiguredInternalApiKey {
    final String? key = internalApiKey?.trim();
    return key != null &&
        key.isNotEmpty &&
        key != blockedDevInternalApiKey;
  }

  int get internalApiKeyLength => internalApiKey?.trim().length ?? 0;

  String get internalApiKeyPreview {
    final String? key = internalApiKey?.trim();
    if (key == null || key.isEmpty) {
      return '-';
    }
    if (key.length <= 10) {
      return '${key.substring(0, key.length.clamp(0, 3))}...';
    }
    return '${key.substring(0, 6)}...${key.substring(key.length - 4)}';
  }

  String? get analyticsConfigurationIssue {
    if (hasConfiguredInternalApiKey) {
      return null;
    }
    return 'Set EPOS_INTERNAL_API_KEY in $envFileName to the real trusted boundary key. The placeholder local-dev-key is blocked.';
  }

  List<String> get startupIssues {
    return <String>[
      if (envLoadIssue case final String issue when issue.trim().isNotEmpty)
        issue,
      if (supabaseConfigurationIssue case final String issue
          when issue.trim().isNotEmpty)
        issue,
      if (analyticsConfigurationIssue case final String issue
          when issue.trim().isNotEmpty)
        issue,
      if (mirrorWriteModeIssue case final String issue
          when issue.trim().isNotEmpty)
        issue,
    ];
  }

  bool get hasStartupIssues => startupIssues.isNotEmpty;

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
        return 'Set SUPABASE_URL and SUPABASE_ANON_KEY in $envFileName to enable sync.';
      case SupabaseConfigurationStatus.invalidUrl:
        return 'SUPABASE_URL must be a valid HTTPS URL.';
      case SupabaseConfigurationStatus.rejectedServiceRoleKey:
        return 'Client builds may use only publishable/anon Supabase keys.';
    }
  }

  Duration get syncInterval => Duration(seconds: syncIntervalSeconds);

  static String? _readString(Map<String, String> values, String key) {
    final String? rawValue = values[key]?.trim();
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }
    return rawValue;
  }

  static bool _readBoolFlag(String? rawValue, {required bool fallback}) {
    if (rawValue == null || rawValue.trim().isEmpty) {
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
