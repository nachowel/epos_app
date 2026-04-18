import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/payment.dart';
import '../../../../domain/models/transaction.dart';
import '../../../../domain/models/transaction_discount.dart';
import '../../../widgets/app_numeric_keypad_dialog.dart';

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
    final bool compactHeight = screenSize.height <= 760;
    final bool extraCompact = compactHeight && _isCustomEditorOpen;
    final bool wideSheet = screenSize.width >= 980;
    final double sheetHeight = screenSize.height - 12;
    final double sheetWidth = math.min(
      wideSheet ? 608.0 : 576.0,
      screenSize.width * (wideSheet ? 0.54 : 0.58),
    );
    final double sectionGap = extraCompact ? 4 : (compactHeight ? 6 : 10);
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
            height: sheetHeight,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.borderStrong.withValues(alpha: 0.72),
                width: 1.5,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.14),
                  blurRadius: 36,
                  offset: const Offset(-8, 20),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                extraCompact ? 8 : (compactHeight ? 12 : 14),
                extraCompact ? 8 : (compactHeight ? 12 : 14),
                extraCompact ? 8 : (compactHeight ? 12 : 14),
                extraCompact ? 6 : (compactHeight ? 10 : 12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildHeader(totalLabel, compactHeight: compactHeight),
                  SizedBox(height: sectionGap),
                  _buildPaymentSection(compactHeight: compactHeight),
                  SizedBox(height: sectionGap),
                  _buildDiscountSection(
                    discountComputation,
                    editedDiscount,
                    compactHeight: compactHeight,
                  ),
                  SizedBox(height: sectionGap),
                  _buildSummarySection(
                    discountComputation,
                    editedDiscount,
                    totalLabel,
                    compactHeight: compactHeight,
                  ),
                  const Spacer(),
                  _buildActionSection(totalLabel, compactHeight: compactHeight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSection({required bool compactHeight}) {
    final bool extraCompact = compactHeight && _isCustomEditorOpen;
    return _CheckoutSectionCard(
      title: AppStrings.paymentTitle,
      compact: compactHeight,
      padding: EdgeInsets.all(extraCompact ? 6 : (compactHeight ? 10 : 12)),
      headerBottomSpacing: extraCompact ? 3 : (compactHeight ? 6 : 10),
      child: Container(
        padding: EdgeInsets.all(extraCompact ? 2 : (compactHeight ? 4 : 6)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.borderStrong.withValues(alpha: 0.72),
            width: 1.1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _PaymentMethodButton(
                label: AppStrings.cash,
                icon: Icons.payments_rounded,
                selected: _paymentMethod == PaymentMethod.cash,
                enabled: !_isActionLocked,
                compact: compactHeight,
                onPressed: () {
                  setState(() {
                    _paymentMethod = PaymentMethod.cash;
                  });
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _PaymentMethodButton(
                label: AppStrings.card,
                icon: Icons.credit_card_rounded,
                selected: _paymentMethod == PaymentMethod.card,
                enabled: !_isActionLocked,
                compact: compactHeight,
                onPressed: () {
                  setState(() {
                    _paymentMethod = PaymentMethod.card;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String totalLabel, {required bool compactHeight}) {
    final bool extraCompact = compactHeight && _isCustomEditorOpen;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: extraCompact ? 8 : (compactHeight ? 12 : 14),
        vertical: extraCompact ? 6 : (compactHeight ? 10 : 12),
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: extraCompact ? 28 : (compactHeight ? 34 : 38),
            height: extraCompact ? 28 : (compactHeight ? 34 : 38),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.receipt_long_rounded,
              color: AppColors.primaryStrong.withValues(alpha: 0.9),
              size: extraCompact ? 16 : (compactHeight ? 19 : 21),
            ),
          ),
          SizedBox(width: extraCompact ? 8 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  AppStrings.checkout,
                  style: TextStyle(
                    fontSize: extraCompact ? 15 : (compactHeight ? 17 : 19),
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                SizedBox(height: extraCompact ? 1 : 4),
                Text(
                  'TOTAL DUE',
                  style: TextStyle(
                    fontSize: extraCompact ? 8 : (compactHeight ? 10 : 11),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: extraCompact ? 10 : (compactHeight ? 11 : 13),
              vertical: extraCompact ? 6 : (compactHeight ? 8 : 10),
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: Text(
              totalLabel,
              style: TextStyle(
                fontSize: extraCompact ? 18 : (compactHeight ? 21 : 24),
                fontWeight: FontWeight.w900,
                color: AppColors.primaryStrong,
                height: 1,
              ),
            ),
          ),
          SizedBox(width: extraCompact ? 4 : 6),
          IconButton(
            onPressed: _isActionLocked
                ? null
                : () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, size: extraCompact ? 18 : 20),
            color: AppColors.textSecondary,
            splashRadius: 20,
            constraints: BoxConstraints(
              minWidth: extraCompact ? 28 : 36,
              minHeight: extraCompact ? 28 : 36,
            ),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(backgroundColor: AppColors.surface),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSection(
    TransactionDiscountComputation discountComputation,
    TransactionDiscountInput? editedDiscount, {
    required bool compactHeight,
  }) {
    final bool extraCompact = compactHeight && _isCustomEditorOpen;
    final Widget presetsBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: extraCompact ? 5 : (compactHeight ? 6 : 8),
          runSpacing: extraCompact ? 5 : (compactHeight ? 6 : 8),
          children: <Widget>[
            ..._quickAmountPresetsMinor.map(
              (int amountMinor) => _QuickDiscountButton(
                buttonKey: ValueKey<String>(
                  'checkout-discount-preset-amount-$amountMinor',
                ),
                label: _formatQuickAmountLabel(amountMinor),
                selected:
                    editedDiscount?.type == TransactionDiscountType.amount &&
                    editedDiscount?.valueMinor == amountMinor,
                compact: compactHeight,
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
                    editedDiscount?.type == TransactionDiscountType.percent &&
                    editedDiscount?.valueMinor == percent,
                compact: compactHeight,
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
        if (editedDiscount != null) ...<Widget>[
          SizedBox(height: extraCompact ? 5 : (compactHeight ? 6 : 8)),
          _AppliedDiscountRow(
            amountLabel:
                '-${CurrencyFormatter.fromMinor(discountComputation.discountAmountMinor)}',
            onRemove: _canEditDiscount ? _handleRemoveDiscount : null,
            compact: compactHeight || extraCompact,
          ),
        ],
        SizedBox(height: extraCompact ? 5 : (compactHeight ? 6 : 8)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('checkout-custom-discount-toggle'),
            onPressed: _canEditDiscount ? _toggleCustomEditor : null,
            icon: Icon(
              _isCustomEditorOpen
                  ? Icons.expand_less_rounded
                  : Icons.tune_rounded,
              size: 18,
            ),
            label: const Text(
              'Custom Discount',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _isCustomEditorOpen
                  ? AppColors.primaryStrong
                  : AppColors.textSecondary,
              minimumSize: Size.fromHeight(
                extraCompact ? 38 : (compactHeight ? 40 : 44),
              ),
              side: BorderSide(
                color: _isCustomEditorOpen
                    ? AppColors.primaryStrong
                    : AppColors.borderStrong.withValues(alpha: 0.72),
                width: _isCustomEditorOpen ? 1.4 : 1.0,
              ),
              backgroundColor: _isCustomEditorOpen
                  ? AppColors.primaryLighter
                  : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.symmetric(horizontal: extraCompact ? 10 : 12),
            ),
          ),
        ),
      ],
    );

    return _CheckoutSectionCard(
      title: 'Discount',
      compact: compactHeight,
      padding: EdgeInsets.all(extraCompact ? 7 : (compactHeight ? 10 : 12)),
      headerBottomSpacing: extraCompact ? 4 : (compactHeight ? 7 : 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          presetsBlock,
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _isCustomEditorOpen
                ? Padding(
                    padding: EdgeInsets.only(
                      top: extraCompact ? 6 : (compactHeight ? 8 : 9),
                    ),
                    child: _buildCustomDiscountEditor(
                      compactHeight: compactHeight,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDiscountEditor({required bool compactHeight}) {
    final bool extraCompact = compactHeight && _isCustomEditorOpen;
    return Container(
      padding: EdgeInsets.all(extraCompact ? 8 : (compactHeight ? 12 : 14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: extraCompact ? 34 : (compactHeight ? 42 : 46),
            child: SegmentedButton<TransactionDiscountType>(
              selected: <TransactionDiscountType>{_discountType},
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return AppColors.surface;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.textOnPrimary;
                  }
                  return AppColors.textPrimary;
                }),
                side: const WidgetStatePropertyAll<BorderSide>(
                  BorderSide(color: AppColors.borderStrong),
                ),
                textStyle: WidgetStatePropertyAll<TextStyle>(
                  TextStyle(
                    fontSize: extraCompact ? 12 : 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              segments: const <ButtonSegment<TransactionDiscountType>>[
                ButtonSegment<TransactionDiscountType>(
                  value: TransactionDiscountType.amount,
                  label: Text('Amount'),
                ),
                ButtonSegment<TransactionDiscountType>(
                  value: TransactionDiscountType.percent,
                  label: Text('Percent'),
                ),
              ],
              onSelectionChanged: _canEditDiscount
                  ? (Set<TransactionDiscountType> selection) {
                      if (selection.isEmpty) {
                        return;
                      }
                      _handleDiscountTypeChanged(selection.first);
                    }
                  : null,
            ),
          ),
          SizedBox(height: extraCompact ? 4 : 8),
          TextField(
            key: const Key('checkout-discount-value-field'),
            controller: _discountValueController,
            focusNode: _discountValueFocusNode,
            autofocus: true,
            enabled: _canEditDiscount,
            readOnly: true,
            showCursor: false,
            enableInteractiveSelection: false,
            keyboardType: TextInputType.none,
            decoration: InputDecoration(
              isDense: extraCompact,
              labelText: _discountType == TransactionDiscountType.amount
                  ? 'Value (£)'
                  : 'Value (%)',
              errorText: _discountError,
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: EdgeInsets.symmetric(
                horizontal: extraCompact ? 10 : 14,
                vertical: extraCompact ? 8 : 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.primaryStrong,
                  width: 1.5,
                ),
              ),
            ),
            onTap: _openDiscountValueKeypad,
          ),
          SizedBox(height: extraCompact ? 4 : 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: TextField(
                  key: const Key('checkout-discount-reason-field'),
                  controller: _discountReasonController,
                  enabled: _canEditDiscount,
                  decoration: InputDecoration(
                    isDense: extraCompact,
                    labelText: 'Reason',
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: extraCompact ? 10 : 14,
                      vertical: extraCompact ? 8 : 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.borderStrong,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.borderStrong,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primaryStrong,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _handleApplyDiscount(),
                ),
              ),
              SizedBox(width: extraCompact ? 4 : 8),
              SizedBox(
                width: extraCompact ? 76 : (compactHeight ? 92 : 104),
                height: extraCompact ? 36 : (compactHeight ? 46 : 50),
                child: FilledButton(
                  key: const Key('checkout-discount-apply-button'),
                  onPressed: _canEditDiscount ? _handleApplyDiscount : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryStrong,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: TextStyle(
                      fontSize: extraCompact ? 13 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(
    TransactionDiscountComputation discountComputation,
    TransactionDiscountInput? editedDiscount,
    String totalLabel, {
    required bool compactHeight,
  }) {
    final bool extraCompact = compactHeight && _isCustomEditorOpen;
    return _CheckoutSectionCard(
      title: '',
      showHeader: false,
      compact: compactHeight,
      padding: EdgeInsets.all(extraCompact ? 8 : (compactHeight ? 14 : 18)),
      child: Column(
        children: <Widget>[
          _SummaryRow(
            label: AppStrings.subtotal,
            value: CurrencyFormatter.fromMinor(widget.subtotalMinor),
            compact: compactHeight || extraCompact,
          ),
          SizedBox(height: extraCompact ? 3 : (compactHeight ? 6 : 8)),
          _SummaryRow(
            label: AppStrings.modifierTotal,
            value: CurrencyFormatter.fromMinor(widget.modifierTotalMinor),
            compact: compactHeight || extraCompact,
          ),
          if (editedDiscount != null) ...<Widget>[
            SizedBox(height: extraCompact ? 3 : (compactHeight ? 6 : 8)),
            _SummaryRow(
              label: 'Discount',
              value:
                  '-${CurrencyFormatter.fromMinor(discountComputation.discountAmountMinor)}',
              valueColor: AppColors.dangerStrong,
              compact: compactHeight || extraCompact,
            ),
          ],
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: extraCompact ? 4 : (compactHeight ? 8 : 12),
            ),
            child: Divider(
              height: 1,
              color: AppColors.primary.withValues(alpha: 0.22),
            ),
          ),
          _SummaryRow(
            label: AppStrings.total,
            value: totalLabel,
            emphasized: true,
            compact: compactHeight || extraCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildActionSection(String totalLabel, {required bool compactHeight}) {
    final bool extraCompact = compactHeight && _isCustomEditorOpen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: extraCompact ? 60 : (compactHeight ? 80 : 90),
          child: ElevatedButton(
            key: const Key('checkout-pay-button'),
            onPressed: widget.canPayNow && !_isActionLocked ? _handlePay : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStrong,
              foregroundColor: AppColors.textOnPrimary,
              disabledBackgroundColor: AppColors.borderStrong,
              disabledForegroundColor: AppColors.textOnPrimary.withValues(
                alpha: 0.72,
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              padding: EdgeInsets.symmetric(horizontal: extraCompact ? 12 : 18),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.surface,
                    ),
                  )
                : Row(
                    children: <Widget>[
                      const Spacer(),
                      Container(
                        width: extraCompact ? 34 : (compactHeight ? 44 : 48),
                        height: extraCompact ? 34 : (compactHeight ? 44 : 48),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _paymentMethod == PaymentMethod.cash
                              ? Icons.payments_rounded
                              : Icons.credit_card_rounded,
                          size: extraCompact ? 18 : (compactHeight ? 22 : 24),
                        ),
                      ),
                      SizedBox(width: extraCompact ? 10 : 16),
                      Flexible(
                        flex: 6,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${AppStrings.payAction} $totalLabel',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: extraCompact
                                  ? 18
                                  : (compactHeight ? 22 : 25),
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
          ),
        ),
        SizedBox(height: extraCompact ? 6 : (compactHeight ? 12 : 16)),
        SizedBox(
          height: extraCompact ? 36 : (compactHeight ? 46 : 54),
          child: OutlinedButton.icon(
            key: const Key('checkout-open-order-button'),
            onPressed: widget.canCreateOrder && !_isActionLocked
                ? _handleCreateOrder
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(
                extraCompact ? 36 : (compactHeight ? 46 : 54),
              ),
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(
                color: AppColors.borderStrong.withValues(alpha: 0.78),
                width: 1.3,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: AppColors.surface,
              padding: EdgeInsets.symmetric(horizontal: extraCompact ? 10 : 18),
            ),
            icon: Icon(
              Icons.schedule_send_rounded,
              size: extraCompact ? 15 : 18,
            ),
            label: Text(
              AppStrings.saveAsOpenOrder,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: extraCompact ? 13 : 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        SizedBox(height: extraCompact ? 4 : (compactHeight ? 10 : 14)),
        Center(
          child: TextButton(
            key: const Key('checkout-clear-button'),
            onPressed: widget.canClearCart && !_isActionLocked
                ? _handleClearCart
                : null,
            style: TextButton.styleFrom(
              minimumSize: Size(72, extraCompact ? 20 : 28),
              foregroundColor: AppColors.dangerStrong,
              overlayColor: AppColors.dangerLight.withValues(alpha: 0.28),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              textStyle: TextStyle(
                fontSize: extraCompact ? 10 : 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(AppStrings.clearCart),
          ),
        ),
      ],
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

  Future<void> _openDiscountValueKeypad() async {
    if (!_canEditDiscount) {
      return;
    }

    if (_discountType == TransactionDiscountType.amount) {
      final int? amountMinor = await AppNumericKeypadDialog.showCurrencyMinor(
        context,
        title: 'Enter discount amount',
        previewLabel: 'Discount amount',
        initialMinor: CurrencyFormatter.tryParseEditableMajorInput(
          _discountValueController.text,
        ),
        prefixText: '£ ',
        emptyPreview: '0.00',
        confirmButtonLabel: 'Apply',
        restoreFocusNode: _discountValueFocusNode,
      );
      if (!mounted || amountMinor == null) {
        return;
      }
      _setDiscountValueText(
        CurrencyFormatter.toEditableMajorInput(amountMinor),
      );
      return;
    }

    final String? percentValue =
        await AppNumericKeypadDialog.showNormalizedText(
          context,
          title: 'Enter discount percent',
          previewLabel: 'Discount percent',
          initialValue: _discountValueController.text.trim(),
          emptyPreview: '0',
          confirmButtonLabel: 'Apply',
          allowDecimal: false,
          maxLength: 3,
          restoreFocusNode: _discountValueFocusNode,
        );
    if (!mounted || percentValue == null) {
      return;
    }
    _setDiscountValueText(percentValue);
  }

  void _setDiscountValueText(String value) {
    _discountValueController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {
      _discountError = null;
    });
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
    required this.compact,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool compact;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: emphasized ? (compact ? 16 : 20) : (compact ? 11 : 14),
      fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
      color: emphasized ? AppColors.primaryStrong : AppColors.textPrimary,
      height: 1.1,
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
    required this.compact,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final Size minimumSize = Size(compact ? 64 : 86, compact ? 34 : 50);
    return selected
        ? FilledButton(
            key: buttonKey,
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              foregroundColor: AppColors.textOnPrimary,
              backgroundColor: AppColors.primaryStrong,
              minimumSize: minimumSize,
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
              side: const BorderSide(
                color: AppColors.primaryDarker,
                width: 1.6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          )
        : OutlinedButton(
            key: buttonKey,
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              minimumSize: minimumSize,
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
              side: const BorderSide(
                color: AppColors.borderStrong,
                width: 1.25,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: AppColors.surface,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
  }
}

class _AppliedDiscountRow extends StatelessWidget {
  const _AppliedDiscountRow({
    required this.amountLabel,
    required this.compact,
    this.onRemove,
  });

  final String amountLabel;
  final bool compact;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('checkout-applied-discount-row'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 8 : 11,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.borderStrong.withValues(alpha: 0.82),
          width: 1.0,
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            'Discount',
            key: const Key('checkout-applied-discount-label'),
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                amountLabel,
                key: const Key('checkout-applied-discount-amount'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 14 : 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dangerStrong,
                ),
              ),
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
              minimumSize: Size(compact ? 30 : 34, compact ? 30 : 34),
              maximumSize: Size(compact ? 30 : 34, compact ? 30 : 34),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            icon: Icon(Icons.close_rounded, size: compact ? 16 : 18),
            tooltip: 'Remove discount',
          ),
        ],
      ),
    );
  }
}

enum _CheckoutSectionEmphasis { normal, strong }

class _CheckoutSectionCard extends StatelessWidget {
  const _CheckoutSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.emphasis = _CheckoutSectionEmphasis.normal,
    this.compact = false,
    this.titleStyle,
    this.headerBottomSpacing,
    this.padding,
    this.showHeader = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final _CheckoutSectionEmphasis emphasis;
  final bool compact;
  final TextStyle? titleStyle;
  final double? headerBottomSpacing;
  final EdgeInsetsGeometry? padding;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final bool strong = emphasis == _CheckoutSectionEmphasis.strong;
    return Container(
      padding: padding ?? EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: strong ? AppColors.primaryLighter : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: strong
              ? AppColors.primary.withValues(alpha: 0.22)
              : AppColors.borderStrong.withValues(alpha: 0.7),
          width: strong ? 1.3 : 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showHeader) ...<Widget>[
            Text(
              title,
              style:
                  titleStyle ??
                  TextStyle(
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.2,
                  ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            SizedBox(height: headerBottomSpacing ?? (compact ? 10 : 12)),
          ],
          child,
        ],
      ),
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  const _PaymentMethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color background = selected
        ? AppColors.primaryStrong
        : Colors.transparent;
    final Color foreground = selected
        ? AppColors.textOnPrimary
        : AppColors.textPrimary;

    return Opacity(
      opacity: enabled ? (selected ? 1 : 0.94) : 0.55,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            height: compact ? 34 : 54,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: compact ? 20 : 34,
                  height: compact ? 20 : 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: foreground, size: compact ? 13 : 19),
                ),
                SizedBox(width: compact ? 4 : 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 12 : 16,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: foreground,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
