import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/order_lifecycle_policy.dart';
import '../../domain/models/shift_report_category_line.dart';
import 'sync_queue_repository.dart';
import '../../domain/models/order_modifier.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/transaction_line.dart';
import '../database/app_database.dart' as db;

class TransactionRepository {
  TransactionRepository(
    this._database, {
    Uuid? uuidGenerator,
    SyncQueueRepository? syncQueueRepository,
  }) : _uuidGenerator = uuidGenerator ?? const Uuid(),
       _syncQueueRepository = syncQueueRepository;

  final db.AppDatabase _database;
  final Uuid _uuidGenerator;
  final SyncQueueRepository? _syncQueueRepository;

  Future<T> runInTransaction<T>(Future<T> Function() action) {
    return _database.transaction(action);
  }

  Future<Transaction?> getById(int id) async {
    final db.Transaction? row = await (_database.select(
      _database.transactions,
    )..where((db.$TransactionsTable t) => t.id.equals(id))).getSingleOrNull();

    return row == null ? null : _mapTransaction(row);
  }

  Future<Transaction?> getByUuid(String uuid) async {
    final db.Transaction? row =
        await (_database.select(_database.transactions)
              ..where((db.$TransactionsTable t) => t.uuid.equals(uuid)))
            .getSingleOrNull();

    return row == null ? null : _mapTransaction(row);
  }

  Future<({bool isActive, bool isVisibleOnPos})?> getProductSaleAvailability(
    int productId,
  ) async {
    final TypedResult? row =
        await (_database.selectOnly(_database.products)
              ..addColumns(<Expression<Object>>[
                _database.products.isActive,
                _database.products.isVisibleOnPos,
              ])
              ..where(_database.products.id.equals(productId)))
            .getSingleOrNull();

    if (row == null) {
      return null;
    }

    return (
      isActive: row.read(_database.products.isActive)!,
      isVisibleOnPos: row.read(_database.products.isVisibleOnPos)!,
    );
  }

  Future<List<Transaction>> getByShift(int shiftId) async {
    final List<db.Transaction> rows =
        await (_database.select(_database.transactions)
              ..where((db.$TransactionsTable t) => t.shiftId.equals(shiftId))
              ..orderBy(<OrderingTerm Function(db.$TransactionsTable)>[
                (db.$TransactionsTable t) => OrderingTerm.desc(t.createdAt),
                (db.$TransactionsTable t) => OrderingTerm.desc(t.id),
              ]))
            .get();

    return rows.map(_mapTransaction).toList(growable: false);
  }

  Future<List<Transaction>> getActiveOrders({int? shiftId}) async {
    final query = _database.select(_database.transactions)
      ..where((db.$TransactionsTable t) {
        return t.status.equals('draft') | t.status.equals('sent');
      })
      ..orderBy(<OrderingTerm Function(db.$TransactionsTable)>[
        (db.$TransactionsTable t) => OrderingTerm.asc(t.createdAt),
        (db.$TransactionsTable t) => OrderingTerm.asc(t.id),
      ]);

    if (shiftId != null) {
      query.where((db.$TransactionsTable t) => t.shiftId.equals(shiftId));
    }

    final List<db.Transaction> rows = await query.get();
    return rows.map(_mapTransaction).toList(growable: false);
  }

  Future<List<Transaction>> getByShiftAndStatus(
    int shiftId,
    TransactionStatus status,
  ) async {
    final List<db.Transaction> rows =
        await (_database.select(_database.transactions)
              ..where((db.$TransactionsTable t) {
                return t.shiftId.equals(shiftId) &
                    t.status.equals(_statusToDb(status));
              })
              ..orderBy(<OrderingTerm Function(db.$TransactionsTable)>[
                (db.$TransactionsTable t) => OrderingTerm.desc(t.createdAt),
                (db.$TransactionsTable t) => OrderingTerm.desc(t.id),
              ]))
            .get();

    return rows.map(_mapTransaction).toList(growable: false);
  }

  Future<List<ShiftReportCategoryLine>> getPaidCategoryTotalsForShift(
    int shiftId,
  ) async {
    final List<QueryRow> rows = await _database
        .customSelect(
          '''
        SELECT
          categories.name AS category_name,
          SUM(transaction_lines.line_total_minor) AS total_minor
        FROM transaction_lines
        INNER JOIN transactions
          ON transactions.id = transaction_lines.transaction_id
        INNER JOIN products
          ON products.id = transaction_lines.product_id
        INNER JOIN categories
          ON categories.id = products.category_id
        WHERE transactions.shift_id = ?
          AND transactions.status = 'paid'
        GROUP BY categories.id, categories.name
        ORDER BY categories.name ASC, categories.id ASC
      ''',
          variables: <Variable<Object>>[Variable<int>(shiftId)],
        )
        .get();

    return rows
        .map((QueryRow row) {
          return ShiftReportCategoryLine(
            categoryName: row.read<String>('category_name'),
            totalMinor: row.read<int>('total_minor'),
          );
        })
        .toList(growable: false);
  }

  Future<List<Transaction>> getPaidTransactionsBetween({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final List<db.Transaction> rows =
        await (_database.select(_database.transactions)
              ..where((db.$TransactionsTable t) {
                return t.status.equals('paid') &
                    t.paidAt.isBiggerOrEqualValue(startInclusive) &
                    t.paidAt.isSmallerThanValue(endExclusive);
              })
              ..orderBy(<OrderingTerm Function(db.$TransactionsTable)>[
                (db.$TransactionsTable t) => OrderingTerm.desc(t.paidAt),
                (db.$TransactionsTable t) => OrderingTerm.desc(t.id),
              ]))
            .get();

    return rows.map(_mapTransaction).toList(growable: false);
  }

  Future<Transaction> createTransaction({
    required int shiftId,
    required int userId,
    int? tableNumber,
    required String uuid,
    required String idempotencyKey,
  }) async {
    return runInTransaction(() async {
      final DateTime now = DateTime.now();
      try {
        final int createdId = await _database
            .into(_database.transactions)
            .insert(
              db.TransactionsCompanion.insert(
                uuid: uuid,
                shiftId: shiftId,
                userId: userId,
                idempotencyKey: idempotencyKey,
                updatedAt: now,
                tableNumber: Value<int?>(tableNumber),
                status: const Value<String>('draft'),
              ),
            );
        final db.Transaction created = await _findTransactionByIdOrThrow(
          createdId,
        );
        return _mapTransaction(created);
      } on SqliteException catch (error) {
        if (_isUniqueIdempotencyViolation(error)) {
          final db.Transaction? existingByIdempotency =
              await (_database.select(_database.transactions)
                    ..where((db.$TransactionsTable t) {
                      return t.idempotencyKey.equals(idempotencyKey);
                    }))
                  .getSingleOrNull();

          if (existingByIdempotency == null) {
            throw DatabaseException(
              'idempotency conflict detected but no existing transaction found.',
            );
          }
          return _mapTransaction(existingByIdempotency);
        }
        rethrow;
      }
    });
  }

  Future<TransactionLine> addLine({
    required int transactionId,
    required int productId,
    required int quantity,
  }) async {
    if (quantity <= 0) {
      throw ValidationException('Quantity must be greater than zero.');
    }

    await _ensureTransactionIsDraft(transactionId);

    final db.Product? productRow =
        await (_database.select(_database.products)
              ..where((db.$ProductsTable t) {
                return t.id.equals(productId) &
                    t.isActive.equals(true) &
                    t.isVisibleOnPos.equals(true);
              }))
            .getSingleOrNull();
    if (productRow == null) {
      throw ValidationException('Product is not available for sale.');
    }

    final int lineId = await _database
        .into(_database.transactionLines)
        .insert(
          db.TransactionLinesCompanion.insert(
            uuid: _uuidGenerator.v4(),
            transactionId: transactionId,
            productId: productId,
            productName: productRow.name,
            unitPriceMinor: productRow.priceMinor,
            quantity: Value<int>(quantity),
            lineTotalMinor: productRow.priceMinor * quantity,
          ),
        );

    final db.TransactionLine insertedLine = await _findLineByIdOrThrow(lineId);
    return _mapLine(insertedLine);
  }

  Future<OrderModifier> addModifier({
    required int transactionLineId,
    required ModifierAction action,
    required String itemName,
    required int extraPriceMinor,
  }) async {
    if (extraPriceMinor < 0) {
      throw ValidationException('extraPriceMinor cannot be negative.');
    }

    final db.TransactionLine lineRow = await _findLineByIdOrThrow(
      transactionLineId,
    );
    await _ensureTransactionIsDraft(lineRow.transactionId);

    final int modifierId = await _database
        .into(_database.orderModifiers)
        .insert(
          db.OrderModifiersCompanion.insert(
            uuid: _uuidGenerator.v4(),
            transactionLineId: transactionLineId,
            action: _modifierActionToDb(action),
            itemName: itemName,
            extraPriceMinor: Value<int>(extraPriceMinor),
          ),
        );

    await _recalculateLineTotalInCurrentTransaction(transactionLineId);

    final db.OrderModifier insertedModifier = await _findModifierByIdOrThrow(
      modifierId,
    );
    return _mapModifier(insertedModifier);
  }

  Future<int> getTransactionIdByLine(int transactionLineId) async {
    final db.TransactionLine line = await _findLineByIdOrThrow(
      transactionLineId,
    );
    return line.transactionId;
  }

  Future<({int subtotalMinor, int modifierTotalMinor, int totalAmountMinor})>
  calculateTotals(int transactionId) async {
    await _findTransactionByIdOrThrow(transactionId);
    final int subtotalMinor = await _sumProductTotals(transactionId);
    final int modifierTotalMinor = await _sumModifierTotals(transactionId);
    return (
      subtotalMinor: subtotalMinor,
      modifierTotalMinor: modifierTotalMinor,
      totalAmountMinor: subtotalMinor + modifierTotalMinor,
    );
  }

  Future<void> updateTotals({
    required int transactionId,
    required int subtotalMinor,
    required int modifierTotalMinor,
    required int totalAmountMinor,
  }) async {
    if (subtotalMinor < 0 || modifierTotalMinor < 0 || totalAmountMinor < 0) {
      throw ValidationException('Totals cannot be negative.');
    }

    final int updatedCount =
        await (_database.update(_database.transactions)
              ..where((db.$TransactionsTable t) => t.id.equals(transactionId)))
            .write(
              db.TransactionsCompanion(
                subtotalMinor: Value<int>(subtotalMinor),
                modifierTotalMinor: Value<int>(modifierTotalMinor),
                totalAmountMinor: Value<int>(totalAmountMinor),
                updatedAt: Value<DateTime>(DateTime.now()),
              ),
            );

    if (updatedCount == 0) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
  }

  Future<void> updateTableNumber({
    required int transactionId,
    required int? tableNumber,
  }) async {
    final db.Transaction row = await _findTransactionByIdOrThrow(transactionId);
    if (!OrderLifecyclePolicy.canUpdateTableNumber(_statusFromDb(row.status))) {
      throw InvalidStateTransitionException(
        'Table number can be updated only for draft or sent transactions.',
      );
    }

    final int updatedCount =
        await (_database.update(_database.transactions)
              ..where((db.$TransactionsTable t) => t.id.equals(transactionId)))
            .write(
              db.TransactionsCompanion(
                tableNumber: Value<int?>(tableNumber),
                updatedAt: Value<DateTime>(DateTime.now()),
              ),
            );

    if (updatedCount == 0) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
  }

  Future<void> recalculateTotals(int transactionId) async {
    await runInTransaction(() async {
      await _recalculateTotalsInCurrentTransaction(transactionId);
    });
  }

  Future<void> deleteDraft(int transactionId) async {
    await runInTransaction(() async {
      final db.Transaction row = await _ensureTransactionIsDraft(transactionId);
      final List<db.TransactionLine> lines =
          await (_database.select(_database.transactionLines)
                ..where((db.$TransactionLinesTable t) {
                  return t.transactionId.equals(transactionId);
                }))
              .get();

      final List<int> lineIds = lines
          .map((db.TransactionLine line) => line.id)
          .toList(growable: false);

      if (lineIds.isNotEmpty) {
        await (_database.delete(_database.orderModifiers)
              ..where((db.$OrderModifiersTable t) {
                return t.transactionLineId.isIn(lineIds);
              }))
            .go();
      }

      await (_database.delete(_database.transactionLines)
            ..where((db.$TransactionLinesTable t) {
              return t.transactionId.equals(transactionId);
            }))
          .go();

      final int deletedCount = await (_database.delete(
        _database.transactions,
      )..where((db.$TransactionsTable t) => t.id.equals(transactionId))).go();

      if (deletedCount == 0) {
        throw NotFoundException('Transaction not found: $transactionId');
      }

      if (_syncQueueRepository != null) {
        await (_database.delete(_database.syncQueue)
              ..where((db.$SyncQueueTable t) {
                return t.recordUuid.equals(row.uuid);
              }))
            .go();
      }
    });
  }

  Future<void> updatePrintFlag({
    required int transactionId,
    bool? kitchenPrinted,
    bool? receiptPrinted,
  }) async {
    if (kitchenPrinted == null && receiptPrinted == null) {
      return;
    }

    await runInTransaction(() async {
      final db.Transaction row = await _findTransactionByIdOrThrow(
        transactionId,
      );
      final int updatedCount =
          await (_database.update(
                _database.transactions,
              )..where((db.$TransactionsTable t) => t.id.equals(transactionId)))
              .write(
                db.TransactionsCompanion(
                  kitchenPrinted: kitchenPrinted == null
                      ? const Value<bool>.absent()
                      : Value<bool>(kitchenPrinted),
                  receiptPrinted: receiptPrinted == null
                      ? const Value<bool>.absent()
                      : Value<bool>(receiptPrinted),
                  updatedAt: Value<DateTime>(DateTime.now()),
                ),
              );

      if (updatedCount == 0) {
        throw NotFoundException('Transaction not found: $transactionId');
      }

      if (OrderLifecyclePolicy.isTerminal(_statusFromDb(row.status))) {
        await _syncQueueRepository?.addTransactionRootToQueue(row.uuid);
      }
    });
  }

  Future<List<TransactionLine>> getLines(int transactionId) async {
    final List<db.TransactionLine> rows =
        await (_database.select(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) {
                return t.transactionId.equals(transactionId);
              })
              ..orderBy(<OrderingTerm Function(db.$TransactionLinesTable)>[
                (db.$TransactionLinesTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    return rows.map(_mapLine).toList(growable: false);
  }

  Future<List<OrderModifier>> getModifiersByLine(int transactionLineId) async {
    final List<db.OrderModifier> rows =
        await (_database.select(_database.orderModifiers)
              ..where((db.$OrderModifiersTable t) {
                return t.transactionLineId.equals(transactionLineId);
              })
              ..orderBy(<OrderingTerm Function(db.$OrderModifiersTable)>[
                (db.$OrderModifiersTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    return rows.map(_mapModifier).toList(growable: false);
  }

  Future<List<String>> getLineUuids(int transactionId) async {
    final List<db.TransactionLine> rows =
        await (_database.select(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) {
                return t.transactionId.equals(transactionId);
              })
              ..orderBy(<OrderingTerm Function(db.$TransactionLinesTable)>[
                (db.$TransactionLinesTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    return rows
        .map((db.TransactionLine row) => row.uuid)
        .toList(growable: false);
  }

  Future<List<String>> getModifierUuidsByTransaction(int transactionId) async {
    final List<TypedResult> rows =
        await (_database.select(_database.orderModifiers).join(<Join>[
                innerJoin(
                  _database.transactionLines,
                  _database.transactionLines.id.equalsExp(
                    _database.orderModifiers.transactionLineId,
                  ),
                ),
              ])
              ..where(
                _database.transactionLines.transactionId.equals(transactionId),
              )
              ..orderBy(<OrderingTerm>[
                OrderingTerm.asc(_database.orderModifiers.id),
              ]))
            .get();

    return rows
        .map((TypedResult row) => row.readTable(_database.orderModifiers).uuid)
        .toList(growable: false);
  }

  Future<void> _recalculateTotalsInCurrentTransaction(int transactionId) async {
    final ({int subtotalMinor, int modifierTotalMinor, int totalAmountMinor})
    totals = await calculateTotals(transactionId);

    final int updatedCount =
        await (_database.update(_database.transactions)
              ..where((db.$TransactionsTable t) => t.id.equals(transactionId)))
            .write(
              db.TransactionsCompanion(
                subtotalMinor: Value<int>(totals.subtotalMinor),
                modifierTotalMinor: Value<int>(totals.modifierTotalMinor),
                totalAmountMinor: Value<int>(totals.totalAmountMinor),
                updatedAt: Value<DateTime>(DateTime.now()),
              ),
            );

    if (updatedCount == 0) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
  }

  Future<void> _recalculateLineTotalInCurrentTransaction(
    int transactionLineId,
  ) async {
    final db.TransactionLine line = await _findLineByIdOrThrow(
      transactionLineId,
    );
    final int modifierTotalMinor = await _sumModifierTotalsForLine(
      transactionLineId,
    );
    final int lineTotalMinor =
        (line.unitPriceMinor * line.quantity) + modifierTotalMinor;

    final int updatedCount =
        await (_database.update(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) {
                return t.id.equals(transactionLineId);
              }))
            .write(
              db.TransactionLinesCompanion(
                lineTotalMinor: Value<int>(lineTotalMinor),
              ),
            );

    if (updatedCount == 0) {
      throw NotFoundException('Transaction line not found: $transactionLineId');
    }
  }

  Future<int> _sumProductTotals(int transactionId) async {
    final QueryRow row = await _database
        .customSelect(
          '''
      SELECT COALESCE(SUM(tl.unit_price_minor * tl.quantity), 0) AS subtotal_minor
      FROM transaction_lines tl
      WHERE tl.transaction_id = ?
      ''',
          variables: <Variable<Object>>[Variable<int>(transactionId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.transactionLines,
          },
        )
        .getSingle();
    return row.read<int>('subtotal_minor');
  }

  Future<int> _sumModifierTotals(int transactionId) async {
    final QueryRow row = await _database
        .customSelect(
          '''
      SELECT COALESCE(SUM(om.extra_price_minor * tl.quantity), 0) AS modifier_total
      FROM order_modifiers om
      INNER JOIN transaction_lines tl ON tl.id = om.transaction_line_id
      WHERE tl.transaction_id = ?
      ''',
          variables: <Variable<Object>>[Variable<int>(transactionId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.orderModifiers,
            _database.transactionLines,
          },
        )
        .getSingle();

    return row.read<int>('modifier_total');
  }

  Future<int> _sumModifierTotalsForLine(int transactionLineId) async {
    final QueryRow row = await _database
        .customSelect(
          '''
      SELECT COALESCE(SUM(om.extra_price_minor * tl.quantity), 0) AS modifier_total
      FROM order_modifiers om
      INNER JOIN transaction_lines tl ON tl.id = om.transaction_line_id
      WHERE tl.id = ?
      ''',
          variables: <Variable<Object>>[Variable<int>(transactionLineId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.orderModifiers,
            _database.transactionLines,
          },
        )
        .getSingle();

    return row.read<int>('modifier_total');
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

  Future<db.Transaction> _ensureTransactionIsDraft(int id) async {
    final db.Transaction row = await _findTransactionByIdOrThrow(id);
    if (!OrderLifecyclePolicy.canMutateLineItems(_statusFromDb(row.status))) {
      throw InvalidStateTransitionException(
        'Cannot mutate non-draft transaction: $id',
      );
    }
    return row;
  }

  Future<db.TransactionLine> _findLineByIdOrThrow(int id) async {
    final db.TransactionLine? row =
        await (_database.select(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) => t.id.equals(id)))
            .getSingleOrNull();
    if (row == null) {
      throw DatabaseException('Line not found after insert: $id');
    }
    return row;
  }

  Future<db.OrderModifier> _findModifierByIdOrThrow(int id) async {
    final db.OrderModifier? row = await (_database.select(
      _database.orderModifiers,
    )..where((db.$OrderModifiersTable t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw DatabaseException('Modifier not found after insert: $id');
    }
    return row;
  }

  Transaction _mapTransaction(db.Transaction row) {
    return Transaction(
      id: row.id,
      uuid: row.uuid,
      shiftId: row.shiftId,
      userId: row.userId,
      tableNumber: row.tableNumber,
      status: _statusFromDb(row.status),
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

  TransactionLine _mapLine(db.TransactionLine row) {
    return TransactionLine(
      id: row.id,
      uuid: row.uuid,
      transactionId: row.transactionId,
      productId: row.productId,
      productName: row.productName,
      unitPriceMinor: row.unitPriceMinor,
      quantity: row.quantity,
      lineTotalMinor: row.lineTotalMinor,
    );
  }

  OrderModifier _mapModifier(db.OrderModifier row) {
    return OrderModifier(
      id: row.id,
      uuid: row.uuid,
      transactionLineId: row.transactionLineId,
      action: _modifierActionFromDb(row.action),
      itemName: row.itemName,
      extraPriceMinor: row.extraPriceMinor,
    );
  }

  TransactionStatus _statusFromDb(String value) {
    switch (value) {
      case 'open':
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

  ModifierAction _modifierActionFromDb(String value) {
    switch (value) {
      case 'remove':
        return ModifierAction.remove;
      case 'add':
        return ModifierAction.add;
      default:
        throw DatabaseException('Unknown modifier action: $value');
    }
  }

  String _modifierActionToDb(ModifierAction value) {
    switch (value) {
      case ModifierAction.remove:
        return 'remove';
      case ModifierAction.add:
        return 'add';
    }
  }

  bool _isUniqueIdempotencyViolation(SqliteException error) {
    final String message = error.message.toLowerCase();
    return error.extendedResultCode == 2067 &&
        message.contains('transactions.idempotency_key');
  }
}
