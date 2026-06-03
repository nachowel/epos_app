import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/bootstrap/bootstrap_policy.dart';
import 'core/bootstrap/pre_install_backup_runner.dart';
import 'core/config/app_config.dart';
import 'core/logging/app_logger.dart';
import 'core/ops/app_crash_guard.dart';
import 'data/database/app_database.dart';
import 'data/database/seed_data.dart';
import 'presentation/screens/startup/startup_failure_app.dart';

Future<void> main(List<String> args) async {
  AppLogger logger = const NoopAppLogger();
  late final AppConfig config;

  await AppCrashGuard.runGuarded(
    logger: () => logger,
    body: () async {
      WidgetsFlutterBinding.ensureInitialized();

      if (args.contains('--backup-before-upgrade')) {
        final PreInstallBackupResult result =
            await const PreInstallBackupRunner(
              databaseFileResolver: AppDatabase.resolveDefaultDatabaseFile,
            ).run();
        if (result.exitCode == 0) {
          io.stdout.writeln(result.message);
        } else {
          io.stderr.writeln(result.message);
        }
        io.exit(result.exitCode);
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        await windowManager.ensureInitialized();
      }
      tz_data.initializeTimeZones();
      config = await AppConfig.load();
      debugPrint(
        'EPOS_INTERNAL_API_KEY bootstrap: source=${config.envFileName}, '
        'exists=${config.hasConfiguredInternalApiKey}, '
        'length=${config.internalApiKeyLength}, '
        'preview=${config.internalApiKeyPreview}. '
        'Full app restart required after .env changes.',
      );
      if (config.hasStartupIssues) {
        debugPrint(config.startupIssues.join('\n'));
      }
      logger = await StructuredAppLogger.create(
        enableInfoLogs: config.featureFlags.debugLoggingEnabled,
      );
      AppCrashGuard.installFlutterErrorHandler(logger);
      if (config.hasStartupIssues) {
        logger.error(
          eventType: 'app_config_invalid',
          message:
              'Application configuration loaded with explicit issues; degraded features may follow.',
          metadata: <String, Object?>{
            'environment': config.environment,
            'env_file': config.envFileName,
            'issues': config.startupIssues,
          },
        );
      }
      logger.audit(
        eventType: 'app_config_loaded',
        message:
            'Application configuration loaded from the bundled environment asset.',
        metadata: <String, Object?>{
          'environment': config.environment,
          'env_file': config.envFileName,
          'internal_api_key_exists': config.hasConfiguredInternalApiKey,
          'internal_api_key_length': config.internalApiKeyLength,
          'internal_api_key_preview': config.internalApiKeyPreview,
          'full_restart_required_after_env_change': true,
        },
      );
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final SupabaseClient? supabaseClient =
          await _initialiseSupabaseIfConfigured(config, logger);
      final io.File databaseFile =
          await AppDatabase.resolveDefaultDatabaseFile();
      final AppDatabase database = AppDatabase();
      try {
        await database.customSelect('PRAGMA user_version;').get();
        if (BootstrapPolicy.shouldAutoSeed) {
          await SeedData.insertIfEmpty(database);
        }
      } catch (error, stackTrace) {
        try {
          await database.close();
        } catch (_) {
          // Ignore close failures while rendering the controlled startup error.
        }
        logger.error(
          eventType: 'database_startup_failed',
          message:
              'Database startup failed during migration or seed validation.',
          metadata: <String, Object?>{
            'database_path': databaseFile.path,
            'backup_directory':
                '${databaseFile.parent.path}${io.Platform.pathSeparator}backups',
            'schema_version': AppDatabase.currentSchemaVersion,
          },
          error: error,
          stackTrace: stackTrace,
        );
        runApp(
          StartupFailureApp.databaseMigrationFailure(
            databasePath: databaseFile.path,
            backupDirectoryPath:
                '${databaseFile.parent.path}${io.Platform.pathSeparator}backups',
            technicalDetails: error.toString(),
          ),
        );
        return;
      }
      logger.audit(
        eventType: 'app_bootstrap_completed',
        message: 'Application bootstrap completed.',
        metadata: <String, Object?>{
          'environment': config.environment,
          'app_version': config.appVersion,
          'sync_enabled': config.featureFlags.syncEnabled,
        },
      );
      runApp(
        EposApp(
          database: database,
          supabaseClient: supabaseClient,
          appConfig: config,
          appLogger: logger,
          sharedPreferences: prefs,
        ),
      );
    },
  );
}

Future<SupabaseClient?> _initialiseSupabaseIfConfigured(
  AppConfig config,
  AppLogger logger,
) async {
  switch (config.supabaseConfigurationStatus) {
    case SupabaseConfigurationStatus.disabled:
      logger.audit(
        eventType: 'sync_bootstrap_skipped',
        message: 'Supabase bootstrap skipped because sync is disabled.',
      );
      return null;
    case SupabaseConfigurationStatus.missing:
    case SupabaseConfigurationStatus.invalidUrl:
    case SupabaseConfigurationStatus.rejectedServiceRoleKey:
      logger.warn(
        eventType: 'sync_misconfigured',
        message:
            config.supabaseConfigurationIssue ??
            'Supabase sync is not configured.',
        metadata: <String, Object?>{
          'configuration_status': config.supabaseConfigurationStatus.name,
        },
      );
      return null;
    case SupabaseConfigurationStatus.valid:
      break;
  }

  try {
    await Supabase.initialize(
      url: config.supabaseUrl!,
      anonKey: config.supabaseAnonKey!,
    );
    final Session? session = Supabase.instance.client.auth.currentSession;
    debugPrint('=== ANALYTICS DEBUG ===');
    debugPrint('USER ID: ${session?.user.id}');
    debugPrint('TOKEN NULL: ${session?.accessToken == null}');
    logger.audit(
      eventType: 'supabase_initialized',
      message: 'Supabase client initialized for sync.',
      metadata: <String, Object?>{
        'configuration_status': config.supabaseConfigurationStatus.name,
      },
    );
    return Supabase.instance.client;
  } catch (error, stackTrace) {
    logger.error(
      eventType: 'supabase_initialization_failed',
      message: 'Supabase initialization failed; app will continue degraded.',
      metadata: <String, Object?>{
        'configuration_status': config.supabaseConfigurationStatus.name,
      },
      error: error,
      stackTrace: stackTrace,
    );
    return null;
  }
}
