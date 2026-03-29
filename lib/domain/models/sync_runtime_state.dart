class SyncRuntimeState {
  const SyncRuntimeState({
    required this.isEnabled,
    required this.isOnline,
    required this.isRunning,
    required this.lastRunStartedAt,
    required this.lastRunCompletedAt,
    required this.lastRuntimeError,
  });

  const SyncRuntimeState.initial()
    : isEnabled = true,
      isOnline = false,
      isRunning = false,
      lastRunStartedAt = null,
      lastRunCompletedAt = null,
      lastRuntimeError = null;

  final bool isEnabled;
  final bool isOnline;
  final bool isRunning;
  final DateTime? lastRunStartedAt;
  final DateTime? lastRunCompletedAt;
  final String? lastRuntimeError;

  SyncRuntimeState copyWith({
    bool? isEnabled,
    bool? isOnline,
    bool? isRunning,
    Object? lastRunStartedAt = _unset,
    Object? lastRunCompletedAt = _unset,
    Object? lastRuntimeError = _unset,
  }) {
    return SyncRuntimeState(
      isEnabled: isEnabled ?? this.isEnabled,
      isOnline: isOnline ?? this.isOnline,
      isRunning: isRunning ?? this.isRunning,
      lastRunStartedAt: lastRunStartedAt == _unset
          ? this.lastRunStartedAt
          : lastRunStartedAt as DateTime?,
      lastRunCompletedAt: lastRunCompletedAt == _unset
          ? this.lastRunCompletedAt
          : lastRunCompletedAt as DateTime?,
      lastRuntimeError: lastRuntimeError == _unset
          ? this.lastRuntimeError
          : lastRuntimeError as String?,
    );
  }
}

const Object _unset = Object();
