import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/cash_movement.dart';
import '../../../domain/models/cashier_dashboard_snapshot.dart';
import '../../../domain/models/interaction_block_reason.dart';
import '../../../domain/models/open_order_summary.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/shift.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cashier_dashboard_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/section_app_bar.dart';

class CashierDashboardScreen extends ConsumerStatefulWidget {
  const CashierDashboardScreen({super.key});

  @override
  ConsumerState<CashierDashboardScreen> createState() =>
      _CashierDashboardScreenState();
}

class _CashierDashboardScreenState
    extends ConsumerState<CashierDashboardScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(cashierDashboardNotifierProvider.notifier).load(),
    );
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      ref.read(cashierDashboardNotifierProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CashierDashboardState dashboardState = ref.watch(
      cashierDashboardNotifierProvider,
    );
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final CashierDashboardSnapshot? snapshot = dashboardState.snapshot;
    final Shift? openShift = snapshot?.shiftSession.backendOpenShift;
    final bool hasOpenShift = openShift != null;
    final bool previewActive =
        snapshot?.shiftSession.cashierPreviewActive ?? false;
    final bool salesLocked = snapshot?.shiftSession.salesLocked ?? false;
    final bool canStartNewOrder = hasOpenShift && !salesLocked;
    final bool canOpenOrders = hasOpenShift;
    final bool canPreview = hasOpenShift && !previewActive;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.dashboard,
        currentRoute: '/dashboard',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(cashierDashboardNotifierProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          children: <Widget>[
            if (dashboardState.errorMessage != null)
              _Banner(
                message: dashboardState.errorMessage!,
                color: AppColors.error,
              ),
            if (dashboardState.isLoading && snapshot == null)
              const Padding(
                padding: EdgeInsets.all(AppSizes.spacingXl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot != null) ...<Widget>[
              // Inline warnings (driven by snapshot, not UI logic)
              ...snapshot.warnings.map(
                (DashboardWarning warning) => _Banner(
                  key: Key('warning-${_warningKeyName(warning.type)}'),
                  message: warning.message,
                  color: _warningColor(warning.type),
                  icon: _warningIcon(warning.type),
                ),
              ),
              _DashboardCard(
                title: AppStrings.activeShiftLabel,
                child: _ShiftStatusBlock(snapshot: snapshot),
              ),
              const SizedBox(height: AppSizes.spacingMd),
              _TwoColumnRow(
                left: _DashboardCard(
                  title: AppStrings.openOrdersTitle,
                  accentColor:
                      snapshot.openOrderLoadLevel == OpenOrderLoadLevel.high
                      ? AppColors.warning
                      : null,
                  trailing: TextButton(
                    onPressed: canOpenOrders
                        ? () => context.go('/orders')
                        : null,
                    child: Text(AppStrings.goToOpenOrders),
                  ),
                  child: _OpenOrdersBlock(snapshot: snapshot),
                ),
                right: _DashboardCard(
                  title: AppStrings.zReport,
                  child: _PreviewStatusBlock(snapshot: snapshot),
                ),
              ),
              const SizedBox(height: AppSizes.spacingMd),
              _DashboardCard(
                title: AppStrings.recentActivity,
                child: _LastActivityBlock(snapshot: snapshot),
              ),
              const SizedBox(height: AppSizes.spacingMd),
              _DashboardCard(
                title: AppStrings.operationsControl,
                child: _QuickActionsBlock(
                  canStartNewOrder: canStartNewOrder,
                  canOpenOrders: canOpenOrders,
                  canPreview: canPreview,
                  onPos: () => context.go('/pos'),
                  onOrders: () => context.go('/orders'),
                  onPreview: () => context.go('/reports'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _warningKeyName(DashboardWarningType type) {
    switch (type) {
      case DashboardWarningType.noShift:
        return 'no-shift';
      case DashboardWarningType.previewTaken:
        return 'preview-taken';
      case DashboardWarningType.highLoad:
        return 'high-load';
    }
  }

  static Color _warningColor(DashboardWarningType type) {
    switch (type) {
      case DashboardWarningType.noShift:
        return AppColors.error;
      case DashboardWarningType.previewTaken:
      case DashboardWarningType.highLoad:
        return AppColors.warning;
    }
  }

  static IconData _warningIcon(DashboardWarningType type) {
    switch (type) {
      case DashboardWarningType.noShift:
        return Icons.block_rounded;
      case DashboardWarningType.previewTaken:
        return Icons.lock_rounded;
      case DashboardWarningType.highLoad:
        return Icons.warning_amber_rounded;
    }
  }
}

class _TwoColumnRow extends StatelessWidget {
  const _TwoColumnRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 1100) {
          return Column(
            children: <Widget>[
              left,
              const SizedBox(height: AppSizes.spacingMd),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            const SizedBox(width: AppSizes.spacingMd),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.child,
    this.trailing,
    this.accentColor,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: accentColor ?? AppColors.border,
          width: accentColor != null ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSizes.spacingMd),
          child,
        ],
      ),
    );
  }
}

class _ShiftStatusBlock extends StatelessWidget {
  const _ShiftStatusBlock({required this.snapshot});

  final CashierDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final Shift? shift = snapshot.shiftSession.backendOpenShift;
    if (shift == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StatusBadge(color: AppColors.error, label: AppStrings.shiftClosed),
          const SizedBox(height: AppSizes.spacingSm),
          _EmptyState(
            message:
                snapshot.shiftSession.lockReason?.operatorMessage ??
                AppStrings.shiftClosedOpenShiftRequired,
          ),
        ],
      );
    }

    final ({Color color, String label}) statusBadge =
        switch (snapshot.shiftSession.effectiveShiftStatus) {
          ShiftStatus.open => (
            color: AppColors.success,
            label: AppStrings.shiftOpen,
          ),
          ShiftStatus.closed => (
            color: AppColors.error,
            label: AppStrings.shiftClosed,
          ),
          ShiftStatus.locked => (
            color: AppColors.warning,
            label: AppStrings.shiftLocked,
          ),
        };

    // Operational state indicator (driven by snapshot, not UI logic)
    final ({Color color, String label, IconData icon}) operationalState =
        _operationalStateDisplay(snapshot.operationalState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSizes.spacingSm,
          runSpacing: AppSizes.spacingSm,
          children: <Widget>[
            _StatusBadge(color: statusBadge.color, label: statusBadge.label),
            _StatusBadge(
              color: operationalState.color,
              label: operationalState.label,
              icon: operationalState.icon,
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacingMd),
        _InfoRow(
          label: AppStrings.openedBy,
          value: snapshot.openedByUser?.name ?? AppStrings.unknownUser,
        ),
        _InfoRow(
          label: AppStrings.openedAt,
          value: DateFormatter.formatDefault(shift.openedAt),
        ),
        _InfoRow(
          label: AppStrings.cashierPreviewedAt,
          value: shift.cashierPreviewedAt == null
              ? AppStrings.cashierPreviewPending
              : DateFormatter.formatDefault(shift.cashierPreviewedAt!),
        ),
        if (shift.cashierPreviewedAt != null)
          _InfoRow(
            label: AppStrings.cashierPreviewedBy,
            value:
                snapshot.cashierPreviewedByUser?.name ?? AppStrings.unknownUser,
          ),
      ],
    );
  }

  static ({Color color, String label, IconData icon}) _operationalStateDisplay(
    ShiftOperationalState state,
  ) {
    switch (state) {
      case ShiftOperationalState.noShift:
      case ShiftOperationalState.previewTakenLocked:
        return (
          color: AppColors.warning,
          label: AppStrings.shiftPreviewTaken,
          icon: Icons.lock_rounded,
        );
      case ShiftOperationalState.normal:
        return (
          color: AppColors.success,
          label: AppStrings.shiftNormalOperation,
          icon: Icons.check_circle_outline_rounded,
        );
    }
  }
}

class _OpenOrdersBlock extends StatelessWidget {
  const _OpenOrdersBlock({required this.snapshot});

  final CashierDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ({Color color, String label}) loadChip = _loadChipData(
      snapshot.openOrderLoadLevel,
    );

    if (snapshot.openOrders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '0',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: AppSizes.spacingSm),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _StatusBadge(
                  color: loadChip.color,
                  label: loadChip.label,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            AppStrings.noOpenOrders,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '${snapshot.openOrderCount}',
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: AppSizes.spacingSm),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _StatusBadge(color: loadChip.color, label: loadChip.label),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacingSm),
        ...snapshot.openOrders.map(_buildOrderTile),
      ],
    );
  }

  static ({Color color, String label}) _loadChipData(OpenOrderLoadLevel level) {
    switch (level) {
      case OpenOrderLoadLevel.calm:
        return (color: AppColors.success, label: AppStrings.openOrderLoadCalm);
      case OpenOrderLoadLevel.normal:
        return (
          color: AppColors.primary,
          label: AppStrings.openOrderLoadNormal,
        );
      case OpenOrderLoadLevel.high:
        return (color: AppColors.warning, label: AppStrings.openOrderLoadHigh);
    }
  }

  Widget _buildOrderTile(OpenOrderSummary summary) {
    final String title =
        '${AppStrings.orderNumber(summary.transaction.id)} · '
        '${DateFormatter.formatTime(summary.transaction.createdAt)} · '
        '${summary.shortContent}';

    return Builder(
      builder: (BuildContext context) {
        return InkWell(
          onTap: () => context.push('/orders/${summary.transaction.id}'),
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.spacingSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSizes.spacingSm),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PreviewStatusBlock extends StatelessWidget {
  const _PreviewStatusBlock({required this.snapshot});

  final CashierDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final Shift? shift = snapshot.shiftSession.backendOpenShift;
    final bool previewTaken = shift?.cashierPreviewedAt != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _InfoRow(
          label: AppStrings.zReport,
          value: previewTaken
              ? AppStrings.shiftPreviewTaken
              : AppStrings.shiftPreviewNotTaken,
        ),
        _InfoRow(
          label: AppStrings.cashierPreviewedAt,
          value: shift?.cashierPreviewedAt == null
              ? AppStrings.cashierPreviewPending
              : DateFormatter.formatDefault(shift!.cashierPreviewedAt!),
        ),
        if (previewTaken)
          _InfoRow(
            label: AppStrings.cashierPreviewedBy,
            value:
                snapshot.cashierPreviewedByUser?.name ?? AppStrings.unknownUser,
          ),
      ],
    );
  }
}

class _LastActivityBlock extends StatelessWidget {
  const _LastActivityBlock({required this.snapshot});

  final CashierDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.activity.isEmpty) {
      return _EmptyState(message: AppStrings.noRecentActivity);
    }

    return Column(
      children: snapshot.activity
          .map((CashierDashboardActivityItem item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(_iconFor(item), color: _iconColorFor(item)),
                  const SizedBox(width: AppSizes.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _labelFor(item),
                          style: const TextStyle(
                            fontSize: AppSizes.fontSm,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          DateFormatter.formatDefault(item.occurredAt),
                          style: const TextStyle(
                            fontSize: AppSizes.fontSm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }

  IconData _iconFor(CashierDashboardActivityItem item) {
    switch (item.type) {
      case CashierDashboardActivityType.payment:
        return Icons.payments_rounded;
      case CashierDashboardActivityType.cancellation:
        return Icons.cancel_rounded;
      case CashierDashboardActivityType.receiptReprint:
        return Icons.print_rounded;
      case CashierDashboardActivityType.cashierPreview:
        return Icons.assessment_rounded;
      case CashierDashboardActivityType.cashMovement:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _iconColorFor(CashierDashboardActivityItem item) {
    switch (item.type) {
      case CashierDashboardActivityType.cancellation:
        return AppColors.error;
      case CashierDashboardActivityType.cashierPreview:
        return AppColors.warning;
      case CashierDashboardActivityType.payment:
      case CashierDashboardActivityType.receiptReprint:
      case CashierDashboardActivityType.cashMovement:
        return AppColors.primary;
    }
  }

  String _labelFor(CashierDashboardActivityItem item) {
    switch (item.type) {
      case CashierDashboardActivityType.payment:
        return 'Order #${item.transactionId} paid ${item.paymentMethod == PaymentMethod.cash ? AppStrings.cash.toLowerCase() : AppStrings.card.toLowerCase()}';
      case CashierDashboardActivityType.cancellation:
        return 'Order #${item.transactionId} cancelled';
      case CashierDashboardActivityType.receiptReprint:
        return 'Receipt reprinted for #${item.transactionId}';
      case CashierDashboardActivityType.cashierPreview:
        return 'Cashier preview run';
      case CashierDashboardActivityType.cashMovement:
        final String movementType =
            item.cashMovementType == CashMovementType.income
            ? 'income'
            : 'expense';
        final String category = item.cashMovementCategory == null
            ? ''
            : ' · ${item.cashMovementCategory}';
        return 'Cash movement $movementType$category';
    }
  }
}

class _QuickActionsBlock extends StatelessWidget {
  const _QuickActionsBlock({
    required this.canStartNewOrder,
    required this.canOpenOrders,
    required this.canPreview,
    required this.onPos,
    required this.onOrders,
    required this.onPreview,
  });

  final bool canStartNewOrder;
  final bool canOpenOrders;
  final bool canPreview;
  final VoidCallback onPos;
  final VoidCallback onOrders;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.spacingSm,
      runSpacing: AppSizes.spacingSm,
      children: <Widget>[
        ElevatedButton.icon(
          key: const Key('cashier-dashboard-pos-action'),
          onPressed: canStartNewOrder ? onPos : null,
          icon: const Icon(Icons.point_of_sale_rounded),
          label: Text(AppStrings.goToPosNewOrder),
        ),
        ElevatedButton.icon(
          key: const Key('cashier-dashboard-orders-action'),
          onPressed: canOpenOrders ? onOrders : null,
          icon: const Icon(Icons.receipt_long_rounded),
          label: Text(AppStrings.goToOpenOrders),
        ),
        ElevatedButton.icon(
          key: const Key('cashier-dashboard-preview-action'),
          onPressed: canPreview ? onPreview : null,
          icon: const Icon(Icons.assessment_rounded),
          label: Text(AppStrings.maskedZReportAction),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: AppSizes.fontSm,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: AppSizes.fontSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.color, required this.label, this.icon});

  final Color color;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingSm,
        vertical: AppSizes.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.message,
    required this.color,
    this.icon,
  });

  final String message;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSizes.spacingSm),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        fontSize: AppSizes.fontSm,
        color: AppColors.textSecondary,
      ),
    );
  }
}
