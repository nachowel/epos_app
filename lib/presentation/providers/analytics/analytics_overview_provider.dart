import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/providers/app_providers.dart';
import '../../../domain/models/analytics/analytics_date_range.dart';
import '../../../domain/models/analytics/overview_metrics.dart';
import '../auth_provider.dart';

class AnalyticsOverviewState {
  const AnalyticsOverviewState({
    required this.metrics,
    required this.selectedPreset,
    required this.range,
    required this.isLoading,
    required this.errorMessage,
  });

  factory AnalyticsOverviewState.initial() {
    return AnalyticsOverviewState(
      metrics: null,
      selectedPreset: AnalyticsDateRangePreset.thisWeek,
      range: AnalyticsDateRange.resolvePreset(
        preset: AnalyticsDateRangePreset.thisWeek,
        now: DateTime.now(),
      ),
      isLoading: false,
      errorMessage: null,
    );
  }

  final OverviewMetrics? metrics;
  final AnalyticsDateRangePreset selectedPreset;
  final AnalyticsDateRange range;
  final bool isLoading;
  final String? errorMessage;

  bool get hasLoaded => metrics != null;

  bool get isEmpty =>
      (metrics ?? const OverviewMetrics.empty()).hasData == false;

  AnalyticsOverviewState copyWith({
    Object? metrics = _unset,
    AnalyticsDateRangePreset? selectedPreset,
    AnalyticsDateRange? range,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AnalyticsOverviewState(
      metrics: metrics == _unset ? this.metrics : metrics as OverviewMetrics?,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      range: range ?? this.range,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AnalyticsOverviewNotifier extends StateNotifier<AnalyticsOverviewState> {
  AnalyticsOverviewNotifier(this._ref)
    : super(AnalyticsOverviewState.initial());

  final Ref _ref;

  Future<void> initialize({AnalyticsDateRangePreset? preset}) async {
    final AnalyticsDateRangePreset resolvedPreset =
        preset ?? state.selectedPreset;
    await loadForPreset(resolvedPreset);
  }

  Future<void> loadForPreset(AnalyticsDateRangePreset preset) async {
    final authState = _ref.read(authNotifierProvider);
    if (authState.currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    final AnalyticsDateRange range = AnalyticsDateRange.resolvePreset(
      preset: preset,
      now: DateTime.now(),
    );
    state = state.copyWith(
      selectedPreset: preset,
      range: range,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final OverviewMetrics metrics = await _ref
          .read(analyticsOverviewServiceProvider)
          .getOverviewMetrics(range);
      state = state.copyWith(
        metrics: metrics,
        selectedPreset: preset,
        range: range,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        selectedPreset: preset,
        range: range,
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'analytics_overview_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> refresh() async {
    await loadForPreset(state.selectedPreset);
  }
}

final StateNotifierProvider<AnalyticsOverviewNotifier, AnalyticsOverviewState>
analyticsOverviewNotifierProvider =
    StateNotifierProvider<AnalyticsOverviewNotifier, AnalyticsOverviewState>(
      (Ref ref) => AnalyticsOverviewNotifier(ref),
    );

String analyticsOverviewPresetQueryValue(AnalyticsDateRangePreset preset) {
  return analyticsDateRangePresetQueryValue(preset);
}

AnalyticsDateRangePreset analyticsOverviewPresetFromQuery(String? value) {
  return analyticsDateRangePresetFromQuery(value);
}

String analyticsOverviewPresetLabel(AnalyticsDateRangePreset preset) {
  return analyticsDateRangePresetLabel(preset);
}

const Object _unset = Object();
