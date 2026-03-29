import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/report_category_display_formatter.dart';
import '../../../../domain/models/cashier_projected_category_line.dart';
import '../../../../domain/models/cashier_projected_report.dart';

class CashierZReportDialog extends StatelessWidget {
  const CashierZReportDialog({
    required this.report,
    this.canConfirm = true,
    this.canPrint = false,
    this.isPrintLoading = false,
    this.onPrint,
    super.key,
  });

  final CashierProjectedReport report;
  final bool canConfirm;
  final bool canPrint;
  final bool isPrintLoading;
  final Future<void> Function()? onPrint;

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
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 820),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.spacingLg,
                AppSizes.spacingLg,
                AppSizes.spacingLg,
                AppSizes.spacingMd,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      AppStrings.zReport,
                      style: const TextStyle(
                        fontSize: AppSizes.fontLg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.spacingLg),
                child: Center(
                  child: Container(
                    width: 460,
                    padding: const EdgeInsets.all(AppSizes.spacingLg),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFCF5),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            AppStrings.zReport.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (_hasValue(report.businessName))
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSizes.spacingMd,
                              ),
                              child: Text(
                                report.businessName!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (_hasValue(report.businessAddress))
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSizes.spacingXs,
                              ),
                              child: Text(
                                report.businessAddress!,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          const SizedBox(height: AppSizes.spacingMd),
                          const _ReceiptDivider(),
                          _IdentityRow(
                            label: AppStrings.reportDate,
                            value: DateFormatter.formatDate(generatedAt),
                          ),
                          _IdentityRow(
                            label: AppStrings.reportTime,
                            value: DateFormatter.formatTime(generatedAt),
                          ),
                          if (report.shiftId != null)
                            _IdentityRow(
                              label: AppStrings.shiftNumber,
                              value: '${report.shiftId}',
                            ),
                          if (_hasValue(report.operatorName))
                            _IdentityRow(
                              label: AppStrings.operatorLabel,
                              value: report.operatorName!,
                            ),
                          const SizedBox(height: AppSizes.spacingSm),
                          const _ReceiptDivider(),
                          _SectionHeader(title: AppStrings.salesSummary),
                          _MoneyRow(
                            label: AppStrings.grossSales,
                            amountMinor: report.visibleGrossSalesMinor,
                          ),
                          _MoneyRow(
                            label: AppStrings.refundTotal,
                            amountMinor: report.visibleRefundTotalMinor,
                          ),
                          _MoneyRow(
                            label: AppStrings.netSales,
                            amountMinor: report.visibleNetSalesMinor,
                          ),
                          _TextRow(
                            label: AppStrings.openOrdersTitle,
                            value:
                                '${report.openOrdersCount} / ${CurrencyFormatter.fromMinor(report.visibleOpenOrdersTotalMinor)}',
                          ),
                          if (report.cancelledOrdersCount > 0)
                            _TextRow(
                              label: AppStrings.cancelledOrders,
                              value: '${report.cancelledOrdersCount}',
                            ),
                          const SizedBox(height: AppSizes.spacingSm),
                          const _ReceiptDivider(),
                          _SectionHeader(title: AppStrings.paymentBreakdown),
                          _MoneyRow(
                            label: AppStrings.grossCash,
                            amountMinor: report.visibleGrossCashMinor,
                          ),
                          _MoneyRow(
                            label: AppStrings.netCash,
                            amountMinor: report.visibleNetCashMinor,
                          ),
                          _MoneyRow(
                            label: AppStrings.grossCard,
                            amountMinor: report.visibleGrossCardMinor,
                          ),
                          _MoneyRow(
                            label: AppStrings.netCard,
                            amountMinor: report.visibleNetCardMinor,
                          ),
                          _TextRow(
                            label: AppStrings.totalOrders,
                            value: '${report.totalOrdersCount}',
                            emphasize: true,
                          ),
                          _MoneyRow(
                            label: AppStrings.totalAmount,
                            amountMinor: report.visibleTotalMinor,
                            emphasize: true,
                          ),
                          if (report.categoryBreakdown.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSizes.spacingSm),
                            const _ReceiptDivider(),
                            _SectionHeader(title: AppStrings.categoryBreakdown),
                            for (
                              int index = 0;
                              index < report.categoryBreakdown.length;
                              index += 1
                            )
                              _CategoryRow(
                                line: report.categoryBreakdown[index],
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSizes.spacingLg),
              child: Row(
                children: <Widget>[
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    key: const Key('cashier-z-report-close'),
                    child: Text(AppStrings.close),
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  OutlinedButton(
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
                        : Text(AppStrings.print),
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  ElevatedButton(
                    key: const Key('cashier-z-report-confirm'),
                    onPressed: canConfirm
                        ? () => Navigator.of(context).pop(true)
                        : null,
                    child: Text(AppStrings.confirmZReportAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.spacingXs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: AppSizes.spacingMd),
          Text(value, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amountMinor,
    this.emphasize = false,
  });

  final String label;
  final int amountMinor;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return _TextRow(
      label: label,
      value: CurrencyFormatter.fromMinor(amountMinor),
      emphasize: emphasize,
    );
  }
}

class _TextRow extends StatelessWidget {
  const _TextRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingXs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: AppSizes.spacingMd),
          Text(value, style: style, textAlign: TextAlign.right),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.line});

  final CashierProjectedCategoryLine line;

  @override
  Widget build(BuildContext context) {
    return _MoneyRow(
      label: ReportCategoryDisplayFormatter.toEnglish(line.categoryName),
      amountMinor: line.visibleAmountMinor,
    );
  }
}

class _ReceiptDivider extends StatelessWidget {
  const _ReceiptDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSizes.spacingSm),
      child: Divider(color: AppColors.textSecondary, thickness: 1, height: 1),
    );
  }
}
