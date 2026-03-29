import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/payment_adjustment.dart';
import '../database/app_database.dart' as db;

class PaymentAdjustmentRepository {
  const PaymentAdjustmentRepository(this._database);

  final db.AppDatabase _database;

  Future<PaymentAdjustment?> getByPaymentId(int paymentId) async {
    final db.PaymentAdjustment? row =
        await (_database.select(_database.paymentAdjustments)..where(
              (db.$PaymentAdjustmentsTable t) => t.paymentId.equals(paymentId),
            ))
            .getSingleOrNull();
    return row == null ? null : _mapAdjustment(row);
  }

  Future<PaymentAdjustment?> getByTransactionId(int transactionId) async {
    final db.PaymentAdjustment? row =
        await (_database.select(_database.paymentAdjustments)..where(
              (db.$PaymentAdjustmentsTable t) =>
                  t.transactionId.equals(transactionId),
            ))
            .getSingleOrNull();
    return row == null ? null : _mapAdjustment(row);
  }

  Future<List<PaymentAdjustment>> getByShift(int shiftId) async {
    final List<db.PaymentAdjustment> rows =
        await (_database.select(_database.paymentAdjustments).join([
                innerJoin(
                  _database.transactions,
                  _database.transactions.id.equalsExp(
                    _database.paymentAdjustments.transactionId,
                  ),
                ),
              ])
              ..where(_database.transactions.shiftId.equals(shiftId))
              ..orderBy([
                OrderingTerm.desc(_database.paymentAdjustments.createdAt),
                OrderingTerm.desc(_database.paymentAdjustments.id),
              ]))
            .map(
              (TypedResult row) => row.readTable(_database.paymentAdjustments),
            )
            .get();

    return rows.map(_mapAdjustment).toList(growable: false);
  }

  Future<PaymentAdjustment> createAdjustment({
    required String uuid,
    required int paymentId,
    required int transactionId,
    required PaymentAdjustmentType type,
    required PaymentAdjustmentStatus status,
    required int amountMinor,
    required String reason,
    required int createdBy,
    DateTime? createdAt,
  }) async {
    try {
      final int adjustmentId = await _database
          .into(_database.paymentAdjustments)
          .insert(
            db.PaymentAdjustmentsCompanion.insert(
              uuid: uuid,
              paymentId: paymentId,
              transactionId: transactionId,
              type: Value<String>(_typeToDb(type)),
              status: Value<String>(_statusToDb(status)),
              amountMinor: amountMinor,
              reason: reason,
              createdBy: createdBy,
              createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
            ),
          );

      final db.PaymentAdjustment? inserted =
          await (_database.select(_database.paymentAdjustments)
                ..where(
                  (db.$PaymentAdjustmentsTable t) => t.id.equals(adjustmentId),
                ))
              .getSingleOrNull();
      if (inserted == null) {
        throw DatabaseException('Payment adjustment not found after insert.');
      }
      return _mapAdjustment(inserted);
    } on SqliteException catch (error) {
      if (_isUniquePaymentConstraint(error)) {
        throw DuplicatePaymentAdjustmentException();
      }
      rethrow;
    }
  }

  PaymentAdjustment _mapAdjustment(db.PaymentAdjustment row) {
    return PaymentAdjustment(
      id: row.id,
      uuid: row.uuid,
      paymentId: row.paymentId,
      transactionId: row.transactionId,
      type: _typeFromDb(row.type),
      status: _statusFromDb(row.status),
      amountMinor: row.amountMinor,
      reason: row.reason,
      createdBy: row.createdBy,
      createdAt: row.createdAt,
    );
  }

  PaymentAdjustmentType _typeFromDb(String value) {
    switch (value) {
      case 'refund':
        return PaymentAdjustmentType.refund;
      case 'reversal':
        return PaymentAdjustmentType.reversal;
      default:
        throw DatabaseException('Unknown payment adjustment type: $value');
    }
  }

  String _typeToDb(PaymentAdjustmentType value) {
    switch (value) {
      case PaymentAdjustmentType.refund:
        return 'refund';
      case PaymentAdjustmentType.reversal:
        return 'reversal';
    }
  }

  PaymentAdjustmentStatus _statusFromDb(String value) {
    switch (value) {
      case 'completed':
        return PaymentAdjustmentStatus.completed;
      default:
        throw DatabaseException('Unknown payment adjustment status: $value');
    }
  }

  String _statusToDb(PaymentAdjustmentStatus value) {
    switch (value) {
      case PaymentAdjustmentStatus.completed:
        return 'completed';
    }
  }

  bool _isUniquePaymentConstraint(SqliteException error) {
    final String message = error.message.toLowerCase();
    return error.extendedResultCode == 2067 &&
        (message.contains('payment_adjustments.payment_id') ||
            message.contains('ux_payment_adjustments_unique_payment'));
  }
}
