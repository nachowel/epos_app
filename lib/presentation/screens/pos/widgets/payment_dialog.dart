import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/payment.dart';

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
    final double dialogWidth = math.min(
      screenSize.width * (_isCashMode ? 0.48 : 0.5),
      _isCashMode ? 580 : 640,
    );
    final double horizontalPadding = _isCashMode ? 18 : 24;
    final double verticalPadding = _isCashMode ? 16 : 22;
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

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: dialogWidth,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(360, screenSize.height - 32),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              verticalPadding,
              horizontalPadding,
              verticalPadding,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    AppStrings.paymentTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.fromMinor(widget.totalAmountMinor),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: _isCashMode ? 10 : 14),
                  SizedBox(
                    height: 44,
                    child: SegmentedButton<PaymentMethod>(
                      selected: <PaymentMethod>{_paymentMethod},
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll<Size>(
                          Size.fromHeight(44),
                        ),
                        textStyle: const WidgetStatePropertyAll<TextStyle>(
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.surface;
                            }
                            return AppColors.primary;
                          },
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (Set<WidgetState> states) {
                            if (states.contains(WidgetState.selected)) {
                              return AppColors.primary;
                            }
                            return AppColors.surfaceMuted;
                          },
                        ),
                        side: const WidgetStatePropertyAll<BorderSide>(
                          BorderSide(color: AppColors.border),
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
                      onSelectionChanged: (Set<PaymentMethod> selected) {
                        if (selected.isEmpty) {
                          return;
                        }
                        final PaymentMethod nextMethod = selected.first;
                        setState(() {
                          _paymentMethod = nextMethod;
                          _errorMessage = null;
                          if (nextMethod == PaymentMethod.cash) {
                            _setReceivedAmountMinor(
                              widget.totalAmountMinor,
                              replaceOnNextDigit: true,
                            );
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isCashMode) ...<Widget>[
                    Text(
                      AppStrings.receivedAmount,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      key: const ValueKey<String>(
                        'payment-received-amount-field',
                      ),
                      controller: _receivedController,
                      readOnly: true,
                      showCursor: false,
                      enableInteractiveSelection: false,
                      keyboardType: TextInputType.none,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        prefixText: '£ ',
                        prefixStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _QuickAmountButton(
                          key: const ValueKey<String>('quick-cash-exact'),
                          label: 'Exact',
                          emphasized: true,
                          onPressed: () => _setReceivedAmountMinor(
                            widget.totalAmountMinor,
                            replaceOnNextDigit: true,
                          ),
                        ),
                        for (final int amountMinor in quickCashAmountsMinor)
                          _QuickAmountButton(
                            key: ValueKey<String>('quick-cash-$amountMinor'),
                            label: _quickAmountLabel(amountMinor),
                            onPressed: () => _setReceivedAmountMinor(
                              amountMinor,
                              replaceOnNextDigit: true,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _NumericKeypad(
                      onDigit: _appendDigit,
                      onDecimal: _appendDecimalPoint,
                      onBackspace: _backspace,
                    ),
                    const SizedBox(height: 6),
                    _CashStatusBanner(
                      shortfallMinor: shortfallMinor,
                      changeMinor: changeMinor,
                    ),
                  ],
                  if (_errorMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (isInteractionBlocked) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      widget.blockedMessage ??
                          AppStrings.salesLockedAdminCloseRequired,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  SizedBox(height: _isCashMode ? 24 : 24),
                  SizedBox(
                    height: 64,
                    child: ElevatedButton(
                      key: const ValueKey<String>('payment-submit'),
                      onPressed: isPayEnabled ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusLg,
                          ),
                        ),
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.surface,
                        disabledBackgroundColor: AppColors.surfaceMuted,
                        disabledForegroundColor: AppColors.textSecondary,
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.surface,
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.6,
                                color: AppColors.surface,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  _isCashMode
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.credit_card_rounded,
                                  size: 22,
                                  color: AppColors.surface,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${AppStrings.payAction} ${CurrencyFormatter.fromMinor(widget.totalAmountMinor)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.surface,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      key: const ValueKey<String>('payment-cancel'),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textSecondary,
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusLg,
                          ),
                        ),
                      ),
                      child: Text(
                        AppStrings.cancel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
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
    return _tryParseReceivedMinor(_receivedController.text) ?? 0;
  }

  int? _tryParseReceivedMinor(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    final RegExp validPattern = RegExp(r'^\d+(\.\d{0,2})?$');
    if (!validPattern.hasMatch(trimmed)) {
      return null;
    }

    final List<String> parts = trimmed.split('.');
    final int pounds = int.parse(parts.first);
    final String pence = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    return (pounds * 100) + int.parse(pence.substring(0, 2));
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
    String current = _replaceOnNextDigit ? '' : _receivedController.text;
    if (current == '0') {
      current = '';
    }
    if (current.contains('.')) {
      final String decimals = current.split('.')[1];
      if (decimals.length >= 2) {
        return;
      }
    }

    final String nextValue = '${current.isEmpty ? '' : current}$digit';
    _setReceivedText(nextValue, replaceOnNextDigit: false);
  }

  void _appendDecimalPoint() {
    String current = _replaceOnNextDigit ? '' : _receivedController.text;
    if (current.contains('.')) {
      return;
    }
    if (current.isEmpty) {
      current = '0';
    }
    _setReceivedText('$current.', replaceOnNextDigit: false);
  }

  void _backspace() {
    if (_replaceOnNextDigit) {
      _setReceivedText('0', replaceOnNextDigit: false);
      return;
    }

    String current = _receivedController.text;
    if (current.isEmpty) {
      return;
    }
    current = current.substring(0, current.length - 1);
    if (current.endsWith('.')) {
      current = current.substring(0, current.length - 1);
    }
    if (current.isEmpty) {
      current = '0';
    }
    _setReceivedText(current, replaceOnNextDigit: false);
  }

  List<int> _buildQuickCashAmountsMinor() {
    final int firstPreset = ((widget.totalAmountMinor + 999) ~/ 1000) * 1000;
    return <int>[firstPreset, firstPreset + 1000, firstPreset + 2000]
        .where((int amountMinor) => amountMinor > widget.totalAmountMinor)
        .toList(growable: false);
  }

  String _quickAmountLabel(int amountMinor) => '£${amountMinor ~/ 100}';
}

class _CashStatusBanner extends StatelessWidget {
  const _CashStatusBanner({
    required this.shortfallMinor,
    required this.changeMinor,
  });

  final int shortfallMinor;
  final int changeMinor;

  @override
  Widget build(BuildContext context) {
    final bool isInsufficient = shortfallMinor > 0;
    final bool hasChange = changeMinor > 0;
    final Color textColor = isInsufficient
        ? AppColors.error
        : (hasChange ? AppColors.success : AppColors.textPrimary);
    final String label = isInsufficient
        ? 'Insufficient by ${CurrencyFormatter.fromMinor(shortfallMinor)}'
        : '${AppStrings.change}: ${CurrencyFormatter.fromMinor(changeMinor)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: textColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({
    required this.onDigit,
    required this.onDecimal,
    required this.onBackspace,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDecimal;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _KeypadRow(
          children: <Widget>[
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-1'),
              label: '1',
              onPressed: () => onDigit('1'),
            ),
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-2'),
              label: '2',
              onPressed: () => onDigit('2'),
            ),
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-3'),
              label: '3',
              onPressed: () => onDigit('3'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _KeypadRow(
          children: <Widget>[
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-4'),
              label: '4',
              onPressed: () => onDigit('4'),
            ),
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-5'),
              label: '5',
              onPressed: () => onDigit('5'),
            ),
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-6'),
              label: '6',
              onPressed: () => onDigit('6'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _KeypadRow(
          children: <Widget>[
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-7'),
              label: '7',
              onPressed: () => onDigit('7'),
            ),
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-8'),
              label: '8',
              onPressed: () => onDigit('8'),
            ),
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-9'),
              label: '9',
              onPressed: () => onDigit('9'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _KeypadRow(
          children: <Widget>[
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-decimal'),
              label: '.',
              onPressed: onDecimal,
            ),
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-0'),
              label: '0',
              onPressed: () => onDigit('0'),
            ),
            _KeypadButton(
              key: const ValueKey<String>('payment-keypad-backspace'),
              icon: Icons.backspace_outlined,
              onPressed: onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadRow extends StatelessWidget {
  const _KeypadRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand(
            (Widget child) => <Widget>[
              Expanded(child: child),
              if (child != children.last) const SizedBox(width: 8),
            ],
          )
          .toList(growable: false),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.onPressed,
    this.label,
    this.icon,
    super.key,
  }) : assert(label != null || icon != null);

  final VoidCallback onPressed;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surfaceMuted,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: icon == null
            ? Text(
                label!,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              )
            : Icon(icon, size: 17),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(108, 54),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          side: BorderSide(
            color: emphasized ? AppColors.primary : AppColors.border,
          ),
          backgroundColor: emphasized
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: emphasized ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
