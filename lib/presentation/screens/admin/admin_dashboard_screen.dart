import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/admin_dashboard_snapshot.dart';
import '../../providers/admin_dashboard_provider.dart';
import 'widgets/admin_scaffold.dart';

const String _cashMovementsLabel = 'Cash Movements';
const String _analyticsLabel = 'Analytics';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminDashboardNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminDashboardNotifierProvider);
    final snapshot = state.snapshot;

    return AdminScaffold(
      title: AppStrings.adminDashboardTitle,
      currentRoute: '/admin',
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(adminDashboardNotifierProvider.notifier).load(),
        child: ListView(
          children: <Widget>[
            if (state.errorMessage != null)
              _InfoBanner(message: state.errorMessage!, color: AppColors.error),
            if (state.isLoading && snapshot == null)
              const Padding(
                padding: EdgeInsets.all(AppSizes.spacingXl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot != null) ...<Widget>[
              Wrap(
                spacing: AppSizes.spacingMd,
                runSpacing: AppSizes.spacingMd,
                children: <Widget>[
                  _MetricCard(
                    title: AppStrings.todaySales,
                    value: CurrencyFormatter.fromMinor(
                      snapshot.todaySalesTotalMinor,
                    ),
                    subtitle: AppStrings.adminRealView,
                    accent: AppColors.success,
                  ),
                  _MetricCard(
                    title: AppStrings.openOrdersTitle,
                    value: '${snapshot.openOrderCount}',
                    subtitle: AppStrings.activeShiftOrders,
                    accent: AppColors.warning,
                  ),
                  _MetricCard(
                    title: AppStrings.syncPendingTitle,
                    value: '${snapshot.pendingSyncCount}',
                    subtitle: AppStrings.syncPendingSubtitle,
                    accent: AppColors.primary,
                  ),
                  _MetricCard(
                    title: AppStrings.syncFailedTitle,
                    value: '${snapshot.failedSyncCount}',
                    subtitle: AppStrings.syncFailedSubtitle,
                    accent: AppColors.error,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingLg),
              _ShiftStatusPanel(snapshot: snapshot),
              const SizedBox(height: AppSizes.spacingLg),
              Wrap(
                spacing: AppSizes.spacingSm,
                runSpacing: AppSizes.spacingSm,
                children: <Widget>[
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/analytics'),
                    icon: const Icon(Icons.analytics_rounded),
                    label: const Text(_analyticsLabel),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/products'),
                    icon: const Icon(Icons.inventory_2_rounded),
                    label: Text(AppStrings.manageProducts),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/cash-movements'),
                    icon: const Icon(Icons.payments_rounded),
                    label: const Text(_cashMovementsLabel),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/shifts'),
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(AppStrings.shiftControl),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.go('/admin/sync'),
                    icon: const Icon(Icons.sync_rounded),
                    label: Text(AppStrings.syncMonitor),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ShiftStatusPanel extends StatelessWidget {
  const _ShiftStatusPanel({required this.snapshot});

  final AdminDashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final shift = snapshot.activeShift;
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppStrings.activeShiftLabel,
            style: const TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          if (shift == null)
            Text(
              AppStrings.adminDashboardNoActiveShift,
              style: const TextStyle(color: AppColors.textSecondary),
            )
          else ...<Widget>[
            Text(
              AppStrings.openShiftLabel(shift.id),
              style: const TextStyle(
                fontSize: AppSizes.fontLg,
                fontWeight: FontWeight.w800,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSizes.spacingSm),
            Text(
              '${AppStrings.openingLabel}: ${DateFormatter.formatDefault(shift.openedAt)}',
            ),
            Text(
              shift.cashierPreviewedAt == null
                  ? AppStrings.cashierPreviewPending
                  : '${AppStrings.cashierPreviewedAt}: ${DateFormatter.formatDefault(shift.cashierPreviewedAt!)}',
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 240),
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Text(
            title,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            value,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}
