import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/repositories/auth_lockout_store.dart';
import 'package:epos_app/domain/models/analytics/analytics_revenue_preset.dart';
import 'package:epos_app/domain/models/analytics/daily_revenue_point.dart';
import 'package:epos_app/domain/models/analytics/revenue_detail_summary.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/analytics/analytics_revenue_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/admin/analytics/analytics_revenue_screen.dart';
import 'package:epos_app/presentation/screens/admin/analytics/widgets/daily_revenue_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsRevenueScreen', () {
    testWidgets('revenue route opens and renders daily trend chart', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          revenueState: _stateForPreset(AnalyticsRevenuePreset.thisWeek),
          initialLocation: '/admin/analytics/revenue?preset=this_week',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnalyticsRevenueScreen), findsOneWidget);
      expect(find.text('Daily Revenue Trend'), findsOneWidget);
      expect(find.byKey(dailyRevenueChartKey), findsOneWidget);
    });

    testWidgets('preset change updates state and comparison label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          revenueState: _stateForPreset(AnalyticsRevenuePreset.thisWeek),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compared to last week'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Last Week'));
      await tester.pumpAndSettle();

      expect(find.text('Compared to previous week'), findsOneWidget);
      expect(find.text('£42.00'), findsOneWidget);
    });

    testWidgets('shows explicit AOV entry context', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          revenueState: _stateForPreset(AnalyticsRevenuePreset.thisWeek),
          initialLocation:
              '/admin/analytics/revenue?preset=this_week&entry=aov',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(revenueDetailContextBannerKey), findsOneWidget);
      expect(find.textContaining('Opened from AOV.'), findsOneWidget);
    });

    testWidgets('shows clean empty state for no paid revenue', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          revenueState: AnalyticsRevenueState(
            summary: RevenueDetailSummary.empty(
              preset: AnalyticsRevenuePreset.last2Weeks,
              comparisonLabel: 'Compared to prior 2-week window',
            ),
            selectedPreset: AnalyticsRevenuePreset.last2Weeks,
            isLoading: false,
            errorMessage: null,
          ),
          initialLocation: '/admin/analytics/revenue?preset=last_2_weeks',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No paid revenue in this period.'), findsOneWidget);
      expect(find.byKey(dailyRevenueChartKey), findsNothing);
    });

    testWidgets('comparison label follows active preset on route load', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          revenueState: _stateForPreset(AnalyticsRevenuePreset.thisMonth),
          initialLocation: '/admin/analytics/revenue?preset=this_month',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compared to last month'), findsOneWidget);
    });

    testWidgets('orders entry context stays explicit on orders route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          revenueState: _stateForPreset(AnalyticsRevenuePreset.lastWeek),
          initialLocation: '/admin/analytics/orders?preset=last_week',
          includeOrdersAlias: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnalyticsRevenueScreen), findsOneWidget);
      expect(find.byKey(revenueDetailContextBannerKey), findsOneWidget);
      expect(find.textContaining('Opened from Orders.'), findsOneWidget);
      expect(find.text('Compared to previous week'), findsOneWidget);
    });
  });
}

AnalyticsRevenueState _stateForPreset(AnalyticsRevenuePreset preset) {
  return AnalyticsRevenueState(
    summary: RevenueDetailSummary(
      preset: preset,
      totalRevenueMinor: preset == AnalyticsRevenuePreset.lastWeek
          ? 4200
          : 9800,
      orderCount: preset == AnalyticsRevenuePreset.lastWeek ? 3 : 7,
      averageOrderValueMinor: 1400,
      dailyRevenueSeries: <DailyRevenuePoint>[
        DailyRevenuePoint(
          date: DateTime(2026, 4, 7),
          revenueMinor: 3200,
          orderCount: 2,
        ),
        DailyRevenuePoint(
          date: DateTime(2026, 4, 8),
          revenueMinor: 2800,
          orderCount: 2,
        ),
        DailyRevenuePoint(
          date: DateTime(2026, 4, 9),
          revenueMinor: 3800,
          orderCount: 3,
        ),
      ],
      comparisonLabel: analyticsRevenueComparisonLabel(preset),
      comparisonRevenueMinor: preset == AnalyticsRevenuePreset.lastWeek
          ? 3900
          : 7600,
      comparisonOrderCount: preset == AnalyticsRevenuePreset.lastWeek ? 3 : 5,
      comparisonAverageOrderValueMinor:
          preset == AnalyticsRevenuePreset.lastWeek ? 1300 : 1200,
      comparisonDeltaRevenueMinor: preset == AnalyticsRevenuePreset.lastWeek
          ? 300
          : 2200,
      comparisonDirection: RevenueComparisonDirection.up,
    ),
    selectedPreset: preset,
    isLoading: false,
    errorMessage: null,
  );
}

Future<Widget> _buildApp({
  required AnalyticsRevenueState revenueState,
  String initialLocation = '/admin/analytics/revenue?preset=this_week',
  bool includeOrdersAlias = false,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/analytics/revenue',
        builder: (_, GoRouterState state) => AnalyticsRevenueScreen(
          initialPreset: analyticsRevenuePresetFromQuery(
            state.uri.queryParameters['preset'] ??
                state.uri.queryParameters['p'],
          ),
          entryPoint: analyticsRevenueDetailEntryPointFromQuery(
            state.uri.queryParameters['entry'],
          ),
        ),
      ),
      if (includeOrdersAlias)
        GoRoute(
          path: '/admin/analytics/orders',
          builder: (_, GoRouterState state) => AnalyticsRevenueScreen(
            initialPreset: analyticsRevenuePresetFromQuery(
              state.uri.queryParameters['preset'] ??
                  state.uri.queryParameters['p'],
            ),
            entryPoint: AnalyticsRevenueDetailEntryPoint.orders,
          ),
        ),
    ],
  );

  const Locale locale = Locale('en');
  AppLocalizationService.instance.setLocale(locale);

  return ProviderScope(
    overrides: <Override>[
      authNotifierProvider.overrideWith(
        (Ref ref) => _FakeAuthNotifier(ref, prefs),
      ),
      shiftNotifierProvider.overrideWith((Ref ref) => _FakeShiftNotifier(ref)),
      sharedPreferencesProvider.overrideWithValue(prefs),
      analyticsRevenueNotifierProvider.overrideWith((Ref ref) {
        return _FakeAnalyticsRevenueNotifier(ref, revenueState);
      }),
    ],
    child: MaterialApp.router(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(Ref ref, SharedPreferences prefs)
    : super(ref, AuthLockoutStore(prefs)) {
    state = AuthState(
      currentUser: User(
        id: 1,
        name: 'Admin',
        pin: '1234',
        password: null,
        role: UserRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 1, 1),
      ),
      isLoading: false,
      errorMessage: null,
      failedAttempts: 0,
      lockedUntil: null,
    );
  }
}

class _FakeShiftNotifier extends ShiftNotifier {
  _FakeShiftNotifier(super.ref);

  @override
  Future<void> refreshOpenShift() async {
    state = ShiftState(
      currentShift: Shift(
        id: 7,
        openedBy: 1,
        openedAt: DateTime(2026, 4, 13, 8),
        closedBy: null,
        closedAt: null,
        cashierPreviewedBy: null,
        cashierPreviewedAt: null,
        status: ShiftStatus.open,
      ),
      backendOpenShift: null,
      effectiveShiftStatus: ShiftStatus.open,
      recentShifts: const <Shift>[],
      cashierPreviewActive: false,
      salesLocked: false,
      paymentsLocked: false,
      lockReason: null,
      isLoading: false,
      staleFinalCloseRecovery: null,
      errorMessage: null,
    );
  }

  @override
  Future<void> loadRecentShifts() async {}
}

class _FakeAnalyticsRevenueNotifier extends AnalyticsRevenueNotifier {
  _FakeAnalyticsRevenueNotifier(super.ref, AnalyticsRevenueState initial)
    : _seedState = initial,
      super() {
    state = initial;
  }

  final AnalyticsRevenueState _seedState;

  @override
  Future<void> initialize({AnalyticsRevenuePreset? preset}) async {
    if (preset != null) {
      state = preset == _seedState.selectedPreset
          ? _seedState
          : _stateForPreset(preset);
    }
  }

  @override
  Future<void> loadForPreset(AnalyticsRevenuePreset preset) async {
    state = _stateForPreset(preset);
  }

  @override
  Future<void> refresh() async {}
}
