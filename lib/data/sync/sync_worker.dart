import 'dart:async';

import '../../core/logging/app_logger.dart';
import '../../data/repositories/sync_queue_repository.dart';
import '../../domain/models/sync_queue_item.dart';
import '../../domain/models/sync_runtime_state.dart';
import 'sync_connectivity_service.dart';
import 'sync_graph_checksum_calculator.dart';
import 'sync_payload_repository.dart';
import 'sync_remote_gateway.dart';
import 'sync_transaction_graph.dart';
import 'trusted_mirror_boundary_contract.dart';

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
  final SyncGraphChecksumCalculator _graphChecksumCalculator =
      const SyncGraphChecksumCalculator();
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
      final String issue =
          _remoteGateway.configurationIssue ??
          'Supabase sync is not configured.';
      _updateState(lastRuntimeError: issue);
      _logger.warn(eventType: 'sync_misconfigured', message: issue);
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
    final SyncQueueItem? rootQueueItem = _latestClaimedRootItem(
      transactionUuid: transactionUuid,
      claimedItems: claimedItems,
    );
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
    _logger.audit(
      eventType: 'sync_queue_root_claimed',
      entityId: transactionUuid,
      message: 'Queued transaction root claimed for sync processing.',
      metadata: <String, Object?>{
        'queue_row_id': rootQueueItem?.id,
        'claimed_queue_row_ids': claimedItems
            .map((SyncQueueItem item) => item.id)
            .toList(growable: false),
        'previous_status': 'pending',
        'new_status': 'processing',
      },
    );

    try {
      final SyncTransactionGraph? graph = await _syncPayloadRepository
          .buildTransactionGraph(transactionUuid);
      if (graph == null) {
        await _syncQueueRepository.markRecordGraphFailed(
          claimedRefs,
          _formatFailureMessage(StateError('Source record missing.')),
          claimedThroughId,
        );
        return;
      }
      await _verifyGraphChecksum(
        transactionUuid: transactionUuid,
        claimedItems: claimedItems,
        graph: graph,
      );

      await _remoteGateway.syncTransactionGraph(graph);

      await _syncQueueRepository
          .markRecordGraphSynced(<({String tableName, String recordUuid})>[
            ...claimedRefs,
            ...graph.records.map((SyncGraphRecord record) => record.queueRef),
          ], claimedThroughId);
      final Map<String, int> tableRecordCounts = <String, int>{};
      for (final SyncGraphRecord record in graph.records) {
        tableRecordCounts.update(
          record.tableName,
          (int count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      _logger.audit(
        eventType: 'sync_graph_succeeded',
        entityId: transactionUuid,
        message: 'Transaction graph synced successfully.',
        metadata: <String, Object?>{
          'queue_row_id': rootQueueItem?.id,
          'previous_status': 'processing',
          'new_status': 'synced',
          'record_count': graph.records.length,
          'tables_synced': tableRecordCounts.keys.toList(growable: false),
          'table_record_counts': tableRecordCounts,
        },
      );
    } catch (error) {
      final String queueMessage = _formatFailureMessage(error);
      final String logMessage = _humanReadableError(error);
      SyncTransactionGraph? graph;
      try {
        graph = await _syncPayloadRepository.buildTransactionGraph(
          transactionUuid,
        );
      } catch (_) {
        graph = null;
      }
      final Iterable<({String tableName, String recordUuid})> failedRefs =
          <({String tableName, String recordUuid})>[
            ...claimedRefs,
            if (graph != null)
              ...graph.records.map((SyncGraphRecord record) => record.queueRef),
          ];
      if (error is MirrorWriteFailure && !error.retryable) {
        await _syncQueueRepository.markRecordGraphFailedPermanently(
          failedRefs,
          queueMessage,
          claimedThroughId,
          targetAttemptCount: maxRetryAttempts,
        );
      } else {
        await _syncQueueRepository.markRecordGraphFailed(
          failedRefs,
          queueMessage,
          claimedThroughId,
        );
      }
      final bool permanentlyFailed =
          error is MirrorWriteFailure && !error.retryable;
      final bool maxRetryHit =
          permanentlyFailed ||
          claimedItems.any(
            (SyncQueueItem item) => item.attemptCount + 1 >= maxRetryAttempts,
          );
      final Map<String, Object?> failureMetadata = <String, Object?>{
        'queue_row_id': rootQueueItem?.id,
        'previous_status': 'processing',
        'new_status': 'failed',
        'record_count': graph?.records.length ?? claimedRefs.length,
        'max_retry_hit': maxRetryHit,
        'response_body_summary': _responseBodySummary(error),
      };
      if (error is MirrorWriteFailure) {
        failureMetadata['failure_type'] = error.type.name;
        failureMetadata['retryable'] = error.retryable;
        if (error.tableName case final String tableName) {
          failureMetadata['table_name'] = tableName;
        }
        if (error.recordUuid case final String recordUuid) {
          failureMetadata['record_uuid'] = recordUuid;
        }
        if (error.recordUuids.isNotEmpty) {
          failureMetadata['record_uuids'] = error.recordUuids;
        }
        if (error.issues.isNotEmpty) {
          failureMetadata['issues'] = error.issues;
        }
      }
      _logger.warn(
        eventType: maxRetryHit
            ? 'sync_graph_max_retry_hit'
            : 'sync_graph_failed',
        entityId: transactionUuid,
        message: logMessage,
        metadata: failureMetadata,
        error: error,
      );
    }
  }

  Future<void> _verifyGraphChecksum({
    required String transactionUuid,
    required List<SyncQueueItem> claimedItems,
    required SyncTransactionGraph graph,
  }) async {
    final SyncQueueItem? rootItem = _latestClaimedRootItem(
      transactionUuid: transactionUuid,
      claimedItems: claimedItems,
    );
    if (rootItem == null) {
      return;
    }

    final String currentChecksum = _graphChecksumCalculator.calculate(graph);
    final String? expectedChecksum = await _syncQueueRepository
        .getTransactionRootChecksum(rootItem.id);
    if (expectedChecksum == null) {
      await _syncQueueRepository.saveTransactionRootChecksum(
        queueId: rootItem.id,
        transactionUuid: transactionUuid,
        checksum: currentChecksum,
      );
      return;
    }
    if (expectedChecksum == currentChecksum) {
      return;
    }

    throw MirrorWriteFailure(
      type: MirrorWriteFailureType.localGraphDrift,
      message:
          'Local terminal graph drift detected. Retry is blocked until the root event is re-queued from the current local snapshot.',
      retryable: false,
      tableName: 'transactions',
      recordUuid: transactionUuid,
      issues: <String>[
        'expected_checksum=$expectedChecksum',
        'current_checksum=$currentChecksum',
      ],
    );
  }

  SyncQueueItem? _latestClaimedRootItem({
    required String transactionUuid,
    required List<SyncQueueItem> claimedItems,
  }) {
    SyncQueueItem? selected;
    for (final SyncQueueItem item in claimedItems) {
      if (item.tableName != 'transactions' ||
          item.recordUuid != transactionUuid) {
        continue;
      }
      if (selected == null || item.id > selected.id) {
        selected = item;
      }
    }
    return selected;
  }

  String _formatFailureMessage(Object error) {
    if (error is MirrorWriteFailure) {
      return <String>[
        'failure_type=${error.type.name}',
        'retryable=${error.retryable}',
        'table=${_safeValue(error.tableName)}',
        'record_uuid=${_safeValue(error.recordUuid)}',
        'record_uuids=${_safeList(error.recordUuids)}',
        'issues=${_safeList(error.issues)}',
        'message=${_safeMessage(error.message)}',
      ].join('|');
    }
    return <String>[
      'failure_type=unknown',
      'retryable=-',
      'table=-',
      'record_uuid=-',
      'record_uuids=-',
      'issues=-',
      'message=${_safeMessage(_truncateError(error))}',
    ].join('|');
  }

  String _humanReadableError(Object error) {
    if (error is MirrorWriteFailure) {
      return error.message;
    }
    return _truncateError(error);
  }

  String _safeValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }
    return value.replaceAll('|', '/').replaceAll(',', ';');
  }

  String _safeList(List<String> values) {
    if (values.isEmpty) {
      return '-';
    }
    return values
        .map((String value) => value.replaceAll('|', '/').replaceAll(',', ';'))
        .join(',');
  }

  String _safeMessage(String value) {
    return value.replaceAll('|', '/').replaceAll('\n', ' ').trim();
  }

  String _truncateError(Object error) {
    final String value = error.toString();
    if (value.length <= 500) {
      return value;
    }
    return value.substring(0, 500);
  }

  String _responseBodySummary(Object error) {
    if (error is MirrorWriteFailure) {
      final List<String> parts = <String>[error.message];
      if (error.issues.isNotEmpty) {
        parts.add('issues=${error.issues.take(3).join('; ')}');
      }
      return _safeMessage(parts.join(' | '));
    }
    return _safeMessage(_truncateError(error));
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
