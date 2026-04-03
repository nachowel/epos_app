import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/analytics/analytics_export.dart';
import '../../../domain/models/analytics/analytics_period.dart';
import '../../../domain/models/analytics/analytics_snapshot.dart';
import '../../../domain/models/analytics/insight.dart';
import '../../../domain/models/analytics/saved_analytics_view.dart';
import '../../../domain/models/revenue_summary.dart';
import '../../providers/admin_revenue_analytics_provider.dart';
import 'widgets/admin_analytics_print_view.dart';
import 'widgets/admin_revenue_analytics_dashboard.dart';
import 'widgets/admin_scaffold.dart';

const String _analyticsTitle = 'Revenue Analytics';

class AdminRevenueAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminRevenueAnalyticsScreen({
    required this.initialPeriodSelection,
    required this.initialComparisonMode,
    this.initialInsightCode,
    this.initialTrendDate,
    this.initialDaypart,
    this.initialMoverId,
    super.key,
  });

  final AnalyticsPeriodSelection initialPeriodSelection;
  final AnalyticsComparisonMode initialComparisonMode;
  final String? initialInsightCode;
  final DateTime? initialTrendDate;
  final String? initialDaypart;
  final String? initialMoverId;

  @override
  ConsumerState<AdminRevenueAnalyticsScreen> createState() =>
      _AdminRevenueAnalyticsScreenState();
}

class _AdminRevenueAnalyticsScreenState
    extends ConsumerState<AdminRevenueAnalyticsScreen> {
  late AnalyticsComparisonMode _comparisonMode;
  String? _selectedInsightCode;
  DateTime? _selectedTrendDate;
  String? _selectedDaypart;
  String? _selectedMoverId;

  @override
  void initState() {
    super.initState();
    _comparisonMode = widget.initialComparisonMode;
    _selectedInsightCode = widget.initialInsightCode;
    _selectedTrendDate = widget.initialTrendDate;
    _selectedDaypart = widget.initialDaypart;
    _selectedMoverId = widget.initialMoverId;
    Future<void>.microtask(
      () => ref
          .read(adminRevenueAnalyticsNotifierProvider.notifier)
          .initialize(selection: widget.initialPeriodSelection),
    );
  }

  @override
  void didUpdateWidget(covariant AdminRevenueAnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialComparisonMode != widget.initialComparisonMode) {
      _comparisonMode = widget.initialComparisonMode;
    }
    if (oldWidget.initialInsightCode != widget.initialInsightCode) {
      _selectedInsightCode = widget.initialInsightCode;
    }
    if (oldWidget.initialTrendDate != widget.initialTrendDate) {
      _selectedTrendDate = widget.initialTrendDate;
    }
    if (oldWidget.initialDaypart != widget.initialDaypart) {
      _selectedDaypart = widget.initialDaypart;
    }
    if (oldWidget.initialMoverId != widget.initialMoverId) {
      _selectedMoverId = widget.initialMoverId;
    }
    if (oldWidget.initialPeriodSelection != widget.initialPeriodSelection) {
      Future<void>.microtask(
        () => ref
            .read(adminRevenueAnalyticsNotifierProvider.notifier)
            .ensurePeriodSelection(widget.initialPeriodSelection),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminRevenueAnalyticsState state = ref.watch(
      adminRevenueAnalyticsNotifierProvider,
    );
    final RevenueSummary? summary = state.summary;
    final AdminRevenueAnalyticsNotifier notifier = ref.read(
      adminRevenueAnalyticsNotifierProvider.notifier,
    );

    final Widget content = switch ((
      summary,
      state.errorMessage,
      state.isLoading,
    )) {
      (null, final String message?, _) => AdminRevenueAnalyticsErrorView(
        message: message,
        onRetry: () => notifier.load(),
      ),
      (null, _, _) => const AdminRevenueAnalyticsLoadingView(),
      (final RevenueSummary loaded, _, _)
          when !loaded.hasPaidData && loaded.semanticSalesAnalytics.isEmpty =>
        AdminRevenueAnalyticsEmptyView(statusMessage: state.errorMessage),
      (final RevenueSummary loaded, _, final bool isLoading) =>
        AdminRevenueAnalyticsDashboard(
          summary: loaded,
          periodSelection: state.periodSelection,
          comparisonMode: _comparisonMode,
          savedViews: state.savedViews,
          selectedSavedViewId: state.selectedSavedViewId,
          selectedInsightCode: _selectedInsightCode,
          selectedTrendDate: _selectedTrendDate,
          selectedDaypart: _selectedDaypart,
          selectedMoverId: _selectedMoverId,
          statusMessage: state.errorMessage,
          isRefreshing: isLoading,
          onPeriodSelected: _handlePresetSelected,
          onCustomPeriodRequested: () => _handleCustomPeriodSelected(context),
          onComparisonModeSelected: _handleComparisonModeSelected,
          onSaveViewRequested: () =>
              _showSaveViewDialog(context: context, notifier: notifier),
          onSavedViewsRequested: () => _showSavedViewsSheet(
            context: context,
            notifier: notifier,
            savedViews: state.savedViews,
            selectedSavedViewId: state.selectedSavedViewId,
          ),
          onCopyShareLink: () => _copyShareLink(
            context: context,
            periodSelection: state.periodSelection,
            comparisonMode: _comparisonMode,
          ),
          onInsightSelected: _handleInsightSelected,
          onTrendDateSelected: _handleTrendDateSelected,
          onDaypartSelected: _handleDaypartSelected,
          onMoverSelected: _handleMoverSelected,
          onCopySnapshot: () => _copySnapshot(
            context: context,
            summary: loaded,
            periodSelection: state.periodSelection,
            notifier: notifier,
          ),
          onPreviewSnapshot: () => _previewSnapshot(
            context: context,
            summary: loaded,
            periodSelection: state.periodSelection,
            notifier: notifier,
          ),
          onOpenPrintView: () => _openPrintView(
            context: context,
            summary: loaded,
            periodSelection: state.periodSelection,
            notifier: notifier,
          ),
        ),
    };

    return AdminScaffold(
      title: _analyticsTitle,
      currentRoute: '/admin/analytics',
      child: RefreshIndicator(
        onRefresh: () => notifier.load(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[content],
        ),
      ),
    );
  }

  Future<void> _handlePresetSelected(AnalyticsPresetPeriod preset) async {
    final AnalyticsPeriodSelection selection = AnalyticsPeriodSelection.preset(
      preset,
    );
    await _applyPeriodSelection(selection);
  }

  Future<void> _handleCustomPeriodSelected(BuildContext context) async {
    final AdminRevenueAnalyticsState state = ref.read(
      adminRevenueAnalyticsNotifierProvider,
    );
    final RevenueSelectedPeriodSummary? summary =
        state.summary?.selectedPeriodSummary;
    final DateTimeRange initialDateRange = DateTimeRange(
      start: state.periodSelection.isCustom
          ? state.periodSelection.start!
          : (summary?.startDate ?? DateTime.now()).toLocal(),
      end: state.periodSelection.isCustom
          ? state.periodSelection.end!
          : (summary?.endDate ?? DateTime.now()).toLocal(),
    );
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: initialDateRange,
    );
    if (picked == null) {
      return;
    }
    await _applyPeriodSelection(
      AnalyticsPeriodSelection.custom(
        start: DateTime.utc(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
      ),
    );
  }

  Future<void> _applyPeriodSelection(AnalyticsPeriodSelection selection) async {
    await ref
        .read(adminRevenueAnalyticsNotifierProvider.notifier)
        .setPeriodSelection(selection);
    ref
        .read(adminRevenueAnalyticsNotifierProvider.notifier)
        .clearSelectedSavedView();
    _syncLocation(selection: selection, comparisonMode: _comparisonMode);
  }

  void _handleComparisonModeSelected(AnalyticsComparisonMode value) {
    setState(() {
      _comparisonMode = value;
    });
    ref
        .read(adminRevenueAnalyticsNotifierProvider.notifier)
        .clearSelectedSavedView();
    _syncLocation(
      selection: ref
          .read(adminRevenueAnalyticsNotifierProvider)
          .periodSelection,
      comparisonMode: value,
    );
  }

  void _handleInsightSelected(String value) {
    setState(() {
      _selectedInsightCode = value;
    });
    _syncLocation(
      selection: ref
          .read(adminRevenueAnalyticsNotifierProvider)
          .periodSelection,
      comparisonMode: _comparisonMode,
    );
  }

  void _handleTrendDateSelected(DateTime value) {
    setState(() {
      _selectedTrendDate = value;
    });
    _syncLocation(
      selection: ref
          .read(adminRevenueAnalyticsNotifierProvider)
          .periodSelection,
      comparisonMode: _comparisonMode,
    );
  }

  void _handleDaypartSelected(String value) {
    setState(() {
      _selectedDaypart = value;
    });
    _syncLocation(
      selection: ref
          .read(adminRevenueAnalyticsNotifierProvider)
          .periodSelection,
      comparisonMode: _comparisonMode,
    );
  }

  void _handleMoverSelected(String value) {
    setState(() {
      _selectedMoverId = value;
    });
    _syncLocation(
      selection: ref
          .read(adminRevenueAnalyticsNotifierProvider)
          .periodSelection,
      comparisonMode: _comparisonMode,
    );
  }

  Future<void> _showSaveViewDialog({
    required BuildContext context,
    required AdminRevenueAnalyticsNotifier notifier,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: _defaultSavedViewName(
        ref.read(adminRevenueAnalyticsNotifierProvider).periodSelection,
        _comparisonMode,
      ),
    );
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Geçerli Görünümü Kaydet'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Görünüm adı',
              hintText: 'Aylık Genel Bakış',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final SavedAnalyticsView savedView = await notifier.saveCurrentView(
      name: name,
      comparisonMode: _comparisonMode,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved analytics view "${savedView.name}"')),
    );
  }

  Future<void> _showSavedViewsSheet({
    required BuildContext context,
    required AdminRevenueAnalyticsNotifier notifier,
    required List<SavedAnalyticsView> savedViews,
    required String? selectedSavedViewId,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: savedViews.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No saved analytics views yet.'),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: savedViews.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final SavedAnalyticsView view = savedViews[index];
                    return ListTile(
                      title: Text(view.name),
                      subtitle: Text(
                        '${view.periodSelection.label} · ${_comparisonModeLabel(view.resolvedComparisonMode)}',
                      ),
                      leading: view.id == selectedSavedViewId
                          ? const Icon(Icons.check_circle_outline)
                          : const Icon(Icons.bookmark_outline),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await notifier.deleteSavedView(view.id);
                          if (!context.mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                        },
                      ),
                      onTap: () async {
                        final NavigatorState navigator = Navigator.of(context);
                        final SavedAnalyticsView? applied = await notifier
                            .applySavedView(view.id);
                        if (applied == null) {
                          return;
                        }
                        if (!context.mounted) {
                          return;
                        }
                        setState(() {
                          _comparisonMode = applied.resolvedComparisonMode;
                        });
                        navigator.pop();
                        _syncLocation(
                          selection: applied.periodSelection,
                          comparisonMode: applied.resolvedComparisonMode,
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _copyShareLink({
    required BuildContext context,
    required AnalyticsPeriodSelection periodSelection,
    required AnalyticsComparisonMode comparisonMode,
  }) async {
    final String link = buildAdminAnalyticsShareLink(
      periodSelection: periodSelection,
      comparisonMode: comparisonMode,
      selectedInsightCode: _selectedInsightCode,
      selectedTrendDate: _selectedTrendDate,
      selectedDaypart: _selectedDaypart,
      selectedMoverId: _selectedMoverId,
    );
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share link copied')));
  }

  Future<void> _copySnapshot({
    required BuildContext context,
    required RevenueSummary summary,
    required AnalyticsPeriodSelection periodSelection,
    required AdminRevenueAnalyticsNotifier notifier,
  }) async {
    final AnalyticsExport export = buildAdminAnalyticsExport(
      summary: summary,
      periodSelection: periodSelection,
      comparisonMode: _comparisonMode,
      selectedInsight: _selectedInsight(summary),
    );
    notifier.setLastExport(export);
    final String text = buildAdminAnalyticsSnapshotText(
      summary: summary,
      periodSelection: periodSelection,
      comparisonMode: _comparisonMode,
      selectedInsight: _selectedInsight(summary),
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analytics snapshot copied to clipboard')),
    );
  }

  Future<void> _previewSnapshot({
    required BuildContext context,
    required RevenueSummary summary,
    required AnalyticsPeriodSelection periodSelection,
    required AdminRevenueAnalyticsNotifier notifier,
  }) async {
    final AnalyticsExport export = buildAdminAnalyticsExport(
      summary: summary,
      periodSelection: periodSelection,
      comparisonMode: _comparisonMode,
      selectedInsight: _selectedInsight(summary),
    );
    notifier.setLastExport(export);
    final String text = buildAdminAnalyticsSnapshotText(
      summary: summary,
      periodSelection: periodSelection,
      comparisonMode: _comparisonMode,
      selectedInsight: _selectedInsight(summary),
    );
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Snapshot Preview',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              SelectableText(text),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openPrintView({
    required BuildContext context,
    required RevenueSummary summary,
    required AnalyticsPeriodSelection periodSelection,
    required AdminRevenueAnalyticsNotifier notifier,
  }) async {
    final AnalyticsSnapshot snapshot = buildAdminAnalyticsSnapshot(
      summary: summary,
      periodSelection: periodSelection,
      comparisonMode: _comparisonMode,
      selectedInsight: _selectedInsight(summary),
    );
    final AnalyticsExport export = buildAdminAnalyticsExport(
      summary: summary,
      periodSelection: periodSelection,
      comparisonMode: _comparisonMode,
      selectedInsight: _selectedInsight(summary),
    );
    notifier.setLastExport(export);
    notifier.setPrintViewOpen(true);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: AdminAnalyticsPrintView(
            summary: summary,
            snapshot: snapshot,
            export: export,
          ),
        );
      },
    );
    notifier.setPrintViewOpen(false);
  }

  Insight? _selectedInsight(RevenueSummary summary) {
    final List<Insight> insights = orderAdminAnalyticsInsights(
      buildPrimaryAnalyticsInsights(summary.insights),
      _comparisonMode,
    );
    return selectAdminAnalyticsInsight(
      insights,
      _selectedInsightCode,
      _comparisonMode,
    );
  }

  void _syncLocation({
    required AnalyticsPeriodSelection selection,
    required AnalyticsComparisonMode comparisonMode,
  }) {
    final GoRouter? router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    router.replace(
      buildAdminAnalyticsShareLink(
        periodSelection: selection,
        comparisonMode: comparisonMode,
        selectedInsightCode: _selectedInsightCode,
        selectedTrendDate: _selectedTrendDate,
        selectedDaypart: _selectedDaypart,
        selectedMoverId: _selectedMoverId,
      ),
    );
  }
}

String buildAdminAnalyticsShareLink({
  required AnalyticsPeriodSelection periodSelection,
  required AnalyticsComparisonMode comparisonMode,
  String? selectedInsightCode,
  DateTime? selectedTrendDate,
  String? selectedDaypart,
  String? selectedMoverId,
}) {
  final Map<String, String> queryParameters = <String, String>{
    ...periodSelection.toQueryParameters(),
    'mode': analyticsComparisonModeQueryValue(comparisonMode),
    if (selectedInsightCode != null && selectedInsightCode.isNotEmpty)
      'insight': selectedInsightCode,
    if (selectedTrendDate != null)
      'trend': selectedTrendDate.toIso8601String().split('T').first,
    if (selectedDaypart != null && selectedDaypart.isNotEmpty)
      'daypart': selectedDaypart,
    if (selectedMoverId != null && selectedMoverId.isNotEmpty)
      'mover': selectedMoverId,
  };
  return Uri(
    path: '/admin/analytics',
    queryParameters: queryParameters,
  ).toString();
}

String _defaultSavedViewName(
  AnalyticsPeriodSelection selection,
  AnalyticsComparisonMode comparisonMode,
) {
  return '${selection.label} ${_comparisonModeLabel(comparisonMode)}';
}

String _comparisonModeLabel(AnalyticsComparisonMode mode) {
  return switch (mode) {
    AnalyticsComparisonMode.baselineSummary => 'Baseline',
    AnalyticsComparisonMode.previousEquivalentPeriod => 'Previous',
    AnalyticsComparisonMode.momentumView => 'Momentum',
  };
}
