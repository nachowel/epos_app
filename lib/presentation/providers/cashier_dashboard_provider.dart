import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/cashier_dashboard_snapshot.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class CashierDashboardState {
  const CashierDashboardState({
    required this.snapshot,
    required this.isLoading,
    required this.errorMessage,
  });

  const CashierDashboardState.initial()
    : snapshot = null,
      isLoading = false,
      errorMessage = null;

  final CashierDashboardSnapshot? snapshot;
  final bool isLoading;
  final String? errorMessage;

  CashierDashboardState copyWith({
    Object? snapshot = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return CashierDashboardState(
      snapshot: snapshot == _unset
          ? this.snapshot
          : snapshot as CashierDashboardSnapshot?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class CashierDashboardNotifier extends StateNotifier<CashierDashboardState> {
  CashierDashboardNotifier(this._ref)
    : super(const CashierDashboardState.initial());

  final Ref _ref;

  Future<void> load() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final CashierDashboardSnapshot snapshot = await _ref
          .read(cashierDashboardServiceProvider)
          .getSnapshot(user: currentUser);
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
          eventType: 'cashier_dashboard_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

final StateNotifierProvider<CashierDashboardNotifier, CashierDashboardState>
cashierDashboardNotifierProvider =
    StateNotifierProvider<CashierDashboardNotifier, CashierDashboardState>(
      (Ref ref) => CashierDashboardNotifier(ref),
    );

const Object _unset = Object();
