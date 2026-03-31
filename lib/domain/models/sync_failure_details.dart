enum SyncFailureKind {
  networkUnreachable,
  validationFailure,
  authOrConfigFailure,
  remoteServerError,
  localGraphDrift,
  unknown,
}

class SyncFailureDetails {
  const SyncFailureDetails({
    required this.failureKind,
    required this.retryable,
    required this.message,
    required this.tableName,
    required this.recordUuid,
    required this.recordUuids,
    required this.issues,
  });

  final SyncFailureKind failureKind;
  final bool? retryable;
  final String message;
  final String? tableName;
  final String? recordUuid;
  final List<String> recordUuids;
  final List<String> issues;

  static SyncFailureDetails? tryParse(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    if (!rawValue.contains('|') || !rawValue.contains('message=')) {
      return SyncFailureDetails(
        failureKind: SyncFailureKind.unknown,
        retryable: null,
        message: rawValue,
        tableName: null,
        recordUuid: null,
        recordUuids: const <String>[],
        issues: const <String>[],
      );
    }

    final Map<String, String> values = <String, String>{};
    for (final String segment in rawValue.split('|')) {
      final int separatorIndex = segment.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }
      final String key = segment.substring(0, separatorIndex).trim();
      final String value = segment.substring(separatorIndex + 1).trim();
      values[key] = value;
    }

    return SyncFailureDetails(
      failureKind: _kindFromString(values['failure_type']),
      retryable: switch (values['retryable']) {
        'true' => true,
        'false' => false,
        _ => null,
      },
      message: values['message'] ?? rawValue,
      tableName: _nullableValue(values['table']),
      recordUuid: _nullableValue(values['record_uuid']),
      recordUuids: _splitList(values['record_uuids']),
      issues: _splitList(values['issues']),
    );
  }

  static SyncFailureKind _kindFromString(String? value) {
    return switch (value) {
      'networkUnreachable' => SyncFailureKind.networkUnreachable,
      'validationFailure' => SyncFailureKind.validationFailure,
      'authOrConfigFailure' => SyncFailureKind.authOrConfigFailure,
      'remoteServerError' => SyncFailureKind.remoteServerError,
      'localGraphDrift' => SyncFailureKind.localGraphDrift,
      _ => SyncFailureKind.unknown,
    };
  }

  static String? _nullableValue(String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return null;
    }
    return value;
  }

  static List<String> _splitList(String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return const <String>[];
    }
    return value
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
}
