import 'package:drift/drift.dart';

import '../../domain/models/sync_queue_item.dart';
import '../database/app_database.dart' as db;

class SyncQueueRepository {
  const SyncQueueRepository(this._database);

  final db.AppDatabase _database;

  Future<void> addToQueue(String tableName, String recordUuid) async {
    await _database.transaction(() async {
      final DateTime now = DateTime.now();
      final db.SyncQueueData? existing =
          await (_database.select(_database.syncQueue)
                ..where((db.$SyncQueueTable t) {
                  return t.queueTableName.equals(tableName) &
                      t.recordUuid.equals(recordUuid) &
                      t.status.isIn(const <String>[
                        'pending',
                        'processing',
                        'failed',
                      ]);
                })
                ..orderBy(<OrderingTerm Function(db.$SyncQueueTable)>[
                  (db.$SyncQueueTable t) => OrderingTerm.desc(t.id),
                ])
                ..limit(1))
              .getSingleOrNull();

      if (existing == null) {
        await _database
            .into(_database.syncQueue)
            .insert(
              db.SyncQueueCompanion.insert(
                queueTableName: tableName,
                recordUuid: recordUuid,
              ),
            );
        return;
      }

      if (existing.status == 'processing') {
        await _database
            .into(_database.syncQueue)
            .insert(
              db.SyncQueueCompanion.insert(
                queueTableName: tableName,
                recordUuid: recordUuid,
                createdAt: Value<DateTime>(now),
              ),
            );
        return;
      }

      await (_database.update(
        _database.syncQueue,
      )..where((db.$SyncQueueTable t) => t.id.equals(existing.id))).write(
        db.SyncQueueCompanion(
          status: const Value<String>('pending'),
          createdAt: Value<DateTime>(now),
          attemptCount: const Value<int>(0),
          errorMessage: const Value<String?>(null),
          lastAttemptAt: const Value<DateTime?>(null),
          syncedAt: const Value<DateTime?>(null),
        ),
      );
    });
  }

  Future<List<SyncQueueItem>> claimProcessableItems({
    int limit = 50,
    int maxRetryAttempts = 5,
    Duration baseRetryDelay = const Duration(seconds: 5),
    Duration maxRetryDelay = const Duration(minutes: 5),
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    return _database.transaction(() async {
      await _promoteDueFailedItems(
        maxRetryAttempts: maxRetryAttempts,
        baseRetryDelay: baseRetryDelay,
        maxRetryDelay: maxRetryDelay,
        now: effectiveNow,
      );

      final List<QueryRow> claimedRows = await _database
          .customSelect(
            '''
                WITH latest_pending AS (
                  SELECT MAX(id) AS id
                  FROM sync_queue
                  WHERE status = 'pending'
                  GROUP BY table_name, record_uuid
                ),
                claimable AS (
                  SELECT sq.id
                  FROM sync_queue sq
                  INNER JOIN latest_pending lp ON lp.id = sq.id
                  ORDER BY sq.created_at ASC, sq.id ASC
                  LIMIT ?
                )
                UPDATE sync_queue
                SET status = 'processing',
                    last_attempt_at = ?
                WHERE id IN (SELECT id FROM claimable)
                RETURNING id
                ''',
            variables: <Variable<Object>>[
              Variable<int>(limit),
              Variable<DateTime>(effectiveNow),
            ],
          )
          .get();

      final List<int> ids = claimedRows
          .map((QueryRow row) => row.read<int>('id'))
          .toList(growable: false);
      if (ids.isEmpty) {
        return const <SyncQueueItem>[];
      }

      final List<db.SyncQueueData> rows = await (_database.select(
        _database.syncQueue,
      )..where((db.$SyncQueueTable t) => t.id.isIn(ids))).get();
      final Map<int, db.SyncQueueData> rowsById = <int, db.SyncQueueData>{
        for (final db.SyncQueueData row in rows) row.id: row,
      };

      return ids
          .map((int id) => rowsById[id])
          .whereType<db.SyncQueueData>()
          .map(_mapQueueItem)
          .toList(growable: false);
    });
  }

  Future<List<SyncQueueItem>> getMonitorItems({int limit = 100}) async {
    final List<db.SyncQueueData> rows =
        await (_database.select(_database.syncQueue)
              ..where((db.$SyncQueueTable t) {
                return t.status.isIn(const <String>[
                  'pending',
                  'processing',
                  'failed',
                ]);
              })
              ..orderBy(<OrderingTerm Function(db.$SyncQueueTable)>[
                (db.$SyncQueueTable t) => OrderingTerm.asc(t.createdAt),
                (db.$SyncQueueTable t) => OrderingTerm.asc(t.id),
              ])
              ..limit(limit))
            .get();

    return rows.map(_mapQueueItem).toList(growable: false);
  }

  Future<({int pendingCount, int failedCount})> getMonitorCounts() async {
    final QueryRow row = await _database
        .customSelect(
          '''
          SELECT
            COALESCE(SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END), 0) AS pending_count,
            COALESCE(SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END), 0) AS failed_count
          FROM sync_queue
          ''',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.syncQueue,
          },
        )
        .getSingle();

    return (
      pendingCount: row.read<int>('pending_count'),
      failedCount: row.read<int>('failed_count'),
    );
  }

  Future<DateTime?> getLastSyncedAt() async {
    final QueryRow row = await _database
        .customSelect(
          '''
          SELECT MAX(synced_at) AS last_synced_at
          FROM sync_queue
          WHERE synced_at IS NOT NULL
          ''',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.syncQueue,
          },
        )
        .getSingle();

    final String? rawValue = row.readNullable<String>('last_synced_at');
    return rawValue == null ? null : DateTime.parse(rawValue);
  }

  Future<String?> getLastError() async {
    final QueryRow? row = await _database
        .customSelect(
          '''
              SELECT error_message
              FROM sync_queue
              WHERE error_message IS NOT NULL AND error_message != ''
              ORDER BY COALESCE(last_attempt_at, created_at) DESC, id DESC
              LIMIT 1
              ''',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.syncQueue,
          },
        )
        .getSingleOrNull();

    return row?.readNullable<String>('error_message');
  }

  Future<int> getStuckCount({
    int maxRetryAttempts = 5,
    Duration processingStuckThreshold = const Duration(minutes: 2),
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final List<db.SyncQueueData> rows =
        await (_database.select(_database.syncQueue)..where((
              db.$SyncQueueTable t,
            ) {
              return t.status.equals('failed') | t.status.equals('processing');
            }))
            .get();

    int stuckCount = 0;
    for (final db.SyncQueueData row in rows) {
      final bool isFailedStuck =
          row.status == 'failed' && row.attemptCount >= maxRetryAttempts;
      final bool isProcessingStuck =
          row.status == 'processing' &&
          row.lastAttemptAt != null &&
          row.lastAttemptAt!
              .add(processingStuckThreshold)
              .isBefore(effectiveNow);
      if (isFailedStuck || isProcessingStuck) {
        stuckCount += 1;
      }
    }
    return stuckCount;
  }

  Future<void> markProcessing(int id) async {
    await (_database.update(
      _database.syncQueue,
    )..where((db.$SyncQueueTable t) => t.id.equals(id))).write(
      db.SyncQueueCompanion(
        status: const Value<String>('processing'),
        lastAttemptAt: Value<DateTime?>(DateTime.now()),
      ),
    );
  }

  Future<void> markSynced(int id) async {
    await (_database.update(
      _database.syncQueue,
    )..where((db.$SyncQueueTable t) => t.id.equals(id))).write(
      db.SyncQueueCompanion(
        status: const Value<String>('synced'),
        syncedAt: Value<DateTime?>(DateTime.now()),
        errorMessage: const Value<String?>(null),
      ),
    );
  }

  Future<void> markFailed(int id, String error) async {
    await _database.transaction(() async {
      final db.SyncQueueData? row = await (_database.select(
        _database.syncQueue,
      )..where((db.$SyncQueueTable t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return;
      }

      await (_database.update(
        _database.syncQueue,
      )..where((db.$SyncQueueTable t) => t.id.equals(id))).write(
        db.SyncQueueCompanion(
          status: const Value<String>('failed'),
          errorMessage: Value<String?>(error),
          lastAttemptAt: Value<DateTime?>(DateTime.now()),
          attemptCount: Value<int>(row.attemptCount + 1),
        ),
      );
    });
  }

  Future<void> resetProcessingToPending() async {
    await (_database.update(_database.syncQueue)
          ..where((db.$SyncQueueTable t) => t.status.equals('processing')))
        .write(const db.SyncQueueCompanion(status: Value<String>('pending')));
  }

  Future<void> resetAttempts(int id) async {
    await (_database.update(
      _database.syncQueue,
    )..where((db.$SyncQueueTable t) => t.id.equals(id))).write(
      const db.SyncQueueCompanion(
        status: Value<String>('pending'),
        attemptCount: Value<int>(0),
        errorMessage: Value<String?>(null),
      ),
    );
  }

  Future<void> resetAllFailedAttempts() async {
    await (_database.update(
      _database.syncQueue,
    )..where((db.$SyncQueueTable t) => t.status.equals('failed'))).write(
      const db.SyncQueueCompanion(
        status: Value<String>('pending'),
        attemptCount: Value<int>(0),
        errorMessage: Value<String?>(null),
        lastAttemptAt: Value<DateTime?>(null),
      ),
    );
  }

  Future<int> getFailedCount() async {
    final ({int pendingCount, int failedCount}) counts =
        await getMonitorCounts();
    return counts.failedCount;
  }

  Future<int> getPendingCount() async {
    final ({int pendingCount, int failedCount}) counts =
        await getMonitorCounts();
    return counts.pendingCount;
  }

  Future<void> markRecordGraphSynced(
    Iterable<({String tableName, String recordUuid})> records,
    int claimedThroughId,
  ) async {
    final List<({String tableName, String recordUuid})> uniqueRecords =
        _dedupeRecords(records);
    if (uniqueRecords.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();
    await _database.transaction(() async {
      for (final ({String tableName, String recordUuid}) record
          in uniqueRecords) {
        await (_database.update(_database.syncQueue)
              ..where((db.$SyncQueueTable t) {
                return t.queueTableName.equals(record.tableName) &
                    t.recordUuid.equals(record.recordUuid) &
                    t.id.isSmallerOrEqualValue(claimedThroughId) &
                    t.status.isIn(const <String>[
                      'pending',
                      'processing',
                      'failed',
                    ]);
              }))
            .write(
              db.SyncQueueCompanion(
                status: const Value<String>('synced'),
                syncedAt: Value<DateTime?>(now),
                errorMessage: const Value<String?>(null),
              ),
            );
      }
    });
  }

  Future<void> markRecordGraphFailed(
    Iterable<({String tableName, String recordUuid})> records,
    String error,
    int claimedThroughId,
  ) async {
    final List<({String tableName, String recordUuid})> uniqueRecords =
        _dedupeRecords(records);
    if (uniqueRecords.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();
    await _database.transaction(() async {
      for (final ({String tableName, String recordUuid}) record
          in uniqueRecords) {
        final List<db.SyncQueueData> rows =
            await (_database.select(_database.syncQueue)
                  ..where((db.$SyncQueueTable t) {
                    return t.queueTableName.equals(record.tableName) &
                        t.recordUuid.equals(record.recordUuid) &
                        t.id.isSmallerOrEqualValue(claimedThroughId) &
                        t.status.isIn(const <String>[
                          'pending',
                          'processing',
                          'failed',
                        ]);
                  }))
                .get();

        for (final db.SyncQueueData row in rows) {
          await (_database.update(
            _database.syncQueue,
          )..where((db.$SyncQueueTable t) => t.id.equals(row.id))).write(
            db.SyncQueueCompanion(
              status: const Value<String>('failed'),
              errorMessage: Value<String?>(error),
              lastAttemptAt: Value<DateTime?>(now),
              attemptCount: Value<int>(row.attemptCount + 1),
            ),
          );
        }
      }
    });
  }

  Future<void> markRecordGraphFailedPermanently(
    Iterable<({String tableName, String recordUuid})> records,
    String error,
    int claimedThroughId, {
    required int targetAttemptCount,
  }) async {
    final List<({String tableName, String recordUuid})> uniqueRecords =
        _dedupeRecords(records);
    if (uniqueRecords.isEmpty) {
      return;
    }

    final DateTime now = DateTime.now();
    await _database.transaction(() async {
      for (final ({String tableName, String recordUuid}) record
          in uniqueRecords) {
        final List<db.SyncQueueData> rows =
            await (_database.select(_database.syncQueue)
                  ..where((db.$SyncQueueTable t) {
                    return t.queueTableName.equals(record.tableName) &
                        t.recordUuid.equals(record.recordUuid) &
                        t.id.isSmallerOrEqualValue(claimedThroughId) &
                        t.status.isIn(const <String>[
                          'pending',
                          'processing',
                          'failed',
                        ]);
                  }))
                .get();

        for (final db.SyncQueueData row in rows) {
          await (_database.update(
            _database.syncQueue,
          )..where((db.$SyncQueueTable t) => t.id.equals(row.id))).write(
            db.SyncQueueCompanion(
              status: const Value<String>('failed'),
              errorMessage: Value<String?>(error),
              lastAttemptAt: Value<DateTime?>(now),
              attemptCount: Value<int>(
                row.attemptCount >= targetAttemptCount
                    ? row.attemptCount
                    : targetAttemptCount,
              ),
            ),
          );
        }
      }
    });
  }

  bool _isDueForRetry(
    db.SyncQueueData row, {
    required DateTime now,
    required Duration baseRetryDelay,
    required Duration maxRetryDelay,
  }) {
    if (row.status == 'pending') {
      return true;
    }
    if (row.status != 'failed') {
      return false;
    }
    final DateTime? lastAttemptAt = row.lastAttemptAt;
    if (lastAttemptAt == null) {
      return true;
    }
    final int retryExponent = row.attemptCount <= 0 ? 0 : row.attemptCount - 1;
    final int multiplier = 1 << retryExponent.clamp(0, 10);
    final Duration rawDelay = Duration(
      milliseconds: baseRetryDelay.inMilliseconds * multiplier,
    );
    final Duration effectiveDelay = rawDelay > maxRetryDelay
        ? maxRetryDelay
        : rawDelay;
    return !lastAttemptAt.add(effectiveDelay).isAfter(now);
  }

  SyncQueueItem _mapQueueItem(db.SyncQueueData row) {
    return SyncQueueItem(
      id: row.id,
      tableName: row.queueTableName,
      recordUuid: row.recordUuid,
      operation: _operationFromDb(row.operation),
      createdAt: row.createdAt,
      status: _statusFromDb(row.status),
      attemptCount: row.attemptCount,
      lastAttemptAt: row.lastAttemptAt,
      syncedAt: row.syncedAt,
      errorMessage: row.errorMessage,
    );
  }

  SyncQueueOperation _operationFromDb(String value) {
    switch (value) {
      case 'upsert':
        return SyncQueueOperation.upsert;
      default:
        throw ArgumentError.value(
          value,
          'value',
          'Unsupported queue operation',
        );
    }
  }

  SyncQueueStatus _statusFromDb(String value) {
    switch (value) {
      case 'pending':
        return SyncQueueStatus.pending;
      case 'processing':
        return SyncQueueStatus.processing;
      case 'synced':
        return SyncQueueStatus.synced;
      case 'failed':
        return SyncQueueStatus.failed;
      default:
        throw ArgumentError.value(value, 'value', 'Unsupported queue status');
    }
  }

  Future<void> _promoteDueFailedItems({
    required int maxRetryAttempts,
    required Duration baseRetryDelay,
    required Duration maxRetryDelay,
    required DateTime now,
  }) async {
    final List<db.SyncQueueData> rows =
        await (_database.select(_database.syncQueue)
              ..where((db.$SyncQueueTable t) {
                return t.status.equals('failed') &
                    t.attemptCount.isSmallerThanValue(maxRetryAttempts);
              })
              ..orderBy(<OrderingTerm Function(db.$SyncQueueTable)>[
                (db.$SyncQueueTable t) => OrderingTerm.asc(t.createdAt),
                (db.$SyncQueueTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    final List<int> dueIds = rows
        .where((db.SyncQueueData row) {
          return _isDueForRetry(
            row,
            now: now,
            baseRetryDelay: baseRetryDelay,
            maxRetryDelay: maxRetryDelay,
          );
        })
        .map((db.SyncQueueData row) => row.id)
        .toList(growable: false);

    if (dueIds.isEmpty) {
      return;
    }

    await (_database.update(_database.syncQueue)
          ..where((db.$SyncQueueTable t) => t.id.isIn(dueIds)))
        .write(const db.SyncQueueCompanion(status: Value<String>('pending')));
  }

  List<({String tableName, String recordUuid})> _dedupeRecords(
    Iterable<({String tableName, String recordUuid})> records,
  ) {
    final Map<String, ({String tableName, String recordUuid})> deduped =
        <String, ({String tableName, String recordUuid})>{};
    for (final ({String tableName, String recordUuid}) record in records) {
      deduped['${record.tableName}:${record.recordUuid}'] = record;
    }
    return deduped.values.toList(growable: false);
  }
}
