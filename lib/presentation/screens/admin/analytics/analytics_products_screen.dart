import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../domain/models/analytics/analytics_date_range.dart';
import '../../../../domain/models/analytics/category_product_analytics_section.dart';
import '../../../providers/analytics/analytics_products_provider.dart';
import '../widgets/admin_scaffold.dart';
import 'analytics_overview_screen.dart';
import 'widgets/category_product_section.dart';

class AnalyticsProductsScreen extends ConsumerStatefulWidget {
  const AnalyticsProductsScreen({required this.initialPreset, super.key});

  final AnalyticsDateRangePreset initialPreset;

  @override
  ConsumerState<AnalyticsProductsScreen> createState() =>
      _AnalyticsProductsScreenState();
}

class _AnalyticsProductsScreenState
    extends ConsumerState<AnalyticsProductsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(analyticsProductsNotifierProvider.notifier)
          .initialize(preset: widget.initialPreset),
    );
  }

  @override
  void didUpdateWidget(covariant AnalyticsProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPreset != widget.initialPreset) {
      Future<void>.microtask(
        () => ref
            .read(analyticsProductsNotifierProvider.notifier)
            .loadForPreset(widget.initialPreset),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AnalyticsProductsState state = ref.watch(
      analyticsProductsNotifierProvider,
    );
    final AnalyticsProductsNotifier notifier = ref.read(
      analyticsProductsNotifierProvider.notifier,
    );
    final List<CategoryProductAnalyticsSection> sections =
        state.sections ?? const <CategoryProductAnalyticsSection>[];

    return AdminScaffold(
      title: analyticsProductsDetailTitle,
      currentRoute: analyticsProductsDetailRoute,
      child: RefreshIndicator(
        onRefresh: notifier.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            _ProductsHeader(
              selectedPreset: state.selectedPreset,
              onPresetSelected: (AnalyticsDateRangePreset preset) {
                context.go(_buildAnalyticsProductsLocation(preset));
              },
            ),
            const SizedBox(height: AppSizes.spacingLg),
            if (state.errorMessage != null && state.sections == null)
              _ProductsErrorView(
                message: state.errorMessage!,
                onRetry: notifier.refresh,
              )
            else if (state.isLoading && state.sections == null)
              const _ProductsLoadingView()
            else
              _ProductsBody(
                sections: sections,
                isRefreshing: state.isLoading && state.sections != null,
                statusMessage: state.errorMessage,
              ),
          ],
        ),
      ),
    );
  }
}

String _buildAnalyticsProductsLocation(AnalyticsDateRangePreset preset) {
  return Uri(
    path: analyticsProductsDetailRoute,
    queryParameters: <String, String>{
      'range': analyticsDateRangePresetQueryValue(preset),
    },
  ).toString();
}

class _ProductsHeader extends StatelessWidget {
  const _ProductsHeader({
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
                const _ProductsHeaderCopy()
              else
                const Expanded(flex: 2, child: _ProductsHeaderCopy()),
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

class _ProductsHeaderCopy extends StatelessWidget {
  const _ProductsHeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Category revenue by paid sales.',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: AppSizes.spacingXs),
        Text(
          'Revenue first, quantity second. Showing top products by category for the active period.',
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

class _ProductsBody extends StatelessWidget {
  const _ProductsBody({
    required this.sections,
    required this.isRefreshing,
    required this.statusMessage,
  });

  final List<CategoryProductAnalyticsSection> sections;
  final bool isRefreshing;
  final String? statusMessage;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSizes.spacingXl),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No product revenue in this period.',
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
        ...List<Widget>.generate(sections.length, (int index) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == sections.length - 1 ? 0 : AppSizes.spacingLg,
            ),
            child: CategoryProductSection(
              key: ValueKey<int>(sections[index].categoryId),
              section: sections[index],
              defaultExpanded: index < 2,
            ),
          );
        }),
      ],
    );
  }
}

class _ProductsLoadingView extends StatelessWidget {
  const _ProductsLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.spacingXl),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProductsErrorView extends StatelessWidget {
  const _ProductsErrorView({required this.message, required this.onRetry});

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
            'Product analytics are unavailable right now.',
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
