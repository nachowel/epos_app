import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/analytics/analytics_date_range.dart';
import '../../domain/models/analytics/analytics_revenue_preset.dart';
import '../../domain/models/user.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/admin/admin_categories_screen.dart';
import '../../presentation/screens/admin/admin_cash_movements_screen.dart';
import '../../presentation/screens/admin/admin_breakfast_set_editor_screen.dart';
import '../../presentation/screens/admin/admin_breakfast_sets_screen.dart';
import '../../presentation/screens/admin/admin_meal_profiles_screen.dart';
import '../../presentation/screens/admin/admin_meal_profile_editor_screen.dart';
import '../../presentation/screens/admin/admin_meal_optimization_screen.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';
import '../../presentation/screens/admin/admin_audit_logs_screen.dart';
import '../../presentation/screens/admin/admin_modifiers_screen.dart';
import '../../presentation/screens/admin/admin_printer_settings_screen.dart';
import '../../presentation/screens/admin/admin_products_screen.dart';
import '../../presentation/screens/admin/admin_report_settings_screen.dart';
import '../../presentation/screens/admin/admin_shifts_screen.dart';
import '../../presentation/screens/admin/admin_sync_screen.dart';
import '../../presentation/screens/admin/admin_system_screen.dart';
import '../../presentation/screens/admin/admin_users_screen.dart';
import '../../presentation/screens/admin/analytics/analytics_overview_screen.dart';
import '../../presentation/screens/admin/analytics/analytics_payments_screen.dart';
import '../../presentation/screens/admin/analytics/analytics_products_screen.dart';
import '../../presentation/screens/admin/analytics/analytics_revenue_screen.dart';
import '../../presentation/providers/analytics/analytics_overview_provider.dart';
import '../../presentation/screens/auth/pin_screen.dart';
import '../../presentation/screens/dashboard/cashier_dashboard_screen.dart';
import '../../presentation/screens/orders/order_detail_screen.dart';
import '../../presentation/screens/orders/orders_screen.dart';
import '../../presentation/screens/pos/category_entry_screen.dart';
import '../../presentation/screens/pos/pos_screen.dart';
import '../../presentation/screens/reports/z_report_screen.dart';
import '../../presentation/screens/shifts/shift_management_screen.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        redirect: (_, __) => _defaultAuthenticatedRoute(authState.currentUser),
      ),
      GoRoute(path: '/login', builder: (_, __) => const PinScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const CashierDashboardScreen(),
      ),
      GoRoute(
        path: '/pos/categories',
        redirect: (_, GoRouterState state) {
          final String? categoryId = state.uri.queryParameters['categoryId'];
          return Uri(
            path: '/pos',
            queryParameters: categoryId == null
                ? null
                : <String, String>{'categoryId': categoryId},
          ).toString();
        },
      ),
      GoRoute(
        path: '/pos',
        builder: (_, GoRouterState state) {
          final int? initialCategoryId = int.tryParse(
            state.uri.queryParameters['categoryId'] ?? '',
          );
          if (initialCategoryId == null) {
            return const CategoryEntryScreen();
          }
          return PosScreen(initialCategoryId: initialCategoryId);
        },
      ),
      GoRoute(path: '/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(path: '/admin/orders', redirect: (_, __) => '/orders'),
      GoRoute(
        path: '/shifts',
        builder: (_, __) => const ShiftManagementScreen(),
      ),
      GoRoute(
        path: '/orders/:transactionId',
        builder: (_, GoRouterState state) => OrderDetailScreen(
          transactionId: int.parse(state.pathParameters['transactionId']!),
        ),
      ),
      GoRoute(path: '/reports', builder: (_, __) => const ZReportScreen()),
      // Keep `/settings` pointed at the production admin settings route.
      // The legacy `SettingsScreen` remains compatibility-only and should not
      // be used as a numeric-input migration target.
      GoRoute(path: '/settings', redirect: (_, __) => '/admin/settings'),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(
        path: '/admin/analytics',
        builder: (_, GoRouterState state) => AnalyticsOverviewScreen(
          initialPreset: analyticsOverviewPresetFromQuery(
            state.uri.queryParameters['range'],
          ),
        ),
      ),
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
      GoRoute(
        path: '/admin/analytics/products',
        builder: (_, GoRouterState state) => AnalyticsProductsScreen(
          initialPreset: analyticsDetailPresetFromQuery(
            state.uri.queryParameters['range'],
          ),
        ),
      ),
      GoRoute(
        path: '/admin/analytics/payments',
        builder: (_, GoRouterState state) => AnalyticsPaymentsScreen(
          initialPreset: analyticsDetailPresetFromQuery(
            state.uri.queryParameters['range'],
          ),
        ),
      ),
      GoRoute(
        path: '/admin/products',
        builder: (_, __) => const AdminProductsScreen(),
      ),
      GoRoute(
        path: '/admin/meal-profiles',
        builder: (_, __) => const AdminMealProfilesScreen(),
      ),
      GoRoute(
        path: '/admin/meal-profiles/:profileId',
        builder: (_, GoRouterState state) => AdminMealProfileEditorScreen(
          profileId: int.parse(state.pathParameters['profileId']!),
        ),
      ),
      GoRoute(
        path: '/admin/meal-optimization',
        builder: (_, __) => const AdminMealOptimizationScreen(),
      ),
      GoRoute(
        path: '/admin/breakfast-sets',
        builder: (_, __) => const AdminBreakfastSetsScreen(),
      ),
      GoRoute(
        path: '/admin/breakfast-sets/:productId',
        builder: (_, GoRouterState state) => AdminBreakfastSetEditorScreen(
          productId: int.parse(state.pathParameters['productId']!),
        ),
      ),
      GoRoute(
        path: '/admin/categories',
        builder: (_, __) => const AdminCategoriesScreen(),
      ),
      GoRoute(
        path: '/admin/modifiers',
        builder: (_, __) => const AdminModifiersScreen(),
      ),
      GoRoute(
        path: '/admin/shifts',
        builder: (_, __) => const AdminShiftsScreen(),
      ),
      GoRoute(
        path: '/admin/cash-movements',
        builder: (_, __) => const AdminCashMovementsScreen(),
      ),
      GoRoute(
        path: '/admin/audit',
        builder: (_, __) => const AdminAuditLogsScreen(),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (_, __) => const AdminReportSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/settings/printer',
        builder: (_, __) => const AdminPrinterSettingsScreen(),
      ),
      GoRoute(
        path: '/admin/settings/report',
        redirect: (_, __) => '/admin/settings',
      ),
      GoRoute(path: '/admin/sync', builder: (_, __) => const AdminSyncScreen()),
      GoRoute(
        path: '/admin/system',
        builder: (_, __) => const AdminSystemScreen(),
      ),
      GoRoute(
        path: '/admin/users',
        builder: (_, __) => const AdminUsersScreen(),
      ),
    ],
    redirect: (_, GoRouterState state) {
      final User? currentUser = authState.currentUser;
      final bool isLoggedIn = currentUser != null;
      final bool isLoginRoute = state.matchedLocation == '/login';
      final bool isAdminRoute = state.matchedLocation.startsWith('/admin');
      final bool isCashierDashboardRoute =
          state.matchedLocation == '/dashboard';
      final bool isCashierRestrictedRouteForCashier =
          state.matchedLocation == '/dashboard' ||
          state.matchedLocation == '/shifts' ||
          state.matchedLocation.startsWith('/orders/');

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }
      if (isLoggedIn && isLoginRoute) {
        return _defaultAuthenticatedRoute(currentUser);
      }
      if (isAdminRoute && currentUser?.role != UserRole.admin) {
        return '/';
      }
      if (isCashierDashboardRoute && currentUser?.role != UserRole.cashier) {
        return currentUser?.role == UserRole.admin ? '/admin' : '/';
      }
      if (currentUser?.role == UserRole.cashier &&
          isCashierRestrictedRouteForCashier) {
        return state.matchedLocation.startsWith('/orders/')
            ? '/orders'
            : '/pos';
      }
      return null;
    },
  );
});

String _defaultAuthenticatedRoute(User? user) {
  if (user == null) {
    return '/login';
  }
  return '/pos';
}
