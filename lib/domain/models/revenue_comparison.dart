enum RevenueMetricFormat { currencyMinor, count }

class RevenueComparison {
  const RevenueComparison({
    required this.currentValue,
    required this.previousValue,
    required this.metricFormat,
  });

  final int currentValue;
  final int previousValue;
  final RevenueMetricFormat metricFormat;

  int get absoluteChange => currentValue - previousValue;

  double? get percentageChange {
    if (previousValue == 0) {
      return currentValue == 0 ? 0 : null;
    }
    return (absoluteChange / previousValue) * 100;
  }

  bool get isPositiveChange => absoluteChange > 0;

  bool get isNegativeChange => absoluteChange < 0;

  bool get isFlat => absoluteChange == 0;
}
