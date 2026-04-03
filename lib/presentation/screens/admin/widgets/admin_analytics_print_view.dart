import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/analytics/analytics_export.dart';
import '../../../../domain/models/analytics/analytics_snapshot.dart';
import '../../../../domain/models/revenue_intelligence_inputs.dart';
import '../../../../domain/models/revenue_summary.dart';
import 'admin_analytics_print_support.dart';

class AdminAnalyticsPrintView extends StatelessWidget {
  const AdminAnalyticsPrintView({
    required this.summary,
    required this.snapshot,
    required this.export,
    super.key,
  });

  final RevenueSummary summary;
  final AnalyticsSnapshot snapshot;
  final AnalyticsExport export;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 980, maxHeight: 860),
      color: Colors.white,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSizes.spacingLg),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        export.title,
                        style: const TextStyle(
                          fontSize: AppSizes.fontLg,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingXs),
                      Text(
                        '${snapshot.periodLabel} · ${snapshot.comparisonModeLabel}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
                const SizedBox(width: AppSizes.spacingSm),
                FilledButton.icon(
                  onPressed: () => _handlePrint(context),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.spacingXl),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: AppSizes.spacingMd,
                      runSpacing: AppSizes.spacingMd,
                      children: snapshot.kpis
                          .map(
                            (AnalyticsSnapshotKpi kpi) =>
                                _PrintMetricCard(kpi: kpi),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: AppSizes.spacingXl),
                    _PrintSection(
                      title: 'Top Insights',
                      children: snapshot.insights
                          .map(
                            (dynamic insight) => _PrintBulletLine(
                              title: insight.title,
                              value: insight.message,
                            ),
                          )
                          .toList(growable: false),
                    ),
                    _PrintSection(
                      title: 'Payment Mix',
                      children: snapshot.kpis
                          .where(
                            (AnalyticsSnapshotKpi kpi) =>
                                kpi.title == 'Payment Mix',
                          )
                          .map(
                            (AnalyticsSnapshotKpi kpi) => _PrintBulletLine(
                              title: kpi.title,
                              value: kpi.supportingLabel == null
                                  ? kpi.value
                                  : '${kpi.value} · ${kpi.supportingLabel!}',
                            ),
                          )
                          .toList(growable: false),
                    ),
                    _PrintSection(
                      title: 'Daypart Summary',
                      children: summary.intelligenceInputs.daypartDistribution
                          .map(
                            (RevenueDaypartPoint point) => _PrintBulletLine(
                              title: _labelDaypart(point.daypart),
                              value:
                                  '${CurrencyFormatter.fromMinor(point.revenueMinor)} · ${point.orderCount} orders',
                            ),
                          )
                          .toList(growable: false),
                    ),
                    _PrintSection(
                      title: 'Product Movers',
                      children: summary.intelligenceInputs.topProductsCurrentPeriod
                          .map(
                            (RevenueProductMover mover) => _PrintBulletLine(
                              title: mover.productName,
                              value:
                                  '${CurrencyFormatter.fromMinor(mover.revenueMinor)} · ${mover.quantitySold} sold',
                            ),
                          )
                          .toList(growable: false),
                    ),
                    if (summary.dataQualityNotes.isNotEmpty)
                      _PrintSection(
                        title: 'Data Notes',
                        children: summary.dataQualityNotes
                            .map(
                              (String note) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSizes.spacingSm,
                                ),
                                child: Text('• $note'),
                              ),
                            )
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePrint(BuildContext context) async {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    final bool triggered = await triggerAdminAnalyticsBrowserPrint();
    if (!context.mounted || messenger == null) {
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          triggered
              ? 'Print dialog opened'
              : 'Use the system print action from this print-friendly view.',
        ),
      ),
    );
  }
}

class _PrintMetricCard extends StatelessWidget {
  const _PrintMetricCard({required this.kpi});

  final AnalyticsSnapshotKpi kpi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kpi.title,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.spacingXs),
          Text(
            kpi.value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (kpi.supportingLabel != null) ...<Widget>[
            const SizedBox(height: AppSizes.spacingXs),
            Text(
              kpi.supportingLabel!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _PrintSection extends StatelessWidget {
  const _PrintSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          ...children,
        ],
      ),
    );
  }
}

class _PrintBulletLine extends StatelessWidget {
  const _PrintBulletLine({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Text('• $title: $value'),
    );
  }
}

String _labelDaypart(String value) {
  return switch (value) {
    'breakfast' => 'Breakfast',
    'lunch' => 'Lunch',
    'afternoon' => 'Afternoon',
    'evening' => 'Evening',
    'late' => 'Late',
    _ => value,
  };
}
