import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/daily_revenue_point.dart';
import '../../../domain/models/hourly_distribution.dart';
import '../../../domain/models/revenue_comparison.dart';
import '../../../domain/models/revenue_summary.dart';
import '../../../domain/models/weekly_revenue_point.dart';
import '../../providers/admin_revenue_analytics_provider.dart';
import 'widgets/admin_scaffold.dart';

const String _analyticsTitle = 'Revenue Analytics';
const String _dailyTrendTitle = 'Daily Revenue Trend';
const String _weeklySummaryTitle = 'Weekly Revenue Summary';
const String _hourlyDistributionTitle = 'Hourly Distribution';
const String _insightsTitle = 'Derived Insights';

class AdminRevenueAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminRevenueAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminRevenueAnalyticsScreen> createState() =>
      _AdminRevenueAnalyticsScreenState();
}

class _AdminRevenueAnalyticsScreenState
    extends ConsumerState<AdminRevenueAnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(adminRevenueAnalyticsNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AdminRevenueAnalyticsState state = ref.watch(
      adminRevenueAnalyticsNotifierProvider,
    );
    final RevenueSummary? summary = state.summary;

    return AdminScaffold(
      title: _analyticsTitle,
      currentRoute: '/admin/analytics',
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(adminRevenueAnalyticsNotifierProvider.notifier).load(),
        child: ListView(
          children: <Widget>[
            if (state.errorMessage != null)
              _Banner(message: state.errorMessage!, color: AppColors.error),
            if (state.isLoading && summary == null)
              const Padding(
                padding: EdgeInsets.all(AppSizes.spacingXl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (summary != null) ...<Widget>[
              _Banner(
                message:
                    'Source: paid Supabase mirror transactions only. Generated ${DateFormat('dd MMM yyyy HH:mm').format(summary.generatedAt)} (${summary.timezone}).',
              ),
              const SizedBox(height: AppSizes.spacingMd),
              if (!summary.hasPaidData)
                const _Banner(
                  message:
                      'No paid transactions were returned for the current analytics window. Charts remain zero-filled instead of showing missing data.',
                  color: AppColors.warning,
                ),
              if (!summary.hasPaidData)
                const SizedBox(height: AppSizes.spacingMd),
              Wrap(
                spacing: AppSizes.spacingMd,
                runSpacing: AppSizes.spacingMd,
                children: <Widget>[
                  _KpiCard(
                    title: 'Today revenue',
                    comparisonLabel: 'vs yesterday',
                    comparison: summary.todayRevenue,
                  ),
                  _KpiCard(
                    title: 'This week revenue',
                    comparisonLabel: 'vs last week',
                    comparison: summary.thisWeekRevenue,
                  ),
                  _KpiCard(
                    title: 'This month revenue',
                    comparisonLabel: 'vs last month',
                    comparison: summary.thisMonthRevenue,
                  ),
                  _KpiCard(
                    title: 'Average order value',
                    subtitle: 'Current week',
                    comparisonLabel: 'vs last week',
                    comparison: summary.averageOrderValueCurrentWeek,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spacingLg),
              _ChartPanel(
                title: _dailyTrendTitle,
                subtitle: 'Last 14 days with zero-filled gaps',
                child: _DailyRevenueLineChart(points: summary.dailyTrend),
              ),
              const SizedBox(height: AppSizes.spacingLg),
              _ChartPanel(
                title: _weeklySummaryTitle,
                subtitle: 'Last 6 Monday-based business weeks',
                child: _WeeklyRevenueBarChart(points: summary.weeklySummary),
              ),
              const SizedBox(height: AppSizes.spacingLg),
              _ChartPanel(
                title: _hourlyDistributionTitle,
                subtitle: 'Last 14 days, grouped by local business hour',
                child: _HourlyDistributionChart(
                  hourlyDistribution: summary.hourlyDistribution,
                ),
              ),
              const SizedBox(height: AppSizes.spacingLg),
              _ChartPanel(
                title: _insightsTitle,
                subtitle: 'Backend/domain-derived commentary',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: summary.insights.messages
                      .map((String message) => _InsightTile(message: message))
                      .toList(growable: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.comparison,
    this.subtitle,
    this.comparisonLabel,
  });

  final String title;
  final String? subtitle;
  final String? comparisonLabel;
  final RevenueComparison comparison;

  @override
  Widget build(BuildContext context) {
    final Color trendColor = comparison.isPositiveChange
        ? AppColors.success
        : comparison.isNegativeChange
        ? AppColors.error
        : AppColors.textSecondary;

    return Container(
      constraints: const BoxConstraints(minWidth: 250, maxWidth: 320),
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: AppSizes.spacingXs),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSizes.spacingMd),
          Text(
            _formatMetric(comparison.currentValue, comparison.metricFormat),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            _comparisonLabel(comparison),
            style: TextStyle(fontWeight: FontWeight.w700, color: trendColor),
          ),
          const SizedBox(height: AppSizes.spacingXs),
          Text(
            '${comparisonLabel ?? 'Previous period'}: ${_formatMetric(comparison.previousValue, comparison.metricFormat)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatMetric(int value, RevenueMetricFormat format) {
    return switch (format) {
      RevenueMetricFormat.currencyMinor => CurrencyFormatter.fromMinor(value),
      RevenueMetricFormat.count => '$value',
    };
  }

  String _comparisonLabel(RevenueComparison comparison) {
    final double? percentageChange = comparison.percentageChange;
    if (percentageChange == null) {
      return comparison.currentValue == 0
          ? 'No previous period data'
          : 'New versus previous period';
    }
    if (comparison.isFlat) {
      return '0.0% vs previous period';
    }
    final String prefix = percentageChange > 0 ? '+' : '-';
    return '$prefix${percentageChange.abs().toStringAsFixed(1)}% vs previous period';
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w800,
            ),
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

class _DailyRevenueLineChart extends StatelessWidget {
  const _DailyRevenueLineChart({required this.points});

  final List<DailyRevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Column(
        children: <Widget>[
          Expanded(
            child: CustomPaint(
              painter: _LineChartPainter(points: points),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Row(
            children: points
                .map(
                  (DailyRevenuePoint point) => Expanded(
                    child: Text(
                      DateFormat('d MMM').format(point.date),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _WeeklyRevenueBarChart extends StatelessWidget {
  const _WeeklyRevenueBarChart({required this.points});

  final List<WeeklyRevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    final int maxValue = points.fold<int>(
      0,
      (int current, WeeklyRevenuePoint point) =>
          math.max(current, point.revenueMinor),
    );
    return SizedBox(
      height: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points
            .map(
              (WeeklyRevenuePoint point) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacingXs,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        CurrencyFormatter.fromMinor(point.revenueMinor),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingSm),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: 42,
                            height: maxValue == 0
                                ? 4
                                : (180 * (point.revenueMinor / maxValue))
                                      .clamp(4, 180)
                                      .toDouble(),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusSm,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingSm),
                      Text(
                        DateFormat('d MMM').format(point.weekStart),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _HourlyDistributionChart extends StatelessWidget {
  const _HourlyDistributionChart({required this.hourlyDistribution});

  final List<HourlyDistribution> hourlyDistribution;

  @override
  Widget build(BuildContext context) {
    final int maxRevenue = hourlyDistribution.fold<int>(
      0,
      (int current, HourlyDistribution point) =>
          math.max(current, point.revenueMinor),
    );

    return SizedBox(
      height: 260,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: hourlyDistribution
              .map(
                (HourlyDistribution point) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.spacingXs,
                  ),
                  child: SizedBox(
                    width: 36,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '${point.orderCount}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacingXs),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 22,
                              height: maxRevenue == 0
                                  ? 4
                                  : (160 * (point.revenueMinor / maxRevenue))
                                        .clamp(4, 160)
                                        .toDouble(),
                              decoration: BoxDecoration(
                                color: point.orderCount == 0
                                    ? AppColors.surfaceMuted
                                    : AppColors.success,
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusSm,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacingXs),
                        Text(
                          point.hour.toString().padLeft(2, '0'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSizes.spacingSm),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, this.color = AppColors.primary});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter({required this.points});

  final List<DailyRevenuePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) {
      return;
    }

    final double chartWidth = size.width;
    final double chartHeight = size.height;
    final int maxRevenue = points.fold<int>(
      0,
      (int current, DailyRevenuePoint point) =>
          math.max(current, point.revenueMinor),
    );

    final Paint gridPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Paint linePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final Paint pointPaint = Paint()..color = AppColors.success;

    for (int lineIndex = 0; lineIndex < 4; lineIndex += 1) {
      final double y = (chartHeight / 3) * lineIndex;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    final Path path = Path();
    for (int index = 0; index < points.length; index += 1) {
      final double x = points.length == 1
          ? chartWidth / 2
          : chartWidth * index / (points.length - 1);
      final double ratio = maxRevenue == 0
          ? 0
          : points[index].revenueMinor / maxRevenue;
      final double y = chartHeight - (ratio * (chartHeight - 8)) - 4;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
