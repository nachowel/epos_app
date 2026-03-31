import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/sync_failure_details.dart';
import '../../../domain/models/sync_failure_guidance.dart';
import '../../../domain/models/sync_queue_item.dart';
import '../../../domain/models/sync_reset_blocked_result.dart';
import '../../providers/admin_sync_provider.dart';
import 'widgets/admin_scaffold.dart';

class AdminSyncScreen extends ConsumerStatefulWidget {
  const AdminSyncScreen({super.key});

  @override
  ConsumerState<AdminSyncScreen> createState() => _AdminSyncScreenState();
}

class _AdminSyncScreenState extends ConsumerState<AdminSyncScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminSyncNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminSyncState state = ref.watch(adminSyncNotifierProvider);

    return AdminScaffold(
      title: AppStrings.syncMonitorTitle,
      currentRoute: '/admin/sync',
      child: RefreshIndicator(
        onRefresh: () => ref.read(adminSyncNotifierProvider.notifier).load(),
        child: ListView(
          children: <Widget>[
            Wrap(
              spacing: AppSizes.spacingMd,
              runSpacing: AppSizes.spacingMd,
              children: <Widget>[
                _MetricCard(
                  label: AppStrings.pending,
                  value: '${state.pendingCount}',
                  color: AppColors.primary,
                ),
                _MetricCard(
                  label: AppStrings.failed,
                  value: '${state.failedCount}',
                  color: AppColors.error,
                ),
                _MetricCard(
                  label: 'Synced',
                  value: '${state.syncedCount}',
                  color: AppColors.success,
                ),
                _MetricCard(
                  label: AppStrings.stuck,
                  value: '${state.stuckCount}',
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacingMd),
            Wrap(
              spacing: AppSizes.spacingMd,
              runSpacing: AppSizes.spacingMd,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _StatusChip(
                  label: state.isOnline
                      ? AppStrings.online
                      : AppStrings.offline,
                  color: state.isOnline
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                _StatusChip(
                  label: state.isWorkerRunning
                      ? AppStrings.workerRunning
                      : AppStrings.workerIdle,
                  color: state.isWorkerRunning
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                _StatusChip(
                  label: state.syncEnabled
                      ? AppStrings.syncEnabled
                      : AppStrings.syncDisabled,
                  color: state.syncEnabled
                      ? AppColors.success
                      : AppColors.warning,
                ),
                _StatusChip(
                  label: state.supabaseConfigurationLabel,
                  color: state.isSupabaseConfigured
                      ? AppColors.success
                      : AppColors.warning,
                ),
                FilledButton.tonal(
                  onPressed: state.isRetrying ? null : () => _retryAll(context),
                  child: Text(
                    state.isRetrying
                        ? AppStrings.retrying
                        : AppStrings.retryAllFailed,
                  ),
                ),
                OutlinedButton(
                  onPressed: state.isRetrying
                      ? null
                      : () => _resetBlockedFailures(context),
                  child: const Text('Reset blocked failures'),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacingMd),
            _InfoCard(
              title: AppStrings.lastSyncTitle,
              value: state.lastSyncedAt == null
                  ? AppStrings.noSuccessfulSyncYet
                  : DateFormatter.formatDefault(state.lastSyncedAt!),
            ),
            const SizedBox(height: AppSizes.spacingSm),
            _InfoCard(
              title: AppStrings.supabaseTitle,
              value:
                  state.supabaseConfigurationIssue ??
                  (state.syncEnabled
                      ? AppStrings.supabaseConfiguredHidden
                      : AppStrings.syncFeatureDisabledForBuild),
              color: state.isSupabaseConfigured
                  ? AppColors.textPrimary
                  : AppColors.warning,
            ),
            const SizedBox(height: AppSizes.spacingSm),
            _InfoCard(
              title: AppStrings.lastErrorTitle,
              value:
                  _displayFailureMessage(state.lastError) ??
                  (state.lastError?.trim().isNotEmpty == true
                      ? state.lastError!.trim()
                      : AppStrings.noLastError),
              color: state.lastError?.trim().isNotEmpty == true
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: AppSizes.spacingSm),
            Wrap(
              spacing: AppSizes.spacingMd,
              runSpacing: AppSizes.spacingMd,
              children: <Widget>[
                _StatusChip(
                  label: 'Retryable failed ${state.retryableFailedCount}',
                  color: AppColors.primary,
                ),
                _StatusChip(
                  label: 'Non-retryable ${state.nonRetryableFailedCount}',
                  color: AppColors.error,
                ),
                _StatusChip(
                  label: 'Drift blocked ${state.driftBlockedCount}',
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spacingSm),
            _FailureSummaryCard(
              item: state.lastFailedItem,
              maxRetryAttempts: state.maxRetryAttempts,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            _Banner(
              message:
                  'Queue rows represent transaction roots only. Child rows are rebuilt from local Drift state during sync.',
            ),
            const SizedBox(height: AppSizes.spacingSm),
            _Banner(
              message:
                  'Retry reuses the current local terminal graph only when its checksum still matches the original root snapshot.',
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            _Banner(
              message: state.stuckDefinition,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSizes.spacingMd),
            _Banner(message: AppStrings.syncQueueInfoMessage),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.spacingMd),
                child: _Banner(
                  message: state.errorMessage!,
                  color: AppColors.error,
                ),
              ),
            const SizedBox(height: AppSizes.spacingMd),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSizes.spacingXl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.items.isEmpty)
              _Banner(message: AppStrings.noSyncQueueItems)
            else
              ...state.items.map(
                (SyncQueueItem item) => _SyncItemTile(
                  item: item,
                  maxRetryAttempts: state.maxRetryAttempts,
                  isRetrying: state.isRetrying,
                  onRetry: item.status == SyncQueueStatus.failed
                      ? () => _retryItem(context, item.id)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _retryAll(BuildContext context) async {
    final result = await ref
        .read(adminSyncNotifierProvider.notifier)
        .retryAll();
    if (!context.mounted) {
      return;
    }
    final String message;
    if (result != null) {
      message =
          'Retried ${result.retriedCount} item(s), skipped ${result.skippedCount}. '
          'Skipped non-retryable: ${result.skippedNonRetryableCount}, manual review: ${result.skippedManualReviewCount}.';
    } else {
      message =
          ref.read(adminSyncNotifierProvider).errorMessage ??
          AppStrings.retryAllFailedMessage;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _retryItem(BuildContext context, int itemId) async {
    final bool success = await ref
        .read(adminSyncNotifierProvider.notifier)
        .retryItem(itemId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? AppStrings.retryItemSuccess
              : (ref.read(adminSyncNotifierProvider).errorMessage ??
                    AppStrings.retryFailedMessage),
        ),
      ),
    );
  }

  Future<void> _resetBlockedFailures(BuildContext context) async {
    final SyncResetBlockedResult? result = await ref
        .read(adminSyncNotifierProvider.notifier)
        .resetBlockedFailures();
    if (!context.mounted) {
      return;
    }
    final String message;
    if (result != null) {
      message =
          'Reset ${result.resetCount} blocked trusted-sync item(s) for retest, skipped ${result.skippedCount}.';
    } else {
      message =
          ref.read(adminSyncNotifierProvider).errorMessage ??
          'Blocked failure reset failed.';
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _displayFailureMessage(String? rawValue) {
    final SyncFailureDetails? details = SyncFailureDetails.tryParse(rawValue);
    if (details == null) {
      return null;
    }
    return details.message;
  }
}

class _FailureSummaryCard extends StatelessWidget {
  const _FailureSummaryCard({
    required this.item,
    required this.maxRetryAttempts,
  });

  final SyncQueueItem? item;
  final int maxRetryAttempts;

  @override
  Widget build(BuildContext context) {
    final SyncQueueItem? failedItem = item;
    if (failedItem == null) {
      return const _InfoCard(
        title: 'Last failed sync',
        value: 'No failed sync item recorded.',
        color: AppColors.textSecondary,
      );
    }

    final SyncFailureDetails? details = failedItem.failureDetails;
    final SyncFailureGuidance guidance = resolveSyncFailureGuidance(
      failedItem,
      maxRetryAttempts: maxRetryAttempts,
    );
    final String? failedTableName = details?.tableName;
    final String? payloadUuid = details?.recordUuid;
    final List<String> issues = details?.issues ?? const <String>[];
    final List<String> lines = <String>[
      'Root UUID: ${failedItem.recordUuid}',
      'Status: ${guidance.summaryLabel}',
      if (failedTableName != null) 'Failed table: $failedTableName',
      'Failure type: ${details?.failureKind.name ?? 'unknown'}',
      'Retryable: ${details?.retryable?.toString() ?? 'unknown'}',
      'Attempts: ${failedItem.attemptCount}',
      'Last attempt: ${failedItem.lastAttemptAt == null ? 'Never' : DateFormatter.formatDefault(failedItem.lastAttemptAt!)}',
      'Reason: ${guidance.reason}',
      'Next step: ${guidance.nextStep}',
      'Message: ${details?.message ?? failedItem.errorMessage ?? 'Unknown error'}',
    ];
    if (payloadUuid != null && payloadUuid != failedItem.recordUuid) {
      lines.add('Payload UUID: $payloadUuid');
    }
    if (issues.isNotEmpty) {
      lines.add('Issues: ${issues.join(', ')}');
    }

    return _InfoCard(
      title: 'Last failed sync',
      value: lines.join('\n'),
      color: AppColors.error,
    );
  }
}

class _SyncItemTile extends StatelessWidget {
  const _SyncItemTile({
    required this.item,
    required this.maxRetryAttempts,
    required this.isRetrying,
    required this.onRetry,
  });

  final SyncQueueItem item;
  final int maxRetryAttempts;
  final bool isRetrying;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final SyncFailureDetails? details = item.failureDetails;
    final SyncFailureGuidance? guidance = item.status == SyncQueueStatus.failed
        ? resolveSyncFailureGuidance(item, maxRetryAttempts: maxRetryAttempts)
        : null;
    final Widget? trailing = switch ((onRetry, guidance)) {
      (null, _) => null,
      (_, final SyncFailureGuidance guidance) when !guidance.canManualRetry =>
        Tooltip(
          message: guidance.nextStep,
          child: OutlinedButton(onPressed: null, child: Text(AppStrings.retry)),
        ),
      _ => OutlinedButton(
        onPressed: isRetrying ? null : () => onRetry!(),
        child: Text(AppStrings.retry),
      ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: ListTile(
        title: Text(
          '${item.tableName} · ${item.recordUuid}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${AppStrings.statusLabel}: ${_statusText(item.status)}'),
            Text('${AppStrings.attemptsLabel}: ${item.attemptCount}'),
            Text(
              '${AppStrings.createdLabel}: ${DateFormatter.formatDefault(item.createdAt)}',
            ),
            if (guidance != null) ...<Widget>[
              Text('Status: ${guidance.summaryLabel}'),
              Text('Why retry may be blocked: ${guidance.reason}'),
              Text('Next step: ${guidance.nextStep}'),
            ],
            if (details != null) ...<Widget>[
              Text('Failure type: ${details.failureKind.name}'),
              Text('Retryable: ${details.retryable?.toString() ?? 'unknown'}'),
              if (details.tableName != null)
                Text('Failed table: ${details.tableName}'),
              if (details.recordUuid != null)
                Text('Payload UUID: ${details.recordUuid}'),
              if (details.issues.isNotEmpty)
                Text('Issues: ${details.issues.join(', ')}'),
              Text('Message: ${details.message}'),
            ],
            if (item.lastAttemptAt != null)
              Text(
                '${AppStrings.lastAttemptLabel}: ${DateFormatter.formatDefault(item.lastAttemptAt!)}',
              ),
            if (item.syncedAt != null)
              Text(
                '${AppStrings.syncedLabel}: ${DateFormatter.formatDefault(item.syncedAt!)}',
              ),
            if (details == null &&
                item.errorMessage != null &&
                item.errorMessage!.isNotEmpty)
              Text('${AppStrings.errorLabel}: ${item.errorMessage!}'),
          ],
        ),
        trailing: trailing,
      ),
    );
  }

  String _statusText(SyncQueueStatus status) {
    return switch (status) {
      SyncQueueStatus.pending => AppStrings.pending,
      SyncQueueStatus.processing => AppStrings.processing,
      SyncQueueStatus.synced => AppStrings.syncedStatus,
      SyncQueueStatus.failed => AppStrings.failed,
    };
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
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
            label,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    this.color = AppColors.textPrimary,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingXs),
          Text(value, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingMd,
        vertical: AppSizes.spacingSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, this.color = AppColors.primary});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}
