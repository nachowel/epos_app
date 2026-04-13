import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/providers/app_providers.dart';
import '../../../domain/models/analytics/analytics_date_range.dart';
import '../../../domain/models/analytics/payment_split_summary.dart';
import '../auth_provider.dart';

class AnalyticsPaymentsState {
  const AnalyticsPaymentsState({
    required this.summary,
    required this.selectedPreset,
    required this.range,
    required this.isLoading,
    required this.errorMessage,
  });

  factory AnalyticsPaymentsState.initial() {
    return AnalyticsPaymentsState(
      summary: null,
      selectedPreset: AnalyticsDateRangePreset.thisWeek,
      range: AnalyticsDateRange.resolvePreset(
        preset: AnalyticsDateRangePreset.thisWeek,
        now: DateTime.now(),
      ),
      isLoading: false,
      errorMessage: null,
    );
  }

  final PaymentSplitSummary? summary;
  final AnalyticsDateRangePreset selectedPreset;
  final AnalyticsDateRange range;
  final bool isLoading;
  final String? errorMessage;

  bool get isEmpty =>
      (summary ?? const PaymentSplitSummary.empty()).totalRevenueMinor == 0 &&
      (summary ?? const PaymentSplitSummary.empty()).cashOrderCount == 0 &&
      (summary ?? const PaymentSplitSummary.empty()).cardOrderCount == 0;

  AnalyticsPaymentsState copyWith({
    Object? summary = _unset,
    AnalyticsDateRangePreset? selectedPreset,
    AnalyticsDateRange? range,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AnalyticsPaymentsState(
      summary: summary == _unset ? this.summary : summary as PaymentSplitSummary?,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      range: range ?? this.range,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AnalyticsPaymentsNotifier extends StateNotifier<AnalyticsPaymentsState> {
  AnalyticsPaymentsNotifier(this._ref)
    : super(AnalyticsPaymentsState.initial());

  final Ref _ref;

  Future<void> initialize({AnalyticsDateRangePreset? preset}) async {
    await loadForPreset(preset ?? state.selectedPreset);
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
      final PaymentSplitSummary summary = await _ref
          .read(analyticsPaymentsServiceProvider)
          .getPaymentSplitSummary(range);
      state = state.copyWith(
        summary: summary,
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
          eventType: 'analytics_payments_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> refresh() async {
    await loadForPreset(state.selectedPreset);
  }
}

final StateNotifierProvider<AnalyticsPaymentsNotifier, AnalyticsPaymentsState>
analyticsPaymentsNotifierProvider =
    StateNotifierProvider<AnalyticsPaymentsNotifier, AnalyticsPaymentsState>(
      (Ref ref) => AnalyticsPaymentsNotifier(ref),
    );

const Object _unset = Object();
