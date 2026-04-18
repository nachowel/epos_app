import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/payment.dart';
import '../../../../domain/models/transaction_discount.dart';
import '../../../../domain/models/transaction.dart';

typedef CheckoutPayCallback = Future<bool> Function(PaymentMethod method);
typedef CheckoutActionCallback = Future<bool> Function();
typedef CheckoutDiscountApplyCallback =
    void Function(TransactionDiscountInput discount);

class CheckoutSheet extends StatefulWidget {
  const CheckoutSheet({
    required this.cartTotalMinor,
    required this.subtotalMinor,
    required this.modifierTotalMinor,
    required this.discount,
    required this.canPayNow,
    required this.canCreateOrder,
    required this.canClearCart,
    required this.canEditDiscount,
    required this.isBusy,
    required this.onPay,
    required this.onCreateOrder,
    required this.onClearCart,
    required this.onApplyDiscount,
    required this.onRemoveDiscount,
    super.key,
  });

  final int cartTotalMinor;
  final int subtotalMinor;
  final int modifierTotalMinor;
  final TransactionDiscountInput? discount;
  final bool canPayNow;
  final bool canCreateOrder;
  final bool canClearCart;
  final bool canEditDiscount;
  final bool isBusy;
  final CheckoutPayCallback onPay;
  final CheckoutActionCallback onCreateOrder;
  final CheckoutActionCallback onClearCart;
  final CheckoutDiscountApplyCallback onApplyDiscount;
  final VoidCallback onRemoveDiscount;

  @override
  State<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends State<CheckoutSheet> {
  static const List<int> _quickAmountPresetsMinor = <int>[50, 100, 200, 300];
  static const List<int> _quickPercentPresets = <int>[10];

  PaymentMethod _paymentMethod = PaymentMethod.cash;
  bool _isSubmitting = false;
  bool _isCustomEditorOpen = false;
  TransactionDiscountInput? _appliedDiscount;
  late TransactionDiscountType _discountType;
  late TextEditingController _discountValueController;
  late TextEditingController _discountReasonController;
  late FocusNode _discountValueFocusNode;
  String? _discountError;

  bool get _isActionLocked => widget.isBusy || _isSubmitting;
  bool get _canEditDiscount => widget.canEditDiscount && !_isActionLocked;

  TransactionDiscountInput? get _pendingDiscountInput {
    final String rawValue = _discountValueController.text.trim();
    if (rawValue.isEmpty) {
      return null;
    }
    final int? parsedValue = switch (_discountType) {
      TransactionDiscountType.amount =>
        CurrencyFormatter.tryParseEditableMajorInput(rawValue),
      TransactionDiscountType.percent => int.tryParse(rawValue),
    };
    if (parsedValue == null) {
      return null;
    }
    final String trimmedReason = _discountReasonController.text.trim();
    return TransactionDiscountInput(
      type: _discountType,
      valueMinor: parsedValue,
      reason: trimmedReason.isEmpty ? null : trimmedReason,
    );
  }

  TransactionDiscountComputation get _discountComputation =>
      TransactionDiscountMath.compute(
        subtotalMinor: widget.subtotalMinor,
        modifierTotalMinor: widget.modifierTotalMinor,
        discountType: _appliedDiscount?.type,
        discountValueMinor: _appliedDiscount?.valueMinor ?? 0,
      );

  @override
  void initState() {
    super.initState();
    _appliedDiscount = widget.discount;
    _discountType = _appliedDiscount?.type ?? TransactionDiscountType.amount;
    _discountValueController = TextEditingController(
      text: _displayValueForDiscount(_appliedDiscount),
    );
    _discountReasonController = TextEditingController(
      text: _appliedDiscount?.reason ?? '',
    );
    _discountValueFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _discountValueController.dispose();
    _discountReasonController.dispose();
    _discountValueFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double sheetWidth = math.min(360, screenSize.width * 0.36);
    final TransactionDiscountComputation discountComputation =
        _discountComputation;
    final String totalLabel = CurrencyFormatter.fromMinor(
      discountComputation.totalAmountMinor,
    );
    final TransactionDiscountInput? editedDiscount = _appliedDiscount;

    return Align(
      alignment: Alignment.centerRight,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: sheetWidth,
            constraints: BoxConstraints(maxHeight: screenSize.height - 16),
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
            child: SingleChildScrollView(
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
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.primary;
                            }
                            return AppColors.surfaceMuted;
                          },
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.surface;
                            }
                            return AppColors.textPrimary;
                          },
                        ),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Discount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            ..._quickAmountPresetsMinor.map(
                              (int amountMinor) => _QuickDiscountButton(
                                buttonKey: ValueKey<String>(
                                  'checkout-discount-preset-amount-$amountMinor',
                                ),
                                label: _formatQuickAmountLabel(amountMinor),
                                selected:
                                    editedDiscount?.type ==
                                        TransactionDiscountType.amount &&
                                    editedDiscount?.valueMinor == amountMinor,
                                onPressed: _canEditDiscount
                                    ? () => _handleQuickDiscount(
                                        TransactionDiscountInput(
                                          type: TransactionDiscountType.amount,
                                          valueMinor: amountMinor,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            ..._quickPercentPresets.map(
                              (int percent) => _QuickDiscountButton(
                                buttonKey: ValueKey<String>(
                                  'checkout-discount-preset-percent-$percent',
                                ),
                                label: '$percent%',
                                selected:
                                    editedDiscount?.type ==
                                        TransactionDiscountType.percent &&
                                    editedDiscount?.valueMinor == percent,
                                onPressed: _canEditDiscount
                                    ? () => _handleQuickDiscount(
                                        TransactionDiscountInput(
                                          type: TransactionDiscountType.percent,
                                          valueMinor: percent,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            key: const Key('checkout-custom-discount-toggle'),
                            onPressed: _canEditDiscount
                                ? _toggleCustomEditor
                                : null,
                            icon: Icon(
                              _isCustomEditorOpen
                                  ? Icons.expand_less_rounded
                                  : Icons.tune_rounded,
                              size: 18,
                            ),
                            label: const Text('Custom Discount'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              minimumSize: const Size.fromHeight(40),
                              side: const BorderSide(
                                color: AppColors.borderStrong,
                              ),
                              backgroundColor: _isCustomEditorOpen
                                  ? AppColors.surface
                                  : null,
                            ),
                          ),
                        ),
                        if (editedDiscount != null) ...<Widget>[
                          const SizedBox(height: 8),
                          _AppliedDiscountRow(
                            amountLabel:
                                '-${CurrencyFormatter.fromMinor(discountComputation.discountAmountMinor)}',
                            onRemove: _canEditDiscount
                                ? _handleRemoveDiscount
                                : null,
                          ),
                        ],
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          child: _isCustomEditorOpen
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        const Text(
                                          'Custom',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        SizedBox(
                                          height: 38,
                                          child: SegmentedButton<TransactionDiscountType>(
                                            selected: <TransactionDiscountType>{
                                              _discountType,
                                            },
                                            showSelectedIcon: false,
                                            segments:
                                                const <
                                                  ButtonSegment<
                                                    TransactionDiscountType
                                                  >
                                                >[
                                                  ButtonSegment<
                                                    TransactionDiscountType
                                                  >(
                                                    value:
                                                        TransactionDiscountType
                                                            .amount,
                                                    label: Text('Amount'),
                                                  ),
                                                  ButtonSegment<
                                                    TransactionDiscountType
                                                  >(
                                                    value:
                                                        TransactionDiscountType
                                                            .percent,
                                                    label: Text('Percent'),
                                                  ),
                                                ],
                                            onSelectionChanged: _canEditDiscount
                                                ? (
                                                    Set<TransactionDiscountType>
                                                    selection,
                                                  ) {
                                                    if (selection.isEmpty) {
                                                      return;
                                                    }
                                                    _handleDiscountTypeChanged(
                                                      selection.first,
                                                    );
                                                  }
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          key: const Key(
                                            'checkout-discount-value-field',
                                          ),
                                          controller: _discountValueController,
                                          focusNode: _discountValueFocusNode,
                                          autofocus: true,
                                          enabled: _canEditDiscount,
                                          keyboardType:
                                              _discountType ==
                                                  TransactionDiscountType.amount
                                              ? const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                )
                                              : TextInputType.number,
                                          textInputAction: TextInputAction.done,
                                          inputFormatters:
                                              _discountType ==
                                                  TransactionDiscountType.amount
                                              ? <TextInputFormatter>[
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r'[\d\.,£\s]'),
                                                  ),
                                                ]
                                              : <TextInputFormatter>[
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                          decoration: InputDecoration(
                                            labelText:
                                                _discountType ==
                                                    TransactionDiscountType
                                                        .amount
                                                ? 'Value (£)'
                                                : 'Value (%)',
                                            isDense: true,
                                            errorText: _discountError,
                                          ),
                                          onChanged: (_) {
                                            setState(() {
                                              _discountError = null;
                                            });
                                          },
                                          onSubmitted: (_) =>
                                              _handleApplyDiscount(),
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          key: const Key(
                                            'checkout-discount-reason-field',
                                          ),
                                          controller: _discountReasonController,
                                          enabled: _canEditDiscount,
                                          decoration: const InputDecoration(
                                            labelText: 'Reason (optional)',
                                            isDense: true,
                                          ),
                                          onSubmitted: (_) =>
                                              _handleApplyDiscount(),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 40,
                                          child: FilledButton(
                                            key: const Key(
                                              'checkout-discount-apply-button',
                                            ),
                                            onPressed: _canEditDiscount
                                                ? _handleApplyDiscount
                                                : null,
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryStrong,
                                            ),
                                            child: const Text('Apply'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
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
                        if (editedDiscount != null) ...<Widget>[
                          const SizedBox(height: 6),
                          _SummaryRow(
                            label: 'Discount',
                            value:
                                '-${CurrencyFormatter.fromMinor(discountComputation.discountAmountMinor)}',
                            valueColor: AppColors.dangerStrong,
                          ),
                        ],
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

  void _handleApplyDiscount() {
    final TransactionDiscountInput? discount = _pendingDiscountInput;
    if (discount == null) {
      setState(() {
        _discountError = _discountType == TransactionDiscountType.amount
            ? 'Enter a valid pound amount.'
            : 'Enter a discount value.';
      });
      return;
    }
    _applyDiscount(discount, closeCustomEditor: true);
  }

  void _handleQuickDiscount(TransactionDiscountInput discount) {
    _applyDiscount(discount, closeCustomEditor: true, resetEditorValue: false);
  }

  void _applyDiscount(
    TransactionDiscountInput discount, {
    required bool closeCustomEditor,
    bool resetEditorValue = true,
  }) {
    try {
      discount.validate();
    } on Exception catch (error) {
      setState(() {
        _discountError = error.toString().replaceFirst(
          'ValidationException: ',
          '',
        );
      });
      return;
    }
    setState(() {
      _appliedDiscount = discount;
      if (resetEditorValue) {
        _discountValueController.text = _displayValueForDiscount(discount);
      }
      _discountError = null;
      if (closeCustomEditor) {
        _isCustomEditorOpen = false;
      }
    });
    widget.onApplyDiscount(discount);
  }

  void _handleRemoveDiscount() {
    _discountValueController.clear();
    _discountReasonController.clear();
    setState(() {
      _appliedDiscount = null;
      _discountType = TransactionDiscountType.amount;
      _discountError = null;
      _isCustomEditorOpen = false;
    });
    widget.onRemoveDiscount();
  }

  void _toggleCustomEditor() {
    setState(() {
      _isCustomEditorOpen = !_isCustomEditorOpen;
      _discountError = null;
      if (_isCustomEditorOpen) {
        _discountType = _appliedDiscount?.type ?? _discountType;
        _discountValueController.text = _displayValueForDiscount(
          _appliedDiscount,
        );
        _discountReasonController.text = _appliedDiscount?.reason ?? '';
      }
    });
    if (_isCustomEditorOpen) {
      _focusDiscountValueField();
    }
  }

  void _handleDiscountTypeChanged(TransactionDiscountType type) {
    setState(() {
      _discountType = type;
      _discountValueController.text = _appliedDiscount?.type == type
          ? _displayValueForDiscount(_appliedDiscount)
          : '';
      _discountError = null;
    });
    _focusDiscountValueField();
  }

  String _displayValueForDiscount(TransactionDiscountInput? discount) {
    if (discount == null) {
      return '';
    }
    return discount.type == TransactionDiscountType.amount
        ? CurrencyFormatter.toEditableMajorInput(discount.valueMinor)
        : discount.valueMinor.toString();
  }

  String _formatQuickAmountLabel(int amountMinor) {
    final int wholePounds = amountMinor ~/ 100;
    if (amountMinor % 100 == 0) {
      return '£$wholePounds';
    }
    return CurrencyFormatter.fromMinor(amountMinor);
  }

  void _focusDiscountValueField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isCustomEditorOpen || !_canEditDiscount) {
        return;
      }
      _discountValueFocusNode.requestFocus();
      _discountValueController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _discountValueController.text.length,
      );
    });
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: emphasized ? 16 : 12,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
      color: emphasized ? AppColors.primary : AppColors.textPrimary,
    );
    final TextStyle valueStyle = style.copyWith(
      color: valueColor ?? style.color,
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
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _QuickDiscountButton extends StatelessWidget {
  const _QuickDiscountButton({
    required this.buttonKey,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton(
            key: buttonKey,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.textOnPrimary,
              backgroundColor: AppColors.primaryStrong,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              side: const BorderSide(
                color: AppColors.primaryDarker,
                width: 1.5,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(label),
          )
        : OutlinedButton(
            key: buttonKey,
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              side: const BorderSide(
                color: AppColors.borderStrong,
                width: 1.25,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(label),
          );
  }
}

class _AppliedDiscountRow extends StatelessWidget {
  const _AppliedDiscountRow({required this.amountLabel, this.onRemove});

  final String amountLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('checkout-applied-discount-row'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          const Text(
            key: Key('checkout-applied-discount-label'),
            'Discount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            key: const Key('checkout-applied-discount-amount'),
            amountLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.dangerStrong,
            ),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            key: const Key('checkout-discount-remove-button'),
            onPressed: onRemove,
            style: IconButton.styleFrom(
              foregroundColor: AppColors.dangerStrong,
              backgroundColor: AppColors.dangerLight,
              disabledForegroundColor: AppColors.textMuted,
              minimumSize: const Size(28, 28),
              maximumSize: const Size(28, 28),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.close_rounded, size: 16),
            tooltip: 'Remove discount',
          ),
        ],
      ),
    );
  }
}
