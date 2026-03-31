import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/order_modifier.dart';
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
    final String modifierSummary = item.modifiers
        .map(_modifierLabel)
        .join('  ·  ');

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
          if (modifierSummary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              modifierSummary,
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
