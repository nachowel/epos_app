import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_sizes.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../domain/models/analytics/payment_split_summary.dart';
import 'analytics_kpi_card.dart';

class PaymentSplitCard extends StatelessWidget {
  const PaymentSplitCard({
    required this.summary,
    required this.onTap,
    super.key,
  });

  final PaymentSplitSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnalyticsKpiCard(
      title: 'Payment Split',
      icon: Icons.payments_rounded,
      onTap: onTap,
      accentColor: AppColors.successStrong,
      body: Column(
        children: <Widget>[
          _PaymentSplitRow(
            label: 'Cash',
            value: CurrencyFormatter.fromMinor(summary.cashRevenueMinor),
            orderCount: summary.cashOrderCount,
          ),
          const SizedBox(height: AppSizes.spacingSm),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSizes.spacingSm),
          _PaymentSplitRow(
            label: 'Card',
            value: CurrencyFormatter.fromMinor(summary.cardRevenueMinor),
            orderCount: summary.cardOrderCount,
          ),
        ],
      ),
      subtitle:
          'Total ${CurrencyFormatter.fromMinor(summary.totalRevenueMinor)}',
    );
  }
}

class _PaymentSplitRow extends StatelessWidget {
  const _PaymentSplitRow({
    required this.label,
    required this.value,
    required this.orderCount,
  });

  final String label;
  final String value;
  final int orderCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$orderCount order${orderCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
