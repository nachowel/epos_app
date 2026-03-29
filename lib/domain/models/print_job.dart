enum PrintJobTarget { kitchen, receipt }

enum PrintJobStatus { pending, printing, printed, failed }

const Duration defaultPrintJobClaimStaleAfter = Duration(minutes: 2);

class PrintJob {
  const PrintJob({
    required this.id,
    required this.transactionId,
    required this.target,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.attemptCount,
    required this.lastAttemptAt,
    required this.completedAt,
    required this.lastError,
  });

  final int id;
  final int transactionId;
  final PrintJobTarget target;
  final PrintJobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final DateTime? completedAt;
  final String? lastError;

  bool get isPending => status == PrintJobStatus.pending;

  bool get isPrinting => status == PrintJobStatus.printing;

  bool get isPrinted => status == PrintJobStatus.printed;

  bool get isFailed => status == PrintJobStatus.failed;

  bool isRecoverablyStalePrinting({
    DateTime? now,
    Duration staleAfter = defaultPrintJobClaimStaleAfter,
  }) {
    if (!isPrinting) {
      return false;
    }
    final DateTime? attemptedAt = lastAttemptAt;
    if (attemptedAt == null) {
      return true;
    }
    return attemptedAt.add(staleAfter).isBefore(now ?? DateTime.now());
  }

  PrintJob copyWith({
    int? id,
    int? transactionId,
    PrintJobTarget? target,
    PrintJobStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? attemptCount,
    Object? lastAttemptAt = _unset,
    Object? completedAt = _unset,
    Object? lastError = _unset,
  }) {
    return PrintJob(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      target: target ?? this.target,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      lastAttemptAt: lastAttemptAt == _unset
          ? this.lastAttemptAt
          : lastAttemptAt as DateTime?,
      completedAt: completedAt == _unset
          ? this.completedAt
          : completedAt as DateTime?,
      lastError: lastError == _unset ? this.lastError : lastError as String?,
    );
  }
}

const Object _unset = Object();
