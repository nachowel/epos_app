import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/meal_adjustment_profile.dart';
import '../../../../domain/models/meal_customization.dart';
import '../../../../domain/models/product.dart';
import '../../../../domain/services/meal_customization_pos_service.dart';

class StandardMealCustomizationDialog extends ConsumerStatefulWidget {
  const StandardMealCustomizationDialog({
    required this.product,
    required this.initialEditorData,
    this.isEditMode = false,
    this.lineQuantity,
    this.editOneMode = false,
    this.isLegacyRecreateMode = false,
    this.suggestions = const <MealQuickSuggestion>[],
    super.key,
  });

  final Product product;
  final MealCustomizationPosEditorData initialEditorData;
  final bool isEditMode;
  final int? lineQuantity;
  final bool editOneMode;
  final bool isLegacyRecreateMode;
  final List<MealQuickSuggestion> suggestions;

  @override
  ConsumerState<StandardMealCustomizationDialog> createState() =>
      _StandardMealCustomizationDialogState();
}

class _StandardMealCustomizationDialogState
    extends ConsumerState<StandardMealCustomizationDialog> {
  late MealCustomizationEditorState _editorState;
  late MealCustomizationPosPreview _preview;
  late bool _isAddInsExpanded;

  MealAdjustmentProfile get _profile => widget.initialEditorData.profile;
  Map<int, String> get _productNamesById =>
      widget.initialEditorData.productNamesById;
  bool get _isSandwichProfile =>
      _profile.kind == MealAdjustmentProfileKind.sandwich;
  SandwichBreadType? get _selectedBreadType =>
      _editorState.sandwichSelection.breadType;
  SandwichToastOption? get _selectedToastOption =>
      _editorState.sandwichSelection.toastOption;

  @override
  void initState() {
    super.initState();
    _editorState = widget.initialEditorData.preview.editorState;
    _preview = widget.initialEditorData.preview;
    _isAddInsExpanded = _hasSelectedAddIns;
  }

  bool get _hasSelectedAddIns => _editorState.extraSelections.any(
    (MealCustomizationExtraSelection selection) => selection.quantity > 0,
  );

  // ── Title / label helpers (same text output as before) ──

  String get _dialogTitle {
    if (_isSandwichProfile) {
      return 'Sandwich customization: ${widget.product.name}';
    }
    if (widget.isLegacyRecreateMode) {
      return 'Recreate meal: ${widget.product.name}';
    }
    if (widget.isEditMode) {
      return 'Edit meal: ${widget.product.name}';
    }
    return 'Meal customization: ${widget.product.name}';
  }

  String get _confirmLabel {
    if (widget.isLegacyRecreateMode) return 'Recreate meal';
    if (widget.isEditMode) return 'Save changes';
    return 'Add to cart';
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final List<MealAdjustmentComponent> activeComponents =
        _profile.components
            .where((MealAdjustmentComponent component) => component.isActive)
            .toList(growable: false)
          ..sort(
            (MealAdjustmentComponent left, MealAdjustmentComponent right) =>
                left.sortOrder.compareTo(right.sortOrder),
          );
    final List<MealAdjustmentExtraOption> activeExtras =
        _profile.extraOptions
            .where((MealAdjustmentExtraOption option) => option.isActive)
            .where(
              (MealAdjustmentExtraOption option) =>
                  _productNamesById.containsKey(option.itemProductId),
            )
            .toList(growable: false)
          ..sort(
            (MealAdjustmentExtraOption left, MealAdjustmentExtraOption right) =>
                left.sortOrder.compareTo(right.sortOrder),
          );

    return Dialog(
      key: const ValueKey<String>('meal-customization-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 908, maxHeight: 860),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ── Header ──
              _buildDialogHeader(),
              const Divider(height: AppSizes.spacingLg),

              // ── Scrollable body ──
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Notices
                      if (widget.isLegacyRecreateMode) ...<Widget>[
                        Container(
                          key: const ValueKey<String>(
                            'meal-customization-legacy-notice',
                          ),
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSizes.spacingSm),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMd),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppColors.warning,
                                size: 20,
                              ),
                              const SizedBox(width: AppSizes.spacingSm),
                              const Expanded(
                                child: Text(
                                  'This item was created before the new meal system and cannot '
                                  'be edited directly. You can recreate it as a new editable meal.',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacingMd),
                      ] else if (widget.isEditMode &&
                          widget.editOneMode) ...<Widget>[
                        Container(
                          key: const ValueKey<String>(
                            'meal-customization-edit-one-notice',
                          ),
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSizes.spacingSm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMd),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: AppSizes.spacingSm),
                              const Expanded(
                                child: Text(
                                  'Editing one item from this grouped line. '
                                  'The remaining items will keep their current customization.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacingMd),
                      ] else if (widget.isEditMode &&
                          (widget.lineQuantity ?? 0) > 1) ...<Widget>[
                        Container(
                          key: const ValueKey<String>(
                            'meal-customization-edit-all-notice',
                          ),
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSizes.spacingSm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMd),
                          ),
                          child: Row(
                            children: <Widget>[
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: AppSizes.spacingSm),
                              Expanded(
                                child: Text(
                                  'Editing applies to all ${widget.lineQuantity} items on this grouped line.',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.spacingMd),
                      ],

                      // Suggestions
                      if (widget.suggestions.isNotEmpty) ...<Widget>[
                        _SectionTitle('Popular customizations'),
                        const SizedBox(height: AppSizes.spacingSm),
                        Wrap(
                          spacing: AppSizes.spacingSm,
                          runSpacing: AppSizes.spacingSm,
                          children: widget.suggestions
                              .map(_buildSuggestionChip)
                              .toList(growable: false),
                        ),
                        const SizedBox(height: AppSizes.spacingMd),
                      ],

                      // Sandwich or standard components
                      if (_isSandwichProfile) ...<Widget>[
                        _SectionTitle('Bread type'),
                        const SizedBox(height: AppSizes.spacingSm),
                        _buildSandwichBreadSection(),
                        const SizedBox(height: AppSizes.spacingMd),
                        _SectionTitle('Sauce'),
                        const SizedBox(height: AppSizes.spacingSm),
                        _buildSandwichSauceSection(),
                        if (_selectedBreadType ==
                            SandwichBreadType.sandwich) ...<Widget>[
                          const SizedBox(height: AppSizes.spacingMd),
                          _SectionTitle('Toast'),
                          const SizedBox(height: AppSizes.spacingSm),
                          _buildSandwichToastSection(),
                        ],
                      ] else ...<Widget>[
                        _SectionTitle('Included sides / components'),
                        const SizedBox(height: AppSizes.spacingSm),
                        for (final MealAdjustmentComponent component
                            in activeComponents)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSizes.spacingSm,
                            ),
                            child: _buildComponentCard(component),
                          ),
                      ],

                      // Add-ins
                      if (activeExtras.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSizes.spacingMd),
                        _buildAddInsSection(activeExtras),
                        const SizedBox(height: AppSizes.spacingLg),
                      ],

                      // Summary
                      _buildSummarySection(),
                      const SizedBox(height: AppSizes.spacingMd),

                      // Price
                      _buildPriceSection(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSizes.spacingMd),
              // ── Footer ──
              _buildDialogFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════

  Widget _buildDialogHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _dialogTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isSandwichProfile
                    ? 'Customize your sandwich options below.'
                    : 'Personalize this meal by adjusting included items or adding extras.',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.spacingSm),
        Material(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            onTap: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close_rounded, size: 22),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  FOOTER
  // ═══════════════════════════════════════════════════════════

  Widget _buildDialogFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(120, 48),
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: AppSizes.spacingMd),
        ElevatedButton(
          key: const ValueKey<String>('meal-customization-confirm'),
          onPressed: _preview.canConfirm
              ? () => Navigator.of(context).pop(_preview.toCartSelection())
              : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(180, 52),
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.check_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                _confirmLabel,
                style: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  COMPONENT CARD
  // ═══════════════════════════════════════════════════════════

  Widget _buildComponentCard(MealAdjustmentComponent component) {
    final MealCustomizationComponentState selection = _editorState
        .selectionForComponent(component.componentKey);
    final String defaultName =
        _productNamesById[component.defaultItemProductId] ??
        'Product ${component.defaultItemProductId}';
    final String defaultLabel = _formatComponentItemLabel(
      defaultName,
      component.quantity,
    );
    final String stateLabel;
    if (selection.isSwap) {
      final String targetName =
          _productNamesById[selection.swapTargetItemProductId] ??
          selection.swapTargetItemProductId.toString();
      stateLabel =
          '$defaultLabel → ${_formatComponentItemLabel(targetName, selection.quantity)}';
    } else if (selection.isRemove) {
      stateLabel = 'No $defaultLabel';
    } else {
      stateLabel = defaultLabel;
    }

    final Color statusColor;
    final String statusText;
    if (selection.isRemove) {
      statusColor = AppColors.danger;
      statusText = 'Removed';
    } else if (selection.isSwap) {
      statusColor = AppColors.warning;
      statusText = 'Swapped';
    } else {
      statusColor = AppColors.success;
      statusText = 'Included';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      component.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stateLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _SectionMetaPill(label: statusText, color: statusColor),
            ],
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Wrap(
            spacing: AppSizes.spacingSm,
            runSpacing: AppSizes.spacingSm,
            children: <Widget>[
              _SelectionChip(
                key: ValueKey<String>(
                  'meal-component-keep-${component.componentKey}',
                ),
                label: 'Keep',
                icon: Icons.check_rounded,
                selected: selection.isKeep,
                onPressed: () => _updateComponent(
                  componentKey: component.componentKey,
                  mode: MealComponentSelectionMode.keep,
                ),
              ),
              if (component.canRemove)
                _SelectionChip(
                  key: ValueKey<String>(
                    'meal-component-remove-${component.componentKey}',
                  ),
                  label: 'Remove',
                  icon: Icons.delete_outline_rounded,
                  selected: selection.isRemove,
                  onPressed: () => _updateComponent(
                    componentKey: component.componentKey,
                    mode: MealComponentSelectionMode.remove,
                  ),
                )
              else
                const _RequiredPill(label: 'Required'),
              for (final MealAdjustmentComponentOption option
                  in component.swapOptions.where(
                    (MealAdjustmentComponentOption option) => option.isActive,
                  ))
                (() {
                  final int swapPriceDeltaMinor =
                      option.fixedPriceDeltaMinor ?? 0;
                  final String optionLabel = _formatComponentItemLabel(
                    _productNamesById[option.optionItemProductId] ??
                        option.optionItemProductId.toString(),
                    component.quantity,
                  );
                  final String priceSuffix = swapPriceDeltaMinor > 0
                      ? ' +${CurrencyFormatter.fromMinor(swapPriceDeltaMinor)}'
                      : '';
                  return _SelectionChip(
                    key: ValueKey<String>(
                      'meal-component-swap-${component.componentKey}-${option.optionItemProductId}',
                    ),
                    label: 'Swap to $optionLabel$priceSuffix',
                    icon: Icons.swap_horiz_rounded,
                    selected:
                        selection.swapTargetItemProductId ==
                        option.optionItemProductId,
                    onPressed: () => _updateComponent(
                      componentKey: component.componentKey,
                      mode: MealComponentSelectionMode.swap,
                      swapTargetItemProductId: option.optionItemProductId,
                    ),
                  );
                })(),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SANDWICH SECTIONS  (logic unchanged, _ModeButton → _SelectionChip)
  // ═══════════════════════════════════════════════════════════

  Widget _buildSandwichBreadSection() {
    return Wrap(
      spacing: AppSizes.spacingSm,
      runSpacing: AppSizes.spacingSm,
      children: SandwichBreadType.values
          .map((SandwichBreadType breadType) {
            final int surchargeMinor = _profile.sandwichSettings
                .surchargeForBread(breadType);
            final String surchargeLabel = surchargeMinor == 0
                ? ''
                : ' +${CurrencyFormatter.fromMinor(surchargeMinor)}';
            return _SelectionChip(
              key: ValueKey<String>('meal-sandwich-bread-${breadType.name}'),
              label: '${sandwichBreadLabel(breadType)}$surchargeLabel',
              selected: _selectedBreadType == breadType,
              onPressed: () => _updateSandwichBreadType(breadType),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildSandwichSauceSection() {
    final List<int> sauceProductIds = _profile.sandwichSettings.sauceProductIds;
    if (sauceProductIds.isEmpty) {
      return const Text(
        'No sauces are enabled for this sandwich profile.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Wrap(
      spacing: AppSizes.spacingSm,
      runSpacing: AppSizes.spacingSm,
      children: sauceProductIds
          .map((int sauceProductId) {
            final String sauceLabel =
                _productNamesById[sauceProductId] ?? 'Product $sauceProductId';
            return _SelectionChip(
              key: ValueKey<String>('meal-sandwich-sauce-$sauceProductId'),
              label: sauceLabel,
              selected: _editorState.sandwichSelection.sauceProductIds.contains(
                sauceProductId,
              ),
              onPressed: () => _toggleSandwichSauce(sauceProductId),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildSandwichToastSection() {
    return Wrap(
      spacing: AppSizes.spacingSm,
      runSpacing: AppSizes.spacingSm,
      children: SandwichToastOption.values
          .map((SandwichToastOption option) {
            return _SelectionChip(
              key: ValueKey<String>('meal-sandwich-toast-${option.name}'),
              label: sandwichToastLabel(option),
              selected: _selectedToastOption == option,
              onPressed: () => _updateSandwichSelection(
                _editorState.sandwichSelection.copyWith(toastOption: option),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  EXTRA CARD  (card-based layout preserved, styling improved)
  // ═══════════════════════════════════════════════════════════

  Widget _buildExtraCard(MealAdjustmentExtraOption option) {
    final MealCustomizationExtraSelection? existingSelection = _editorState
        .extraSelections
        .where(
          (MealCustomizationExtraSelection selection) =>
              selection.itemProductId == option.itemProductId,
        )
        .cast<MealCustomizationExtraSelection?>()
        .firstWhere(
          (MealCustomizationExtraSelection? selection) => selection != null,
          orElse: () => null,
        );
    final int quantity = existingSelection?.quantity ?? 0;
    final bool isSelected = quantity > 0;
    final String itemName =
        _productNamesById[option.itemProductId] ??
        'Product ${option.itemProductId}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey<String>('meal-extra-toggle-${option.itemProductId}'),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        onTap: () =>
            _updateExtraQuantity(option.itemProductId, isSelected ? 0 : 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surface,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      itemName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      key: ValueKey<String>(
                        'meal-extra-selected-${option.itemProductId}',
                      ),
                      color: AppColors.primary,
                      size: 22,
                    )
                  else
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.textMuted,
                      size: 22,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '+${CurrencyFormatter.fromMinor(option.fixedPriceDeltaMinor)}',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  ADD-INS SECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildAddInsSection(List<MealAdjustmentExtraOption> activeExtras) {
    final List<String> selectedNames = _selectedAddInNames(activeExtras);
    final int selectedCount = selectedNames.length;
    final String headerLabel = selectedCount > 0
        ? 'Add-ins ($selectedCount selected)'
        : 'Add-ins (${activeExtras.length})';
    final String? collapsedSummary =
        !_isAddInsExpanded && selectedNames.isNotEmpty
        ? selectedNames.map((String name) => '+$name').join(', ')
        : null;

    return Container(
      key: const ValueKey<String>('meal-addins-section'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            key: const ValueKey<String>('meal-addins-toggle'),
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            onTap: () {
              setState(() {
                _isAddInsExpanded = !_isAddInsExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          headerLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (collapsedSummary != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            collapsedSummary,
                            key: const ValueKey<String>('meal-addins-summary'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _isAddInsExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isAddInsExpanded)
            Padding(
              key: const ValueKey<String>('meal-addins-body'),
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Added into the meal itself.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spacingSm),
                  Wrap(
                    spacing: AppSizes.spacingSm,
                    runSpacing: AppSizes.spacingSm,
                    children: activeExtras
                        .map(_buildExtraCard)
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SUMMARY SECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildSummarySection() {
    final int changeCount = _preview.summaryLines.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.receipt_long_outlined,
                color: AppColors.textSecondary,
                size: 18,
              ),
              const SizedBox(width: AppSizes.spacingSm),
              Text(
                'Summary',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSizes.spacingSm),
              _SectionMetaPill(
                label: '$changeCount change${changeCount == 1 ? '' : 's'}',
                color: changeCount > 0
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingSm),
          if (_preview.validationMessages.isNotEmpty)
            Container(
              key: const ValueKey<String>(
                'meal-customization-invalid-message',
              ),
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _preview.validationMessages
                    .map(
                      (String message) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
          else if (_preview.summaryLines.isEmpty)
            const Text(
              'No changes. The meal will be added as configured by default.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _preview.summaryLines
                  .map(
                    (String line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            '•  ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              line,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PRICE SECTION
  // ═══════════════════════════════════════════════════════════

  Widget _buildPriceSection() {
    return Container(
      key: const ValueKey<String>('meal-customization-price-preview'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingSm,
        vertical: AppSizes.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryStat(
              label: 'Adjustment',
              value: _signedMoney(_preview.adjustmentMinor),
            ),
          ),
          const SizedBox(width: AppSizes.spacingSm),
          Expanded(
            child: _SummaryStat(
              label: 'Final line total',
              value: CurrencyFormatter.fromMinor(
                _preview.finalLineTotalMinor,
              ),
              emphasize: true,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  BUSINESS LOGIC — ALL UNCHANGED
  // ═══════════════════════════════════════════════════════════

  List<String> _selectedAddInNames(
    List<MealAdjustmentExtraOption> activeExtras,
  ) {
    final Set<int> activeIds = activeExtras
        .map((MealAdjustmentExtraOption option) => option.itemProductId)
        .toSet();
    return _editorState.extraSelections
        .where(
          (MealCustomizationExtraSelection selection) =>
              selection.quantity > 0 &&
              activeIds.contains(selection.itemProductId),
        )
        .map(
          (MealCustomizationExtraSelection selection) =>
              _productNamesById[selection.itemProductId] ??
              'Product ${selection.itemProductId}',
        )
        .toList(growable: false);
  }

  void _updateComponent({
    required String componentKey,
    required MealComponentSelectionMode mode,
    int? swapTargetItemProductId,
  }) {
    final int componentQuantity = _componentQuantityForKey(componentKey);
    final List<MealCustomizationComponentState> componentSelections =
        _editorState.componentSelections
            .where(
              (MealCustomizationComponentState selection) =>
                  selection.componentKey != componentKey,
            )
            .toList(growable: true);
    switch (mode) {
      case MealComponentSelectionMode.keep:
        break;
      case MealComponentSelectionMode.remove:
        componentSelections.add(
          MealCustomizationComponentState(
            componentKey: componentKey,
            mode: MealComponentSelectionMode.remove,
            quantity: componentQuantity,
          ),
        );
        break;
      case MealComponentSelectionMode.swap:
        componentSelections.add(
          MealCustomizationComponentState(
            componentKey: componentKey,
            mode: MealComponentSelectionMode.swap,
            swapTargetItemProductId: swapTargetItemProductId,
            quantity: componentQuantity,
          ),
        );
        break;
    }
    componentSelections.sort(
      (
        MealCustomizationComponentState left,
        MealCustomizationComponentState right,
      ) => left.componentKey.compareTo(right.componentKey),
    );
    _setEditorState(
      _editorState.copyWith(componentSelections: componentSelections),
    );
  }

  void _updateExtraQuantity(int itemProductId, int quantity) {
    final int normalizedQuantity = quantity <= 0 ? 0 : 1;
    final List<MealCustomizationExtraSelection> extras = _editorState
        .extraSelections
        .where(
          (MealCustomizationExtraSelection selection) =>
              selection.itemProductId != itemProductId,
        )
        .toList(growable: true);
    if (normalizedQuantity > 0) {
      extras.add(
        MealCustomizationExtraSelection(
          itemProductId: itemProductId,
          quantity: normalizedQuantity,
        ),
      );
    }
    extras.sort(
      (
        MealCustomizationExtraSelection left,
        MealCustomizationExtraSelection right,
      ) => left.itemProductId.compareTo(right.itemProductId),
    );
    _setEditorState(_editorState.copyWith(extraSelections: extras));
  }

  void _updateSandwichBreadType(SandwichBreadType breadType) {
    final SandwichCustomizationSelection current =
        _editorState.sandwichSelection;
    final SandwichToastOption? nextToast =
        breadType == SandwichBreadType.sandwich
        ? (current.toastOption ?? SandwichToastOption.normal)
        : null;
    _updateSandwichSelection(
      current.copyWith(breadType: breadType, toastOption: nextToast),
    );
  }

  void _updateSandwichSelection(SandwichCustomizationSelection selection) {
    _setEditorState(_editorState.copyWith(sandwichSelection: selection));
  }

  void _toggleSandwichSauce(int sauceProductId) {
    final List<int> current = List<int>.from(
      _editorState.sandwichSelection.sauceProductIds,
    );
    if (current.contains(sauceProductId)) {
      current.remove(sauceProductId);
    } else {
      current.add(sauceProductId);
    }
    _updateSandwichSelection(
      _editorState.sandwichSelection.copyWith(
        sauceProductIds: normalizeSandwichSauceProductIds(current),
        legacySauceLookupKeys: const <String>[],
      ),
    );
  }

  void _setEditorState(MealCustomizationEditorState nextState) {
    setState(() {
      _editorState = nextState;
      _preview = ref
          .read(mealCustomizationPosServiceProvider)
          .previewSelection(
            product: widget.product,
            profile: _profile,
            editorState: _editorState,
            productNamesById: _productNamesById,
          );
    });
  }

  Widget _buildSuggestionChip(MealQuickSuggestion suggestion) {
    return ActionChip(
      key: ValueKey<String>('meal-suggestion-${suggestion.label}'),
      label: Text(
        suggestion.label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      onPressed: () => _applySuggestion(suggestion),
    );
  }

  void _applySuggestion(MealQuickSuggestion suggestion) {
    switch (suggestion.kind) {
      case MealSuggestionActionKind.remove:
        if (suggestion.componentKey != null) {
          _updateComponent(
            componentKey: suggestion.componentKey!,
            mode: MealComponentSelectionMode.remove,
          );
        }
        break;
      case MealSuggestionActionKind.swap:
        if (suggestion.componentKey != null &&
            suggestion.targetItemProductId != null) {
          _updateComponent(
            componentKey: suggestion.componentKey!,
            mode: MealComponentSelectionMode.swap,
            swapTargetItemProductId: suggestion.targetItemProductId,
          );
        }
        break;
      case MealSuggestionActionKind.addExtra:
        if (suggestion.itemProductId != null) {
          final int current = _editorState.extraSelections
              .where(
                (MealCustomizationExtraSelection selection) =>
                    selection.itemProductId == suggestion.itemProductId,
              )
              .fold<int>(
                0,
                (int total, MealCustomizationExtraSelection s) =>
                    total + s.quantity,
              );
          _updateExtraQuantity(
            suggestion.itemProductId!,
            current + suggestion.quantity,
          );
        }
        break;
    }
  }

  String _signedMoney(int amountMinor) {
    if (amountMinor > 0) {
      return '+${CurrencyFormatter.fromMinor(amountMinor)}';
    }
    if (amountMinor < 0) {
      return '-${CurrencyFormatter.fromMinor(amountMinor.abs())}';
    }
    return CurrencyFormatter.fromMinor(amountMinor);
  }

  int _componentQuantityForKey(String componentKey) {
    for (final MealAdjustmentComponent component in _profile.components) {
      if (component.componentKey == componentKey) {
        return component.quantity;
      }
    }
    return 1;
  }

  String _formatComponentItemLabel(String label, int quantity) {
    return quantity > 1 ? '$label x$quantity' : label;
  }
}

// ═════════════════════════════════════════════════════════════
//  PRIVATE HELPER WIDGETS
// ═════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

/// Pill-shaped selectable chip replacing the old [OutlinedButton]-based
/// _ModeButton. Follows the Set Breakfast `_CookingInstructionChip` pattern.
class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequiredPill extends StatelessWidget {
  const _RequiredPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Mini stat card matching Set Breakfast's `_SummaryStat` pattern.
class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingXs,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: emphasize
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
          color: emphasize
              ? AppColors.primary.withValues(alpha: 0.24)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontSm,
              fontWeight: FontWeight.w700,
              color: emphasize ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? AppSizes.fontMd : 14,
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill-shaped status badge (e.g. "Included", "Removed", "Swapped").
class _SectionMetaPill extends StatelessWidget {
  const _SectionMetaPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
