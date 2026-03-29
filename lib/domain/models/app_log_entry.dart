enum AppLogLevel { info, audit, warn, error }

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.eventType,
    required this.message,
    required this.entityId,
    required this.metadata,
    required this.error,
    required this.stackTrace,
  });

  final DateTime timestamp;
  final AppLogLevel level;
  final String eventType;
  final String? message;
  final String? entityId;
  final Map<String, Object?> metadata;
  final String? error;
  final String? stackTrace;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'timestamp': timestamp.toIso8601String(),
      'level': level.name.toUpperCase(),
      'event_type': eventType,
      'message': message,
      'entity_id': entityId,
      'metadata': metadata,
      'error': error,
      'stack_trace': stackTrace,
    };
  }
}
