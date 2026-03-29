import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/models/draft_order_policy.dart';
import '../../domain/models/transaction.dart';

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({
    required this.status,
    this.updatedAt,
    this.compact = false,
    super.key,
  });

  final TransactionStatus status;
  final DateTime? updatedAt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ({Color color, String label}) presentation = _presentationForStatus(
      status,
      updatedAt: updatedAt,
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSizes.spacingSm : AppSizes.spacingMd,
        vertical: AppSizes.spacingXs,
      ),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        presentation.label,
        style: TextStyle(
          fontSize: AppSizes.fontSm,
          color: presentation.color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  ({Color color, String label}) _presentationForStatus(
    TransactionStatus status, {
    DateTime? updatedAt,
  }) {
    switch (status) {
      case TransactionStatus.draft:
        final bool isStaleDraft =
            updatedAt != null && DraftOrderPolicy.isUpdatedAtStale(updatedAt);
        return (
          color: isStaleDraft ? AppColors.error : AppColors.warning,
          label: isStaleDraft
              ? AppStrings.statusDraftStale
              : AppStrings.statusDraft,
        );
      case TransactionStatus.sent:
        return (color: AppColors.primary, label: AppStrings.statusSent);
      case TransactionStatus.paid:
        return (color: AppColors.success, label: AppStrings.statusPaid);
      case TransactionStatus.cancelled:
        return (color: AppColors.error, label: AppStrings.statusCancelled);
    }
  }
}
