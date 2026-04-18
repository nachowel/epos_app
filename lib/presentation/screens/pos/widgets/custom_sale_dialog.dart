import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/custom_sale.dart';

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
    final double dialogWidth = math.min(screenSize.width * 0.42, 520);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(
        width: dialogWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.24),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: AppColors.warningStrong,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Custom Sale',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Manual price item',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const ValueKey<String>('custom-sale-price-field'),
                  controller: _priceController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    hintText: '0.00',
                    prefixText: '£ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_showNoteField) ...<Widget>[
                  TextField(
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),
                ] else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey<String>(
                        'custom-sale-show-note-button',
                      ),
                      onPressed: () {
                        setState(() {
                          _showNoteField = true;
                          _errorMessage = null;
                        });
                      },
                      icon: const Icon(Icons.notes_rounded, size: 18),
                      label: const Text('Add note'),
                    ),
                  ),
                if (_showAdminPinField) ...<Widget>[
                  TextField(
                    key: const ValueKey<String>('custom-sale-admin-pin-field'),
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_errorMessage != null) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
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
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningStrong,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        key: const ValueKey<String>(
                          'custom-sale-submit-button',
                        ),
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warning,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: AppColors.textPrimary,
                                ),
                              )
                            : const Icon(Icons.add_rounded, size: 18),
                        label: Text(
                          widget.initialRequest == null ? 'Add' : 'Update',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
}
