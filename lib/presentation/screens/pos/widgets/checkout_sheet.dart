import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/payment.dart';

typedef CheckoutPayCallback = Future<bool> Function(PaymentMethod method);
typedef CheckoutActionCallback = Future<bool> Function();

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({
    required this.cartTotalMinor,
    required this.subtotalMinor,
    required this.modifierTotalMinor,
    required this.canPayNow,
    required this.canCreateOrder,
    required this.canClearCart,
    required this.isBusy,
    required this.onPay,
    required this.onCreateOrder,
    required this.onClearCart,
    super.key,
  });

  final int cartTotalMinor;
  final int subtotalMinor;
  final int modifierTotalMinor;
  final bool canPayNow;
  final bool canCreateOrder;
  final bool canClearCart;
  final bool isBusy;
  final CheckoutPayCallback onPay;
  final CheckoutActionCallback onCreateOrder;
  final CheckoutActionCallback onClearCart;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _isSubmitting = false;

  bool get _isActionLocked => widget.isBusy || _isSubmitting;

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double sheetWidth = math.min(360, screenSize.width * 0.36);
    final String totalLabel = CurrencyFormatter.fromMinor(widget.cartTotalMinor);

    return Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: sheetWidth,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(-3, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppStrings.checkout,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              totalLabel,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isActionLocked
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.textSecondary,
                        splashRadius: 18,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.paymentTitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 42,
                    child: SegmentedButton<PaymentMethod>(
                      selected: <PaymentMethod>{_paymentMethod},
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((
                          Set<WidgetState> states,
                        ) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.primary;
                          }
                          return AppColors.surfaceMuted;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((
                          Set<WidgetState> states,
                        ) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.surface;
                          }
                          return AppColors.textPrimary;
                        }),
                        side: const WidgetStatePropertyAll<BorderSide>(
                          BorderSide(color: AppColors.border),
                        ),
                        textStyle: const WidgetStatePropertyAll<TextStyle>(
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ),
                      segments: <ButtonSegment<PaymentMethod>>[
                        ButtonSegment(
                          value: PaymentMethod.cash,
                          label: Text(AppStrings.cash),
                        ),
                        ButtonSegment(
                          value: PaymentMethod.card,
                          label: Text(AppStrings.card),
                        ),
                      ],
                      onSelectionChanged: _isActionLocked
                          ? null
                          : (Set<PaymentMethod> selection) {
                              if (selection.isEmpty) {
                                return;
                              }
                              setState(() {
                                _paymentMethod = selection.first;
                              });
                            },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: <Widget>[
                        _SummaryRow(
                          label: AppStrings.subtotal,
                          value: CurrencyFormatter.fromMinor(
                            widget.subtotalMinor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _SummaryRow(
                          label: AppStrings.modifierTotal,
                          value: CurrencyFormatter.fromMinor(
                            widget.modifierTotalMinor,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        _SummaryRow(
                          label: AppStrings.total,
                          value: totalLabel,
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: widget.canPayNow && !_isActionLocked
                          ? _handlePay
                          : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: AppColors.surface,
                              ),
                            )
                          : Text(
                              '${AppStrings.payAction} $totalLabel',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: widget.canCreateOrder && !_isActionLocked
                          ? _handleCreateOrder
                          : null,
                      child: Text(
                        AppStrings.saveAsOpenOrder,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: widget.canClearCart && !_isActionLocked
                        ? _handleClearCart
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(
                      AppStrings.clearCart,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePay() async {
    setState(() {
      _isSubmitting = true;
    });
    final bool shouldClose = await widget.onPay(_paymentMethod);
    if (!mounted) {
      return;
    }
    if (shouldClose) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isSubmitting = false;
    });
  }

  Future<void> _handleCreateOrder() async {
    setState(() {
      _isSubmitting = true;
    });
    final bool shouldClose = await widget.onCreateOrder();
    if (!mounted) {
      return;
    }
    if (shouldClose) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isSubmitting = false;
    });
  }

  Future<void> _handleClearCart() async {
    setState(() {
      _isSubmitting = true;
    });
    final bool shouldClose = await widget.onClearCart();
    if (!mounted) {
      return;
    }
    if (shouldClose) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isSubmitting = false;
    });
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: emphasized ? 16 : 12,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
      color: emphasized ? AppColors.primary : AppColors.textPrimary,
    );

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: style),
      ],
    );
  }
}
