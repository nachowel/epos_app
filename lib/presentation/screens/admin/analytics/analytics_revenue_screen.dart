import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/analytics/analytics_date_range.dart';
import '../../../../domain/models/analytics/analytics_revenue_preset.dart';
import '../../../../domain/models/analytics/revenue_detail_summary.dart';
import '../../../providers/analytics/analytics_revenue_provider.dart';
import '../widgets/admin_scaffold.dart';
import 'widgets/daily_revenue_chart.dart';

const Key revenueDetailContextBannerKey = Key('revenue-detail-context-banner');
const String _analyticsRevenueRoute = '/admin/analytics/revenue';
const String _analyticsOrdersRoute = '/admin/analytics/orders';

enum AnalyticsRevenueDetailEntryPoint { revenue, aov, orders }

AnalyticsRevenueDetailEntryPoint analyticsRevenueDetailEntryPointFromQuery(
  String? value,
) {
  return switch (value) {
    'aov' => AnalyticsRevenueDetailEntryPoint.aov,
    'orders' => AnalyticsRevenueDetailEntryPoint.orders,
    _ => AnalyticsRevenueDetailEntryPoint.revenue,
  };
}

String? analyticsRevenueDetailEntryPointQueryValue(
  AnalyticsRevenueDetailEntryPoint entryPoint,
) {
  return switch (entryPoint) {
    AnalyticsRevenueDetailEntryPoint.revenue => null,
    AnalyticsRevenueDetailEntryPoint.aov => 'aov',
    AnalyticsRevenueDetailEntryPoint.orders => 'orders',
  };
}

AnalyticsRevenuePreset analyticsRevenuePresetFromOverviewPreset(
  AnalyticsDateRangePreset preset,
) {
  return switch (analyticsDetailPresetFromOverviewPreset(preset)) {
    AnalyticsDateRangePreset.thisMonth => AnalyticsRevenuePreset.thisMonth,
    AnalyticsDateRangePreset.lastWeek => AnalyticsRevenuePreset.lastWeek,
    AnalyticsDateRangePreset.last2Weeks => AnalyticsRevenuePreset.last2Weeks,
    AnalyticsDateRangePreset.today ||
    AnalyticsDateRangePreset.thisWeek ||
    AnalyticsDateRangePreset.explicit => AnalyticsRevenuePreset.thisWeek,
  };
}

String buildAnalyticsRevenueRouteLocation({
  required AnalyticsRevenuePreset preset,
  AnalyticsRevenueDetailEntryPoint entryPoint =
      AnalyticsRevenueDetailEntryPoint.revenue,
  String path = _analyticsRevenueRoute,
}) {
  return Uri(
    path: path,
    queryParameters: <String, String>{
      'preset': analyticsRevenuePresetQueryValue(preset),
      if (analyticsRevenueDetailEntryPointQueryValue(entryPoint)
          case final String value)
        'entry': value,
    },
  ).toString();
}

class AnalyticsRevenueScreen extends ConsumerStatefulWidget {
  const AnalyticsRevenueScreen({
    required this.initialPreset,
    required this.entryPoint,
    super.key,
  });

  final AnalyticsRevenuePreset initialPreset;
  final AnalyticsRevenueDetailEntryPoint entryPoint;

  @override
  ConsumerState<AnalyticsRevenueScreen> createState() =>
      _AnalyticsRevenueScreenState();
}

class _AnalyticsRevenueScreenState
    extends ConsumerState<AnalyticsRevenueScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(analyticsRevenueNotifierProvider.notifier)
          .initialize(preset: widget.initialPreset),
    );
  }

  @override
  void didUpdateWidget(covariant AnalyticsRevenueScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPreset != widget.initialPreset) {
      Future<void>.microtask(
        () => ref
            .read(analyticsRevenueNotifierProvider.notifier)
            .loadForPreset(widget.initialPreset),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AnalyticsRevenueState state = ref.watch(
      analyticsRevenueNotifierProvider,
    );
    final AnalyticsRevenueNotifier notifier = ref.read(
      analyticsRevenueNotifierProvider.notifier,
    );
    final RevenueDetailSummary summary =
        state.summary ??
        RevenueDetailSummary.empty(
          preset: state.selectedPreset,
          comparisonLabel: analyticsRevenueComparisonLabel(
            state.selectedPreset,
          ),
        );

    return AdminScaffold(
      title: widget.entryPoint == AnalyticsRevenueDetailEntryPoint.aov
          ? 'Revenue Detail · AOV Context'
          : widget.entryPoint == AnalyticsRevenueDetailEntryPoint.orders
          ? 'Revenue Detail · Orders Context'
          : 'Revenue Detail',
      currentRoute: widget.entryPoint == AnalyticsRevenueDetailEntryPoint.orders
          ? _analyticsOrdersRoute
          : _analyticsRevenueRoute,
      child: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            if (_entryHintMessage case final String message) ...<Widget>[
              _RevenueEntryBanner(message: message),
              const SizedBox(height: AppSizes.spacingMd),
            ],
            _RevenueHeader(
              selectedPreset: state.selectedPreset,
              onPresetSelected: (AnalyticsRevenuePreset preset) {
                context.go(
                  buildAnalyticsRevenueRouteLocation(
                    path:
                        widget.entryPoint ==
                            AnalyticsRevenueDetailEntryPoint.orders
                        ? _analyticsOrdersRoute
                        : _analyticsRevenueRoute,
                    preset: preset,
                    entryPoint: widget.entryPoint,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSizes.spacingLg),
            if (state.errorMessage != null && state.summary == null)
              _RevenueErrorView(
                message: state.errorMessage!,
                onRetry: notifier.refresh,
              )
            else if (state.isLoading && state.summary == null)
              const _RevenueLoadingView()
            else
              _RevenueBody(
                summary: summary,
                isRefreshing: state.isLoading && state.summary != null,
                statusMessage: state.errorMessage,
              ),
          ],
        ),
      ),
    );
  }

  String? get _entryHintMessage {
    return switch (widget.entryPoint) {
      AnalyticsRevenueDetailEntryPoint.revenue => null,
      AnalyticsRevenueDetailEntryPoint.aov =>
        'Opened from AOV. Use revenue and order flow to review average ticket movement.',
      AnalyticsRevenueDetailEntryPoint.orders =>
        'Opened from Orders. Use paid revenue and order totals to review volume for this period.',
    };
  }
}

class _RevenueHeader extends StatelessWidget {
  const _RevenueHeader({
    required this.selectedPreset,
    required this.onPresetSelected,
  });

  final AnalyticsRevenuePreset selectedPreset;
  final ValueChanged<AnalyticsRevenuePreset> onPresetSelected;

  @override
  Widget build(BuildContext context) {
    const List<AnalyticsRevenuePreset> presets = <AnalyticsRevenuePreset>[
      AnalyticsRevenuePreset.thisWeek,
      AnalyticsRevenuePreset.lastWeek,
      AnalyticsRevenuePreset.last2Weeks,
      AnalyticsRevenuePreset.thisMonth,
    ];

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
                const _RevenueHeaderCopy()
              else
                const Expanded(flex: 2, child: _RevenueHeaderCopy()),
              if (!stacked) const SizedBox(width: AppSizes.spacingLg),
              if (stacked) const SizedBox(height: AppSizes.spacingMd),
              Wrap(
                spacing: AppSizes.spacingSm,
                runSpacing: AppSizes.spacingSm,
                children: presets
                    .map(
                      (AnalyticsRevenuePreset preset) => ChoiceChip(
                        selected: preset == selectedPreset,
                        label: Text(analyticsRevenuePresetLabel(preset)),
                        onSelected: (_) => onPresetSelected(preset),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RevenueHeaderCopy extends StatelessWidget {
  const _RevenueHeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Daily paid revenue trend.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppSizes.spacingXs),
        Text(
          'One preset at a time. Revenue, orders, and AOV stay on the same paid-at window.',
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

class _RevenueBody extends StatelessWidget {
  const _RevenueBody({
    required this.summary,
    required this.isRefreshing,
    required this.statusMessage,
  });

  final RevenueDetailSummary summary;
  final bool isRefreshing;
  final String? statusMessage;

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
        if (statusMessage != null) ...<Widget>[
          _RevenueStatusBanner(message: statusMessage!),
          const SizedBox(height: AppSizes.spacingMd),
        ],
        _RevenueSummaryStrip(summary: summary),
        const SizedBox(height: AppSizes.spacingMd),
        _RevenueComparisonBanner(summary: summary),
        const SizedBox(height: AppSizes.spacingLg),
        if (!summary.hasData)
          const _RevenueEmptyView()
        else
          DailyRevenueChart(points: summary.dailyRevenueSeries),
      ],
    );
  }
}

class _RevenueSummaryStrip extends StatelessWidget {
  const _RevenueSummaryStrip({required this.summary});

  final RevenueDetailSummary summary;

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
          final bool stacked = constraints.maxWidth < 720;
          final List<Widget> items = <Widget>[
            _SummaryMetric(
              label: 'Total Revenue',
              value: CurrencyFormatter.fromMinor(summary.totalRevenueMinor),
            ),
            _SummaryMetric(label: 'Orders', value: '${summary.orderCount}'),
            _SummaryMetric(
              label: 'AOV',
              value: CurrencyFormatter.fromMinor(
                summary.averageOrderValueMinor,
              ),
            ),
          ];

          if (stacked) {
            return Column(
              children: List<Widget>.generate(items.length, (int index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == items.length - 1 ? 0 : AppSizes.spacingMd,
                  ),
                  child: items[index],
                );
              }),
            );
          }

          return Row(
            children: List<Widget>.generate(items.length, (int index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == items.length - 1 ? 0 : AppSizes.spacingMd,
                  ),
                  child: items[index],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingXs),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueComparisonBanner extends StatelessWidget {
  const _RevenueComparisonBanner({required this.summary});

  final RevenueDetailSummary summary;

  @override
  Widget build(BuildContext context) {
    final String deltaLabel = CurrencyFormatter.fromMinor(
      summary.comparisonDeltaRevenueMinor.abs(),
    );
    final String body = switch (summary.comparisonDirection) {
      RevenueComparisonDirection.up =>
        '$deltaLabel higher than the comparison window.',
      RevenueComparisonDirection.down =>
        '$deltaLabel lower than the comparison window.',
      RevenueComparisonDirection.flat =>
        'Revenue is flat against the comparison window.',
      RevenueComparisonDirection.none =>
        'No paid revenue in either period yet.',
    };

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            summary.comparisonLabel,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingXs),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueEmptyView extends StatelessWidget {
  const _RevenueEmptyView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingXl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: const Text(
        'No paid revenue in this period.',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _RevenueStatusBanner extends StatelessWidget {
  const _RevenueStatusBanner({required this.message});

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

class _RevenueEntryBanner extends StatelessWidget {
  const _RevenueEntryBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: revenueDetailContextBannerKey,
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.filter_alt_outlined, color: AppColors.primaryStrong),
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

class _RevenueLoadingView extends StatelessWidget {
  const _RevenueLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.spacingXl),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _RevenueErrorView extends StatelessWidget {
  const _RevenueErrorView({required this.message, required this.onRetry});

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
            'Revenue detail is unavailable right now.',
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
