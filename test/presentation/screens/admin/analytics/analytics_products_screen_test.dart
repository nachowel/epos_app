import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/repositories/auth_lockout_store.dart';
import 'package:epos_app/domain/models/analytics/analytics_date_range.dart';
import 'package:epos_app/domain/models/analytics/category_product_analytics_section.dart';
import 'package:epos_app/domain/models/analytics/product_analytics_item.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/analytics/analytics_products_provider.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/admin/analytics/analytics_products_screen.dart';
import 'package:epos_app/presentation/screens/admin/analytics/analytics_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsProductsScreen', () {
    testWidgets('renders products analytics route and category sections', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          productsState: AnalyticsProductsState(
            sections: _sampleSections(),
            selectedPreset: AnalyticsDateRangePreset.thisMonth,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.thisMonth,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: false,
            errorMessage: null,
          ),
          initialLocation: '/admin/analytics/products?range=this_month',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Category revenue by paid sales.'), findsOneWidget);
      expect(find.text('Last Week'), findsOneWidget);
      expect(find.text('Last 2 Weeks'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.text('Bakery'), findsOneWidget);
      expect(find.text('£158.00'), findsOneWidget);
      expect(find.text('£94.50'), findsOneWidget);
    });

    testWidgets('supports basic expand and collapse behavior', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        await _buildApp(
          productsState: AnalyticsProductsState(
            sections: _sampleSections(),
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

      expect(find.text('Flat White'), findsOneWidget);
      expect(find.text('Croissant'), findsOneWidget);
      expect(find.text('Orange Juice'), findsNothing);

      await tester.ensureVisible(find.text('Cold Drinks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cold Drinks'));
      await tester.pumpAndSettle();

      expect(find.text('Orange Juice'), findsOneWidget);

      await tester.tap(find.text('Coffee'));
      await tester.pumpAndSettle();

      expect(find.text('Flat White'), findsNothing);
    });

    testWidgets('preserves repository product order on screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          productsState: AnalyticsProductsState(
            sections: <CategoryProductAnalyticsSection>[
              CategoryProductAnalyticsSection(
                categoryId: 1,
                categoryName: 'Coffee',
                totalRevenueMinor: 15800,
                products: const <ProductAnalyticsItem>[
                  ProductAnalyticsItem(
                    productId: 1,
                    productName: 'Flat White',
                    revenueMinor: 6200,
                    quantityCount: 31,
                  ),
                  ProductAnalyticsItem(
                    productId: 2,
                    productName: 'Latte',
                    revenueMinor: 5400,
                    quantityCount: 27,
                  ),
                  ProductAnalyticsItem(
                    productId: 3,
                    productName: 'Americano',
                    revenueMinor: 4200,
                    quantityCount: 21,
                  ),
                ],
              ),
            ],
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

      final double flatWhiteY = tester.getTopLeft(find.text('Flat White')).dy;
      final double latteY = tester.getTopLeft(find.text('Latte')).dy;
      final double americanoY = tester.getTopLeft(find.text('Americano')).dy;

      expect(flatWhiteY, lessThan(latteY));
      expect(latteY, lessThan(americanoY));
    });

    testWidgets('shows clean empty message for empty ranges', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        await _buildApp(
          productsState: AnalyticsProductsState(
            sections: const <CategoryProductAnalyticsSection>[],
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

      expect(find.text('No product revenue in this period.'), findsOneWidget);
    });

    testWidgets('shows retryable error state', (WidgetTester tester) async {
      await tester.pumpWidget(
        await _buildApp(
          productsState: AnalyticsProductsState(
            sections: null,
            selectedPreset: AnalyticsDateRangePreset.thisWeek,
            range: AnalyticsDateRange.resolvePreset(
              preset: AnalyticsDateRangePreset.thisWeek,
              now: DateTime(2026, 4, 13),
            ),
            isLoading: false,
            errorMessage: 'Product analytics query failed.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Product analytics are unavailable right now.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

List<CategoryProductAnalyticsSection> _sampleSections() {
  return <CategoryProductAnalyticsSection>[
    CategoryProductAnalyticsSection(
      categoryId: 1,
      categoryName: 'Coffee',
      totalRevenueMinor: 15800,
      products: const <ProductAnalyticsItem>[
        ProductAnalyticsItem(
          productId: 1,
          productName: 'Flat White',
          revenueMinor: 6200,
          quantityCount: 31,
        ),
        ProductAnalyticsItem(
          productId: 2,
          productName: 'Latte',
          revenueMinor: 5400,
          quantityCount: 27,
        ),
        ProductAnalyticsItem(
          productId: 3,
          productName: 'Americano',
          revenueMinor: 4200,
          quantityCount: 21,
        ),
      ],
    ),
    CategoryProductAnalyticsSection(
      categoryId: 2,
      categoryName: 'Bakery',
      totalRevenueMinor: 9450,
      products: const <ProductAnalyticsItem>[
        ProductAnalyticsItem(
          productId: 4,
          productName: 'Croissant',
          revenueMinor: 5200,
          quantityCount: 26,
        ),
        ProductAnalyticsItem(
          productId: 5,
          productName: 'Pain au Chocolat',
          revenueMinor: 4250,
          quantityCount: 17,
        ),
      ],
    ),
    CategoryProductAnalyticsSection(
      categoryId: 3,
      categoryName: 'Cold Drinks',
      totalRevenueMinor: 3800,
      products: const <ProductAnalyticsItem>[
        ProductAnalyticsItem(
          productId: 6,
          productName: 'Orange Juice',
          revenueMinor: 3800,
          quantityCount: 19,
        ),
      ],
    ),
  ];
}

Future<Widget> _buildApp({
  required AnalyticsProductsState productsState,
  String initialLocation = analyticsProductsDetailRoute,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final GoRouter router = GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: analyticsProductsDetailRoute,
        builder: (_, GoRouterState state) => AnalyticsProductsScreen(
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
      analyticsProductsNotifierProvider.overrideWith((Ref ref) {
        return _FakeAnalyticsProductsNotifier(ref, productsState);
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

class _FakeAnalyticsProductsNotifier extends AnalyticsProductsNotifier {
  _FakeAnalyticsProductsNotifier(super.ref, AnalyticsProductsState initial)
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
