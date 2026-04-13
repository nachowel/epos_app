import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/providers/app_providers.dart';
import '../../../domain/models/analytics/analytics_date_range.dart';
import '../../../domain/models/analytics/category_product_analytics_section.dart';
import '../auth_provider.dart';

class AnalyticsProductsState {
  const AnalyticsProductsState({
    required this.sections,
    required this.selectedPreset,
    required this.range,
    required this.isLoading,
    required this.errorMessage,
  });

  factory AnalyticsProductsState.initial() {
    return AnalyticsProductsState(
      sections: null,
      selectedPreset: AnalyticsDateRangePreset.thisWeek,
      range: AnalyticsDateRange.resolvePreset(
        preset: AnalyticsDateRangePreset.thisWeek,
        now: DateTime.now(),
      ),
      isLoading: false,
      errorMessage: null,
    );
  }

  final List<CategoryProductAnalyticsSection>? sections;
  final AnalyticsDateRangePreset selectedPreset;
  final AnalyticsDateRange range;
  final bool isLoading;
  final String? errorMessage;

  bool get isEmpty =>
      (sections ?? const <CategoryProductAnalyticsSection>[]).isEmpty;

  AnalyticsProductsState copyWith({
    Object? sections = _unset,
    AnalyticsDateRangePreset? selectedPreset,
    AnalyticsDateRange? range,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AnalyticsProductsState(
      sections: sections == _unset
          ? this.sections
          : sections as List<CategoryProductAnalyticsSection>?,
      selectedPreset: selectedPreset ?? this.selectedPreset,
      range: range ?? this.range,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AnalyticsProductsNotifier extends StateNotifier<AnalyticsProductsState> {
  AnalyticsProductsNotifier(this._ref)
    : super(AnalyticsProductsState.initial());

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
      final List<CategoryProductAnalyticsSection> sections = await _ref
          .read(analyticsProductsServiceProvider)
          .getCategoryProductSections(range);
      state = state.copyWith(
        sections: sections,
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
          eventType: 'analytics_products_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> refresh() async {
    await loadForPreset(state.selectedPreset);
  }
}

final StateNotifierProvider<AnalyticsProductsNotifier, AnalyticsProductsState>
analyticsProductsNotifierProvider =
    StateNotifierProvider<AnalyticsProductsNotifier, AnalyticsProductsState>(
      (Ref ref) => AnalyticsProductsNotifier(ref),
    );

const Object _unset = Object();
