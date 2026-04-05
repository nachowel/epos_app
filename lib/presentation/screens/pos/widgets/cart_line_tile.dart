import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/breakfast_cooking_instruction.dart';
import '../../../../domain/models/meal_customization.dart';
import '../../../../domain/models/order_modifier.dart';
import '../../../../domain/models/breakfast_cart_selection.dart';
import '../../../providers/cart_models.dart';

class CartLineTile extends StatelessWidget {
  const CartLineTile({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDelete,
    this.compactLayout = false,
    super.key,
  });

  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onDelete;
  final bool compactLayout;

  @override
  Widget build(BuildContext context) {
    final BreakfastCartSelection? breakfastSelection = item.breakfastSelection;
    final MealCustomizationCartSelection? mealCustomizationSelection =
        item.mealCustomizationSelection;
    final List<String> cookingSummaryLines = _buildCookingSummaryLines();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compactLayout ? 4 : 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.05,
                  ),
                ),
              ),
              SizedBox(width: compactLayout ? 6 : 8),
              Text(
                CurrencyFormatter.fromMinor(item.totalMinor),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (breakfastSelection != null)
            ..._buildBreakfastSummary(breakfastSelection)
          else if (mealCustomizationSelection != null &&
              mealCustomizationSelection.compactSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              mealCustomizationSelection.compactSummary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                height: 1.05,
              ),
            ),
          ]
          else if (_buildModifierSummary().isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              _buildModifierSummary(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.05,
              ),
            ),
          ],
          if (cookingSummaryLines.isNotEmpty)
            ...cookingSummaryLines.map(
              (String line) => Padding(
                padding: const EdgeInsets.only(top: 2, left: 2),
                child: Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.05,
                  ),
                ),
              ),
            ),
          SizedBox(height: compactLayout ? 3 : 4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${CurrencyFormatter.fromMinor(item.unitPriceMinor)} x${item.quantity}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              _StepperButton(icon: Icons.remove_rounded, onPressed: onDecrease),
              Container(
                width: 22,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StepperButton(icon: Icons.add_rounded, onPressed: onIncrease),
              SizedBox(width: compactLayout ? 2 : 4),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.error,
                iconSize: 18,
                splashRadius: 16,
                constraints: BoxConstraints(
                  minWidth: compactLayout ? 30 : 32,
                  minHeight: compactLayout ? 30 : 32,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBreakfastSummary(BreakfastCartSelection selection) {
    final List<Widget> widgets = <Widget>[];
    for (final BreakfastCartModifierDisplayLine line
        in selection.modifierDisplayLines) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            line.cartLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: line.tone == BreakfastCartModifierTone.removed
                  ? AppColors.warning
                  : AppColors.primary,
              height: 1.05,
            ),
          ),
        ),
      );
    }
    if (selection.choiceDisplayLines.isNotEmpty) {
      final String compactChoiceSummary = _buildChoiceSummaryLine(
        selection.choiceDisplayLines,
      );
      widgets.add(const SizedBox(height: 3));
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            compactChoiceSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.05,
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  String _buildChoiceSummaryLine(List<BreakfastCartChoiceDisplayLine> lines) {
    final List<BreakfastCartChoiceDisplayLine> orderedLines =
        List<BreakfastCartChoiceDisplayLine>.from(lines)
          ..sort(
            (
              BreakfastCartChoiceDisplayLine a,
              BreakfastCartChoiceDisplayLine b,
            ) => _choiceSortRank(a.groupName).compareTo(
              _choiceSortRank(b.groupName),
            ),
          );
    return orderedLines
        .map((BreakfastCartChoiceDisplayLine line) => line.selectedLabel)
        .join(' · ');
  }

  int _choiceSortRank(String groupName) {
    final String normalized = groupName.toLowerCase();
    if (normalized.contains('drink') ||
        normalized.contains('tea') ||
        normalized.contains('coffee') ||
        normalized.contains('latte') ||
        normalized.contains('cappuccino')) {
      return 0;
    }
    if (normalized.contains('bread') || normalized.contains('toast')) {
      return 1;
    }
    return 2;
  }

  String _buildModifierSummary() {
    return item.modifiers.map(_modifierLabel).join('  ·  ');
  }

  List<String> _buildCookingSummaryLines() {
    final selection = item.breakfastSelection;
    if (selection == null) {
      return const <String>[];
    }
    return selection.cookingDisplayLines
        .map((BreakfastCookingInstructionDisplayLine line) => line.cartLabel)
        .toList(growable: false);
  }

  String _modifierLabel(CartModifier modifier) {
    final bool isAdd = modifier.action == ModifierAction.add;
    final String pricePart = isAdd && modifier.extraPriceMinor > 0
        ? ' ${CurrencyFormatter.fromMinor(modifier.extraPriceMinor)}'
        : '';
    return '${isAdd ? '+' : '-'} ${modifier.itemName}$pricePart';
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(icon, size: 17, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
