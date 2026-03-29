import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/order_lifecycle_policy.dart';
import '../../domain/models/transaction.dart';
import '../database/app_database.dart' as db;

class TransactionStateRepository {
  const TransactionStateRepository(this._database);

  final db.AppDatabase _database;

  Future<void> transitionDraftOrderToSent({required int transactionId}) async {
    final db.Transaction row = await _findTransactionByIdOrThrow(transactionId);
    final TransactionStatus currentStatus = _statusFromDb(row.status);
    OrderLifecyclePolicy.ensureCanTransition(
      from: currentStatus,
      to: TransactionStatus.sent,
    );

    final DateTime now = DateTime.now();
    final int updatedCount =
        await (_database.update(_database.transactions)
              ..where((db.$TransactionsTable t) => t.id.equals(transactionId)))
            .write(
              db.TransactionsCompanion(
                status: const Value<String>('sent'),
                updatedAt: Value<DateTime>(now),
              ),
            );
    if (updatedCount == 0) {
      throw DatabaseException('Failed to send transaction: $transactionId');
    }
  }

  Future<void> transitionSentOrderToCancelled({
    required int transactionId,
    required int cancelledByUserId,
  }) async {
    final db.Transaction row = await _findTransactionByIdOrThrow(transactionId);
    final TransactionStatus currentStatus = _statusFromDb(row.status);
    OrderLifecyclePolicy.ensureCanTransition(
      from: currentStatus,
      to: TransactionStatus.cancelled,
    );

    final int paymentCount = await _countPaymentsForTransaction(transactionId);
    if (paymentCount > 0) {
      throw InvalidStateTransitionException(
        'Cannot cancel transaction with existing payment.',
      );
    }

    final DateTime now = DateTime.now();
    final int updatedCount =
        await (_database.update(_database.transactions)
              ..where((db.$TransactionsTable t) => t.id.equals(transactionId)))
            .write(
              db.TransactionsCompanion(
                status: Value<String>(_statusToDb(TransactionStatus.cancelled)),
                cancelledAt: Value<DateTime?>(now),
                cancelledBy: Value<int?>(cancelledByUserId),
                paidAt: const Value<DateTime?>.absent(),
                updatedAt: Value<DateTime>(now),
              ),
            );
    if (updatedCount == 0) {
      throw DatabaseException('Failed to cancel transaction: $transactionId');
    }
  }

  Future<void> transitionSentOrderToPaid({
    required int transactionId,
    required DateTime paidAt,
  }) async {
    final db.Transaction row = await _findTransactionByIdOrThrow(transactionId);
    final TransactionStatus currentStatus = _statusFromDb(row.status);
    OrderLifecyclePolicy.ensureCanTransition(
      from: currentStatus,
      to: TransactionStatus.paid,
    );

    final int paymentCount = await _countPaymentsForTransaction(transactionId);
    if (paymentCount == 0) {
      throw InvalidStateTransitionException(
        'Cannot mark transaction paid without an existing payment.',
      );
    }
    if (paymentCount > 1) {
      throw DatabaseException(
        'Expected exactly one payment before marking transaction paid, found $paymentCount.',
      );
    }

    final int updatedCount =
        await (_database.update(_database.transactions)
              ..where((db.$TransactionsTable t) => t.id.equals(transactionId)))
            .write(
              db.TransactionsCompanion(
                status: Value<String>(_statusToDb(TransactionStatus.paid)),
                paidAt: Value<DateTime?>(paidAt),
                cancelledAt: const Value<DateTime?>.absent(),
                cancelledBy: const Value<int?>.absent(),
                updatedAt: Value<DateTime>(paidAt),
              ),
            );
    if (updatedCount == 0) {
      throw DatabaseException('Failed to update transaction to paid state.');
    }
  }

  Future<db.Transaction> _findTransactionByIdOrThrow(int id) async {
    final db.Transaction? row = await (_database.select(
      _database.transactions,
    )..where((db.$TransactionsTable t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw NotFoundException('Transaction not found: $id');
    }
    return row;
  }

  Future<int> _countPaymentsForTransaction(int transactionId) async {
    final Expression<int> countExpression = _database.payments.id.count();
    final TypedResult row =
        await (_database.selectOnly(_database.payments)
              ..addColumns(<Expression<int>>[countExpression])
              ..where(_database.payments.transactionId.equals(transactionId)))
            .getSingle();
    return row.read(countExpression) ?? 0;
  }

  TransactionStatus _statusFromDb(String value) {
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

  String _statusToDb(TransactionStatus value) {
    switch (value) {
      case TransactionStatus.draft:
        return 'draft';
      case TransactionStatus.sent:
        return 'sent';
      case TransactionStatus.paid:
        return 'paid';
      case TransactionStatus.cancelled:
        return 'cancelled';
    }
  }
}
