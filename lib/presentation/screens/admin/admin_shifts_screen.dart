import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/shift.dart';
import '../../../domain/models/shift_report.dart';
import '../../../domain/models/stale_final_close_recovery_details.dart';
import '../../providers/admin_shift_provider.dart';
import '../../widgets/counted_cash_dialog.dart';
import '../../widgets/stale_final_close_recovery_dialog.dart';
import 'widgets/admin_scaffold.dart';

final adminShiftUserNameProvider = FutureProvider.family<String, int>((
  Ref ref,
  int userId,
) async {
  final user = await ref.read(authServiceProvider).getUserById(userId);
  return user?.name ?? AppStrings.unknownUser;
});

class AdminShiftsScreen extends ConsumerStatefulWidget {
  const AdminShiftsScreen({super.key});

  @override
  ConsumerState<AdminShiftsScreen> createState() => _AdminShiftsScreenState();
}

class _AdminShiftsScreenState extends ConsumerState<AdminShiftsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminShiftNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminShiftNotifierProvider);

    return AdminScaffold(
      title: AppStrings.shiftControlTitle,
      currentRoute: '/admin/shifts',
      child: RefreshIndicator(
        onRefresh: () => ref.read(adminShiftNotifierProvider.notifier).load(),
        child: ListView(
          children: <Widget>[
            if (state.errorMessage != null)
              _Banner(message: state.errorMessage!, color: AppColors.error),
            _Banner(
              message: AppStrings.shiftControlBannerMessage,
              color: AppColors.primary,
            ),
            _ActiveShiftPanel(
              shift: state.activeShift,
              report: state.activeReport,
              isBusy: state.isActionLoading,
              onFinalClose: () async {
                final ShiftReport? report = state.activeReport;
                if (report == null) {
                  return;
                }
                final int? countedCashMinor = await showDialog<int>(
                  context: context,
                  builder: (_) => CountedCashDialog(
                    expectedCashMinor: report.cashTotalMinor,
                  ),
                );
                if (countedCashMinor == null) {
                  return;
                }
                final bool success = await ref
                    .read(adminShiftNotifierProvider.notifier)
                    .runFinalClose(countedCashMinor: countedCashMinor);
                if (!context.mounted) {
                  return;
                }
                final AdminShiftState shiftState = ref.read(
                  adminShiftNotifierProvider,
                );
                final StaleFinalCloseRecoveryDetails? recovery =
                    shiftState.staleFinalCloseRecovery;
                if (recovery != null) {
                  await _handleStaleFinalCloseRecovery(recovery);
                  return;
                }
                _showMessage(
                  success
                      ? AppStrings.finalCloseCompleted
                      : (shiftState.errorMessage ??
                            AppStrings.finalCloseFailed),
                );
              },
            ),
            const SizedBox(height: AppSizes.spacingLg),
            Text(
              AppStrings.shiftHistoryTitle,
              style: const TextStyle(
                fontSize: AppSizes.fontMd,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            if (state.recentShifts.isEmpty)
              _Banner(
                message: AppStrings.noShiftHistoryYet,
                color: AppColors.warning,
              )
            else
              ...state.recentShifts.map(
                (Shift shift) => _HistoryTile(shift: shift),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStaleFinalCloseRecovery(
    StaleFinalCloseRecoveryDetails recovery,
  ) async {
    final StaleFinalCloseRecoveryAction? action =
        await showDialog<StaleFinalCloseRecoveryAction>(
          context: context,
          builder: (_) => StaleFinalCloseRecoveryDialog(recovery: recovery),
        );
    if (!mounted) {
      return;
    }

    switch (action) {
      case StaleFinalCloseRecoveryAction.resume:
        final bool resumed = await ref
            .read(adminShiftNotifierProvider.notifier)
            .resumeStaleFinalClose();
        if (!mounted) {
          return;
        }
        final AdminShiftState shiftState = ref.read(adminShiftNotifierProvider);
        _showMessage(
          resumed
              ? AppStrings.finalCloseCompleted
              : (shiftState.errorMessage ?? AppStrings.finalCloseFailed),
        );
        return;
      case StaleFinalCloseRecoveryAction.discardAndReenter:
        final bool discarded = await ref
            .read(adminShiftNotifierProvider.notifier)
            .discardStaleFinalClose();
        if (!mounted) {
          return;
        }
        if (!discarded) {
          final AdminShiftState shiftState = ref.read(
            adminShiftNotifierProvider,
          );
          _showMessage(shiftState.errorMessage ?? AppStrings.finalCloseFailed);
          return;
        }
        final ShiftReport? report = ref
            .read(adminShiftNotifierProvider)
            .activeReport;
        if (report == null) {
          return;
        }
        final int? countedCashMinor = await showDialog<int>(
          context: context,
          builder: (_) =>
              CountedCashDialog(expectedCashMinor: report.cashTotalMinor),
        );
        if (countedCashMinor == null || !mounted) {
          return;
        }
        final bool success = await ref
            .read(adminShiftNotifierProvider.notifier)
            .runFinalClose(countedCashMinor: countedCashMinor);
        if (!mounted) {
          return;
        }
        final AdminShiftState shiftState = ref.read(adminShiftNotifierProvider);
        final StaleFinalCloseRecoveryDetails? nextRecovery =
            shiftState.staleFinalCloseRecovery;
        if (nextRecovery != null) {
          await _handleStaleFinalCloseRecovery(nextRecovery);
          return;
        }
        _showMessage(
          success
              ? AppStrings.finalCloseCompleted
              : (shiftState.errorMessage ?? AppStrings.finalCloseFailed),
        );
        return;
      case StaleFinalCloseRecoveryAction.cancel:
      case null:
        ref
            .read(adminShiftNotifierProvider.notifier)
            .clearStaleFinalCloseRecovery();
        return;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ActiveShiftPanel extends StatelessWidget {
  const _ActiveShiftPanel({
    required this.shift,
    required this.report,
    required this.isBusy,
    required this.onFinalClose,
  });

  final Shift? shift;
  final ShiftReport? report;
  final bool isBusy;
  final Future<void> Function() onFinalClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: shift == null
          ? Text(
              AppStrings.nextLoginOpensShift,
              style: const TextStyle(color: AppColors.textSecondary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.openShiftLabel(shift!.id),
                  style: const TextStyle(
                    fontSize: AppSizes.fontLg,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                Text(
                  '${AppStrings.openingLabel}: ${DateFormatter.formatDefault(shift!.openedAt)}',
                ),
                if (shift!.cashierPreviewedAt != null)
                  Text(
                    '${AppStrings.cashierPreviewedAt}: ${DateFormatter.formatDefault(shift!.cashierPreviewedAt!)}',
                  ),
                if (report != null) ...<Widget>[
                  const SizedBox(height: AppSizes.spacingMd),
                  Wrap(
                    spacing: AppSizes.spacingLg,
                    runSpacing: AppSizes.spacingSm,
                    children: <Widget>[
                      Text('${AppStrings.paidOrders}: ${report!.paidCount}'),
                      Text(
                        '${AppStrings.openOrdersTitle}: ${report!.openCount}',
                      ),
                      Text(
                        '${AppStrings.cancelledOrders}: ${report!.cancelledCount}',
                      ),
                      Text(
                        '${AppStrings.grossSales}: ${CurrencyFormatter.fromMinor(report!.paidTotalMinor)}',
                      ),
                      Text(
                        '${AppStrings.refundTotal}: ${CurrencyFormatter.fromMinor(report!.refundTotalMinor)}',
                      ),
                      Text(
                        '${AppStrings.netSales}: ${CurrencyFormatter.fromMinor(report!.netSalesMinor)}',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSizes.spacingLg),
                ElevatedButton.icon(
                  onPressed: isBusy ? null : () => onFinalClose(),
                  icon: const Icon(Icons.lock_clock_rounded),
                  label: isBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppStrings.adminFinalClose),
                ),
              ],
            ),
    );
  }
}

class _HistoryTile extends ConsumerWidget {
  const _HistoryTile({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> openedBy = ref.watch(
      adminShiftUserNameProvider(shift.openedBy),
    );
    final AsyncValue<String> closedBy = shift.closedBy == null
        ? const AsyncValue<String>.data('-')
        : ref.watch(adminShiftUserNameProvider(shift.closedBy!));

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: ListTile(
        title: Text(
          AppStrings.openShiftLabel(shift.id),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${AppStrings.openingLabel}: ${DateFormatter.formatDefault(shift.openedAt)}',
            ),
            Text(
              '${AppStrings.closingLabel}: ${shift.closedAt == null ? AppStrings.none : DateFormatter.formatDefault(shift.closedAt!)}',
            ),
            Text(
              '${AppStrings.openedByLabel}: ${openedBy.valueOrNull ?? AppStrings.none}',
            ),
            Text(
              '${AppStrings.closedByLabel}: ${closedBy.valueOrNull ?? AppStrings.none}',
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.color});

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
