import 'shift_report.dart';

class ZReportActionResult {
  const ZReportActionResult({
    required this.shiftId,
    required this.report,
    required this.finalCloseCompleted,
    required this.cashierPreviewRecorded,
  });

  final int shiftId;
  final ShiftReport report;
  final bool finalCloseCompleted;
  final bool cashierPreviewRecorded;
}
