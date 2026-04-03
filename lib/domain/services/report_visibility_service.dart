import '../models/shift_report.dart';
import '../models/user.dart';
import '../models/semantic_sales_analytics.dart';

class ReportVisibilityService {
  const ReportVisibilityService();

  int applyVisibilityRatio(int amountMinor, double ratio) {
    return _maskAmount(amountMinor, _normalizedRatio(ratio));
  }

  int visibleAmountForUser({
    required int amountMinor,
    required User user,
    required double ratio,
  }) {
    if (user.role == UserRole.admin) {
      return amountMinor;
    }
    return applyVisibilityRatio(amountMinor, ratio);
  }

  ShiftReport applyVisibilityToReport(
    ShiftReport raw,
    User user,
    double ratio,
  ) {
    if (user.role == UserRole.admin) {
      return raw;
    }

    final double safeRatio = _normalizedRatio(ratio);
    final int effectiveNetSalesMinor =
        raw.netSalesMinor == 0 && raw.refundCount == 0
        ? raw.paidTotalMinor
        : raw.netSalesMinor;
    final int effectiveCashGrossTotalMinor =
        raw.cashGrossTotalMinor == 0 && raw.refundCount == 0
        ? raw.cashTotalMinor
        : raw.cashGrossTotalMinor;
    final int effectiveCardGrossTotalMinor =
        raw.cardGrossTotalMinor == 0 && raw.refundCount == 0
        ? raw.cardTotalMinor
        : raw.cardGrossTotalMinor;
    final int visiblePaidTotalMinor = _maskAmount(
      raw.paidTotalMinor,
      safeRatio,
    );
    final int visibleRefundTotalMinor = _maskAmount(
      raw.refundTotalMinor,
      safeRatio,
    );
    final int visibleNetSalesMinor = _maskAmount(
      effectiveNetSalesMinor,
      safeRatio,
    );
    final int visibleOpenTotalMinor = _maskAmount(
      raw.openTotalMinor,
      safeRatio,
    );
    final int visibleCashGrossTotalMinor = _maskAmount(
      effectiveCashGrossTotalMinor,
      safeRatio,
    );
    final int visibleCashTotalMinor = _maskAmount(
      raw.cashTotalMinor,
      safeRatio,
    );
    final int visibleCardGrossTotalMinor = _maskAmount(
      effectiveCardGrossTotalMinor,
      safeRatio,
    );
    final int visibleCardTotalMinor = _allocateRemainingTotal(
      maskedParentTotal: visibleNetSalesMinor,
      firstChildMaskedTotal: visibleCashTotalMinor,
    );

    return raw.copyWith(
      paidTotalMinor: visiblePaidTotalMinor,
      refundTotalMinor: visibleRefundTotalMinor,
      netSalesMinor: visibleNetSalesMinor,
      openTotalMinor: visibleOpenTotalMinor,
      cashGrossTotalMinor: visibleCashGrossTotalMinor,
      cashTotalMinor: visibleCashTotalMinor,
      cardGrossTotalMinor: visibleCardGrossTotalMinor,
      cardTotalMinor: visibleCardTotalMinor,
      semanticSalesAnalytics: const SemanticSalesAnalytics.empty(),
    );
  }

  double _normalizedRatio(double ratio) {
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  int _maskAmount(int amountMinor, double ratio) {
    return (amountMinor * ratio).round();
  }

  int _allocateRemainingTotal({
    required int maskedParentTotal,
    required int firstChildMaskedTotal,
  }) {
    final int remainder = maskedParentTotal - firstChildMaskedTotal;
    return remainder < 0 ? 0 : remainder;
  }
}
