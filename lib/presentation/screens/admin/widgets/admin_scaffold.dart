import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../widgets/section_app_bar.dart';

const String _cashMovementsLabel = 'Cash Movements';
const String _auditLogsLabel = 'Audit Logs';

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
      label: AppStrings.products,
      route: '/admin/products',
      icon: Icons.inventory_2_rounded,
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
      icon: Icons.analytics_rounded,
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
    _AdminDestination(
      label: AppStrings.system,
      route: '/admin/system',
      icon: Icons.health_and_safety_rounded,
    ),
  ];

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
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth >= 1080) {
            return Row(
              children: <Widget>[
                Container(
                  width: 220,
                  padding: const EdgeInsets.all(AppSizes.spacingMd),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: _AdminRail(currentRoute: currentRoute),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.spacingMd),
                    child: child,
                  ),
                ),
              ],
            );
          }

          return Column(
            children: <Widget>[
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSizes.spacingSm,
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
                child: Padding(
                  padding: const EdgeInsets.all(AppSizes.spacingMd),
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

class _AdminRail extends StatelessWidget {
  const _AdminRail({required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
          child: Text(
            AppStrings.operationsControl,
            style: const TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: isActive ? null : () => context.go(destination.route),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSizes.minTouch),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacingMd,
            vertical: AppSizes.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                destination.icon,
                color: isActive ? AppColors.surface : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSizes.spacingSm),
              Expanded(
                child: Text(
                  destination.label,
                  style: TextStyle(
                    fontSize: AppSizes.fontSm,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppColors.surface : AppColors.textPrimary,
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
    return ChoiceChip(
      selected: isActive,
      label: Text(destination.label),
      avatar: Icon(destination.icon, size: 20),
      onSelected: (_) => context.go(destination.route),
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
