import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/audit_log_record.dart';
import '../../providers/admin_audit_provider.dart';
import 'widgets/admin_scaffold.dart';

const String _auditLogsTitle = 'Audit Logs';
const String _auditLogsInfo =
    'Read-only audit trail for business-critical operational actions only.';
const String _actorFilterLabel = 'Actor';
const String _actionFilterLabel = 'Action';
const String _entityTypeFilterLabel = 'Entity Type';
const String _allFilterLabel = 'All';
const String _noAuditLogs = 'No audit logs match the current filters.';

class AdminAuditLogsScreen extends ConsumerStatefulWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  ConsumerState<AdminAuditLogsScreen> createState() =>
      _AdminAuditLogsScreenState();
}

class _AdminAuditLogsScreenState extends ConsumerState<AdminAuditLogsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminAuditNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminAuditState state = ref.watch(adminAuditNotifierProvider);

    return AdminScaffold(
      title: _auditLogsTitle,
      currentRoute: '/admin/audit',
      child: RefreshIndicator(
        onRefresh: () => ref.read(adminAuditNotifierProvider.notifier).load(),
        child: ListView(
          children: <Widget>[
            if (state.errorMessage != null)
              _Banner(message: state.errorMessage!, color: AppColors.error),
            const _Banner(message: _auditLogsInfo, color: AppColors.primary),
            _FilterBar(state: state),
            const SizedBox(height: AppSizes.spacingMd),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSizes.spacingXl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.logs.isEmpty)
              const _EmptyState(message: _noAuditLogs)
            else
              ...state.logs.map(
                (AuditLogRecord entry) => _AuditLogTile(entry: entry),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.state});

  final AdminAuditState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AdminAuditNotifier notifier = ref.read(
      adminAuditNotifierProvider.notifier,
    );

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: AppSizes.spacingMd,
        runSpacing: AppSizes.spacingMd,
        children: <Widget>[
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<int?>(
              value: state.actorFilter,
              decoration: const InputDecoration(labelText: _actorFilterLabel),
              items: <DropdownMenuItem<int?>>[
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text(_allFilterLabel),
                ),
                ...state.availableActorIds.map(
                  (int actorUserId) => DropdownMenuItem<int?>(
                    value: actorUserId,
                    child: Text('Actor #$actorUserId'),
                  ),
                ),
              ],
              onChanged: (int? value) {
                notifier.setActorFilter(value);
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              value: state.actionFilter,
              decoration: const InputDecoration(labelText: _actionFilterLabel),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(_allFilterLabel),
                ),
                ...state.availableActions.map(
                  (String action) => DropdownMenuItem<String?>(
                    value: action,
                    child: Text(action),
                  ),
                ),
              ],
              onChanged: (String? value) {
                notifier.setActionFilter(value);
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String?>(
              value: state.entityTypeFilter,
              decoration: const InputDecoration(
                labelText: _entityTypeFilterLabel,
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text(_allFilterLabel),
                ),
                ...state.availableEntityTypes.map(
                  (String entityType) => DropdownMenuItem<String?>(
                    value: entityType,
                    child: Text(entityType),
                  ),
                ),
              ],
              onChanged: (String? value) {
                notifier.setEntityTypeFilter(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  const _AuditLogTile({required this.entry});

  final AuditLogRecord entry;

  @override
  Widget build(BuildContext context) {
    final String metadataPreview = entry.metadataJson.length > 140
        ? '${entry.metadataJson.substring(0, 140)}...'
        : entry.metadataJson;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: ListTile(
        title: Wrap(
          spacing: AppSizes.spacingSm,
          runSpacing: AppSizes.spacingXs,
          children: <Widget>[
            _Tag(label: entry.action, color: AppColors.primary),
            _Tag(label: entry.entityType, color: AppColors.textSecondary),
            _Tag(
              label: 'Actor #${entry.actorUserId}',
              color: AppColors.success,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSizes.spacingSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Entity ID: ${entry.entityId}'),
              const SizedBox(height: AppSizes.spacingXs),
              Text(DateFormatter.formatDefault(entry.createdAt.toLocal())),
              const SizedBox(height: AppSizes.spacingXs),
              Text(
                metadataPreview,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

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
      child: Text(label, style: TextStyle(color: color)),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}
