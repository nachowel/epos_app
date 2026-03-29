import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/transaction.dart';
import '../database/app_database.dart' as db;

class PaymentRepository {
  const PaymentRepository(this._database);

  final db.AppDatabase _database;

  Future<Payment?> getById(int paymentId) async {
    final db.Payment? row =
        await (_database.select(_database.payments)
              ..where((db.$PaymentsTable t) => t.id.equals(paymentId)))
            .getSingleOrNull();

    return row == null ? null : _mapPayment(row);
  }

  Future<Payment?> getByTransactionId(int transactionId) async {
    final db.Payment? row =
        await (_database.select(_database.payments)..where(
              (db.$PaymentsTable t) => t.transactionId.equals(transactionId),
            ))
            .getSingleOrNull();

    return row == null ? null : _mapPayment(row);
  }

  Future<List<Payment>> getByShift(int shiftId) async {
    final List<db.Payment> rows =
        await (_database.select(_database.payments).join([
                innerJoin(
                  _database.transactions,
                  _database.transactions.id.equalsExp(
                    _database.payments.transactionId,
                  ),
                ),
              ])
              ..where(_database.transactions.shiftId.equals(shiftId))
              ..orderBy([
                OrderingTerm.desc(_database.payments.paidAt),
                OrderingTerm.desc(_database.payments.id),
              ]))
            .map((TypedResult row) => row.readTable(_database.payments))
            .get();

    return rows.map(_mapPayment).toList(growable: false);
  }

  Future<Payment> createPayment({
    required int transactionId,
    required String uuid,
    required PaymentMethod method,
    required int amountMinor,
    DateTime? paidAt,
  }) async {
    final db.Transaction? txRow =
        await (_database.select(_database.transactions)
              ..where((db.$TransactionsTable t) => t.id.equals(transactionId)))
            .getSingleOrNull();
    if (txRow == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
    if (_txStatusFromDb(txRow.status) != TransactionStatus.sent) {
      throw InvalidStateTransitionException(
        'Payment can be created only for sent transactions.',
      );
    }
    if (amountMinor != txRow.totalAmountMinor) {
      throw PaymentAmountMismatchException(
        expectedMinor: txRow.totalAmountMinor,
        actualMinor: amountMinor,
      );
    }

    final DateTime effectivePaidAt = paidAt ?? DateTime.now();
    try {
      final int paymentId = await _database
          .into(_database.payments)
          .insert(
            db.PaymentsCompanion.insert(
              uuid: uuid,
              transactionId: transactionId,
              method: _paymentMethodToDb(method),
              amountMinor: amountMinor,
              paidAt: Value<DateTime>(effectivePaidAt),
            ),
          );

      final db.Payment? inserted =
          await (_database.select(_database.payments)
                ..where((db.$PaymentsTable t) => t.id.equals(paymentId)))
              .getSingleOrNull();
      if (inserted == null) {
        throw DatabaseException('Payment not found after insert.');
      }
      return _mapPayment(inserted);
    } on SqliteException catch (error) {
      if (_isUniqueTransactionPaymentViolation(error)) {
        throw DuplicatePaymentException();
      }
      rethrow;
    }
  }

  bool _isUniqueTransactionPaymentViolation(SqliteException error) {
    final String message = error.message.toLowerCase();
    return error.extendedResultCode == 2067 &&
        message.contains('payments.transaction_id');
  }

  Payment _mapPayment(db.Payment row) {
    return Payment(
      id: row.id,
      uuid: row.uuid,
      transactionId: row.transactionId,
      method: _paymentMethodFromDb(row.method),
      amountMinor: row.amountMinor,
      paidAt: row.paidAt,
    );
  }

  PaymentMethod _paymentMethodFromDb(String value) {
    switch (value) {
      case 'cash':
        return PaymentMethod.cash;
      case 'card':
        return PaymentMethod.card;
      default:
        throw DatabaseException('Unknown payment method: $value');
    }
  }

  String _paymentMethodToDb(PaymentMethod value) {
    switch (value) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.card:
        return 'card';
    }
  }

  TransactionStatus _txStatusFromDb(String value) {
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
}
