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

  MealAdjustmentProfile get _profile => widget.initialEditorData.profile;
  Map<int, String> get _productNamesById => widget.initialEditorData.productNamesById;

  @override
  void initState() {
    super.initState();
    _editorState = widget.initialEditorData.preview.editorState;
    _preview = widget.initialEditorData.preview;
  }

  @override
  Widget build(BuildContext context) {
    final List<MealAdjustmentComponent> activeComponents = _profile.components
        .where((MealAdjustmentComponent component) => component.isActive)
        .toList(growable: false)
      ..sort(
        (MealAdjustmentComponent left, MealAdjustmentComponent right) =>
            left.sortOrder.compareTo(right.sortOrder),
      );
    final List<MealAdjustmentExtraOption> activeExtras = _profile.extraOptions
        .where((MealAdjustmentExtraOption option) => option.isActive)
        .toList(growable: false)
      ..sort(
        (MealAdjustmentExtraOption left, MealAdjustmentExtraOption right) =>
            left.sortOrder.compareTo(right.sortOrder),
      );

    return AlertDialog(
      key: const ValueKey<String>('meal-customization-dialog'),
      title: Text(
        widget.isLegacyRecreateMode
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
                  key: const ValueKey<String>('meal-customization-legacy-notice'),
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
                  key: const ValueKey<String>('meal-customization-edit-one-notice'),
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
                  key: const ValueKey<String>('meal-customization-edit-all-notice'),
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
              _SectionTitle('Included sides / components'),
              const SizedBox(height: AppSizes.spacingSm),
              for (final MealAdjustmentComponent component in activeComponents)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
                  child: _buildComponentCard(component),
                ),
              const SizedBox(height: AppSizes.spacingMd),
              _SectionTitle('Extras'),
              const SizedBox(height: AppSizes.spacingSm),
              if (activeExtras.isEmpty)
                const Text(
                  'No extras configured.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                Wrap(
                  spacing: AppSizes.spacingSm,
                  runSpacing: AppSizes.spacingSm,
                  children: activeExtras
                      .map(_buildExtraCard)
                      .toList(growable: false),
                ),
              const SizedBox(height: AppSizes.spacingLg),
              _SectionTitle('Summary'),
              const SizedBox(height: AppSizes.spacingSm),
              if (_preview.validationMessages.isNotEmpty)
                Container(
                  key: const ValueKey<String>('meal-customization-invalid-message'),
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
    final MealCustomizationComponentSelection? swapSelection =
        _editorState.swapSelections.cast<MealCustomizationComponentSelection?>().firstWhere(
              (MealCustomizationComponentSelection? selection) =>
                  selection?.componentKey == component.componentKey,
              orElse: () => null,
            );
    final bool isRemoved = _editorState.removedComponentKeys.contains(
      component.componentKey,
    );
    final String defaultName =
        _productNamesById[component.defaultItemProductId] ??
        'Product ${component.defaultItemProductId}';
    final String stateLabel;
    if (swapSelection != null) {
      stateLabel =
          '$defaultName → ${_productNamesById[swapSelection.targetItemProductId] ?? swapSelection.targetItemProductId}';
    } else if (isRemoved) {
      stateLabel = 'No $defaultName';
    } else {
      stateLabel = defaultName;
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
                key: ValueKey<String>('meal-component-keep-${component.componentKey}'),
                label: 'Keep',
                selected: !isRemoved && swapSelection == null,
                onPressed: () => _updateComponent(
                  componentKey: component.componentKey,
                ),
              ),
              if (component.canRemove)
                _ModeButton(
                  key: ValueKey<String>(
                    'meal-component-remove-${component.componentKey}',
                  ),
                  label: 'Remove',
                  selected: isRemoved,
                  onPressed: () => _updateComponent(
                    componentKey: component.componentKey,
                    remove: true,
                  ),
                )
              else
                const _RequiredPill(label: 'Required'),
              for (final MealAdjustmentComponentOption option in component.swapOptions
                  .where((MealAdjustmentComponentOption option) => option.isActive))
                (() {
                  final int swapPriceDeltaMinor =
                      option.fixedPriceDeltaMinor ?? 0;
                  final String optionLabel =
                      _productNamesById[option.optionItemProductId] ??
                      option.optionItemProductId.toString();
                  final String priceSuffix = swapPriceDeltaMinor > 0
                      ? ' +${CurrencyFormatter.fromMinor(swapPriceDeltaMinor)}'
                      : '';
                  return _ModeButton(
                    key: ValueKey<String>(
                      'meal-component-swap-${component.componentKey}-${option.optionItemProductId}',
                    ),
                    label: 'Swap to $optionLabel$priceSuffix',
                    selected:
                        swapSelection?.targetItemProductId ==
                        option.optionItemProductId,
                    onPressed: () => _updateComponent(
                      componentKey: component.componentKey,
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
    final String itemName =
        _productNamesById[option.itemProductId] ?? 'Product ${option.itemProductId}';

    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppSizes.spacingSm),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            itemName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.fromMinor(option.fixedPriceDeltaMinor),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Row(
            children: <Widget>[
              IconButton(
                key: ValueKey<String>('meal-extra-dec-${option.itemProductId}'),
                onPressed: quantity == 0
                    ? null
                    : () => _updateExtraQuantity(
                        option.itemProductId,
                        quantity - 1,
                      ),
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey<String>('meal-extra-inc-${option.itemProductId}'),
                onPressed: () => _updateExtraQuantity(
                  option.itemProductId,
                  quantity + 1,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateComponent({
    required String componentKey,
    bool remove = false,
    int? swapTargetItemProductId,
  }) {
    final Set<String> removedKeys = _editorState.removedComponentKeys.toSet();
    final List<MealCustomizationComponentSelection> swaps = _editorState
        .swapSelections
        .where(
          (MealCustomizationComponentSelection selection) =>
              selection.componentKey != componentKey,
        )
        .toList(growable: true);
    if (remove) {
      removedKeys.add(componentKey);
    } else {
      removedKeys.remove(componentKey);
      if (swapTargetItemProductId != null) {
        swaps.add(
          MealCustomizationComponentSelection(
            componentKey: componentKey,
            targetItemProductId: swapTargetItemProductId,
          ),
        );
      }
    }
    _setEditorState(
      _editorState.copyWith(
        removedComponentKeys: removedKeys.toList(growable: false)..sort(),
        swapSelections: swaps,
      ),
    );
  }

  void _updateExtraQuantity(int itemProductId, int quantity) {
    final List<MealCustomizationExtraSelection> extras = _editorState
        .extraSelections
        .where(
          (MealCustomizationExtraSelection selection) =>
              selection.itemProductId != itemProductId,
        )
        .toList(growable: true);
    if (quantity > 0) {
      extras.add(
        MealCustomizationExtraSelection(
          itemProductId: itemProductId,
          quantity: quantity,
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

  void _setEditorState(MealCustomizationEditorState nextState) {
    setState(() {
      _editorState = nextState;
      _preview = ref.read(mealCustomizationPosServiceProvider).previewSelection(
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
            remove: true,
          );
        }
        break;
      case MealSuggestionActionKind.swap:
        if (suggestion.componentKey != null &&
            suggestion.targetItemProductId != null) {
          _updateComponent(
            componentKey: suggestion.componentKey!,
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
              .fold<int>(0, (int total, MealCustomizationExtraSelection s) =>
                  total + s.quantity);
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
