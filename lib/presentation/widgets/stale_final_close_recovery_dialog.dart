import 'package:flutter/material.dart';

import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../domain/models/stale_final_close_recovery_details.dart';

enum StaleFinalCloseRecoveryAction { resume, discardAndReenter, cancel }

class StaleFinalCloseRecoveryDialog extends StatelessWidget {
  const StaleFinalCloseRecoveryDialog({required this.recovery, super.key});

  final StaleFinalCloseRecoveryDetails recovery;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppStrings.previousFinalCloseAttemptDetected),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DetailRow(
            label: AppStrings.shiftIdLabel,
            value: '${recovery.shiftId}',
          ),
          _DetailRow(
            label: AppStrings.countedCash,
            value: CurrencyFormatter.fromMinor(recovery.countedCashMinor),
          ),
          _DetailRow(
            label: AppStrings.expectedCash,
            value: CurrencyFormatter.fromMinor(recovery.expectedCashMinor),
          ),
          _DetailRow(
            label: AppStrings.variance,
            value: CurrencyFormatter.fromMinor(recovery.varianceMinor),
          ),
          _DetailRow(
            label: AppStrings.countedAtLabel,
            value: DateFormatter.formatDefault(recovery.countedAt),
          ),
          _DetailRow(
            label: AppStrings.countedByLabel,
            value: _countedByLabel(recovery),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(StaleFinalCloseRecoveryAction.cancel),
          child: Text(AppStrings.cancel),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(StaleFinalCloseRecoveryAction.discardAndReenter),
          child: Text(AppStrings.discardAndReenterAction),
        ),
        ElevatedButton(
          onPressed: () =>
              Navigator.of(context).pop(StaleFinalCloseRecoveryAction.resume),
          child: Text(AppStrings.resumeFinalCloseAction),
        ),
      ],
    );
  }

  String _countedByLabel(StaleFinalCloseRecoveryDetails recovery) {
    final String? countedByName = recovery.countedByName?.trim();
    if (countedByName != null && countedByName.isNotEmpty) {
      return '$countedByName (#${recovery.countedByUserId})';
    }
    return '${AppStrings.unknownUser} (#${recovery.countedByUserId})';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingXs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: AppSizes.spacingSm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
