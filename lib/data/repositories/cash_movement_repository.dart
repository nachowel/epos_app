import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/cash_movement.dart';
import '../database/app_database.dart' as db;

class CashMovementRepository {
  const CashMovementRepository(this._database);

  final db.AppDatabase _database;

  Future<CashMovement> createCashMovement({
    required int shiftId,
    required CashMovementType type,
    required String category,
    required int amountMinor,
    required CashMovementPaymentMethod paymentMethod,
    String? note,
    required int createdByUserId,
    DateTime? createdAt,
  }) async {
    await _ensureShiftExists(shiftId);
    await _ensureUserExists(createdByUserId);

    final int movementId = await _database
        .into(_database.cashMovements)
        .insert(
          db.CashMovementsCompanion.insert(
            shiftId: shiftId,
            type: _typeToDb(type),
            category: category,
            amountMinor: amountMinor,
            paymentMethod: _paymentMethodToDb(paymentMethod),
            note: Value<String?>(note),
            createdByUserId: createdByUserId,
            createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
          ),
        );

    final db.CashMovement? inserted =
        await (_database.select(_database.cashMovements)
              ..where((db.$CashMovementsTable t) => t.id.equals(movementId)))
            .getSingleOrNull();
    if (inserted == null) {
      throw DatabaseException('Cash movement not found after insert.');
    }

    return _mapCashMovement(inserted);
  }

  Future<List<CashMovement>> listCashMovementsForShift(int shiftId) async {
    final List<db.CashMovement> rows =
        await (_database.select(_database.cashMovements)
              ..where((db.$CashMovementsTable t) => t.shiftId.equals(shiftId))
              ..orderBy(<OrderingTerm Function(db.$CashMovementsTable)>[
                (db.$CashMovementsTable t) => OrderingTerm.desc(t.createdAt),
                (db.$CashMovementsTable t) => OrderingTerm.desc(t.id),
              ]))
            .get();

    return rows.map(_mapCashMovement).toList(growable: false);
  }

  Future<List<CashMovement>> listRecentCashMovements({int limit = 50}) async {
    final List<db.CashMovement> rows =
        await (_database.select(_database.cashMovements)
              ..orderBy(<OrderingTerm Function(db.$CashMovementsTable)>[
                (db.$CashMovementsTable t) => OrderingTerm.desc(t.createdAt),
                (db.$CashMovementsTable t) => OrderingTerm.desc(t.id),
              ])
              ..limit(limit))
            .get();

    return rows.map(_mapCashMovement).toList(growable: false);
  }

  Future<void> _ensureShiftExists(int shiftId) async {
    final db.Shift? shift = await (_database.select(
      _database.shifts,
    )..where((db.$ShiftsTable t) => t.id.equals(shiftId))).getSingleOrNull();
    if (shift == null) {
      throw ValidationException('Cash movement shift is invalid.');
    }
  }

  Future<void> _ensureUserExists(int userId) async {
    final db.User? user = await (_database.select(
      _database.users,
    )..where((db.$UsersTable t) => t.id.equals(userId))).getSingleOrNull();
    if (user == null) {
      throw ValidationException('Cash movement actor is invalid.');
    }
  }

  CashMovement _mapCashMovement(db.CashMovement row) {
    return CashMovement(
      id: row.id,
      shiftId: row.shiftId,
      type: _typeFromDb(row.type),
      category: row.category,
      amountMinor: row.amountMinor,
      paymentMethod: _paymentMethodFromDb(row.paymentMethod),
      note: row.note,
      createdByUserId: row.createdByUserId,
      createdAt: row.createdAt,
    );
  }

  CashMovementType _typeFromDb(String value) {
    switch (value) {
      case 'income':
        return CashMovementType.income;
      case 'expense':
        return CashMovementType.expense;
      default:
        throw DatabaseException('Unknown cash movement type: $value');
    }
  }

  String _typeToDb(CashMovementType value) {
    switch (value) {
      case CashMovementType.income:
        return 'income';
      case CashMovementType.expense:
        return 'expense';
    }
  }

  CashMovementPaymentMethod _paymentMethodFromDb(String value) {
    switch (value) {
      case 'cash':
        return CashMovementPaymentMethod.cash;
      case 'card':
        return CashMovementPaymentMethod.card;
      case 'other':
        return CashMovementPaymentMethod.other;
      default:
        throw DatabaseException('Unknown cash movement payment method: $value');
    }
  }

  String _paymentMethodToDb(CashMovementPaymentMethod value) {
    switch (value) {
      case CashMovementPaymentMethod.cash:
        return 'cash';
      case CashMovementPaymentMethod.card:
        return 'card';
      case CashMovementPaymentMethod.other:
        return 'other';
    }
  }
}
