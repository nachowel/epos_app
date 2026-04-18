import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/payment.dart';
import '../../../widgets/app_numeric_keypad_dialog.dart';

typedef PaymentSubmitCallback =
    Future<String?> Function(PaymentMethod paymentMethod);

class PaymentDialog extends StatefulWidget {
  const PaymentDialog({
    required this.totalAmountMinor,
    required this.onSubmit,
    this.isSubmissionBlocked = false,
    this.blockedMessage,
    this.initialPaymentMethod = PaymentMethod.cash,
    super.key,
  });

  final int totalAmountMinor;
  final PaymentSubmitCallback onSubmit;
  final bool isSubmissionBlocked;
  final String? blockedMessage;
  final PaymentMethod initialPaymentMethod;

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  static const AppNumericValueOptions _cashInputOptions =
      AppNumericValueOptions(currencyMode: true);

  late PaymentMethod _paymentMethod;
  bool _isSubmitting = false;
  bool _replaceOnNextDigit = true;
  String? _errorMessage;
  late final TextEditingController _receivedController;

  bool get _isCashMode => _paymentMethod == PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _paymentMethod = widget.initialPaymentMethod;
    _receivedController = TextEditingController(
      text: CurrencyFormatter.toEditableMajorInput(widget.totalAmountMinor),
    );
  }

  @override
  void dispose() {
    _receivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool isInteractionBlocked = widget.isSubmissionBlocked;
    final int receivedMinor = _receivedMinor;
    final int shortfallMinor = math.max(
      0,
      widget.totalAmountMinor - receivedMinor,
    );
    final int changeMinor = math.max(
      0,
      receivedMinor - widget.totalAmountMinor,
    );
    final bool isPayEnabled =
        !_isSubmitting &&
        !isInteractionBlocked &&
        (!_isCashMode || shortfallMinor == 0);
    final List<int> quickCashAmountsMinor = _buildQuickCashAmountsMinor();
    final bool compactDialog = screenSize.height <= 700;
    final double dialogWidth = math.min(
      screenSize.width * (_isCashMode ? 0.48 : 0.44),
      _isCashMode ? 580 : 520,
    );
    final double dialogHeight = math.min(
      _isCashMode ? (compactDialog ? 560 : 860) : (compactDialog ? 400 : 470),
      screenSize.height - 32,
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            _isCashMode ? (compactDialog ? 10 : 20) : 24,
            _isCashMode ? (compactDialog ? 10 : 18) : 24,
            _isCashMode ? (compactDialog ? 10 : 20) : 24,
            _isCashMode ? (compactDialog ? 8 : 18) : 20,
          ),
          child: _isCashMode
              ? _buildCashScreen(
                  shortfallMinor: shortfallMinor,
                  changeMinor: changeMinor,
                  isInteractionBlocked: isInteractionBlocked,
                  isPayEnabled: isPayEnabled,
                  quickCashAmountsMinor: quickCashAmountsMinor,
                  compactDialog: compactDialog,
                )
              : _buildCardScreen(
                  isInteractionBlocked: isInteractionBlocked,
                  isPayEnabled: isPayEnabled,
                  compactDialog: compactDialog,
                ),
        ),
      ),
    );
  }

  Widget _buildCardScreen({
    required bool isInteractionBlocked,
    required bool isPayEnabled,
    required bool compactDialog,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: compactDialog ? 4 : 8),
        Text(
          'Card Payment',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compactDialog ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: compactDialog ? 10 : 16),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  CurrencyFormatter.fromMinor(widget.totalAmountMinor),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compactDialog ? 44 : 56,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryStrong,
                    height: 1,
                  ),
                ),
                SizedBox(height: compactDialog ? 8 : 10),
                Icon(
                  Icons.credit_card_rounded,
                  size: compactDialog ? 28 : 34,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        _buildFeedbackMessages(isInteractionBlocked: isInteractionBlocked),
        SizedBox(
          height: compactDialog ? 64 : 76,
          child: ElevatedButton(
            key: const ValueKey<String>('payment-submit'),
            onPressed: isPayEnabled ? _submit : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              backgroundColor: AppColors.primaryStrong,
              foregroundColor: AppColors.surface,
              disabledBackgroundColor: AppColors.surfaceMuted,
              disabledForegroundColor: AppColors.textSecondary,
              textStyle: TextStyle(
                fontSize: compactDialog ? 19 : 22,
                fontWeight: FontWeight.w900,
                color: AppColors.surface,
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: AppColors.surface,
                    ),
                  )
                : Text(
                    '${AppStrings.payAction} ${CurrencyFormatter.fromMinor(widget.totalAmountMinor)}',
                  ),
          ),
        ),
        SizedBox(height: compactDialog ? 6 : 10),
        Center(
          child: TextButton(
            key: const ValueKey<String>('payment-cancel'),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(AppStrings.cancel),
          ),
        ),
      ],
    );
  }

  Widget _buildCashScreen({
    required int shortfallMinor,
    required int changeMinor,
    required bool isInteractionBlocked,
    required bool isPayEnabled,
    required List<int> quickCashAmountsMinor,
    required bool compactDialog,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          AppStrings.receivedAmount,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: compactDialog ? 12 : 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: compactDialog ? 4 : 8),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: compactDialog ? 10 : 18,
            vertical: compactDialog ? 10 : 18,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderStrong, width: 1.2),
          ),
          child: TextField(
            key: const ValueKey<String>('payment-received-amount-field'),
            controller: _receivedController,
            readOnly: true,
            showCursor: false,
            enableInteractiveSelection: false,
            keyboardType: TextInputType.none,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compactDialog ? 28 : 40,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1,
            ),
            decoration: InputDecoration(
              prefixText: '£ ',
              prefixStyle: TextStyle(
                fontSize: compactDialog ? 20 : 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        SizedBox(height: compactDialog ? 6 : 12),
        Wrap(
          spacing: compactDialog ? 6 : 10,
          runSpacing: compactDialog ? 6 : 10,
          children: <Widget>[
            _QuickAmountButton(
              key: const ValueKey<String>('quick-cash-exact'),
              label: 'Exact',
              emphasized: true,
              compact: compactDialog,
              onPressed: () => _setReceivedAmountMinor(
                widget.totalAmountMinor,
                replaceOnNextDigit: true,
              ),
            ),
            for (final int amountMinor in quickCashAmountsMinor)
              _QuickAmountButton(
                key: ValueKey<String>('quick-cash-$amountMinor'),
                label: _quickAmountLabel(amountMinor),
                compact: compactDialog,
                onPressed: () => _setReceivedAmountMinor(
                  amountMinor,
                  replaceOnNextDigit: true,
                ),
              ),
          ],
        ),
        SizedBox(height: compactDialog ? 6 : 12),
        Container(
          padding: EdgeInsets.all(compactDialog ? 6 : 12),
          decoration: BoxDecoration(
            color: AppColors.primaryLighter,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.24),
            ),
          ),
          child: AppNumericKeypad(
            keyPrefix: 'payment-keypad',
            buttonHeight: compactDialog ? 44 : 72,
            rowSpacing: compactDialog ? 6 : 10,
            columnSpacing: compactDialog ? 6 : 10,
            digitTextStyle: TextStyle(
              fontSize: compactDialog ? 16 : 22,
              fontWeight: FontWeight.w900,
            ),
            iconSize: compactDialog ? 16 : 22,
            onDigit: _appendDigit,
            onDecimal: _appendDecimal,
            onBackspace: _backspace,
          ),
        ),
        SizedBox(height: compactDialog ? 6 : 12),
        _CashStatusBanner(
          shortfallMinor: shortfallMinor,
          changeMinor: changeMinor,
          compact: compactDialog,
        ),
        _buildFeedbackMessages(isInteractionBlocked: isInteractionBlocked),
        if (!compactDialog) const Spacer() else const SizedBox(height: 6),
        SizedBox(
          height: compactDialog ? 56 : 78,
          child: ElevatedButton(
            key: const ValueKey<String>('payment-submit'),
            onPressed: isPayEnabled ? _submit : null,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              ),
              backgroundColor: AppColors.primaryStrong,
              foregroundColor: AppColors.surface,
              disabledBackgroundColor: AppColors.surfaceMuted,
              disabledForegroundColor: AppColors.textSecondary,
              textStyle: TextStyle(
                fontSize: compactDialog ? 17 : 22,
                fontWeight: FontWeight.w900,
                color: AppColors.surface,
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: AppColors.surface,
                    ),
                  )
                : Text(
                    '${AppStrings.payAction} ${CurrencyFormatter.fromMinor(widget.totalAmountMinor)}',
                  ),
          ),
        ),
        SizedBox(height: compactDialog ? 4 : 10),
        Center(
          child: TextButton(
            key: const ValueKey<String>('payment-cancel'),
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(AppStrings.cancel),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackMessages({required bool isInteractionBlocked}) {
    if (_errorMessage == null && !isInteractionBlocked) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (_errorMessage != null && isInteractionBlocked)
            const SizedBox(height: 6),
          if (isInteractionBlocked)
            Text(
              widget.blockedMessage ?? AppStrings.salesLockedAdminCloseRequired,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final String? error = await widget.onSubmit(_paymentMethod);
    if (!mounted) {
      return;
    }

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });
  }

  int get _receivedMinor {
    if (!_isCashMode) {
      return widget.totalAmountMinor;
    }
    return AppNumericInputLogic.tryParseCurrencyMinor(
          _receivedController.text,
        ) ??
        0;
  }

  void _setReceivedAmountMinor(
    int amountMinor, {
    required bool replaceOnNextDigit,
  }) {
    final String nextValue = CurrencyFormatter.toEditableMajorInput(
      amountMinor,
    );
    _receivedController.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
    setState(() {
      _replaceOnNextDigit = replaceOnNextDigit;
      _errorMessage = null;
    });
  }

  void _setReceivedText(String value, {required bool replaceOnNextDigit}) {
    _receivedController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {
      _replaceOnNextDigit = replaceOnNextDigit;
      _errorMessage = null;
    });
  }

  void _appendDigit(String digit) {
    final AppNumericEditResult result = AppNumericInputLogic.appendDigit(
      currentValue: _receivedController.text,
      digit: digit,
      replaceOnNextDigit: _replaceOnNextDigit,
      options: _cashInputOptions,
    );
    _setReceivedText(
      result.value,
      replaceOnNextDigit: result.replaceOnNextDigit,
    );
  }

  void _appendDecimal() {
    final AppNumericEditResult result = AppNumericInputLogic.appendDecimal(
      currentValue: _receivedController.text,
      replaceOnNextDigit: _replaceOnNextDigit,
      options: _cashInputOptions,
    );
    _setReceivedText(
      result.value,
      replaceOnNextDigit: result.replaceOnNextDigit,
    );
  }

  void _backspace() {
    final AppNumericEditResult result = AppNumericInputLogic.backspace(
      currentValue: _receivedController.text,
      replaceOnNextDigit: _replaceOnNextDigit,
      emptyValue: '0',
    );
    _setReceivedText(
      result.value,
      replaceOnNextDigit: result.replaceOnNextDigit,
    );
  }

  List<int> _buildQuickCashAmountsMinor() {
    return const <int>[2000, 3000, 4000];
  }

  String _quickAmountLabel(int amountMinor) => '£${amountMinor ~/ 100}';
}

class _CashStatusBanner extends StatelessWidget {
  const _CashStatusBanner({
    required this.shortfallMinor,
    required this.changeMinor,
    this.compact = false,
  });

  final int shortfallMinor;
  final int changeMinor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool isInsufficient = shortfallMinor > 0;
    final bool hasChange = changeMinor > 0;
    final Color textColor = isInsufficient
        ? AppColors.error
        : (hasChange ? AppColors.success : AppColors.textPrimary);
    final Color backgroundColor = isInsufficient
        ? AppColors.dangerLight
        : (hasChange ? AppColors.successLight : AppColors.surfaceMuted);
    final String label = isInsufficient
        ? 'Insufficient by ${CurrencyFormatter.fromMinor(shortfallMinor)}'
        : '${AppStrings.change}: ${CurrencyFormatter.fromMinor(changeMinor)}';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 10 : 16,
      ),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(
          color: hasChange ? AppColors.success : AppColors.borderStrong,
          width: hasChange ? 1.4 : 1.0,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: hasChange ? (compact ? 18 : 28) : (compact ? 14 : 20),
          color: textColor,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasized;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 82 : 122,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(compact ? 82 : 122, compact ? 40 : 58),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 16,
            vertical: compact ? 10 : 16,
          ),
          side: BorderSide(
            color: emphasized
                ? AppColors.primaryStrong
                : AppColors.borderStrong,
            width: emphasized ? 1.5 : 1.1,
          ),
          backgroundColor: emphasized
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            fontSize: compact ? 13 : 17,
            fontWeight: FontWeight.w800,
            color: emphasized ? AppColors.primaryStrong : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
