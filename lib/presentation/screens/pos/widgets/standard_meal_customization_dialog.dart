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

    return AlertDialog(
      key: const ValueKey<String>('meal-customization-dialog'),
      title: Text(
        _isSandwichProfile
            ? 'Sandwich customization: ${widget.product.name}'
            : widget.isLegacyRecreateMode
            ? 'Recreate meal: ${widget.product.name}'
            : widget.isEditMode
            ? 'Edit meal: ${widget.product.name}'
            : 'Meal customization: ${widget.product.name}',
      ),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.isLegacyRecreateMode) ...<Widget>[
                Container(
                  key: const ValueKey<String>(
                    'meal-customization-legacy-notice',
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.spacingSm),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Text(
                    'This item was created before the new meal system and cannot '
                    'be edited directly. You can recreate it as a new editable meal.',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacingMd),
              ] else if (widget.isEditMode && widget.editOneMode) ...<Widget>[
                Container(
                  key: const ValueKey<String>(
                    'meal-customization-edit-one-notice',
                  ),
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.spacingSm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: const Text(
                    'Editing one item from this grouped line. '
                    'The remaining items will keep their current customization.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
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
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Text(
                    'Editing applies to all ${widget.lineQuantity} items on this grouped line.',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacingMd),
              ],
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
                    padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
                    child: _buildComponentCard(component),
                  ),
              ],
              if (activeExtras.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSizes.spacingMd),
                _buildAddInsSection(activeExtras),
                const SizedBox(height: AppSizes.spacingLg),
              ],
              _SectionTitle('Summary'),
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
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
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
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _preview.summaryLines
                      .map(
                        (String line) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            line,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              const SizedBox(height: AppSizes.spacingLg),
              _SectionTitle('Price effect'),
              const SizedBox(height: AppSizes.spacingSm),
              Container(
                key: const ValueKey<String>('meal-customization-price-preview'),
                width: double.infinity,
                padding: const EdgeInsets.all(AppSizes.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _PriceMetric(
                        label: 'Adjustment',
                        value: _signedMoney(_preview.adjustmentMinor),
                      ),
                    ),
                    Expanded(
                      child: _PriceMetric(
                        label: 'Final line total',
                        value: CurrencyFormatter.fromMinor(
                          _preview.finalLineTotalMinor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const ValueKey<String>('meal-customization-confirm'),
          onPressed: _preview.canConfirm
              ? () => Navigator.of(context).pop(_preview.toCartSelection())
              : null,
          child: Text(
            widget.isLegacyRecreateMode
                ? 'Recreate meal'
                : widget.isEditMode
                ? 'Save changes'
                : 'Add to cart',
          ),
        ),
      ],
    );
  }

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

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  component.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                stateLabel,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Wrap(
            spacing: AppSizes.spacingSm,
            runSpacing: AppSizes.spacingSm,
            children: <Widget>[
              _ModeButton(
                key: ValueKey<String>(
                  'meal-component-keep-${component.componentKey}',
                ),
                label: 'Keep',
                selected: selection.isKeep,
                onPressed: () => _updateComponent(
                  componentKey: component.componentKey,
                  mode: MealComponentSelectionMode.keep,
                ),
              ),
              if (component.canRemove)
                _ModeButton(
                  key: ValueKey<String>(
                    'meal-component-remove-${component.componentKey}',
                  ),
                  label: 'Remove',
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
                  return _ModeButton(
                    key: ValueKey<String>(
                      'meal-component-swap-${component.componentKey}-${option.optionItemProductId}',
                    ),
                    label: 'Swap to $optionLabel$priceSuffix',
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
            return _ModeButton(
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
    final List<SandwichSauceType> sauceOptions =
        _profile.sandwichSettings.sauceOptions;
    if (sauceOptions.isEmpty) {
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
      children: sauceOptions
          .map((SandwichSauceType sauceType) {
            return _ModeButton(
              key: ValueKey<String>('meal-sandwich-sauce-${sauceType.name}'),
              label: sandwichSauceLabel(sauceType),
              selected: _editorState.sandwichSelection.sauceTypes.contains(
                sauceType,
              ),
              onPressed: () => _toggleSandwichSauce(sauceType),
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
            return _ModeButton(
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
          width: 220,
          padding: const EdgeInsets.all(AppSizes.spacingSm),
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
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '+${CurrencyFormatter.fromMinor(option.fixedPriceDeltaMinor)}',
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isSelected) ...<Widget>[
                const SizedBox(height: AppSizes.spacingSm),
                Container(
                  key: ValueKey<String>(
                    'meal-extra-selected-${option.itemProductId}',
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Added',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

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
              padding: const EdgeInsets.all(AppSizes.spacingSm),
              child: Row(
                children: <Widget>[
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
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacingSm,
                0,
                AppSizes.spacingSm,
                AppSizes.spacingSm,
              ),
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

  void _toggleSandwichSauce(SandwichSauceType sauceType) {
    final List<SandwichSauceType> current = List<SandwichSauceType>.from(
      _editorState.sandwichSelection.sauceTypes,
    );
    if (current.contains(sauceType)) {
      current.remove(sauceType);
    } else {
      current.add(sauceType);
    }
    _updateSandwichSelection(
      _editorState.sandwichSelection.copyWith(
        sauceTypes: normalizeSandwichSauceTypes(current),
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

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : null,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Text(label),
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

class _PriceMetric extends StatelessWidget {
  const _PriceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
}
