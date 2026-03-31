import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/revenue_summary.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminRevenueAnalyticsState {
  const AdminRevenueAnalyticsState({
    required this.summary,
    required this.isLoading,
    required this.errorMessage,
  });

  const AdminRevenueAnalyticsState.initial()
    : summary = null,
      isLoading = false,
      errorMessage = null;

  final RevenueSummary? summary;
  final bool isLoading;
  final String? errorMessage;

  AdminRevenueAnalyticsState copyWith({
    Object? summary = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AdminRevenueAnalyticsState(
      summary: summary == _unset ? this.summary : summary as RevenueSummary?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AdminRevenueAnalyticsNotifier
    extends StateNotifier<AdminRevenueAnalyticsState> {
  AdminRevenueAnalyticsNotifier(this._ref)
    : super(const AdminRevenueAnalyticsState.initial());

  final Ref _ref;

  Future<void> load() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final RevenueSummary summary = await _ref
          .read(revenueAnalyticsServiceProvider)
          .getRevenueSummary(user: currentUser);
      state = state.copyWith(
        summary: summary,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_revenue_analytics_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }
}

final StateNotifierProvider<
  AdminRevenueAnalyticsNotifier,
  AdminRevenueAnalyticsState
>
adminRevenueAnalyticsNotifierProvider =
    StateNotifierProvider<
      AdminRevenueAnalyticsNotifier,
      AdminRevenueAnalyticsState
    >((Ref ref) => AdminRevenueAnalyticsNotifier(ref));

const Object _unset = Object();
