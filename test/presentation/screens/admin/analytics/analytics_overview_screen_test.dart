import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/repositories/analytics_repository.dart';
import 'package:epos_app/data/repositories/auth_lockout_store.dart';
import 'package:epos_app/domain/models/analytics/analytics_date_range.dart';
import 'package:epos_app/domain/models/analytics/analytics_detail_preset.dart';
import 'package:epos_app/domain/models/analytics/category_product_analytics_section.dart';
import 'package:epos_app/domain/models/analytics/daily_revenue_point.dart';
import 'package:epos_app/domain/models/analytics/analytics_insight.dart';
import 'package:epos_app/domain/models/analytics/overview_metrics.dart';
import 'package:epos_app/domain/models/analytics/payment_split_summary.dart';
import 'package:epos_app/domain/models/analytics/revenue_metrics.dart';
import 'package:epos_app/domain/models/analytics/top_product_summary.dart';
import 'package:epos_app/domain/services/analytics_export_service.dart';
import 'package:epos_app/domain/services/analytics_overview_service.dart';
import 'package:epos_app/domain/services/analytics_payments_service.dart';
import 'package:epos_app/domain/services/analytics_products_service.dart';
import 'package:epos_app/domain/services/analytics_revenue_service.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/analytics/analytics_insight_provider.dart';
import 'package:epos_app/presentation/providers/analytics/analytics_overview_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/admin/analytics/analytics_overview_screen.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsOverviewScreen', () {
    testWidgets('renders loading state before first dataset arrives', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AnalyticsOverviewState(
            metrics: null,
            selectedPreset: AnalyticsDateRangePreset.thisWeek,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.thisWeek,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: true,
            errorMessage: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Summary and navigation hub for admin analytics.'),
        findsOneWidget,
      );
      expect(find.text('Total Revenue'), findsNothing);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
    });

    testWidgets('renders a retryable error state on initial load failure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AnalyticsOverviewState(
            metrics: null,
            selectedPreset: AnalyticsDateRangePreset.thisWeek,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.thisWeek,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: false,
            errorMessage: 'Local analytics query failed.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Analytics overview is unavailable right now.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders overview cards with formatted analytics data', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AnalyticsOverviewState(
            metrics: OverviewMetrics(
              totalRevenueMinor: 123456,
              orderCount: 12,
              averageOrderValueMinor: 10288,
              topProductsPreview: const <TopProductSummary>[
                TopProductSummary(
                  productId: 1,
                  productName: 'Flat White',
                  revenueMinor: 4020,
                ),
                TopProductSummary(
                  productId: 2,
                  productName: 'Croissant',
                  revenueMinor: 2210,
                ),
                TopProductSummary(
                  productId: 3,
                  productName: 'Breakfast Roll',
                  revenueMinor: 1840,
                ),
              ],
              paymentSplitSummary: const PaymentSplitSummary(
                cashRevenueMinor: 40000,
                cardRevenueMinor: 83456,
                totalRevenueMinor: 123456,
                cashOrderCount: 4,
                cardOrderCount: 8,
              ),
            ),
            selectedPreset: AnalyticsDateRangePreset.thisWeek,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.thisWeek,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: false,
            errorMessage: null,
          ),
          insights: const <AnalyticsInsight>[
            AnalyticsInsight(
              message: 'Revenue is up 18% vs last period',
              type: AnalyticsInsightType.revenue,
              priority: 1,
            ),
            AnalyticsInsight(
              message: 'Card payments dominate (68%)',
              type: AnalyticsInsightType.payment,
              priority: 3,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Summary and navigation hub for admin analytics.'),
        findsOneWidget,
      );
      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('£1,234.56'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('AOV'), findsOneWidget);
      expect(find.text('£102.88'), findsOneWidget);
      expect(find.text('Top Products'), findsOneWidget);
      expect(find.text('Flat White'), findsOneWidget);
      expect(find.text('Croissant'), findsOneWidget);
      expect(find.text('Payment Split'), findsOneWidget);
      expect(find.text('£400.00'), findsOneWidget);
      expect(find.text('£834.56'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Revenue is up 18% vs last period'), findsOneWidget);
      expect(find.text('Card payments dominate (68%)'), findsOneWidget);
    });

    testWidgets('hero revenue card navigates to revenue detail route', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(await _buildApp(analyticsState: _dataState()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Total Revenue'));
      await tester.pumpAndSettle();

      expect(find.text('Revenue Detail'), findsOneWidget);
    });

    testWidgets('orders card navigates to revenue detail with orders intent', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _buildApp(analyticsState: _dataState()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(find.text('Revenue Detail · orders'), findsOneWidget);
    });

    testWidgets('aov card carries explicit revenue detail context', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _buildApp(analyticsState: _dataState()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('AOV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AOV'));
      await tester.pumpAndSettle();

      expect(find.text('Revenue Detail · aov'), findsOneWidget);
    });

    testWidgets('top products card navigates to products analytics route', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _buildApp(analyticsState: _dataState()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Top Products'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Top Products'));
      await tester.pumpAndSettle();

      expect(find.text('Product Analytics Screen'), findsOneWidget);
    });

    testWidgets('payment split card navigates to payment analytics screen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(await _buildApp(analyticsState: _dataState()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Payment Split'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payment Split'));
      await tester.pumpAndSettle();

      expect(find.text('Revenue Split'), findsOneWidget);
    });

    testWidgets('empty dataset keeps zero cards and a single overview banner', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: AnalyticsOverviewState(
            metrics: const OverviewMetrics.empty(),
            selectedPreset: AnalyticsDateRangePreset.today,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.today,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: false,
            errorMessage: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No paid transactions in this period.'), findsOneWidget);
      expect(find.text('£0.00'), findsWidgets);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('export analytics action opens json preview dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          analyticsState: _dataState(),
          exportService: _FakeAnalyticsExportService(
            '{"summary":{},"dailyRevenue":[],"topProducts":[],"categories":[],"paymentSplit":{},"analysisPrompt":"Analyze this cafe analytics data."}',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export Analytics'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Analytics Export'), findsOneWidget);
      expect(find.textContaining('"analysisPrompt"'), findsOneWidget);
      expect(find.text('Copy JSON'), findsOneWidget);
    });
  });
}

AnalyticsOverviewState _dataState() {
  return AnalyticsOverviewState(
    metrics: OverviewMetrics(
      totalRevenueMinor: 9800,
      orderCount: 7,
      averageOrderValueMinor: 1400,
      topProductsPreview: const <TopProductSummary>[
        TopProductSummary(
          productId: 1,
          productName: 'Flat White',
          revenueMinor: 4200,
        ),
        TopProductSummary(
          productId: 2,
          productName: 'Bagel',
          revenueMinor: 2800,
        ),
        TopProductSummary(
          productId: 3,
          productName: 'Brownie',
          revenueMinor: 1800,
        ),
      ],
      paymentSplitSummary: const PaymentSplitSummary(
        cashRevenueMinor: 3000,
        cardRevenueMinor: 6800,
        totalRevenueMinor: 9800,
        cashOrderCount: 2,
        cardOrderCount: 5,
      ),
    ),
    selectedPreset: AnalyticsDateRangePreset.thisWeek,
    range: AnalyticsDateRange.resolvePreset(
      preset: AnalyticsDateRangePreset.thisWeek,
      now: DateTime(2026, 4, 13),
    ),
    isLoading: false,
    errorMessage: null,
  );
}

Future<Widget> _buildApp({
  required AnalyticsOverviewState analyticsState,
  List<AnalyticsInsight>? insights,
  AnalyticsExportService? exportService,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final GoRouter router = GoRouter(
    initialLocation: analyticsOverviewRoute,
    routes: <RouteBase>[
      GoRoute(
        path: analyticsOverviewRoute,
        builder: (_, __) => const AnalyticsOverviewScreen(
          initialPreset: AnalyticsDateRangePreset.thisWeek,
        ),
      ),
      GoRoute(
        path: analyticsRevenueDetailRoute,
        builder: (_, GoRouterState state) {
          final String? entry = state.uri.queryParameters['entry'];
          return Scaffold(
            body: Center(
              child: Text(
                entry == null || entry.isEmpty
                    ? 'Revenue Detail'
                    : 'Revenue Detail · $entry',
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: analyticsOrdersDetailRoute,
        builder: (_, GoRouterState state) {
          final String? entry = state.uri.queryParameters['entry'];
          return Scaffold(
            body: Center(
              child: Text(
                entry == null || entry.isEmpty
                    ? 'Revenue Detail'
                    : 'Revenue Detail · $entry',
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: analyticsProductsDetailRoute,
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('Product Analytics Screen')),
        ),
      ),
      GoRoute(
        path: analyticsPaymentsDetailRoute,
        builder: (_, __) =>
            const Scaffold(body: Center(child: Text('Revenue Split'))),
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
      analyticsOverviewNotifierProvider.overrideWith((Ref ref) {
        return _FakeAnalyticsOverviewNotifier(ref, analyticsState);
      }),
      analyticsOverviewInsightsProvider.overrideWith(
        (Ref ref) async => insights ?? const <AnalyticsInsight>[],
      ),
      analyticsExportServiceProvider.overrideWithValue(
        exportService ?? _FakeAnalyticsExportService('{}'),
      ),
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

class _FakeAnalyticsOverviewNotifier extends AnalyticsOverviewNotifier {
  _FakeAnalyticsOverviewNotifier(super.ref, AnalyticsOverviewState initial)
    : super() {
    state = initial;
  }

  @override
  Future<void> initialize({AnalyticsDateRangePreset? preset}) async {
    if (preset != null) {
      state = state.copyWith(selectedPreset: preset);
    }
  }

  @override
  Future<void> loadForPreset(AnalyticsDateRangePreset preset) async {
    state = state.copyWith(selectedPreset: preset);
  }

  @override
  Future<void> refresh() async {}
}

class _FakeAnalyticsExportService extends AnalyticsExportService {
  _FakeAnalyticsExportService(this._json)
    : super(
        overviewService: AnalyticsOverviewService(
          repository: const _ExportRepo(),
        ),
        revenueService: AnalyticsRevenueService(
          repository: const _ExportRepo(),
        ),
        productsService: AnalyticsProductsService(
          repository: const _ExportRepo(),
        ),
        paymentsService: AnalyticsPaymentsService(
          repository: const _ExportRepo(),
        ),
      );

  final String _json;

  @override
  Future<String> exportAnalytics({
    required AnalyticsDetailPreset preset,
  }) async {
    return _json;
  }
}

class _ExportRepo implements AnalyticsRepository {
  const _ExportRepo();

  @override
  Future<List<CategoryProductAnalyticsSection>> getCategoryProductSections(
    AnalyticsDateRange range, {
    int perCategoryLimit = 5,
  }) async => const <CategoryProductAnalyticsSection>[];

  @override
  Future<List<DailyRevenuePoint>> getDailyRevenueSeries(
    AnalyticsDateRange range,
  ) async => const <DailyRevenuePoint>[];

  @override
  Future<OverviewMetrics> getOverviewMetrics(AnalyticsDateRange range) async =>
      const OverviewMetrics.empty();

  @override
  Future<PaymentSplitSummary> getPaymentSplit(AnalyticsDateRange range) async =>
      const PaymentSplitSummary.empty();

  @override
  Future<List<TopProductSummary>> getTopProductsOverall(
    AnalyticsDateRange range, {
    int limit = 3,
  }) async => const <TopProductSummary>[];

  @override
  Future<RevenueMetrics> getRevenueMetrics(AnalyticsDateRange range) async =>
      const RevenueMetrics.empty();
}
