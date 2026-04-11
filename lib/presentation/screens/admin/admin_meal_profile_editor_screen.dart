import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  const AdminMealProfileEditorScreen({required this.profileId, super.key});

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
    final AdminMealProfileEditorState state = ref.watch(
      adminMealProfileEditorNotifierProvider,
    );

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
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
    final List<_EditorTabDefinition> tabs =
        draft.kind == MealAdjustmentProfileKind.sandwich
        ? <_EditorTabDefinition>[
            _EditorTabDefinition(
              label: 'Basic Info',
              section: MealAdjustmentValidationSection.profile,
              child: _BasicInfoSection(draft: draft),
            ),
            _EditorTabDefinition(
              label: 'Sandwich Settings',
              section: MealAdjustmentValidationSection.profile,
              child: _SandwichSettingsSection(draft: draft),
            ),
            _EditorTabDefinition(
              label: 'Add-ins',
              section: MealAdjustmentValidationSection.extras,
              child: _ExtrasSection(draft: draft),
            ),
            _EditorTabDefinition(
              label: 'Validation',
              section: null,
              totalIssueCount:
                  (validation?.blockingErrors.length ?? 0) +
                  (validation?.warnings.length ?? 0),
              child: _ValidationSummarySection(
                kind: draft.kind,
                validation: validation,
                healthSummary: state.healthSummary,
              ),
            ),
          ]
        : <_EditorTabDefinition>[
            _EditorTabDefinition(
              label: 'Basic Info',
              section: MealAdjustmentValidationSection.profile,
              child: _BasicInfoSection(draft: draft),
            ),
            _EditorTabDefinition(
              label: 'Components',
              section: MealAdjustmentValidationSection.components,
              child: _ComponentsSection(draft: draft),
            ),
            _EditorTabDefinition(
              label: 'Add-ins',
              section: MealAdjustmentValidationSection.extras,
              child: _ExtrasSection(draft: draft),
            ),
            _EditorTabDefinition(
              label: 'Pricing Rules',
              section: MealAdjustmentValidationSection.rules,
              child: _PricingRulesSection(
                draft: draft,
                validation: validation,
                explanations: state.ruleExplanations,
              ),
            ),
            _EditorTabDefinition(
              label: 'Validation',
              section: null,
              totalIssueCount:
                  (validation?.blockingErrors.length ?? 0) +
                  (validation?.warnings.length ?? 0),
              child: _ValidationSummarySection(
                kind: draft.kind,
                validation: validation,
                healthSummary: state.healthSummary,
              ),
            ),
          ];

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
              onPressed: state.isSaving || !state.isDirty || !state.canSave
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
        if (state.healthSummary != null &&
            (draft.kind != MealAdjustmentProfileKind.sandwich ||
                state.healthSummary!.healthStatus !=
                    MealAdjustmentHealthStatus.valid))
          _Banner(
            message: state.healthSummary!.headline,
            color: _healthColor(state.healthSummary!.healthStatus),
          ),
        const SizedBox(height: AppSizes.spacingSm),
        // Section tabs
        Expanded(
          child: DefaultTabController(
            length: tabs.length,
            child: Column(
              children: <Widget>[
                TabBar(
                  isScrollable: true,
                  tabs: tabs
                      .map(
                        (_EditorTabDefinition tab) => _SectionTab(
                          label: tab.label,
                          section: tab.section,
                          counts: state.sectionValidationCounts,
                          totalIssueCount: tab.totalIssueCount,
                        ),
                      )
                      .toList(growable: false),
                ),
                Expanded(
                  child: TabBarView(
                    children: tabs
                        .map((_EditorTabDefinition tab) => tab.child)
                        .toList(growable: false),
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
              key: ValueKey<String>(
                'meal-profile-tab-badge-${section?.name ?? label.toLowerCase()}',
              ),
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

class _EditorTabDefinition {
  const _EditorTabDefinition({
    required this.label,
    required this.section,
    required this.child,
    this.totalIssueCount,
  });

  final String label;
  final MealAdjustmentValidationSection? section;
  final Widget child;
  final int? totalIssueCount;
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
    _descriptionController = TextEditingController(
      text: widget.draft.description ?? '',
    );
    _freeSwapController = TextEditingController(
      text: '${widget.draft.freeSwapLimit}',
    );
  }

  @override
  void didUpdateWidget(covariant _BasicInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft.id != widget.draft.id ||
        oldWidget.draft.kind != widget.draft.kind ||
        oldWidget.draft.freeSwapLimit != widget.draft.freeSwapLimit) {
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
    final bool isSandwich =
        widget.draft.kind == MealAdjustmentProfileKind.sandwich;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ProfileKindGuidancePanel(kind: widget.draft.kind),
          const SizedBox(height: AppSizes.spacingMd),
          if (!isSandwich) ...<Widget>[
            DropdownButtonFormField<MealAdjustmentProfileKind>(
              key: const ValueKey<String>('meal-profile-editor-kind'),
              value: widget.draft.kind,
              decoration: const InputDecoration(labelText: 'Profile type'),
              items: MealAdjustmentProfileKind.values
                  .map(
                    (MealAdjustmentProfileKind kind) =>
                        DropdownMenuItem<MealAdjustmentProfileKind>(
                          value: kind,
                          child: Text(_profileKindLabel(kind)),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (MealAdjustmentProfileKind? value) {
                if (value == null) {
                  return;
                }
                ref
                    .read(adminMealProfileEditorNotifierProvider.notifier)
                    .updateBasicInfo(kind: value);
              },
            ),
            const SizedBox(height: AppSizes.spacingSm),
          ],
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
          if (!isSandwich) ...<Widget>[
            const SizedBox(height: AppSizes.spacingSm),
            TextField(
              key: const ValueKey<String>('meal-profile-editor-swaps'),
              controller: _freeSwapController,
              decoration: const InputDecoration(labelText: 'Free swap limit'),
              keyboardType: TextInputType.number,
              onChanged: (String value) => ref
                  .read(adminMealProfileEditorNotifierProvider.notifier)
                  .updateBasicInfo(freeSwapLimit: int.tryParse(value) ?? 0),
            ),
          ],
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

String _profileKindLabel(MealAdjustmentProfileKind kind) {
  switch (kind) {
    case MealAdjustmentProfileKind.standard:
      return 'Standard Meal Profile';
    case MealAdjustmentProfileKind.sandwich:
      return 'Sandwich Profile';
  }
}

class _ProfileKindGuidancePanel extends StatelessWidget {
  const _ProfileKindGuidancePanel({required this.kind});

  final MealAdjustmentProfileKind kind;

  @override
  Widget build(BuildContext context) {
    final bool isSandwich = kind == MealAdjustmentProfileKind.sandwich;
    return Container(
      key: ValueKey<String>(
        isSandwich ? 'sandwich-profile-guidance' : 'standard-profile-guidance',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isSandwich ? 'Sandwich Profile' : 'Standard Meal Profile',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSandwich
                ? 'This profile controls editable bread surcharges, enabled sauces, sandwich-only toast, and paid add-ins.'
                : 'This profile defines standard meal behavior including components, swap options, add-ins, and pricing rules.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isSandwich) ...<Widget>[
            const SizedBox(height: 4),
            const Text(
              'Use Components and Pricing Rules tabs to define default meal structure and rule-based price changes. Add-ins remain separate paid extras.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sandwich settings section
// ─────────────────────────────────────────────────────────────────────────────

class _SandwichSettingsSection extends ConsumerStatefulWidget {
  const _SandwichSettingsSection({required this.draft});

  final MealAdjustmentProfileDraft draft;

  @override
  ConsumerState<_SandwichSettingsSection> createState() =>
      _SandwichSettingsSectionState();
}

class _SandwichSettingsSectionState
    extends ConsumerState<_SandwichSettingsSection> {
  late final TextEditingController _sandwichSurchargeController;
  late final TextEditingController _baguetteSurchargeController;
  String? _sandwichSurchargeParseError;
  String? _baguetteSurchargeParseError;

  @override
  void initState() {
    super.initState();
    _sandwichSurchargeController = TextEditingController(
      text: CurrencyFormatter.toEditableMajorInput(
        widget.draft.sandwichSettings.sandwichSurchargeMinor,
      ),
    );
    _baguetteSurchargeController = TextEditingController(
      text: CurrencyFormatter.toEditableMajorInput(
        widget.draft.sandwichSettings.baguetteSurchargeMinor,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _SandwichSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextSandwich = CurrencyFormatter.toEditableMajorInput(
      widget.draft.sandwichSettings.sandwichSurchargeMinor,
    );
    final String nextBaguette = CurrencyFormatter.toEditableMajorInput(
      widget.draft.sandwichSettings.baguetteSurchargeMinor,
    );
    if (oldWidget.draft.sandwichSettings.sandwichSurchargeMinor !=
            widget.draft.sandwichSettings.sandwichSurchargeMinor &&
        _sandwichSurchargeController.text != nextSandwich) {
      _sandwichSurchargeController.text = nextSandwich;
    }
    if (oldWidget.draft.sandwichSettings.baguetteSurchargeMinor !=
            widget.draft.sandwichSettings.baguetteSurchargeMinor &&
        _baguetteSurchargeController.text != nextBaguette) {
      _baguetteSurchargeController.text = nextBaguette;
    }
  }

  @override
  void dispose() {
    _sandwichSurchargeController.dispose();
    _baguetteSurchargeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.draft.kind != MealAdjustmentProfileKind.sandwich) {
      return const Center(
        child: Text(
          'Sandwich settings are only available for sandwich profiles.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final SandwichProfileSettings settings = widget.draft.sandwichSettings;
    final AsyncValue<AdminMealProfileProductCatalog> catalogAsync = ref.watch(
      adminMealProfileProductCatalogProvider,
    );
    final AdminMealProfileProductCatalog? catalog = catalogAsync.valueOrNull;
    final String? catalogError = catalogAsync.hasError
        ? 'Sauce products could not be loaded. Refresh and try again.'
        : null;
    final List<AdminMealProfileProductOption> sauceProducts =
        catalog?.activeSauceProducts ?? const <AdminMealProfileProductOption>[];
    return ListView(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      children: <Widget>[
        Container(
          key: const ValueKey<String>('sandwich-settings-help'),
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.spacingSm),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: const Text(
            'Roll uses the product base price. Sandwich and Baguette add the surcharges set here. Sauces are free multi-select options. Toast stays free and only appears when Sandwich bread is selected.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.spacingMd),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.spacingSm),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Roll',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'Base price',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spacingMd),
        TextField(
          key: const ValueKey<String>('meal-profile-editor-sandwich-surcharge'),
          controller: _sandwichSurchargeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Sandwich surcharge',
            helperText: 'Added to the base product price for Sandwich bread.',
            errorText: _sandwichSurchargeParseError,
          ),
          onChanged: _updateSandwichSurcharge,
        ),
        const SizedBox(height: AppSizes.spacingMd),
        TextField(
          key: const ValueKey<String>('meal-profile-editor-baguette-surcharge'),
          controller: _baguetteSurchargeController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Baguette surcharge',
            helperText: 'Added to the base product price for Baguette bread.',
            errorText: _baguetteSurchargeParseError,
          ),
          onChanged: _updateBaguetteSurcharge,
        ),
        const SizedBox(height: AppSizes.spacingMd),
        const Text(
          'Sauce options',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSizes.spacingXs),
        if (catalogError != null)
          _InlineIssueBanner(message: catalogError)
        else if (sauceProducts.isEmpty)
          const Text(
            'No active products were found in the Sauces category.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Wrap(
            spacing: AppSizes.spacingSm,
            runSpacing: AppSizes.spacingSm,
            children: sauceProducts
                .map((AdminMealProfileProductOption sauceProduct) {
                  final bool isSelected = settings.sauceProductIds.contains(
                    sauceProduct.id,
                  );
                  return FilterChip(
                    key: ValueKey<String>(
                      'sandwich-profile-sauce-${sauceProduct.id}',
                    ),
                    label: Text(sauceProduct.name),
                    selected: isSelected,
                    onSelected: (bool value) {
                      final SandwichProfileSettings latestSettings =
                          _currentSandwichSettings;
                      final List<int> nextOptions = List<int>.from(
                        latestSettings.sauceProductIds,
                      );
                      if (value) {
                        nextOptions.add(sauceProduct.id);
                      } else {
                        nextOptions.remove(sauceProduct.id);
                      }
                      _updateSandwichSettings(
                        latestSettings.copyWith(
                          sauceProductIds: normalizeSandwichSauceProductIds(
                            nextOptions,
                          ),
                        ),
                      );
                    },
                  );
                })
                .toList(growable: false),
          ),
      ],
    );
  }

  void _updateSandwichSurcharge(String value) {
    final int? parsed = CurrencyFormatter.tryParseEditableMajorInput(
      value.trim(),
    );
    if (parsed == null) {
      setState(() {
        _sandwichSurchargeParseError = 'Enter a valid amount';
      });
      return;
    }
    if (_sandwichSurchargeParseError != null) {
      setState(() {
        _sandwichSurchargeParseError = null;
      });
    }
    _updateSandwichSettings(
      _currentSandwichSettings.copyWith(sandwichSurchargeMinor: parsed),
    );
  }

  void _updateBaguetteSurcharge(String value) {
    final int? parsed = CurrencyFormatter.tryParseEditableMajorInput(
      value.trim(),
    );
    if (parsed == null) {
      setState(() {
        _baguetteSurchargeParseError = 'Enter a valid amount';
      });
      return;
    }
    if (_baguetteSurchargeParseError != null) {
      setState(() {
        _baguetteSurchargeParseError = null;
      });
    }
    _updateSandwichSettings(
      _currentSandwichSettings.copyWith(baguetteSurchargeMinor: parsed),
    );
  }

  void _updateSandwichSettings(SandwichProfileSettings settings) {
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updateSandwichSettings(settings);
  }

  SandwichProfileSettings get _currentSandwichSettings {
    return ref
            .read(adminMealProfileEditorNotifierProvider)
            .draft
            ?.sandwichSettings ??
        widget.draft.sandwichSettings;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Components section
// ─────────────────────────────────────────────────────────────────────────────

class _ComponentsSection extends ConsumerStatefulWidget {
  const _ComponentsSection({required this.draft});

  final MealAdjustmentProfileDraft draft;

  @override
  ConsumerState<_ComponentsSection> createState() => _ComponentsSectionState();
}

class _ComponentsSectionState extends ConsumerState<_ComponentsSection> {
  int? _expandedIndex;

  @override
  void didUpdateWidget(covariant _ComponentsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_expandedIndex != null &&
        _expandedIndex! >= widget.draft.components.length) {
      _expandedIndex = widget.draft.components.isEmpty
          ? null
          : widget.draft.components.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.draft.kind == MealAdjustmentProfileKind.sandwich) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSizes.spacingMd),
          child: Text(
            'Sandwich profiles do not use components. Bread, sauce, and toast are applied automatically by the sandwich flow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    final AsyncValue<AdminMealProfileProductCatalog> catalogAsync = ref.watch(
      adminMealProfileProductCatalogProvider,
    );
    final AdminMealProfileProductCatalog? catalog = catalogAsync.valueOrNull;
    final String? catalogError = catalogAsync.hasError
        ? 'Products are unavailable. Existing invalid references are still visible.'
        : null;

    if (widget.draft.components.isEmpty) {
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
              onPressed: _addComponent,
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
        ...widget.draft.components.asMap().entries.map((
          MapEntry<int, MealAdjustmentComponentDraft> entry,
        ) {
          return _ComponentCard(
            key: ValueKey<String>(
              'component-card-${entry.key}-${entry.value.componentKey}-${entry.value.id ?? 'draft'}',
            ),
            index: entry.key,
            component: entry.value,
            allComponents: widget.draft.components,
            isExpanded: _expandedIndex == entry.key,
            catalog: catalog,
            isCatalogLoading: catalogAsync.isLoading,
            catalogError: catalogError,
            onToggleExpanded: () {
              setState(() {
                _expandedIndex = _expandedIndex == entry.key ? null : entry.key;
              });
            },
            onChanged: (MealAdjustmentComponentDraft updated) {
              ref
                  .read(adminMealProfileEditorNotifierProvider.notifier)
                  .updateComponentAt(entry.key, updated);
            },
            onRemove: () => _removeComponent(entry.key),
          );
        }),
        const SizedBox(height: AppSizes.spacingSm),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            key: const ValueKey<String>('meal-profile-add-component'),
            onPressed: _addComponent,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Component'),
          ),
        ),
      ],
    );
  }

  void _addComponent() {
    setState(() {
      _expandedIndex = widget.draft.components.length;
    });
    ref.read(adminMealProfileEditorNotifierProvider.notifier).addComponent();
  }

  void _removeComponent(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .removeComponentAt(index);
  }
}

class _ComponentCard extends StatefulWidget {
  const _ComponentCard({
    required this.index,
    required this.component,
    required this.allComponents,
    required this.isExpanded,
    required this.catalog,
    required this.isCatalogLoading,
    required this.catalogError,
    required this.onToggleExpanded,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int index;
  final MealAdjustmentComponentDraft component;
  final List<MealAdjustmentComponentDraft> allComponents;
  final bool isExpanded;
  final AdminMealProfileProductCatalog? catalog;
  final bool isCatalogLoading;
  final String? catalogError;
  final VoidCallback onToggleExpanded;
  final ValueChanged<MealAdjustmentComponentDraft> onChanged;
  final VoidCallback onRemove;

  @override
  State<_ComponentCard> createState() => _ComponentCardState();
}

class _ComponentCardState extends State<_ComponentCard> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _componentKeyController;
  late final TextEditingController _quantityController;
  String? _swapMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.component.displayName,
    );
    _componentKeyController = TextEditingController(
      text: widget.component.componentKey,
    );
    _quantityController = TextEditingController(
      text: '${widget.component.quantity}',
    );
  }

  @override
  void didUpdateWidget(covariant _ComponentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.component.displayName != widget.component.displayName &&
        _displayNameController.text != widget.component.displayName) {
      _displayNameController.text = widget.component.displayName;
    }
    if (oldWidget.component.componentKey != widget.component.componentKey &&
        _componentKeyController.text != widget.component.componentKey) {
      _componentKeyController.text = widget.component.componentKey;
    }
    final String nextQuantity = '${widget.component.quantity}';
    if (oldWidget.component.quantity != widget.component.quantity &&
        _quantityController.text != nextQuantity) {
      _quantityController.text = nextQuantity;
    }
    if (oldWidget.component.swapOptions != widget.component.swapOptions &&
        _swapMessage != null) {
      _swapMessage = null;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _componentKeyController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminMealProfileProductOption? defaultProduct = _resolveProduct(
      widget.component.defaultItemProductId,
    );
    final String? displayNameError = widget.component.displayName.trim().isEmpty
        ? 'Display name required'
        : null;
    final String? componentKeyError = _componentKeyError;
    final String? quantityError = widget.component.quantity > 0
        ? null
        : 'Quantity must be greater than 0';
    final String? defaultProductError = _defaultProductError(defaultProduct);
    final List<String> summaryMessages = <String>[
      if (displayNameError != null) displayNameError,
      if (componentKeyError != null) componentKeyError,
      if (defaultProductError != null) defaultProductError,
      if (quantityError != null) quantityError,
    ];
    final int swapIssueCount = widget.component.swapOptions.fold<int>(
      0,
      (int total, MealAdjustmentComponentOptionDraft option) =>
          total + _swapMessages(option).length,
    );
    final int issueCount = summaryMessages.length + swapIssueCount;
    final String title = widget.component.displayName.trim().isEmpty
        ? 'Unnamed component'
        : widget.component.displayName.trim();

    return Card(
      key: ValueKey<String>('meal-profile-component-card-${widget.index}'),
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingMd),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.component.componentKey.trim().isEmpty
                                  ? 'Key not set'
                                  : widget.component.componentKey,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          if (issueCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$issueCount issue${issueCount == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Default product: ${_productSummary(defaultProduct, widget.component.defaultItemProductId)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Quantity: ${widget.component.quantity} · Removable: ${widget.component.canRemove ? 'Yes' : 'No'} · Sort order: ${widget.component.sortOrder + 1} · Swaps: ${widget.component.swapOptions.length}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (summaryMessages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            summaryMessages.length == 1
                                ? summaryMessages.first
                                : '${summaryMessages.first} +${summaryMessages.length - 1} more',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.spacingSm),
                OutlinedButton.icon(
                  key: ValueKey<String>('component-expand-${widget.index}'),
                  onPressed: widget.onToggleExpanded,
                  icon: Icon(
                    widget.isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.edit_rounded,
                  ),
                  label: Text(widget.isExpanded ? 'Collapse' : 'Edit'),
                ),
                const SizedBox(width: AppSizes.spacingSm),
                IconButton(
                  key: ValueKey<String>('component-remove-${widget.index}'),
                  icon: const Icon(Icons.delete_rounded),
                  color: AppColors.error,
                  onPressed: widget.onRemove,
                  tooltip: 'Delete component',
                ),
              ],
            ),
            if (widget.isExpanded)
              ..._buildExpandedContent(
                defaultProduct: defaultProduct,
                displayNameError: displayNameError,
                componentKeyError: componentKeyError,
                quantityError: quantityError,
                defaultProductError: defaultProductError,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExpandedContent({
    required AdminMealProfileProductOption? defaultProduct,
    required String? displayNameError,
    required String? componentKeyError,
    required String? quantityError,
    required String? defaultProductError,
  }) {
    return <Widget>[
      const SizedBox(height: AppSizes.spacingMd),
      TextField(
        key: ValueKey<String>('component-display-name-${widget.index}'),
        controller: _displayNameController,
        decoration: InputDecoration(
          labelText: 'Display name',
          errorText: displayNameError,
        ),
        onChanged: (String value) {
          widget.onChanged(widget.component.copyWith(displayName: value));
        },
      ),
      const SizedBox(height: AppSizes.spacingMd),
      TextField(
        key: ValueKey<String>('component-key-${widget.index}'),
        controller: _componentKeyController,
        decoration: InputDecoration(
          labelText: 'Component key',
          helperText: 'Stable semantic slot used by pricing and runtime logic.',
          errorText: componentKeyError,
        ),
        onChanged: (String value) {
          widget.onChanged(widget.component.copyWith(componentKey: value));
        },
      ),
      const SizedBox(height: AppSizes.spacingMd),
      _ProductSelectionField(
        key: ValueKey<String>('component-default-product-${widget.index}'),
        label: 'Default product',
        productLabel: _productSummary(
          defaultProduct,
          widget.component.defaultItemProductId,
        ),
        productSubtitle: defaultProduct != null
            ? defaultProduct.categoryName
            : null,
        errorText: defaultProductError,
        isLoading: widget.isCatalogLoading,
        disabledReason: widget.catalogError,
        onPressed: () => _selectDefaultProduct(),
      ),
      const SizedBox(height: AppSizes.spacingMd),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Quantity',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    IconButton(
                      key: ValueKey<String>(
                        'component-qty-dec-${widget.index}',
                      ),
                      onPressed: () {
                        final int nextValue = widget.component.quantity > 0
                            ? widget.component.quantity - 1
                            : 0;
                        widget.onChanged(
                          widget.component.copyWith(quantity: nextValue),
                        );
                      },
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    SizedBox(
                      width: 96,
                      child: TextField(
                        key: ValueKey<String>(
                          'component-qty-input-${widget.index}',
                        ),
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(errorText: quantityError),
                        onChanged: (String value) {
                          final int nextValue = int.tryParse(value) ?? 0;
                          widget.onChanged(
                            widget.component.copyWith(quantity: nextValue),
                          );
                        },
                      ),
                    ),
                    IconButton(
                      key: ValueKey<String>(
                        'component-qty-inc-${widget.index}',
                      ),
                      onPressed: () {
                        widget.onChanged(
                          widget.component.copyWith(
                            quantity: widget.component.quantity + 1,
                          ),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          Expanded(
            child: SwitchListTile(
              key: ValueKey<String>('component-removable-${widget.index}'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Removable'),
              subtitle: const Text(
                'Controls whether the default product can be removed.',
              ),
              value: widget.component.canRemove,
              onChanged: (bool value) {
                widget.onChanged(widget.component.copyWith(canRemove: value));
              },
            ),
          ),
        ],
      ),
      const Divider(height: AppSizes.spacingLg * 2),
      Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'Swap options',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          OutlinedButton.icon(
            key: ValueKey<String>('component-add-swap-${widget.index}'),
            onPressed: () => _addSwap(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add swap'),
          ),
        ],
      ),
      const SizedBox(height: AppSizes.spacingSm),
      if (_swapMessage != null)
        _InlineIssueBanner(
          key: ValueKey<String>('component-swap-message-${widget.index}'),
          message: _swapMessage!,
        ),
      if (widget.component.swapOptions.isEmpty)
        const Text(
          'No swap options yet.',
          style: TextStyle(color: AppColors.textSecondary),
        )
      else
        ...widget.component.swapOptions.asMap().entries.map((
          MapEntry<int, MealAdjustmentComponentOptionDraft> entry,
        ) {
          return _SwapOptionRow(
            key: ValueKey<String>(
              'component-swap-row-${widget.index}-${entry.key}-${entry.value.id ?? 'draft'}',
            ),
            componentIndex: widget.index,
            swapIndex: entry.key,
            option: entry.value,
            siblingOptions: widget.component.swapOptions,
            defaultProductId: widget.component.defaultItemProductId,
            catalog: widget.catalog,
            isCatalogLoading: widget.isCatalogLoading,
            catalogError: widget.catalogError,
            onChanged: (MealAdjustmentComponentOptionDraft updated) {
              final List<MealAdjustmentComponentOptionDraft> swaps =
                  List<MealAdjustmentComponentOptionDraft>.from(
                    widget.component.swapOptions,
                  );
              swaps[entry.key] = updated;
              widget.onChanged(widget.component.copyWith(swapOptions: swaps));
            },
            onRemove: () {
              final List<MealAdjustmentComponentOptionDraft> swaps =
                  List<MealAdjustmentComponentOptionDraft>.from(
                    widget.component.swapOptions,
                  )..removeAt(entry.key);
              widget.onChanged(widget.component.copyWith(swapOptions: swaps));
            },
            onInvalidSelection: (String message) {
              setState(() {
                _swapMessage = message;
              });
            },
            onValidSelection: () {
              if (_swapMessage == null) {
                return;
              }
              setState(() {
                _swapMessage = null;
              });
            },
          );
        }),
    ];
  }

  String? get _componentKeyError {
    final String normalizedKey = widget.component.componentKey
        .trim()
        .toLowerCase();
    if (normalizedKey.isEmpty) {
      return 'Component key required';
    }
    final int duplicateCount = widget.allComponents
        .where(
          (MealAdjustmentComponentDraft component) =>
              component.componentKey.trim().toLowerCase() == normalizedKey,
        )
        .length;
    if (duplicateCount > 1) {
      return 'Component key must be unique';
    }
    return null;
  }

  AdminMealProfileProductOption? _resolveProduct(int productId) {
    return widget.catalog?.byId[productId];
  }

  String? _defaultProductError(AdminMealProfileProductOption? product) {
    if (widget.component.defaultItemProductId <= 0) {
      return 'Default product required';
    }
    if (product == null) {
      return 'Default product no longer exists';
    }
    if (!product.isActive) {
      return 'Default product is inactive';
    }
    return null;
  }

  String _productSummary(
    AdminMealProfileProductOption? product,
    int productId,
  ) {
    if (productId <= 0) {
      return 'Not selected';
    }
    if (product == null) {
      return 'Missing product #$productId';
    }
    if (!product.isActive) {
      return '${product.name} (Inactive)';
    }
    return product.name;
  }

  List<String> _swapMessages(MealAdjustmentComponentOptionDraft option) {
    final List<String> messages = <String>[];
    if (option.optionItemProductId <= 0) {
      messages.add('Swap option product required');
      return messages;
    }
    if (widget.component.defaultItemProductId > 0 &&
        option.optionItemProductId == widget.component.defaultItemProductId) {
      messages.add('Swap option cannot match default product');
    }
    final int duplicateCount = widget.component.swapOptions
        .where(
          (MealAdjustmentComponentOptionDraft candidate) =>
              candidate.optionItemProductId == option.optionItemProductId,
        )
        .length;
    if (duplicateCount > 1) {
      messages.add('Swap option duplicates existing item');
    }
    final AdminMealProfileProductOption? product = _resolveProduct(
      option.optionItemProductId,
    );
    if (product == null) {
      messages.add('Swap product no longer exists');
    } else if (!product.isActive) {
      messages.add('Swap product is inactive');
    }
    return messages;
  }

  Future<void> _selectDefaultProduct() async {
    final AdminMealProfileProductCatalog? catalog = widget.catalog;
    if (catalog == null) {
      return;
    }
    final AdminMealProfileProductOption? selected =
        await showDialog<AdminMealProfileProductOption>(
          context: context,
          builder: (BuildContext context) {
            return _ProductPickerDialog(
              title: 'Select default product',
              products: catalog.activeProducts,
              selectedProductId: widget.component.defaultItemProductId,
            );
          },
        );
    if (selected == null) {
      return;
    }
    widget.onChanged(
      widget.component.copyWith(defaultItemProductId: selected.id),
    );
  }

  Future<void> _addSwap() async {
    final AdminMealProfileProductCatalog? catalog = widget.catalog;
    if (catalog == null) {
      return;
    }
    final AdminMealProfileProductOption? selected =
        await showDialog<AdminMealProfileProductOption>(
          context: context,
          builder: (BuildContext context) {
            return _ProductPickerDialog(
              title: 'Add swap option',
              products: catalog.activeProducts,
            );
          },
        );
    if (selected == null) {
      return;
    }
    final String? validationMessage = _validateSwapSelection(selected.id);
    if (validationMessage != null) {
      setState(() {
        _swapMessage = validationMessage;
      });
      return;
    }
    setState(() {
      _swapMessage = null;
    });
    final List<MealAdjustmentComponentOptionDraft> swaps =
        List<MealAdjustmentComponentOptionDraft>.from(
          widget.component.swapOptions,
        )..add(
          MealAdjustmentComponentOptionDraft(
            optionItemProductId: selected.id,
            fixedPriceDeltaMinor: null,
            sortOrder: widget.component.swapOptions.length,
            isActive: true,
          ),
        );
    widget.onChanged(widget.component.copyWith(swapOptions: swaps));
  }

  String? _validateSwapSelection(int productId, {int? editingIndex}) {
    if (widget.component.defaultItemProductId > 0 &&
        productId == widget.component.defaultItemProductId) {
      return 'Swap option cannot match default product';
    }
    final bool duplicateExists = widget.component.swapOptions
        .asMap()
        .entries
        .any((MapEntry<int, MealAdjustmentComponentOptionDraft> entry) {
          if (editingIndex != null && entry.key == editingIndex) {
            return false;
          }
          return entry.value.optionItemProductId == productId;
        });
    if (duplicateExists) {
      return 'Swap option duplicates existing item';
    }
    return null;
  }
}

class _SwapOptionRow extends StatefulWidget {
  const _SwapOptionRow({
    required this.componentIndex,
    required this.swapIndex,
    required this.option,
    required this.siblingOptions,
    required this.defaultProductId,
    required this.catalog,
    required this.isCatalogLoading,
    required this.catalogError,
    required this.onChanged,
    required this.onRemove,
    required this.onInvalidSelection,
    required this.onValidSelection,
    super.key,
  });

  final int componentIndex;
  final int swapIndex;
  final MealAdjustmentComponentOptionDraft option;
  final List<MealAdjustmentComponentOptionDraft> siblingOptions;
  final int defaultProductId;
  final AdminMealProfileProductCatalog? catalog;
  final bool isCatalogLoading;
  final String? catalogError;
  final ValueChanged<MealAdjustmentComponentOptionDraft> onChanged;
  final VoidCallback onRemove;
  final ValueChanged<String> onInvalidSelection;
  final VoidCallback onValidSelection;

  @override
  State<_SwapOptionRow> createState() => _SwapOptionRowState();
}

class _SwapOptionRowState extends State<_SwapOptionRow> {
  late final TextEditingController _deltaController;

  @override
  void initState() {
    super.initState();
    _deltaController = TextEditingController(
      text: widget.option.fixedPriceDeltaMinor == null
          ? ''
          : CurrencyFormatter.toEditableMajorInput(
              widget.option.fixedPriceDeltaMinor!,
            ),
    );
  }

  @override
  void didUpdateWidget(covariant _SwapOptionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextValue = widget.option.fixedPriceDeltaMinor == null
        ? ''
        : CurrencyFormatter.toEditableMajorInput(
            widget.option.fixedPriceDeltaMinor!,
          );
    if (oldWidget.option.fixedPriceDeltaMinor !=
            widget.option.fixedPriceDeltaMinor &&
        _deltaController.text != nextValue) {
      _deltaController.text = nextValue;
    }
  }

  @override
  void dispose() {
    _deltaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminMealProfileProductOption? product =
        widget.catalog?.byId[widget.option.optionItemProductId];
    final String productLabel;
    if (widget.option.optionItemProductId <= 0) {
      productLabel = 'Not selected';
    } else if (product == null) {
      productLabel = 'Missing product #${widget.option.optionItemProductId}';
    } else if (!product.isActive) {
      productLabel = '${product.name} (Inactive)';
    } else {
      productLabel = product.name;
    }

    final List<String> errorMessages = <String>[
      if (widget.option.optionItemProductId <= 0)
        'Swap option product required',
      if (widget.defaultProductId > 0 &&
          widget.option.optionItemProductId == widget.defaultProductId)
        'Swap option cannot match default product',
      if (_duplicateCount > 1) 'Swap option duplicates existing item',
      if (widget.option.optionItemProductId > 0 && product == null)
        'Swap product no longer exists',
      if (product != null && !product.isActive) 'Swap product is inactive',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Swap ${widget.swapIndex + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: ValueKey<String>(
                  'component-swap-remove-${widget.componentIndex}-${widget.swapIndex}',
                ),
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Remove swap',
              ),
            ],
          ),
          _ProductSelectionField(
            key: ValueKey<String>(
              'component-swap-product-${widget.componentIndex}-${widget.swapIndex}',
            ),
            label: 'Swap product',
            productLabel: productLabel,
            productSubtitle: product != null ? product.categoryName : null,
            errorText: errorMessages.isEmpty ? null : errorMessages.first,
            isLoading: widget.isCatalogLoading,
            disabledReason: widget.catalogError,
            onPressed: () => _selectProduct(),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          TextField(
            key: ValueKey<String>(
              'component-swap-delta-${widget.componentIndex}-${widget.swapIndex}',
            ),
            controller: _deltaController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fixed price delta',
              hintText: 'Optional',
              helperText:
                  'Leave blank to use rule pricing or a zero fallback for this swap.',
            ),
            onChanged: (String value) {
              final String trimmed = value.trim();
              if (trimmed.isEmpty) {
                widget.onChanged(
                  widget.option.copyWith(fixedPriceDeltaMinor: null),
                );
                return;
              }
              final int? parsed = CurrencyFormatter.tryParseEditableMajorInput(
                trimmed,
              );
              if (parsed == null) {
                return;
              }
              widget.onChanged(
                widget.option.copyWith(fixedPriceDeltaMinor: parsed),
              );
            },
          ),
          if (errorMessages.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: errorMessages
                    .skip(1)
                    .map((String message) => _InlineIssueText(message: message))
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  int get _duplicateCount => widget.siblingOptions
      .where(
        (MealAdjustmentComponentOptionDraft option) =>
            option.optionItemProductId == widget.option.optionItemProductId,
      )
      .length;

  Future<void> _selectProduct() async {
    final AdminMealProfileProductCatalog? catalog = widget.catalog;
    if (catalog == null) {
      return;
    }
    final AdminMealProfileProductOption? selected =
        await showDialog<AdminMealProfileProductOption>(
          context: context,
          builder: (BuildContext context) {
            return _ProductPickerDialog(
              title: 'Select swap product',
              products: catalog.activeProducts,
              selectedProductId: widget.option.optionItemProductId,
            );
          },
        );
    if (selected == null) {
      return;
    }
    if (widget.defaultProductId > 0 && selected.id == widget.defaultProductId) {
      widget.onInvalidSelection('Swap option cannot match default product');
      return;
    }
    final bool duplicateExists = widget.siblingOptions.asMap().entries.any((
      MapEntry<int, MealAdjustmentComponentOptionDraft> entry,
    ) {
      if (entry.key == widget.swapIndex) {
        return false;
      }
      return entry.value.optionItemProductId == selected.id;
    });
    if (duplicateExists) {
      widget.onInvalidSelection('Swap option duplicates existing item');
      return;
    }
    widget.onValidSelection();
    widget.onChanged(widget.option.copyWith(optionItemProductId: selected.id));
  }
}

class _ProductSelectionField extends StatelessWidget {
  const _ProductSelectionField({
    required this.label,
    required this.productLabel,
    required this.isLoading,
    required this.onPressed,
    super.key,
    this.productSubtitle,
    this.errorText,
    this.disabledReason,
  });

  final String label;
  final String productLabel;
  final String? productSubtitle;
  final String? errorText;
  final bool isLoading;
  final String? disabledReason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = isLoading || disabledReason != null;
    return InputDecorator(
      decoration: InputDecoration(labelText: label, errorText: errorText),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  productLabel,
                  style: TextStyle(
                    color: productLabel == 'Not selected'
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (productSubtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      productSubtitle!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (disabledReason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      disabledReason!,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.spacingSm),
          OutlinedButton.icon(
            onPressed: isDisabled ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(isLoading ? 'Loading' : 'Choose'),
          ),
        ],
      ),
    );
  }
}

class _ProductPickerDialog extends StatefulWidget {
  const _ProductPickerDialog({
    required this.title,
    required this.products,
    this.selectedProductId,
  });

  final String title;
  final List<AdminMealProfileProductOption> products;
  final int? selectedProductId;

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String normalizedQuery = _query.trim().toLowerCase();
    final List<AdminMealProfileProductOption> filteredProducts = widget.products
        .where((AdminMealProfileProductOption product) {
          if (normalizedQuery.isEmpty) {
            return true;
          }
          return product.searchLabel.contains(normalizedQuery);
        })
        .toList(growable: false);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: <Widget>[
            TextField(
              key: const ValueKey<String>('meal-profile-product-search'),
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search products',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (String value) {
                setState(() {
                  _query = value;
                });
              },
            ),
            const SizedBox(height: AppSizes.spacingMd),
            Expanded(
              child: filteredProducts.isEmpty
                  ? const Center(
                      child: Text(
                        'No active products match this search.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredProducts.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (BuildContext context, int index) {
                        final AdminMealProfileProductOption product =
                            filteredProducts[index];
                        return ListTile(
                          key: ValueKey<String>(
                            'meal-profile-product-option-${product.id}',
                          ),
                          title: Text(product.name),
                          subtitle: Text(product.categoryName),
                          trailing: widget.selectedProductId == product.id
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () => Navigator.of(context).pop(product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _InlineIssueBanner extends StatelessWidget {
  const _InlineIssueBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineIssueText extends StatelessWidget {
  const _InlineIssueText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.error,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extras section
// ─────────────────────────────────────────────────────────────────────────────

class _ExtrasSection extends ConsumerStatefulWidget {
  const _ExtrasSection({required this.draft});

  final MealAdjustmentProfileDraft draft;

  @override
  ConsumerState<_ExtrasSection> createState() => _ExtrasSectionState();
}

class _ExtrasSectionState extends ConsumerState<_ExtrasSection> {
  int? _expandedIndex;

  @override
  void didUpdateWidget(covariant _ExtrasSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.extraOptions.isEmpty) {
      _expandedIndex = null;
      return;
    }
    if (widget.draft.extraOptions.length >
        oldWidget.draft.extraOptions.length) {
      _expandedIndex = widget.draft.extraOptions.length - 1;
      return;
    }
    final int? expandedIndex = _expandedIndex;
    if (expandedIndex != null &&
        expandedIndex >= widget.draft.extraOptions.length) {
      _expandedIndex = widget.draft.extraOptions.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSandwich =
        widget.draft.kind == MealAdjustmentProfileKind.sandwich;
    final AsyncValue<AdminMealProfileProductCatalog> catalogAsync = ref.watch(
      adminMealProfileProductCatalogProvider,
    );
    final AdminMealProfileProductCatalog? catalog = catalogAsync.valueOrNull;
    final bool isCatalogLoading = catalogAsync.isLoading && catalog == null;
    final String? catalogError = catalogAsync.hasError
        ? 'Product catalog could not be loaded.'
        : null;

    if (widget.draft.extraOptions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              isSandwich
                  ? 'No add-ins configured yet.'
                  : 'No add-ins defined for this meal.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.spacingXs),
            Text(
              isSandwich
                  ? 'Add paid extras that can be added to sandwich products using this profile. Sauces stay separate as free multi-select options.'
                  : 'Use add-ins for items added into the meal itself. '
                        'Separate side items should be added from the main POS catalog.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSizes.spacingSm),
            ElevatedButton.icon(
              key: const ValueKey<String>('meal-profile-add-extra'),
              onPressed: _addExtra,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Add-in'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      children: <Widget>[
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
          padding: const EdgeInsets.all(AppSizes.spacingSm),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Text(
            isSandwich
                ? 'Add-ins remain paid extras for sandwich products. Free sauces are configured in Sandwich Settings and are not priced here.'
                : 'Add-ins are items added into the meal itself. '
                      'Separate side products should be added from the main POS catalog.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (catalogError != null) ...<Widget>[
          _InlineIssueBanner(message: catalogError),
          const SizedBox(height: AppSizes.spacingSm),
        ],
        ...widget.draft.extraOptions.asMap().entries.map((
          MapEntry<int, MealAdjustmentExtraOptionDraft> entry,
        ) {
          return _ExtraOptionCard(
            index: entry.key,
            extra: entry.value,
            allExtras: widget.draft.extraOptions,
            catalog: catalog,
            isCatalogLoading: isCatalogLoading,
            catalogError: catalogError,
            isExpanded: _expandedIndex == entry.key,
            onToggleExpanded: () {
              setState(() {
                _expandedIndex = _expandedIndex == entry.key ? null : entry.key;
              });
            },
            onChanged: (MealAdjustmentExtraOptionDraft updated) {
              _updateExtraAt(entry.key, updated);
            },
            onRemove: () => _removeExtra(entry.key),
          );
        }),
        const SizedBox(height: AppSizes.spacingSm),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            key: const ValueKey<String>('meal-profile-add-extra'),
            onPressed: _addExtra,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Add-in'),
          ),
        ),
      ],
    );
  }

  void _addExtra() {
    final int nextIndex = widget.draft.extraOptions.length;
    final List<MealAdjustmentExtraOptionDraft> updated =
        List<MealAdjustmentExtraOptionDraft>.from(widget.draft.extraOptions)
          ..add(
            MealAdjustmentExtraOptionDraft(
              itemProductId: 0,
              fixedPriceDeltaMinor: 0,
              sortOrder: nextIndex,
              isActive: true,
            ),
          );
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updateExtras(updated);
    setState(() {
      _expandedIndex = nextIndex;
    });
  }

  void _updateExtraAt(int index, MealAdjustmentExtraOptionDraft extra) {
    final List<MealAdjustmentExtraOptionDraft> updated =
        List<MealAdjustmentExtraOptionDraft>.from(widget.draft.extraOptions);
    updated[index] = extra.copyWith(sortOrder: index);
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updateExtras(updated);
  }

  void _removeExtra(int index) {
    final List<MealAdjustmentExtraOptionDraft> updated =
        List<MealAdjustmentExtraOptionDraft>.from(widget.draft.extraOptions)
          ..removeAt(index);
    final List<MealAdjustmentExtraOptionDraft> normalized = updated
        .asMap()
        .entries
        .map(
          (MapEntry<int, MealAdjustmentExtraOptionDraft> entry) =>
              entry.value.copyWith(sortOrder: entry.key),
        )
        .toList(growable: false);
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updateExtras(normalized);
    setState(() {
      if (normalized.isEmpty) {
        _expandedIndex = null;
      } else if (_expandedIndex == index) {
        _expandedIndex = index >= normalized.length
            ? normalized.length - 1
            : index;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
  }
}

class _ExtraOptionCard extends ConsumerStatefulWidget {
  const _ExtraOptionCard({
    required this.index,
    required this.extra,
    required this.allExtras,
    required this.catalog,
    required this.isCatalogLoading,
    required this.catalogError,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final MealAdjustmentExtraOptionDraft extra;
  final List<MealAdjustmentExtraOptionDraft> allExtras;
  final AdminMealProfileProductCatalog? catalog;
  final bool isCatalogLoading;
  final String? catalogError;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<MealAdjustmentExtraOptionDraft> onChanged;
  final VoidCallback onRemove;

  @override
  ConsumerState<_ExtraOptionCard> createState() => _ExtraOptionCardState();
}

class _ExtraOptionCardState extends ConsumerState<_ExtraOptionCard> {
  late final TextEditingController _deltaController;
  String? _deltaParseError;

  @override
  void initState() {
    super.initState();
    _deltaController = TextEditingController(
      text: CurrencyFormatter.toEditableMajorInput(
        widget.extra.fixedPriceDeltaMinor,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _ExtraOptionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextDelta = CurrencyFormatter.toEditableMajorInput(
      widget.extra.fixedPriceDeltaMinor,
    );
    if (oldWidget.extra.fixedPriceDeltaMinor !=
            widget.extra.fixedPriceDeltaMinor &&
        _deltaController.text != nextDelta) {
      _deltaController.text = nextDelta;
    }
  }

  @override
  void dispose() {
    _deltaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AdminMealProfileProductOption? product =
        widget.catalog?.byId[widget.extra.itemProductId];
    final List<String> issues = _buildIssues(product);
    final String productLabel = _productLabel(product);

    return Card(
      key: ValueKey<String>('meal-profile-extra-card-${widget.index}'),
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingMd),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            productLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: widget.extra.isActive
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.textSecondary.withValues(
                                      alpha: 0.12,
                                    ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.extra.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.extra.isActive
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (issues.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${issues.length} issue${issues.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add-in ${CurrencyFormatter.fromMinor(widget.extra.fixedPriceDeltaMinor)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (issues.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            issues.length == 1
                                ? issues.first
                                : '${issues.first} +${issues.length - 1} more',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.spacingSm),
                OutlinedButton.icon(
                  key: ValueKey<String>('extra-expand-${widget.index}'),
                  onPressed: widget.onToggleExpanded,
                  icon: Icon(
                    widget.isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.edit_rounded,
                  ),
                  label: Text(widget.isExpanded ? 'Collapse' : 'Edit'),
                ),
                const SizedBox(width: AppSizes.spacingSm),
                IconButton(
                  key: ValueKey<String>('extra-remove-${widget.index}'),
                  icon: const Icon(Icons.delete_rounded),
                  color: AppColors.error,
                  onPressed: widget.onRemove,
                  tooltip: 'Delete extra',
                ),
              ],
            ),
            if (widget.isExpanded) ...<Widget>[
              const SizedBox(height: AppSizes.spacingMd),
              _ProductSelectionField(
                key: ValueKey<String>('extra-product-${widget.index}'),
                label: 'Add-in product',
                productLabel: productLabel,
                productSubtitle: product != null ? product.categoryName : null,
                errorText: issues.isEmpty ? null : issues.first,
                isLoading: widget.isCatalogLoading,
                disabledReason: widget.catalogError,
                onPressed: _selectProduct,
              ),
              const SizedBox(height: AppSizes.spacingMd),
              TextField(
                key: ValueKey<String>('extra-delta-${widget.index}'),
                controller: _deltaController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Add-in price',
                  helperText:
                      'Enter the price for adding this item into the meal.',
                  errorText:
                      _deltaParseError ??
                      (widget.extra.fixedPriceDeltaMinor < 0
                          ? 'Add-in price cannot be negative'
                          : null),
                ),
                onChanged: _updateDelta,
              ),
              const SizedBox(height: AppSizes.spacingSm),
              SwitchListTile(
                key: ValueKey<String>('extra-active-${widget.index}'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Add-in active'),
                subtitle: const Text(
                  'Inactive add-ins stay in the profile but do not appear in POS.',
                ),
                value: widget.extra.isActive,
                onChanged: (bool value) {
                  widget.onChanged(widget.extra.copyWith(isActive: value));
                },
              ),
              if (issues.length > 1) ...<Widget>[
                const SizedBox(height: AppSizes.spacingSm),
                ...issues
                    .skip(1)
                    .map(
                      (String message) => _InlineIssueText(message: message),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<String> _buildIssues(AdminMealProfileProductOption? product) {
    final List<String> issues = <String>[];
    if (widget.extra.itemProductId <= 0) {
      issues.add('Add-in product required');
    } else if (product == null) {
      issues.add('Add-in product no longer exists');
    } else if (!product.isActive) {
      issues.add('Add-in product is inactive');
    }
    if (widget.extra.fixedPriceDeltaMinor < 0) {
      issues.add('Add-in price cannot be negative');
    }
    final int duplicateCount = widget.allExtras
        .where(
          (MealAdjustmentExtraOptionDraft extra) =>
              extra.itemProductId == widget.extra.itemProductId,
        )
        .length;
    if (widget.extra.itemProductId > 0 && duplicateCount > 1) {
      issues.add('Add-in product duplicates another entry');
    }
    return issues;
  }

  String _productLabel(AdminMealProfileProductOption? product) {
    if (widget.extra.itemProductId <= 0) {
      return 'Not selected';
    }
    if (product == null) {
      return 'Missing product #${widget.extra.itemProductId}';
    }
    if (!product.isActive) {
      return '${product.name} (Inactive)';
    }
    return product.name;
  }

  Future<void> _selectProduct() async {
    AdminMealProfileProductCatalog? catalog = widget.catalog;
    try {
      catalog = await ref.refresh(
        adminMealProfileProductCatalogProvider.future,
      );
    } catch (_) {
      catalog = widget.catalog;
    }
    if (catalog == null) {
      return;
    }
    final AdminMealProfileProductCatalog latestCatalog = catalog;
    final AdminMealProfileProductOption? selected =
        await showDialog<AdminMealProfileProductOption>(
          context: context,
          builder: (BuildContext context) {
            return _ProductPickerDialog(
              title: 'Select add-in product',
              products: latestCatalog.activeAddInProducts,
              selectedProductId: widget.extra.itemProductId,
            );
          },
        );
    if (selected == null) {
      return;
    }
    widget.onChanged(widget.extra.copyWith(itemProductId: selected.id));
  }

  void _updateDelta(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _deltaParseError = 'Enter a valid amount';
      });
      return;
    }
    final int? parsed = CurrencyFormatter.tryParseSignedEditableMajorInput(
      trimmed,
    );
    if (parsed == null) {
      setState(() {
        _deltaParseError = 'Enter a valid amount';
      });
      return;
    }
    if (_deltaParseError != null) {
      setState(() {
        _deltaParseError = null;
      });
    }
    widget.onChanged(widget.extra.copyWith(fixedPriceDeltaMinor: parsed));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pricing rules section (B. Pricing Rule Authoring)
// ─────────────────────────────────────────────────────────────────────────────

class _PricingRulesSection extends ConsumerStatefulWidget {
  const _PricingRulesSection({
    required this.draft,
    required this.validation,
    required this.explanations,
  });

  final MealAdjustmentProfileDraft draft;
  final MealAdjustmentValidationResult? validation;
  final Map<int, String> explanations;

  @override
  ConsumerState<_PricingRulesSection> createState() =>
      _PricingRulesSectionState();
}

class _PricingRulesSectionState extends ConsumerState<_PricingRulesSection> {
  int? _expandedIndex;

  @override
  void didUpdateWidget(covariant _PricingRulesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.draft.pricingRules.isEmpty) {
      _expandedIndex = null;
      return;
    }
    if (widget.draft.pricingRules.length >
        oldWidget.draft.pricingRules.length) {
      _expandedIndex = widget.draft.pricingRules.length - 1;
      return;
    }
    final int? expandedIndex = _expandedIndex;
    if (expandedIndex != null &&
        expandedIndex >= widget.draft.pricingRules.length) {
      _expandedIndex = widget.draft.pricingRules.length - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AdminMealProfileProductCatalog> catalogAsync = ref.watch(
      adminMealProfileProductCatalogProvider,
    );
    final AdminMealProfileProductCatalog? catalog = catalogAsync.valueOrNull;
    final String? catalogError = catalogAsync.hasError
        ? 'Product catalog could not be loaded.'
        : null;
    final bool isCatalogLoading = catalogAsync.isLoading && catalog == null;

    if (widget.draft.pricingRules.isEmpty) {
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
              onPressed: _addRule,
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
        if (catalogError != null) ...<Widget>[
          _InlineIssueBanner(message: catalogError),
          const SizedBox(height: AppSizes.spacingSm),
        ],
        ...widget.draft.pricingRules.asMap().entries.map((
          MapEntry<int, MealAdjustmentPricingRuleDraft> entry,
        ) {
          final MealAdjustmentPricingRuleDraft rule = entry.value;
          final int ruleKey = rule.id ?? rule.hashCode;
          return _PricingRuleCard(
            index: entry.key,
            rule: rule,
            allRules: widget.draft.pricingRules,
            draft: widget.draft,
            validation: widget.validation,
            explanation:
                widget.explanations[ruleKey] ?? 'No explanation available.',
            catalog: catalog,
            isCatalogLoading: isCatalogLoading,
            catalogError: catalogError,
            isExpanded: _expandedIndex == entry.key,
            onToggleExpanded: () {
              setState(() {
                _expandedIndex = _expandedIndex == entry.key ? null : entry.key;
              });
            },
            onChanged: (MealAdjustmentPricingRuleDraft updatedRule) {
              _updateRuleAt(entry.key, updatedRule);
            },
            onRemove: () => _removeRule(entry.key),
          );
        }),
        const SizedBox(height: AppSizes.spacingSm),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            key: const ValueKey<String>('meal-profile-add-rule'),
            onPressed: _addRule,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Rule'),
          ),
        ),
      ],
    );
  }

  void _addRule() {
    final int nextIndex = widget.draft.pricingRules.length;
    final List<MealAdjustmentPricingRuleDraft> updated =
        List<MealAdjustmentPricingRuleDraft>.from(widget.draft.pricingRules)
          ..add(
            MealAdjustmentPricingRuleDraft(
              id: _nextDraftRuleId(widget.draft.pricingRules),
              name: 'Rule ${nextIndex + 1}',
              ruleType: MealAdjustmentPricingRuleType.removeOnly,
              priceDeltaMinor: 0,
              priority: nextIndex,
              isActive: true,
              conditions: <MealAdjustmentPricingRuleConditionDraft>[
                _defaultConditionForRuleType(
                  MealAdjustmentPricingRuleType.removeOnly,
                  existingConditions:
                      const <MealAdjustmentPricingRuleConditionDraft>[],
                ),
              ],
            ),
          );
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updatePricingRules(updated);
    setState(() {
      _expandedIndex = nextIndex;
    });
  }

  void _updateRuleAt(int index, MealAdjustmentPricingRuleDraft rule) {
    final List<MealAdjustmentPricingRuleDraft> updated =
        List<MealAdjustmentPricingRuleDraft>.from(widget.draft.pricingRules);
    updated[index] = rule;
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updatePricingRules(updated);
  }

  void _removeRule(int index) {
    final List<MealAdjustmentPricingRuleDraft> updated =
        List<MealAdjustmentPricingRuleDraft>.from(widget.draft.pricingRules)
          ..removeAt(index);
    ref
        .read(adminMealProfileEditorNotifierProvider.notifier)
        .updatePricingRules(updated);
    setState(() {
      if (updated.isEmpty) {
        _expandedIndex = null;
      } else if (_expandedIndex == index) {
        _expandedIndex = index >= updated.length ? updated.length - 1 : index;
      } else if (_expandedIndex != null && _expandedIndex! > index) {
        _expandedIndex = _expandedIndex! - 1;
      }
    });
  }
}

class _PricingRuleCard extends StatefulWidget {
  const _PricingRuleCard({
    required this.index,
    required this.rule,
    required this.allRules,
    required this.draft,
    required this.validation,
    required this.explanation,
    required this.catalog,
    required this.isCatalogLoading,
    required this.catalogError,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final MealAdjustmentPricingRuleDraft rule;
  final List<MealAdjustmentPricingRuleDraft> allRules;
  final MealAdjustmentProfileDraft draft;
  final MealAdjustmentValidationResult? validation;
  final String explanation;
  final AdminMealProfileProductCatalog? catalog;
  final bool isCatalogLoading;
  final String? catalogError;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<MealAdjustmentPricingRuleDraft> onChanged;
  final VoidCallback onRemove;

  @override
  State<_PricingRuleCard> createState() => _PricingRuleCardState();
}

class _PricingRuleCardState extends State<_PricingRuleCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _deltaController;
  late final TextEditingController _priorityController;
  String? _deltaParseError;
  String? _priorityParseError;
  String? _interactionMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule.name);
    _deltaController = TextEditingController(
      text: CurrencyFormatter.toEditableMajorInput(widget.rule.priceDeltaMinor),
    );
    _priorityController = TextEditingController(
      text: '${widget.rule.priority}',
    );
  }

  @override
  void didUpdateWidget(covariant _PricingRuleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule.name != widget.rule.name &&
        _nameController.text != widget.rule.name) {
      _nameController.text = widget.rule.name;
    }
    final String nextDelta = CurrencyFormatter.toEditableMajorInput(
      widget.rule.priceDeltaMinor,
    );
    if (oldWidget.rule.priceDeltaMinor != widget.rule.priceDeltaMinor &&
        _deltaController.text != nextDelta) {
      _deltaController.text = nextDelta;
    }
    final String nextPriority = '${widget.rule.priority}';
    if (oldWidget.rule.priority != widget.rule.priority &&
        _priorityController.text != nextPriority) {
      _priorityController.text = nextPriority;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _deltaController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> issues = _buildIssues();
    final String title = widget.rule.name.trim().isEmpty
        ? 'Untitled rule'
        : widget.rule.name.trim();

    return Card(
      key: ValueKey<String>('meal-profile-rule-card-${widget.index}'),
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.spacingMd),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _pricingRuleTypeLabel(widget.rule.ruleType),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: widget.rule.isActive
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.textSecondary.withValues(
                                      alpha: 0.12,
                                    ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              widget.rule.isActive ? 'ACTIVE' : 'INACTIVE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: widget.rule.isActive
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (issues.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${issues.length} issue${issues.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _buildExplanation(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Delta: ${CurrencyFormatter.fromMinor(widget.rule.priceDeltaMinor)} · Priority: ${widget.rule.priority} · Conditions: ${widget.rule.conditions.length}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (issues.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            issues.length == 1
                                ? issues.first
                                : '${issues.first} +${issues.length - 1} more',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.spacingSm),
                OutlinedButton.icon(
                  key: ValueKey<String>('rule-expand-${widget.index}'),
                  onPressed: widget.onToggleExpanded,
                  icon: Icon(
                    widget.isExpanded
                        ? Icons.expand_less_rounded
                        : Icons.edit_rounded,
                  ),
                  label: Text(widget.isExpanded ? 'Collapse' : 'Edit'),
                ),
                const SizedBox(width: AppSizes.spacingSm),
                IconButton(
                  key: ValueKey<String>('rule-remove-${widget.index}'),
                  icon: const Icon(Icons.delete_rounded),
                  color: AppColors.error,
                  onPressed: widget.onRemove,
                  tooltip: 'Remove rule',
                ),
              ],
            ),
            if (widget.isExpanded) ..._buildExpandedContent(issues),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildExpandedContent(List<String> issues) {
    return <Widget>[
      const SizedBox(height: AppSizes.spacingMd),
      if (_interactionMessage != null) ...<Widget>[
        _InlineIssueBanner(
          key: ValueKey<String>('rule-inline-message-${widget.index}'),
          message: _interactionMessage!,
        ),
        const SizedBox(height: AppSizes.spacingSm),
      ],
      TextField(
        key: ValueKey<String>('rule-name-${widget.index}'),
        controller: _nameController,
        decoration: InputDecoration(
          labelText: 'Rule name',
          errorText: widget.rule.name.trim().isEmpty
              ? 'Rule name required'
              : null,
        ),
        onChanged: (String value) {
          widget.onChanged(widget.rule.copyWith(name: value));
        },
      ),
      const SizedBox(height: AppSizes.spacingMd),
      DropdownButtonFormField<MealAdjustmentPricingRuleType>(
        key: ValueKey<String>('rule-type-${widget.index}'),
        value: widget.rule.ruleType,
        decoration: const InputDecoration(labelText: 'Rule type'),
        items: MealAdjustmentPricingRuleType.values
            .map(
              (MealAdjustmentPricingRuleType value) =>
                  DropdownMenuItem<MealAdjustmentPricingRuleType>(
                    value: value,
                    child: Text(_pricingRuleTypeLabel(value)),
                  ),
            )
            .toList(growable: false),
        onChanged: (MealAdjustmentPricingRuleType? value) {
          if (value != null) {
            _updateRuleType(value);
          }
        },
      ),
      const SizedBox(height: AppSizes.spacingMd),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: TextField(
              key: ValueKey<String>('rule-delta-${widget.index}'),
              controller: _deltaController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: 'Price delta',
                helperText: 'Enter signed major units, for example -1.00.',
                errorText: _deltaParseError ?? _deltaValidationError,
              ),
              onChanged: _updateDelta,
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          Expanded(
            child: TextField(
              key: ValueKey<String>('rule-priority-${widget.index}'),
              controller: _priorityController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'-?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'Priority',
                helperText:
                    'Higher priority wins when rules are equally specific.',
                errorText: _priorityParseError,
              ),
              onChanged: _updatePriority,
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSizes.spacingSm),
      SwitchListTile(
        key: ValueKey<String>('rule-active-${widget.index}'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Rule active'),
        subtitle: const Text(
          'Inactive rules stay in the draft but will not resolve at runtime.',
        ),
        value: widget.rule.isActive,
        onChanged: (bool value) {
          widget.onChanged(widget.rule.copyWith(isActive: value));
        },
      ),
      const SizedBox(height: AppSizes.spacingSm),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _buildExplanation(),
          key: ValueKey<String>('rule-explanation-${widget.index}'),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      const Divider(height: AppSizes.spacingLg * 2),
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Conditions',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          if (_canAddCondition)
            OutlinedButton.icon(
              key: ValueKey<String>('rule-add-condition-${widget.index}'),
              onPressed: _addCondition,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                widget.rule.ruleType == MealAdjustmentPricingRuleType.combo
                    ? 'Add condition'
                    : 'Reset condition',
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSizes.spacingXs),
      Text(
        _conditionHelperText(widget.rule.ruleType),
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      const SizedBox(height: AppSizes.spacingSm),
      if (widget.rule.conditions.isEmpty)
        const Text(
          'No conditions yet. Add a condition to make this rule resolvable.',
          style: TextStyle(color: AppColors.textSecondary),
        )
      else
        ...widget.rule.conditions.asMap().entries.map(
          (
            MapEntry<int, MealAdjustmentPricingRuleConditionDraft> entry,
          ) => _PricingRuleConditionEditorRow(
            key: ValueKey<String>(
              'rule-condition-row-${widget.index}-${entry.key}-${entry.value.id ?? 'draft'}',
            ),
            ruleIndex: widget.index,
            conditionIndex: entry.key,
            ruleType: widget.rule.ruleType,
            condition: entry.value,
            draft: widget.draft,
            catalog: widget.catalog,
            isCatalogLoading: widget.isCatalogLoading,
            catalogError: widget.catalogError,
            onChanged: (MealAdjustmentPricingRuleConditionDraft updated) {
              _updateConditionAt(entry.key, updated);
            },
            onRemove: () => _removeConditionAt(entry.key),
          ),
        ),
      if (issues.isNotEmpty) ...<Widget>[
        const SizedBox(height: AppSizes.spacingMd),
        ...issues.map((String message) => _InlineIssueText(message: message)),
      ],
    ];
  }

  String? get _deltaValidationError {
    if (widget.rule.ruleType == MealAdjustmentPricingRuleType.extra &&
        widget.rule.priceDeltaMinor < 0) {
      return 'Extra rules cannot use negative deltas';
    }
    if (widget.rule.ruleType == MealAdjustmentPricingRuleType.removeOnly &&
        widget.rule.priceDeltaMinor > 0) {
      return 'Remove-only rules cannot use positive deltas';
    }
    return null;
  }

  bool get _canAddCondition {
    if (widget.rule.ruleType == MealAdjustmentPricingRuleType.combo) {
      return true;
    }
    return widget.rule.conditions.isEmpty;
  }

  void _updateDelta(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      setState(() {
        _deltaParseError = 'Enter a valid amount';
      });
      return;
    }
    final int? parsed = CurrencyFormatter.tryParseSignedEditableMajorInput(
      trimmed,
    );
    if (parsed == null) {
      setState(() {
        _deltaParseError = 'Enter a valid amount';
      });
      return;
    }
    if (_deltaParseError != null) {
      setState(() {
        _deltaParseError = null;
      });
    }
    widget.onChanged(widget.rule.copyWith(priceDeltaMinor: parsed));
  }

  void _updatePriority(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      setState(() {
        _priorityParseError = 'Enter an integer priority';
      });
      return;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null) {
      setState(() {
        _priorityParseError = 'Enter an integer priority';
      });
      return;
    }
    if (_priorityParseError != null) {
      setState(() {
        _priorityParseError = null;
      });
    }
    widget.onChanged(widget.rule.copyWith(priority: parsed));
  }

  void _updateRuleType(MealAdjustmentPricingRuleType nextType) {
    if (nextType == widget.rule.ruleType) {
      return;
    }
    final _RuleTypeNormalizationResult normalized = _normalizeRuleForType(
      widget.rule,
      nextType,
    );
    setState(() {
      _interactionMessage = normalized.message;
    });
    widget.onChanged(normalized.rule);
  }

  void _addCondition() {
    final List<MealAdjustmentPricingRuleConditionDraft> updated =
        List<MealAdjustmentPricingRuleConditionDraft>.from(
          widget.rule.conditions,
        )..add(
          _defaultConditionForRuleType(
            widget.rule.ruleType,
            existingConditions: widget.rule.conditions,
          ),
        );
    widget.onChanged(widget.rule.copyWith(conditions: updated));
  }

  void _updateConditionAt(
    int index,
    MealAdjustmentPricingRuleConditionDraft condition,
  ) {
    final List<MealAdjustmentPricingRuleConditionDraft> updated =
        List<MealAdjustmentPricingRuleConditionDraft>.from(
          widget.rule.conditions,
        );
    updated[index] = condition;
    final bool duplicatesMeaning = _hasDuplicateConditionMeaning(updated);
    if (duplicatesMeaning && condition.isStructurallyValid) {
      setState(() {
        _interactionMessage =
            'Duplicate conditions with the same semantic meaning are not allowed.';
      });
      return;
    }
    if (_interactionMessage != null) {
      setState(() {
        _interactionMessage = null;
      });
    }
    widget.onChanged(widget.rule.copyWith(conditions: updated));
  }

  void _removeConditionAt(int index) {
    final List<MealAdjustmentPricingRuleConditionDraft> updated =
        List<MealAdjustmentPricingRuleConditionDraft>.from(
          widget.rule.conditions,
        )..removeAt(index);
    widget.onChanged(widget.rule.copyWith(conditions: updated));
  }

  List<String> _buildIssues() {
    final List<String> issues = <String>[];
    if (widget.rule.name.trim().isEmpty) {
      issues.add('Rule name is required.');
    }
    if (_deltaValidationError != null) {
      issues.add(_deltaValidationError!);
    }
    if (_deltaParseError != null) {
      issues.add(_deltaParseError!);
    }
    if (_priorityParseError != null) {
      issues.add(_priorityParseError!);
    }
    if (widget.rule.conditions.isEmpty) {
      issues.add('At least one condition is required.');
    }

    final Set<String> seenConditionKeys = <String>{};
    for (final MealAdjustmentPricingRuleConditionDraft condition
        in widget.rule.conditions) {
      if (!condition.isStructurallyValid) {
        issues.add(
          'Complete the condition fields required by this condition type.',
        );
        continue;
      }
      if (!seenConditionKeys.add(condition.semanticMeaningKey)) {
        issues.add(
          'Duplicate conditions with the same semantic meaning are not allowed.',
        );
        continue;
      }
      final String? semanticIssue = _validateCondition(condition);
      if (semanticIssue != null) {
        issues.add(semanticIssue);
      }
    }

    final int matchingRuleCount = widget.allRules
        .where(
          (MealAdjustmentPricingRuleDraft other) =>
              other != widget.rule &&
              other.semanticMeaningKey == widget.rule.semanticMeaningKey,
        )
        .length;
    if (matchingRuleCount > 0) {
      issues.add('Another rule already uses the same semantic meaning.');
    }

    return issues.toSet().toList(growable: false);
  }

  String? _validateCondition(
    MealAdjustmentPricingRuleConditionDraft condition,
  ) {
    final Map<String, MealAdjustmentComponentDraft> componentsByKey =
        <String, MealAdjustmentComponentDraft>{
          for (final MealAdjustmentComponentDraft component
              in widget.draft.components)
            if (component.isActive)
              component.componentKey.trim().toLowerCase(): component,
        };
    final Map<int, AdminMealProfileProductOption> productsById =
        widget.catalog?.byId ?? const <int, AdminMealProfileProductOption>{};
    final String normalizedComponentKey =
        condition.componentKey?.trim().toLowerCase() ?? '';
    switch (condition.conditionType) {
      case MealAdjustmentPricingRuleConditionType.removedComponent:
        final MealAdjustmentComponentDraft? component =
            componentsByKey[normalizedComponentKey];
        if (component == null) {
          return 'Removed-component condition must reference an active profile component.';
        }
        if (!component.canRemove) {
          return 'Removed-component condition must reference a removable component.';
        }
        return null;
      case MealAdjustmentPricingRuleConditionType.swapToItem:
        final MealAdjustmentComponentDraft? component =
            componentsByKey[normalizedComponentKey];
        if (component == null) {
          return 'Swap condition must reference an active profile component.';
        }
        final Set<int> swapTargets = component.swapOptions
            .where(
              (MealAdjustmentComponentOptionDraft option) => option.isActive,
            )
            .map(
              (MealAdjustmentComponentOptionDraft option) =>
                  option.optionItemProductId,
            )
            .toSet();
        if (!swapTargets.contains(condition.itemProductId)) {
          return 'Swap condition target must be configured as an active swap option for the component.';
        }
        final AdminMealProfileProductOption? product =
            productsById[condition.itemProductId];
        if (product == null) {
          return 'Pricing rule item ${condition.itemProductId ?? 'unknown'} is missing.';
        }
        if (!product.isActive) {
          return 'Pricing rule item ${condition.itemProductId ?? 'unknown'} is inactive.';
        }
        return null;
      case MealAdjustmentPricingRuleConditionType.extraItem:
        final Set<int> activeExtraItems = widget.draft.extraOptions
            .where((MealAdjustmentExtraOptionDraft extra) => extra.isActive)
            .map((MealAdjustmentExtraOptionDraft extra) => extra.itemProductId)
            .toSet();
        if (!activeExtraItems.contains(condition.itemProductId)) {
          return 'Extra-item condition must reference an active profile extra.';
        }
        final AdminMealProfileProductOption? product =
            productsById[condition.itemProductId];
        if (product == null) {
          return 'Pricing rule item ${condition.itemProductId ?? 'unknown'} is missing.';
        }
        if (!product.isActive) {
          return 'Pricing rule item ${condition.itemProductId ?? 'unknown'} is inactive.';
        }
        return null;
    }
  }

  String _buildExplanation() {
    if (widget.rule.conditions.isEmpty) {
      return 'This rule is incomplete.';
    }
    final List<String?> conditionPhrases = widget.rule.conditions
        .map(_conditionPhrase)
        .toList(growable: false);
    if (conditionPhrases.any((String? phrase) => phrase == null)) {
      return 'This rule is incomplete.';
    }
    final String conditionText = _joinHumanList(
      conditionPhrases.cast<String>(),
      conjunction: 'and',
    );
    return 'If $conditionText, ${_deltaSentence(widget.rule.priceDeltaMinor)}';
  }

  String? _conditionPhrase(MealAdjustmentPricingRuleConditionDraft condition) {
    final Map<String, MealAdjustmentComponentDraft> componentsByKey =
        <String, MealAdjustmentComponentDraft>{
          for (final MealAdjustmentComponentDraft component
              in widget.draft.components)
            if (component.isActive)
              component.componentKey.trim().toLowerCase(): component,
        };
    final Map<int, AdminMealProfileProductOption> productsById =
        widget.catalog?.byId ?? const <int, AdminMealProfileProductOption>{};
    switch (condition.conditionType) {
      case MealAdjustmentPricingRuleConditionType.removedComponent:
        final MealAdjustmentComponentDraft? component =
            componentsByKey[condition.componentKey?.trim().toLowerCase() ?? ''];
        if (component == null) {
          return null;
        }
        final String quantityPrefix = condition.quantity > 1
            ? '${condition.quantity}x '
            : '';
        return '$quantityPrefix${component.displayName} is removed';
      case MealAdjustmentPricingRuleConditionType.swapToItem:
        final MealAdjustmentComponentDraft? component =
            componentsByKey[condition.componentKey?.trim().toLowerCase() ?? ''];
        final AdminMealProfileProductOption? product =
            productsById[condition.itemProductId];
        if (component == null || product == null) {
          return null;
        }
        final String quantityPrefix = condition.quantity > 1
            ? '${condition.quantity}x '
            : '';
        return '$quantityPrefix${component.displayName} is swapped to ${product.name}';
      case MealAdjustmentPricingRuleConditionType.extraItem:
        final AdminMealProfileProductOption? product =
            productsById[condition.itemProductId];
        if (product == null) {
          return null;
        }
        final String quantityPrefix = condition.quantity > 1
            ? '${condition.quantity}x '
            : '';
        return '$quantityPrefix${product.name} is added into the meal';
    }
  }

  bool _hasDuplicateConditionMeaning(
    List<MealAdjustmentPricingRuleConditionDraft> conditions,
  ) {
    final Set<String> seen = <String>{};
    for (final MealAdjustmentPricingRuleConditionDraft condition
        in conditions) {
      if (!condition.isStructurallyValid) {
        continue;
      }
      if (!seen.add(condition.semanticMeaningKey)) {
        return true;
      }
    }
    return false;
  }
}

class _PricingRuleConditionEditorRow extends StatefulWidget {
  const _PricingRuleConditionEditorRow({
    required this.ruleIndex,
    required this.conditionIndex,
    required this.ruleType,
    required this.condition,
    required this.draft,
    required this.catalog,
    required this.isCatalogLoading,
    required this.catalogError,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final int ruleIndex;
  final int conditionIndex;
  final MealAdjustmentPricingRuleType ruleType;
  final MealAdjustmentPricingRuleConditionDraft condition;
  final MealAdjustmentProfileDraft draft;
  final AdminMealProfileProductCatalog? catalog;
  final bool isCatalogLoading;
  final String? catalogError;
  final ValueChanged<MealAdjustmentPricingRuleConditionDraft> onChanged;
  final VoidCallback onRemove;

  @override
  State<_PricingRuleConditionEditorRow> createState() =>
      _PricingRuleConditionEditorRowState();
}

class _PricingRuleConditionEditorRowState
    extends State<_PricingRuleConditionEditorRow> {
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: '${widget.condition.quantity}',
    );
  }

  @override
  void didUpdateWidget(covariant _PricingRuleConditionEditorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String nextQuantity = '${widget.condition.quantity}';
    if (oldWidget.condition.quantity != widget.condition.quantity &&
        _quantityController.text != nextQuantity) {
      _quantityController.text = nextQuantity;
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_ComponentChoice> components = _availableComponents();
    final AdminMealProfileProductOption? selectedProduct =
        widget.catalog?.byId[widget.condition.itemProductId];
    final String productLabel;
    if (_requiresProductSelection) {
      if (widget.condition.itemProductId == null ||
          widget.condition.itemProductId! <= 0) {
        productLabel = 'Not selected';
      } else if (selectedProduct == null) {
        productLabel = 'Missing product #${widget.condition.itemProductId}';
      } else if (!selectedProduct.isActive) {
        productLabel = '${selectedProduct.name} (Inactive)';
      } else {
        productLabel = selectedProduct.name;
      }
    } else {
      productLabel = 'Not selected';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Condition ${widget.conditionIndex + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                key: ValueKey<String>(
                  'rule-condition-remove-${widget.ruleIndex}-${widget.conditionIndex}',
                ),
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Remove condition',
              ),
            ],
          ),
          if (_canEditConditionType) ...<Widget>[
            DropdownButtonFormField<MealAdjustmentPricingRuleConditionType>(
              key: ValueKey<String>(
                'rule-condition-type-${widget.ruleIndex}-${widget.conditionIndex}',
              ),
              value: widget.condition.conditionType,
              decoration: const InputDecoration(labelText: 'Condition type'),
              items: _allowedConditionTypes(widget.ruleType)
                  .map(
                    (MealAdjustmentPricingRuleConditionType value) =>
                        DropdownMenuItem<
                          MealAdjustmentPricingRuleConditionType
                        >(
                          value: value,
                          child: Text(_pricingRuleConditionTypeLabel(value)),
                        ),
                  )
                  .toList(growable: false),
              onChanged: (MealAdjustmentPricingRuleConditionType? value) {
                if (value == null || value == widget.condition.conditionType) {
                  return;
                }
                widget.onChanged(
                  _resetConditionForType(widget.condition, value),
                );
              },
            ),
            const SizedBox(height: AppSizes.spacingMd),
          ],
          if (_requiresComponentSelection) ...<Widget>[
            DropdownButtonFormField<String>(
              key: ValueKey<String>(
                'rule-condition-component-${widget.ruleIndex}-${widget.conditionIndex}',
              ),
              value: _selectedComponentKey(components),
              decoration: const InputDecoration(labelText: 'Component'),
              items: components
                  .map(
                    (_ComponentChoice component) => DropdownMenuItem<String>(
                      value: component.componentKey,
                      child: Text(component.displayLabel),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (String? value) {
                widget.onChanged(
                  widget.condition.copyWith(
                    componentKey: value,
                    itemProductId:
                        widget.condition.conditionType ==
                            MealAdjustmentPricingRuleConditionType.swapToItem
                        ? null
                        : widget.condition.itemProductId,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSizes.spacingMd),
          ],
          if (_requiresProductSelection) ...<Widget>[
            _ProductSelectionField(
              key: ValueKey<String>(
                'rule-condition-item-${widget.ruleIndex}-${widget.conditionIndex}',
              ),
              label: _itemFieldLabel,
              productLabel: productLabel,
              productSubtitle: selectedProduct != null
                  ? selectedProduct.categoryName
                  : null,
              errorText: _productSelectionError,
              isLoading: widget.isCatalogLoading,
              disabledReason: _productSelectionDisabledReason,
              onPressed: _selectProduct,
            ),
            const SizedBox(height: AppSizes.spacingMd),
          ],
          TextField(
            key: ValueKey<String>(
              'rule-condition-qty-${widget.ruleIndex}-${widget.conditionIndex}',
            ),
            controller: _quantityController,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Quantity',
              helperText: 'Used for exact semantic matching.',
            ),
            onChanged: (String value) {
              final int nextValue = int.tryParse(value) ?? 0;
              widget.onChanged(widget.condition.copyWith(quantity: nextValue));
            },
          ),
        ],
      ),
    );
  }

  bool get _canEditConditionType =>
      widget.ruleType == MealAdjustmentPricingRuleType.combo;

  bool get _requiresComponentSelection {
    return widget.condition.conditionType ==
            MealAdjustmentPricingRuleConditionType.removedComponent ||
        widget.condition.conditionType ==
            MealAdjustmentPricingRuleConditionType.swapToItem;
  }

  bool get _requiresProductSelection {
    return widget.condition.conditionType ==
            MealAdjustmentPricingRuleConditionType.swapToItem ||
        widget.condition.conditionType ==
            MealAdjustmentPricingRuleConditionType.extraItem;
  }

  String? get _productSelectionError {
    if (!_requiresProductSelection) {
      return null;
    }
    if (widget.condition.conditionType ==
        MealAdjustmentPricingRuleConditionType.swapToItem) {
      if ((widget.condition.componentKey ?? '').trim().isEmpty) {
        return 'Select a component first';
      }
      if (widget.condition.itemProductId == null ||
          widget.condition.itemProductId! <= 0) {
        return 'Swap target required';
      }
      if (_availableSwapTargets().every(
        (AdminMealProfileProductOption product) =>
            product.id != widget.condition.itemProductId,
      )) {
        return 'Swap target must be an active swap option';
      }
    }
    if (widget.condition.conditionType ==
        MealAdjustmentPricingRuleConditionType.extraItem) {
      if (widget.condition.itemProductId == null ||
          widget.condition.itemProductId! <= 0) {
        return 'Add-in item required';
      }
      if (_availableExtraProducts().every(
        (AdminMealProfileProductOption product) =>
            product.id != widget.condition.itemProductId,
      )) {
        return 'Add-in item must be an active configured add-in';
      }
    }
    return null;
  }

  String? get _productSelectionDisabledReason {
    if (!_requiresProductSelection) {
      return null;
    }
    if (widget.catalogError != null) {
      return widget.catalogError;
    }
    if (widget.condition.conditionType ==
            MealAdjustmentPricingRuleConditionType.swapToItem &&
        (widget.condition.componentKey ?? '').trim().isEmpty) {
      return 'Select a component first.';
    }
    return null;
  }

  String get _itemFieldLabel {
    switch (widget.condition.conditionType) {
      case MealAdjustmentPricingRuleConditionType.swapToItem:
        return 'Swap target';
      case MealAdjustmentPricingRuleConditionType.extraItem:
        return 'Add-in item';
      case MealAdjustmentPricingRuleConditionType.removedComponent:
        return 'Item';
    }
  }

  List<_ComponentChoice> _availableComponents() {
    final Iterable<MealAdjustmentComponentDraft> source = widget
        .draft
        .components
        .where((MealAdjustmentComponentDraft component) => component.isActive)
        .where((MealAdjustmentComponentDraft component) {
          if (widget.condition.conditionType ==
              MealAdjustmentPricingRuleConditionType.removedComponent) {
            return component.canRemove;
          }
          return true;
        });
    return source
        .map(
          (MealAdjustmentComponentDraft component) => _ComponentChoice(
            componentKey: component.componentKey,
            displayLabel:
                '${component.displayName} (${component.componentKey})',
          ),
        )
        .toList(growable: false);
  }

  String? _selectedComponentKey(List<_ComponentChoice> components) {
    final String selected = widget.condition.componentKey ?? '';
    final bool exists = components.any(
      (_ComponentChoice component) => component.componentKey == selected,
    );
    return exists ? selected : null;
  }

  List<AdminMealProfileProductOption> _availableSwapTargets() {
    final AdminMealProfileProductCatalog? catalog = widget.catalog;
    if (catalog == null) {
      return const <AdminMealProfileProductOption>[];
    }
    final String normalizedComponentKey =
        widget.condition.componentKey?.trim().toLowerCase() ?? '';
    final List<MealAdjustmentComponentDraft> matches = widget.draft.components
        .where((MealAdjustmentComponentDraft value) => value.isActive)
        .where(
          (MealAdjustmentComponentDraft value) =>
              value.componentKey.trim().toLowerCase() == normalizedComponentKey,
        )
        .toList(growable: false);
    if (matches.isEmpty) {
      return const <AdminMealProfileProductOption>[];
    }
    return matches.first.swapOptions
        .where((MealAdjustmentComponentOptionDraft option) => option.isActive)
        .map(
          (MealAdjustmentComponentOptionDraft option) =>
              catalog.byId[option.optionItemProductId],
        )
        .whereType<AdminMealProfileProductOption>()
        .where((AdminMealProfileProductOption product) => product.isActive)
        .toList(growable: false);
  }

  List<AdminMealProfileProductOption> _availableExtraProducts() {
    final AdminMealProfileProductCatalog? catalog = widget.catalog;
    if (catalog == null) {
      return const <AdminMealProfileProductOption>[];
    }
    return widget.draft.extraOptions
        .where((MealAdjustmentExtraOptionDraft extra) => extra.isActive)
        .map(
          (MealAdjustmentExtraOptionDraft extra) =>
              catalog.byId[extra.itemProductId],
        )
        .whereType<AdminMealProfileProductOption>()
        .where((AdminMealProfileProductOption product) => product.isActive)
        .toList(growable: false);
  }

  Future<void> _selectProduct() async {
    final AdminMealProfileProductCatalog? catalog = widget.catalog;
    if (catalog == null) {
      return;
    }
    final List<AdminMealProfileProductOption> candidates =
        widget.condition.conditionType ==
            MealAdjustmentPricingRuleConditionType.swapToItem
        ? _availableSwapTargets()
        : _availableExtraProducts();
    final AdminMealProfileProductOption? selected =
        await showDialog<AdminMealProfileProductOption>(
          context: context,
          builder: (BuildContext context) {
            return _ProductPickerDialog(
              title:
                  widget.condition.conditionType ==
                      MealAdjustmentPricingRuleConditionType.swapToItem
                  ? 'Select swap target'
                  : 'Select add-in item',
              products: candidates,
              selectedProductId: widget.condition.itemProductId,
            );
          },
        );
    if (selected == null) {
      return;
    }
    widget.onChanged(widget.condition.copyWith(itemProductId: selected.id));
  }
}

class _RuleTypeNormalizationResult {
  const _RuleTypeNormalizationResult({required this.rule, this.message});

  final MealAdjustmentPricingRuleDraft rule;
  final String? message;
}

class _ComponentChoice {
  const _ComponentChoice({
    required this.componentKey,
    required this.displayLabel,
  });

  final String componentKey;
  final String displayLabel;
}

int _nextDraftRuleId(List<MealAdjustmentPricingRuleDraft> rules) {
  int nextId = -1;
  for (final MealAdjustmentPricingRuleDraft rule in rules) {
    final int? id = rule.id;
    if (id != null && id <= nextId) {
      nextId = id - 1;
    }
  }
  return nextId;
}

int _nextDraftConditionId(
  List<MealAdjustmentPricingRuleConditionDraft> conditions,
) {
  int nextId = -1;
  for (final MealAdjustmentPricingRuleConditionDraft condition in conditions) {
    final int? id = condition.id;
    if (id != null && id <= nextId) {
      nextId = id - 1;
    }
  }
  return nextId;
}

List<MealAdjustmentPricingRuleConditionType> _allowedConditionTypes(
  MealAdjustmentPricingRuleType ruleType,
) {
  switch (ruleType) {
    case MealAdjustmentPricingRuleType.removeOnly:
      return const <MealAdjustmentPricingRuleConditionType>[
        MealAdjustmentPricingRuleConditionType.removedComponent,
      ];
    case MealAdjustmentPricingRuleType.combo:
      return const <MealAdjustmentPricingRuleConditionType>[
        MealAdjustmentPricingRuleConditionType.removedComponent,
        MealAdjustmentPricingRuleConditionType.swapToItem,
        MealAdjustmentPricingRuleConditionType.extraItem,
      ];
    case MealAdjustmentPricingRuleType.swap:
      return const <MealAdjustmentPricingRuleConditionType>[
        MealAdjustmentPricingRuleConditionType.swapToItem,
      ];
    case MealAdjustmentPricingRuleType.extra:
      return const <MealAdjustmentPricingRuleConditionType>[
        MealAdjustmentPricingRuleConditionType.extraItem,
      ];
  }
}

MealAdjustmentPricingRuleConditionDraft _defaultConditionForRuleType(
  MealAdjustmentPricingRuleType ruleType, {
  required List<MealAdjustmentPricingRuleConditionDraft> existingConditions,
}) {
  final MealAdjustmentPricingRuleConditionType defaultType =
      _allowedConditionTypes(ruleType).first;
  return MealAdjustmentPricingRuleConditionDraft(
    id: _nextDraftConditionId(existingConditions),
    conditionType: defaultType,
    quantity: 1,
  );
}

MealAdjustmentPricingRuleConditionDraft _resetConditionForType(
  MealAdjustmentPricingRuleConditionDraft current,
  MealAdjustmentPricingRuleConditionType nextType,
) {
  switch (nextType) {
    case MealAdjustmentPricingRuleConditionType.removedComponent:
      return current.copyWith(conditionType: nextType, itemProductId: null);
    case MealAdjustmentPricingRuleConditionType.swapToItem:
      return current.copyWith(conditionType: nextType, itemProductId: null);
    case MealAdjustmentPricingRuleConditionType.extraItem:
      return current.copyWith(
        conditionType: nextType,
        componentKey: null,
        itemProductId: null,
      );
  }
}

_RuleTypeNormalizationResult _normalizeRuleForType(
  MealAdjustmentPricingRuleDraft rule,
  MealAdjustmentPricingRuleType nextType,
) {
  List<MealAdjustmentPricingRuleConditionDraft> conditions;
  switch (nextType) {
    case MealAdjustmentPricingRuleType.removeOnly:
      conditions = rule.conditions
          .where(
            (MealAdjustmentPricingRuleConditionDraft condition) =>
                condition.conditionType ==
                MealAdjustmentPricingRuleConditionType.removedComponent,
          )
          .take(1)
          .toList(growable: false);
      break;
    case MealAdjustmentPricingRuleType.combo:
      conditions = List<MealAdjustmentPricingRuleConditionDraft>.from(
        rule.conditions,
      );
      break;
    case MealAdjustmentPricingRuleType.swap:
      conditions = rule.conditions
          .where(
            (MealAdjustmentPricingRuleConditionDraft condition) =>
                condition.conditionType ==
                MealAdjustmentPricingRuleConditionType.swapToItem,
          )
          .take(1)
          .toList(growable: false);
      break;
    case MealAdjustmentPricingRuleType.extra:
      conditions = rule.conditions
          .where(
            (MealAdjustmentPricingRuleConditionDraft condition) =>
                condition.conditionType ==
                MealAdjustmentPricingRuleConditionType.extraItem,
          )
          .take(1)
          .toList(growable: false);
      break;
  }

  String? message;
  if (conditions.isEmpty) {
    conditions = <MealAdjustmentPricingRuleConditionDraft>[
      _defaultConditionForRuleType(
        nextType,
        existingConditions: rule.conditions,
      ),
    ];
    message = 'Conditions were reset to match the selected rule type.';
  } else if (conditions.length != rule.conditions.length) {
    message =
        'Incompatible conditions were removed for the selected rule type.';
  }

  return _RuleTypeNormalizationResult(
    rule: rule.copyWith(ruleType: nextType, conditions: conditions),
    message: message,
  );
}

String _pricingRuleTypeLabel(MealAdjustmentPricingRuleType ruleType) {
  switch (ruleType) {
    case MealAdjustmentPricingRuleType.removeOnly:
      return 'Remove only';
    case MealAdjustmentPricingRuleType.combo:
      return 'Combo';
    case MealAdjustmentPricingRuleType.swap:
      return 'Swap';
    case MealAdjustmentPricingRuleType.extra:
      return 'Add-in';
  }
}

String _pricingRuleConditionTypeLabel(
  MealAdjustmentPricingRuleConditionType conditionType,
) {
  switch (conditionType) {
    case MealAdjustmentPricingRuleConditionType.removedComponent:
      return 'Removed component';
    case MealAdjustmentPricingRuleConditionType.swapToItem:
      return 'Swap target';
    case MealAdjustmentPricingRuleConditionType.extraItem:
      return 'Add-in item';
  }
}

String _conditionHelperText(MealAdjustmentPricingRuleType ruleType) {
  switch (ruleType) {
    case MealAdjustmentPricingRuleType.removeOnly:
      return 'Remove-only rules support removed-component conditions.';
    case MealAdjustmentPricingRuleType.combo:
      return 'Combo rules use exact semantic matches across removed, swap, and extra conditions.';
    case MealAdjustmentPricingRuleType.swap:
      return 'Swap rules require a component and one configured swap target.';
    case MealAdjustmentPricingRuleType.extra:
      return 'Add-in rules require one configured active add-in item.';
  }
}

String _deltaSentence(int deltaMinor) {
  if (deltaMinor == 0) {
    return 'price stays the same.';
  }
  final String amount = CurrencyFormatter.fromMinor(deltaMinor.abs());
  if (deltaMinor < 0) {
    return 'reduce price by $amount.';
  }
  return 'increase price by $amount.';
}

String _joinHumanList(List<String> values, {required String conjunction}) {
  if (values.isEmpty) {
    return '';
  }
  if (values.length == 1) {
    return values.first;
  }
  if (values.length == 2) {
    return '${values.first} $conjunction ${values.last}';
  }
  final List<String> leading = values.sublist(0, values.length - 1);
  return '${leading.join(', ')}, $conjunction ${values.last}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Validation summary section (F. Admin Validation Clarity)
// ─────────────────────────────────────────────────────────────────────────────

class _ValidationSummarySection extends StatelessWidget {
  const _ValidationSummarySection({
    required this.kind,
    required this.validation,
    required this.healthSummary,
  });

  final MealAdjustmentProfileKind kind;
  final MealAdjustmentValidationResult? validation;
  final MealAdjustmentProfileHealthSummary? healthSummary;

  @override
  Widget build(BuildContext context) {
    if (validation == null) {
      return const Center(child: Text('No validation data available.'));
    }
    final bool isSandwich = kind == MealAdjustmentProfileKind.sandwich;

    final List<MealAdjustmentValidationIssue> allIssues =
        <MealAdjustmentValidationIssue>[
          ...validation!.blockingErrors,
          ...validation!.warnings,
        ];

    return ListView(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      children: <Widget>[
        if (healthSummary != null &&
            (!isSandwich || allIssues.isNotEmpty)) ...<Widget>[
          _Banner(
            message: healthSummary!.headline,
            color: _healthColor(healthSummary!.healthStatus),
          ),
          if (!isSandwich) ...<Widget>[
            const SizedBox(height: AppSizes.spacingXs),
            Text(
              healthSummary!.body,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.spacingMd),
          ],
        ],
        if (allIssues.isEmpty)
          Container(
            key: ValueKey<String>(
              isSandwich
                  ? 'sandwich-validation-success'
                  : 'standard-validation-success',
            ),
            padding: const EdgeInsets.all(AppSizes.spacingSm),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.24),
              ),
            ),
            child: Text(
              isSandwich
                  ? 'Sandwich profile is valid. Metadata, sandwich settings, and add-ins are ready.'
                  : 'No issues found. Profile is valid.',
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
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
  const _ValidationIssueRow({required this.issue, required this.isBlocking});

  final MealAdjustmentValidationIssue issue;
  final bool isBlocking;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: isBlocking
          ? AppColors.error.withValues(alpha: 0.06)
          : AppColors.warning.withValues(alpha: 0.06),
      child: ListTile(
        dense: true,
        leading: Icon(
          isBlocking ? Icons.error_rounded : Icons.warning_amber_rounded,
          color: isBlocking ? AppColors.error : AppColors.warning,
          size: 20,
        ),
        title: Text(issue.message, style: const TextStyle(fontSize: 13)),
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
