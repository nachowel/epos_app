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
const double _filterFieldMaxWidth = 220;

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
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double fieldWidth = constraints.maxWidth < _filterFieldMaxWidth
              ? constraints.maxWidth
              : _filterFieldMaxWidth;
          return Wrap(
            spacing: AppSizes.spacingMd,
            runSpacing: AppSizes.spacingMd,
            children: <Widget>[
              SizedBox(
                width: fieldWidth,
                child: _AuditFilterDropdown<int?>(
                  value: state.actorFilter,
                  label: _actorFilterLabel,
                  items: <({int? value, String label})>[
                    (value: null, label: _allFilterLabel),
                    ...state.availableActorIds.map(
                      (int actorUserId) =>
                          (value: actorUserId, label: 'Actor #$actorUserId'),
                    ),
                  ],
                  onChanged: notifier.setActorFilter,
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: _AuditFilterDropdown<String?>(
                  value: state.actionFilter,
                  label: _actionFilterLabel,
                  items: <({String? value, String label})>[
                    (value: null, label: _allFilterLabel),
                    ...state.availableActions.map(
                      (String action) => (value: action, label: action),
                    ),
                  ],
                  onChanged: notifier.setActionFilter,
                ),
              ),
              SizedBox(
                width: fieldWidth,
                child: _AuditFilterDropdown<String?>(
                  value: state.entityTypeFilter,
                  label: _entityTypeFilterLabel,
                  items: <({String? value, String label})>[
                    (value: null, label: _allFilterLabel),
                    ...state.availableEntityTypes.map(
                      (String entityType) =>
                          (value: entityType, label: entityType),
                    ),
                  ],
                  onChanged: notifier.setEntityTypeFilter,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AuditFilterDropdown<T> extends StatelessWidget {
  const _AuditFilterDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String label;
  final List<({T value, String label})> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacingSm,
          vertical: AppSizes.spacingSm,
        ),
      ),
      selectedItemBuilder: (BuildContext context) {
        return items
            .map(
              (({T value, String label}) item) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false);
      },
      items: items
          .map(
            (({T value, String label}) item) => DropdownMenuItem<T>(
              value: item.value,
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
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
