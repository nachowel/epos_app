import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/providers/app_providers.dart';
import '../../../domain/models/analytics/analytics_revenue_preset.dart';
import '../../../domain/models/analytics/revenue_detail_summary.dart';
import '../auth_provider.dart';

class AnalyticsRevenueState {
  const AnalyticsRevenueState({
    required this.summary,
    required this.selectedPreset,
    required this.isLoading,
    required this.errorMessage,
  });

  factory AnalyticsRevenueState.initial() {
    return AnalyticsRevenueState(
      summary: null,
      selectedPreset: AnalyticsRevenuePreset.thisWeek,
      isLoading: false,
      errorMessage: null,
    );
  }

  final RevenueDetailSummary? summary;
  final AnalyticsRevenuePreset selectedPreset;
  final bool isLoading;
  final String? errorMessage;

  AnalyticsRevenueState copyWith({
    Object? summary = _unset,
    AnalyticsRevenuePreset? selectedPreset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AnalyticsRevenueState(
      summary: summary == _unset ? this.summary : summary as RevenueDetailSummary?,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AnalyticsRevenueNotifier extends StateNotifier<AnalyticsRevenueState> {
  AnalyticsRevenueNotifier(this._ref) : super(AnalyticsRevenueState.initial());

  final Ref _ref;

  Future<void> initialize({AnalyticsRevenuePreset? preset}) async {
    await loadForPreset(preset ?? state.selectedPreset);
  }

  Future<void> loadForPreset(AnalyticsRevenuePreset preset) async {
    final authState = _ref.read(authNotifierProvider);
    if (authState.currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    state = state.copyWith(
      selectedPreset: preset,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final RevenueDetailSummary summary = await _ref
          .read(analyticsRevenueServiceProvider)
          .getRevenueDetailSummary(preset: preset);
      state = state.copyWith(
        summary: summary,
        selectedPreset: preset,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        selectedPreset: preset,
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'analytics_revenue_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> refresh() async {
    await loadForPreset(state.selectedPreset);
  }
}

final StateNotifierProvider<AnalyticsRevenueNotifier, AnalyticsRevenueState>
analyticsRevenueNotifierProvider =
    StateNotifierProvider<AnalyticsRevenueNotifier, AnalyticsRevenueState>(
      (Ref ref) => AnalyticsRevenueNotifier(ref),
    );

const Object _unset = Object();
