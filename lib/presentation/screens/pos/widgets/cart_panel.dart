import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../providers/cart_provider.dart';
import 'cart_line_tile.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({
    required this.cartState,
    required this.panelWidth,
    required this.canCheckout,
    required this.isCheckoutLoading,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
    required this.onRemoveLine,
    required this.onCheckout,
    super.key,
  });

  final CartState cartState;
  final double panelWidth;
  final bool canCheckout;
  final bool isCheckoutLoading;
  final ValueChanged<String> onIncreaseQuantity;
  final ValueChanged<String> onDecreaseQuantity;
  final ValueChanged<String> onRemoveLine;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = cartState.items.isEmpty;
    final bool isCompact = panelWidth < 320;
    final double horizontalPadding = isCompact ? 10 : 14;
    final double footerVerticalPadding = isCompact ? 10 : 12;
    final double listHorizontalPadding = isCompact ? 10 : 12;

    return Container(
      width: panelWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isCompact ? 9 : 10,
              horizontalPadding,
              isCompact ? 6 : 8,
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.shopping_cart_checkout,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppStrings.cartTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (!isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${cartState.items.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(isCompact ? 10 : 12),
                      child: Text(
                        AppStrings.cartEmpty,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      listHorizontalPadding,
                      2,
                      listHorizontalPadding,
                      isCompact ? 4 : 6,
                    ),
                    itemCount: cartState.items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (BuildContext context, int index) {
                      final item = cartState.items[index];
                      return CartLineTile(
                        item: item,
                        compactLayout: isCompact,
                        onIncrease: () => onIncreaseQuantity(item.localId),
                        onDecrease: () => onDecreaseQuantity(item.localId),
                        onDelete: () => onRemoveLine(item.localId),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              isCompact ? 8 : 10,
              horizontalPadding,
              footerVerticalPadding,
            ),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: <Widget>[
                _TotalRow(
                  label: AppStrings.subtotal,
                  value: CurrencyFormatter.fromMinor(cartState.subtotalMinor),
                ),
                const SizedBox(height: 4),
                _TotalRow(
                  label: AppStrings.modifierTotal,
                  value: CurrencyFormatter.fromMinor(
                    cartState.modifierTotalMinor,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                _TotalRow(
                  label: AppStrings.total,
                  value: CurrencyFormatter.fromMinor(cartState.totalMinor),
                  isEmphasis: true,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: isCompact ? 44 : 46,
                  child: ElevatedButton(
                    onPressed: canCheckout ? onCheckout : null,
                    child: isCheckoutLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppColors.surface,
                            ),
                          )
                        : Text(
                            AppStrings.checkout,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isEmphasis = false,
  });

  final String label;
  final String value;
  final bool isEmphasis;

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = TextStyle(
      fontSize: isEmphasis ? 17 : 12,
      fontWeight: isEmphasis ? FontWeight.w800 : FontWeight.w600,
      color: isEmphasis ? AppColors.primary : AppColors.textPrimary,
    );

    return Row(
      children: <Widget>[
        Text(label, style: textStyle),
        const Spacer(),
        Text(value, style: textStyle),
      ],
    );
  }
}
