import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/breakfast_cart_selection.dart';
import '../../../../domain/models/breakfast_cooking_instruction.dart';
import '../../../../domain/models/meal_adjustment_profile.dart';
import '../../../../domain/models/meal_customization.dart';
import '../../../../domain/models/order_modifier.dart';
import '../../../../domain/services/breakfast_modifier_renderer.dart';
import '../../../providers/cart_models.dart';

class CartLineTile extends StatefulWidget {
  const CartLineTile({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDelete,
    this.compactLayout = false,
    this.isSelected = false,
    this.onSelect,
    super.key,
  });

  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onDelete;
  final bool compactLayout;
  final bool isSelected;
  final VoidCallback? onSelect;

  @override
  State<CartLineTile> createState() => _CartLineTileState();
}

class _CartLineTileState extends State<CartLineTile> {
  static const BreakfastModifierRenderer _breakfastModifierRenderer =
      BreakfastModifierRenderer();

  Timer? _highlightTimer;
  bool _isInteractionHighlighted = false;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  void _pulseHighlight() {
    _highlightTimer?.cancel();
    setState(() {
      _isInteractionHighlighted = true;
    });
    _highlightTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isInteractionHighlighted = false;
      });
    });
  }

  void _handleSelect() {
    widget.onSelect?.call();
  }

  void _handleIncrease() {
    _handleSelect();
    _pulseHighlight();
    widget.onIncrease();
  }

  void _handleDecrease() {
    _handleSelect();
    _pulseHighlight();
    widget.onDecrease();
  }

  void _handleDelete() {
    _handleSelect();
    _pulseHighlight();
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final BreakfastCartSelection? breakfastSelection =
        widget.item.breakfastSelection;
    final MealCustomizationCartSelection? mealCustomizationSelection =
        widget.item.mealCustomizationSelection;
    final List<_ModifierVisualEntry> modifierEntries = _buildModifierEntries(
      breakfastSelection: breakfastSelection,
      mealCustomizationSelection: mealCustomizationSelection,
    );
    final _ModifierLineSet modifierLines = _buildModifierLineSet(
      modifierEntries,
    );
    final String lineDisplayName =
        mealCustomizationSelection?.displayName ?? widget.item.productName;
    final bool hasChoiceLine =
        modifierLines.choiceLine != null &&
        modifierLines.choiceLine!.trim().isNotEmpty;
    final bool hasDetailLines = modifierLines.detailLines.isNotEmpty;
    final bool isActionActive = widget.isSelected || _isInteractionHighlighted;

    final Color backgroundColor = widget.isSelected
        ? AppColors.primaryLight
        : (_isInteractionHighlighted
              ? AppColors.primaryLighter
              : Colors.transparent);
    final Color accentColor = widget.isSelected
        ? AppColors.primaryStrong
        : (_isInteractionHighlighted ? AppColors.primary : Colors.transparent);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      color: backgroundColor,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleSelect,
          splashColor: AppColors.primaryLight,
          highlightColor: AppColors.primaryLighter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              widget.compactLayout ? 5 : 6,
              0,
              widget.compactLayout ? 5 : 6,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: 3,
                  height: hasDetailLines || hasChoiceLine ? 74 : 48,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                lineDisplayName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13.2,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  height: 1.12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TopRowActions(
                            totalMinor: widget.item.totalMinor,
                            quantity: widget.item.quantity,
                            compactLayout: widget.compactLayout,
                            isActive: isActionActive,
                            onDecrease: _handleDecrease,
                            onIncrease: _handleIncrease,
                            onDelete: _handleDelete,
                          ),
                        ],
                      ),
                      if (hasChoiceLine) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          modifierLines.choiceLine!,
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            fontSize: 11.1,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                            height: 1.1,
                          ),
                        ),
                      ],
                      if (hasDetailLines) ...<Widget>[
                        SizedBox(height: hasChoiceLine ? 2 : 3),
                        ...modifierLines.detailLines.map(
                          (String line) => Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              line,
                              maxLines: 3,
                              overflow: TextOverflow.visible,
                              style: const TextStyle(
                                fontSize: 10.8,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                height: 1.08,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_ModifierVisualEntry> _buildModifierEntries({
    required BreakfastCartSelection? breakfastSelection,
    required MealCustomizationCartSelection? mealCustomizationSelection,
  }) {
    if (breakfastSelection != null) {
      return _buildBreakfastEntries(breakfastSelection);
    }
    if (mealCustomizationSelection != null) {
      return _buildMealCustomizationEntries(mealCustomizationSelection);
    }
    return _buildLegacyModifierEntries();
  }

  List<_ModifierVisualEntry> _buildBreakfastEntries(
    BreakfastCartSelection selection,
  ) {
    final List<_ModifierVisualEntry> entries = <_ModifierVisualEntry>[];
    final List<BreakfastModifierRendered> renderedModifiers =
        _breakfastModifierRenderer.renderClassified(
          selection.rebuildResult.classifiedModifiers,
        );

    for (final BreakfastModifierRendered modifier in renderedModifiers) {
      if (!modifier.showOnReceipt) {
        continue;
      }
      if (modifier.chargeReason == ModifierChargeReason.includedChoice ||
          modifier.action == ModifierAction.choice) {
        continue;
      }
      entries.add(
        _ModifierVisualEntry(
          text: _stripCartSummaryPriceText(_breakfastRenderedLabel(modifier)),
          kind: _kindFromBreakfastModifier(modifier),
        ),
      );
    }

    for (final BreakfastCartChoiceDisplayLine line
        in selection.choiceDisplayLines) {
      entries.add(
        _ModifierVisualEntry(
          text: _stripCartSummaryPriceText(line.cartLabel),
          kind: _ModifierVisualKind.choice,
        ),
      );
    }

    for (final BreakfastCookingInstructionDisplayLine line
        in selection.cookingDisplayLines) {
      entries.add(
        _ModifierVisualEntry(
          text: _stripCartSummaryPriceText(line.cartLabel),
          kind: _ModifierVisualKind.neutral,
        ),
      );
    }

    return entries;
  }

  List<_ModifierVisualEntry> _buildMealCustomizationEntries(
    MealCustomizationCartSelection selection,
  ) {
    final List<String> lines = selection.summaryLines
        .where((String line) => line.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return const <_ModifierVisualEntry>[];
    }

    final List<_ModifierVisualKind> kinds =
        selection.snapshot.sandwichSelection != null
        ? _buildSandwichMealKinds(selection)
        : _buildStandardMealKinds(selection);

    final List<_ModifierVisualEntry> entries = <_ModifierVisualEntry>[];
    for (int index = 0; index < lines.length; index += 1) {
      final _ModifierVisualKind kind = index < kinds.length
          ? kinds[index]
          : _ModifierVisualKind.neutral;
      entries.add(
        _ModifierVisualEntry(
          text: _stripCartSummaryPriceText(
            _normalizeMealLine(lines[index], kind),
          ),
          kind: kind,
        ),
      );
    }
    return entries;
  }

  List<_ModifierVisualKind> _buildSandwichMealKinds(
    MealCustomizationCartSelection selection,
  ) {
    final SandwichCustomizationSelection sandwichSelection =
        selection.snapshot.sandwichSelection!;
    final int choiceCount =
        sandwichSelection.sauceProductIds.length +
        (sandwichSelection.toastOption != null ? 1 : 0);
    final int extraCount = selection.snapshot.resolvedExtraActions.length;
    return <_ModifierVisualKind>[
      ...List<_ModifierVisualKind>.filled(
        choiceCount,
        _ModifierVisualKind.choice,
      ),
      ...List<_ModifierVisualKind>.filled(extraCount, _ModifierVisualKind.add),
    ];
  }

  List<_ModifierVisualKind> _buildStandardMealKinds(
    MealCustomizationCartSelection selection,
  ) {
    final int removeCount = selection.snapshot.resolvedComponentActions
        .where(
          (MealCustomizationSemanticAction action) =>
              action.action == MealCustomizationAction.remove,
        )
        .length;
    final int swapCount = selection.snapshot.resolvedComponentActions
        .where(
          (MealCustomizationSemanticAction action) =>
              action.action == MealCustomizationAction.swap,
        )
        .length;
    final int extraCount = selection.snapshot.resolvedExtraActions.length;
    final int comboCount = selection.snapshot.appliedRules
        .where(
          (MealCustomizationAppliedRule rule) =>
              rule.ruleType == MealAdjustmentPricingRuleType.combo &&
              rule.priceDeltaMinor != 0,
        )
        .length;

    return <_ModifierVisualKind>[
      ...List<_ModifierVisualKind>.filled(
        removeCount,
        _ModifierVisualKind.remove,
      ),
      ...List<_ModifierVisualKind>.filled(swapCount, _ModifierVisualKind.swap),
      ...List<_ModifierVisualKind>.filled(extraCount, _ModifierVisualKind.add),
      ...List<_ModifierVisualKind>.filled(
        comboCount,
        _ModifierVisualKind.neutral,
      ),
    ];
  }

  List<_ModifierVisualEntry> _buildLegacyModifierEntries() {
    return widget.item.modifiers
        .map(
          (CartModifier modifier) => _ModifierVisualEntry(
            text: _modifierLabel(modifier),
            kind: _kindFromCartModifier(modifier),
          ),
        )
        .toList(growable: false);
  }

  String _breakfastRenderedLabel(BreakfastModifierRendered modifier) {
    switch (modifier.chargeReason) {
      case ModifierChargeReason.freeSwap:
      case ModifierChargeReason.paidSwap:
        return modifier.label
            .replaceFirst('+ ', '↔ ')
            .replaceAll(' (swap)', '');
      case ModifierChargeReason.extraAdd:
        return modifier.label;
      case ModifierChargeReason.includedChoice:
      case ModifierChargeReason.removalDiscount:
      case ModifierChargeReason.comboDiscount:
      case null:
        return modifier.label;
    }
  }

  String _normalizeMealLine(String line, _ModifierVisualKind kind) {
    switch (kind) {
      case _ModifierVisualKind.remove:
        return line.startsWith('No ') ? '- ${line.substring(3)}' : line;
      case _ModifierVisualKind.swap:
        return line.startsWith('↔') ? line : '↔ $line';
      case _ModifierVisualKind.add:
        if (line.startsWith('Extra ')) {
          return '+ ${line.substring(6)}';
        }
        return line.startsWith('+') ? line : '+ $line';
      case _ModifierVisualKind.choice:
      case _ModifierVisualKind.neutral:
        return line;
    }
  }

  _ModifierVisualKind _kindFromBreakfastModifier(
    BreakfastModifierRendered modifier,
  ) {
    switch (modifier.chargeReason) {
      case ModifierChargeReason.freeSwap:
      case ModifierChargeReason.paidSwap:
        return _ModifierVisualKind.swap;
      case ModifierChargeReason.extraAdd:
        return _ModifierVisualKind.add;
      case ModifierChargeReason.includedChoice:
        return _ModifierVisualKind.choice;
      case ModifierChargeReason.removalDiscount:
      case ModifierChargeReason.comboDiscount:
        return _ModifierVisualKind.neutral;
      case null:
        if (modifier.action == ModifierAction.remove) {
          return _ModifierVisualKind.remove;
        }
        if (modifier.action == ModifierAction.choice) {
          return _ModifierVisualKind.choice;
        }
        return _ModifierVisualKind.add;
    }
  }

  _ModifierVisualKind _kindFromCartModifier(CartModifier modifier) {
    switch (modifier.action) {
      case ModifierAction.remove:
        return _ModifierVisualKind.remove;
      case ModifierAction.choice:
        return _ModifierVisualKind.choice;
      case ModifierAction.add:
        return _ModifierVisualKind.add;
    }
  }

  String _modifierLabel(CartModifier modifier) {
    switch (modifier.action) {
      case ModifierAction.add:
        return '+ ${modifier.itemName}'.trim();
      case ModifierAction.remove:
        return '- ${modifier.itemName}'.trim();
      case ModifierAction.choice:
        return modifier.itemName.trim();
    }
  }

  String _stripCartSummaryPriceText(String value) {
    String normalized = value.trim();
    normalized = normalized.replaceAll(
      RegExp(r'\s*\(([+-]?£\d+(?:\.\d{2})?)\)\s*$'),
      '',
    );
    normalized = normalized.replaceAll(
      RegExp(r'\s+[+-]?£\d+(?:\.\d{2})?\s*$'),
      '',
    );
    return normalized.trim();
  }

  _ModifierLineSet _buildModifierLineSet(List<_ModifierVisualEntry> entries) {
    final List<String> choiceTokens = <String>[];
    final List<String> detailSegments = <String>[];

    for (final _ModifierVisualEntry entry in entries) {
      if (entry.kind == _ModifierVisualKind.choice) {
        final String token = _choiceToken(entry.text);
        if (token.isNotEmpty) {
          choiceTokens.add(token);
        }
        continue;
      }

      final String segment = _detailSegment(entry);
      if (segment.isNotEmpty) {
        detailSegments.add(segment);
      }
    }

    final List<String> detailLines = <String>[];
    for (int index = 0; index < detailSegments.length; index += 2) {
      detailLines.add(detailSegments.skip(index).take(2).join(' · '));
    }

    return _ModifierLineSet(
      choiceLine: choiceTokens.isEmpty ? null : choiceTokens.join(' · '),
      detailLines: detailLines,
    );
  }

  String _choiceToken(String text) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final int colonIndex = trimmed.indexOf(':');
    if (colonIndex >= 0 && colonIndex < trimmed.length - 1) {
      return trimmed.substring(colonIndex + 1).trim();
    }
    return trimmed.replaceFirst(RegExp(r'^[+\-↔]\s*'), '').trim();
  }

  String _detailSegment(_ModifierVisualEntry entry) {
    final String trimmed = entry.text.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    switch (entry.kind) {
      case _ModifierVisualKind.add:
        if (trimmed.startsWith('+')) {
          return trimmed;
        }
        return '+ $trimmed';
      case _ModifierVisualKind.remove:
        if (trimmed.startsWith('-')) {
          return trimmed;
        }
        return trimmed.startsWith('No ')
            ? '- ${trimmed.substring(3)}'
            : '- $trimmed';
      case _ModifierVisualKind.swap:
        return trimmed.startsWith('↔') ? trimmed : '↔ $trimmed';
      case _ModifierVisualKind.neutral:
        return trimmed;
      case _ModifierVisualKind.choice:
        return '';
    }
  }
}

enum _ModifierVisualKind { add, remove, swap, choice, neutral }

class _ModifierVisualEntry {
  const _ModifierVisualEntry({required this.text, required this.kind});

  final String text;
  final _ModifierVisualKind kind;
}

class _ModifierLineSet {
  const _ModifierLineSet({required this.choiceLine, required this.detailLines});

  final String? choiceLine;
  final List<String> detailLines;
}

class _QuantityControlGroup extends StatelessWidget {
  const _QuantityControlGroup({
    required this.quantity,
    required this.compactLayout,
    required this.isActive,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final bool compactLayout;
  final bool isActive;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    final double buttonSize = compactLayout ? 36 : 38;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepperButton(
          icon: Icons.remove_rounded,
          onPressed: onDecrease,
          size: buttonSize,
          isActive: isActive,
        ),
        SizedBox(
          width: compactLayout ? 12 : 14,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isActive ? AppColors.primaryDarker : AppColors.textPrimary,
              height: 1,
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add_rounded,
          onPressed: onIncrease,
          size: buttonSize,
          isActive: isActive,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.size,
    required this.isActive,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primaryLight : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.primaryLight,
        highlightColor: AppColors.primaryLighter,
        hoverColor: AppColors.primaryLighter,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: 16,
            color: isActive ? AppColors.primaryDarker : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.onPressed,
    required this.compactLayout,
    required this.isActive,
  });

  final VoidCallback onPressed;
  final bool compactLayout;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final double buttonSize = compactLayout ? 34 : 36;

    return Material(
      color: isActive ? AppColors.dangerLight : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor: AppColors.dangerLight,
        highlightColor: AppColors.dangerLight,
        hoverColor: AppColors.dangerLight,
        child: SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.dangerStrong,
            size: 17,
          ),
        ),
      ),
    );
  }
}

class _TopRowActions extends StatelessWidget {
  const _TopRowActions({
    required this.totalMinor,
    required this.quantity,
    required this.compactLayout,
    required this.isActive,
    required this.onDecrease,
    required this.onIncrease,
    required this.onDelete,
  });

  final int totalMinor;
  final int quantity;
  final bool compactLayout;
  final bool isActive;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.surface : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Text(
            CurrencyFormatter.fromMinor(totalMinor),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13.4,
              fontWeight: FontWeight.w800,
              color: isActive ? AppColors.primaryDarker : AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(width: 5),
          _QuantityControlGroup(
            quantity: quantity,
            compactLayout: compactLayout,
            isActive: isActive,
            onDecrease: onDecrease,
            onIncrease: onIncrease,
          ),
          const SizedBox(width: 2),
          _DeleteButton(
            onPressed: onDelete,
            compactLayout: compactLayout,
            isActive: isActive,
          ),
        ],
      ),
    );
  }
}
