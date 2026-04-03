import 'insight.dart';

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.periodLabel,
    required this.comparisonModeLabel,
    required this.kpis,
    required this.insights,
    required this.keyBreakdowns,
    required this.notes,
  });

  final String periodLabel;
  final String comparisonModeLabel;
  final List<AnalyticsSnapshotKpi> kpis;
  final List<Insight> insights;
  final List<AnalyticsSnapshotSection> keyBreakdowns;
  final List<String> notes;
}

class AnalyticsSnapshotKpi {
  const AnalyticsSnapshotKpi({
    required this.title,
    required this.value,
    this.supportingLabel,
  });

  final String title;
  final String value;
  final String? supportingLabel;
}

class AnalyticsSnapshotSection {
  const AnalyticsSnapshotSection({
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;
}
