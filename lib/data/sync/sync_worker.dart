import 'dart:async';

import '../../core/logging/app_logger.dart';
import '../../data/repositories/sync_queue_repository.dart';
import '../../domain/models/sync_queue_item.dart';
import '../../domain/models/sync_runtime_state.dart';
import 'sync_connectivity_service.dart';
import 'sync_payload_repository.dart';
import 'sync_remote_gateway.dart';

class SyncWorker {
  SyncWorker({
    required SyncQueueRepository syncQueueRepository,
    required SyncPayloadRepository syncPayloadRepository,
    required SyncRemoteGateway remoteGateway,
    required SyncConnectivityService connectivityService,
    AppLogger logger = const NoopAppLogger(),
    this.isEnabled = true,
    this.pollInterval = const Duration(seconds: 10),
    this.batchSize = 20,
    this.maxRetryAttempts = 5,
    this.baseRetryDelay = const Duration(seconds: 5),
    this.maxRetryDelay = const Duration(minutes: 5),
  }) : _syncQueueRepository = syncQueueRepository,
       _syncPayloadRepository = syncPayloadRepository,
       _remoteGateway = remoteGateway,
       _connectivityService = connectivityService,
       _logger = logger,
       _stateController = StreamController<SyncRuntimeState>.broadcast();

  final SyncQueueRepository _syncQueueRepository;
  final SyncPayloadRepository _syncPayloadRepository;
  final SyncRemoteGateway _remoteGateway;
  final SyncConnectivityService _connectivityService;
  final AppLogger _logger;
  final bool isEnabled;
  final Duration pollInterval;
  final int batchSize;
  final int maxRetryAttempts;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;

  final StreamController<SyncRuntimeState> _stateController;
  Timer? _timer;
  StreamSubscription<bool>? _connectivitySubscription;
  Future<void>? _activeRun;
  bool _started = false;
  SyncRuntimeState _state = const SyncRuntimeState.initial();

  SyncRuntimeState get currentState => _state;

  Stream<SyncRuntimeState> watchState() => _stateController.stream;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;
    if (!isEnabled) {
      _updateState(
        isEnabled: false,
        isOnline: false,
        isRunning: false,
        lastRuntimeError: 'Sync disabled by feature flag.',
      );
      _logger.warn(
        eventType: 'sync_disabled',
        message: 'Sync worker start skipped because sync is disabled.',
      );
      return;
    }

    final bool isOnline = await _connectivityService.isOnline();
    _updateState(isEnabled: true, isOnline: isOnline, lastRuntimeError: null);
    await _syncQueueRepository.resetProcessingToPending();
    await runOnce();

    _timer = Timer.periodic(pollInterval, (_) {
      unawaited(runOnce());
    });
    _connectivitySubscription = _connectivityService.watchOnlineStatus().listen(
      (bool online) {
        _updateState(isOnline: online);
        if (online) {
          unawaited(runOnce());
        }
      },
    );
  }

  Future<void> stop() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _timer?.cancel();
    _timer = null;
    _started = false;
  }

  Future<void> dispose() async {
    await stop();
    await _stateController.close();
  }

  Future<void> runOnce() {
    if (!isEnabled) {
      _updateState(
        isEnabled: false,
        isOnline: false,
        isRunning: false,
        lastRuntimeError: 'Sync disabled by feature flag.',
      );
      return Future<void>.value();
    }
    final Future<void>? existingRun = _activeRun;
    if (existingRun != null) {
      return existingRun;
    }

    final Future<void> run = _runInternal().whenComplete(() {
      _activeRun = null;
    });
    _activeRun = run;
    return run;
  }

  Future<void> retryAllFailed() async {
    await _syncQueueRepository.resetAllFailedAttempts();
    _logger.audit(
      eventType: 'sync_retry_all_requested',
      message: 'Admin requested retry for all failed sync items.',
    );
    await runOnce();
  }

  Future<void> _runInternal() async {
    final bool isOnline = await _connectivityService.isOnline();
    _updateState(isEnabled: isEnabled, isOnline: isOnline);
    if (!isOnline) {
      return;
    }
    if (!_remoteGateway.isConfigured) {
      _updateState(lastRuntimeError: 'Supabase sync is not configured.');
      _logger.warn(
        eventType: 'sync_misconfigured',
        message:
            'Supabase sync is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
      return;
    }

    _updateState(
      isRunning: true,
      lastRunStartedAt: DateTime.now(),
      lastRuntimeError: null,
    );
    try {
      final List<SyncQueueItem> items = await _syncQueueRepository
          .claimProcessableItems(
            limit: batchSize,
            maxRetryAttempts: maxRetryAttempts,
            baseRetryDelay: baseRetryDelay,
            maxRetryDelay: maxRetryDelay,
            now: DateTime.now(),
          );

      final Map<String, List<SyncQueueItem>> claimedItemsByTransaction =
          <String, List<SyncQueueItem>>{};
      for (final SyncQueueItem item in items) {
        final String? transactionUuid = await _syncPayloadRepository
            .resolveTransactionUuid(
              tableName: item.tableName,
              recordUuid: item.recordUuid,
            );
        if (transactionUuid == null) {
          await _syncQueueRepository.markRecordGraphFailed(
            <({String tableName, String recordUuid})>[
              (tableName: item.tableName, recordUuid: item.recordUuid),
            ],
            'Source record missing.',
            item.id,
          );
          continue;
        }

        claimedItemsByTransaction
            .putIfAbsent(transactionUuid, () => <SyncQueueItem>[])
            .add(item);
      }

      for (final MapEntry<String, List<SyncQueueItem>> entry
          in claimedItemsByTransaction.entries) {
        await _processTransactionGraph(entry.key, entry.value);
      }
      _updateState(lastRunCompletedAt: DateTime.now(), lastRuntimeError: null);
    } catch (error) {
      _updateState(
        lastRunCompletedAt: DateTime.now(),
        lastRuntimeError: error.toString(),
      );
    } finally {
      _updateState(isRunning: false);
    }
  }

  Future<void> _processTransactionGraph(
    String transactionUuid,
    List<SyncQueueItem> claimedItems,
  ) async {
    final int claimedThroughId = claimedItems
        .map((SyncQueueItem item) => item.id)
        .reduce((int current, int next) => current > next ? current : next);
    final List<({String tableName, String recordUuid})> claimedRefs =
        claimedItems
            .map(
              (SyncQueueItem item) =>
                  (tableName: item.tableName, recordUuid: item.recordUuid),
            )
            .toList(growable: false);

    try {
      final SyncTransactionGraph? graph = await _syncPayloadRepository
          .buildTransactionGraph(transactionUuid);
      if (graph == null) {
        await _syncQueueRepository.markRecordGraphFailed(
          claimedRefs,
          'Source record missing.',
          claimedThroughId,
        );
        return;
      }

      for (final SyncGraphRecord record in graph.records) {
        await _remoteGateway.upsertRecord(
          tableName: record.tableName,
          payload: record.payload,
          idempotencyKey: record.idempotencyKey,
        );
      }

      await _syncQueueRepository
          .markRecordGraphSynced(<({String tableName, String recordUuid})>[
            ...claimedRefs,
            ...graph.records.map((SyncGraphRecord record) => record.queueRef),
          ], claimedThroughId);
      _logger.audit(
        eventType: 'sync_graph_succeeded',
        entityId: transactionUuid,
        message: 'Transaction graph synced successfully.',
        metadata: <String, Object?>{'record_count': graph.records.length},
      );
    } catch (error) {
      final String message = _truncateError(error);
      SyncTransactionGraph? graph;
      try {
        graph = await _syncPayloadRepository.buildTransactionGraph(
          transactionUuid,
        );
      } catch (_) {
        graph = null;
      }
      await _syncQueueRepository.markRecordGraphFailed(
        <({String tableName, String recordUuid})>[
          ...claimedRefs,
          if (graph != null)
            ...graph.records.map((SyncGraphRecord record) => record.queueRef),
        ],
        message,
        claimedThroughId,
      );
      final bool maxRetryHit = claimedItems.any(
        (SyncQueueItem item) => item.attemptCount + 1 >= maxRetryAttempts,
      );
      _logger.warn(
        eventType: maxRetryHit
            ? 'sync_graph_max_retry_hit'
            : 'sync_graph_failed',
        entityId: transactionUuid,
        message: message,
        metadata: <String, Object?>{
          'record_count': graph?.records.length ?? claimedRefs.length,
          'max_retry_hit': maxRetryHit,
        },
        error: error,
      );
    }
  }

  String _truncateError(Object error) {
    final String value = error.toString();
    if (value.length <= 500) {
      return value;
    }
    return value.substring(0, 500);
  }

  void _updateState({
    bool? isEnabled,
    bool? isOnline,
    bool? isRunning,
    Object? lastRunStartedAt = _unset,
    Object? lastRunCompletedAt = _unset,
    Object? lastRuntimeError = _unset,
  }) {
    _state = _state.copyWith(
      isEnabled: isEnabled,
      isOnline: isOnline,
      isRunning: isRunning,
      lastRunStartedAt: lastRunStartedAt,
      lastRunCompletedAt: lastRunCompletedAt,
      lastRuntimeError: lastRuntimeError,
    );
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}

const Object _unset = Object();
