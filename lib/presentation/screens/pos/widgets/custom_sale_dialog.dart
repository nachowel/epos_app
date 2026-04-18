import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/custom_sale.dart';
import '../../../widgets/app_numeric_keypad_dialog.dart';
import '../../../widgets/selective_system_keyboard_field.dart';

typedef CustomSaleValidationCallback =
    Future<void> Function(CustomSaleWriteRequest request);

class CustomSaleDialog extends StatefulWidget {
  const CustomSaleDialog({
    required this.onValidateRequest,
    this.customSalesLimitMinor,
    this.initialRequest,
    super.key,
  });

  final CustomSaleValidationCallback onValidateRequest;
  final int? customSalesLimitMinor;
  final CustomSaleWriteRequest? initialRequest;

  @override
  State<CustomSaleDialog> createState() => _CustomSaleDialogState();
}

class _CustomSaleDialogState extends State<CustomSaleDialog> {
  static const String _noteRequiredMessage =
      'Custom Sale note is required when amount exceeds the configured limit.';
  static const String _adminRequiredMessage =
      'Custom Sale admin PIN approval is required when amount exceeds the configured limit.';
  static const String _invalidPinMessage =
      'Invalid admin PIN for Custom Sale override.';

  late final TextEditingController _priceController;
  late final TextEditingController _noteController;
  late final TextEditingController _pinController;
  bool _replacePriceOnNextDigit = true;
  bool _showNoteField = false;
  bool _showAdminPinField = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final CustomSaleWriteRequest? initial = widget.initialRequest;
    _priceController = TextEditingController(
      text: initial == null
          ? ''
          : CurrencyFormatter.toEditableMajorInput(initial.amountMinor),
    );
    _noteController = TextEditingController(text: initial?.note ?? '');
    _pinController = TextEditingController(
      text: initial?.overrideRequest?.adminPin ?? '',
    );
    _showNoteField = (initial?.note?.trim().isNotEmpty ?? false);
    _showAdminPinField = initial?.overrideRequest != null;
    _priceController.addListener(_handlePriceChanged);
    _syncOverLimitExpansion(notify: false);
  }

  @override
  void dispose() {
    _priceController.removeListener(_handlePriceChanged);
    _priceController.dispose();
    _noteController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _handlePriceChanged() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
    _syncOverLimitExpansion();
  }

  void _syncOverLimitExpansion({bool notify = true}) {
    final int? customSalesLimitMinor = widget.customSalesLimitMinor;
    if (customSalesLimitMinor == null) {
      return;
    }
    final int? amountMinor = CurrencyFormatter.tryParseEditableMajorInput(
      _priceController.text,
    );
    final bool shouldRevealFullForm =
        amountMinor != null && amountMinor > customSalesLimitMinor;
    if (!shouldRevealFullForm || (_showNoteField && _showAdminPinField)) {
      return;
    }
    void applyExpansion() {
      _showNoteField = true;
      _showAdminPinField = true;
    }

    if (notify) {
      setState(applyExpansion);
      return;
    }
    applyExpansion();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final bool compactHeight = screenSize.height <= 760;
    final bool hasExpandedInputs =
        _showNoteField || _showAdminPinField || _errorMessage != null;
    final bool denseHeight = screenSize.height <= 680 || hasExpandedInputs;
    final bool ultraDenseHeight =
        screenSize.height <= 620 || _showAdminPinField || _errorMessage != null;
    final double dialogWidth = math.min(screenSize.width * 0.42, 500);
    final double dialogHeight = math.min(
      hasExpandedInputs ? 724 : 636,
      screenSize.height - 12,
    );
    final double outerPadding = ultraDenseHeight
        ? 7
        : (denseHeight ? 12 : (compactHeight ? 16 : 20));
    final double titleGap = ultraDenseHeight
        ? 5
        : (denseHeight ? 8 : (compactHeight ? 10 : 12));
    final double sectionGap = ultraDenseHeight
        ? 3
        : (denseHeight ? 8 : (compactHeight ? 12 : 14));
    final double keypadPadding = ultraDenseHeight
        ? 4
        : (denseHeight ? 6 : (compactHeight ? 8 : 10));
    final double keypadButtonHeight = ultraDenseHeight
        ? 34
        : (denseHeight ? 42 : (compactHeight ? 54 : 64));
    final double keypadSpacing = ultraDenseHeight
        ? 5
        : (denseHeight ? 6 : (compactHeight ? 8 : 10));
    final double actionMaxHeight = ultraDenseHeight
        ? 48
        : (compactHeight ? 60 : 68);
    final double actionMinHeight = ultraDenseHeight
        ? 42
        : (denseHeight ? 48 : 54);
    final double secondaryActionMaxHeight = ultraDenseHeight ? 38 : 44;
    final double secondaryActionMinHeight = ultraDenseHeight ? 34 : 40;
    final double actionGap = ultraDenseHeight ? 3 : (denseHeight ? 6 : 8);
    final double inlineFieldGap = ultraDenseHeight ? 3 : (denseHeight ? 6 : 8);
    final double noteActionTopGap = ultraDenseHeight
        ? 0
        : (denseHeight ? 2 : 4);
    final double inlineHorizontalPadding = ultraDenseHeight ? 10 : 12;
    final double adminPanelHorizontalPadding = ultraDenseHeight ? 10 : 12;
    final double beforeActionsGap = hasExpandedInputs
        ? (ultraDenseHeight ? 0 : 8)
        : 0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Padding(
          padding: EdgeInsets.all(outerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Custom Sale',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: titleGap),
              _buildPriceDisplay(
                compactHeight: compactHeight,
                denseHeight: denseHeight,
                ultraDenseHeight: ultraDenseHeight,
              ),
              SizedBox(height: sectionGap),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(keypadPadding),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.18),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final double availableKeypadHeight = math.max(
                            0,
                            constraints.maxHeight - (keypadSpacing * 3),
                          );
                          final double resolvedButtonHeight = math.min(
                            keypadButtonHeight,
                            availableKeypadHeight / 4,
                          );

                          return AppNumericKeypad(
                            keyPrefix: 'custom-sale-keypad',
                            buttonHeight: resolvedButtonHeight,
                            rowSpacing: keypadSpacing,
                            columnSpacing: keypadSpacing,
                            buttonElevation: ultraDenseHeight ? 1.5 : 2.5,
                            pressedElevation: 0.5,
                            buttonBackgroundColor: AppColors.surface,
                            buttonBorderColor: AppColors.warning.withValues(
                              alpha: 0.16,
                            ),
                            buttonShadowColor: Colors.black.withValues(
                              alpha: 0.1,
                            ),
                            buttonOverlayColor: AppColors.warning.withValues(
                              alpha: 0.08,
                            ),
                            digitTextStyle: TextStyle(
                              fontSize: ultraDenseHeight
                                  ? 16
                                  : (denseHeight
                                        ? 18
                                        : (compactHeight ? 20 : 22)),
                              fontWeight: FontWeight.w900,
                            ),
                            iconSize: ultraDenseHeight
                                ? 16
                                : (denseHeight
                                      ? 18
                                      : (compactHeight ? 20 : 22)),
                            onDigit: _appendPriceDigit,
                            onDecimal: _appendPriceDecimal,
                            onBackspace: _backspacePrice,
                          );
                        },
                  ),
                ),
              ),
              if (hasExpandedInputs) SizedBox(height: sectionGap),
              if (_showNoteField) ...<Widget>[
                SelectiveSystemKeyboardTextField(
                  key: const ValueKey<String>('custom-sale-note-field'),
                  controller: _noteController,
                  textInputAction: _showAdminPinField
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onChanged: (_) {
                    if (_errorMessage != null) {
                      setState(() {
                        _errorMessage = null;
                      });
                    }
                  },
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Note',
                    hintText: 'Optional note',
                    isDense: true,
                    alignLabelWithHint: !ultraDenseHeight,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: inlineHorizontalPadding,
                      vertical: ultraDenseHeight ? 8 : (denseHeight ? 10 : 12),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                  maxLines: ultraDenseHeight ? 2 : 3,
                ),
                SizedBox(height: inlineFieldGap),
              ],
              if (_showAdminPinField) ...<Widget>[
                Container(
                  padding: EdgeInsets.fromLTRB(
                    adminPanelHorizontalPadding,
                    ultraDenseHeight ? 10 : 12,
                    adminPanelHorizontalPadding,
                    ultraDenseHeight ? 8 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Admin Approval Required',
                        style: TextStyle(
                          fontSize: ultraDenseHeight ? 11.5 : 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warningStrong,
                        ),
                      ),
                      SizedBox(height: ultraDenseHeight ? 6 : 8),
                      TextField(
                        key: const ValueKey<String>(
                          'custom-sale-admin-pin-field',
                        ),
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() {
                              _errorMessage = null;
                            });
                          }
                        },
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Admin PIN',
                          filled: true,
                          fillColor: AppColors.surface,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: inlineHorizontalPadding,
                            vertical: ultraDenseHeight
                                ? 8
                                : (denseHeight ? 10 : 12),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusMd,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: inlineFieldGap),
              ],
              if (_errorMessage != null) ...<Widget>[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: ultraDenseHeight ? 6 : (denseHeight ? 8 : 10),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.24),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: ultraDenseHeight ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warningStrong,
                    ),
                  ),
                ),
              ],
              if (hasExpandedInputs) SizedBox(height: beforeActionsGap),
              if (!_showNoteField) ...<Widget>[
                SizedBox(height: noteActionTopGap),
                Center(
                  child: TextButton(
                    key: const ValueKey<String>('custom-sale-show-note-button'),
                    onPressed: () {
                      setState(() {
                        _showNoteField = true;
                        _errorMessage = null;
                      });
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      textStyle: TextStyle(
                        fontSize: ultraDenseHeight
                            ? 11
                            : (denseHeight ? 11.5 : 12.5),
                        fontWeight: FontWeight.w700,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: ultraDenseHeight ? 1 : (denseHeight ? 2 : 4),
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('+ Add note'),
                  ),
                ),
                SizedBox(height: actionGap),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: actionMinHeight,
                  maxHeight: actionMaxHeight,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const ValueKey<String>('custom-sale-submit-button'),
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: AppColors.textPrimary,
                      textStyle: TextStyle(
                        fontSize: ultraDenseHeight
                            ? 17
                            : (denseHeight ? 18 : (compactHeight ? 20 : 22)),
                        fontWeight: FontWeight.w900,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Icon(Icons.add_rounded, size: 20),
                    label: Text(
                      widget.initialRequest == null ? 'Add' : 'Update',
                    ),
                  ),
                ),
              ),
              SizedBox(height: actionGap),
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: secondaryActionMinHeight,
                  maxHeight: secondaryActionMaxHeight,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const ValueKey<String>('custom-sale-cancel-button'),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      backgroundColor: AppColors.surface,
                      textStyle: TextStyle(
                        fontSize: ultraDenseHeight
                            ? 11.5
                            : (denseHeight ? 12 : 13),
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: AppColors.textSecondary.withValues(alpha: 0.22),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: ultraDenseHeight ? 6 : 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceDisplay({
    required bool compactHeight,
    required bool denseHeight,
    required bool ultraDenseHeight,
  }) {
    final String formattedPrice = _formattedPricePreview();
    return Container(
      key: const ValueKey<String>('custom-sale-price-field'),
      padding: EdgeInsets.symmetric(
        horizontal: ultraDenseHeight
            ? 10
            : (denseHeight ? 12 : (compactHeight ? 12 : 16)),
        vertical: ultraDenseHeight
            ? 10
            : (denseHeight ? 12 : (compactHeight ? 16 : 18)),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.24),
          width: 1.4,
        ),
      ),
      child: Column(
        children: <Widget>[
          const Text(
            'Price',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(
            height: ultraDenseHeight
                ? 3
                : (denseHeight ? 4 : (compactHeight ? 6 : 8)),
          ),
          Text(
            formattedPrice,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: ultraDenseHeight
                  ? 28
                  : (denseHeight ? 32 : (compactHeight ? 40 : 46)),
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formattedPricePreview() {
    final int? amountMinor = CurrencyFormatter.tryParseEditableMajorInput(
      _priceController.text,
    );
    if (amountMinor == null) {
      return CurrencyFormatter.fromMinor(0);
    }
    return CurrencyFormatter.fromMinor(amountMinor);
  }

  Future<void> _submit() async {
    final int? amountMinor = CurrencyFormatter.tryParseEditableMajorInput(
      _priceController.text,
    );
    if (amountMinor == null) {
      setState(() {
        _errorMessage = 'Enter a valid price.';
      });
      return;
    }

    final CustomSaleWriteRequest request = CustomSaleWriteRequest(
      amountMinor: amountMinor,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text,
      overrideRequest: _pinController.text.trim().isEmpty
          ? null
          : CustomSaleOverrideRequest(adminPin: _pinController.text.trim()),
    );

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.onValidateRequest(request);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(request);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (error is ValidationException &&
            error.message == _noteRequiredMessage) {
          _showNoteField = true;
        }
        if (error is ValidationException &&
                error.message == _adminRequiredMessage ||
            error is UnauthorisedException &&
                error.message == _invalidPinMessage) {
          _showNoteField = true;
          _showAdminPinField = true;
        }
        _errorMessage = error is AppException
            ? error.message
            : ErrorMapper.toUserMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _appendPriceDigit(String digit) {
    final AppNumericEditResult result = AppNumericInputLogic.appendDigit(
      currentValue: _priceController.text,
      digit: digit,
      replaceOnNextDigit: _replacePriceOnNextDigit,
      options: const AppNumericValueOptions(currencyMode: true),
    );
    _setPriceText(result.value, replaceOnNextDigit: result.replaceOnNextDigit);
  }

  void _appendPriceDecimal() {
    final AppNumericEditResult result = AppNumericInputLogic.appendDecimal(
      currentValue: _priceController.text,
      replaceOnNextDigit: _replacePriceOnNextDigit,
      options: const AppNumericValueOptions(currencyMode: true),
    );
    _setPriceText(result.value, replaceOnNextDigit: result.replaceOnNextDigit);
  }

  void _backspacePrice() {
    final AppNumericEditResult result = AppNumericInputLogic.backspace(
      currentValue: _priceController.text,
      replaceOnNextDigit: _replacePriceOnNextDigit,
      emptyValue: '0',
    );
    _setPriceText(result.value, replaceOnNextDigit: result.replaceOnNextDigit);
  }

  void _setPriceText(String value, {required bool replaceOnNextDigit}) {
    _priceController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() {
      _replacePriceOnNextDigit = replaceOnNextDigit;
      _errorMessage = null;
    });
  }
}
