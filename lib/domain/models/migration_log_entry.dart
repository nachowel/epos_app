enum MigrationLogStatus { started, succeeded, failed }

class MigrationLogEntry {
  const MigrationLogEntry({
    required this.timestamp,
    required this.step,
    required this.fromVersion,
    required this.toVersion,
    required this.status,
    required this.message,
  });

  final DateTime timestamp;
  final String step;
  final int fromVersion;
  final int toVersion;
  final MigrationLogStatus status;
  final String? message;
}
