import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/authorization_policy.dart';
import '../../../domain/models/shift.dart';
import '../../../domain/models/shift_close_readiness.dart';
import '../../../domain/models/shift_report.dart';
import '../../../domain/models/stale_final_close_recovery_details.dart';
import '../../../domain/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/counted_cash_dialog.dart';
import '../../widgets/section_app_bar.dart';
import '../../widgets/stale_final_close_recovery_dialog.dart';

final shiftUserNameProvider = FutureProvider.family<String, int>((
  Ref ref,
  int userId,
) async {
  final user = await ref.read(authServiceProvider).getUserById(userId);
  return user?.name ?? AppStrings.unknownUser;
});

class ShiftManagementScreen extends ConsumerStatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  ConsumerState<ShiftManagementScreen> createState() =>
      _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends ConsumerState<ShiftManagementScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
      await ref.read(shiftNotifierProvider.notifier).loadRecentShifts();
    });
  }

  Future<void> _runAction(
    Future<bool> Function() action,
    String successMessage,
  ) async {
    final bool success = await action();
    if (!mounted) {
      return;
    }
    final String message = success
        ? successMessage
        : (ref.read(shiftNotifierProvider).errorMessage ??
              AppStrings.operationFailed);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runFinalCloseWithCountedCash(int expectedCashMinor) async {
    final int? countedCashMinor = await showDialog<int>(
      context: context,
      builder: (_) => CountedCashDialog(expectedCashMinor: expectedCashMinor),
    );
    if (countedCashMinor == null || !mounted) {
      return;
    }
    final bool success = await ref
        .read(shiftNotifierProvider.notifier)
        .finalCloseShift(countedCashMinor: countedCashMinor);
    if (!mounted) {
      return;
    }

    final ShiftState shiftState = ref.read(shiftNotifierProvider);
    final StaleFinalCloseRecoveryDetails? recovery =
        shiftState.staleFinalCloseRecovery;
    if (recovery != null) {
      await _handleStaleFinalCloseRecovery(recovery);
      return;
    }

    _showMessage(
      success
          ? AppStrings.finalCloseCompleted
          : (shiftState.errorMessage ?? AppStrings.operationFailed),
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
            .read(shiftNotifierProvider.notifier)
            .resumeStaleFinalClose();
        if (!mounted) {
          return;
        }
        final ShiftState shiftState = ref.read(shiftNotifierProvider);
        _showMessage(
          resumed
              ? AppStrings.finalCloseCompleted
              : (shiftState.errorMessage ?? AppStrings.finalCloseFailed),
        );
        return;
      case StaleFinalCloseRecoveryAction.discardAndReenter:
        final bool discarded = await ref
            .read(shiftNotifierProvider.notifier)
            .discardStaleFinalClose();
        if (!mounted) {
          return;
        }
        if (!discarded) {
          final ShiftState shiftState = ref.read(shiftNotifierProvider);
          _showMessage(shiftState.errorMessage ?? AppStrings.finalCloseFailed);
          return;
        }
        final Shift? backendShift = ref
            .read(shiftNotifierProvider)
            .backendOpenShift;
        if (backendShift == null) {
          return;
        }
        ref.invalidate(adminVisibleShiftReportProvider(backendShift.id));
        final ShiftReport report = await ref.read(
          adminVisibleShiftReportProvider(backendShift.id).future,
        );
        if (!mounted) {
          return;
        }
        await _runFinalCloseWithCountedCash(report.cashTotalMinor);
        return;
      case StaleFinalCloseRecoveryAction.cancel:
      case null:
        ref.read(shiftNotifierProvider.notifier).clearStaleFinalCloseRecovery();
        return;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final User? currentUser = authState.currentUser;
    final Shift? backendShift = shiftState.backendOpenShift;
    final bool hasOpenShift = backendShift != null;
    final bool canOpenShift = AuthorizationPolicy.canPerform(
      currentUser,
      OperatorPermission.openShift,
    );
    final bool canLockShift = AuthorizationPolicy.canPerform(
      currentUser,
      OperatorPermission.lockShiftForPreviewClose,
    );
    final bool canFinalClose = AuthorizationPolicy.canPerform(
      currentUser,
      OperatorPermission.finalCloseShift,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.navShifts,
        currentRoute: '/shifts',
        currentUser: currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
          await ref.read(shiftNotifierProvider.notifier).loadRecentShifts();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          children: <Widget>[
            if (shiftState.errorMessage != null)
              _Banner(
                message: shiftState.errorMessage!,
                color: AppColors.error,
              ),
            _Banner(
              message: hasOpenShift
                  ? (shiftState.effectiveShiftStatus == ShiftStatus.locked
                        ? AppStrings.salesLockedAdminCloseRequired
                        : AppStrings.closeShiftConfirmation)
                  : AppStrings.shiftScreenNoOpenShift,
              color: hasOpenShift ? AppColors.primary : AppColors.warning,
            ),
            _CurrentShiftCard(
              currentUser: currentUser,
              currentShift: shiftState.currentShift,
              backendShift: backendShift,
              onReviewOrders: hasOpenShift ? () => context.go('/orders') : null,
              onFinalClose: canFinalClose && backendShift != null
                  ? _runFinalCloseWithCountedCash
                  : null,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            Wrap(
              spacing: AppSizes.spacingSm,
              runSpacing: AppSizes.spacingSm,
              children: <Widget>[
                ElevatedButton.icon(
                  onPressed:
                      !hasOpenShift && !shiftState.isLoading && canOpenShift
                      ? () => _runAction(
                          () => ref
                              .read(shiftNotifierProvider.notifier)
                              .openShift(),
                          AppStrings.shiftOpened,
                        )
                      : null,
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: Text(AppStrings.openShiftAction),
                ),
                ElevatedButton.icon(
                  onPressed:
                      hasOpenShift &&
                          canLockShift &&
                          !shiftState.cashierPreviewActive &&
                          !shiftState.isLoading
                      ? () => _runAction(
                          () => ref
                              .read(shiftNotifierProvider.notifier)
                              .lockShift(),
                          AppStrings.shiftLockedMessage,
                        )
                      : null,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: Text(AppStrings.closeShiftAction),
                ),
                ElevatedButton.icon(
                  onPressed:
                      hasOpenShift && canFinalClose && !shiftState.isLoading
                      ? () async {
                          final ShiftReport? report = ref
                              .read(
                                adminVisibleShiftReportProvider(
                                  backendShift!.id,
                                ),
                              )
                              .valueOrNull;
                          if (report == null) {
                            return;
                          }
                          await _runFinalCloseWithCountedCash(
                            report.cashTotalMinor,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.lock_clock_outlined),
                  label: Text(AppStrings.adminFinalClose),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacingLg),
            Text(
              AppStrings.recentShifts,
              style: const TextStyle(
                fontSize: AppSizes.fontMd,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            if (shiftState.recentShifts.isEmpty)
              Text(
                AppStrings.noShiftHistory,
                style: const TextStyle(color: AppColors.textSecondary),
              )
            else
              ...shiftState.recentShifts.map(
                (Shift shift) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
                  child: _ShiftListTile(shift: shift),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrentShiftCard extends ConsumerWidget {
  const _CurrentShiftCard({
    required this.currentUser,
    required this.currentShift,
    required this.backendShift,
    required this.onReviewOrders,
    required this.onFinalClose,
  });

  final User? currentUser;
  final Shift? currentShift;
  final Shift? backendShift;
  final VoidCallback? onReviewOrders;
  final Future<void> Function(int expectedCashMinor)? onFinalClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (backendShift == null) {
      return Container(
        padding: const EdgeInsets.all(AppSizes.spacingLg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          AppStrings.shiftScreenNoOpenShift,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final AsyncValue<String> openedBy = ref.watch(
      shiftUserNameProvider(backendShift!.openedBy),
    );
    final AsyncValue<ShiftCloseReadiness> closeReadiness = ref.watch(
      shiftCloseReadinessProvider(backendShift!.id),
    );
    final AsyncValue<String> previewedBy =
        backendShift!.cashierPreviewedBy == null
        ? const AsyncValue<String>.data('')
        : ref.watch(shiftUserNameProvider(backendShift!.cashierPreviewedBy!));
    final bool showFinancialSummary = AuthorizationPolicy.canPerform(
      currentUser,
      OperatorPermission.viewFullReports,
    );
    final AsyncValue<ShiftReport>? report = showFinancialSummary
        ? ref.watch(adminVisibleShiftReportProvider(backendShift!.id))
        : null;

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
            AppStrings.currentShiftSummary,
            style: const TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          _DetailRow(
            label: AppStrings.shiftIdLabel,
            value: '${backendShift!.id}',
          ),
          _DetailRow(
            label: AppStrings.orderStatusLabel,
            value: AppStrings.shiftStatusText(
              currentShift?.status ?? backendShift!.status,
            ),
            emphasize: currentShift?.status == ShiftStatus.locked,
          ),
          _DetailRow(
            label: AppStrings.openedAt,
            value: DateFormatter.formatDefault(backendShift!.openedAt),
          ),
          _DetailRow(
            label: AppStrings.openedBy,
            value: openedBy.valueOrNull ?? AppStrings.loading,
          ),
          _DetailRow(
            label: AppStrings.cashierPreviewedAt,
            value: backendShift!.cashierPreviewedAt == null
                ? AppStrings.cashierPreviewPending
                : DateFormatter.formatDefault(
                    backendShift!.cashierPreviewedAt!,
                  ),
          ),
          if (backendShift!.cashierPreviewedBy != null)
            _DetailRow(
              label: AppStrings.cashierPreviewedBy,
              value: previewedBy.valueOrNull ?? AppStrings.loading,
            ),
          const SizedBox(height: AppSizes.spacingMd),
          closeReadiness.when(
            data: (ShiftCloseReadiness readiness) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _DetailRow(
                    label: AppStrings.sentOrdersPendingLabel,
                    value: '${readiness.sentOrderCount}',
                    emphasize: readiness.sentOrderCount > 0,
                  ),
                  _DetailRow(
                    label: AppStrings.freshDraftsPendingLabel,
                    value: '${readiness.freshDraftCount}',
                    emphasize: readiness.freshDraftCount > 0,
                  ),
                  _DetailRow(
                    label: AppStrings.staleDraftsPendingLabel,
                    value: '${readiness.staleDraftCount}',
                    emphasize: readiness.staleDraftCount > 0,
                  ),
                  if (readiness.hasStaleDrafts)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSizes.spacingSm),
                      child: Text(
                        AppStrings.staleDraftCloseHelp,
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (!readiness.canFinalClose && onReviewOrders != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSizes.spacingSm),
                      child: TextButton(
                        onPressed: onReviewOrders,
                        child: Text(AppStrings.goToOpenOrders),
                      ),
                    ),
                  const SizedBox(height: AppSizes.spacingMd),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(bottom: AppSizes.spacingMd),
              child: CircularProgressIndicator(),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (report != null)
            report.when(
              data: (ShiftReport shiftReport) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSizes.spacingSm),
                  child: Wrap(
                    spacing: AppSizes.spacingLg,
                    runSpacing: AppSizes.spacingSm,
                    children: <Widget>[
                      Text(
                        '${AppStrings.paidOrders}: ${shiftReport.paidCount}',
                      ),
                      Text(
                        '${AppStrings.cancelledOrders}: ${shiftReport.cancelledCount}',
                      ),
                      _DetailRow(
                        label: AppStrings.expectedCash,
                        value: CurrencyFormatter.fromMinor(
                          shiftReport.cashTotalMinor,
                        ),
                      ),
                      _DetailRow(
                        label: AppStrings.grossSales,
                        value: CurrencyFormatter.fromMinor(
                          shiftReport.paidTotalMinor,
                        ),
                      ),
                      _DetailRow(
                        label: AppStrings.refundTotal,
                        value: CurrencyFormatter.fromMinor(
                          shiftReport.refundTotalMinor,
                        ),
                      ),
                      _DetailRow(
                        label: AppStrings.netSales,
                        value: CurrencyFormatter.fromMinor(
                          shiftReport.netSalesMinor,
                        ),
                      ),
                      Text(
                        '${AppStrings.grossCash}: ${CurrencyFormatter.fromMinor(shiftReport.cashGrossTotalMinor)}',
                      ),
                      Text(
                        '${AppStrings.netCash}: ${CurrencyFormatter.fromMinor(shiftReport.cashTotalMinor)}',
                      ),
                      Text(
                        '${AppStrings.grossCard}: ${CurrencyFormatter.fromMinor(shiftReport.cardGrossTotalMinor)}',
                      ),
                      Text(
                        '${AppStrings.netCard}: ${CurrencyFormatter.fromMinor(shiftReport.cardTotalMinor)}',
                      ),
                      if (onFinalClose != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSizes.spacingSm,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton(
                              onPressed: () =>
                                  onFinalClose!(shiftReport.cashTotalMinor),
                              child: Text(AppStrings.enterCountedCashAction),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => Text(AppStrings.noReportData),
            ),
        ],
      ),
    );
  }
}

class _ShiftListTile extends ConsumerWidget {
  const _ShiftListTile({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String> openedBy = ref.watch(
      shiftUserNameProvider(shift.openedBy),
    );
    final AsyncValue<String> closedBy = shift.closedBy == null
        ? const AsyncValue<String>.data('-')
        : ref.watch(shiftUserNameProvider(shift.closedBy!));

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DetailRow(label: AppStrings.shiftIdLabel, value: '${shift.id}'),
          _DetailRow(
            label: AppStrings.orderStatusLabel,
            value: AppStrings.shiftStatusText(shift.status),
          ),
          _DetailRow(
            label: AppStrings.openedAt,
            value: DateFormatter.formatDefault(shift.openedAt),
          ),
          _DetailRow(
            label: AppStrings.closedAt,
            value: shift.closedAt == null
                ? AppStrings.none
                : DateFormatter.formatDefault(shift.closedAt!),
          ),
          _DetailRow(
            label: AppStrings.openedBy,
            value: openedBy.valueOrNull ?? AppStrings.loading,
          ),
          _DetailRow(
            label: AppStrings.closedBy,
            value: closedBy.valueOrNull ?? AppStrings.loading,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingXs),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? AppColors.warning : AppColors.textPrimary,
            ),
          ),
        ],
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
