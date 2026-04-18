import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/user.dart';

enum _HeaderNavLayout { wide, compact, collapsed }

const String _brandTitle = 'Halfway Cafe POS';
const String _brandLogoAsset = 'assets/images/logo.png';

class SectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SectionAppBar({
    required this.title,
    required this.currentRoute,
    required this.currentUser,
    required this.currentShift,
    required this.onLogout,
    this.compactVisual = false,
    this.onSelectDestination,
    this.onOpenDrawer,
    super.key,
  });

  final String title;
  final String currentRoute;
  final User? currentUser;
  final Shift? currentShift;
  final VoidCallback onLogout;
  final bool compactVisual;
  final FutureOr<void> Function(String route)? onSelectDestination;
  final VoidCallback? onOpenDrawer;

  @override
  Size get preferredSize =>
      Size.fromHeight((compactVisual ? 68 : AppSizes.topBarHeight) + 1);

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
    final bool isCashier = currentUser?.role == UserRole.cashier;
    final String contextLabel = currentUser == null
        ? title
        : '$title · ${currentUser!.name}';
    final VoidCallback? onShiftTap = isCashier
        ? null
        : () => context.go('/shifts');
    final List<_NavDestination> destinations = _buildDestinations(
      isAdmin: isAdmin,
    );
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
      toolbarHeight: compactVisual ? 68 : AppSizes.topBarHeight,
      backgroundColor: AppColors.surface,
      titleSpacing: layoutConfig.useCompactTitle ? 14 : AppSizes.spacingMd,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: AppColors.border.withValues(alpha: 0.85),
        ),
      ),
      title: layoutConfig.useCompactTitle
          ? _CompactHeaderTitle(
              key: const ValueKey<String>('section_app_bar_compact_title'),
              contextLabel: contextLabel,
              shiftIndicator: shiftIndicator,
              onOpenShifts: onShiftTap,
            )
          : Row(
              key: const ValueKey<String>('section_app_bar_standard_title'),
              children: <Widget>[
                Expanded(
                  child: _BrandBlock(
                    contextLabel: contextLabel,
                    compactVisual: false,
                  ),
                ),
                if (layoutConfig.layout !=
                    _HeaderNavLayout.collapsed) ...<Widget>[
                  const SizedBox(width: AppSizes.spacingMd),
                  _ShiftIndicator(
                    shiftIndicator: shiftIndicator,
                    compactVisual: false,
                    onTap: onShiftTap,
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
                onSelectDestination: (_NavDestination destination) =>
                    _handleDestinationTap(context, destination.route),
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
                onOpenDrawer: onOpenDrawer,
                compactVisual: layoutConfig.useCompactInlineNav,
                onSelectDestination: (_NavDestination destination) =>
                    _handleDestinationTap(context, destination.route),
              ),
            ],
    );
  }

  List<_NavDestination> _buildDestinations({required bool isAdmin}) {
    return <_NavDestination>[
      _NavDestination(
        label: AppStrings.categories,
        route: '/pos/categories',
        isActive: currentRoute == '/pos/categories',
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
      if (isAdmin)
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

  FutureOr<void> _handleDestinationTap(BuildContext context, String route) {
    final FutureOr<void> Function(String route)? handler = onSelectDestination;
    if (handler != null) {
      return handler(route);
    }
    context.go(route);
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
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );

    return 184 + 12 + labelWidth + 44;
  }

  static double _estimateStandardTitleWidth(String shiftLabel) {
    final double labelWidth = _measureTextWidth(
      shiftLabel,
      const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );

    return 234 + 16 + labelWidth + 96;
  }

  static double _estimateActionsWidth({
    required List<String> navLabels,
    required bool compactNav,
    required String logoutLabel,
  }) {
    final TextStyle buttonStyle = TextStyle(
      fontSize: compactNav ? 12 : 13.5,
      fontWeight: FontWeight.w600,
      letterSpacing: compactNav ? -0.1 : -0.2,
    );
    final double navHorizontalPadding = compactNav ? 22 : 30;
    final double navGap = compactNav ? 4 : 6;
    double totalWidth = compactNav ? 24 : 34;

    for (final String label in navLabels) {
      totalWidth +=
          _measureTextWidth(label, buttonStyle) + navHorizontalPadding + navGap;
    }

    final TextStyle logoutStyle = TextStyle(
      fontSize: compactNav ? 12 : 13.5,
      fontWeight: FontWeight.w600,
      letterSpacing: compactNav ? -0.1 : -0.2,
    );

    totalWidth += compactNav ? 10 : 14;
    totalWidth += _measureTextWidth(logoutLabel, logoutStyle);
    totalWidth += compactNav ? 48 : 54;
    totalWidth += compactNav ? 14 : 18;

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

class _BrandBlock extends StatelessWidget {
  const _BrandBlock({required this.contextLabel, required this.compactVisual});

  final String contextLabel;
  final bool compactVisual;

  @override
  Widget build(BuildContext context) {
    final double logoShellSize = compactVisual ? 40 : 46;
    final double logoSize = compactVisual ? 26 : 30;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: logoShellSize,
          height: logoShellSize,
          decoration: BoxDecoration(
            color: compactVisual
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(compactVisual ? 12 : 14),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.95)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primaryDarker.withValues(alpha: 0.08),
                blurRadius: compactVisual ? 12 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(compactVisual ? 7 : 8),
            child: Image.asset(
              _brandLogoAsset,
              width: logoSize,
              height: logoSize,
              fit: BoxFit.contain,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Icon(
                      Icons.storefront_rounded,
                      size: logoSize,
                      color: AppColors.primaryStrong,
                    );
                  },
            ),
          ),
        ),
        SizedBox(width: compactVisual ? 10 : 14),
        Flexible(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _brandTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compactVisual ? 15 : 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                  height: 1,
                ),
              ),
              SizedBox(height: compactVisual ? 3 : 4),
              Text(
                contextLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compactVisual ? 11.5 : 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: compactVisual ? -0.05 : -0.1,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactHeaderTitle extends StatelessWidget {
  const _CompactHeaderTitle({
    super.key,
    required this.contextLabel,
    required this.shiftIndicator,
    required this.onOpenShifts,
  });

  final String contextLabel;
  final ({Color color, String label}) shiftIndicator;
  final VoidCallback? onOpenShifts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Flexible(
          child: _BrandBlock(contextLabel: contextLabel, compactVisual: true),
        ),
        const SizedBox(width: 12),
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
    required this.onSelectDestination,
    this.onOpenDrawer,
  });

  final List<_NavDestination> destinations;
  final VoidCallback onLogout;
  final bool compactVisual;
  final FutureOr<void> Function(_NavDestination destination)
  onSelectDestination;
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: compactVisual ? 10 : AppSizes.spacingMd),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(compactVisual ? 14 : 18),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.95),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compactVisual ? 4 : 6,
                vertical: compactVisual ? 4 : 6,
              ),
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
                      onTap: () => onSelectDestination(destination),
                      compactVisual: compactVisual,
                    ),
                ],
              ),
            ),
          ),
          if (onOpenDrawer != null) ...<Widget>[
            SizedBox(width: compactVisual ? 8 : 10),
            OutlinedButton.icon(
              key: const ValueKey<String>('section_app_bar_inline_open_drawer'),
              onPressed: onOpenDrawer,
              icon: Icon(
                Icons.point_of_sale_rounded,
                size: compactVisual ? 16 : 18,
              ),
              label: const Text('Open Drawer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.border.withValues(alpha: 0.92)),
                padding: EdgeInsets.symmetric(
                  horizontal: compactVisual ? 12 : 14,
                  vertical: compactVisual ? 10 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(compactVisual ? 13 : 16),
                ),
                textStyle: TextStyle(
                  fontSize: compactVisual ? 12 : 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: compactVisual ? -0.1 : -0.2,
                ),
              ),
            ),
          ],
          SizedBox(width: compactVisual ? 8 : 10),
          OutlinedButton.icon(
            key: const ValueKey<String>('section_app_bar_inline_logout'),
            onPressed: onLogout,
            icon: Icon(Icons.logout_rounded, size: compactVisual ? 16 : 18),
            label: Text(AppStrings.navLogout),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              backgroundColor: AppColors.surface,
              side: BorderSide(color: AppColors.border.withValues(alpha: 0.92)),
              padding: EdgeInsets.symmetric(
                horizontal: compactVisual ? 12 : 14,
                vertical: compactVisual ? 10 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(compactVisual ? 13 : 16),
              ),
              textStyle: TextStyle(
                fontSize: compactVisual ? 12 : 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: compactVisual ? -0.1 : -0.2,
              ),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(
      compactVisual ? 15 : 18,
    );

    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compactVisual ? 10 : 12,
          vertical: compactVisual ? 8 : 9,
        ),
        decoration: BoxDecoration(
          color: compactVisual ? AppColors.surfaceAlt : AppColors.surface,
          borderRadius: borderRadius,
          border: Border.all(
            color: shiftIndicator.color.withValues(
              alpha: compactVisual ? 0.22 : 0.14,
            ),
          ),
          boxShadow: compactVisual
              ? const <BoxShadow>[]
              : <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: compactVisual ? 20 : 28,
              height: compactVisual ? 20 : 28,
              decoration: BoxDecoration(
                color: shiftIndicator.color.withValues(
                  alpha: compactVisual ? 0.14 : 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: compactVisual ? 7 : 9,
                  height: compactVisual ? 7 : 9,
                  decoration: BoxDecoration(
                    color: shiftIndicator.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            SizedBox(width: compactVisual ? 7 : 10),
            Flexible(
              child: compactVisual
                  ? Text(
                      shiftIndicator.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: shiftIndicator.color,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Shift',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.2,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          shiftIndicator.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            height: 1,
                          ),
                        ),
                      ],
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
    required this.onSelectDestination,
  });

  final List<_NavDestination> destinations;
  final VoidCallback onLogout;
  final bool compactVisual;
  final FutureOr<void> Function(_NavDestination destination)
  onSelectDestination;

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
                        onSelectDestination(destination);
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
          backgroundColor: AppColors.surfaceAlt,
          minimumSize: const Size(42, 42),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.9)),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Text(
                        _brandTitle,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Navigation',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
            ? AppColors.primary.withValues(alpha: 0.09)
            : Colors.transparent,
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(horizontal: compactVisual ? 2 : 3),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(compactVisual ? 12 : 14),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.transparent,
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
      child: InkWell(
        onTap: isActive ? null : onTap,
        borderRadius: BorderRadius.circular(compactVisual ? 12 : 14),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compactVisual ? 10 : 14,
            vertical: compactVisual ? 8 : 10,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: compactVisual ? 12 : 13.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: compactVisual ? -0.1 : -0.15,
              color: isActive
                  ? AppColors.primaryStrong
                  : (compactVisual
                        ? AppColors.textSecondary
                        : AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
