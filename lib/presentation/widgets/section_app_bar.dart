import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/user.dart';

enum _HeaderNavLayout { wide, compact, collapsed }

class SectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SectionAppBar({
    required this.title,
    required this.currentRoute,
    required this.currentUser,
    required this.currentShift,
    required this.onLogout,
    this.compactVisual = false,
    super.key,
  });

  final String title;
  final String currentRoute;
  final User? currentUser;
  final Shift? currentShift;
  final VoidCallback onLogout;
  final bool compactVisual;

  @override
  Size get preferredSize =>
      Size.fromHeight(compactVisual ? 44 : AppSizes.topBarHeight);

  @visibleForTesting
  static String debugNavigationStage({
    required double viewportWidth,
    required bool compactVisual,
    required List<String> navLabels,
    String shiftLabel = 'Shift #5',
    String logoutLabel = 'Logout',
  }) {
    return _HeaderLayoutConfig.resolve(
      viewportWidth: viewportWidth,
      compactVisual: compactVisual,
      navLabels: navLabels,
      shiftLabel: shiftLabel,
      logoutLabel: logoutLabel,
    ).layout.name;
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = currentUser?.role == UserRole.admin;
    final List<_NavDestination> destinations = _buildDestinations(isAdmin);
    final ({Color color, String label}) shiftIndicator = _resolveShiftIndicator(
      currentShift,
    );
    final _HeaderLayoutConfig layoutConfig = _HeaderLayoutConfig.resolve(
      viewportWidth: MediaQuery.sizeOf(context).width,
      compactVisual: compactVisual,
      navLabels: destinations.map((d) => d.label).toList(growable: false),
      shiftLabel: shiftIndicator.label,
      logoutLabel: AppStrings.navLogout,
    );
    return AppBar(
      toolbarHeight: compactVisual ? 44 : AppSizes.topBarHeight,
      titleSpacing: layoutConfig.useCompactTitle ? 10 : AppSizes.spacingMd,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      title: layoutConfig.useCompactTitle
          ? _CompactHeaderTitle(
              key: const ValueKey<String>('section_app_bar_compact_title'),
              shiftIndicator: shiftIndicator,
              onOpenShifts: () => context.go('/shifts'),
            )
          : Row(
              key: const ValueKey<String>('section_app_bar_standard_title'),
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        AppStrings.appName,
                        style: const TextStyle(
                          fontSize: AppSizes.fontMd,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        currentUser == null
                            ? title
                            : '$title · ${currentUser!.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (layoutConfig.layout !=
                    _HeaderNavLayout.collapsed) ...<Widget>[
                  const SizedBox(width: AppSizes.spacingMd),
                  _ShiftIndicator(
                    shiftIndicator: shiftIndicator,
                    compactVisual: false,
                    onTap: () => context.go('/shifts'),
                  ),
                ],
              ],
            ),
      actions: layoutConfig.layout == _HeaderNavLayout.collapsed
          ? <Widget>[
              _CollapsedNavigationButton(
                destinations: destinations,
                onLogout: onLogout,
                compactVisual: compactVisual,
              ),
              const SizedBox(width: AppSizes.spacingSm),
            ]
          : <Widget>[
              _InlineHeaderActions(
                key: ValueKey<String>(
                  layoutConfig.useCompactInlineNav
                      ? 'section_app_bar_inline_actions_compact'
                      : 'section_app_bar_inline_actions',
                ),
                destinations: destinations,
                onLogout: onLogout,
                compactVisual: layoutConfig.useCompactInlineNav,
              ),
            ],
    );
  }

  List<_NavDestination> _buildDestinations(bool isAdmin) {
    return <_NavDestination>[
      if (!isAdmin)
        _NavDestination(
          label: AppStrings.dashboard,
          route: '/dashboard',
          isActive: currentRoute == '/dashboard',
        ),
      _NavDestination(
        label: AppStrings.navPos,
        route: '/pos',
        isActive: currentRoute == '/pos',
      ),
      _NavDestination(
        label: AppStrings.navOrders,
        route: '/orders',
        isActive: currentRoute == '/orders',
      ),
      _NavDestination(
        label: AppStrings.navReports,
        route: '/reports',
        isActive: currentRoute == '/reports',
      ),
      _NavDestination(
        label: AppStrings.navShifts,
        route: '/shifts',
        isActive: currentRoute == '/shifts',
      ),
      if (isAdmin)
        _NavDestination(
          label: AppStrings.navAdmin,
          route: '/admin',
          isActive: currentRoute.startsWith('/admin'),
        ),
    ];
  }

  ({Color color, String label}) _resolveShiftIndicator(Shift? shift) {
    if (shift == null) {
      return (color: AppColors.error, label: AppStrings.shiftClosed);
    }

    switch (shift.status) {
      case ShiftStatus.open:
        return (
          color: AppColors.success,
          label: AppStrings.openShiftLabel(shift.id),
        );
      case ShiftStatus.closed:
        return (color: AppColors.error, label: AppStrings.shiftClosed);
      case ShiftStatus.locked:
        return (
          color: AppColors.warning,
          label:
              '${AppStrings.openShiftLabel(shift.id)} (${AppStrings.statusLocked})',
        );
    }
  }
}

class _HeaderLayoutConfig {
  const _HeaderLayoutConfig({
    required this.layout,
    required this.useCompactTitle,
    required this.useCompactInlineNav,
  });

  final _HeaderNavLayout layout;
  final bool useCompactTitle;
  final bool useCompactInlineNav;

  static _HeaderLayoutConfig resolve({
    required double viewportWidth,
    required bool compactVisual,
    required List<String> navLabels,
    required String shiftLabel,
    required String logoutLabel,
  }) {
    final double wideRequiredWidth = _estimateHeaderWidth(
      compactTitle: compactVisual,
      compactNav: false,
      navLabels: navLabels,
      shiftLabel: shiftLabel,
      logoutLabel: logoutLabel,
    );
    final double compactRequiredWidth = _estimateHeaderWidth(
      compactTitle: true,
      compactNav: true,
      navLabels: navLabels,
      shiftLabel: shiftLabel,
      logoutLabel: logoutLabel,
    );
    final _HeaderNavLayout layout = viewportWidth >= wideRequiredWidth
        ? _HeaderNavLayout.wide
        : (viewportWidth >= compactRequiredWidth
              ? _HeaderNavLayout.compact
              : _HeaderNavLayout.collapsed);

    return _HeaderLayoutConfig(
      layout: layout,
      useCompactTitle: compactVisual || layout != _HeaderNavLayout.wide,
      useCompactInlineNav: compactVisual || layout == _HeaderNavLayout.compact,
    );
  }

  static double _estimateHeaderWidth({
    required bool compactTitle,
    required bool compactNav,
    required List<String> navLabels,
    required String shiftLabel,
    required String logoutLabel,
  }) {
    final double titleWidth = compactTitle
        ? _estimateCompactTitleWidth(shiftLabel)
        : _estimateStandardTitleWidth(shiftLabel);
    final double actionsWidth = _estimateActionsWidth(
      navLabels: navLabels,
      compactNav: compactNav,
      logoutLabel: logoutLabel,
    );
    final double buffer = compactNav ? 32 : 48;

    return titleWidth + actionsWidth + buffer;
  }

  static double _estimateCompactTitleWidth(String shiftLabel) {
    final double labelWidth = _measureTextWidth(
      shiftLabel,
      const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
    );

    return 42 + 8 + labelWidth + 32;
  }

  static double _estimateStandardTitleWidth(String shiftLabel) {
    final double labelWidth = _measureTextWidth(
      shiftLabel,
      const TextStyle(
        fontSize: AppSizes.fontSm,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
    );

    return 212 + 16 + labelWidth + 48;
  }

  static double _estimateActionsWidth({
    required List<String> navLabels,
    required bool compactNav,
    required String logoutLabel,
  }) {
    final TextStyle buttonStyle = TextStyle(
      fontSize: compactNav ? 11.5 : AppSizes.fontSm,
      fontWeight: FontWeight.w600,
      letterSpacing: compactNav ? -0.1 : -0.2,
    );
    final double navHorizontalPadding = compactNav ? 16 : 32;
    final double navGap = compactNav ? 4 : 8;
    double totalWidth = compactNav ? 8 : 16;

    for (final String label in navLabels) {
      totalWidth +=
          _measureTextWidth(label, buttonStyle) + navHorizontalPadding + navGap;
    }

    final TextStyle logoutStyle = TextStyle(
      fontSize: compactNav ? 11.5 : AppSizes.fontSm,
      fontWeight: FontWeight.w600,
      letterSpacing: compactNav ? -0.1 : -0.2,
    );

    totalWidth += compactNav ? 6 : 12;
    totalWidth += _measureTextWidth(logoutLabel, logoutStyle);
    totalWidth += compactNav ? 16 : 44;
    totalWidth += compactNav ? 12 : 20;

    return totalWidth;
  }

  static double _measureTextWidth(String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    return painter.width;
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.route,
    required this.isActive,
  });

  final String label;
  final String route;
  final bool isActive;
}

class _CompactHeaderTitle extends StatelessWidget {
  const _CompactHeaderTitle({
    super.key,
    required this.shiftIndicator,
    required this.onOpenShifts,
  });

  final ({Color color, String label}) shiftIndicator;
  final VoidCallback onOpenShifts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Text(
          'EPOS',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: _ShiftIndicator(
            shiftIndicator: shiftIndicator,
            compactVisual: true,
            onTap: onOpenShifts,
          ),
        ),
      ],
    );
  }
}

class _InlineHeaderActions extends StatelessWidget {
  const _InlineHeaderActions({
    super.key,
    required this.destinations,
    required this.onLogout,
    required this.compactVisual,
  });

  final List<_NavDestination> destinations;
  final VoidCallback onLogout;
  final bool compactVisual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: compactVisual ? 8 : AppSizes.spacingMd),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final _NavDestination destination in destinations)
            _NavButton(
              key: ValueKey<String>(
                'section_app_bar_inline_nav_${destination.route}',
              ),
              label: destination.label,
              isActive: destination.isActive,
              onTap: () => context.go(destination.route),
              compactVisual: compactVisual,
            ),
          SizedBox(width: compactVisual ? 2 : AppSizes.spacingSm),
          compactVisual
              ? TextButton(
                  key: const ValueKey<String>('section_app_bar_inline_logout'),
                  onPressed: onLogout,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                  ),
                  child: Text(AppStrings.navLogout),
                )
              : OutlinedButton(
                  key: const ValueKey<String>('section_app_bar_inline_logout'),
                  onPressed: onLogout,
                  child: Text(
                    AppStrings.navLogout,
                    style: const TextStyle(fontSize: AppSizes.fontSm),
                  ),
                ),
        ],
      ),
    );
  }
}

class _ShiftIndicator extends StatelessWidget {
  const _ShiftIndicator({
    required this.shiftIndicator,
    required this.compactVisual,
    required this.onTap,
  });

  final ({Color color, String label}) shiftIndicator;
  final bool compactVisual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(
        compactVisual ? 999 : AppSizes.radiusSm,
      ),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compactVisual ? 8 : 12,
          vertical: compactVisual ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: shiftIndicator.color.withValues(
            alpha: compactVisual ? 0.08 : 0.12,
          ),
          borderRadius: BorderRadius.circular(
            compactVisual ? 999 : AppSizes.radiusSm,
          ),
          border: Border.all(
            color: shiftIndicator.color.withValues(
              alpha: compactVisual ? 0.16 : 0,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compactVisual ? 6 : 10,
              height: compactVisual ? 6 : 10,
              decoration: BoxDecoration(
                color: shiftIndicator.color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: compactVisual ? 5 : AppSizes.spacingSm),
            Flexible(
              child: Text(
                shiftIndicator.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compactVisual ? 11.5 : AppSizes.fontSm,
                  color: shiftIndicator.color,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsedNavigationButton extends StatelessWidget {
  const _CollapsedNavigationButton({
    required this.destinations,
    required this.onLogout,
    required this.compactVisual,
  });

  final List<_NavDestination> destinations;
  final VoidCallback onLogout;
  final bool compactVisual;

  Future<void> _openNavigationMenu(BuildContext context) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Navigation',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: compactVisual ? 6 : 10,
                    right: compactVisual ? 8 : 12,
                    left: 12,
                  ),
                  child: _CollapsedNavigationSheet(
                    destinations: destinations,
                    onSelectDestination: (_NavDestination destination) {
                      Navigator.of(dialogContext).pop();
                      if (!destination.isActive) {
                        context.go(destination.route);
                      }
                    },
                    onLogout: () {
                      Navigator.of(dialogContext).pop();
                      onLogout();
                    },
                  ),
                ),
              ),
            );
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final CurvedAnimation curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, -0.02),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: compactVisual ? 4 : AppSizes.spacingSm),
      child: IconButton(
        key: const ValueKey<String>('section_app_bar_nav_menu_button'),
        tooltip: 'Navigation',
        onPressed: () => _openNavigationMenu(context),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          backgroundColor: AppColors.surface,
          minimumSize: const Size(40, 40),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
        icon: const Icon(Icons.menu_rounded),
      ),
    );
  }
}

class _CollapsedNavigationSheet extends StatelessWidget {
  const _CollapsedNavigationSheet({
    required this.destinations,
    required this.onSelectDestination,
    required this.onLogout,
  });

  final List<_NavDestination> destinations;
  final ValueChanged<_NavDestination> onSelectDestination;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey<String>('section_app_bar_nav_menu_sheet'),
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 312),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.9)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 2, 6, 8),
                  child: Text(
                    'Navigation',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                for (final _NavDestination destination in destinations)
                  _CollapsedNavigationItem(
                    key: ValueKey<String>(
                      'section_app_bar_menu_nav_${destination.route}',
                    ),
                    label: destination.label,
                    isActive: destination.isActive,
                    onTap: () => onSelectDestination(destination),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                TextButton(
                  key: const ValueKey<String>('section_app_bar_menu_logout'),
                  onPressed: onLogout,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size.fromHeight(46),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(AppStrings.navLogout),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollapsedNavigationItem extends StatelessWidget {
  const _CollapsedNavigationItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: isActive ? null : onTap,
      style: TextButton.styleFrom(
        foregroundColor: isActive ? AppColors.primary : AppColors.textPrimary,
        backgroundColor: isActive
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
      child: Text(label),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.compactVisual,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool compactVisual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compactVisual ? 2 : AppSizes.spacingXs,
      ),
      child: TextButton(
        onPressed: isActive ? null : onTap,
        style: TextButton.styleFrom(
          foregroundColor: isActive
              ? AppColors.primary
              : (compactVisual
                    ? AppColors.textSecondary
                    : AppColors.textPrimary),
          backgroundColor: isActive
              ? AppColors.primary.withValues(alpha: compactVisual ? 0.08 : 0.10)
              : Colors.transparent,
          padding: EdgeInsets.symmetric(
            horizontal: compactVisual ? 8 : 16,
            vertical: compactVisual ? 5 : 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compactVisual ? 8 : 16),
          ),
          textStyle: TextStyle(
            fontSize: compactVisual ? 11.5 : AppSizes.fontSm,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: compactVisual ? -0.1 : -0.2,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
