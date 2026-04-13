import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/analytics/analytics_date_range.dart';
import '../../../../domain/models/analytics/analytics_detail_preset.dart';
import '../../../../domain/models/analytics/analytics_insight.dart';
import '../../../../domain/models/analytics/overview_metrics.dart';
import '../../../providers/analytics/analytics_insight_provider.dart';
import '../../../providers/analytics/analytics_overview_provider.dart';
import '../widgets/admin_scaffold.dart';
import 'analytics_revenue_screen.dart';
import 'widgets/analytics_kpi_card.dart';
import 'widgets/payment_split_card.dart';
import 'widgets/top_products_preview_card.dart';

const String analyticsOverviewRoute = '/admin/analytics';
const String analyticsRevenueDetailRoute = '/admin/analytics/revenue';
const String analyticsOrdersDetailRoute = '/admin/analytics/orders';
const String analyticsProductsDetailRoute = '/admin/analytics/products';
const String analyticsPaymentsDetailRoute = '/admin/analytics/payments';
const String analyticsProductsDetailTitle = 'Product Analytics';
const String analyticsPaymentsDetailTitle = 'Payment Analytics';

class AnalyticsOverviewScreen extends ConsumerStatefulWidget {
  const AnalyticsOverviewScreen({required this.initialPreset, super.key});

  final AnalyticsDateRangePreset initialPreset;

  @override
  ConsumerState<AnalyticsOverviewScreen> createState() =>
      _AnalyticsOverviewScreenState();
}

class _AnalyticsOverviewScreenState
    extends ConsumerState<AnalyticsOverviewScreen> {
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(analyticsOverviewNotifierProvider.notifier)
          .initialize(preset: widget.initialPreset),
    );
  }

  @override
  void didUpdateWidget(covariant AnalyticsOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPreset != widget.initialPreset) {
      Future<void>.microtask(
        () => ref
            .read(analyticsOverviewNotifierProvider.notifier)
            .loadForPreset(widget.initialPreset),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AnalyticsOverviewState state = ref.watch(
      analyticsOverviewNotifierProvider,
    );
    final AsyncValue<List<AnalyticsInsight>> insightsState = ref.watch(
      analyticsOverviewInsightsProvider,
    );
    final AnalyticsOverviewNotifier notifier = ref.read(
      analyticsOverviewNotifierProvider.notifier,
    );
    final OverviewMetrics metrics =
        state.metrics ?? const OverviewMetrics.empty();

    return AdminScaffold(
      title: 'Analytics Overview',
      currentRoute: analyticsOverviewRoute,
      child: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            _OverviewHeader(
              selectedPreset: state.selectedPreset,
              isExporting: _isExporting,
              onPresetSelected: (AnalyticsDateRangePreset preset) {
                context.go(buildAnalyticsOverviewLocation(preset));
              },
              onExportPressed: () => _exportAnalytics(
                context,
                analyticsDetailExportPresetFromOverviewPreset(
                  state.selectedPreset,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.spacingLg),
            if (state.errorMessage != null && state.metrics == null)
              _OverviewErrorCard(
                message: state.errorMessage!,
                onRetry: notifier.refresh,
              )
            else if (state.isLoading && state.metrics == null)
              const _OverviewLoadingView()
            else
              _OverviewBody(
                metrics: metrics,
                insights:
                    insightsState.valueOrNull ?? const <AnalyticsInsight>[],
                selectedPreset: state.selectedPreset,
                statusMessage: state.errorMessage,
                isRefreshing: state.isLoading && state.metrics != null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAnalytics(
    BuildContext context,
    AnalyticsDetailPreset preset,
  ) async {
    if (_isExporting) {
      return;
    }
    setState(() {
      _isExporting = true;
    });
    try {
      final String exportJson = await ref
          .read(analyticsExportServiceProvider)
          .exportAnalytics(preset: preset);
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Analytics Export'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: SelectableText(
                  exportJson,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              FilledButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: exportJson));
                  if (!context.mounted) {
                    return;
                  }
                  Navigator.of(context).pop();
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Analytics export copied to clipboard'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_all_rounded),
                label: const Text('Copy JSON'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Analytics export failed')));
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}

String buildAnalyticsOverviewLocation(AnalyticsDateRangePreset preset) {
  return Uri(
    path: analyticsOverviewRoute,
    queryParameters: <String, String>{
      'range': analyticsOverviewPresetQueryValue(preset),
    },
  ).toString();
}

String buildAnalyticsRevenueDetailLocation(
  AnalyticsDateRangePreset preset, {
  AnalyticsRevenueDetailEntryPoint entryPoint =
      AnalyticsRevenueDetailEntryPoint.revenue,
}) {
  return buildAnalyticsRevenueRouteLocation(
    preset: analyticsRevenuePresetFromOverviewPreset(preset),
    entryPoint: entryPoint,
  );
}

String buildAnalyticsOrdersDetailLocation(AnalyticsDateRangePreset preset) {
  return buildAnalyticsRevenueRouteLocation(
    path: analyticsOrdersDetailRoute,
    preset: analyticsRevenuePresetFromOverviewPreset(preset),
    entryPoint: AnalyticsRevenueDetailEntryPoint.orders,
  );
}

String buildAnalyticsDetailLocation({
  required String path,
  required AnalyticsDateRangePreset preset,
}) {
  return Uri(
    path: path,
    queryParameters: <String, String>{
      'range': analyticsDateRangePresetQueryValue(
        analyticsDetailPresetFromOverviewPreset(preset),
      ),
    },
  ).toString();
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.selectedPreset,
    required this.isExporting,
    required this.onPresetSelected,
    required this.onExportPressed,
  });

  final AnalyticsDateRangePreset selectedPreset;
  final bool isExporting;
  final ValueChanged<AnalyticsDateRangePreset> onPresetSelected;
  final VoidCallback onExportPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stacked = constraints.maxWidth < 760;
          return Flex(
            direction: stacked ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: <Widget>[
              if (stacked)
                const _OverviewHeaderCopy()
              else
                const Expanded(flex: 2, child: _OverviewHeaderCopy()),
              if (!stacked) const SizedBox(width: AppSizes.spacingLg),
              if (stacked) const SizedBox(height: AppSizes.spacingMd),
              Column(
                crossAxisAlignment: stacked
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: <Widget>[
                  Wrap(
                    spacing: AppSizes.spacingSm,
                    runSpacing: AppSizes.spacingSm,
                    children: kAnalyticsOverviewPresets
                        .map(
                          (AnalyticsDateRangePreset preset) => ChoiceChip(
                            selected: preset == selectedPreset,
                            label: Text(analyticsDateRangePresetLabel(preset)),
                            onSelected: (_) => onPresetSelected(preset),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: AppSizes.spacingSm),
                  OutlinedButton.icon(
                    onPressed: isExporting ? null : onExportPressed,
                    icon: isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      isExporting ? 'Exporting...' : 'Export Analytics',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewHeaderCopy extends StatelessWidget {
  const _OverviewHeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Summary and navigation hub for admin analytics.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppSizes.spacingXs),
        Text(
          'Paid orders only. Revenue, orders, AOV, top products, and payment mix at a glance.',
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.metrics,
    required this.insights,
    required this.selectedPreset,
    required this.statusMessage,
    required this.isRefreshing,
  });

  final OverviewMetrics metrics;
  final List<AnalyticsInsight> insights;
  final AnalyticsDateRangePreset selectedPreset;
  final String? statusMessage;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (isRefreshing)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSizes.spacingSm),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (!metrics.hasData) ...<Widget>[
          const _OverviewStatusBanner(
            message: 'No paid transactions in this period.',
          ),
          const SizedBox(height: AppSizes.spacingMd),
        ] else if (statusMessage != null) ...<Widget>[
          _OverviewStatusBanner(message: statusMessage!),
          const SizedBox(height: AppSizes.spacingMd),
        ],
        AnalyticsKpiCard(
          title: 'Total Revenue',
          icon: Icons.stacked_line_chart_rounded,
          value: CurrencyFormatter.fromMinor(metrics.totalRevenueMinor),
          subtitle: 'Paid transaction total for the selected range',
          isHero: true,
          onTap: () =>
              context.go(buildAnalyticsRevenueDetailLocation(selectedPreset)),
        ),
        const SizedBox(height: AppSizes.spacingLg),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool twoColumns = constraints.maxWidth >= 780;
            if (!twoColumns) {
              return Column(children: _buildCards(context, compact: false));
            }
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: AppSizes.spacingMd,
              mainAxisSpacing: AppSizes.spacingMd,
              childAspectRatio: 1.28,
              children: _buildCards(context, compact: true),
            );
          },
        ),
        if (insights.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSizes.spacingLg),
          _InsightsSection(insights: insights),
        ],
      ],
    );
  }

  List<Widget> _buildCards(BuildContext context, {required bool compact}) {
    final List<Widget> cards = <Widget>[
      AnalyticsKpiCard(
        title: 'Orders',
        icon: Icons.receipt_long_rounded,
        value: '${metrics.orderCount}',
        subtitle: 'Completed paid orders',
        accentColor: AppColors.warningStrong,
        onTap: () =>
            context.go(buildAnalyticsOrdersDetailLocation(selectedPreset)),
      ),
      AnalyticsKpiCard(
        title: 'AOV',
        icon: Icons.calculate_rounded,
        value: CurrencyFormatter.fromMinor(metrics.averageOrderValueMinor),
        subtitle: 'Average order value',
        accentColor: AppColors.primaryStrong,
        onTap: () => context.go(
          buildAnalyticsRevenueDetailLocation(
            selectedPreset,
            entryPoint: AnalyticsRevenueDetailEntryPoint.aov,
          ),
        ),
      ),
      TopProductsPreviewCard(
        products: metrics.topProductsPreview,
        onTap: () => context.go(
          buildAnalyticsDetailLocation(
            path: analyticsProductsDetailRoute,
            preset: selectedPreset,
          ),
        ),
      ),
      PaymentSplitCard(
        summary: metrics.paymentSplitSummary,
        onTap: () => context.go(
          buildAnalyticsDetailLocation(
            path: analyticsPaymentsDetailRoute,
            preset: selectedPreset,
          ),
        ),
      ),
    ];
    if (compact) {
      return cards;
    }
    return cards
        .map(
          (Widget child) => Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
            child: child,
          ),
        )
        .toList(growable: false);
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({required this.insights});

  final List<AnalyticsInsight> insights;

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
          const Text(
            'Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          ...List<Widget>.generate(insights.length, (int index) {
            final AnalyticsInsight insight = insights[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == insights.length - 1 ? 0 : AppSizes.spacingSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: _insightColor(insight.type),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  Expanded(
                    child: Text(
                      insight.message,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _insightColor(AnalyticsInsightType? type) {
    return switch (type) {
      AnalyticsInsightType.revenue => AppColors.primaryStrong,
      AnalyticsInsightType.product => AppColors.warningStrong,
      AnalyticsInsightType.payment => AppColors.successStrong,
      AnalyticsInsightType.aov => AppColors.textSecondary,
      null => AppColors.textMuted,
    };
  }
}

class _OverviewStatusBanner extends StatelessWidget {
  const _OverviewStatusBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryStrong,
          ),
          const SizedBox(width: AppSizes.spacingSm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewErrorCard extends StatelessWidget {
  const _OverviewErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingXl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: AppColors.dangerStrong,
          ),
          const SizedBox(height: AppSizes.spacingMd),
          const Text(
            'Analytics overview is unavailable right now.',
            style: TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingLg),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _OverviewLoadingView extends StatelessWidget {
  const _OverviewLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _LoadingCard(height: 220),
        const SizedBox(height: AppSizes.spacingLg),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool twoColumns = constraints.maxWidth >= 780;
            if (!twoColumns) {
              return const Column(
                children: <Widget>[
                  _LoadingCard(height: 176),
                  SizedBox(height: AppSizes.spacingMd),
                  _LoadingCard(height: 176),
                  SizedBox(height: AppSizes.spacingMd),
                  _LoadingCard(height: 176),
                  SizedBox(height: AppSizes.spacingMd),
                  _LoadingCard(height: 176),
                ],
              );
            }
            final double cardWidth =
                (constraints.maxWidth - AppSizes.spacingMd) / 2;
            return Wrap(
              spacing: AppSizes.spacingMd,
              runSpacing: AppSizes.spacingMd,
              children: List<Widget>.generate(
                4,
                (_) => SizedBox(
                  width: cardWidth,
                  child: const _LoadingCard(height: 176),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Container(width: 92, height: 10, color: AppColors.surfaceAlt),
          const SizedBox(height: 6),
          Container(width: 120, height: 18, color: AppColors.surfaceAlt),
          const Spacer(),
          Container(width: 120, height: 10, color: AppColors.surfaceAlt),
        ],
      ),
    );
  }
}
