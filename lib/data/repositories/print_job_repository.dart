import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/print_job.dart';
import '../database/app_database.dart' as db;

class PrintJobRepository {
  const PrintJobRepository(this._database);

  final db.AppDatabase _database;

  Future<List<PrintJob>> getByTransactionId(int transactionId) async {
    final List<db.PrintJob> rows =
        await (_database.select(_database.printJobs)
              ..where(
                (db.$PrintJobsTable t) => t.transactionId.equals(transactionId),
              )
              ..orderBy(<OrderingTerm Function(db.$PrintJobsTable)>[
                (db.$PrintJobsTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    return rows.map(_mapPrintJob).toList(growable: false);
  }

  Future<PrintJob?> getByTransactionIdAndTarget({
    required int transactionId,
    required PrintJobTarget target,
  }) async {
    final db.PrintJob? row =
        await (_database.select(_database.printJobs)
              ..where((db.$PrintJobsTable t) {
                return t.transactionId.equals(transactionId) &
                    t.target.equals(_targetToDb(target));
              }))
            .getSingleOrNull();

    return row == null ? null : _mapPrintJob(row);
  }

  Future<PrintJob> ensureQueued({
    required int transactionId,
    required PrintJobTarget target,
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    try {
      final int id = await _database
          .into(_database.printJobs)
          .insert(
            db.PrintJobsCompanion.insert(
              transactionId: transactionId,
              target: _targetToDb(target),
              status: const Value<String>('pending'),
              createdAt: Value<DateTime>(effectiveNow),
              updatedAt: Value<DateTime>(effectiveNow),
            ),
          );
      return _mapPrintJob(await _findById(id));
    } on SqliteException catch (error) {
      if (_isUniqueTransactionTargetViolation(error)) {
        final PrintJob? existing = await getByTransactionIdAndTarget(
          transactionId: transactionId,
          target: target,
        );
        if (existing != null) {
          return existing;
        }
      }
      rethrow;
    }
  }

  Future<PrintJob> markInProgress({
    required int transactionId,
    required PrintJobTarget target,
    required bool allowReprint,
    DateTime? now,
    Duration staleAfter = defaultPrintJobClaimStaleAfter,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final PrintJob existing = await ensureQueued(
      transactionId: transactionId,
      target: target,
      now: effectiveNow,
    );

    if (existing.isPrinted && !allowReprint) {
      return existing;
    }
    if (existing.isFailed && !allowReprint) {
      return existing;
    }

    final int claimedCount = await _database.customUpdate(
      '''
      UPDATE print_jobs
      SET status = ?,
          updated_at = ?,
          last_attempt_at = ?,
          attempt_count = attempt_count + 1,
          last_error = NULL
      WHERE transaction_id = ?
        AND target = ?
        AND (
          status = 'pending'
          OR (? = 1 AND status = 'failed')
          OR (
            ? = 1
            AND status = 'printing'
            AND (
              last_attempt_at IS NULL
              OR last_attempt_at <= ?
            )
          )
        )
      ''',
      variables: <Variable<Object>>[
        const Variable<String>('printing'),
        Variable<DateTime>(effectiveNow),
        Variable<DateTime>(effectiveNow),
        Variable<int>(transactionId),
        Variable<String>(_targetToDb(target)),
        Variable<int>(allowReprint ? 1 : 0),
        Variable<int>(allowReprint ? 1 : 0),
        Variable<DateTime>(effectiveNow.subtract(staleAfter)),
      ],
      updates: {_database.printJobs},
    );

    if (claimedCount == 1) {
      final PrintJob? claimed = await getByTransactionIdAndTarget(
        transactionId: transactionId,
        target: target,
      );
      if (claimed != null) {
        return claimed;
      }
    }

    final PrintJob? current = await getByTransactionIdAndTarget(
      transactionId: transactionId,
      target: target,
    );
    if (current == null) {
      throw NotFoundException(
        'Print job not found for transaction $transactionId and ${target.name}.',
      );
    }
    if (current.isPrinted && !allowReprint) {
      return current;
    }
    if (current.isFailed && !allowReprint) {
      return current;
    }
    if (current.isPrinting) {
      throw PrintJobInProgressException(target: target);
    }
    throw DatabaseException(
      'Failed to claim ${target.name} print job for transaction $transactionId.',
    );
  }

  Future<PrintJob> markFailed({
    required int transactionId,
    required PrintJobTarget target,
    required String error,
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final PrintJob existing = await ensureQueued(
      transactionId: transactionId,
      target: target,
      now: effectiveNow,
    );

    await (_database.update(_database.printJobs)..where((db.$PrintJobsTable t) {
          return t.id.equals(existing.id);
        }))
        .write(
          db.PrintJobsCompanion(
            status: const Value<String>('failed'),
            updatedAt: Value<DateTime>(effectiveNow),
            lastError: Value<String?>(error),
            completedAt: const Value<DateTime?>.absent(),
          ),
        );

    return _mapPrintJob(await _findById(existing.id));
  }

  Future<PrintJob> markPrinted({
    required int transactionId,
    required PrintJobTarget target,
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final PrintJob existing = await ensureQueued(
      transactionId: transactionId,
      target: target,
      now: effectiveNow,
    );

    await (_database.update(_database.printJobs)..where((db.$PrintJobsTable t) {
          return t.id.equals(existing.id);
        }))
        .write(
          db.PrintJobsCompanion(
            status: const Value<String>('printed'),
            updatedAt: Value<DateTime>(effectiveNow),
            completedAt: Value<DateTime?>(effectiveNow),
            lastError: const Value<String?>(null),
          ),
        );

    return _mapPrintJob(await _findById(existing.id));
  }

  Future<db.PrintJob> _findById(int id) async {
    final db.PrintJob? row = await (_database.select(
      _database.printJobs,
    )..where((db.$PrintJobsTable t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw NotFoundException('Print job not found: $id');
    }
    return row;
  }

  PrintJob _mapPrintJob(db.PrintJob row) {
    return PrintJob(
      id: row.id,
      transactionId: row.transactionId,
      target: _targetFromDb(row.target),
      status: _statusFromDb(row.status),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      attemptCount: row.attemptCount,
      lastAttemptAt: row.lastAttemptAt,
      completedAt: row.completedAt,
      lastError: row.lastError,
    );
  }

  PrintJobTarget _targetFromDb(String value) {
    switch (value) {
      case 'kitchen':
        return PrintJobTarget.kitchen;
      case 'receipt':
        return PrintJobTarget.receipt;
      default:
        throw DatabaseException('Unknown print job target: $value');
    }
  }

  String _targetToDb(PrintJobTarget value) {
    switch (value) {
      case PrintJobTarget.kitchen:
        return 'kitchen';
      case PrintJobTarget.receipt:
        return 'receipt';
    }
  }

  PrintJobStatus _statusFromDb(String value) {
    switch (value) {
      case 'pending':
        return PrintJobStatus.pending;
      case 'printing':
        return PrintJobStatus.printing;
      case 'printed':
        return PrintJobStatus.printed;
      case 'failed':
        return PrintJobStatus.failed;
      default:
        throw DatabaseException('Unknown print job status: $value');
    }
  }

  bool _isUniqueTransactionTargetViolation(SqliteException error) {
    final String message = error.message.toLowerCase();
    return error.extendedResultCode == 2067 &&
        message.contains('print_jobs.transaction_id, print_jobs.target');
  }
}
