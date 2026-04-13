import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/analytics/analytics_date_range.dart';
import '../../../../domain/models/analytics/payment_split_summary.dart';
import '../../../providers/analytics/analytics_payments_provider.dart';
import '../widgets/admin_scaffold.dart';
import 'analytics_overview_screen.dart';

class AnalyticsPaymentsScreen extends ConsumerStatefulWidget {
  const AnalyticsPaymentsScreen({required this.initialPreset, super.key});

  final AnalyticsDateRangePreset initialPreset;

  @override
  ConsumerState<AnalyticsPaymentsScreen> createState() =>
      _AnalyticsPaymentsScreenState();
}

class _AnalyticsPaymentsScreenState
    extends ConsumerState<AnalyticsPaymentsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(analyticsPaymentsNotifierProvider.notifier)
          .initialize(preset: widget.initialPreset),
    );
  }

  @override
  void didUpdateWidget(covariant AnalyticsPaymentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPreset != widget.initialPreset) {
      Future<void>.microtask(
        () => ref
            .read(analyticsPaymentsNotifierProvider.notifier)
            .loadForPreset(widget.initialPreset),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AnalyticsPaymentsState state = ref.watch(
      analyticsPaymentsNotifierProvider,
    );
    final AnalyticsPaymentsNotifier notifier = ref.read(
      analyticsPaymentsNotifierProvider.notifier,
    );
    final PaymentSplitSummary summary =
        state.summary ?? const PaymentSplitSummary.empty();

    return AdminScaffold(
      title: analyticsPaymentsDetailTitle,
      currentRoute: analyticsPaymentsDetailRoute,
      child: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            _PaymentsHeader(
              selectedPreset: state.selectedPreset,
              onPresetSelected: (AnalyticsDateRangePreset preset) {
                context.go(_buildAnalyticsPaymentsLocation(preset));
              },
            ),
            const SizedBox(height: AppSizes.spacingLg),
            if (state.errorMessage != null && state.summary == null)
              _PaymentsErrorView(
                message: state.errorMessage!,
                onRetry: notifier.refresh,
              )
            else if (state.isLoading && state.summary == null)
              const _PaymentsLoadingView()
            else
              _PaymentsBody(
                summary: summary,
                isRefreshing: state.isLoading && state.summary != null,
                statusMessage: state.errorMessage,
              ),
          ],
        ),
      ),
    );
  }
}

String _buildAnalyticsPaymentsLocation(AnalyticsDateRangePreset preset) {
  return Uri(
    path: analyticsPaymentsDetailRoute,
    queryParameters: <String, String>{
      'range': analyticsDateRangePresetQueryValue(preset),
    },
  ).toString();
}

class _PaymentsHeader extends StatelessWidget {
  const _PaymentsHeader({
    required this.selectedPreset,
    required this.onPresetSelected,
  });

  final AnalyticsDateRangePreset selectedPreset;
  final ValueChanged<AnalyticsDateRangePreset> onPresetSelected;

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
                const _PaymentsHeaderCopy()
              else
                const Expanded(flex: 2, child: _PaymentsHeaderCopy()),
              if (!stacked) const SizedBox(width: AppSizes.spacingLg),
              if (stacked) const SizedBox(height: AppSizes.spacingMd),
              Wrap(
                spacing: AppSizes.spacingSm,
                runSpacing: AppSizes.spacingSm,
                children: kAnalyticsDetailPresets
                    .map(
                      (AnalyticsDateRangePreset preset) => ChoiceChip(
                        selected: preset == selectedPreset,
                        label: Text(analyticsDateRangePresetLabel(preset)),
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

class _PaymentsHeaderCopy extends StatelessWidget {
  const _PaymentsHeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Paid revenue split by payment method.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppSizes.spacingXs),
        Text(
          'Revenue leads the view. Order counts stay secondary for quick readout.',
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

class _PaymentsBody extends StatelessWidget {
  const _PaymentsBody({
    required this.summary,
    required this.isRefreshing,
    required this.statusMessage,
  });

  final PaymentSplitSummary summary;
  final bool isRefreshing;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty =
        summary.totalRevenueMinor == 0 &&
        summary.cashOrderCount == 0 &&
        summary.cardOrderCount == 0;

    if (isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSizes.spacingXl),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No payments in this period.',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (isRefreshing)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSizes.spacingSm),
            child: LinearProgressIndicator(minHeight: 3),
          ),
        if (statusMessage != null) ...<Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
            padding: const EdgeInsets.all(AppSizes.spacingMd),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              statusMessage!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        _PaymentsSummaryStrip(summary: summary),
        const SizedBox(height: AppSizes.spacingLg),
        _RevenueSplitPanel(summary: summary),
      ],
    );
  }
}

class _PaymentsSummaryStrip extends StatelessWidget {
  const _PaymentsSummaryStrip({required this.summary});

  final PaymentSplitSummary summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked = constraints.maxWidth < 760;
        final List<Widget> metrics = <Widget>[
          _PaymentSummaryMetric(
            label: 'Card Revenue',
            value: CurrencyFormatter.fromMinor(summary.cardRevenueMinor),
            accentColor: AppColors.primaryStrong,
          ),
          _PaymentSummaryMetric(
            label: 'Cash Revenue',
            value: CurrencyFormatter.fromMinor(summary.cashRevenueMinor),
            accentColor: AppColors.successStrong,
          ),
          _PaymentSummaryMetric(
            label: 'Total Revenue',
            value: CurrencyFormatter.fromMinor(summary.totalRevenueMinor),
            accentColor: AppColors.textPrimary,
          ),
        ];

        if (stacked) {
          return Column(
            children: List<Widget>.generate(metrics.length, (int index) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == metrics.length - 1 ? 0 : AppSizes.spacingMd,
                ),
                child: metrics[index],
              );
            }),
          );
        }

        return Row(
          children: List<Widget>.generate(metrics.length, (int index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == metrics.length - 1 ? 0 : AppSizes.spacingMd,
                ),
                child: metrics[index],
              ),
            );
          }),
        );
      },
    );
  }
}

class _PaymentSummaryMetric extends StatelessWidget {
  const _PaymentSummaryMetric({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

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
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueSplitPanel extends StatelessWidget {
  const _RevenueSplitPanel({required this.summary});

  final PaymentSplitSummary summary;

  @override
  Widget build(BuildContext context) {
    final double cashFlex = summary.totalRevenueMinor <= 0
        ? 0
        : summary.cashRevenueMinor / summary.totalRevenueMinor;
    final double cardFlex = summary.totalRevenueMinor <= 0
        ? 0
        : summary.cardRevenueMinor / summary.totalRevenueMinor;

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
            'Revenue Split',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingXs),
          const Text(
            'Revenue share by payment method for completed paid orders.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingLg),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            child: SizedBox(
              height: 18,
              child: Row(
                children: <Widget>[
                  if (cardFlex > 0)
                    Expanded(
                      flex: (cardFlex * 1000).round(),
                      child: Container(color: AppColors.primaryStrong),
                    ),
                  if (cashFlex > 0)
                    Expanded(
                      flex: (cashFlex * 1000).round(),
                      child: Container(color: AppColors.successStrong),
                    ),
                  if (cardFlex == 0 && cashFlex == 0)
                    const Expanded(
                      child: ColoredBox(color: AppColors.surfaceAlt),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.spacingLg),
          _RevenueSplitRow(
            label: 'Card',
            revenueLabel: CurrencyFormatter.fromMinor(summary.cardRevenueMinor),
            shareLabel: _shareLabel(summary.cardRevenueShare),
            orderCountLabel:
                '${summary.cardOrderCount} order${summary.cardOrderCount == 1 ? '' : 's'}',
            color: AppColors.primaryStrong,
          ),
          const SizedBox(height: AppSizes.spacingMd),
          _RevenueSplitRow(
            label: 'Cash',
            revenueLabel: CurrencyFormatter.fromMinor(summary.cashRevenueMinor),
            shareLabel: _shareLabel(summary.cashRevenueShare),
            orderCountLabel:
                '${summary.cashOrderCount} order${summary.cashOrderCount == 1 ? '' : 's'}',
            color: AppColors.successStrong,
          ),
        ],
      ),
    );
  }

  String _shareLabel(double? value) {
    if (value == null) {
      return '0%';
    }
    return '${(value * 100).toStringAsFixed(0)}%';
  }
}

class _RevenueSplitRow extends StatelessWidget {
  const _RevenueSplitRow({
    required this.label,
    required this.revenueLabel,
    required this.shareLabel,
    required this.orderCountLabel,
    required this.color,
  });

  final String label;
  final String revenueLabel;
  final String shareLabel;
  final String orderCountLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: AppSizes.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                orderCountLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              revenueLabel,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              shareLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PaymentsLoadingView extends StatelessWidget {
  const _PaymentsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.spacingXl),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PaymentsErrorView extends StatelessWidget {
  const _PaymentsErrorView({required this.message, required this.onRetry});

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
            'Payment analytics are unavailable right now.',
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
