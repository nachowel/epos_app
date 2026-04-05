import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/meal_adjustment_profile.dart';
import '../../../domain/services/meal_adjustment_profile_validation_service.dart';
import '../../providers/admin_meal_profiles_provider.dart';
import 'widgets/admin_scaffold.dart';

class AdminMealProfileEditorScreen extends ConsumerStatefulWidget {
  const AdminMealProfileEditorScreen({
    required this.profileId,
    super.key,
  });

  final int profileId;

  @override
  ConsumerState<AdminMealProfileEditorScreen> createState() =>
      _AdminMealProfileEditorScreenState();
}

class _AdminMealProfileEditorScreenState
    extends ConsumerState<AdminMealProfileEditorScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref
          .read(adminMealProfileEditorNotifierProvider.notifier)
          .loadProfile(widget.profileId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AdminMealProfileEditorState state =
        ref.watch(adminMealProfileEditorNotifierProvider);

    return AdminScaffold(
      title: state.draft?.name ?? 'Profile Editor',
      currentRoute: '/admin/meal-profiles',
      child: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.draft == null
              ? Center(
                  child: Text(
                    state.errorMessage ?? 'Profile not found.',
                    style: const TextStyle(color: AppColors.error),
                  ),
                )
              : _EditorBody(
                  state: state,
                  onSave: _save,
                  onBack: () => context.go('/admin/meal-profiles'),
                ),
    );
  }

  Future<void> _save() async {
    final bool saved = await ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .save();
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor body
// ─────────────────────────────────────────────────────────────────────────────

class _EditorBody extends ConsumerWidget {
  const _EditorBody({
    required this.state,
    required this.onSave,
    required this.onBack,
  });

  final AdminMealProfileEditorState state;
  final VoidCallback onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MealAdjustmentProfileDraft draft = state.draft!;
    final MealAdjustmentValidationResult? validation = state.validationResult;

    return Column(
      children: <Widget>[
        // Top bar: back + save
        Row(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Profiles'),
            ),
            const Spacer(),
            if (state.isDirty)
              const Padding(
                padding: EdgeInsets.only(right: AppSizes.spacingSm),
                child: Text(
                  'Unsaved changes',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (state.hasBlockingErrors)
              Padding(
                padding: const EdgeInsets.only(right: AppSizes.spacingSm),
                child: Text(
                  '${validation!.blockingErrors.length} blocking error(s)',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ElevatedButton.icon(
              key: const ValueKey<String>('meal-profile-editor-save'),
              onPressed:
                  state.isSaving || !state.isDirty || !state.canSave
                      ? null
                      : onSave,
              icon: const Icon(Icons.save_rounded),
              label: Text(state.isSaving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacingMd),
        if (state.errorMessage != null)
          _Banner(message: state.errorMessage!, color: AppColors.error),
        if (state.healthSummary != null)
          _Banner(
            message: state.healthSummary!.headline,
            color: _healthColor(state.healthSummary!.healthStatus),
          ),
        const SizedBox(height: AppSizes.spacingSm),
        // Section tabs
        Expanded(
          child: DefaultTabController(
            length: 5,
            child: Column(
              children: <Widget>[
                TabBar(
                  isScrollable: true,
                  tabs: <Widget>[
                    _SectionTab(
                      label: 'Basic Info',
                      section: MealAdjustmentValidationSection.profile,
                      counts: state.sectionValidationCounts,
                    ),
                    _SectionTab(
                      label: 'Components',
                      section: MealAdjustmentValidationSection.components,
                      counts: state.sectionValidationCounts,
                    ),
                    _SectionTab(
                      label: 'Extras',
                      section: MealAdjustmentValidationSection.extras,
                      counts: state.sectionValidationCounts,
                    ),
                    _SectionTab(
                      label: 'Pricing Rules',
                      section: MealAdjustmentValidationSection.rules,
                      counts: state.sectionValidationCounts,
                    ),
                    _SectionTab(
                      label: 'Validation',
                      section: null,
                      counts: state.sectionValidationCounts,
                      totalIssueCount: (validation?.blockingErrors.length ??
                              0) +
                          (validation?.warnings.length ?? 0),
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      _BasicInfoSection(draft: draft),
                      _ComponentsSection(draft: draft),
                      _ExtrasSection(draft: draft),
                      _PricingRulesSection(
                        draft: draft,
                        explanations: state.ruleExplanations,
                      ),
                      _ValidationSummarySection(
                        validation: validation,
                        healthSummary: state.healthSummary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section tab with badge
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.label,
    required this.section,
    required this.counts,
    this.totalIssueCount,
  });

  final String label;
  final MealAdjustmentValidationSection? section;
  final Map<MealAdjustmentValidationSection, int> counts;
  final int? totalIssueCount;

  @override
  Widget build(BuildContext context) {
    final int issueCount =
        totalIssueCount ?? (section != null ? (counts[section] ?? 0) : 0);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          if (issueCount > 0) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$issueCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Basic info section
// ─────────────────────────────────────────────────────────────────────────────

class _BasicInfoSection extends ConsumerStatefulWidget {
  const _BasicInfoSection({required this.draft});

  final MealAdjustmentProfileDraft draft;

  @override
  ConsumerState<_BasicInfoSection> createState() => _BasicInfoSectionState();
}

class _BasicInfoSectionState extends ConsumerState<_BasicInfoSection> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _freeSwapController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
    _descriptionController =
        TextEditingController(text: widget.draft.description ?? '');
    _freeSwapController =
        TextEditingController(text: '${widget.draft.freeSwapLimit}');
  }

  @override
  void didUpdateWidget(covariant _BasicInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.id != widget.draft.id) {
      _nameController.text = widget.draft.name;
      _descriptionController.text = widget.draft.description ?? '';
      _freeSwapController.text = '${widget.draft.freeSwapLimit}';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _freeSwapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('meal-profile-editor-name'),
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Profile name'),
            onChanged: (String value) => ref
                .read(adminMealProfileEditorNotifierProvider.notifier)
                .updateBasicInfo(name: value.trim()),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          TextField(
            key: const ValueKey<String>('meal-profile-editor-desc'),
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
            ),
            onChanged: (String value) => ref
                .read(adminMealProfileEditorNotifierProvider.notifier)
                .updateBasicInfo(
                  description: value.trim().isEmpty ? null : value.trim(),
                ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          TextField(
            key: const ValueKey<String>('meal-profile-editor-swaps'),
            controller: _freeSwapController,
            decoration: const InputDecoration(labelText: 'Free swap limit'),
            keyboardType: TextInputType.number,
            onChanged: (String value) => ref
                .read(adminMealProfileEditorNotifierProvider.notifier)
                .updateBasicInfo(
                  freeSwapLimit: int.tryParse(value) ?? 0,
                ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          SwitchListTile(
            key: const ValueKey<String>('meal-profile-editor-active'),
            title: const Text('Active'),
            subtitle: const Text(
              'Inactive profiles will not be used during POS customization.',
            ),
            value: widget.draft.isActive,
            onChanged: (bool value) => ref
                .read(adminMealProfileEditorNotifierProvider.notifier)
                .updateBasicInfo(isActive: value),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Components section
// ─────────────────────────────────────────────────────────────────────────────

class _ComponentsSection extends ConsumerWidget {
  const _ComponentsSection({required this.draft});

  final MealAdjustmentProfileDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (draft.components.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'No components defined.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.spacingSm),
            ElevatedButton.icon(
              key: const ValueKey<String>('meal-profile-add-component'),
              onPressed: () => _addComponent(ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Component'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      children: <Widget>[
        ...draft.components.asMap().entries.map(
          (MapEntry<int, MealAdjustmentComponentDraft> entry) {
            return _ComponentCard(
              index: entry.key,
              component: entry.value,
              onRemove: () => _removeComponent(ref, entry.key),
            );
          },
        ),
        const SizedBox(height: AppSizes.spacingSm),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            key: const ValueKey<String>('meal-profile-add-component'),
            onPressed: () => _addComponent(ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Component'),
          ),
        ),
      ],
    );
  }

  void _addComponent(WidgetRef ref) {
    final List<MealAdjustmentComponentDraft> updated =
        List<MealAdjustmentComponentDraft>.from(draft.components)
          ..add(
            MealAdjustmentComponentDraft(
              componentKey: 'component_${draft.components.length + 1}',
              displayName: 'Component ${draft.components.length + 1}',
              defaultItemProductId: 0,
              quantity: 1,
              canRemove: true,
              sortOrder: draft.components.length,
              isActive: true,
            ),
          );
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updateComponents(updated);
  }

  void _removeComponent(WidgetRef ref, int index) {
    final List<MealAdjustmentComponentDraft> updated =
        List<MealAdjustmentComponentDraft>.from(draft.components)
          ..removeAt(index);
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updateComponents(updated);
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({
    required this.index,
    required this.component,
    required this.onRemove,
  });

  final int index;
  final MealAdjustmentComponentDraft component;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${component.displayName} (${component.componentKey})',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: ValueKey<String>('component-remove-$index'),
                  icon: const Icon(Icons.delete_rounded),
                  color: AppColors.error,
                  onPressed: onRemove,
                  tooltip: 'Remove component',
                ),
              ],
            ),
            Text(
              'Default product: #${component.defaultItemProductId} | Qty: ${component.quantity} | Removable: ${component.canRemove} | Swaps: ${component.swapOptions.length}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (component.swapOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: component.swapOptions
                      .map(
                        (MealAdjustmentComponentOptionDraft option) =>
                            Chip(
                              label: Text(
                                'Swap #${option.optionItemProductId}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                      )
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extras section
// ─────────────────────────────────────────────────────────────────────────────

class _ExtrasSection extends ConsumerWidget {
  const _ExtrasSection({required this.draft});

  final MealAdjustmentProfileDraft draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (draft.extraOptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'No extra options defined.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.spacingSm),
            ElevatedButton.icon(
              key: const ValueKey<String>('meal-profile-add-extra'),
              onPressed: () => _addExtra(ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Extra'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      children: <Widget>[
        ...draft.extraOptions.asMap().entries.map(
          (MapEntry<int, MealAdjustmentExtraOptionDraft> entry) {
            return Card(
              margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
              child: ListTile(
                title: Text(
                  'Extra: product #${entry.value.itemProductId}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Price delta: ${CurrencyFormatter.fromMinor(entry.value.fixedPriceDeltaMinor)} | Active: ${entry.value.isActive}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: IconButton(
                  key: ValueKey<String>('extra-remove-${entry.key}'),
                  icon: const Icon(Icons.delete_rounded),
                  color: AppColors.error,
                  onPressed: () => _removeExtra(ref, entry.key),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSizes.spacingSm),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            key: const ValueKey<String>('meal-profile-add-extra'),
            onPressed: () => _addExtra(ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Extra'),
          ),
        ),
      ],
    );
  }

  void _addExtra(WidgetRef ref) {
    final List<MealAdjustmentExtraOptionDraft> updated =
        List<MealAdjustmentExtraOptionDraft>.from(draft.extraOptions)
          ..add(
            MealAdjustmentExtraOptionDraft(
              itemProductId: 0,
              fixedPriceDeltaMinor: 0,
              sortOrder: draft.extraOptions.length,
              isActive: true,
            ),
          );
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updateExtras(updated);
  }

  void _removeExtra(WidgetRef ref, int index) {
    final List<MealAdjustmentExtraOptionDraft> updated =
        List<MealAdjustmentExtraOptionDraft>.from(draft.extraOptions)
          ..removeAt(index);
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updateExtras(updated);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pricing rules section (B. Pricing Rule Authoring)
// ─────────────────────────────────────────────────────────────────────────────

class _PricingRulesSection extends ConsumerWidget {
  const _PricingRulesSection({
    required this.draft,
    required this.explanations,
  });

  final MealAdjustmentProfileDraft draft;
  final Map<int, String> explanations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (draft.pricingRules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'No pricing rules defined.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.spacingSm),
            ElevatedButton.icon(
              key: const ValueKey<String>('meal-profile-add-rule'),
              onPressed: () => _addRule(ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Rule'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      children: <Widget>[
        ...draft.pricingRules.asMap().entries.map(
          (MapEntry<int, MealAdjustmentPricingRuleDraft> entry) {
            final MealAdjustmentPricingRuleDraft rule = entry.value;
            final int ruleKey = rule.id ?? rule.hashCode;
            final String explanation =
                explanations[ruleKey] ?? 'No explanation available.';
            return _PricingRuleCard(
              index: entry.key,
              rule: rule,
              explanation: explanation,
              onRemove: () => _removeRule(ref, entry.key),
            );
          },
        ),
        const SizedBox(height: AppSizes.spacingSm),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            key: const ValueKey<String>('meal-profile-add-rule'),
            onPressed: () => _addRule(ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Rule'),
          ),
        ),
      ],
    );
  }

  void _addRule(WidgetRef ref) {
    final List<MealAdjustmentPricingRuleDraft> updated =
        List<MealAdjustmentPricingRuleDraft>.from(draft.pricingRules)
          ..add(
            MealAdjustmentPricingRuleDraft(
              name: 'Rule ${draft.pricingRules.length + 1}',
              ruleType: MealAdjustmentPricingRuleType.swap,
              priceDeltaMinor: 0,
              priority: draft.pricingRules.length,
              isActive: true,
            ),
          );
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updatePricingRules(updated);
  }

  void _removeRule(WidgetRef ref, int index) {
    final List<MealAdjustmentPricingRuleDraft> updated =
        List<MealAdjustmentPricingRuleDraft>.from(draft.pricingRules)
          ..removeAt(index);
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updatePricingRules(updated);
  }
}

class _PricingRuleCard extends StatelessWidget {
  const _PricingRuleCard({
    required this.index,
    required this.rule,
    required this.explanation,
    required this.onRemove,
  });

  final int index;
  final MealAdjustmentPricingRuleDraft rule;
  final String explanation;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    rule.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: rule.isActive
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.textSecondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    rule.isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: rule.isActive
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.spacingSm),
                IconButton(
                  key: ValueKey<String>('rule-remove-$index'),
                  icon: const Icon(Icons.delete_rounded),
                  color: AppColors.error,
                  onPressed: onRemove,
                  tooltip: 'Remove rule',
                ),
              ],
            ),
            // Real-time explanation text (Section B requirement)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  explanation,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Text(
              'Type: ${rule.ruleType.name} | Delta: ${CurrencyFormatter.fromMinor(rule.priceDeltaMinor)} | Priority: ${rule.priority} | Conditions: ${rule.conditions.length}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (rule.conditions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rule.conditions
                      .map(
                        (MealAdjustmentPricingRuleConditionDraft condition) =>
                            _ConditionRow(condition: condition),
                      )
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConditionRow extends StatelessWidget {
  const _ConditionRow({required this.condition});

  final MealAdjustmentPricingRuleConditionDraft condition;

  @override
  Widget build(BuildContext context) {
    final String typeLabel = switch (condition.conditionType) {
      MealAdjustmentPricingRuleConditionType.removedComponent =>
        'Removed component',
      MealAdjustmentPricingRuleConditionType.swapToItem => 'Swap to item',
      MealAdjustmentPricingRuleConditionType.extraItem => 'Extra item',
    };
    final String valid = condition.isStructurallyValid ? '' : ' [INVALID]';
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2),
      child: Row(
        children: <Widget>[
          const Icon(Icons.subdirectory_arrow_right_rounded, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$typeLabel: component=${condition.componentKey ?? '-'}, product=${condition.itemProductId ?? '-'}, qty=${condition.quantity}$valid',
              style: TextStyle(
                fontSize: 11,
                color: condition.isStructurallyValid
                    ? AppColors.textSecondary
                    : AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Validation summary section (F. Admin Validation Clarity)
// ─────────────────────────────────────────────────────────────────────────────

class _ValidationSummarySection extends StatelessWidget {
  const _ValidationSummarySection({
    required this.validation,
    required this.healthSummary,
  });

  final MealAdjustmentValidationResult? validation;
  final MealAdjustmentProfileHealthSummary? healthSummary;

  @override
  Widget build(BuildContext context) {
    if (validation == null) {
      return const Center(child: Text('No validation data available.'));
    }

    final List<MealAdjustmentValidationIssue> allIssues = <
      MealAdjustmentValidationIssue
    >[
      ...validation!.blockingErrors,
      ...validation!.warnings,
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      children: <Widget>[
        if (healthSummary != null) ...<Widget>[
          _Banner(
            message: healthSummary!.headline,
            color: _healthColor(healthSummary!.healthStatus),
          ),
          const SizedBox(height: AppSizes.spacingXs),
          Text(
            healthSummary!.body,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.spacingMd),
        ],
        if (allIssues.isEmpty)
          const _Banner(
            message: 'No issues found. Profile is valid.',
            color: AppColors.success,
          )
        else ...<Widget>[
          Text(
            '${validation!.blockingErrors.length} blocking error(s), ${validation!.warnings.length} warning(s)',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          ...allIssues.map(
            (MealAdjustmentValidationIssue issue) => _ValidationIssueRow(
              issue: issue,
              isBlocking: validation!.blockingErrors.contains(issue),
            ),
          ),
        ],
      ],
    );
  }
}

class _ValidationIssueRow extends StatelessWidget {
  const _ValidationIssueRow({
    required this.issue,
    required this.isBlocking,
  });

  final MealAdjustmentValidationIssue issue;
  final bool isBlocking;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color:
          isBlocking
              ? AppColors.error.withValues(alpha: 0.06)
              : AppColors.warning.withValues(alpha: 0.06),
      child: ListTile(
        dense: true,
        leading: Icon(
          isBlocking
              ? Icons.error_rounded
              : Icons.warning_amber_rounded,
          color: isBlocking ? AppColors.error : AppColors.warning,
          size: 20,
        ),
        title: Text(
          issue.message,
          style: const TextStyle(fontSize: 13),
        ),
        subtitle: Text(
          'Section: ${issue.section.name}',
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared
// ─────────────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

Color _healthColor(MealAdjustmentHealthStatus status) {
  switch (status) {
    case MealAdjustmentHealthStatus.valid:
      return AppColors.success;
    case MealAdjustmentHealthStatus.incomplete:
      return AppColors.warning;
    case MealAdjustmentHealthStatus.invalid:
      return AppColors.error;
  }
}
