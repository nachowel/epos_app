import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/database_export_result.dart';
import '../../domain/models/system_health_snapshot.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminSystemState {
  const AdminSystemState({
    required this.snapshot,
    required this.isLoading,
    required this.isExporting,
    required this.errorMessage,
    required this.lastExportResult,
  });

  const AdminSystemState.initial()
    : snapshot = null,
      isLoading = false,
      isExporting = false,
      errorMessage = null,
      lastExportResult = null;

  final SystemHealthSnapshot? snapshot;
  final bool isLoading;
  final bool isExporting;
  final String? errorMessage;
  final DatabaseExportResult? lastExportResult;

  AdminSystemState copyWith({
    Object? snapshot = _unset,
    bool? isLoading,
    bool? isExporting,
    Object? errorMessage = _unset,
    Object? lastExportResult = _unset,
  }) {
    return AdminSystemState(
      snapshot: snapshot == _unset
          ? this.snapshot
          : snapshot as SystemHealthSnapshot?,
      isLoading: isLoading ?? this.isLoading,
      isExporting: isExporting ?? this.isExporting,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      lastExportResult: lastExportResult == _unset
          ? this.lastExportResult
          : lastExportResult as DatabaseExportResult?,
    );
  }
}

class AdminSystemNotifier extends StateNotifier<AdminSystemState> {
  AdminSystemNotifier(this._ref) : super(const AdminSystemState.initial());

  final Ref _ref;

  Future<void> load() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: 'Oturum bulunamadı.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final SystemHealthSnapshot snapshot = await _ref
          .read(adminServiceProvider)
          .getSystemHealthSnapshot(
            user: currentUser,
            runtimeState: _ref.read(syncWorkerProvider).currentState,
          );
      state = state.copyWith(
        snapshot: snapshot,
        isLoading: false,
        errorMessage: null,
        lastExportResult: snapshot.lastBackup,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_system_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<bool> exportBackup() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: 'Oturum bulunamadı.');
      return false;
    }

    state = state.copyWith(isExporting: true, errorMessage: null);
    try {
      final DatabaseExportResult result = await _ref
          .read(adminServiceProvider)
          .exportLocalDatabase(user: currentUser);
      await load();
      state = state.copyWith(
        isExporting: false,
        lastExportResult: result,
        errorMessage: null,
      );
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isExporting: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_backup_export_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }
}

final StateNotifierProvider<AdminSystemNotifier, AdminSystemState>
adminSystemNotifierProvider =
    StateNotifierProvider<AdminSystemNotifier, AdminSystemState>(
      (Ref ref) => AdminSystemNotifier(ref),
    );

const Object _unset = Object();
