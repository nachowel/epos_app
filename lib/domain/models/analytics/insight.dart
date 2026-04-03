enum InsightSeverity { info, positive, warning, negative }

class Insight {
  const Insight({
    required this.code,
    required this.severity,
    required this.title,
    required this.message,
    required this.evidence,
  });

  final String code;
  final InsightSeverity severity;
  final String title;
  final String message;
  final Map<String, dynamic> evidence;
}
