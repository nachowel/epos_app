import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';

class CountedCashDialog extends StatefulWidget {
  const CountedCashDialog({
    required this.expectedCashMinor,
    this.closeActionLabel,
    this.confirmActionLabel,
    super.key,
  });

  final int expectedCashMinor;
  final String? closeActionLabel;
  final String? confirmActionLabel;

  @override
  State<CountedCashDialog> createState() => _CountedCashDialogState();
}

class _CountedCashDialogState extends State<CountedCashDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int countedCashMinor = _parseMinorAmount(_controller.text);
    final int varianceMinor = countedCashMinor - widget.expectedCashMinor;
    final bool hasVariance = varianceMinor != 0;

    return AlertDialog(
      title: Text(AppStrings.finalCloseCashDialogTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${AppStrings.expectedCash}: ${CurrencyFormatter.fromMinor(widget.expectedCashMinor)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.countedCash,
                hintText: AppStrings.countedCashHint,
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _errorText = null),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            Text(
              '${AppStrings.variance}: ${CurrencyFormatter.fromMinor(varianceMinor)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: hasVariance ? Colors.orange.shade700 : null,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.closeActionLabel ?? AppStrings.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            final String rawValue = _controller.text.trim();
            if (rawValue.isEmpty) {
              setState(() => _errorText = AppStrings.countedCashRequired);
              return;
            }
            if (int.tryParse(rawValue) == null) {
              setState(() => _errorText = AppStrings.countedCashInvalid);
              return;
            }
            final int countedCashMinor = int.parse(rawValue);
            if (countedCashMinor < 0) {
              setState(() => _errorText = AppStrings.countedCashInvalid);
              return;
            }
            Navigator.of(context).pop(countedCashMinor);
          },
          child: Text(widget.confirmActionLabel ?? AppStrings.adminFinalClose),
        ),
      ],
    );
  }

  int _parseMinorAmount(String value) {
    final int? parsed = int.tryParse(value.trim());
    return parsed == null || parsed < 0 ? 0 : parsed;
  }
}
