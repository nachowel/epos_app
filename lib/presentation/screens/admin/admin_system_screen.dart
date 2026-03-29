import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/audit_log_record.dart';
import '../../providers/admin_audit_provider.dart';
import '../../../domain/models/migration_log_entry.dart';
import '../../../domain/models/system_health_snapshot.dart';
import '../../providers/admin_system_provider.dart';
import 'widgets/admin_scaffold.dart';

class AdminSystemScreen extends ConsumerStatefulWidget {
  const AdminSystemScreen({super.key});

  @override
  ConsumerState<AdminSystemScreen> createState() => _AdminSystemScreenState();
}

class _AdminSystemScreenState extends ConsumerState<AdminSystemScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminSystemNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminSystemState state = ref.watch(adminSystemNotifierProvider);
    final SystemHealthSnapshot? snapshot = state.snapshot;
    final AsyncValue<List<AuditLogRecord>> auditEntries = ref.watch(
      recentAuditLogProvider,
    );

    return AdminScaffold(
      title: AppStrings.systemHealthTitle,
      currentRoute: '/admin/system',
      child: RefreshIndicator(
        onRefresh: () => ref.read(adminSystemNotifierProvider.notifier).load(),
        child: ListView(
          children: <Widget>[
            if (state.errorMessage != null)
              _Banner(message: state.errorMessage!, color: AppColors.error),
            if (state.errorMessage != null)
              const SizedBox(height: AppSizes.spacingMd),
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
                    label: AppStrings.pending,
                    value: '${snapshot.pendingCount}',
                  ),
                  _MetricCard(
                    label: AppStrings.failed,
                    value: '${snapshot.failedCount}',
                  ),
                  _MetricCard(
                    label: AppStrings.stuck,
                    value: '${snapshot.stuckCount}',
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingMd),
              Wrap(
                spacing: AppSizes.spacingMd,
                runSpacing: AppSizes.spacingMd,
                children: <Widget>[
                  _StatusChip(
                    label: snapshot.syncEnabled
                        ? AppStrings.syncEnabled
                        : AppStrings.syncDisabled,
                    color: snapshot.syncEnabled
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  _StatusChip(
                    label: snapshot.supabaseConfigurationLabel,
                    color: snapshot.isSupabaseConfigured
                        ? AppColors.success
                        : AppColors.warning,
                  ),
                  _StatusChip(
                    label: snapshot.isOnline
                        ? AppStrings.online
                        : AppStrings.offline,
                    color: snapshot.isOnline
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                  _StatusChip(
                    label: snapshot.isWorkerRunning
                        ? AppStrings.workerRunning
                        : AppStrings.workerIdle,
                    color: snapshot.isWorkerRunning
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                  _StatusChip(
                    label: snapshot.debugLoggingEnabled
                        ? AppStrings.debugLoggingOn
                        : AppStrings.debugLoggingOff,
                    color: snapshot.debugLoggingEnabled
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingMd),
              _InfoCard(
                title: AppStrings.environmentTitle,
                lines: <String>[
                  '${AppStrings.appVersionLabel}: ${snapshot.appVersion}',
                  '${AppStrings.environmentLabel}: ${snapshot.environment}',
                  '${AppStrings.schemaVersionLabel}: ${snapshot.schemaVersion}',
                  '${AppStrings.activeShiftLabel}: ${snapshot.activeShift?.id ?? AppStrings.none}',
                ],
              ),
              const SizedBox(height: AppSizes.spacingSm),
              _InfoCard(
                title: AppStrings.syncStateTitle,
                lines: <String>[
                  'Supabase: ${snapshot.isSupabaseConfigured ? AppStrings.supabaseConfigured : AppStrings.supabaseNotConfigured}',
                  if (snapshot.supabaseConfigurationIssue != null)
                    '${AppStrings.configIssueLabel}: ${snapshot.supabaseConfigurationIssue}',
                  '${AppStrings.lastSyncLabel}: ${_formatDate(snapshot.lastSyncedAt)}',
                  '${AppStrings.lastErrorLabel}: ${snapshot.lastError?.trim().isNotEmpty == true ? snapshot.lastError! : AppStrings.none}',
                ],
              ),
              const SizedBox(height: AppSizes.spacingSm),
              _InfoCard(
                title: AppStrings.backupTitle,
                lines: <String>[
                  '${AppStrings.lastBackupLabel}: ${snapshot.lastBackup == null ? AppStrings.none : DateFormatter.formatDefault(snapshot.lastBackup!.createdAt.toLocal())}',
                  if (snapshot.lastBackup != null)
                    snapshot.lastBackup!.filePath,
                ],
                footer: FilledButton.tonal(
                  onPressed: state.isExporting ? null : _exportBackup,
                  child: Text(
                    state.isExporting
                        ? AppStrings.exportInProgress
                        : AppStrings.exportLocalDb,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spacingSm),
              _InfoCard(
                title: AppStrings.migrationHistoryTitle,
                lines: snapshot.migrationHistory.isEmpty
                    ? <String>[AppStrings.noMigrationTelemetry]
                    : snapshot.migrationHistory
                          .map(_formatMigrationLog)
                          .toList(growable: false),
                color: snapshot.lastMigrationFailure == null
                    ? AppColors.textPrimary
                    : AppColors.error,
              ),
              const SizedBox(height: AppSizes.spacingSm),
              _AuditActivityCard(auditEntries: auditEntries),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final bool success = await ref
        .read(adminSystemNotifierProvider.notifier)
        .exportBackup();
    if (!mounted) {
      return;
    }
    final AdminSystemState state = ref.read(adminSystemNotifierProvider);
    final String message = success
        ? AppStrings.exportSuccess(state.lastExportResult?.filePath ?? '-')
        : (state.errorMessage ?? AppStrings.exportFailed);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return AppStrings.none;
    }
    return DateFormatter.formatDefault(value.toLocal());
  }

  String _formatMigrationLog(MigrationLogEntry entry) {
    final String timestamp = DateFormatter.formatDefault(
      entry.timestamp.toLocal(),
    );
    final String message = entry.message == null ? '' : ' · ${entry.message}';
    return '$timestamp · ${entry.step} · ${_migrationStatusLabel(entry.status)}$message';
  }

  String _migrationStatusLabel(MigrationLogStatus status) {
    return switch (status) {
      MigrationLogStatus.started => AppStrings.migrationStarted,
      MigrationLogStatus.succeeded => AppStrings.migrationSucceeded,
      MigrationLogStatus.failed => AppStrings.migrationFailed,
    };
  }
}

class _AuditActivityCard extends StatelessWidget {
  const _AuditActivityCard({required this.auditEntries});

  final AsyncValue<List<AuditLogRecord>> auditEntries;

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
            AppStrings.recentActivity,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          auditEntries.when(
            data: (List<AuditLogRecord> entries) {
              if (entries.isEmpty) {
                return Text(AppStrings.noAuditEntries);
              }
              return Column(
                children: entries
                    .take(12)
                    .map(
                      (AuditLogRecord entry) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppSizes.spacingSm,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 3,
                              child: Text(
                                entry.action,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${entry.entityType}:${entry.entityId}',
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Actor #${entry.actorUserId}',
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                DateFormatter.formatDefault(entry.createdAt),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (Object error, StackTrace stackTrace) =>
                Text(error.toString(), style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
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
    required this.lines,
    this.color = AppColors.textPrimary,
    this.footer,
  });

  final String title;
  final List<String> lines;
  final Color color;
  final Widget? footer;

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
          const SizedBox(height: AppSizes.spacingSm),
          for (final String line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacingXs),
              child: Text(line, style: TextStyle(color: color)),
            ),
          if (footer != null) ...<Widget>[
            const SizedBox(height: AppSizes.spacingSm),
            footer!,
          ],
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
  const _Banner({required this.message, required this.color});

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
