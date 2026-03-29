enum CashierReportMode {
  percentage('percentage'),
  capAmount('cap_amount');

  const CashierReportMode(this.dbValue);

  final String dbValue;

  static CashierReportMode fromDbValue(String value) {
    for (final CashierReportMode mode in CashierReportMode.values) {
      if (mode.dbValue == value) {
        return mode;
      }
    }
    throw ArgumentError.value(value, 'value', 'Unknown cashier report mode.');
  }
}

class ReportSettingsPolicy {
  const ReportSettingsPolicy({
    required this.cashierReportMode,
    required this.visibilityRatio,
    required this.maxVisibleTotalMinor,
  });

  const ReportSettingsPolicy.defaults()
    : cashierReportMode = CashierReportMode.percentage,
      visibilityRatio = 1.0,
      maxVisibleTotalMinor = null;

  final CashierReportMode cashierReportMode;
  final double visibilityRatio;
  final int? maxVisibleTotalMinor;

  bool get isPercentageMode =>
      cashierReportMode == CashierReportMode.percentage;

  bool get isCapAmountMode => cashierReportMode == CashierReportMode.capAmount;

  ReportSettingsPolicy copyWith({
    CashierReportMode? cashierReportMode,
    double? visibilityRatio,
    Object? maxVisibleTotalMinor = _unset,
  }) {
    return ReportSettingsPolicy(
      cashierReportMode: cashierReportMode ?? this.cashierReportMode,
      visibilityRatio: visibilityRatio ?? this.visibilityRatio,
      maxVisibleTotalMinor: maxVisibleTotalMinor == _unset
          ? this.maxVisibleTotalMinor
          : maxVisibleTotalMinor as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ReportSettingsPolicy &&
        other.cashierReportMode == cashierReportMode &&
        other.visibilityRatio == visibilityRatio &&
        other.maxVisibleTotalMinor == maxVisibleTotalMinor;
  }

  @override
  int get hashCode =>
      Object.hash(cashierReportMode, visibilityRatio, maxVisibleTotalMinor);
}

const Object _unset = Object();
