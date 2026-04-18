import 'dart:async';

import 'package:epos_app/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

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
    return _WindowsWakeLockScope(
      child: ProviderScope(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(database),
          appConfigProvider.overrideWithValue(appConfig),
          appLoggerProvider.overrideWithValue(appLogger),
          supabaseClientProvider.overrideWithValue(supabaseClient),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const _SyncBootstrap(child: _AppView()),
      ),
    );
  }
}

class _WindowsWakeLockScope extends StatefulWidget {
  const _WindowsWakeLockScope({required this.child});

  final Widget child;

  @override
  State<_WindowsWakeLockScope> createState() => _WindowsWakeLockScopeState();
}

class _WindowsWakeLockScopeState extends State<_WindowsWakeLockScope> {
  bool _windowBootstrapScheduled = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _windowBootstrapScheduled) {
          return;
        }
        _windowBootstrapScheduled = true;
        unawaited(_bootstrapWindowsShell());
      });
    }
  }

  Future<void> _bootstrapWindowsShell() async {
    try {
      final bool isVisible = await windowManager.isVisible();
      if (!isVisible) {
        await windowManager.show();
      }

      final bool isFullScreen = await windowManager.isFullScreen();
      if (!isFullScreen) {
        await windowManager.setFullScreen(true);
      }

      final bool isResizable = await windowManager.isResizable();
      if (isResizable) {
        await windowManager.setResizable(false);
      }

      await windowManager.focus();
      await WakelockPlus.enable();
    } catch (error, stackTrace) {
      debugPrint(
        '[WINDOW_BOOTSTRAP] Failed to restore Windows shell state: $error',
      );
      debugPrintStack(
        stackTrace: stackTrace,
        label: '[WINDOW_BOOTSTRAP]',
      );
      // Desktop shell bootstrap must never block Flutter from painting.
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      unawaited(WakelockPlus.disable());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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
