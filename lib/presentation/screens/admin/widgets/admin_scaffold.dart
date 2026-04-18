import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../widgets/logout_confirmation.dart';
import '../../../widgets/operator_page_intro.dart';
import '../../../widgets/section_app_bar.dart';

const String _cashMovementsLabel = 'Cash Movements';
const String _auditLogsLabel = 'Audit Logs';
const String _analyticsLabel = 'Analytics';
const String _mealProfilesLabel = 'Meal Profiles';
const String _mealOptimizationLabel = 'Meal Optimization';
const String _breakfastSetsLabel = 'Breakfast Sets';

class AdminScaffold extends ConsumerWidget {
  const AdminScaffold({
    required this.title,
    required this.currentRoute,
    required this.child,
    super.key,
  });

  final String title;
  final String currentRoute;
  final Widget child;

  static List<_AdminDestination> _destinations() => <_AdminDestination>[
    _AdminDestination(
      label: AppStrings.dashboard,
      route: '/admin',
      icon: Icons.space_dashboard_rounded,
    ),
    _AdminDestination(
      label: _analyticsLabel,
      route: '/admin/analytics',
      icon: Icons.analytics_rounded,
    ),
    _AdminDestination(
      label: AppStrings.products,
      route: '/admin/products',
      icon: Icons.inventory_2_rounded,
    ),
    _AdminDestination(
      label: _mealProfilesLabel,
      route: '/admin/meal-profiles',
      icon: Icons.restaurant_menu_rounded,
    ),
    _AdminDestination(
      label: _mealOptimizationLabel,
      route: '/admin/meal-optimization',
      icon: Icons.trending_up_rounded,
    ),
    _AdminDestination(
      label: _breakfastSetsLabel,
      route: '/admin/breakfast-sets',
      icon: Icons.breakfast_dining_rounded,
    ),
    _AdminDestination(
      label: AppStrings.categories,
      route: '/admin/categories',
      icon: Icons.category_rounded,
    ),
    _AdminDestination(
      label: AppStrings.modifiers,
      route: '/admin/modifiers',
      icon: Icons.tune_rounded,
    ),
    _AdminDestination(
      label: _cashMovementsLabel,
      route: '/admin/cash-movements',
      icon: Icons.payments_rounded,
    ),
    _AdminDestination(
      label: _auditLogsLabel,
      route: '/admin/audit',
      icon: Icons.fact_check_rounded,
    ),
    _AdminDestination(
      label: AppStrings.navSettings,
      route: '/admin/settings',
      icon: Icons.settings_rounded,
    ),
    _AdminDestination(
      label: AppStrings.shifts,
      route: '/admin/shifts',
      icon: Icons.schedule_rounded,
    ),
    _AdminDestination(
      label: AppStrings.printer,
      route: '/admin/settings/printer',
      icon: Icons.print_rounded,
    ),
    _AdminDestination(
      label: AppStrings.sync,
      route: '/admin/sync',
      icon: Icons.sync_rounded,
    ),
    const _AdminDestination(
      label: 'Users',
      route: '/admin/users',
      icon: Icons.people_rounded,
    ),
    _AdminDestination(
      label: AppStrings.system,
      route: '/admin/system',
      icon: Icons.health_and_safety_rounded,
    ),
  ];

  static String _resolveIntroSubtitle(String currentRoute, String title) {
    if (currentRoute == '/admin') {
      return 'Monitor trading, sync health, and operational control points from one workspace.';
    }
    if (currentRoute.startsWith('/admin/analytics')) {
      return 'Review revenue, order, and payment performance without leaving the admin shell.';
    }
    if (currentRoute.startsWith('/admin/products')) {
      return 'Manage catalog availability, structure, and operator-facing product setup.';
    }
    if (currentRoute.startsWith('/admin/categories')) {
      return 'Control category structure and keep POS navigation organised for service.';
    }
    if (currentRoute.startsWith('/admin/modifiers')) {
      return 'Maintain modifier options and keep ordering logic consistent across the menu.';
    }
    if (currentRoute.startsWith('/admin/shifts')) {
      return 'Review shift activity, controls, and closure context for the current operation.';
    }
    if (currentRoute.startsWith('/admin/sync')) {
      return 'Track sync state, failures, and recovery signals from the operational shell.';
    }
    if (currentRoute.startsWith('/admin/users')) {
      return 'Manage operator access, roles, and active account status for the live system.';
    }
    if (currentRoute.startsWith('/admin/system')) {
      return 'Review environment status, diagnostics, and system health from one workspace.';
    }
    if (currentRoute.startsWith('/admin/settings')) {
      return 'Adjust operator-facing configuration without disrupting the live service flow.';
    }
    return 'Manage $title while staying inside the shared operator workspace.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final List<_AdminDestination> destinations = _destinations();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: title,
        currentRoute: currentRoute,
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () => handleLogoutRequest(context, ref),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth >= 1080) {
            return Row(
              children: <Widget>[
                Container(
                  width: 228,
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.spacingMd,
                    AppSizes.spacingSm,
                    AppSizes.spacingMd,
                    AppSizes.spacingMd,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.spacingSm),
                      child: _AdminRail(currentRoute: currentRoute),
                    ),
                  ),
                ),
                Expanded(
                  child: _AdminContentShell(
                    title: title,
                    subtitle: _resolveIntroSubtitle(currentRoute, title),
                    child: child,
                  ),
                ),
              ],
            );
          }

          return Column(
            children: <Widget>[
              Container(
                height: 68,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSizes.spacingXs,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacingMd,
                  ),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: destinations
                        .map(
                          (_AdminDestination destination) => Padding(
                            padding: const EdgeInsets.only(
                              right: AppSizes.spacingSm,
                            ),
                            child: _AdminChip(
                              destination: destination,
                              isActive: _matchesRoute(
                                destination.route,
                                currentRoute,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ),
              Expanded(
                child: _AdminContentShell(
                  title: title,
                  subtitle: _resolveIntroSubtitle(currentRoute, title),
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _matchesRoute(String route, String currentRoute) {
    if (route == '/admin') {
      return currentRoute == '/admin';
    }
    if (route == '/admin/settings') {
      return currentRoute == '/admin/settings';
    }
    return currentRoute.startsWith(route);
  }
}

class _AdminContentShell extends StatelessWidget {
  const _AdminContentShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.spacingMd,
        AppSizes.spacingSm,
        AppSizes.spacingMd,
        AppSizes.spacingMd,
      ),
      child: Column(
        children: <Widget>[
          OperatorSectionHeading(
            eyebrow: 'ADMIN',
            title: title,
            subtitle: subtitle,
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AdminRail extends StatelessWidget {
  const _AdminRail({required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Admin Navigation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Keep core management tools visible and reachable during service.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacingSm),
        Expanded(
          child: ListView(
            children: AdminScaffold._destinations()
                .map(
                  (_AdminDestination destination) => _AdminRailTile(
                    destination: destination,
                    isActive: AdminScaffold._matchesRoute(
                      destination.route,
                      currentRoute,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _AdminRailTile extends StatelessWidget {
  const _AdminRailTile({required this.destination, required this.isActive});

  final _AdminDestination destination;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingXs),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: isActive ? null : () => context.go(destination.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacingMd,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryLight : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.22)
                  : AppColors.border,
            ),
            boxShadow: isActive
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.primaryDarker.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  destination.icon,
                  color: isActive
                      ? AppColors.primaryStrong
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSizes.spacingSm),
              Expanded(
                child: Text(
                  destination.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminChip extends StatelessWidget {
  const _AdminChip({required this.destination, required this.isActive});

  final _AdminDestination destination;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isActive ? null : () => context.go(destination.route),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryLight : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.22)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                destination.icon,
                size: 18,
                color: isActive
                    ? AppColors.primaryStrong
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                destination.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminDestination {
  const _AdminDestination({
    required this.label,
    required this.route,
    required this.icon,
  });

  final String label;
  final String route;
  final IconData icon;
}
