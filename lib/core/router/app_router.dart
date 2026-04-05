import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/user.dart';
import '../../domain/models/analytics/analytics_period.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/admin/admin_categories_screen.dart';
import '../../presentation/screens/admin/admin_cash_movements_screen.dart';
import '../../presentation/screens/admin/admin_breakfast_set_editor_screen.dart';
import '../../presentation/screens/admin/admin_breakfast_sets_screen.dart';
import '../../presentation/screens/admin/admin_meal_profiles_screen.dart';
import '../../presentation/screens/admin/admin_meal_profile_editor_screen.dart';
import '../../presentation/screens/admin/admin_meal_optimization_screen.dart';
import '../../presentation/screens/admin/admin_dashboard_screen.dart';
import '../../presentation/screens/admin/admin_revenue_analytics_screen.dart';
import '../../presentation/screens/admin/admin_audit_logs_screen.dart';
import '../../presentation/screens/admin/admin_modifiers_screen.dart';
import '../../presentation/screens/admin/admin_printer_settings_screen.dart';
import '../../presentation/screens/admin/admin_products_screen.dart';
import '../../presentation/screens/admin/admin_report_settings_screen.dart';
import '../../presentation/screens/admin/admin_shifts_screen.dart';
import '../../presentation/screens/admin/admin_sync_screen.dart';
import '../../presentation/screens/admin/admin_system_screen.dart';
import '../../presentation/screens/auth/pin_screen.dart';
import '../../presentation/screens/dashboard/cashier_dashboard_screen.dart';
import '../../presentation/screens/orders/order_detail_screen.dart';
import '../../presentation/screens/orders/open_orders_screen.dart';
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
        redirect: (_, __) => authState.currentUser == null ? '/login' : '/pos',
      ),
      GoRoute(path: '/login', builder: (_, __) => const PinScreen()),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const CashierDashboardScreen(),
      ),
      GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
      GoRoute(path: '/orders', builder: (_, __) => const OpenOrdersScreen()),
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
      GoRoute(path: '/settings', redirect: (_, __) => '/admin/settings'),
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
      GoRoute(
        path: '/admin/analytics',
        builder: (_, GoRouterState state) => AdminRevenueAnalyticsScreen(
          initialPeriodSelection: AnalyticsPeriodSelection.fromQueryParameters(
            state.uri.queryParameters,
          ),
          initialComparisonMode: analyticsComparisonModeFromQuery(
            state.uri.queryParameters['mode'],
          ),
          initialInsightCode: state.uri.queryParameters['insight'],
          initialTrendDate: DateTime.tryParse(
            state.uri.queryParameters['trend'] ?? '',
          ),
          initialDaypart: state.uri.queryParameters['daypart'],
          initialMoverId: state.uri.queryParameters['mover'],
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
    ],
    redirect: (_, GoRouterState state) {
      final User? currentUser = authState.currentUser;
      final bool isLoggedIn = currentUser != null;
      final bool isLoginRoute = state.matchedLocation == '/login';
      final bool isAdminRoute = state.matchedLocation.startsWith('/admin');
      final bool isCashierDashboardRoute =
          state.matchedLocation == '/dashboard';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }
      if (isLoggedIn && isLoginRoute) {
        return '/pos';
      }
      if (isAdminRoute && currentUser?.role != UserRole.admin) {
        return '/';
      }
      if (isCashierDashboardRoute && currentUser?.role != UserRole.cashier) {
        return currentUser?.role == UserRole.admin ? '/admin' : '/';
      }
      return null;
    },
  );
});
