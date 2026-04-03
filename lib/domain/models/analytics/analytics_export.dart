class AnalyticsExport {
  const AnalyticsExport({
    required this.title,
    required this.periodLabel,
    required this.kpis,
    required this.highlights,
    required this.notes,
  });

  final String title;
  final String periodLabel;
  final Map<String, dynamic> kpis;
  final List<String> highlights;
  final List<String> notes;
}
