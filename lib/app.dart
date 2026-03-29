import 'dart:async';

import 'package:epos_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_sizes.dart';
import 'core/localization/app_localization_service.dart';
import 'core/logging/app_logger.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'data/database/app_database.dart';
import 'data/sync/supabase_client_provider.dart';
import 'data/sync/sync_worker.dart';
import 'presentation/providers/app_locale_provider.dart';

class EposApp extends StatelessWidget {
  const EposApp({
    required this.database,
    required this.appConfig,
    required this.appLogger,
    required this.sharedPreferences,
    this.supabaseClient,
    super.key,
  });

  final AppDatabase database;
  final AppConfig appConfig;
  final AppLogger appLogger;
  final SharedPreferences sharedPreferences;
  final SupabaseClient? supabaseClient;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(database),
        appConfigProvider.overrideWithValue(appConfig),
        appLoggerProvider.overrideWithValue(appLogger),
        supabaseClientProvider.overrideWithValue(supabaseClient),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const _SyncBootstrap(child: _AppView()),
    );
  }
}

class _SyncBootstrap extends ConsumerStatefulWidget {
  const _SyncBootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_SyncBootstrap> createState() => _SyncBootstrapState();
}

class _SyncBootstrapState extends ConsumerState<_SyncBootstrap> {
  late final SyncWorker _worker;

  @override
  void initState() {
    super.initState();
    _worker = ref.read(syncWorkerProvider);
    Future<void>.microtask(() async {
      await _worker.start();
    });
  }

  @override
  void dispose() {
    unawaited(_worker.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _AppView extends ConsumerWidget {
  const _AppView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);
    AppLocalizationService.instance.setLocale(locale);

    return MaterialApp.router(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)!.appTitle,
      routerConfig: router,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: AppSizes.fontSm),
        ),
      ),
    );
  }
}
