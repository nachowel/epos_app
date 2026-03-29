import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/admin_dashboard_snapshot.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminDashboardState {
  const AdminDashboardState({
    required this.snapshot,
    required this.isLoading,
    required this.errorMessage,
  });

  const AdminDashboardState.initial()
    : snapshot = null,
      isLoading = false,
      errorMessage = null;

  final AdminDashboardSnapshot? snapshot;
  final bool isLoading;
  final String? errorMessage;

  AdminDashboardState copyWith({
    Object? snapshot = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AdminDashboardState(
      snapshot: snapshot == _unset
          ? this.snapshot
          : snapshot as AdminDashboardSnapshot?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminDashboardNotifier extends StateNotifier<AdminDashboardState> {
  AdminDashboardNotifier(this._ref)
    : super(const AdminDashboardState.initial());

  final Ref _ref;

  Future<void> load() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final AdminDashboardSnapshot snapshot = await _ref
          .read(adminServiceProvider)
          .getDashboardSnapshot(user: currentUser);
      state = state.copyWith(
        snapshot: snapshot,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_dashboard_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

final StateNotifierProvider<AdminDashboardNotifier, AdminDashboardState>
adminDashboardNotifierProvider =
    StateNotifierProvider<AdminDashboardNotifier, AdminDashboardState>(
      (Ref ref) => AdminDashboardNotifier(ref),
    );

const Object _unset = Object();
