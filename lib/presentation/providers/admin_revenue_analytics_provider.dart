import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/analytics/analytics_export.dart';
import '../../domain/models/analytics/analytics_period.dart';
import '../../domain/models/analytics/saved_analytics_view.dart';
import '../../domain/models/revenue_summary.dart';
import '../../domain/models/semantic_sales_analytics.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';

class AdminRevenueAnalyticsState {
  const AdminRevenueAnalyticsState({
    required this.summary,
    required this.isLoading,
    required this.errorMessage,
    required this.periodSelection,
    required this.savedViews,
    required this.selectedSavedViewId,
    required this.lastExport,
    required this.isPrintViewOpen,
  });

  const AdminRevenueAnalyticsState.initial()
    : summary = null,
      isLoading = false,
      errorMessage = null,
      periodSelection = const AnalyticsPeriodSelection.preset(
        AnalyticsPresetPeriod.thisWeek,
      ),
      savedViews = const <SavedAnalyticsView>[],
      selectedSavedViewId = null,
      lastExport = null,
      isPrintViewOpen = false;

  final RevenueSummary? summary;
  final bool isLoading;
  final String? errorMessage;
  final AnalyticsPeriodSelection periodSelection;
  final List<SavedAnalyticsView> savedViews;
  final String? selectedSavedViewId;
  final AnalyticsExport? lastExport;
  final bool isPrintViewOpen;

  AdminRevenueAnalyticsState copyWith({
    Object? summary = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
    AnalyticsPeriodSelection? periodSelection,
    List<SavedAnalyticsView>? savedViews,
    Object? selectedSavedViewId = _unset,
    Object? lastExport = _unset,
    bool? isPrintViewOpen,
  }) {
    return AdminRevenueAnalyticsState(
      summary: summary == _unset ? this.summary : summary as RevenueSummary?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      periodSelection: periodSelection ?? this.periodSelection,
      savedViews: savedViews ?? this.savedViews,
      selectedSavedViewId: selectedSavedViewId == _unset
          ? this.selectedSavedViewId
          : selectedSavedViewId as String?,
      lastExport: lastExport == _unset
          ? this.lastExport
          : lastExport as AnalyticsExport?,
      isPrintViewOpen: isPrintViewOpen ?? this.isPrintViewOpen,
    );
  }
}

class AdminRevenueAnalyticsNotifier
    extends StateNotifier<AdminRevenueAnalyticsState> {
  AdminRevenueAnalyticsNotifier(this._ref)
    : _uuid = const Uuid(),
      super(const AdminRevenueAnalyticsState.initial());

  final Ref _ref;
  final Uuid _uuid;

  Future<void> initialize({AnalyticsPeriodSelection? selection}) async {
    await loadSavedViews();
    await ensurePeriodSelection(selection ?? state.periodSelection);
  }

  Future<void> load({AnalyticsPeriodSelection? selection}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    final AnalyticsPeriodSelection effectiveSelection =
        selection ?? state.periodSelection;
    if (currentUser == null) {
      state = state.copyWith(
        errorMessage: AppStrings.accessDenied,
        periodSelection: effectiveSelection,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      periodSelection: effectiveSelection,
    );
    try {
      final RevenueSummary summary = await _ref
          .read(revenueAnalyticsServiceProvider)
          .getRevenueSummary(
            user: currentUser,
            periodSelection: effectiveSelection,
          );
      SemanticSalesAnalytics semanticSalesAnalytics =
          const SemanticSalesAnalytics.empty();
      String? semanticAnalyticsWarning;
      try {
        semanticSalesAnalytics = await _ref
            .read(reportServiceProvider)
            .getSemanticSalesAnalyticsForPeriod(
              user: currentUser,
              periodSelection: effectiveSelection,
            );
      } catch (error, stackTrace) {
        semanticAnalyticsWarning = ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_semantic_analytics_load_failed',
          stackTrace: stackTrace,
        );
      }
      state = state.copyWith(
        summary: _summaryWithSemanticAnalytics(summary, semanticSalesAnalytics),
        isLoading: false,
        errorMessage: semanticAnalyticsWarning,
        periodSelection: effectiveSelection,
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
        periodSelection: effectiveSelection,
      );
    }
  }

  Future<void> loadSavedViews() async {
    final List<SavedAnalyticsView> savedViews = await _ref
        .read(savedAnalyticsViewStoreProvider)
        .readAll();
    state = state.copyWith(savedViews: savedViews);
  }

  Future<void> setPeriodSelection(AnalyticsPeriodSelection selection) async {
    if (selection == state.periodSelection && state.summary != null) {
      return;
    }
    state = state.copyWith(selectedSavedViewId: null);
    await load(selection: selection);
  }

  Future<void> ensurePeriodSelection(AnalyticsPeriodSelection selection) async {
    if (selection == state.periodSelection && state.summary != null) {
      return;
    }
    state = state.copyWith(periodSelection: selection);
    await load(selection: selection);
  }

  Future<SavedAnalyticsView> saveCurrentView({
    required String name,
    required AnalyticsComparisonMode comparisonMode,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final SavedAnalyticsView view = SavedAnalyticsView.create(
      id: _uuid.v4(),
      name: name,
      periodSelection: state.periodSelection,
      comparisonMode: comparisonMode,
      createdAt: now,
    );
    final List<SavedAnalyticsView> savedViews = await _ref
        .read(savedAnalyticsViewStoreProvider)
        .save(view);
    state = state.copyWith(
      savedViews: savedViews,
      selectedSavedViewId: view.id,
    );
    return view;
  }

  Future<SavedAnalyticsView?> applySavedView(String id) async {
    final SavedAnalyticsView? view = state.savedViews
        .cast<SavedAnalyticsView?>()
        .firstWhere(
          (SavedAnalyticsView? item) => item?.id == id,
          orElse: () => null,
        );
    if (view == null) {
      state = state.copyWith(selectedSavedViewId: null);
      return null;
    }
    state = state.copyWith(selectedSavedViewId: id);
    await load(selection: view.periodSelection);
    return view;
  }

  Future<void> deleteSavedView(String id) async {
    final List<SavedAnalyticsView> savedViews = await _ref
        .read(savedAnalyticsViewStoreProvider)
        .delete(id);
    state = state.copyWith(
      savedViews: savedViews,
      selectedSavedViewId: state.selectedSavedViewId == id
          ? null
          : state.selectedSavedViewId,
    );
  }

  void clearSelectedSavedView() {
    if (state.selectedSavedViewId == null) {
      return;
    }
    state = state.copyWith(selectedSavedViewId: null);
  }

  void setLastExport(AnalyticsExport export) {
    state = state.copyWith(lastExport: export);
  }

  void setPrintViewOpen(bool value) {
    state = state.copyWith(isPrintViewOpen: value);
  }

  RevenueSummary _summaryWithSemanticAnalytics(
    RevenueSummary summary,
    SemanticSalesAnalytics analytics,
  ) {
    return RevenueSummary(
      generatedAt: summary.generatedAt,
      timezone: summary.timezone,
      todayRevenue: summary.todayRevenue,
      thisWeekRevenue: summary.thisWeekRevenue,
      thisMonthRevenue: summary.thisMonthRevenue,
      averageOrderValueCurrentWeek: summary.averageOrderValueCurrentWeek,
      dailyTrend: summary.dailyTrend,
      weeklySummary: summary.weeklySummary,
      hourlyDistribution: summary.hourlyDistribution,
      insights: summary.insights,
      intelligenceInputs: summary.intelligenceInputs,
      selectedPeriodSummary: summary.selectedPeriodSummary,
      semanticSalesAnalytics: analytics,
    );
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
