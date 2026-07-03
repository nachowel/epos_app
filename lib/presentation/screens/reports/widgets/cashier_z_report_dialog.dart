import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../domain/models/cashier_projected_report.dart';

class CashierZReportDialog extends StatelessWidget {
  const CashierZReportDialog({
    required this.report,
    this.canPrint = false,
    this.isPrintLoading = false,
    this.onPrint,
    super.key,
  });

  final CashierProjectedReport report;
  final bool canPrint;
  final bool isPrintLoading;
  final Future<void> Function()? onPrint;

  static final NumberFormat _wholePoundFormat = NumberFormat.decimalPattern(
    'en_GB',
  );

  @override
  Widget build(BuildContext context) {
    final DateTime generatedAt = report.generatedAt ?? DateTime.now();

    return Dialog(
      key: const Key('cashier-z-report-modal'),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingLg,
        vertical: AppSizes.spacingLg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: Column(
          children: <Widget>[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
                child: DefaultTextStyle(
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Z REPORT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingMd),
                      const Text(
                        'Halfway Cafe',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingXs),
                      const Text(
                        '176 Halfway St, Sidcup DA15 8DJ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const Text(
                        '02033435303',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const _ReceiptDivider(),
                      _ReportRow(
                        label: 'Date',
                        value: DateFormatter.formatDate(generatedAt),
                      ),
                      _ReportRow(
                        label: 'Time',
                        value: DateFormatter.formatTime(generatedAt),
                      ),
                      _ReportRow(
                        label: 'Shift #',
                        value: report.shiftId?.toString() ?? '-',
                      ),
                      const SizedBox(height: AppSizes.spacingMd),
                      const _ReceiptDivider(),
                      const _SectionHeader(title: 'SUMMARY'),
                      _ReportRow(
                        label: 'Total Orders',
                        value: '${report.totalOrdersCount}',
                      ),
                      _ReportRow(
                        label: 'Refunds',
                        value: report.visibleRefundTotalMinor == 0
                            ? '0'
                            : _formatRoundedPounds(
                                report.visibleRefundTotalMinor,
                              ),
                      ),
                      _ReportRow(
                        label: 'Open Orders',
                        value: '${report.openOrdersCount}',
                      ),
                      if (report.cancelledOrdersCount > 0)
                        _ReportRow(
                          label: 'Cancelled Orders',
                          value: '${report.cancelledOrdersCount}',
                        ),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacingLg,
                          vertical: 28,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFFAF1),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusMd,
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            const Text(
                              'TOTAL SALES',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF126C2E),
                              ),
                            ),
                            const SizedBox(height: AppSizes.spacingSm),
                            Text(
                              _formatRoundedPounds(report.visibleTotalMinor),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF126C2E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      key: const Key('cashier-z-report-close'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingMd),
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('cashier-z-report-print'),
                      onPressed: !canPrint || isPrintLoading || onPrint == null
                          ? null
                          : () async {
                              await onPrint!();
                            },
                      child: isPrintLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Print'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRoundedPounds(int amountMinor) {
    final int wholePounds = amountMinor >= 0
        ? (amountMinor + 50) ~/ 100
        : -((-amountMinor + 50) ~/ 100);
    return '£${_wholePoundFormat.format(wholePounds)}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.spacingLg),
      child: Divider(color: Color(0xFFD7D2C8), thickness: 1, height: 1),
    );
  }
}
