import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/repositories/auth_lockout_store.dart';
import 'package:epos_app/domain/models/analytics/analytics_date_range.dart';
import 'package:epos_app/domain/models/analytics/payment_split_summary.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/analytics/analytics_payments_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/admin/analytics/analytics_payments_screen.dart';
import 'package:epos_app/presentation/screens/admin/analytics/analytics_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsPaymentsScreen', () {
    testWidgets('renders payments summary and revenue split', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          paymentsState: AnalyticsPaymentsState(
            summary: const PaymentSplitSummary(
              cashRevenueMinor: 3200,
              cardRevenueMinor: 6800,
              totalRevenueMinor: 10000,
              cashOrderCount: 2,
              cardOrderCount: 5,
            ),
            selectedPreset: AnalyticsDateRangePreset.thisWeek,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.thisWeek,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: false,
            errorMessage: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Last Week'), findsOneWidget);
      expect(find.text('Last 2 Weeks'), findsOneWidget);
      expect(find.text('Card Revenue'), findsOneWidget);
      expect(find.text('Cash Revenue'), findsOneWidget);
      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('£68.00'), findsWidgets);
      expect(find.text('£32.00'), findsWidgets);
      expect(find.text('£100.00'), findsOneWidget);
      expect(find.text('Revenue Split'), findsOneWidget);
      expect(find.text('5 orders'), findsOneWidget);
      expect(find.text('2 orders'), findsOneWidget);
    });

    testWidgets('shows clean empty state', (WidgetTester tester) async {
      await tester.pumpWidget(
        await _buildApp(
          paymentsState: AnalyticsPaymentsState(
            summary: const PaymentSplitSummary.empty(),
            selectedPreset: AnalyticsDateRangePreset.thisWeek,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.thisWeek,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: false,
            errorMessage: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No payments in this period.'), findsOneWidget);
    });

    testWidgets('shows retryable error state', (WidgetTester tester) async {
      await tester.pumpWidget(
        await _buildApp(
          paymentsState: AnalyticsPaymentsState(
            summary: null,
            selectedPreset: AnalyticsDateRangePreset.thisWeek,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.thisWeek,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: false,
            errorMessage: 'Payment analytics query failed.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Payment analytics are unavailable right now.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('route opens payments analytics screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          paymentsState: AnalyticsPaymentsState(
            summary: const PaymentSplitSummary(
              cashRevenueMinor: 1200,
              cardRevenueMinor: 3800,
              totalRevenueMinor: 5000,
              cashOrderCount: 1,
              cardOrderCount: 3,
            ),
            selectedPreset: AnalyticsDateRangePreset.thisMonth,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.thisMonth,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: false,
            errorMessage: null,
          ),
          initialLocation: '/admin/analytics/payments?range=this_month',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AnalyticsPaymentsScreen), findsOneWidget);
      expect(find.text('Revenue Split'), findsOneWidget);
    });
  });
}

Future<Widget> _buildApp({
  required AnalyticsPaymentsState paymentsState,
  String initialLocation = analyticsPaymentsDetailRoute,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: analyticsPaymentsDetailRoute,
        builder: (_, GoRouterState state) => AnalyticsPaymentsScreen(
          initialPreset: analyticsDetailPresetFromQuery(
            state.uri.queryParameters['range'],
          ),
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
      analyticsPaymentsNotifierProvider.overrideWith((Ref ref) {
        return _FakeAnalyticsPaymentsNotifier(ref, paymentsState);
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

class _FakeAnalyticsPaymentsNotifier extends AnalyticsPaymentsNotifier {
  _FakeAnalyticsPaymentsNotifier(super.ref, AnalyticsPaymentsState initial)
    : _seedState = initial,
      super() {
    state = initial;
  }

  final AnalyticsPaymentsState _seedState;

  @override
  Future<void> initialize({AnalyticsDateRangePreset? preset}) async {
    if (preset != null) {
      state = preset == _seedState.selectedPreset
          ? _seedState
          : _seedState.copyWith(selectedPreset: preset);
    }
  }

  @override
  Future<void> loadForPreset(AnalyticsDateRangePreset preset) async {
    state = _seedState.copyWith(selectedPreset: preset);
  }

  @override
  Future<void> refresh() async {}
}
