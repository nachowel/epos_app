import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/sync_monitor_snapshot.dart';
import '../../domain/models/sync_queue_item.dart';
import '../../domain/models/sync_runtime_state.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminSyncState {
  const AdminSyncState({
    required this.items,
    required this.pendingCount,
    required this.failedCount,
    required this.stuckCount,
    required this.syncEnabled,
    required this.isSupabaseConfigured,
    required this.supabaseConfigurationLabel,
    required this.supabaseConfigurationIssue,
    required this.lastSyncedAt,
    required this.lastError,
    required this.isOnline,
    required this.isWorkerRunning,
    required this.isLoading,
    required this.isRetrying,
    required this.errorMessage,
  });

  const AdminSyncState.initial()
    : items = const <SyncQueueItem>[],
      pendingCount = 0,
      failedCount = 0,
      stuckCount = 0,
      syncEnabled = true,
      isSupabaseConfigured = false,
      supabaseConfigurationLabel = 'Supabase config missing',
      supabaseConfigurationIssue = null,
      lastSyncedAt = null,
      lastError = null,
      isOnline = false,
      isWorkerRunning = false,
      isLoading = false,
      isRetrying = false,
      errorMessage = null;

  final List<SyncQueueItem> items;
  final int pendingCount;
  final int failedCount;
  final int stuckCount;
  final bool syncEnabled;
  final bool isSupabaseConfigured;
  final String supabaseConfigurationLabel;
  final String? supabaseConfigurationIssue;
  final DateTime? lastSyncedAt;
  final String? lastError;
  final bool isOnline;
  final bool isWorkerRunning;
  final bool isLoading;
  final bool isRetrying;
  final String? errorMessage;

  AdminSyncState copyWith({
    List<SyncQueueItem>? items,
    int? pendingCount,
    int? failedCount,
    int? stuckCount,
    bool? syncEnabled,
    bool? isSupabaseConfigured,
    String? supabaseConfigurationLabel,
    Object? supabaseConfigurationIssue = _unset,
    Object? lastSyncedAt = _unset,
    Object? lastError = _unset,
    bool? isOnline,
    bool? isWorkerRunning,
    bool? isLoading,
    bool? isRetrying,
    Object? errorMessage = _unset,
  }) {
    return AdminSyncState(
      items: items ?? this.items,
      pendingCount: pendingCount ?? this.pendingCount,
      failedCount: failedCount ?? this.failedCount,
      stuckCount: stuckCount ?? this.stuckCount,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      isSupabaseConfigured: isSupabaseConfigured ?? this.isSupabaseConfigured,
      supabaseConfigurationLabel:
          supabaseConfigurationLabel ?? this.supabaseConfigurationLabel,
      supabaseConfigurationIssue: supabaseConfigurationIssue == _unset
          ? this.supabaseConfigurationIssue
          : supabaseConfigurationIssue as String?,
      lastSyncedAt: lastSyncedAt == _unset
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      lastError: lastError == _unset ? this.lastError : lastError as String?,
      isOnline: isOnline ?? this.isOnline,
      isWorkerRunning: isWorkerRunning ?? this.isWorkerRunning,
      isLoading: isLoading ?? this.isLoading,
      isRetrying: isRetrying ?? this.isRetrying,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminSyncNotifier extends StateNotifier<AdminSyncState> {
  AdminSyncNotifier(this._ref) : super(const AdminSyncState.initial()) {
    _runtimeSubscription = _ref
        .read(syncWorkerProvider)
        .watchState()
        .listen(_handleRuntimeState);
  }

  final Ref _ref;
  StreamSubscription<SyncRuntimeState>? _runtimeSubscription;

  Future<void> load() async {
    if (!mounted) {
      return;
    }
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      if (mounted) {
        state = state.copyWith(errorMessage: AppStrings.accessDenied);
      }
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final SyncRuntimeState runtimeState = _ref
          .read(syncWorkerProvider)
          .currentState;
      final SyncMonitorSnapshot snapshot = await _ref
          .read(adminServiceProvider)
          .getSyncMonitorSnapshot(
            user: currentUser,
            runtimeState: runtimeState,
          );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        items: snapshot.items,
        pendingCount: snapshot.pendingCount,
        failedCount: snapshot.failedCount,
        stuckCount: snapshot.stuckCount,
        syncEnabled: snapshot.syncEnabled,
        isSupabaseConfigured: snapshot.isSupabaseConfigured,
        supabaseConfigurationLabel: snapshot.supabaseConfigurationLabel,
        supabaseConfigurationIssue: snapshot.supabaseConfigurationIssue,
        lastSyncedAt: snapshot.lastSyncedAt,
        lastError: snapshot.lastError,
        isOnline: snapshot.isOnline,
        isWorkerRunning: snapshot.isRunning,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: ErrorMapper.toUserMessageAndLog(
            error,
            logger: _ref.read(appLoggerProvider),
            eventType: 'admin_sync_load_failed',
            stackTrace: stackTrace,
          ),
        );
      }
    }
  }

  Future<bool> retryItem(int itemId) async {
    if (!mounted) {
      return false;
    }
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      if (mounted) {
        state = state.copyWith(errorMessage: AppStrings.accessDenied);
      }
      return false;
    }

    state = state.copyWith(isRetrying: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .retrySyncItem(user: currentUser, itemId: itemId);
      await _ref.read(syncWorkerProvider).runOnce();
      await load();
      if (!mounted) {
        return false;
      }
      state = state.copyWith(isRetrying: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(
          isRetrying: false,
          errorMessage: ErrorMapper.toUserMessageAndLog(
            error,
            logger: _ref.read(appLoggerProvider),
            eventType: 'admin_sync_retry_item_failed',
            stackTrace: stackTrace,
          ),
        );
      }
      return false;
    }
  }

  Future<bool> retryAll() async {
    if (!mounted) {
      return false;
    }
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      if (mounted) {
        state = state.copyWith(errorMessage: AppStrings.accessDenied);
      }
      return false;
    }

    state = state.copyWith(isRetrying: true, errorMessage: null);
    try {
      await _ref
          .read(adminServiceProvider)
          .retryAllSyncItems(user: currentUser);
      await _ref.read(syncWorkerProvider).runOnce();
      await load();
      if (!mounted) {
        return false;
      }
      state = state.copyWith(isRetrying: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      if (mounted) {
        state = state.copyWith(
          isRetrying: false,
          errorMessage: ErrorMapper.toUserMessageAndLog(
            error,
            logger: _ref.read(appLoggerProvider),
            eventType: 'admin_sync_retry_all_failed',
            stackTrace: stackTrace,
          ),
        );
      }
      return false;
    }
  }

  void _handleRuntimeState(SyncRuntimeState runtimeState) {
    if (!mounted) {
      return;
    }
    state = state.copyWith(
      isOnline: runtimeState.isOnline,
      isWorkerRunning: runtimeState.isRunning,
      errorMessage: runtimeState.lastRuntimeError ?? state.errorMessage,
    );
    unawaited(load());
  }

  @override
  void dispose() {
    unawaited(_runtimeSubscription?.cancel());
    super.dispose();
  }
}

final StateNotifierProvider<AdminSyncNotifier, AdminSyncState>
adminSyncNotifierProvider =
    StateNotifierProvider<AdminSyncNotifier, AdminSyncState>(
      (Ref ref) => AdminSyncNotifier(ref),
    );

const Object _unset = Object();
