import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/audit_log_record.dart';
import '../../domain/models/authorization_policy.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

final FutureProvider<List<AuditLogRecord>> recentAuditLogProvider =
    FutureProvider<List<AuditLogRecord>>((Ref ref) async {
      final User? currentUser = ref.read(authNotifierProvider).currentUser;
      if (currentUser == null) {
        throw StateError('Current user is required to load audit logs.');
      }
      AuthorizationPolicy.ensureAllowed(
        currentUser,
        OperatorPermission.viewAuditLog,
      );
      return ref.read(auditLogRepositoryProvider).listAuditLogs(limit: 100);
    });

class AdminAuditState {
  const AdminAuditState({
    required this.logs,
    required this.actorFilter,
    required this.actionFilter,
    required this.entityTypeFilter,
    required this.availableActorIds,
    required this.availableActions,
    required this.availableEntityTypes,
    required this.isLoading,
    required this.errorMessage,
  });

  const AdminAuditState.initial()
    : logs = const <AuditLogRecord>[],
      actorFilter = null,
      actionFilter = null,
      entityTypeFilter = null,
      availableActorIds = const <int>[],
      availableActions = const <String>[],
      availableEntityTypes = const <String>[],
      isLoading = false,
      errorMessage = null;

  final List<AuditLogRecord> logs;
  final int? actorFilter;
  final String? actionFilter;
  final String? entityTypeFilter;
  final List<int> availableActorIds;
  final List<String> availableActions;
  final List<String> availableEntityTypes;
  final bool isLoading;
  final String? errorMessage;

  AdminAuditState copyWith({
    List<AuditLogRecord>? logs,
    Object? actorFilter = _unset,
    Object? actionFilter = _unset,
    Object? entityTypeFilter = _unset,
    List<int>? availableActorIds,
    List<String>? availableActions,
    List<String>? availableEntityTypes,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AdminAuditState(
      logs: logs ?? this.logs,
      actorFilter: actorFilter == _unset ? this.actorFilter : actorFilter as int?,
      actionFilter: actionFilter == _unset
          ? this.actionFilter
          : actionFilter as String?,
      entityTypeFilter: entityTypeFilter == _unset
          ? this.entityTypeFilter
          : entityTypeFilter as String?,
      availableActorIds: availableActorIds ?? this.availableActorIds,
      availableActions: availableActions ?? this.availableActions,
      availableEntityTypes: availableEntityTypes ?? this.availableEntityTypes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminAuditNotifier extends StateNotifier<AdminAuditState> {
  AdminAuditNotifier(this._ref) : super(const AdminAuditState.initial());

  final Ref _ref;

  Future<void> load() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      AuthorizationPolicy.ensureAllowed(
        currentUser,
        OperatorPermission.viewAuditLog,
      );
      final repository = _ref.read(auditLogRepositoryProvider);
      final List<AuditLogRecord> allLogs = await repository.listAuditLogs(
        limit: 200,
      );
      final List<AuditLogRecord> filteredLogs = await repository.listAuditLogs(
        limit: 200,
        actorUserId: state.actorFilter,
        action: state.actionFilter,
        entityType: state.entityTypeFilter,
      );

      state = state.copyWith(
        logs: filteredLogs,
        availableActorIds: allLogs
            .map((AuditLogRecord entry) => entry.actorUserId)
            .toSet()
            .toList()
          ..sort(),
        availableActions: allLogs
            .map((AuditLogRecord entry) => entry.action)
            .toSet()
            .toList()
          ..sort(),
        availableEntityTypes: allLogs
            .map((AuditLogRecord entry) => entry.entityType)
            .toSet()
            .toList()
          ..sort(),
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_audit_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> setActorFilter(int? actorUserId) async {
    state = state.copyWith(actorFilter: actorUserId);
    await load();
  }

  Future<void> setActionFilter(String? action) async {
    state = state.copyWith(actionFilter: _normalizeFilter(action));
    await load();
  }

  Future<void> setEntityTypeFilter(String? entityType) async {
    state = state.copyWith(entityTypeFilter: _normalizeFilter(entityType));
    await load();
  }

  String? _normalizeFilter(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

final StateNotifierProvider<AdminAuditNotifier, AdminAuditState>
adminAuditNotifierProvider =
    StateNotifierProvider<AdminAuditNotifier, AdminAuditState>(
      (Ref ref) => AdminAuditNotifier(ref),
    );

const Object _unset = Object();
