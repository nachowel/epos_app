import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/draft_order_policy.dart';
import '../../domain/models/shift_close_readiness.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/transaction.dart';
import '../database/app_database.dart' as db;

class ShiftRepository {
  const ShiftRepository(this._database);

  final db.AppDatabase _database;

  Future<Shift?> getOpenShift() async {
    final db.Shift? row =
        await (_database.select(_database.shifts)
              ..where(
                (db.$ShiftsTable t) =>
                    t.status.equals(_statusToDb(ShiftStatus.open)),
              )
              ..orderBy(<OrderingTerm Function(db.$ShiftsTable)>[
                (db.$ShiftsTable t) => OrderingTerm.desc(t.openedAt),
              ]))
            .getSingleOrNull();

    return row == null ? null : _mapShift(row);
  }

  Future<Shift?> getById(int shiftId) async {
    final db.Shift? row = await (_database.select(
      _database.shifts,
    )..where((db.$ShiftsTable t) => t.id.equals(shiftId))).getSingleOrNull();

    return row == null ? null : _mapShift(row);
  }

  Future<Shift> openShift(int userId) async {
    return _database.transaction(() async {
      final db.Shift? existing =
          await (_database.select(_database.shifts)..where(
                (db.$ShiftsTable t) =>
                    t.status.equals(_statusToDb(ShiftStatus.open)),
              ))
              .getSingleOrNull();
      if (existing != null) {
        throw ShiftAlreadyOpenException();
      }

      try {
        final int id = await _database
            .into(_database.shifts)
            .insert(
              db.ShiftsCompanion.insert(
                openedBy: userId,
                status: const Value<String>('open'),
              ),
            );
        final db.Shift created = await _findShiftByIdOrThrow(id);
        return _mapShift(created);
      } on SqliteException catch (e) {
        if (_isSingleOpenShiftConstraint(e)) {
          throw ShiftAlreadyOpenException();
        }
        rethrow;
      }
    });
  }

  Future<void> closeShift(int shiftId, int userId, {DateTime? now}) async {
    await _database.transaction(() async {
      final db.Shift? row = await (_database.select(
        _database.shifts,
      )..where((db.$ShiftsTable t) => t.id.equals(shiftId))).getSingleOrNull();

      if (row == null) {
        throw NotFoundException('Shift not found: $shiftId');
      }
      if (_statusFromDb(row.status) != ShiftStatus.open) {
        throw ShiftClosedException();
      }

      final ShiftCloseReadiness readiness = await getShiftCloseReadiness(
        shiftId,
        now: now,
      );
      if (!readiness.canFinalClose) {
        throw ShiftCloseBlockedException(readiness);
      }

      final int updatedCount =
          await (_database.update(
            _database.shifts,
          )..where((db.$ShiftsTable t) => t.id.equals(shiftId))).write(
            db.ShiftsCompanion(
              status: Value<String>(_statusToDb(ShiftStatus.closed)),
              closedBy: Value<int?>(userId),
              closedAt: Value<DateTime?>(now ?? DateTime.now()),
            ),
          );

      if (updatedCount == 0) {
        throw DatabaseException('Failed to close shift: $shiftId');
      }
    });
  }

  Future<Shift> markCashierPreview({
    required int shiftId,
    required int userId,
  }) async {
    return _database.transaction(() async {
      final db.Shift row = await _findShiftByIdOrThrow(shiftId);
      if (_statusFromDb(row.status) != ShiftStatus.open) {
        throw ShiftClosedException();
      }

      final DateTime previewedAt = row.cashierPreviewedAt ?? DateTime.now();
      final int previewedBy = row.cashierPreviewedBy ?? userId;

      final int updatedCount =
          await (_database.update(
            _database.shifts,
          )..where((db.$ShiftsTable t) => t.id.equals(shiftId))).write(
            db.ShiftsCompanion(
              cashierPreviewedBy: Value<int?>(previewedBy),
              cashierPreviewedAt: Value<DateTime?>(previewedAt),
            ),
          );

      if (updatedCount == 0) {
        throw DatabaseException('Failed to mark cashier preview: $shiftId');
      }

      final db.Shift refreshed = await _findShiftByIdOrThrow(shiftId);
      return _mapShift(refreshed);
    });
  }

  Future<List<Shift>> getRecentShifts({int limit = 50}) async {
    final List<db.Shift> rows =
        await (_database.select(_database.shifts)
              ..orderBy(<OrderingTerm Function(db.$ShiftsTable)>[
                (db.$ShiftsTable t) => OrderingTerm.desc(t.openedAt),
                (db.$ShiftsTable t) => OrderingTerm.desc(t.id),
              ])
              ..limit(limit))
            .get();

    return rows.map(_mapShift).toList(growable: false);
  }

  Future<ShiftCloseReadiness> getShiftCloseReadiness(
    int shiftId, {
    DateTime? now,
  }) async {
    final DateTime effectiveNow = now ?? DateTime.now();
    final List<db.Transaction> rows =
        await (_database.select(_database.transactions)
              ..where((db.$TransactionsTable t) {
                return t.shiftId.equals(shiftId) &
                    (t.status.equals('draft') | t.status.equals('sent'));
              }))
            .get();

    int sentOrderCount = 0;
    int freshDraftCount = 0;
    int staleDraftCount = 0;

    for (final db.Transaction row in rows) {
      final Transaction transaction = _mapTransaction(row);
      if (transaction.status == TransactionStatus.sent) {
        sentOrderCount += 1;
        continue;
      }
      if (DraftOrderPolicy.isStale(transaction, now: effectiveNow)) {
        staleDraftCount += 1;
      } else {
        freshDraftCount += 1;
      }
    }

    return ShiftCloseReadiness(
      sentOrderCount: sentOrderCount,
      freshDraftCount: freshDraftCount,
      staleDraftCount: staleDraftCount,
    );
  }

  Future<db.Shift> _findShiftByIdOrThrow(int id) async {
    final db.Shift? shiftRow = await (_database.select(
      _database.shifts,
    )..where((db.$ShiftsTable t) => t.id.equals(id))).getSingleOrNull();
    if (shiftRow == null) {
      throw DatabaseException('Shift not found after insert: $id');
    }
    return shiftRow;
  }

  Shift _mapShift(db.Shift row) {
    return Shift(
      id: row.id,
      openedBy: row.openedBy,
      openedAt: row.openedAt,
      closedBy: row.closedBy,
      closedAt: row.closedAt,
      cashierPreviewedBy: row.cashierPreviewedBy,
      cashierPreviewedAt: row.cashierPreviewedAt,
      status: _statusFromDb(row.status),
    );
  }

  Transaction _mapTransaction(db.Transaction row) {
    return Transaction(
      id: row.id,
      uuid: row.uuid,
      shiftId: row.shiftId,
      userId: row.userId,
      tableNumber: row.tableNumber,
      status: _transactionStatusFromDb(row.status),
      subtotalMinor: row.subtotalMinor,
      modifierTotalMinor: row.modifierTotalMinor,
      totalAmountMinor: row.totalAmountMinor,
      createdAt: row.createdAt,
      paidAt: row.paidAt,
      updatedAt: row.updatedAt,
      cancelledAt: row.cancelledAt,
      cancelledBy: row.cancelledBy,
      idempotencyKey: row.idempotencyKey,
      kitchenPrinted: row.kitchenPrinted,
      receiptPrinted: row.receiptPrinted,
    );
  }

  ShiftStatus _statusFromDb(String value) {
    switch (value) {
      case 'open':
        return ShiftStatus.open;
      case 'closed':
        return ShiftStatus.closed;
      default:
        throw DatabaseException('Unknown shift status: $value');
    }
  }

  String _statusToDb(ShiftStatus value) {
    switch (value) {
      case ShiftStatus.open:
        return 'open';
      case ShiftStatus.closed:
        return 'closed';
      case ShiftStatus.locked:
        throw ArgumentError.value(
          value,
          'value',
          'Locked is an effective UI status and cannot be persisted.',
        );
    }
  }

  TransactionStatus _transactionStatusFromDb(String value) {
    switch (value) {
      case 'draft':
        return TransactionStatus.draft;
      case 'sent':
        return TransactionStatus.sent;
      case 'paid':
        return TransactionStatus.paid;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        throw DatabaseException('Unknown transaction status: $value');
    }
  }

  bool _isSingleOpenShiftConstraint(SqliteException error) {
    final String message = error.message.toLowerCase();
    return error.extendedResultCode == 2067 &&
        (message.contains('ux_shifts_single_open') ||
            message.contains('shifts.status'));
  }
}
