import 'package:drift/drift.dart';

import '../database/app_database.dart' as db;
import 'phase1_sync_contract.dart';
import 'phase1_sync_payload_mapper.dart';
import 'sync_transaction_graph.dart';

class SyncPayloadRepository {
  const SyncPayloadRepository(
    this._database, {
    Phase1SyncPayloadMapper payloadMapper = const Phase1SyncPayloadMapper(),
  }) : _payloadMapper = payloadMapper;

  final db.AppDatabase _database;
  final Phase1SyncPayloadMapper _payloadMapper;

  Future<String?> resolveTransactionUuid({
    required String tableName,
    required String recordUuid,
  }) async {
    switch (tableName) {
      case 'transactions':
        final db.Transaction? transaction =
            await (_database.select(_database.transactions)..where(
                  (db.$TransactionsTable t) => t.uuid.equals(recordUuid),
                ))
                .getSingleOrNull();
        return transaction?.uuid;
      case 'transaction_lines':
        final db.TransactionLine? line =
            await (_database.select(_database.transactionLines)..where(
                  (db.$TransactionLinesTable t) => t.uuid.equals(recordUuid),
                ))
                .getSingleOrNull();
        if (line == null) {
          return null;
        }
        final db.Transaction? transaction =
            await (_database.select(_database.transactions)..where(
                  (db.$TransactionsTable t) => t.id.equals(line.transactionId),
                ))
                .getSingleOrNull();
        return transaction?.uuid;
      case 'order_modifiers':
        final db.OrderModifier? modifier =
            await (_database.select(_database.orderModifiers)..where(
                  (db.$OrderModifiersTable t) => t.uuid.equals(recordUuid),
                ))
                .getSingleOrNull();
        if (modifier == null) {
          return null;
        }
        final db.TransactionLine? line =
            await (_database.select(_database.transactionLines)..where(
                  (db.$TransactionLinesTable t) =>
                      t.id.equals(modifier.transactionLineId),
                ))
                .getSingleOrNull();
        if (line == null) {
          return null;
        }
        final db.Transaction? transaction =
            await (_database.select(_database.transactions)..where(
                  (db.$TransactionsTable t) => t.id.equals(line.transactionId),
                ))
                .getSingleOrNull();
        return transaction?.uuid;
      case 'payments':
        final db.Payment? payment =
            await (_database.select(_database.payments)
                  ..where((db.$PaymentsTable t) => t.uuid.equals(recordUuid)))
                .getSingleOrNull();
        if (payment == null) {
          return null;
        }
        final db.Transaction? transaction =
            await (_database.select(_database.transactions)..where(
                  (db.$TransactionsTable t) =>
                      t.id.equals(payment.transactionId),
                ))
                .getSingleOrNull();
        return transaction?.uuid;
      default:
        throw ArgumentError.value(
          tableName,
          'tableName',
          'Unsupported sync table',
        );
    }
  }

  Future<SyncTransactionGraph?> buildTransactionGraph(
    String transactionUuid,
  ) async {
    final db.Transaction? transaction =
        await (_database.select(_database.transactions)..where(
              (db.$TransactionsTable t) => t.uuid.equals(transactionUuid),
            ))
            .getSingleOrNull();
    if (transaction == null) {
      return null;
    }
    // Local truth is created and finalized in Drift. The remote mirror accepts
    // only finalized snapshots, never local in-progress order state.
    if (!Phase1SyncContract.isTerminalTransactionStatus(transaction.status)) {
      throw StateError('Only finalized local transactions may be mirrored.');
    }

    final Map<String, Object?> transactionPayload =
        await _buildTransactionPayload(transactionUuid) ??
        (throw StateError('Transaction payload missing for $transactionUuid.'));

    final List<db.TransactionLine> lineRows =
        await (_database.select(_database.transactionLines)
              ..where(
                (db.$TransactionLinesTable t) =>
                    t.transactionId.equals(transaction.id),
              )
              ..orderBy(<OrderingTerm Function(db.$TransactionLinesTable)>[
                (db.$TransactionLinesTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    final List<SyncGraphRecord> records = <SyncGraphRecord>[
      SyncGraphRecord(
        tableName: 'transactions',
        recordUuid: transaction.uuid,
        payload: transactionPayload,
        idempotencyKey: transaction.idempotencyKey,
      ),
    ];

    for (final db.TransactionLine line in lineRows) {
      final Map<String, Object?> linePayload =
          await _buildTransactionLinePayload(line.uuid) ??
          (throw StateError(
            'Transaction line payload missing for ${line.uuid}.',
          ));
      records.add(
        SyncGraphRecord(
          tableName: 'transaction_lines',
          recordUuid: line.uuid,
          payload: linePayload,
          idempotencyKey: '${transaction.idempotencyKey}:line:${line.uuid}',
        ),
      );
    }

    final List<TypedResult> modifierRows =
        await (_database.select(_database.orderModifiers).join(<Join>[
                innerJoin(
                  _database.transactionLines,
                  _database.transactionLines.id.equalsExp(
                    _database.orderModifiers.transactionLineId,
                  ),
                ),
              ])
              ..where(
                _database.transactionLines.transactionId.equals(transaction.id),
              )
              ..orderBy(<OrderingTerm>[
                OrderingTerm.asc(_database.transactionLines.id),
                OrderingTerm.asc(_database.orderModifiers.sortKey),
                OrderingTerm.asc(_database.orderModifiers.id),
              ]))
            .get();

    for (final TypedResult row in modifierRows) {
      final db.OrderModifier modifier = row.readTable(_database.orderModifiers);
      final Map<String, Object?> modifierPayload =
          await _buildOrderModifierPayload(modifier.uuid) ??
          (throw StateError(
            'Order modifier payload missing for ${modifier.uuid}.',
          ));
      records.add(
        SyncGraphRecord(
          tableName: 'order_modifiers',
          recordUuid: modifier.uuid,
          payload: modifierPayload,
          idempotencyKey:
              '${transaction.idempotencyKey}:modifier:${modifier.uuid}',
        ),
      );
    }

    final db.Payment? payment =
        await (_database.select(_database.payments)..where(
              (db.$PaymentsTable t) => t.transactionId.equals(transaction.id),
            ))
            .getSingleOrNull();
    if (transaction.status == 'paid' && payment == null) {
      throw StateError(
        'PAID transaction graph requires a payment snapshot for $transactionUuid.',
      );
    }
    if (payment != null) {
      final Map<String, Object?> paymentPayload =
          await _buildPaymentPayload(payment.uuid) ??
          (throw StateError('Payment payload missing for ${payment.uuid}.'));
      records.add(
        SyncGraphRecord(
          tableName: 'payments',
          recordUuid: payment.uuid,
          payload: paymentPayload,
          idempotencyKey:
              '${transaction.idempotencyKey}:payment:${payment.uuid}',
        ),
      );
    }

    return SyncTransactionGraph(
      transactionUuid: transaction.uuid,
      transactionIdempotencyKey: transaction.idempotencyKey,
      records: records,
    );
  }

  Future<Map<String, Object?>?> buildPayload({
    required String tableName,
    required String recordUuid,
  }) async {
    switch (tableName) {
      case 'transactions':
        return _buildTransactionPayload(recordUuid);
      case 'transaction_lines':
        return _buildTransactionLinePayload(recordUuid);
      case 'order_modifiers':
        return _buildOrderModifierPayload(recordUuid);
      case 'payments':
        return _buildPaymentPayload(recordUuid);
      default:
        throw ArgumentError.value(
          tableName,
          'tableName',
          'Unsupported sync table',
        );
    }
  }

  Future<Map<String, Object?>?> _buildTransactionPayload(String uuid) async {
    final db.Transaction? row =
        await (_database.select(_database.transactions)
              ..where((db.$TransactionsTable t) => t.uuid.equals(uuid)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    return _payloadMapper.transactionPayload(row);
  }

  Future<Map<String, Object?>?> _buildTransactionLinePayload(
    String uuid,
  ) async {
    final db.TransactionLine? row =
        await (_database.select(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) => t.uuid.equals(uuid)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    final db.Transaction? transaction =
        await (_database.select(_database.transactions)..where(
              (db.$TransactionsTable t) => t.id.equals(row.transactionId),
            ))
            .getSingleOrNull();
    if (transaction == null) {
      return null;
    }

    return _payloadMapper.transactionLinePayload(
      row: row,
      transactionUuid: transaction.uuid,
    );
  }

  Future<Map<String, Object?>?> _buildOrderModifierPayload(String uuid) async {
    final db.OrderModifier? row =
        await (_database.select(_database.orderModifiers)
              ..where((db.$OrderModifiersTable t) => t.uuid.equals(uuid)))
            .getSingleOrNull();
    if (row == null) {
      return null;
    }

    final db.TransactionLine? line =
        await (_database.select(_database.transactionLines)..where(
              (db.$TransactionLinesTable t) =>
                  t.id.equals(row.transactionLineId),
            ))
            .getSingleOrNull();
    if (line == null) {
      return null;
    }

    return _payloadMapper.orderModifierPayload(
      row: row,
      transactionLineUuid: line.uuid,
    );
  }

  Future<Map<String, Object?>?> _buildPaymentPayload(String uuid) async {
    final db.Payment? row = await (_database.select(
      _database.payments,
    )..where((db.$PaymentsTable t) => t.uuid.equals(uuid))).getSingleOrNull();
    if (row == null) {
      return null;
    }

    final db.Transaction? transaction =
        await (_database.select(_database.transactions)..where(
              (db.$TransactionsTable t) => t.id.equals(row.transactionId),
            ))
            .getSingleOrNull();
    if (transaction == null) {
      return null;
    }

    return _payloadMapper.paymentPayload(
      row: row,
      transactionUuid: transaction.uuid,
    );
  }
}
