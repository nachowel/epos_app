import 'cashier_projected_category_line.dart';

class CashierProjectedReport {
  const CashierProjectedReport({
    required this.hasOpenShift,
    required this.shiftId,
    required this.previewTaken,
    required this.previewTakenAt,
    required this.previewTakenByUserName,
    required this.generatedAt,
    required this.operatorName,
    required this.businessName,
    required this.businessAddress,
    required this.visibleGrossSalesMinor,
    required this.visibleRefundTotalMinor,
    required this.visibleNetSalesMinor,
    required this.visibleGrossCashMinor,
    required this.visibleCashMinor,
    required this.visibleGrossCardMinor,
    required this.visibleCardMinor,
    required this.visibleOpenOrdersTotalMinor,
    required this.visibleTotalMinor,
    required this.totalOrdersCount,
    required this.openOrdersCount,
    required this.cancelledOrdersCount,
    required this.categoryBreakdown,
  });

  const CashierProjectedReport.empty()
    : hasOpenShift = false,
      shiftId = null,
      previewTaken = false,
      previewTakenAt = null,
      previewTakenByUserName = null,
      generatedAt = null,
      operatorName = null,
      businessName = null,
      businessAddress = null,
      visibleGrossSalesMinor = 0,
      visibleRefundTotalMinor = 0,
      visibleNetSalesMinor = 0,
      visibleGrossCashMinor = 0,
      visibleCashMinor = 0,
      visibleGrossCardMinor = 0,
      visibleCardMinor = 0,
      visibleOpenOrdersTotalMinor = 0,
      visibleTotalMinor = 0,
      totalOrdersCount = 0,
      openOrdersCount = 0,
      cancelledOrdersCount = 0,
      categoryBreakdown = const <CashierProjectedCategoryLine>[];

  final bool hasOpenShift;
  final int? shiftId;
  final bool previewTaken;
  final DateTime? previewTakenAt;
  final String? previewTakenByUserName;
  final DateTime? generatedAt;
  final String? operatorName;
  final String? businessName;
  final String? businessAddress;
  final int visibleGrossSalesMinor;
  final int visibleRefundTotalMinor;
  final int visibleNetSalesMinor;
  final int visibleGrossCashMinor;
  final int visibleCashMinor;
  final int visibleGrossCardMinor;
  final int visibleCardMinor;
  final int visibleOpenOrdersTotalMinor;
  final int visibleTotalMinor;
  final int totalOrdersCount;
  final int openOrdersCount;
  final int cancelledOrdersCount;
  final List<CashierProjectedCategoryLine> categoryBreakdown;

  int get visibleNetCashMinor => visibleCashMinor;

  int get visibleNetCardMinor => visibleCardMinor;

  CashierProjectedReport copyWith({
    bool? hasOpenShift,
    Object? shiftId = _unset,
    bool? previewTaken,
    Object? previewTakenAt = _unset,
    Object? previewTakenByUserName = _unset,
    Object? generatedAt = _unset,
    Object? operatorName = _unset,
    Object? businessName = _unset,
    Object? businessAddress = _unset,
    int? visibleGrossSalesMinor,
    int? visibleRefundTotalMinor,
    int? visibleNetSalesMinor,
    int? visibleGrossCashMinor,
    int? visibleCashMinor,
    int? visibleGrossCardMinor,
    int? visibleCardMinor,
    int? visibleOpenOrdersTotalMinor,
    int? visibleTotalMinor,
    int? totalOrdersCount,
    int? openOrdersCount,
    int? cancelledOrdersCount,
    List<CashierProjectedCategoryLine>? categoryBreakdown,
  }) {
    return CashierProjectedReport(
      hasOpenShift: hasOpenShift ?? this.hasOpenShift,
      shiftId: shiftId == _unset ? this.shiftId : shiftId as int?,
      previewTaken: previewTaken ?? this.previewTaken,
      previewTakenAt: previewTakenAt == _unset
          ? this.previewTakenAt
          : previewTakenAt as DateTime?,
      previewTakenByUserName: previewTakenByUserName == _unset
          ? this.previewTakenByUserName
          : previewTakenByUserName as String?,
      generatedAt: generatedAt == _unset
          ? this.generatedAt
          : generatedAt as DateTime?,
      operatorName: operatorName == _unset
          ? this.operatorName
          : operatorName as String?,
      businessName: businessName == _unset
          ? this.businessName
          : businessName as String?,
      businessAddress: businessAddress == _unset
          ? this.businessAddress
          : businessAddress as String?,
      visibleGrossSalesMinor:
          visibleGrossSalesMinor ?? this.visibleGrossSalesMinor,
      visibleRefundTotalMinor:
          visibleRefundTotalMinor ?? this.visibleRefundTotalMinor,
      visibleNetSalesMinor: visibleNetSalesMinor ?? this.visibleNetSalesMinor,
      visibleGrossCashMinor:
          visibleGrossCashMinor ?? this.visibleGrossCashMinor,
      visibleCashMinor: visibleCashMinor ?? this.visibleCashMinor,
      visibleGrossCardMinor:
          visibleGrossCardMinor ?? this.visibleGrossCardMinor,
      visibleCardMinor: visibleCardMinor ?? this.visibleCardMinor,
      visibleOpenOrdersTotalMinor:
          visibleOpenOrdersTotalMinor ?? this.visibleOpenOrdersTotalMinor,
      visibleTotalMinor: visibleTotalMinor ?? this.visibleTotalMinor,
      totalOrdersCount: totalOrdersCount ?? this.totalOrdersCount,
      openOrdersCount: openOrdersCount ?? this.openOrdersCount,
      cancelledOrdersCount: cancelledOrdersCount ?? this.cancelledOrdersCount,
      categoryBreakdown: categoryBreakdown ?? this.categoryBreakdown,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CashierProjectedReport &&
        other.hasOpenShift == hasOpenShift &&
        other.shiftId == shiftId &&
        other.previewTaken == previewTaken &&
        other.previewTakenAt == previewTakenAt &&
        other.previewTakenByUserName == previewTakenByUserName &&
        other.generatedAt == generatedAt &&
        other.operatorName == operatorName &&
        other.businessName == businessName &&
        other.businessAddress == businessAddress &&
        other.visibleGrossSalesMinor == visibleGrossSalesMinor &&
        other.visibleRefundTotalMinor == visibleRefundTotalMinor &&
        other.visibleNetSalesMinor == visibleNetSalesMinor &&
        other.visibleGrossCashMinor == visibleGrossCashMinor &&
        other.visibleCashMinor == visibleCashMinor &&
        other.visibleGrossCardMinor == visibleGrossCardMinor &&
        other.visibleCardMinor == visibleCardMinor &&
        other.visibleOpenOrdersTotalMinor == visibleOpenOrdersTotalMinor &&
        other.visibleTotalMinor == visibleTotalMinor &&
        other.totalOrdersCount == totalOrdersCount &&
        other.openOrdersCount == openOrdersCount &&
        other.cancelledOrdersCount == cancelledOrdersCount &&
        _listEquals(other.categoryBreakdown, categoryBreakdown);
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    hasOpenShift,
    shiftId,
    previewTaken,
    previewTakenAt,
    previewTakenByUserName,
    generatedAt,
    operatorName,
    businessName,
    businessAddress,
    visibleGrossSalesMinor,
    visibleRefundTotalMinor,
    visibleNetSalesMinor,
    visibleGrossCashMinor,
    visibleCashMinor,
    visibleGrossCardMinor,
    visibleCardMinor,
    visibleOpenOrdersTotalMinor,
    visibleTotalMinor,
    totalOrdersCount,
    openOrdersCount,
    cancelledOrdersCount,
    Object.hashAll(categoryBreakdown),
  ]);

  bool _listEquals(
    List<CashierProjectedCategoryLine> a,
    List<CashierProjectedCategoryLine> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }
}

const Object _unset = Object();
