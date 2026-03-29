import '../models/cashier_projected_category_line.dart';
import '../models/cashier_projected_report.dart';
import '../models/report_settings_policy.dart';
import '../models/shift_report.dart';
import '../models/shift_report_category_line.dart';

class CashierReportProjectionService {
  const CashierReportProjectionService();

  CashierProjectedReport project({
    required ShiftReport rawReport,
    required ReportSettingsPolicy settings,
  }) {
    final int realVisibleBaseTotal = _effectiveRealVisibleTotal(rawReport);
    final int visibleTotalMinor = _calculateVisibleTotal(
      realTotalMinor: realVisibleBaseTotal,
      settings: settings,
    );
    final int visibleRefundTotalMinor = _scaleStandaloneAmount(
      rawAmountMinor: rawReport.refundTotalMinor,
      baseTotalMinor: realVisibleBaseTotal,
      targetTotalMinor: visibleTotalMinor,
    );
    final int visibleGrossSalesMinor =
        visibleTotalMinor + visibleRefundTotalMinor;
    final int visibleOpenOrdersTotalMinor = _scaleStandaloneAmount(
      rawAmountMinor: rawReport.openTotalMinor,
      baseTotalMinor: realVisibleBaseTotal,
      targetTotalMinor: visibleTotalMinor,
    );
    final List<int> visibleGrossPaymentBreakdown = _allocateByWeights(
      targetTotalMinor: visibleGrossSalesMinor,
      weightedBuckets: <_WeightedBucket>[
        _WeightedBucket(
          key: 'cash-gross',
          weightMinor: rawReport.cashGrossTotalMinor,
        ),
        _WeightedBucket(
          key: 'card-gross',
          weightMinor: rawReport.cardGrossTotalMinor,
        ),
      ],
    );
    final List<int> visiblePaymentBreakdown = _allocateByWeights(
      targetTotalMinor: visibleTotalMinor,
      weightedBuckets: <_WeightedBucket>[
        _WeightedBucket(key: 'cash', weightMinor: rawReport.cashTotalMinor),
        _WeightedBucket(key: 'card', weightMinor: rawReport.cardTotalMinor),
      ],
    );
    final List<int> visibleCategoryTotals = _allocateByWeights(
      targetTotalMinor: visibleTotalMinor,
      weightedBuckets: rawReport.categoryBreakdown
          .map(
            (ShiftReportCategoryLine line) => _WeightedBucket(
              key: line.categoryName,
              weightMinor: line.totalMinor,
            ),
          )
          .toList(growable: false),
    );

    return CashierProjectedReport(
      hasOpenShift: true,
      shiftId: rawReport.shiftId,
      previewTaken: false,
      previewTakenAt: null,
      previewTakenByUserName: null,
      generatedAt: null,
      operatorName: null,
      businessName: null,
      businessAddress: null,
      visibleGrossSalesMinor: visibleGrossSalesMinor,
      visibleRefundTotalMinor: visibleRefundTotalMinor,
      visibleNetSalesMinor: visibleTotalMinor,
      visibleGrossCashMinor: visibleGrossPaymentBreakdown.isEmpty
          ? 0
          : visibleGrossPaymentBreakdown[0],
      visibleCashMinor: visiblePaymentBreakdown.isEmpty
          ? 0
          : visiblePaymentBreakdown[0],
      visibleGrossCardMinor: visibleGrossPaymentBreakdown.length < 2
          ? 0
          : visibleGrossPaymentBreakdown[1],
      visibleCardMinor: visiblePaymentBreakdown.length < 2
          ? 0
          : visiblePaymentBreakdown[1],
      visibleOpenOrdersTotalMinor: visibleOpenOrdersTotalMinor,
      visibleTotalMinor: visibleTotalMinor,
      totalOrdersCount: rawReport.paidCount,
      openOrdersCount: rawReport.openCount,
      cancelledOrdersCount: rawReport.cancelledCount,
      categoryBreakdown: <CashierProjectedCategoryLine>[
        for (
          int index = 0;
          index < rawReport.categoryBreakdown.length;
          index += 1
        )
          CashierProjectedCategoryLine(
            categoryName: rawReport.categoryBreakdown[index].categoryName,
            visibleAmountMinor: visibleCategoryTotals[index],
          ),
      ],
    );
  }

  int _effectiveRealVisibleTotal(ShiftReport rawReport) {
    if (rawReport.netSalesMinor == 0 && rawReport.refundTotalMinor == 0) {
      return rawReport.paidTotalMinor;
    }
    return rawReport.netSalesMinor;
  }

  int _calculateVisibleTotal({
    required int realTotalMinor,
    required ReportSettingsPolicy settings,
  }) {
    if (realTotalMinor <= 0) {
      return 0;
    }

    switch (settings.cashierReportMode) {
      case CashierReportMode.percentage:
        return _projectByRatio(
          amountMinor: realTotalMinor,
          ratio: settings.visibilityRatio,
        );
      case CashierReportMode.capAmount:
        final int capMinor = settings.maxVisibleTotalMinor ?? realTotalMinor;
        if (capMinor <= 0) {
          return 0;
        }
        return capMinor < realTotalMinor ? capMinor : realTotalMinor;
    }
  }

  int _projectByRatio({required int amountMinor, required double ratio}) {
    final double safeRatio = ratio.clamp(0.0, 1.0).toDouble();
    return (amountMinor * safeRatio).round();
  }

  int _scaleStandaloneAmount({
    required int rawAmountMinor,
    required int baseTotalMinor,
    required int targetTotalMinor,
  }) {
    if (rawAmountMinor <= 0 || baseTotalMinor <= 0 || targetTotalMinor <= 0) {
      return 0;
    }
    final double scaled = (rawAmountMinor * targetTotalMinor) / baseTotalMinor;
    final int rounded = scaled.round();
    return rounded.clamp(0, rawAmountMinor);
  }

  List<int> _allocateByWeights({
    required int targetTotalMinor,
    required List<_WeightedBucket> weightedBuckets,
  }) {
    if (weightedBuckets.isEmpty) {
      return const <int>[];
    }
    if (targetTotalMinor <= 0) {
      return List<int>.filled(weightedBuckets.length, 0);
    }

    final int totalWeight = weightedBuckets.fold<int>(
      0,
      (int sum, _WeightedBucket bucket) => sum + bucket.weightMinor,
    );
    if (totalWeight <= 0) {
      return List<int>.filled(weightedBuckets.length, 0);
    }

    final List<_AllocationSlice> slices = <_AllocationSlice>[];
    int allocatedMinor = 0;
    for (int index = 0; index < weightedBuckets.length; index += 1) {
      final _WeightedBucket bucket = weightedBuckets[index];
      final int numerator = targetTotalMinor * bucket.weightMinor;
      final int floorValue = numerator ~/ totalWeight;
      final int remainder = numerator % totalWeight;
      allocatedMinor += floorValue;
      slices.add(
        _AllocationSlice(
          index: index,
          key: bucket.key,
          amountMinor: floorValue,
          remainderNumerator: remainder,
        ),
      );
    }

    int remainingMinor = targetTotalMinor - allocatedMinor;
    slices.sort((_AllocationSlice left, _AllocationSlice right) {
      final int remainderCompare = right.remainderNumerator.compareTo(
        left.remainderNumerator,
      );
      if (remainderCompare != 0) {
        return remainderCompare;
      }
      final int keyCompare = left.key.compareTo(right.key);
      if (keyCompare != 0) {
        return keyCompare;
      }
      return left.index.compareTo(right.index);
    });

    for (
      int index = 0;
      index < slices.length && remainingMinor > 0;
      index += 1
    ) {
      slices[index] = slices[index].copyWith(
        amountMinor: slices[index].amountMinor + 1,
      );
      remainingMinor -= 1;
    }

    slices.sort((_AllocationSlice left, _AllocationSlice right) {
      return left.index.compareTo(right.index);
    });
    return slices
        .map((_AllocationSlice slice) => slice.amountMinor)
        .toList(growable: false);
  }
}

class _WeightedBucket {
  const _WeightedBucket({required this.key, required this.weightMinor});

  final String key;
  final int weightMinor;
}

class _AllocationSlice {
  const _AllocationSlice({
    required this.index,
    required this.key,
    required this.amountMinor,
    required this.remainderNumerator,
  });

  final int index;
  final String key;
  final int amountMinor;
  final int remainderNumerator;

  _AllocationSlice copyWith({int? amountMinor}) {
    return _AllocationSlice(
      index: index,
      key: key,
      amountMinor: amountMinor ?? this.amountMinor,
      remainderNumerator: remainderNumerator,
    );
  }
}
