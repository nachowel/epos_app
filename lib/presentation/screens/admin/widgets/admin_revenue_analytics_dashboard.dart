import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/analytics/analytics_export.dart';
import '../../../../domain/models/analytics/analytics_period.dart';
import '../../../../domain/models/analytics/analytics_snapshot.dart';
import '../../../../domain/models/analytics/insight.dart';
import '../../../../domain/models/analytics/saved_analytics_view.dart';
import '../../../../domain/models/daily_revenue_point.dart';
import '../../../../domain/models/order_modifier.dart';
import '../../../../domain/models/revenue_comparison.dart';
import '../../../../domain/models/revenue_insights.dart';
import '../../../../domain/models/revenue_intelligence_inputs.dart';
import '../../../../domain/models/revenue_summary.dart';
import '../../../../domain/models/semantic_sales_analytics.dart';

const ValueKey<String> adminAnalyticsDashboardKey = ValueKey<String>(
  'admin_analytics_dashboard',
);
const ValueKey<String> adminAnalyticsLoadingKey = ValueKey<String>(
  'admin_analytics_loading',
);
const ValueKey<String> adminAnalyticsErrorKey = ValueKey<String>(
  'admin_analytics_error',
);
const ValueKey<String> adminAnalyticsEmptyKey = ValueKey<String>(
  'admin_analytics_empty',
);
const ValueKey<String> adminAnalyticsCopySnapshotButtonKey = ValueKey<String>(
  'admin_analytics_copy_snapshot_button',
);
const ValueKey<String> adminAnalyticsSecondaryInsightsKey = ValueKey<String>(
  'admin_analytics_secondary_insights',
);
const ValueKey<String> adminAnalyticsSecondaryInsightCardKey = ValueKey<String>(
  'admin_analytics_secondary_insight_card',
);
const ValueKey<String> adminAnalyticsSemanticSectionKey = ValueKey<String>(
  'admin_analytics_semantic_section',
);

class AdminRevenueAnalyticsDashboard extends StatelessWidget {
  const AdminRevenueAnalyticsDashboard({
    required this.summary,
    required this.periodSelection,
    required this.comparisonMode,
    required this.savedViews,
    required this.selectedSavedViewId,
    required this.selectedInsightCode,
    required this.selectedTrendDate,
    required this.selectedDaypart,
    required this.selectedMoverId,
    required this.onPeriodSelected,
    required this.onCustomPeriodRequested,
    required this.onComparisonModeSelected,
    required this.onSaveViewRequested,
    required this.onSavedViewsRequested,
    required this.onCopyShareLink,
    required this.onInsightSelected,
    required this.onTrendDateSelected,
    required this.onDaypartSelected,
    required this.onMoverSelected,
    required this.onCopySnapshot,
    required this.onPreviewSnapshot,
    required this.onOpenPrintView,
    this.statusMessage,
    this.isRefreshing = false,
    super.key,
  });

  final RevenueSummary summary;
  final AnalyticsPeriodSelection periodSelection;
  final AnalyticsComparisonMode comparisonMode;
  final List<SavedAnalyticsView> savedViews;
  final String? selectedSavedViewId;
  final String? selectedInsightCode;
  final DateTime? selectedTrendDate;
  final String? selectedDaypart;
  final String? selectedMoverId;
  final ValueChanged<AnalyticsPresetPeriod> onPeriodSelected;
  final VoidCallback onCustomPeriodRequested;
  final ValueChanged<AnalyticsComparisonMode> onComparisonModeSelected;
  final VoidCallback onSaveViewRequested;
  final VoidCallback onSavedViewsRequested;
  final VoidCallback onCopyShareLink;
  final ValueChanged<String> onInsightSelected;
  final ValueChanged<DateTime> onTrendDateSelected;
  final ValueChanged<String> onDaypartSelected;
  final ValueChanged<String> onMoverSelected;
  final VoidCallback onCopySnapshot;
  final VoidCallback onPreviewSnapshot;
  final VoidCallback onOpenPrintView;
  final String? statusMessage;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final RevenueSelectedPeriodSummary selected = summary.selectedPeriodSummary;
    final List<DailyRevenuePoint> trendPoints = _trendPointsForDisplay(
      summary: summary,
      selected: selected,
    );
    final List<Insight> orderedInsights = orderAdminAnalyticsInsights(
      buildPrimaryAnalyticsInsights(summary.insights),
      comparisonMode,
    );
    final Insight? selectedInsight = selectAdminAnalyticsInsight(
      orderedInsights,
      selectedInsightCode,
      comparisonMode,
    );
    final Insight? primaryMessage = _primaryMessageInsight(
      orderedInsights,
      selected,
    );
    final List<Insight> secondaryInsights = _secondaryInsights(
      orderedInsights
          .map(
            (Insight insight) => _localizeInsight(insight, selected.selection),
          )
          .toList(growable: false),
      primaryMessage,
    );
    final DailyRevenuePoint? selectedTrendPoint = _selectedTrendPoint(
      trendPoints,
      selectedTrendDate,
    );
    final _PaymentMixDisplay paymentMix = _paymentMixDisplay(
      mix: selected.paymentMix,
      totalRevenueMinor: selected.revenue.currentValue,
    );
    final String periodLabel = selected.selection.isCustom
        ? _dateRangeLabel(selected.startDate, selected.endDate)
        : _selectionLabel(selected.selection);
    final SemanticSalesAnalytics semanticAnalytics =
        summary.semanticSalesAnalytics;
    return Container(
      key: adminAnalyticsDashboardKey,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _HeroHeader(
            summary: summary,
            periodSelection: periodSelection,
            selectedPeriodSummary: selected,
            savedViews: savedViews,
            selectedSavedViewId: selectedSavedViewId,
            statusMessage: statusMessage,
            isRefreshing: isRefreshing,
            onPeriodSelected: onPeriodSelected,
            onCustomPeriodRequested: onCustomPeriodRequested,
            onSaveViewRequested: onSaveViewRequested,
            onSavedViewsRequested: onSavedViewsRequested,
            onCopyShareLink: onCopyShareLink,
            onCopySnapshot: onCopySnapshot,
            onPreviewSnapshot: onPreviewSnapshot,
            onOpenPrintView: onOpenPrintView,
          ),
          const SizedBox(height: AppSizes.spacingLg),
          Wrap(
            spacing: AppSizes.spacingMd,
            runSpacing: AppSizes.spacingMd,
            children: <Widget>[
              _KpiCard(
                title: 'Toplam Ciro',
                value: _formatMetric(
                  selected.revenue.currentValue,
                  selected.revenue.metricFormat,
                ),
                comparison: selected.revenue,
                selection: selected.selection,
              ),
              _KpiCard(
                title: 'Sipariş Sayısı',
                value: _formatMetric(
                  selected.orderCount.currentValue,
                  selected.orderCount.metricFormat,
                ),
                comparison: selected.orderCount,
                selection: selected.selection,
              ),
              _KpiCard(
                title: 'Ortalama Sipariş Tutarı',
                value: _formatMetric(
                  selected.averageOrderValue.currentValue,
                  selected.averageOrderValue.metricFormat,
                ),
                comparison: selected.averageOrderValue,
                selection: selected.selection,
              ),
              _PaymentMixKpiCard(mix: paymentMix),
            ],
          ),
          const SizedBox(height: AppSizes.spacingLg),
          _PrimaryMessageCard(
            display: _buildPrimaryMessageDisplay(
              selected: selected,
              insight: primaryMessage,
            ),
          ),
          const SizedBox(height: AppSizes.spacingLg),
          _Panel(
            title: _trendTitle(selected.selection),
            subtitle: _trendSubtitle(
              selection: selected.selection,
              periodLabel: periodLabel,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _DailyBarChart(
                  points: trendPoints,
                  selectedPoint: selectedTrendPoint,
                  onPointSelected: onTrendDateSelected,
                ),
                const SizedBox(height: AppSizes.spacingMd),
                Wrap(
                  spacing: AppSizes.spacingMd,
                  runSpacing: AppSizes.spacingSm,
                  children: _trendSummaryChips(
                    selectedPoint: selectedTrendPoint,
                    selectedPeriodSummary: selected,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingLg),
          _Panel(
            key: adminAnalyticsSecondaryInsightsKey,
            title: 'Öne Çıkan İçgörüler',
            subtitle: 'Yalnızca en güçlü sinyaller gösterilir',
            child: secondaryInsights.isEmpty
                ? const _MutedState(
                    message: 'Bu dönem için ek içgörü bulunmuyor.',
                  )
                : Column(
                    children: secondaryInsights
                        .map(
                          (Insight insight) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSizes.spacingSm,
                            ),
                            child: _SecondaryInsightCard(
                              key: ValueKey<String>(
                                '${adminAnalyticsSecondaryInsightCardKey.value}:${insight.code}',
                              ),
                              insight: insight,
                              isSelected: selectedInsight?.code == insight.code,
                              onTap: () => onInsightSelected(insight.code),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
          if (!semanticAnalytics.isEmpty) ...<Widget>[
            const SizedBox(height: AppSizes.spacingLg),
            _SemanticAnalyticsSection(analytics: semanticAnalytics),
          ],
          if (summary.dataQualityNotes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSizes.spacingLg),
            _DataNotesBlock(
              notes: _localizedDataNotes(summary.dataQualityNotes),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminRevenueAnalyticsLoadingView extends StatelessWidget {
  const AdminRevenueAnalyticsLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: adminAnalyticsLoadingKey,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const <Widget>[
          _LoadingBlock(height: 22, width: 220),
          SizedBox(height: AppSizes.spacingSm),
          _LoadingBlock(height: 14, width: 320),
          SizedBox(height: AppSizes.spacingLg),
          Wrap(
            spacing: AppSizes.spacingMd,
            runSpacing: AppSizes.spacingMd,
            children: <Widget>[
              _LoadingCard(),
              _LoadingCard(),
              _LoadingCard(),
              _LoadingCard(),
            ],
          ),
          SizedBox(height: AppSizes.spacingLg),
          _LoadingPanel(height: 110),
          SizedBox(height: AppSizes.spacingLg),
          _LoadingPanel(height: 260),
          SizedBox(height: AppSizes.spacingLg),
          _LoadingPanel(height: 180),
        ],
      ),
    );
  }
}

class AdminRevenueAnalyticsErrorView extends StatelessWidget {
  const AdminRevenueAnalyticsErrorView({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: adminAnalyticsErrorKey,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Analiz ekranı kullanılamıyor',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(message),
          const SizedBox(height: AppSizes.spacingLg),
          FilledButton(onPressed: onRetry, child: const Text('Yeniden Dene')),
        ],
      ),
    );
  }
}

class AdminRevenueAnalyticsEmptyView extends StatelessWidget {
  const AdminRevenueAnalyticsEmptyView({this.statusMessage, super.key});

  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: adminAnalyticsEmptyKey,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Henüz tamamlanmış analiz verisi yok',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            statusMessage?.trim().isNotEmpty == true
                ? statusMessage!
                : 'Ciro analizi, ödenmiş veya iptal edilmiş işlemler aynalandığında görünecektir.',
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.summary,
    required this.periodSelection,
    required this.selectedPeriodSummary,
    required this.savedViews,
    required this.selectedSavedViewId,
    required this.statusMessage,
    required this.isRefreshing,
    required this.onPeriodSelected,
    required this.onCustomPeriodRequested,
    required this.onSaveViewRequested,
    required this.onSavedViewsRequested,
    required this.onCopyShareLink,
    required this.onCopySnapshot,
    required this.onPreviewSnapshot,
    required this.onOpenPrintView,
  });

  final RevenueSummary summary;
  final AnalyticsPeriodSelection periodSelection;
  final RevenueSelectedPeriodSummary selectedPeriodSummary;
  final List<SavedAnalyticsView> savedViews;
  final String? selectedSavedViewId;
  final String? statusMessage;
  final bool isRefreshing;
  final ValueChanged<AnalyticsPresetPeriod> onPeriodSelected;
  final VoidCallback onCustomPeriodRequested;
  final VoidCallback onSaveViewRequested;
  final VoidCallback onSavedViewsRequested;
  final VoidCallback onCopyShareLink;
  final VoidCallback onCopySnapshot;
  final VoidCallback onPreviewSnapshot;
  final VoidCallback onOpenPrintView;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3EE),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Ciro Paneli',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacingXs),
                    Text(
                      _headerPeriodLabel(selectedPeriodSummary),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spacingXs),
                    Text(
                      'Oluşturulma: ${_formatDateTimeTr(summary.generatedAt)} · ${summary.timezone}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (statusMessage?.trim().isNotEmpty == true) ...<Widget>[
                      const SizedBox(height: AppSizes.spacingSm),
                      Text(
                        statusMessage!,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              _ActionsMenu(
                savedViews: savedViews,
                selectedSavedViewId: selectedSavedViewId,
                onSaveViewRequested: onSaveViewRequested,
                onSavedViewsRequested: onSavedViewsRequested,
                onCopyShareLink: onCopyShareLink,
                onCopySnapshot: onCopySnapshot,
                onPreviewSnapshot: onPreviewSnapshot,
                onOpenPrintView: onOpenPrintView,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingLg),
          Wrap(
            spacing: AppSizes.spacingSm,
            runSpacing: AppSizes.spacingSm,
            children: <Widget>[
              _PeriodChip(
                label: 'Bugün',
                selected:
                    periodSelection ==
                    const AnalyticsPeriodSelection.preset(
                      AnalyticsPresetPeriod.today,
                    ),
                onTap: () => onPeriodSelected(AnalyticsPresetPeriod.today),
              ),
              _PeriodChip(
                label: 'Bu Hafta',
                selected:
                    periodSelection ==
                    const AnalyticsPeriodSelection.preset(
                      AnalyticsPresetPeriod.thisWeek,
                    ),
                onTap: () => onPeriodSelected(AnalyticsPresetPeriod.thisWeek),
              ),
              _PeriodChip(
                label: 'Bu Ay',
                selected:
                    periodSelection ==
                    const AnalyticsPeriodSelection.preset(
                      AnalyticsPresetPeriod.thisMonth,
                    ),
                onTap: () => onPeriodSelected(AnalyticsPresetPeriod.thisMonth),
              ),
              _PeriodChip(
                label: periodSelection.isCustom
                    ? 'Özel Aralık: ${_dateRangeLabel(selectedPeriodSummary.startDate, selectedPeriodSummary.endDate)}'
                    : 'Özel Aralık',
                selected: periodSelection.isCustom,
                onTap: onCustomPeriodRequested,
              ),
            ],
          ),
          if (isRefreshing) ...<Widget>[
            const SizedBox(height: AppSizes.spacingMd),
            Row(
              children: const <Widget>[
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: AppSizes.spacingSm),
                Text(
                  'Analizler yenileniyor...',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.savedViews,
    required this.selectedSavedViewId,
    required this.onSaveViewRequested,
    required this.onSavedViewsRequested,
    required this.onCopyShareLink,
    required this.onCopySnapshot,
    required this.onPreviewSnapshot,
    required this.onOpenPrintView,
  });

  final List<SavedAnalyticsView> savedViews;
  final String? selectedSavedViewId;
  final VoidCallback onSaveViewRequested;
  final VoidCallback onSavedViewsRequested;
  final VoidCallback onCopyShareLink;
  final VoidCallback onCopySnapshot;
  final VoidCallback onPreviewSnapshot;
  final VoidCallback onOpenPrintView;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_DashboardAction>(
      tooltip: 'Dashboard actions',
      onSelected: (_DashboardAction action) {
        switch (action) {
          case _DashboardAction.saveView:
            onSaveViewRequested();
          case _DashboardAction.savedViews:
            onSavedViewsRequested();
          case _DashboardAction.shareLink:
            onCopyShareLink();
          case _DashboardAction.copySnapshot:
            onCopySnapshot();
          case _DashboardAction.previewSnapshot:
            onPreviewSnapshot();
          case _DashboardAction.printView:
            onOpenPrintView();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<_DashboardAction>>[
        const PopupMenuItem<_DashboardAction>(
          value: _DashboardAction.saveView,
          child: Text('Görünümü Kaydet'),
        ),
        PopupMenuItem<_DashboardAction>(
          value: _DashboardAction.savedViews,
          child: Text(
            selectedSavedViewId == null
                ? 'Kayıtlı Görünümler'
                : 'Kayıtlı Görünümler (${savedViews.length})',
          ),
        ),
        const PopupMenuItem<_DashboardAction>(
          value: _DashboardAction.shareLink,
          child: Text('Bağlantıyı Kopyala'),
        ),
        const PopupMenuItem<_DashboardAction>(
          value: _DashboardAction.copySnapshot,
          child: Text('Özeti Kopyala'),
        ),
        const PopupMenuItem<_DashboardAction>(
          value: _DashboardAction.previewSnapshot,
          child: Text('Özeti Önizle'),
        ),
        const PopupMenuItem<_DashboardAction>(
          value: _DashboardAction.printView,
          child: Text('Yazdırma Görünümü'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.spacingMd,
          vertical: AppSizes.spacingSm,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const <Widget>[
            Icon(Icons.more_horiz_rounded, size: 18),
            SizedBox(width: AppSizes.spacingXs),
            Text('İşlemler', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.comparison,
    required this.selection,
  });

  final String title;
  final String value;
  final RevenueComparison comparison;
  final AnalyticsPeriodSelection selection;

  @override
  Widget build(BuildContext context) {
    final _TrendLine trend = _trendLine(comparison, selection);
    return Container(
      width: 250,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            trend.label,
            style: TextStyle(color: trend.color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PaymentMixKpiCard extends StatelessWidget {
  const _PaymentMixKpiCard({required this.mix});

  final _PaymentMixDisplay mix;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Ödeme Dağılımı',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          if (mix.isUnavailable) ...<Widget>[
            Text(
              mix.headline,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            if (mix.supportingLabel != null) ...<Widget>[
              const SizedBox(height: AppSizes.spacingSm),
              Text(
                mix.supportingLabel!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ] else ...<Widget>[
            _PaymentMixLine(
              label: 'Nakit',
              amount: mix.cashAmountLabel!,
              shareLabel: mix.cashShareLabel!,
            ),
            const SizedBox(height: AppSizes.spacingSm),
            _PaymentMixLine(
              label: 'Kart',
              amount: mix.cardAmountLabel!,
              shareLabel: mix.cardShareLabel!,
            ),
          ],
        ],
      ),
    );
  }
}

class _PrimaryMessageCard extends StatelessWidget {
  const _PrimaryMessageCard({required this.display});

  final _PrimaryMessageDisplay display;

  @override
  Widget build(BuildContext context) {
    final _SeverityStyle style = _severityStyle(display.severity);
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: style.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(style.icon, color: style.foreground),
          const SizedBox(width: AppSizes.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Durum Özeti',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingXs),
                Text(
                  display.headline,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (display.secondaryText != null) ...<Widget>[
                  const SizedBox(height: AppSizes.spacingSm),
                  Text(
                    display.secondaryText!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SemanticAnalyticsSection extends StatelessWidget {
  const _SemanticAnalyticsSection({required this.analytics});

  final SemanticSalesAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final List<SemanticRootProductAnalytics> topProducts = analytics
        .rootProducts
        .take(3)
        .toList(growable: false);
    final List<SemanticChoiceSelectionAnalytics> topChoices = analytics
        .choiceSelections
        .take(4)
        .toList(growable: false);
    final List<SemanticItemBehaviorAnalytics> removedItems = analytics
        .removedItems
        .take(3)
        .toList(growable: false);
    final List<SemanticItemBehaviorAnalytics> addedItems = analytics.addedItems
        .take(3)
        .toList(growable: false);
    final List<SemanticBundleVariantAnalytics> variants = analytics
        .bundleVariants
        .take(3)
        .toList(growable: false);

    final int extraRevenueMinor = _chargeReasonRevenue(
      analytics,
      ModifierChargeReason.extraAdd,
    );
    final int paidSwapRevenueMinor = _chargeReasonRevenue(
      analytics,
      ModifierChargeReason.paidSwap,
    );
    final int freeSwapCount = _chargeReasonEvents(
      analytics,
      ModifierChargeReason.freeSwap,
    );
    final int paidSwapCount = _chargeReasonEvents(
      analytics,
      ModifierChargeReason.paidSwap,
    );

    return _Panel(
      key: adminAnalyticsSemanticSectionKey,
      title: 'Menü Davranışı',
      subtitle: 'Set satışları, seçim dağılımı ve ek gelir sinyalleri',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSizes.spacingMd,
            runSpacing: AppSizes.spacingMd,
            children: <Widget>[
              _SemanticInsightCard(
                title: 'Ürün Performansı',
                emptyMessage: 'Semantic set satışı henüz yok.',
                items: topProducts
                    .map(
                      (
                        SemanticRootProductAnalytics entry,
                      ) => _SemanticInsightLine(
                        title: _semanticDisplayLabel(entry.rootProductName),
                        detail:
                            '${entry.quantitySold} satış · ${CurrencyFormatter.fromMinor(entry.revenueMinor)}',
                      ),
                    )
                    .toList(growable: false),
              ),
              _SemanticInsightCard(
                title: 'Seçim Dağılımı',
                emptyMessage: 'Henüz kaydedilmiş grup seçimi yok.',
                items: topChoices
                    .map(
                      (
                        SemanticChoiceSelectionAnalytics entry,
                      ) => _SemanticInsightLine(
                        title:
                            '${_semanticDisplayLabel(entry.groupName)}: ${_semanticDisplayLabel(entry.itemName)}',
                        detail:
                            '%${_formatPercent(entry.distributionPercent)} · ${entry.selectionCount} sipariş',
                      ),
                    )
                    .toList(growable: false),
              ),
              _SemanticInsightCard(
                title: 'Davranış İçgörüleri',
                emptyMessage: 'Ek veya çıkarma davranışı oluşmadı.',
                items: <_SemanticInsightLine>[
                  ...removedItems.map(
                    (
                      SemanticItemBehaviorAnalytics entry,
                    ) => _SemanticInsightLine(
                      title:
                          '${_semanticDisplayLabel(entry.itemName)} çıkarıldı',
                      detail:
                          '%${_formatPercent(entry.percentageOfRootSales)} · ${entry.occurrenceCount} sipariş',
                    ),
                  ),
                  ...addedItems.map(
                    (
                      SemanticItemBehaviorAnalytics entry,
                    ) => _SemanticInsightLine(
                      title: '${_semanticDisplayLabel(entry.itemName)} eklendi',
                      detail:
                          '${entry.occurrenceCount} sipariş · ${CurrencyFormatter.fromMinor(entry.revenueMinor)}',
                    ),
                  ),
                ],
              ),
              _SemanticInsightCard(
                title: 'Ek Gelir',
                emptyMessage: 'Ek gelir davranışı henüz yok.',
                items: <_SemanticInsightLine>[
                  if (extraRevenueMinor > 0)
                    _SemanticInsightLine(
                      title: 'Ek ürün geliri',
                      detail: CurrencyFormatter.fromMinor(extraRevenueMinor),
                    ),
                  if (paidSwapRevenueMinor > 0)
                    _SemanticInsightLine(
                      title: 'Ücretli değişim geliri',
                      detail: CurrencyFormatter.fromMinor(paidSwapRevenueMinor),
                    ),
                  if (freeSwapCount > 0 || paidSwapCount > 0)
                    _SemanticInsightLine(
                      title: 'Değişim sayısı',
                      detail:
                          '$freeSwapCount ücretsiz · $paidSwapCount ücretli',
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingLg),
          _SemanticInsightCard(
            title: 'Öne Çıkan Varyantlar',
            emptyMessage: 'Varyant paterni oluşmadı.',
            width: double.infinity,
            items: variants
                .map(
                  (
                    SemanticBundleVariantAnalytics entry,
                  ) => _SemanticInsightLine(
                    title: _bundleVariantSummary(entry),
                    detail:
                        '${entry.orderCount} sipariş · ${CurrencyFormatter.fromMinor(entry.revenueMinor)}',
                  ),
                )
                .toList(growable: false),
          ),
          if (analytics.dataQualityNotes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSizes.spacingLg),
            _DataNotesBlock(
              notes: _localizedDataNotes(analytics.dataQualityNotes),
            ),
          ],
        ],
      ),
    );
  }
}

class _SemanticInsightCard extends StatelessWidget {
  const _SemanticInsightCard({
    required this.title,
    required this.items,
    required this.emptyMessage,
    this.width = 320,
  });

  final String title;
  final List<_SemanticInsightLine> items;
  final String emptyMessage;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          if (items.isEmpty)
            _MutedState(message: emptyMessage)
          else
            Column(
              children: items
                  .map(
                    (_SemanticInsightLine item) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSizes.spacingSm,
                      ),
                      child: _SemanticInsightRow(item: item),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _SemanticInsightRow extends StatelessWidget {
  const _SemanticInsightRow({required this.item});

  final _SemanticInsightLine item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.spacingXs),
        Text(
          item.detail,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SemanticInsightLine {
  const _SemanticInsightLine({required this.title, required this.detail});

  final String title;
  final String detail;
}

class _PaymentMixLine extends StatelessWidget {
  const _PaymentMixLine({
    required this.label,
    required this.amount,
    required this.shareLabel,
  });

  final String label;
  final String amount;
  final String shareLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            '$amount · $shareLabel',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({
    required this.points,
    required this.selectedPoint,
    required this.onPointSelected,
  });

  final List<DailyRevenuePoint> points;
  final DailyRevenuePoint? selectedPoint;
  final ValueChanged<DateTime> onPointSelected;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _MutedState(message: 'Henüz günlük trend verisi yok.');
    }
    final int maxRevenue = points.fold<int>(
      0,
      (int current, DailyRevenuePoint point) =>
          math.max(current, point.revenueMinor),
    );
    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points
            .map(
              (DailyRevenuePoint point) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                    onTap: () => onPointSelected(point.date),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          CurrencyFormatter.fromMinor(point.revenueMinor),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                selectedPoint != null &&
                                    _isSameDate(selectedPoint!.date, point.date)
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSizes.spacingSm),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: double.infinity,
                          height: maxRevenue == 0
                              ? 12
                              : math
                                    .max(
                                      12,
                                      ((point.revenueMinor / maxRevenue) * 160)
                                          .round(),
                                    )
                                    .toDouble(),
                          decoration: BoxDecoration(
                            color:
                                selectedPoint != null &&
                                    _isSameDate(selectedPoint!.date, point.date)
                                ? AppColors.primary
                                : AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusSm,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacingSm),
                        Text(
                          DateFormat('d MMM').format(point.date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _TrendSummaryChip extends StatelessWidget {
  const _TrendSummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingMd,
        vertical: AppSizes.spacingSm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F8),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SecondaryInsightCard extends StatelessWidget {
  const _SecondaryInsightCard({
    required this.insight,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final Insight insight;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _SeverityStyle style = _severityStyle(insight.severity);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.spacingMd),
        decoration: BoxDecoration(
          color: isSelected ? style.background : Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: isSelected ? style.border : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(style.icon, color: style.foreground, size: 18),
            const SizedBox(width: AppSizes.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    insight.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSizes.spacingXs),
                  Text(
                    insight.message,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataNotesBlock extends StatelessWidget {
  const _DataNotesBlock({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('admin_analytics_data_notes'),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Veri Notları',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          ...notes
              .take(3)
              .map(
                (String note) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $note',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _MutedState extends StatelessWidget {
  const _MutedState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(color: AppColors.textSecondary),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSizes.spacingXs),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.spacingLg),
          child,
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
      showCheckmark: false,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 250, child: _LoadingPanel(height: 132));
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.height, required this.width});

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
    );
  }
}

enum _DashboardAction {
  saveView,
  savedViews,
  shareLink,
  copySnapshot,
  previewSnapshot,
  printView,
}

class _TrendLine {
  const _TrendLine({required this.label, required this.color});

  final String label;
  final Color color;
}

class _SeverityStyle {
  const _SeverityStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;
}

class _PaymentMixDisplay {
  const _PaymentMixDisplay({
    required this.headline,
    this.supportingLabel,
    this.cashAmountLabel,
    this.cardAmountLabel,
    this.cashShareLabel,
    this.cardShareLabel,
    this.isUnavailable = false,
  });

  final String headline;
  final String? supportingLabel;
  final String? cashAmountLabel;
  final String? cardAmountLabel;
  final String? cashShareLabel;
  final String? cardShareLabel;
  final bool isUnavailable;
}

class _PrimaryMessageDisplay {
  const _PrimaryMessageDisplay({
    required this.headline,
    required this.severity,
    this.secondaryText,
  });

  final String headline;
  final String? secondaryText;
  final InsightSeverity severity;
}

List<Insight> buildPrimaryAnalyticsInsights(RevenueInsights insights) {
  final List<Insight> structured = insights.structuredInsights
      .where((Insight insight) => !insight.code.startsWith('data_quality_'))
      .toList(growable: false);
  if (structured.isNotEmpty) {
    return structured;
  }
  return insights.messages
      .where((String message) => message.trim().isNotEmpty)
      .map(
        (String message) => Insight(
          code: 'legacy_fallback',
          severity: InsightSeverity.info,
          title: 'Analiz Özeti',
          message: message,
          evidence: const <String, dynamic>{},
        ),
      )
      .toList(growable: false);
}

List<Insight> orderAdminAnalyticsInsights(
  List<Insight> insights,
  AnalyticsComparisonMode mode,
) {
  final List<String> priorityCodes = switch (mode) {
    AnalyticsComparisonMode.baselineSummary => <String>[
      'period_revenue_delta',
      'period_order_count_delta',
      'period_average_order_value_delta',
      'period_payment_mix',
      'strongest_day',
      'peak_hours',
    ],
    AnalyticsComparisonMode.previousEquivalentPeriod => <String>[
      'period_revenue_delta',
      'period_order_count_delta',
      'period_average_order_value_delta',
      'period_payment_mix',
      'strongest_day',
      'peak_hours',
    ],
    AnalyticsComparisonMode.momentumView => <String>[
      'revenue_momentum_14d',
      'period_revenue_delta',
      'period_order_count_delta',
      'period_average_order_value_delta',
      'strongest_day',
      'peak_hours',
    ],
  };
  final List<Insight> prioritized = <Insight>[];
  final List<Insight> remaining = <Insight>[];
  for (final Insight insight in insights) {
    if (priorityCodes.contains(insight.code)) {
      prioritized.add(insight);
    } else {
      remaining.add(insight);
    }
  }
  prioritized.sort((Insight left, Insight right) {
    final int priorityComparison = priorityCodes
        .indexOf(left.code)
        .compareTo(priorityCodes.indexOf(right.code));
    if (priorityComparison != 0) {
      return priorityComparison;
    }
    return _deterministicInsightSort(left, right);
  });
  remaining.sort(_deterministicInsightSort);
  return <Insight>[...prioritized, ...remaining];
}

Insight? selectAdminAnalyticsInsight(
  List<Insight> insights,
  String? selectedInsightCode,
  AnalyticsComparisonMode mode,
) {
  final Insight? explicit = selectedInsightCode == null
      ? null
      : _findInsight(insights, selectedInsightCode);
  if (explicit != null) {
    return explicit;
  }
  final String preferredCode = switch (mode) {
    AnalyticsComparisonMode.baselineSummary => 'period_revenue_delta',
    AnalyticsComparisonMode.previousEquivalentPeriod => 'period_revenue_delta',
    AnalyticsComparisonMode.momentumView => 'revenue_momentum_14d',
  };
  return _findInsight(insights, preferredCode) ??
      (insights.isEmpty ? null : insights.first);
}

String buildAdminAnalyticsSnapshotText({
  required RevenueSummary summary,
  required AnalyticsPeriodSelection periodSelection,
  required AnalyticsComparisonMode comparisonMode,
  required Insight? selectedInsight,
}) {
  final AnalyticsSnapshot snapshot = buildAdminAnalyticsSnapshot(
    summary: summary,
    periodSelection: periodSelection,
    comparisonMode: comparisonMode,
    selectedInsight: selectedInsight,
  );
  final StringBuffer buffer = StringBuffer()
    ..writeln('EPOS Analiz Özeti')
    ..writeln(snapshot.periodLabel)
    ..writeln('Karşılaştırma: ${snapshot.comparisonModeLabel}')
    ..writeln(
      'Trend: ${_snapshotTrendLabel(summary.selectedPeriodSummary.selection)}',
    );
  for (final AnalyticsSnapshotKpi kpi in snapshot.kpis) {
    buffer.writeln('${kpi.title}: ${kpi.value}');
  }
  buffer.writeln('İçgörüler:');
  for (final Insight insight in snapshot.insights) {
    buffer.writeln('- ${insight.title}: ${insight.message}');
  }
  if (selectedInsight != null) {
    buffer.writeln(
      'Öne Çıkan İçgörü: ${_localizeInsight(selectedInsight, summary.selectedPeriodSummary.selection).title}',
    );
  }
  for (final AnalyticsSnapshotSection section in snapshot.keyBreakdowns) {
    buffer.writeln('${section.title}:');
    for (final String line in section.lines) {
      buffer.writeln('- $line');
    }
  }
  if (snapshot.notes.isNotEmpty) {
    buffer.writeln('Veri Notu: ${snapshot.notes.first}');
  }
  return buffer.toString().trimRight();
}

AnalyticsSnapshot buildAdminAnalyticsSnapshot({
  required RevenueSummary summary,
  required AnalyticsPeriodSelection periodSelection,
  required AnalyticsComparisonMode comparisonMode,
  required Insight? selectedInsight,
}) {
  final RevenueSelectedPeriodSummary selected = summary.selectedPeriodSummary;
  final List<Insight> ordered = orderAdminAnalyticsInsights(
    buildPrimaryAnalyticsInsights(summary.insights),
    comparisonMode,
  );
  final Insight? primary = _primaryMessageInsight(ordered, selected);
  final List<Insight> secondary = _secondaryInsights(ordered, primary);
  final _PaymentMixDisplay paymentMix = _paymentMixDisplay(
    mix: selected.paymentMix,
    totalRevenueMinor: selected.revenue.currentValue,
  );
  final String periodLabel = _selectedPeriodDisplayLabel(selected);

  return AnalyticsSnapshot(
    periodLabel: periodLabel,
    comparisonModeLabel: _comparisonModeShortLabel(comparisonMode),
    kpis: <AnalyticsSnapshotKpi>[
      AnalyticsSnapshotKpi(
        title: 'Toplam Ciro',
        value: _formatMetric(
          selected.revenue.currentValue,
          selected.revenue.metricFormat,
        ),
        supportingLabel: _snapshotComparisonLine(
          selected.revenue,
          selected.selection,
        ),
      ),
      AnalyticsSnapshotKpi(
        title: 'Sipariş Sayısı',
        value: _formatMetric(
          selected.orderCount.currentValue,
          selected.orderCount.metricFormat,
        ),
        supportingLabel: _snapshotComparisonLine(
          selected.orderCount,
          selected.selection,
        ),
      ),
      AnalyticsSnapshotKpi(
        title: 'Ortalama Sipariş Tutarı',
        value: _formatMetric(
          selected.averageOrderValue.currentValue,
          selected.averageOrderValue.metricFormat,
        ),
        supportingLabel: _snapshotComparisonLine(
          selected.averageOrderValue,
          selected.selection,
        ),
      ),
      AnalyticsSnapshotKpi(
        title: 'Ödeme Dağılımı',
        value: paymentMix.isUnavailable
            ? paymentMix.headline
            : '${paymentMix.cashAmountLabel} · ${paymentMix.cashShareLabel} | ${paymentMix.cardAmountLabel} · ${paymentMix.cardShareLabel}',
        supportingLabel: paymentMix.supportingLabel,
      ),
    ],
    insights: <Insight>[
      if (primary != null) _localizeInsight(primary, selected.selection),
      ...secondary.map(
        (Insight insight) => _localizeInsight(insight, selected.selection),
      ),
    ].take(3).toList(growable: false),
    keyBreakdowns: <AnalyticsSnapshotSection>[
      AnalyticsSnapshotSection(
        title: 'Trend Özeti',
        lines: <String>[
          'Trend: ${_snapshotTrendLabel(selected.selection)}',
          'Ciro ${_formatMetric(selected.revenue.currentValue, selected.revenue.metricFormat)}',
          'Sipariş Sayısı ${_formatMetric(selected.orderCount.currentValue, selected.orderCount.metricFormat)}',
        ],
      ),
    ],
    notes: _localizedDataNotes(summary.dataQualityNotes),
  );
}

AnalyticsExport buildAdminAnalyticsExport({
  required RevenueSummary summary,
  required AnalyticsPeriodSelection periodSelection,
  required AnalyticsComparisonMode comparisonMode,
  required Insight? selectedInsight,
}) {
  final AnalyticsSnapshot snapshot = buildAdminAnalyticsSnapshot(
    summary: summary,
    periodSelection: periodSelection,
    comparisonMode: comparisonMode,
    selectedInsight: selectedInsight,
  );
  return AnalyticsExport(
    title: 'EPOS Analiz Raporu',
    periodLabel: snapshot.periodLabel,
    kpis: <String, dynamic>{
      for (final AnalyticsSnapshotKpi kpi in snapshot.kpis)
        kpi.title: kpi.value,
    },
    highlights: snapshot.insights
        .map((Insight insight) => '${insight.title}: ${insight.message}')
        .toList(growable: false),
    notes: snapshot.notes,
  );
}

Insight? _primaryMessageInsight(
  List<Insight> insights,
  RevenueSelectedPeriodSummary selected,
) {
  if (selected.revenue.previousValue == 0) {
    return null;
  }
  if (insights.isEmpty) {
    return null;
  }
  for (final Insight insight in insights) {
    if (_isMeaningfulInsight(insight)) {
      return insight;
    }
  }
  return insights.first;
}

List<Insight> _secondaryInsights(List<Insight> insights, Insight? primary) {
  final List<String> preferredCodes = <String>[
    'period_revenue_delta',
    'period_order_count_delta',
    'period_average_order_value_delta',
    'period_payment_mix',
    'period_cancelled_order_delta',
    'strongest_day',
    'peak_hours',
  ];
  final Set<String> seenGroups = <String>{};
  final List<Insight> results = <Insight>[];
  for (final String code in preferredCodes) {
    final Insight? match = _findInsight(insights, code);
    if (match == null ||
        match.code == primary?.code ||
        !_isMeaningfulInsight(match)) {
      continue;
    }
    final String group = _insightGroup(match.code);
    if (!seenGroups.add(group)) {
      continue;
    }
    results.add(match);
    if (results.length == 3) {
      break;
    }
  }
  return results;
}

String _insightGroup(String code) {
  if (code.contains('revenue')) {
    return 'revenue';
  }
  if (code.contains('average_order_value')) {
    return 'aov';
  }
  if (code.contains('order_count')) {
    return 'orders';
  }
  if (code.contains('cancelled')) {
    return 'cancel';
  }
  if (code.contains('payment_mix')) {
    return 'payment_mix';
  }
  if (code.contains('strongest_day') || code.contains('weakest_day')) {
    return 'day';
  }
  if (code == 'peak_hours' || code == 'low_hours') {
    return 'hours';
  }
  return code;
}

DailyRevenuePoint? _selectedTrendPoint(
  List<DailyRevenuePoint> points,
  DateTime? selectedTrendDate,
) {
  if (points.isEmpty) {
    return null;
  }
  if (selectedTrendDate == null) {
    return null;
  }
  for (final DailyRevenuePoint point in points) {
    if (_isSameDate(point.date, selectedTrendDate)) {
      return point;
    }
  }
  return null;
}

Insight? _findInsight(List<Insight> insights, String code) {
  for (final Insight insight in insights) {
    if (insight.code == code) {
      return insight;
    }
  }
  return null;
}

_TrendLine _trendLine(
  RevenueComparison comparison,
  AnalyticsPeriodSelection selection,
) {
  if (comparison.previousValue == 0) {
    return const _TrendLine(
      label: 'Karşılaştırma verisi yok',
      color: AppColors.textSecondary,
    );
  }
  if (comparison.isFlat) {
    return _TrendLine(
      label: 'Değişim yok · ${_comparisonReference(selection)}',
      color: AppColors.textSecondary,
    );
  }
  final double? percentage = comparison.percentageChange;
  if (percentage == null) {
    return const _TrendLine(
      label: 'Karşılaştırma verisi yok',
      color: AppColors.textSecondary,
    );
  }
  final String direction = comparison.absoluteChange > 0 ? 'artış' : 'düşüş';
  final Color color = comparison.absoluteChange > 0
      ? AppColors.success
      : AppColors.error;
  return _TrendLine(
    label:
        '%${_formatPercent(percentage.abs())} $direction · ${_comparisonReference(selection)}',
    color: color,
  );
}

String _formatMetric(int value, RevenueMetricFormat format) {
  return switch (format) {
    RevenueMetricFormat.currencyMinor => CurrencyFormatter.fromMinor(value),
    RevenueMetricFormat.count => '$value',
  };
}

String _comparisonReference(AnalyticsPeriodSelection selection) {
  return switch (selection.preset) {
    AnalyticsPresetPeriod.today => 'düne göre',
    AnalyticsPresetPeriod.thisWeek => 'geçen haftaya göre',
    AnalyticsPresetPeriod.thisMonth => 'geçen aya göre',
    AnalyticsPresetPeriod.last14Days => 'önceki eşdeğer döneme göre',
    null => 'önceki eşdeğer döneme göre',
  };
}

_PaymentMixDisplay _paymentMixDisplay({
  required RevenuePaymentMixComparison mix,
  required int totalRevenueMinor,
}) {
  final int cash = mix.cashRevenue.currentValue;
  final int card = mix.cardRevenue.currentValue;
  final int total = cash + card;
  final int previousTotal =
      mix.cashRevenue.previousValue + mix.cardRevenue.previousValue;
  if (totalRevenueMinor == 0 && total == 0) {
    return const _PaymentMixDisplay(
      headline: 'Henüz ödeme geliri yok',
      supportingLabel: 'Ödeme dağılımı, ödenmiş ciro oluştuktan sonra görünür.',
      isUnavailable: true,
    );
  }
  if (totalRevenueMinor > 0 && total == 0 && previousTotal == 0) {
    return const _PaymentMixDisplay(
      headline: 'Ödeme dağılımı mevcut değil',
      supportingLabel: 'Ciro var, ancak ödeme dağılımı verisi dönmedi.',
      isUnavailable: true,
    );
  }
  if (totalRevenueMinor > 0 && total == 0) {
    return const _PaymentMixDisplay(
      headline: 'Ödeme dağılımı eksik',
      supportingLabel:
          'Ciro olan bir dönem için nakit ve kart toplamları sıfır görünüyor.',
      isUnavailable: true,
    );
  }
  if ((totalRevenueMinor == 0 && total > 0) ||
      (totalRevenueMinor > 0 && total != totalRevenueMinor)) {
    return const _PaymentMixDisplay(
      headline: 'Ödeme dağılımı eksik',
      supportingLabel:
          'Nakit ve kart toplamı, seçili dönem cirosu ile uyuşmuyor.',
      isUnavailable: true,
    );
  }
  final double cashShare = total == 0 ? 0 : (cash / total) * 100;
  final double cardShare = total == 0 ? 0 : (card / total) * 100;
  return _PaymentMixDisplay(
    headline: 'Ödeme Dağılımı',
    cashAmountLabel: CurrencyFormatter.fromMinor(cash),
    cardAmountLabel: CurrencyFormatter.fromMinor(card),
    cashShareLabel: '%${_formatPercent(cashShare)}',
    cardShareLabel: '%${_formatPercent(cardShare)}',
  );
}

String _selectedPeriodDisplayLabel(RevenueSelectedPeriodSummary selected) {
  if (selected.selection.isCustom) {
    return 'Özel Aralık: ${_dateRangeLabel(selected.startDate, selected.endDate)}';
  }
  return switch (selected.selection.preset) {
    AnalyticsPresetPeriod.today => 'Bugün',
    AnalyticsPresetPeriod.thisWeek => 'Bu Hafta (Pzt → Bugün)',
    AnalyticsPresetPeriod.thisMonth => 'Bu Ay (1 → Bugün)',
    AnalyticsPresetPeriod.last14Days => 'Son 14 Gün',
    null => 'Özel Aralık',
  };
}

String _snapshotComparisonLine(
  RevenueComparison comparison,
  AnalyticsPeriodSelection selection,
) {
  return _trendLine(comparison, selection).label;
}

_SeverityStyle _severityStyle(InsightSeverity severity) {
  return switch (severity) {
    InsightSeverity.positive => const _SeverityStyle(
      background: Color(0xFFF1FAF5),
      border: Color(0xFFD3EEDF),
      foreground: AppColors.success,
      icon: Icons.trending_up_rounded,
    ),
    InsightSeverity.warning => const _SeverityStyle(
      background: Color(0xFFFFF8EA),
      border: Color(0xFFF3E0B2),
      foreground: AppColors.warning,
      icon: Icons.warning_amber_rounded,
    ),
    InsightSeverity.negative => const _SeverityStyle(
      background: Color(0xFFFFF2F1),
      border: Color(0xFFF0CBC8),
      foreground: AppColors.error,
      icon: Icons.trending_down_rounded,
    ),
    InsightSeverity.info => const _SeverityStyle(
      background: Color(0xFFF4F7FA),
      border: Color(0xFFDCE4EC),
      foreground: AppColors.primary,
      icon: Icons.info_outline_rounded,
    ),
  };
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
    border: Border.all(color: AppColors.border),
  );
}

String _comparisonModeShortLabel(AnalyticsComparisonMode mode) {
  return switch (mode) {
    AnalyticsComparisonMode.baselineSummary => 'Standart',
    AnalyticsComparisonMode.previousEquivalentPeriod => 'Önceki Dönem',
    AnalyticsComparisonMode.momentumView => 'İvme',
  };
}

String _dateRangeLabel(DateTime start, DateTime end) {
  final DateFormat formatter = DateFormat('d MMM y', 'tr_TR');
  if (_isSameDate(start, end)) {
    return formatter.format(start);
  }
  return '${formatter.format(start)} - ${formatter.format(end)}';
}

String _headerPeriodLabel(RevenueSelectedPeriodSummary selected) {
  if (selected.selection.isCustom) {
    return 'Özel Aralık: ${_dateRangeLabel(selected.startDate, selected.endDate)}';
  }
  return _selectionLabel(selected.selection);
}

String _trendTitle(AnalyticsPeriodSelection selection) {
  return selection.isCustom ? 'Seçili Aralık Trendi' : 'Son 14 Gün Trendi';
}

String _trendSubtitle({
  required AnalyticsPeriodSelection selection,
  required String periodLabel,
}) {
  if (selection.isCustom) {
    return 'Seçili aralıktaki günlük ciro görünümü.';
  }
  return '$periodLabel seçiminin dışında, son 14 günün günlük ciro görünümü.';
}

String _snapshotTrendLabel(AnalyticsPeriodSelection selection) {
  return selection.isCustom ? 'Seçili Aralık' : 'Son 14 Gün';
}

_PrimaryMessageDisplay _buildPrimaryMessageDisplay({
  required RevenueSelectedPeriodSummary selected,
  required Insight? insight,
}) {
  final int currentRevenue = selected.revenue.currentValue;
  final int previousRevenue = selected.revenue.previousValue;
  final int currentOrders = selected.orderCount.currentValue;
  final int previousOrders = selected.orderCount.previousValue;
  if (currentRevenue == 0 && previousRevenue == 0) {
    return const _PrimaryMessageDisplay(
      headline: 'Seçili dönemde tamamlanmış sipariş bulunmuyor.',
      secondaryText: 'Önceki eşdeğer dönemde de ödenmiş ciro bulunmuyor.',
      severity: InsightSeverity.info,
    );
  }
  if (currentRevenue == 0 && previousRevenue > 0) {
    return _PrimaryMessageDisplay(
      headline: 'Seçili dönemde ödenmiş ciro oluşmadı.',
      secondaryText:
          'Önceki eşdeğer dönemde ${CurrencyFormatter.fromMinor(previousRevenue)} ciro ve $previousOrders tamamlanmış sipariş vardı.',
      severity: InsightSeverity.negative,
    );
  }
  if (previousRevenue == 0) {
    return _PrimaryMessageDisplay(
      headline:
          'Seçili dönemde $currentOrders tamamlanmış siparişten ${CurrencyFormatter.fromMinor(currentRevenue)} ciro elde edildi.',
      secondaryText: 'Önceki eşdeğer dönemde ödenmiş ciro bulunmuyor.',
      severity: InsightSeverity.info,
    );
  }
  if (insight != null) {
    final Insight localized = _localizeInsight(insight, selected.selection);
    return _PrimaryMessageDisplay(
      headline: localized.message,
      severity: localized.severity,
    );
  }
  return _PrimaryMessageDisplay(
    headline:
        'Seçili dönemde $currentOrders tamamlanmış siparişten ${CurrencyFormatter.fromMinor(currentRevenue)} ciro elde edildi.',
    severity: InsightSeverity.info,
  );
}

List<DailyRevenuePoint> _trendPointsForDisplay({
  required RevenueSummary summary,
  required RevenueSelectedPeriodSummary selected,
}) {
  if (!selected.selection.isCustom) {
    return summary.dailyTrend;
  }
  return summary.dailyTrend
      .where(
        (DailyRevenuePoint point) =>
            !_isBeforeDate(point.date, selected.startDate) &&
            !_isAfterDate(point.date, selected.endDate),
      )
      .toList(growable: false);
}

List<Widget> _trendSummaryChips({
  required DailyRevenuePoint? selectedPoint,
  required RevenueSelectedPeriodSummary selectedPeriodSummary,
}) {
  if (selectedPoint == null) {
    return <Widget>[
      _TrendSummaryChip(
        label: 'Ciro',
        value: _formatMetric(
          selectedPeriodSummary.revenue.currentValue,
          selectedPeriodSummary.revenue.metricFormat,
        ),
      ),
      _TrendSummaryChip(
        label: 'Sipariş Sayısı',
        value: _formatMetric(
          selectedPeriodSummary.orderCount.currentValue,
          selectedPeriodSummary.orderCount.metricFormat,
        ),
      ),
    ];
  }
  return <Widget>[
    _TrendSummaryChip(
      label: 'Seçili Gün',
      value: _formatDateTr(selectedPoint.date, includeYear: false),
    ),
    _TrendSummaryChip(
      label: 'Ciro',
      value: CurrencyFormatter.fromMinor(selectedPoint.revenueMinor),
    ),
    _TrendSummaryChip(
      label: 'Sipariş Sayısı',
      value: '${selectedPoint.orderCount}',
    ),
  ];
}

bool _isMeaningfulInsight(Insight insight) {
  final Map<String, dynamic> evidence = insight.evidence;
  switch (insight.code) {
    case 'period_revenue_delta':
    case 'period_order_count_delta':
    case 'period_average_order_value_delta':
    case 'period_cancelled_order_delta':
      final int current = _evidenceInt(evidence, 'current_value');
      final int previous = _evidenceInt(evidence, 'previous_value');
      final int absoluteChange = _evidenceInt(
        evidence,
        'absolute_change',
      ).abs();
      if (previous == 0) {
        return false;
      }
      if (insight.code == 'period_cancelled_order_delta' &&
          current <= 1 &&
          previous <= 1) {
        return false;
      }
      if (insight.code == 'period_order_count_delta' && absoluteChange < 2) {
        return false;
      }
      return true;
    case 'period_payment_mix':
      return _evidenceInt(evidence, 'cash_revenue_minor') +
              _evidenceInt(evidence, 'card_revenue_minor') >
          0;
    case 'strongest_day':
    case 'weakest_day':
    case 'peak_hours':
    case 'low_hours':
      return _evidenceInt(evidence, 'revenue_minor') > 0;
    case 'revenue_momentum_14d':
      final num? percentage = _evidenceNum(evidence, 'percentage_change');
      return percentage != null && percentage.abs() >= 5;
    default:
      return true;
  }
}

int _deterministicInsightSort(Insight left, Insight right) {
  final int codeComparison = left.code.compareTo(right.code);
  if (codeComparison != 0) {
    return codeComparison;
  }
  final int titleComparison = left.title.compareTo(right.title);
  if (titleComparison != 0) {
    return titleComparison;
  }
  return left.message.compareTo(right.message);
}

int _evidenceInt(Map<String, dynamic> evidence, String key) {
  final Object? value = evidence[key];
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

num? _evidenceNum(Map<String, dynamic> evidence, String key) {
  final Object? value = evidence[key];
  return value is num ? value : null;
}

bool _isBeforeDate(DateTime left, DateTime right) {
  return DateTime.utc(
    left.year,
    left.month,
    left.day,
  ).isBefore(DateTime.utc(right.year, right.month, right.day));
}

bool _isAfterDate(DateTime left, DateTime right) {
  return DateTime.utc(
    left.year,
    left.month,
    left.day,
  ).isAfter(DateTime.utc(right.year, right.month, right.day));
}

Insight _localizeInsight(Insight insight, AnalyticsPeriodSelection selection) {
  return Insight(
    code: insight.code,
    severity: insight.severity,
    title: _localizedInsightTitle(insight, selection),
    message: _localizedInsightMessage(insight, selection),
    evidence: insight.evidence,
  );
}

String _localizedInsightTitle(
  Insight insight,
  AnalyticsPeriodSelection selection,
) {
  return switch (insight.code) {
    'period_revenue_delta' => '${_selectionLabel(selection)} Ciro',
    'period_order_count_delta' => 'Sipariş Sayısı',
    'period_average_order_value_delta' => 'Ortalama Sipariş Tutarı',
    'period_payment_mix' => 'Ödeme Dağılımı',
    'period_cancelled_order_delta' => 'İptal Edilen Siparişler',
    'revenue_momentum_14d' => '14 Günlük Ciro Trendi',
    'strongest_day' => 'En Güçlü Gün',
    'peak_hours' => 'Yoğun Saatler',
    'top_product_current_period' => 'Öne Çıkan Ürün',
    'legacy_fallback' => 'Analiz Özeti',
    _ => insight.title,
  };
}

String _localizedInsightMessage(
  Insight insight,
  AnalyticsPeriodSelection selection,
) {
  final Map<String, dynamic> evidence = insight.evidence;
  switch (insight.code) {
    case 'period_revenue_delta':
      return _localizedDeltaSentence(
        subject: '${_selectionLabel(selection)} ciro',
        comparison: _comparisonReference(selection),
        currentValue: _evidenceInt(evidence, 'current_value'),
        previousValue: _evidenceInt(evidence, 'previous_value'),
        valueFormatter: (int value) => CurrencyFormatter.fromMinor(value),
        increaseVerb: 'daha yüksek',
        decreaseVerb: 'daha düşük',
      );
    case 'period_order_count_delta':
      return _localizedDeltaSentence(
        subject: 'Sipariş sayısı',
        comparison: _comparisonReference(selection),
        currentValue: _evidenceInt(evidence, 'current_value'),
        previousValue: _evidenceInt(evidence, 'previous_value'),
        valueFormatter: (int value) => '$value',
        increaseVerb: 'arttı',
        decreaseVerb: 'azaldı',
        includeArrowValues: true,
      );
    case 'period_average_order_value_delta':
      return _localizedDeltaSentence(
        subject: 'Ortalama sipariş tutarı',
        comparison: _comparisonReference(selection),
        currentValue: _evidenceInt(evidence, 'current_value'),
        previousValue: _evidenceInt(evidence, 'previous_value'),
        valueFormatter: (int value) => CurrencyFormatter.fromMinor(value),
        increaseVerb: 'arttı',
        decreaseVerb: 'azaldı',
        includeArrowValues: true,
      );
    case 'period_payment_mix':
      final int cash = _evidenceInt(evidence, 'cash_revenue_minor');
      final int card = _evidenceInt(evidence, 'card_revenue_minor');
      if (cash + card == 0) {
        return 'Seçili dönem için ödeme dağılımı bulunmuyor.';
      }
      return 'Ödeme dağılımı: nakit ${CurrencyFormatter.fromMinor(cash)} (%${_formatPercent(_evidenceNum(evidence, 'cash_share_percent')?.toDouble() ?? 0)}), kart ${CurrencyFormatter.fromMinor(card)} (%${_formatPercent(_evidenceNum(evidence, 'card_share_percent')?.toDouble() ?? 0)}).';
    case 'period_cancelled_order_delta':
      return _localizedDeltaSentence(
        subject: 'İptal edilen sipariş sayısı',
        comparison: _comparisonReference(selection),
        currentValue: _evidenceInt(evidence, 'current_value'),
        previousValue: _evidenceInt(evidence, 'previous_value'),
        valueFormatter: (int value) => '$value',
        increaseVerb: 'arttı',
        decreaseVerb: 'azaldı',
        includeArrowValues: true,
      );
    case 'revenue_momentum_14d':
      final num? percentage = _evidenceNum(evidence, 'percentage_change');
      if (percentage == null) {
        return 'Son 14 günün ciro trendi dengeli seyrediyor.';
      }
      final String direction = percentage >= 0 ? 'yükseldi' : 'geriledi';
      return 'Son 14 günde ciro %${_formatPercent(percentage.abs().toDouble())} $direction.';
    case 'strongest_day':
      final Object? rawDate = evidence['date'];
      final int revenueMinor = _evidenceInt(evidence, 'revenue_minor');
      if (rawDate is String && rawDate.trim().isNotEmpty) {
        final DateTime? parsed = DateTime.tryParse(rawDate);
        if (parsed != null) {
          return 'En güçlü gün ${_formatDateTr(parsed)}; ciro ${CurrencyFormatter.fromMinor(revenueMinor)}.';
        }
      }
      return 'En güçlü gün verisi bulunmuyor.';
    case 'peak_hours':
      final int? startHour = _evidenceNum(evidence, 'start_hour')?.toInt();
      final int? endHour = _evidenceNum(
        evidence,
        'end_hour_exclusive',
      )?.toInt();
      if (startHour == null || endHour == null) {
        return 'Yoğun saat verisi bulunmuyor.';
      }
      return 'En yoğun saat aralığı ${_hourRange(startHour, endHour)}.';
    case 'top_product_current_period':
      final String productName = _sanitizeDisplayText(
        '${evidence['current_product_name'] ?? evidence['product_name'] ?? ''}',
      ).trim();
      if (productName.isEmpty) {
        return 'Seçili dönemde öne çıkan ürün bilgisi bulunmuyor.';
      }
      return 'Seçili dönemde öne çıkan ürün $productName.';
    case 'legacy_fallback':
      return 'Seçili dönem için özet analiz hazır.';
    default:
      return _sanitizeDisplayText(insight.message);
  }
}

String _localizedDeltaSentence({
  required String subject,
  required String comparison,
  required int currentValue,
  required int previousValue,
  required String Function(int value) valueFormatter,
  required String increaseVerb,
  required String decreaseVerb,
  bool includeArrowValues = false,
}) {
  if (previousValue == 0) {
    return '$subject için karşılaştırma verisi bulunmuyor.';
  }
  if (currentValue == previousValue) {
    return '$subject, $comparison değişmedi.';
  }
  final double percentage =
      (((currentValue - previousValue) / previousValue) * 100).abs();
  final bool increased = currentValue > previousValue;
  final StringBuffer buffer = StringBuffer()
    ..write(subject)
    ..write(', ')
    ..write(comparison)
    ..write(' %')
    ..write(_formatPercent(percentage))
    ..write(' ')
    ..write(increased ? increaseVerb : decreaseVerb);
  if (includeArrowValues) {
    buffer
      ..write(' (')
      ..write(valueFormatter(previousValue))
      ..write(' → ')
      ..write(valueFormatter(currentValue))
      ..write(')');
  }
  buffer.write('.');
  return buffer.toString();
}

int _chargeReasonRevenue(
  SemanticSalesAnalytics analytics,
  ModifierChargeReason reason,
) {
  for (final SemanticChargeReasonAnalytics entry
      in analytics.chargeReasonBreakdown) {
    if (entry.chargeReason == reason) {
      return entry.revenueMinor;
    }
  }
  return 0;
}

int _chargeReasonEvents(
  SemanticSalesAnalytics analytics,
  ModifierChargeReason reason,
) {
  for (final SemanticChargeReasonAnalytics entry
      in analytics.chargeReasonBreakdown) {
    if (entry.chargeReason == reason) {
      return entry.eventCount;
    }
  }
  return 0;
}

String _bundleVariantSummary(SemanticBundleVariantAnalytics variant) {
  String formatItems(String label, List<String> items) {
    if (items.isEmpty) {
      return '$label yok';
    }
    return '$label ${items.map(_semanticDisplayLabel).join(', ')}';
  }

  return <String>[
    formatItems('Seçim', variant.chosenItemNames),
    formatItems('Çıkarma', variant.removedItemNames),
    formatItems('Ek', variant.addedItemNames),
  ].join(' · ');
}

List<String> _localizedDataNotes(List<String> notes) {
  return notes.map(_localizeDataNote).toList(growable: false);
}

String _localizeDataNote(String note) {
  if (note.startsWith('Choice-group analytics for root product ') &&
      note.contains('current configuration no longer contains that group')) {
    return 'Bazı geçmiş seçim grupları mevcut menüde bulunmadığı için arşivlenmiş grup kimliğiyle gösteriliyor.';
  }
  if (note.startsWith('Choice-group analytics for root product ') &&
      note.contains(
        'current configuration no longer matches that historical membership',
      )) {
    return 'Bazı geçmiş seçimler mevcut üyelik yapısı değiştiği için satış anındaki kayıtlarla gösteriliyor.';
  }
  if (note.startsWith('Legacy semantic modifier rows for root product ') &&
      note.contains(
        'missing source group IDs and cannot be fully grouped after the live configuration was removed',
      )) {
    return 'Eski semantic satışlarda kaynak grup kimliği bulunmadığı için kaldırılmış gruplar tam olarak ayrıştırılamadı.';
  }
  return switch (note) {
    'refunds not available in remote analytics' =>
      'İade verileri uzaktan analiz sistemine dahil değildir.',
    'true shift intelligence unavailable because shifts are not mirrored' =>
      'Vardiya verileri aynalanmadığı için vardiya bazlı analiz kullanılamıyor.',
    'product mover aggregation is name-based because stable mirrored product identifiers were unavailable for part of the dataset' =>
      'Ürün hareketleri, kararlı ürün kimlikleri eksik olduğu için ad bazlı gruplanmıştır.',
    'cancelled attribution unavailable for some mirror rows because reliable cancelled_at was missing' =>
      'Bazı iptal kayıtlarında güvenilir iptal zamanı bulunmadığı için dönem ataması sınırlıdır.',
    'cancelled attribution unavailable for some mirror rows because cancelled_at was invalid' =>
      'Bazı iptal kayıtlarında geçersiz iptal zamanı bulunduğu için dönem ataması sınırlıdır.',
    'Legacy semantic modifier rows without persisted source group IDs were inferred from the current semantic configuration.' =>
      'Eski semantic satışlarda kaynak grup kimliği saklanmadığı için bazı seçimler mevcut menü yapılandırmasından türetildi.',
    'Insufficient data for reliable comparison' =>
      'Güvenilir karşılaştırma için yeterli veri bulunmuyor.',
    _ => _sanitizeDisplayText(note),
  };
}

String _semanticDisplayLabel(String value) {
  final String cleaned = _sanitizeDisplayText(value).trim();
  if (cleaned.isEmpty) {
    return 'Arşivlenmiş öğe';
  }
  final RegExpMatch? groupMatch = RegExp(r'^Group #(\d+)$').firstMatch(cleaned);
  if (groupMatch != null) {
    return 'Arşiv grup #${groupMatch.group(1)}';
  }
  final RegExpMatch? productMatch = RegExp(
    r'^Product (\d+)$',
  ).firstMatch(cleaned);
  if (productMatch != null) {
    return 'Ürün #${productMatch.group(1)}';
  }
  return cleaned;
}

String _selectionLabel(AnalyticsPeriodSelection selection) {
  return switch (selection.preset) {
    AnalyticsPresetPeriod.today => 'Bugün',
    AnalyticsPresetPeriod.thisWeek => 'Bu Hafta',
    AnalyticsPresetPeriod.thisMonth => 'Bu Ay',
    AnalyticsPresetPeriod.last14Days => 'Son 14 Gün',
    null => 'Özel Aralık',
  };
}

String _formatPercent(double value) {
  if (!value.isFinite) {
    return '0';
  }
  final double normalized = value >= 100
      ? value.roundToDouble()
      : double.parse(value.toStringAsFixed(1));
  if (normalized == normalized.truncateToDouble()) {
    return normalized.toInt().toString();
  }
  return normalized.toStringAsFixed(1);
}

String _formatDateTr(DateTime value, {bool includeYear = true}) {
  return DateFormat(includeYear ? 'd MMM y' : 'd MMM', 'tr_TR').format(value);
}

String _formatDateTimeTr(DateTime value) {
  return DateFormat('d MMM y, HH:mm', 'tr_TR').format(value);
}

String _sanitizeDisplayText(String value) {
  if (value.contains('NaN') ||
      value.contains('Infinity') ||
      value.contains('null')) {
    return value
        .replaceAll('NaN', '0')
        .replaceAll('Infinity', '0')
        .replaceAll('null', '');
  }
  return value;
}

String _hourRange(int startHour, int endHour) {
  final String start = startHour.toString().padLeft(2, '0');
  final String end = endHour.toString().padLeft(2, '0');
  return '$start:00-$end:00';
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}
