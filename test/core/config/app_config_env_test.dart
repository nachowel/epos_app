import 'package:epos_app/core/config/app_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppConfig reads expected values from a loaded dotenv source', () {
    final DotEnv dotenv = DotEnv()
      ..testLoad(
        fileInput: '''
APP_ENV=staging
APP_VERSION=2.3.4+5
SUPABASE_URL=https://example.supabase.co
SUPABASE_ANON_KEY=anon-key
EPOS_INTERNAL_API_KEY=internal-key
SYNC_MIRROR_WRITE_MODE=trusted_sync_boundary
SYNC_INTERVAL_SECONDS=45
FEATURE_SYNC_ENABLED=true
FEATURE_DEBUG_LOGGING=false
FEATURE_BACKUP_EXPORT_ENABLED=true
''',
      );
    final AppConfig config = AppConfig.fromDotEnv(
      dotenv,
      envFileName: '.env.test',
    );

    expect(config.environment, 'staging');
    expect(config.appVersion, '2.3.4+5');
    expect(config.supabaseUrl, 'https://example.supabase.co');
    expect(config.supabaseAnonKey, 'anon-key');
    expect(config.internalApiKey, 'internal-key');
    expect(config.hasConfiguredInternalApiKey, isTrue);
    expect(config.internalApiKeyLength, 'internal-key'.length);
    expect(config.internalApiKeyPreview, 'intern...-key');
    expect(config.mirrorWriteMode, MirrorWriteMode.trustedSyncBoundary);
    expect(config.syncIntervalSeconds, 45);
    expect(config.featureFlags.syncEnabled, isTrue);
    expect(config.featureFlags.debugLoggingEnabled, isFalse);
    expect(config.featureFlags.backupExportEnabled, isTrue);
    expect(
      config.supabaseConfigurationStatus,
      SupabaseConfigurationStatus.valid,
    );
    expect(config.envLoadIssue, isNull);
    expect(config.analyticsConfigurationIssue, isNull);
    expect(config.startupIssues, isEmpty);
  });

  test('AppConfig reports missing required keys clearly', () {
    final DotEnv dotenv = DotEnv()
      ..testLoad(
        fileInput: '''
FEATURE_SYNC_ENABLED=true
''',
      );
    final AppConfig config = AppConfig.fromDotEnv(dotenv);

    expect(config.supabaseUrl, isNull);
    expect(config.supabaseAnonKey, isNull);
    expect(config.internalApiKey, isNull);
    expect(
      config.supabaseConfigurationIssue,
      'Set SUPABASE_URL and SUPABASE_ANON_KEY in .env to enable sync.',
    );
    expect(
      config.analyticsConfigurationIssue,
      'Set EPOS_INTERNAL_API_KEY in .env to the real trusted boundary key. The placeholder local-dev-key is blocked.',
    );
    expect(config.startupIssues, hasLength(2));
  });

  test('AppConfig blocks the placeholder local-dev-key', () {
    final DotEnv dotenv = DotEnv()
      ..testLoad(
        fileInput: '''
SUPABASE_URL=https://example.supabase.co
SUPABASE_ANON_KEY=anon-key
EPOS_INTERNAL_API_KEY=local-dev-key
FEATURE_SYNC_ENABLED=true
''',
      );
    final AppConfig config = AppConfig.fromDotEnv(dotenv);

    expect(config.internalApiKey, 'local-dev-key');
    expect(config.hasConfiguredInternalApiKey, isFalse);
    expect(config.internalApiKeyPreview, 'local-...-key');
    expect(
      config.analyticsConfigurationIssue,
      'Set EPOS_INTERNAL_API_KEY in .env to the real trusted boundary key. The placeholder local-dev-key is blocked.',
    );
    expect(
      config.startupIssues,
      contains(
        'Set EPOS_INTERNAL_API_KEY in .env to the real trusted boundary key. The placeholder local-dev-key is blocked.',
      ),
    );
  });

  test('AppConfig.load reports a missing env file explicitly', () async {
    final AppConfig config = await AppConfig.load(
      dotenv: DotEnv(),
      fileName: '__missing__.env',
    );

    expect(
      config.envLoadIssue,
      'Environment file __missing__.env was not found. Create it from .env.example before running flutter run.',
    );
    expect(config.hasStartupIssues, isTrue);
    expect(
      config.startupIssues,
      contains(
        'Environment file __missing__.env was not found. Create it from .env.example before running flutter run.',
      ),
    );
  });

  test('production rejects direct mirror write mode', () {
    const AppConfig config = AppConfig(
      environment: 'prod',
      appVersion: '1.0.0+1',
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'anon-key',
      mirrorWriteMode: MirrorWriteMode.directMirrorWrite,
      syncIntervalSeconds: 10,
      featureFlags: FeatureFlags(
        syncEnabled: true,
        debugLoggingEnabled: false,
        backupExportEnabled: true,
      ),
    );

    expect(
      config.mirrorWriteModeIssue,
      'Direct client mirror write is disabled in production. Use trusted_sync_boundary.',
    );
    expect(config.isSupabaseReadyForSync, isFalse);
  });
}
