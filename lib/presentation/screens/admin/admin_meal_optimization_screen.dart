import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/meal_optimization.dart';
import 'widgets/admin_scaffold.dart';

// ignore_for_file: public_member_api_docs

/// Phase 9 – Meal Optimization / Insights screen.
///
/// Shows discount leakage, upsell opportunities, swap behaviour,
/// profile performance and actionable recommendations for the admin.
/// Nothing is auto-applied — the admin decides what to act on.
class AdminMealOptimizationScreen extends ConsumerStatefulWidget {
  const AdminMealOptimizationScreen({super.key});

  @override
  ConsumerState<AdminMealOptimizationScreen> createState() =>
      _AdminMealOptimizationScreenState();
}

class _AdminMealOptimizationScreenState
    extends ConsumerState<AdminMealOptimizationScreen>
    with SingleTickerProviderStateMixin {
  MealOptimizationReport? _report;
  bool _isLoading = false;
  String? _errorMessage;
  int _lookbackDays = 30;
  late TabController _tabController;

  static const List<String> _tabs = <String>[
    'Recommendations',
    'Discount',
    'Upsell',
    'Swaps',
    'Profiles',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final MealOptimizationReport report = await ref
          .read(mealOptimizationServiceProvider)
          .generateReport(lookbackDays: _lookbackDays);
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Meal Optimization',
      currentRoute: '/admin/meal-optimization',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ControlBar(
            lookbackDays: _lookbackDays,
            isLoading: _isLoading,
            onLookbackChanged: (int days) {
              setState(() => _lookbackDays = days);
              _load();
            },
            onRefresh: _load,
            report: _report,
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
              child: _AlertBox(
                message: _errorMessage!,
                color: AppColors.error,
              ),
            ),
          if (_report != null && _report!.dataQualityNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
              child: _AlertBox(
                message:
                    '⚠ Data quality: ${_report!.dataQualityNotes.length} note(s). Tap to expand.',
                color: AppColors.warning,
                details: _report!.dataQualityNotes,
              ),
            ),
          TabBar(
            key: const ValueKey<String>('meal-optimization-tabs'),
            controller: _tabController,
            isScrollable: true,
            tabs: _tabs.map((String t) => Tab(text: t)).toList(),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _report == null
                ? const Center(child: Text('No data. Tap Refresh to generate.'))
                : TabBarView(
                    controller: _tabController,
                    children: <Widget>[
                      _RecommendationsTab(
                        recommendations: _report!.recommendations,
                      ),
                      _DiscountLeakageTab(
                        items: _report!.discountLeakage,
                      ),
                      _UpsellTab(opportunities: _report!.upsellOpportunities),
                      _SwapBehaviorTab(behaviors: _report!.swapBehaviors),
                      _ProfilePerformanceTab(
                        performances: _report!.profilePerformances,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Control bar
// ─────────────────────────────────────────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.lookbackDays,
    required this.isLoading,
    required this.onLookbackChanged,
    required this.onRefresh,
    required this.report,
  });

  final int lookbackDays;
  final bool isLoading;
  final ValueChanged<int> onLookbackChanged;
  final VoidCallback onRefresh;
  final MealOptimizationReport? report;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
      child: Wrap(
        spacing: AppSizes.spacingMd,
        runSpacing: AppSizes.spacingSm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          DropdownButton<int>(
            key: const ValueKey<String>('meal-opt-lookback'),
            value: lookbackDays,
            items: const <DropdownMenuItem<int>>[
              DropdownMenuItem<int>(value: 7, child: Text('Last 7 days')),
              DropdownMenuItem<int>(value: 14, child: Text('Last 14 days')),
              DropdownMenuItem<int>(value: 30, child: Text('Last 30 days')),
              DropdownMenuItem<int>(value: 60, child: Text('Last 60 days')),
              DropdownMenuItem<int>(value: 90, child: Text('Last 90 days')),
            ],
            onChanged: isLoading
                ? null
                : (int? v) {
                    if (v != null) onLookbackChanged(v);
                  },
          ),
          ElevatedButton.icon(
            key: const ValueKey<String>('meal-opt-refresh'),
            onPressed: isLoading ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
          ),
          if (report != null)
            Text(
              'Generated: ${_timeAgo(report!.generatedAt)}  ·  '
              '${report!.recommendations.length} recommendations',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: AppSizes.fontSm,
              ),
            ),
        ],
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab A – Recommendations
// ─────────────────────────────────────────────────────────────────────────────

class _RecommendationsTab extends StatelessWidget {
  const _RecommendationsTab({required this.recommendations});

  final List<MealOptimizationRecommendation> recommendations;

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return const _EmptyHint(
        message: 'No recommendations for this period — data looks healthy.',
      );
    }
    return ListView.separated(
      key: const ValueKey<String>('recommendations-list'),
      itemCount: recommendations.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSizes.spacingSm),
      itemBuilder: (BuildContext context, int index) {
        final MealOptimizationRecommendation rec = recommendations[index];
        return _RecommendationCard(rec: rec);
      },
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.rec});

  final MealOptimizationRecommendation rec;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey<String>('rec-${rec.affectedProductId}-${rec.type.name}'),
      child: ListTile(
        leading: _SeverityBadge(severity: rec.severity),
        title: Text(
          rec.description,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 4),
            Text(
              '→ ${rec.suggestedAction}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: <Widget>[
                _Chip(label: _typeLabel(rec.type), color: AppColors.primary),
                _Chip(
                  label: _confidenceLabel(rec.confidence),
                  color: _confidenceColor(rec.confidence),
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  static String _typeLabel(RecommendationType t) {
    switch (t) {
      case RecommendationType.reduceDiscount:
        return 'Reduce Discount';
      case RecommendationType.adjustDefaultComponent:
        return 'Adjust Default';
      case RecommendationType.promoteExtra:
        return 'Promote Extra';
      case RecommendationType.reviseSwapOptions:
        return 'Revise Swaps';
      case RecommendationType.reviewProfileRules:
        return 'Review Rules';
    }
  }

  static String _confidenceLabel(InsightConfidence c) {
    switch (c) {
      case InsightConfidence.high:
        return 'High confidence';
      case InsightConfidence.medium:
        return 'Medium confidence';
      case InsightConfidence.low:
        return 'Low confidence';
    }
  }

  static Color _confidenceColor(InsightConfidence c) {
    switch (c) {
      case InsightConfidence.high:
        return AppColors.success;
      case InsightConfidence.medium:
        return AppColors.warning;
      case InsightConfidence.low:
        return AppColors.textSecondary;
    }
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final RecommendationSeverity severity;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (severity) {
      case RecommendationSeverity.high:
        color = AppColors.error;
        label = 'HIGH';
        break;
      case RecommendationSeverity.medium:
        color = AppColors.warning;
        label = 'MED';
        break;
      case RecommendationSeverity.low:
        color = AppColors.textSecondary;
        label = 'LOW';
        break;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab B – Discount Leakage
// ─────────────────────────────────────────────────────────────────────────────

class _DiscountLeakageTab extends StatelessWidget {
  const _DiscountLeakageTab({required this.items});

  final List<ProductDiscountLeakage> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyHint(message: 'No discount data for this period.');
    }
    return ListView.separated(
      key: const ValueKey<String>('discount-leakage-list'),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSizes.spacingSm),
      itemBuilder: (BuildContext context, int index) {
        final ProductDiscountLeakage item = items[index];
        return _InsightCard(
          key: ValueKey<String>('disc-${item.productId}'),
          title: item.productName,
          confidence: item.confidence,
          hasLegacy: item.hasLegacyLines,
          flagCount: item.flags.length,
          flagColor: item.flags.isEmpty ? AppColors.success : AppColors.error,
          metrics: <_Metric>[
            _Metric(
              label: 'Orders',
              value: '${item.totalOrders}',
            ),
            _Metric(
              label: 'Discounted orders',
              value:
                  '${item.discountedOrders} (${item.discountFrequency.toStringAsFixed(1)}%)',
            ),
            _Metric(
              label: 'Total discount',
              value: CurrencyFormatter.fromMinor(item.totalDiscountMinor),
            ),
            _Metric(
              label: 'Avg/discounted order',
              value: CurrencyFormatter.fromMinor(item.avgDiscountPerOrderMinor),
            ),
            _Metric(
              label: 'Combo discount orders',
              value: '${item.comboDiscountOrders}',
            ),
          ],
          insights: item.insights,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab C – Upsell Opportunities
// ─────────────────────────────────────────────────────────────────────────────

class _UpsellTab extends StatelessWidget {
  const _UpsellTab({required this.opportunities});

  final List<ProductUpsellOpportunity> opportunities;

  @override
  Widget build(BuildContext context) {
    if (opportunities.isEmpty) {
      return const _EmptyHint(message: 'No extra/upsell data for this period.');
    }
    return ListView.separated(
      key: const ValueKey<String>('upsell-list'),
      itemCount: opportunities.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSizes.spacingSm),
      itemBuilder: (BuildContext context, int index) {
        final ProductUpsellOpportunity item = opportunities[index];
        return _InsightCard(
          key: ValueKey<String>('upsell-${item.productId}'),
          title: item.productName,
          confidence: item.confidence,
          hasLegacy: item.hasLegacyLines,
          flagCount: item.extraAttachRate < kLowExtraAttachThreshold * 100 &&
                  item.totalOrders >= kMinOrdersForMediumConfidence
              ? 1
              : 0,
          flagColor: AppColors.warning,
          metrics: <_Metric>[
            _Metric(label: 'Orders', value: '${item.totalOrders}'),
            _Metric(
              label: 'Extra attach rate',
              value: '${item.extraAttachRate.toStringAsFixed(1)}%',
            ),
            _Metric(
              label: 'Extra revenue',
              value: CurrencyFormatter.fromMinor(item.totalExtraRevenueMinor),
            ),
            _Metric(
              label: 'Avg extra/order',
              value:
                  CurrencyFormatter.fromMinor(item.extraRevenuePerOrderMinor),
            ),
            _Metric(
              label: 'Never-selected extras',
              value: '${item.neverSelectedExtraProductIds.length}',
            ),
          ],
          insights: item.insights,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab D – Swap Behavior
// ─────────────────────────────────────────────────────────────────────────────

class _SwapBehaviorTab extends StatelessWidget {
  const _SwapBehaviorTab({required this.behaviors});

  final List<ProductSwapBehavior> behaviors;

  @override
  Widget build(BuildContext context) {
    if (behaviors.isEmpty) {
      return const _EmptyHint(message: 'No swap data for this period.');
    }
    return ListView.separated(
      key: const ValueKey<String>('swap-list'),
      itemCount: behaviors.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSizes.spacingSm),
      itemBuilder: (BuildContext context, int index) {
        final ProductSwapBehavior item = behaviors[index];
        return _InsightCard(
          key: ValueKey<String>('swap-${item.productId}'),
          title: item.productName,
          confidence: item.confidence,
          hasLegacy: item.hasLegacyLines,
          flagCount: 0,
          flagColor: AppColors.primary,
          metrics: <_Metric>[
            _Metric(label: 'Orders', value: '${item.totalOrders}'),
            _Metric(
              label: 'Orders with swaps',
              value: '${item.ordersWithSwaps}',
            ),
            _Metric(
              label: 'Free swap orders',
              value:
                  '${item.freeSwapOrders} (${item.freeSwapUsageRate.toStringAsFixed(1)}%)',
            ),
            _Metric(label: 'Paid swap orders', value: '${item.paidSwapOrders}'),
            _Metric(
              label: 'Top swap pairs',
              value: '${item.topSwapPairs.length}',
            ),
          ],
          insights: item.insights,
          extra: item.topSwapPairs.isEmpty
              ? null
              : _SwapPairList(pairs: item.topSwapPairs.take(3).toList()),
        );
      },
    );
  }
}

class _SwapPairList extends StatelessWidget {
  const _SwapPairList({required this.pairs});

  final List<SwapPairStats> pairs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: pairs
          .map(
            (SwapPairStats p) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• "${p.componentKey}" → id=${p.targetItemProductId}: '
                '${p.occurrenceCount}× (${p.frequencyPercent.toStringAsFixed(1)}%) '
                '[free=${p.freeCount}, paid=${p.paidCount}]',
                style: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab E – Profile Performance
// ─────────────────────────────────────────────────────────────────────────────

class _ProfilePerformanceTab extends StatelessWidget {
  const _ProfilePerformanceTab({required this.performances});

  final List<ProfilePerformance> performances;

  @override
  Widget build(BuildContext context) {
    if (performances.isEmpty) {
      return const _EmptyHint(
        message: 'No profile performance data for this period.',
      );
    }
    return ListView.separated(
      key: const ValueKey<String>('profile-perf-list'),
      itemCount: performances.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppSizes.spacingSm),
      itemBuilder: (BuildContext context, int index) {
        final ProfilePerformance item = performances[index];
        return _InsightCard(
          key: ValueKey<String>('prof-${item.profileId}'),
          title: item.profileName,
          confidence: item.confidence,
          hasLegacy: false,
          flagCount: item.healthLabel == ProfileHealthLabel.discountHeavy ||
                  item.healthLabel == ProfileHealthLabel.upsellWeak
              ? 1
              : 0,
          flagColor: _healthColor(item.healthLabel),
          metrics: <_Metric>[
            _Metric(label: 'Orders', value: '${item.totalOrders}'),
            _Metric(
              label: 'Avg discount',
              value: CurrencyFormatter.fromMinor(item.avgDiscountMinor),
            ),
            _Metric(
              label: 'Avg extra revenue',
              value: CurrencyFormatter.fromMinor(item.avgExtraRevenueMinor),
            ),
            _Metric(
              label: 'Avg net adjustment',
              value: CurrencyFormatter.fromMinor(item.avgNetAdjustmentMinor),
            ),
            _Metric(
              label: 'Customization rate',
              value: '${item.customizationRate.toStringAsFixed(1)}%',
            ),
            _Metric(
              label: 'Health',
              value: _healthLabel(item.healthLabel),
            ),
          ],
          insights: item.insights,
        );
      },
    );
  }

  static Color _healthColor(ProfileHealthLabel l) {
    switch (l) {
      case ProfileHealthLabel.balanced:
        return AppColors.success;
      case ProfileHealthLabel.discountHeavy:
        return AppColors.error;
      case ProfileHealthLabel.upsellWeak:
        return AppColors.warning;
      case ProfileHealthLabel.overCustomized:
        return AppColors.primary;
    }
  }

  static String _healthLabel(ProfileHealthLabel l) {
    switch (l) {
      case ProfileHealthLabel.balanced:
        return 'Balanced';
      case ProfileHealthLabel.discountHeavy:
        return 'Discount-heavy';
      case ProfileHealthLabel.upsellWeak:
        return 'Upsell-weak';
      case ProfileHealthLabel.overCustomized:
        return 'Over-customized';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Generic insight card for all product-level sections.
class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required super.key,
    required this.title,
    required this.confidence,
    required this.hasLegacy,
    required this.flagCount,
    required this.flagColor,
    required this.metrics,
    required this.insights,
    this.extra,
  });

  final String title;
  final InsightConfidence confidence;
  final bool hasLegacy;
  final int flagCount;
  final Color flagColor;
  final List<_Metric> metrics;
  final List<String> insights;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: AppSizes.fontMd,
                    ),
                  ),
                ),
                if (flagCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSizes.spacingSm),
                    child: Icon(
                      Icons.flag_rounded,
                      color: flagColor,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: AppSizes.spacingSm),
                _ConfidenceBadge(confidence: confidence),
                if (hasLegacy)
                  const Padding(
                    padding: EdgeInsets.only(left: AppSizes.spacingSm),
                    child: Tooltip(
                      message: 'Legacy lines present — partial data',
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.spacingSm),
            Wrap(
              spacing: AppSizes.spacingMd,
              runSpacing: 4,
              children: metrics
                  .map(
                    (_Metric m) => _MetricChip(label: m.label, value: m.value),
                  )
                  .toList(),
            ),
            if (insights.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSizes.spacingSm),
              const Divider(height: 1),
              const SizedBox(height: AppSizes.spacingSm),
              ...insights.map(
                (String s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $s',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: AppSizes.fontSm,
                    ),
                  ),
                ),
              ),
            ],
            if (extra != null) ...<Widget>[
              const SizedBox(height: AppSizes.spacingSm),
              extra!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: const Border.fromBorderSide(
          BorderSide(color: AppColors.border),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(
            fontSize: AppSizes.fontSm,
          ),
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final InsightConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (confidence) {
      case InsightConfidence.high:
        color = AppColors.success;
        label = 'High';
        break;
      case InsightConfidence.medium:
        color = AppColors.warning;
        label = 'Med';
        break;
      case InsightConfidence.low:
        color = AppColors.textSecondary;
        label = 'Low';
        break;
    }
    return _Chip(label: label, color: color);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AlertBox extends StatefulWidget {
  const _AlertBox({
    required this.message,
    required this.color,
    this.details = const <String>[],
  });

  final String message;
  final Color color;
  final List<String> details;

  @override
  State<_AlertBox> createState() => _AlertBoxState();
}

class _AlertBoxState extends State<_AlertBox> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.details.isEmpty
          ? null
          : () => setState(() => _expanded = !_expanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSizes.spacingSm),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: widget.color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.message,
              style: TextStyle(
                color: widget.color,
                fontWeight: FontWeight.w600,
                fontSize: AppSizes.fontSm,
              ),
            ),
            if (_expanded && widget.details.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSizes.spacingSm),
              ...widget.details.map(
                (String s) => Text(
                  '• $s',
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingXl),
        child: Text(
          message,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppSizes.fontMd,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
