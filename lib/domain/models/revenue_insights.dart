class RevenueInsights {
  const RevenueInsights({
    required this.weeklyPerformance,
    required this.revenueMomentum,
    required this.strongestDay,
    required this.weakestDay,
    required this.peakHours,
    required this.lowHours,
    required this.topHourConcentration,
    required this.distributionBalance,
  });

  final String weeklyPerformance;
  final String revenueMomentum;
  final String strongestDay;
  final String weakestDay;
  final String peakHours;
  final String lowHours;
  final String topHourConcentration;
  final String distributionBalance;

  List<String> get messages => <String>[
    weeklyPerformance,
    revenueMomentum,
    strongestDay,
    weakestDay,
    peakHours,
    lowHours,
    topHourConcentration,
    distributionBalance,
  ];
}
