import 'package:epos_app/core/config/app_config.dart';
import 'package:epos_app/core/config/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppConfig.fromEnvironment maps Env values safely', () {
    final AppConfig config = AppConfig.fromEnvironment(
      env: const Env(
        environment: 'staging',
        appVersion: '2.3.4+5',
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        syncMirrorWriteMode: 'trusted_sync_boundary',
        syncIntervalSeconds: '45',
        syncEnabled: 'true',
        debugLoggingEnabled: 'false',
        backupExportEnabled: 'true',
      ),
    );

    expect(config.environment, 'staging');
    expect(config.appVersion, '2.3.4+5');
    expect(config.supabaseUrl, 'https://example.supabase.co');
    expect(config.supabaseAnonKey, 'anon-key');
    expect(config.mirrorWriteMode, MirrorWriteMode.trustedSyncBoundary);
    expect(config.syncIntervalSeconds, 45);
    expect(config.featureFlags.syncEnabled, isTrue);
    expect(config.featureFlags.debugLoggingEnabled, isFalse);
    expect(config.featureFlags.backupExportEnabled, isTrue);
    expect(config.supabaseConfigurationStatus, SupabaseConfigurationStatus.valid);
  });

  test('AppConfig.fromEnvironment treats empty Supabase config as optional', () {
    final AppConfig config = AppConfig.fromEnvironment(
      env: const Env(
        environment: '',
        appVersion: '',
        supabaseUrl: '',
        supabaseAnonKey: '',
        syncMirrorWriteMode: '',
        syncIntervalSeconds: '',
        syncEnabled: 'true',
        debugLoggingEnabled: '',
        backupExportEnabled: '',
      ),
    );

    expect(config.supabaseUrl, isNull);
    expect(config.supabaseAnonKey, isNull);
    expect(config.mirrorWriteMode, MirrorWriteMode.trustedSyncBoundary);
    expect(config.supabaseConfigurationStatus, SupabaseConfigurationStatus.missing);
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
