import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/exceptions.dart';
import '../mappers/transaction_persistence_mapper.dart';
import '../../domain/models/breakfast_cooking_instruction.dart';
import '../../domain/models/breakfast_rebuild.dart';
import '../../domain/models/meal_customization.dart';
import '../../domain/models/order_lifecycle_policy.dart';
import '../../domain/models/order_modifier.dart';
import '../../domain/models/product_modifier.dart';
import '../../domain/models/shift_report_category_line.dart';
import '../../domain/models/transaction_line.dart';
import '../../domain/services/meal_customization_persistence_mapper.dart';
import 'sync_queue_repository.dart';
import '../../domain/models/transaction.dart';
import '../database/app_database.dart' as db;

const String _mealCustomizationSnapshotsTable =
    'meal_customization_line_snapshots';

class TransactionRepository {
  TransactionRepository(
    this._database, {
    Uuid? uuidGenerator,
    SyncQueueRepository? syncQueueRepository,
    Future<void> Function(
      db.AppDatabase database,
      int transactionLineId,
      int transactionId,
    )?
    beforeBreakfastSnapshotFinancialRecompute,
    TransactionPersistenceMapper persistenceMapper =
        const TransactionPersistenceMapper(),
    MealCustomizationPersistenceMapper mealCustomizationPersistenceMapper =
        const MealCustomizationPersistenceMapper(),
  }) : _uuidGenerator = uuidGenerator ?? const Uuid(),
       _syncQueueRepository = syncQueueRepository,
       _beforeBreakfastSnapshotFinancialRecompute =
           beforeBreakfastSnapshotFinancialRecompute,
       _persistenceMapper = persistenceMapper,
       _mealCustomizationPersistenceMapper = mealCustomizationPersistenceMapper;

  final db.AppDatabase _database;
  final Uuid _uuidGenerator;
  final SyncQueueRepository? _syncQueueRepository;
  final Future<void> Function(
    db.AppDatabase database,
    int transactionLineId,
    int transactionId,
  )?
  _beforeBreakfastSnapshotFinancialRecompute;
  final TransactionPersistenceMapper _persistenceMapper;
  final MealCustomizationPersistenceMapper _mealCustomizationPersistenceMapper;

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
    ModifierPriceBehavior? priceBehavior,
    ModifierUiSection? uiSection,
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
            quantity: const Value<int>(1),
            itemProductId: const Value<int?>(null),
            sourceGroupId: const Value<int?>(null),
            extraPriceMinor: Value<int>(extraPriceMinor),
            chargeReason: const Value<String?>(null),
            unitPriceMinor: Value<int>(extraPriceMinor),
            priceEffectMinor: Value<int>(extraPriceMinor),
            sortKey: const Value<int>(0),
            priceBehavior: Value<String?>(
              _modifierPriceBehaviorToDb(priceBehavior),
            ),
            uiSection: Value<String?>(_modifierUiSectionToDb(uiSection)),
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

  Future<TransactionLine?> getLineById(int transactionLineId) async {
    final db.TransactionLine? row =
        await (_database.select(_database.transactionLines)..where(
              (db.$TransactionLinesTable t) => t.id.equals(transactionLineId),
            ))
            .getSingleOrNull();
    return row == null ? null : _mapLine(row);
  }

  Future<
    ({
      TransactionLine line,
      TransactionStatus status,
      DateTime transactionUpdatedAt,
    })?
  >
  getLineContext(int transactionLineId) async {
    final TypedResult? row =
        await (_database.select(_database.transactionLines).join(<Join>[
              innerJoin(
                _database.transactions,
                _database.transactions.id.equalsExp(
                  _database.transactionLines.transactionId,
                ),
              ),
            ])..where(_database.transactionLines.id.equals(transactionLineId)))
            .getSingleOrNull();

    if (row == null) {
      return null;
    }

    final db.TransactionLine lineRow = row.readTable(
      _database.transactionLines,
    );
    final db.Transaction transactionRow = row.readTable(_database.transactions);
    return (
      line: _mapLine(lineRow),
      status: _statusFromDb(transactionRow.status),
      transactionUpdatedAt: transactionRow.updatedAt,
    );
  }

  Future<TransactionLine> splitLineForIndependentEdit(
    int transactionLineId,
  ) async {
    final db.TransactionLine lineRow = await _findLineByIdOrThrow(
      transactionLineId,
    );
    if (lineRow.quantity <= 1) {
      return _mapLine(lineRow);
    }

    await _ensureTransactionIsDraft(lineRow.transactionId);
    final List<db.OrderModifier> modifiers =
        await (_database.select(_database.orderModifiers)
              ..where((db.$OrderModifiersTable t) {
                return t.transactionLineId.equals(transactionLineId);
              })
              ..orderBy(<OrderingTerm Function(db.$OrderModifiersTable)>[
                (db.$OrderModifiersTable t) => OrderingTerm.asc(t.sortKey),
                (db.$OrderModifiersTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final List<db.BreakfastCookingInstruction> cookingInstructions =
        await (_database.select(_database.breakfastCookingInstructions)
              ..where((db.$BreakfastCookingInstructionsTable t) {
                return t.transactionLineId.equals(transactionLineId);
              })
              ..orderBy([
                (db.$BreakfastCookingInstructionsTable t) =>
                    OrderingTerm.asc(t.sortKey),
                (db.$BreakfastCookingInstructionsTable t) =>
                    OrderingTerm.asc(t.id),
              ]))
            .get();
    final MealCustomizationPersistedSnapshotRecord? mealSnapshot =
        await getMealCustomizationSnapshotByLine(transactionLineId);

    final bool hasSemanticBreakfastRows =
        lineRow.pricingMode == 'set' &&
        lineRow.quantity > 1 &&
        modifiers.any(_isSemanticModifierRow);
    if (hasSemanticBreakfastRows) {
      throw BreakfastEditRejectedException(
        codes: const <BreakfastEditErrorCode>[
          BreakfastEditErrorCode.unsupportedLineSplitState,
        ],
        transactionLineId: transactionLineId,
      );
    }

    final int clonedLineId = await _database
        .into(_database.transactionLines)
        .insert(
          db.TransactionLinesCompanion.insert(
            uuid: _uuidGenerator.v4(),
            transactionId: lineRow.transactionId,
            productId: lineRow.productId,
            productName: lineRow.productName,
            unitPriceMinor: lineRow.unitPriceMinor,
            quantity: const Value<int>(1),
            lineTotalMinor: lineRow.unitPriceMinor,
            pricingMode: Value<String>(lineRow.pricingMode),
            removalDiscountTotalMinor: Value<int>(
              lineRow.removalDiscountTotalMinor,
            ),
          ),
        );

    for (final db.OrderModifier modifier in modifiers) {
      await _database
          .into(_database.orderModifiers)
          .insert(
            db.OrderModifiersCompanion.insert(
              uuid: _uuidGenerator.v4(),
              transactionLineId: clonedLineId,
              action: modifier.action,
              itemName: modifier.itemName,
              quantity: Value<int>(modifier.quantity),
              itemProductId: Value<int?>(modifier.itemProductId),
              sourceGroupId: Value<int?>(modifier.sourceGroupId),
              extraPriceMinor: Value<int>(modifier.extraPriceMinor),
              chargeReason: Value<String?>(modifier.chargeReason),
              unitPriceMinor: Value<int>(modifier.unitPriceMinor),
              priceEffectMinor: Value<int>(modifier.priceEffectMinor),
              sortKey: Value<int>(modifier.sortKey),
              priceBehavior: Value<String?>(modifier.priceBehavior),
              uiSection: Value<String?>(modifier.uiSection),
            ),
          );
    }
    for (final db.BreakfastCookingInstruction instruction
        in cookingInstructions) {
      await _database
          .into(_database.breakfastCookingInstructions)
          .insert(
            db.BreakfastCookingInstructionsCompanion.insert(
              uuid: _uuidGenerator.v4(),
              transactionLineId: clonedLineId,
              itemProductId: instruction.itemProductId,
              itemName: instruction.itemName,
              instructionCode: instruction.instructionCode,
              instructionLabel: instruction.instructionLabel,
              appliedQuantity: Value<int>(instruction.appliedQuantity),
              sortKey: Value<int>(instruction.sortKey),
            ),
          );
    }
    if (mealSnapshot != null) {
      await _database.customUpdate(
        '''
        INSERT INTO $_mealCustomizationSnapshotsTable (
          transaction_line_id,
          product_id,
          profile_id,
          customization_key,
          snapshot_json,
          total_adjustment_minor,
          free_swap_count_used,
          paid_swap_count_used
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        variables: <Variable<Object>>[
          Variable<int>(clonedLineId),
          Variable<int>(mealSnapshot.productId),
          Variable<int>(mealSnapshot.profileId),
          Variable<String>(mealSnapshot.customizationKey),
          Variable<String>(jsonEncode(mealSnapshot.snapshot.toJson())),
          Variable<int>(mealSnapshot.snapshot.totalAdjustmentMinor),
          Variable<int>(mealSnapshot.snapshot.freeSwapCountUsed),
          Variable<int>(mealSnapshot.snapshot.paidSwapCountUsed),
        ],
        updates: <ResultSetImplementation<dynamic, dynamic>>{},
      );
    }

    final int updatedCount =
        await (_database.update(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) {
                return t.id.equals(transactionLineId);
              }))
            .write(
              db.TransactionLinesCompanion(
                quantity: Value<int>(lineRow.quantity - 1),
              ),
            );
    if (updatedCount == 0) {
      throw NotFoundException('Transaction line not found: $transactionLineId');
    }

    await _recalculateLineTotalInCurrentTransaction(transactionLineId);
    await _recalculateLineTotalInCurrentTransaction(clonedLineId);
    return _mapLine(await _findLineByIdOrThrow(clonedLineId));
  }

  Future<void> replaceBreakfastLineSnapshot({
    required int transactionLineId,
    required BreakfastRebuildResult rebuildResult,
    List<BreakfastCookingInstructionRecord> cookingInstructions =
        const <BreakfastCookingInstructionRecord>[],
  }) async {
    final List<db.OrderModifiersCompanion> serializedModifiers = rebuildResult
        .classifiedModifiers
        .map(
          (BreakfastClassifiedModifier modifier) =>
              _serializeBreakfastSnapshotModifier(
                transactionLineId: transactionLineId,
                modifier: modifier,
              ),
        )
        .toList(growable: false);
    final List<db.BreakfastCookingInstructionsCompanion>
    serializedCookingInstructions = cookingInstructions
        .map(
          (BreakfastCookingInstructionRecord instruction) =>
              db.BreakfastCookingInstructionsCompanion.insert(
                uuid: instruction.uuid,
                transactionLineId: transactionLineId,
                itemProductId: instruction.itemProductId,
                itemName: instruction.itemName,
                instructionCode: instruction.instructionCode,
                instructionLabel: instruction.instructionLabel,
                appliedQuantity: Value<int>(instruction.appliedQuantity),
                sortKey: Value<int>(instruction.sortKey),
              ),
        )
        .toList(growable: false);

    await _database.transaction(() async {
      final db.TransactionLine lineRow = await _findLineByIdOrThrow(
        transactionLineId,
      );
      await _ensureTransactionIsDraft(lineRow.transactionId);

      final int siblingCountBefore = await _countSiblingModifierRows(
        transactionLineId,
      );

      await (_database.delete(_database.orderModifiers)
            ..where((db.$OrderModifiersTable t) {
              return t.transactionLineId.equals(transactionLineId);
            }))
          .go();
      await (_database.delete(_database.breakfastCookingInstructions)
            ..where((db.$BreakfastCookingInstructionsTable t) {
              return t.transactionLineId.equals(transactionLineId);
            }))
          .go();

      await _assertSiblingModifierRowsUnchanged(
        transactionLineId: transactionLineId,
        expectedSiblingCount: siblingCountBefore,
        phase: 'delete',
      );

      for (final db.OrderModifiersCompanion companion in serializedModifiers) {
        final int insertedId = await _database
            .into(_database.orderModifiers)
            .insert(companion);
        final db.OrderModifier insertedRow = await _findModifierByIdOrThrow(
          insertedId,
        );
        _assertPersistedSemanticFieldsMatchCompanion(
          companion: companion,
          row: insertedRow,
        );
      }
      for (final db.BreakfastCookingInstructionsCompanion companion
          in serializedCookingInstructions) {
        await _database
            .into(_database.breakfastCookingInstructions)
            .insert(companion);
      }

      final int updatedCount =
          await (_database.update(_database.transactionLines)
                ..where((db.$TransactionLinesTable t) {
                  return t.id.equals(transactionLineId);
                }))
              .write(
                db.TransactionLinesCompanion(
                  pricingMode: const Value<String>('set'),
                  removalDiscountTotalMinor: Value<int>(
                    rebuildResult.lineSnapshot.removalDiscountTotalMinor,
                  ),
                ),
              );
      if (updatedCount != 1) {
        throw DatabaseException(
          'Breakfast snapshot replace expected one target line update, got $updatedCount for line $transactionLineId.',
        );
      }

      await _assertSiblingModifierRowsUnchanged(
        transactionLineId: transactionLineId,
        expectedSiblingCount: siblingCountBefore,
        phase: 'insert',
      );

      final int transactionId = lineRow.transactionId;
      final beforeBreakfastSnapshotFinancialRecompute =
          _beforeBreakfastSnapshotFinancialRecompute;
      if (beforeBreakfastSnapshotFinancialRecompute != null) {
        await beforeBreakfastSnapshotFinancialRecompute(
          _database,
          transactionLineId,
          transactionId,
        );
      }

      await _recomputeBreakfastSnapshotFinancialsInCurrentTransaction(
        transactionLineId: transactionLineId,
        expectedSnapshot: rebuildResult.lineSnapshot,
        expectedModifierCount: serializedModifiers.length,
      );
    });
  }

  Future<void> replaceMealCustomizationLineSnapshot({
    required int transactionLineId,
    required MealCustomizationResolvedSnapshot snapshot,
  }) async {
    final Set<int> referencedProductIds = <int>{};
    for (final MealCustomizationSemanticAction action in snapshot.actions) {
      final int? itemProductId = action.itemProductId;
      if (itemProductId != null) {
        referencedProductIds.add(itemProductId);
      }
      final int? sourceItemProductId = action.sourceItemProductId;
      if (sourceItemProductId != null) {
        referencedProductIds.add(sourceItemProductId);
      }
    }
    referencedProductIds.addAll(
      snapshot.sandwichSelection?.sauceProductIds ?? const <int>[],
    );
    final Map<int, String> productNamesById = await _loadProductNamesByIds(
      referencedProductIds,
    );

    final MealCustomizationPersistenceProjection projection =
        _mealCustomizationPersistenceMapper.mapSnapshot(
          transactionLineId: transactionLineId,
          snapshot: snapshot,
          productNamesById: productNamesById,
          createUuid: _uuidGenerator.v4,
        );

    await _database.transaction(() async {
      final db.TransactionLine lineRow = await _findLineByIdOrThrow(
        transactionLineId,
      );
      await _ensureTransactionIsDraft(lineRow.transactionId);

      await (_database.delete(_database.orderModifiers)
            ..where((db.$OrderModifiersTable t) {
              return t.transactionLineId.equals(transactionLineId);
            }))
          .go();

      for (final OrderModifier modifier in projection.modifiers) {
        await _database
            .into(_database.orderModifiers)
            .insert(_persistenceMapper.orderModifierToCompanion(modifier));
      }

      await _database.customUpdate(
        '''
        INSERT INTO $_mealCustomizationSnapshotsTable (
          transaction_line_id,
          product_id,
          profile_id,
          customization_key,
          snapshot_json,
          total_adjustment_minor,
          free_swap_count_used,
          paid_swap_count_used
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(transaction_line_id) DO UPDATE SET
          product_id = excluded.product_id,
          profile_id = excluded.profile_id,
          customization_key = excluded.customization_key,
          snapshot_json = excluded.snapshot_json,
          total_adjustment_minor = excluded.total_adjustment_minor,
          free_swap_count_used = excluded.free_swap_count_used,
          paid_swap_count_used = excluded.paid_swap_count_used
        ''',
        variables: <Variable<Object>>[
          Variable<int>(transactionLineId),
          Variable<int>(snapshot.productId),
          Variable<int>(snapshot.profileId),
          Variable<String>(snapshot.stableIdentityKey),
          Variable<String>(jsonEncode(snapshot.toJson())),
          Variable<int>(snapshot.totalAdjustmentMinor),
          Variable<int>(snapshot.freeSwapCountUsed),
          Variable<int>(snapshot.paidSwapCountUsed),
        ],
        updates: <ResultSetImplementation<dynamic, dynamic>>{},
      );

      final int updatedCount =
          await (_database.update(_database.transactionLines)
                ..where((db.$TransactionLinesTable t) {
                  return t.id.equals(transactionLineId);
                }))
              .write(
                const db.TransactionLinesCompanion(
                  pricingMode: Value<String>('standard'),
                  removalDiscountTotalMinor: Value<int>(0),
                ),
              );
      if (updatedCount != 1) {
        throw DatabaseException(
          'Meal customization snapshot replace expected one target line update, got $updatedCount for line $transactionLineId.',
        );
      }

      await _recalculateLineTotalInCurrentTransaction(transactionLineId);
      await _recalculateTotalsInCurrentTransaction(lineRow.transactionId);
    });
  }

  Future<MealCustomizationPersistedSnapshotRecord?>
  getMealCustomizationSnapshotByLine(int transactionLineId) async {
    final QueryRow? row = await _database
        .customSelect(
          '''
          SELECT
            transaction_line_id,
            product_id,
            profile_id,
            customization_key,
            snapshot_json
          FROM $_mealCustomizationSnapshotsTable
          WHERE transaction_line_id = ?
          ''',
          variables: <Variable<Object>>[Variable<int>(transactionLineId)],
        )
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return MealCustomizationPersistedSnapshotRecord(
      transactionLineId: row.read<int>('transaction_line_id'),
      productId: row.read<int>('product_id'),
      profileId: row.read<int>('profile_id'),
      customizationKey: row.read<String>('customization_key'),
      snapshot: MealCustomizationResolvedSnapshot.fromJson(
        Map<String, Object?>.from(
          jsonDecode(row.read<String>('snapshot_json')) as Map,
        ),
      ),
    );
  }

  Future<TransactionLine?> findDraftMealCustomizationLineByIdentity({
    required int transactionId,
    required int productId,
    required String customizationKey,
    int? excludeTransactionLineId,
  }) async {
    final String excludeClause = excludeTransactionLineId == null
        ? ''
        : 'AND tl.id != ?';
    final List<Variable<Object>> variables = <Variable<Object>>[
      Variable<int>(transactionId),
      Variable<int>(productId),
      Variable<String>(customizationKey),
      if (excludeTransactionLineId != null)
        Variable<int>(excludeTransactionLineId),
    ];
    final QueryRow? row = await _database
        .customSelect(
          '''
          SELECT tl.*
          FROM transaction_lines tl
          INNER JOIN transactions tx ON tx.id = tl.transaction_id
          INNER JOIN $_mealCustomizationSnapshotsTable ms
            ON ms.transaction_line_id = tl.id
          WHERE tl.transaction_id = ?
            AND tl.product_id = ?
            AND tx.status = 'draft'
            AND ms.customization_key = ?
            $excludeClause
          ORDER BY tl.id ASC
          LIMIT 1
          ''',
          variables: variables,
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.transactionLines,
            _database.transactions,
          },
        )
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _mapLine(
      db.TransactionLine(
        id: row.read<int>('id'),
        uuid: row.read<String>('uuid'),
        transactionId: row.read<int>('transaction_id'),
        productId: row.read<int>('product_id'),
        productName: row.read<String>('product_name'),
        unitPriceMinor: row.read<int>('unit_price_minor'),
        quantity: row.read<int>('quantity'),
        lineTotalMinor: row.read<int>('line_total_minor'),
        pricingMode: row.read<String>('pricing_mode'),
        removalDiscountTotalMinor: row.read<int>(
          'removal_discount_total_minor',
        ),
      ),
    );
  }

  Future<bool> isLegacyMealCustomizationLine(int transactionLineId) async {
    final db.TransactionLine lineRow = await _findLineByIdOrThrow(
      transactionLineId,
    );
    if (lineRow.pricingMode != 'standard') {
      return false;
    }
    if (await getMealCustomizationSnapshotByLine(transactionLineId) != null) {
      return false;
    }
    final List<db.OrderModifier> modifiers = await _findModifierRowsByLine(
      transactionLineId,
    );
    return modifiers.any(_isMealCustomizationSemanticModifierRow);
  }

  Future<TransactionLine> incrementLineQuantity({
    required int transactionLineId,
    int incrementBy = 1,
  }) async {
    if (incrementBy <= 0) {
      throw ValidationException('incrementBy must be greater than zero.');
    }
    final db.TransactionLine lineRow = await _findLineByIdOrThrow(
      transactionLineId,
    );
    await _ensureTransactionIsDraft(lineRow.transactionId);
    final int updatedCount =
        await (_database.update(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) {
                return t.id.equals(transactionLineId);
              }))
            .write(
              db.TransactionLinesCompanion(
                quantity: Value<int>(lineRow.quantity + incrementBy),
              ),
            );
    if (updatedCount != 1) {
      throw NotFoundException('Transaction line not found: $transactionLineId');
    }
    await _recalculateLineTotalInCurrentTransaction(transactionLineId);
    await _recalculateTotalsInCurrentTransaction(lineRow.transactionId);
    return _mapLine(await _findLineByIdOrThrow(transactionLineId));
  }

  Future<void> decrementLineQuantityOrDelete(int transactionLineId) async {
    final db.TransactionLine lineRow = await _findLineByIdOrThrow(
      transactionLineId,
    );
    await _ensureTransactionIsDraft(lineRow.transactionId);
    if (lineRow.quantity > 1) {
      final int updatedCount =
          await (_database.update(_database.transactionLines)
                ..where((db.$TransactionLinesTable t) {
                  return t.id.equals(transactionLineId);
                }))
              .write(
                db.TransactionLinesCompanion(
                  quantity: Value<int>(lineRow.quantity - 1),
                ),
              );
      if (updatedCount != 1) {
        throw NotFoundException(
          'Transaction line not found: $transactionLineId',
        );
      }
      await _recalculateLineTotalInCurrentTransaction(transactionLineId);
      await _recalculateTotalsInCurrentTransaction(lineRow.transactionId);
      return;
    }

    await deleteDraftLineCompletely(transactionLineId);
  }

  Future<void> deleteDraftLineCompletely(int transactionLineId) async {
    final db.TransactionLine lineRow = await _findLineByIdOrThrow(
      transactionLineId,
    );
    await _ensureTransactionIsDraft(lineRow.transactionId);
    await _deleteLineArtifactsInCurrentTransaction(transactionLineId);
    final int deletedCount =
        await (_database.delete(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) {
                return t.id.equals(transactionLineId);
              }))
            .go();
    if (deletedCount != 1) {
      throw NotFoundException('Transaction line not found: $transactionLineId');
    }
    await _recalculateTotalsInCurrentTransaction(lineRow.transactionId);
  }

  /// Loads all meal customization snapshots for a given product across all
  /// paid/draft/sent transactions. Used for analytics aggregation.
  Future<List<MealCustomizationPersistedSnapshotRecord>>
  getMealCustomizationSnapshotsByProduct(int productId) async {
    final List<QueryRow> rows = await _database
        .customSelect(
          '''
          SELECT
            ms.transaction_line_id,
            ms.product_id,
            ms.profile_id,
            ms.customization_key,
            ms.snapshot_json
          FROM $_mealCustomizationSnapshotsTable ms
          WHERE ms.product_id = ?
          ORDER BY ms.transaction_line_id DESC
          ''',
          variables: <Variable<Object>>[Variable<int>(productId)],
        )
        .get();
    return rows
        .map((QueryRow row) {
          return MealCustomizationPersistedSnapshotRecord(
            transactionLineId: row.read<int>('transaction_line_id'),
            productId: row.read<int>('product_id'),
            profileId: row.read<int>('profile_id'),
            customizationKey: row.read<String>('customization_key'),
            snapshot: MealCustomizationResolvedSnapshot.fromJson(
              Map<String, Object?>.from(
                jsonDecode(row.read<String>('snapshot_json')) as Map,
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  /// Counts legacy (non-snapshot-backed) meal customization lines for a
  /// product. These are lines with standard pricing mode and semantic modifiers
  /// but no snapshot record.
  Future<int> countLegacyMealCustomizationLines(int productId) async {
    final QueryRow row = await _database
        .customSelect(
          '''
          SELECT COUNT(*) AS cnt
          FROM transaction_lines tl
          WHERE tl.product_id = ?
            AND tl.pricing_mode = 'standard'
            AND NOT EXISTS (
              SELECT 1 FROM $_mealCustomizationSnapshotsTable ms
              WHERE ms.transaction_line_id = tl.id
            )
            AND EXISTS (
              SELECT 1 FROM order_modifiers om
              WHERE om.transaction_line_id = tl.id
                AND om.charge_reason IS NOT NULL
            )
          ''',
          variables: <Variable<Object>>[Variable<int>(productId)],
        )
        .getSingle();
    return row.read<int>('cnt');
  }

  /// Returns distinct product IDs that have meal customization snapshots
  /// within the given lookback window.
  Future<List<int>> getMealCustomizationActiveProductIds({
    int lookbackDays = 30,
  }) async {
    final List<QueryRow> rows = await _database.customSelect('''
          SELECT DISTINCT ms.product_id
          FROM $_mealCustomizationSnapshotsTable ms
          INNER JOIN transaction_lines tl ON tl.id = ms.transaction_line_id
          INNER JOIN transactions tx ON tx.id = tl.transaction_id
          WHERE tx.created_at >= CAST(strftime('%s', 'now', '-$lookbackDays days') AS INTEGER)
          ORDER BY ms.product_id ASC
          ''').get();
    return rows
        .map((QueryRow row) => row.read<int>('product_id'))
        .toList(growable: false);
  }

  /// Deletes orphan meal customization snapshot rows that reference
  /// transaction_line_ids which no longer exist. Returns the count of
  /// cleaned-up rows.
  Future<int> cleanupOrphanMealCustomizationSnapshots() async {
    final QueryRow result = await _database.customSelect('''
          SELECT COUNT(*) AS cnt
          FROM $_mealCustomizationSnapshotsTable ms
          WHERE NOT EXISTS (
            SELECT 1 FROM transaction_lines tl
            WHERE tl.id = ms.transaction_line_id
          )
          ''').getSingle();
    final int orphanCount = result.read<int>('cnt');
    if (orphanCount > 0) {
      await _database.customUpdate('''
        DELETE FROM $_mealCustomizationSnapshotsTable
        WHERE NOT EXISTS (
          SELECT 1 FROM transaction_lines tl
          WHERE tl.id = $_mealCustomizationSnapshotsTable.transaction_line_id
        )
        ''', updates: <ResultSetImplementation<dynamic, dynamic>>{});
    }
    return orphanCount;
  }

  /// Returns legacy meal line counts grouped by product ID.
  /// This is a lightweight query intended for admin visibility surfaces.
  Future<Map<int, int>> getLegacyMealCustomizationLineCountsByProduct() async {
    final List<QueryRow> rows = await _database.customSelect('''
          SELECT tl.product_id, COUNT(*) AS cnt
          FROM transaction_lines tl
          WHERE tl.pricing_mode = 'standard'
            AND NOT EXISTS (
              SELECT 1 FROM $_mealCustomizationSnapshotsTable ms
              WHERE ms.transaction_line_id = tl.id
            )
            AND EXISTS (
              SELECT 1 FROM order_modifiers om
              WHERE om.transaction_line_id = tl.id
                AND om.charge_reason IS NOT NULL
            )
          GROUP BY tl.product_id
          ORDER BY cnt DESC
          ''').get();
    return <int, int>{
      for (final QueryRow row in rows)
        row.read<int>('product_id'): row.read<int>('cnt'),
    };
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
    if (subtotalMinor < 0 || totalAmountMinor < 0) {
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
        await (_database.delete(_database.breakfastCookingInstructions)
              ..where((db.$BreakfastCookingInstructionsTable t) {
                return t.transactionLineId.isIn(lineIds);
              }))
            .go();
        await _database.customUpdate(
          'DELETE FROM $_mealCustomizationSnapshotsTable WHERE transaction_line_id IN (${lineIds.join(',')})',
          updates: <ResultSetImplementation<dynamic, dynamic>>{},
        );
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
                (db.$OrderModifiersTable t) => OrderingTerm.asc(t.sortKey),
                (db.$OrderModifiersTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    return rows.map(_mapModifier).toList(growable: false);
  }

  Future<List<BreakfastCookingInstructionRecord>>
  getBreakfastCookingInstructionsByLine(int transactionLineId) async {
    final List<db.BreakfastCookingInstruction> rows =
        await (_database.select(_database.breakfastCookingInstructions)
              ..where((db.$BreakfastCookingInstructionsTable t) {
                return t.transactionLineId.equals(transactionLineId);
              })
              ..orderBy([
                (db.$BreakfastCookingInstructionsTable t) =>
                    OrderingTerm.asc(t.sortKey),
                (db.$BreakfastCookingInstructionsTable t) =>
                    OrderingTerm.asc(t.id),
              ]))
            .get();

    return rows.map(_mapBreakfastCookingInstruction).toList(growable: false);
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
                OrderingTerm.asc(_database.transactionLines.id),
                OrderingTerm.asc(_database.orderModifiers.sortKey),
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
        (line.unitPriceMinor * line.quantity) +
        modifierTotalMinor -
        line.removalDiscountTotalMinor;
    if (lineTotalMinor < 0) {
      throw DatabaseException(
        'Recomputed line_total_minor became negative for line $transactionLineId.',
      );
    }

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
    final List<db.TransactionLine> lines =
        await (_database.select(_database.transactionLines)
              ..where((db.$TransactionLinesTable t) {
                return t.transactionId.equals(transactionId);
              }))
            .get();
    int totalMinor = 0;
    for (final db.TransactionLine lineRow in lines) {
      totalMinor += await _effectiveModifierTotalForLine(
        transactionLineId: lineRow.id,
        lineRow: lineRow,
      );
    }
    return totalMinor;
  }

  Future<int> _sumModifierTotalsForLine(int transactionLineId) async {
    final db.TransactionLine lineRow = await _findLineByIdOrThrow(
      transactionLineId,
    );
    return _effectiveModifierTotalForLine(
      transactionLineId: transactionLineId,
      lineRow: lineRow,
    );
  }

  Future<int> _effectiveModifierTotalForLine({
    required int transactionLineId,
    required db.TransactionLine lineRow,
  }) async {
    final List<db.OrderModifier> modifiers = await _findModifierRowsByLine(
      transactionLineId,
    );
    final bool hasMealSnapshot =
        await getMealCustomizationSnapshotByLine(transactionLineId) != null;
    if (hasMealSnapshot) {
      int perUnitTotal = 0;
      for (final db.OrderModifier modifierRow in modifiers) {
        if (!_isSemanticModifierRow(modifierRow)) {
          throw DatabaseException(
            'Meal customization line $transactionLineId contains non-semantic modifier row ${modifierRow.uuid}.',
          );
        }
        perUnitTotal += _readSemanticModifierContributionMinor(modifierRow);
      }
      return perUnitTotal * lineRow.quantity;
    }

    int totalMinor = 0;
    for (final db.OrderModifier modifierRow in modifiers) {
      totalMinor += _modifierContributionMinor(
        modifierRow: modifierRow,
        lineRow: lineRow,
      );
    }
    return totalMinor;
  }

  Future<void> _recomputeBreakfastSnapshotFinancialsInCurrentTransaction({
    required int transactionLineId,
    required BreakfastLineSnapshot expectedSnapshot,
    required int expectedModifierCount,
  }) async {
    final db.TransactionLine lineRow = await _findLineByIdOrThrow(
      transactionLineId,
    );
    final List<db.OrderModifier> persistedModifiers =
        await _findModifierRowsByLine(transactionLineId);

    _assertBreakfastRecomputeUsesCommittedPersistedRowsOnly(
      lineRow: lineRow,
      persistedModifiers: persistedModifiers,
      expectedSnapshot: expectedSnapshot,
      expectedModifierCount: expectedModifierCount,
    );

    final int modifierTotalMinor = _sumBreakfastSemanticModifierPriceEffects(
      persistedModifiers,
    );
    final int lineTotalMinor =
        (lineRow.unitPriceMinor * lineRow.quantity) +
        modifierTotalMinor -
        lineRow.removalDiscountTotalMinor;
    if (lineTotalMinor < 0) {
      throw DatabaseException(
        'Breakfast snapshot recompute produced a negative line total for line $transactionLineId.',
      );
    }

    _assertBreakfastSnapshotMatchesPersistedRows(
      transactionLineId: transactionLineId,
      expectedSnapshot: expectedSnapshot,
      recomputedModifierTotalMinor: modifierTotalMinor,
      recomputedLineTotalMinor: lineTotalMinor,
      lineRow: lineRow,
    );

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
    if (updatedCount != 1) {
      throw DatabaseException(
        'Breakfast snapshot recompute expected one target line update, got $updatedCount for line $transactionLineId.',
      );
    }

    final db.TransactionLine refreshedLine = await _findLineByIdOrThrow(
      transactionLineId,
    );
    if (refreshedLine.lineTotalMinor != lineTotalMinor ||
        refreshedLine.removalDiscountTotalMinor !=
            expectedSnapshot.removalDiscountTotalMinor ||
        refreshedLine.pricingMode != 'set') {
      throw DatabaseException(
        'Breakfast snapshot recompute mismatch between recomputed totals and persisted line state for line $transactionLineId.',
      );
    }

    await _recalculateTotalsInCurrentTransaction(lineRow.transactionId);

    final ({int subtotalMinor, int modifierTotalMinor, int totalAmountMinor})
    persistedTotals = await calculateTotals(lineRow.transactionId);
    final db.Transaction transactionRow = await _findTransactionByIdOrThrow(
      lineRow.transactionId,
    );
    if (transactionRow.subtotalMinor != persistedTotals.subtotalMinor ||
        transactionRow.modifierTotalMinor !=
            persistedTotals.modifierTotalMinor ||
        transactionRow.totalAmountMinor != persistedTotals.totalAmountMinor) {
      throw DatabaseException(
        'Breakfast snapshot recompute mismatch between recomputed totals and persisted transaction state for transaction ${lineRow.transactionId}.',
      );
    }
  }

  int _modifierContributionMinor({
    required db.OrderModifier modifierRow,
    required db.TransactionLine lineRow,
  }) {
    if (_isSemanticModifierRow(modifierRow)) {
      return _readSemanticModifierContributionMinor(modifierRow);
    }
    return modifierRow.extraPriceMinor * lineRow.quantity;
  }

  int _readSemanticModifierContributionMinor(db.OrderModifier row) {
    return _readBreakfastSemanticPriceEffectMinor(
      row: row,
      sourceField: 'price_effect_minor',
    );
  }

  int _readBreakfastSemanticPriceEffectMinor({
    required db.OrderModifier row,
    required String sourceField,
  }) {
    if (sourceField != 'price_effect_minor') {
      throw DatabaseException(
        'Breakfast semantic totals must use price_effect_minor, not $sourceField for modifier ${row.uuid}.',
      );
    }
    return row.priceEffectMinor;
  }

  int _sumBreakfastSemanticModifierPriceEffects(
    List<db.OrderModifier> persistedModifiers,
  ) {
    int totalMinor = 0;
    for (final db.OrderModifier modifierRow in persistedModifiers) {
      if (!_isSemanticModifierRow(modifierRow)) {
        throw DatabaseException(
          'Breakfast snapshot recompute received an invalid recomputation source row ${modifierRow.uuid}.',
        );
      }
      totalMinor += _readSemanticModifierContributionMinor(modifierRow);
    }
    return totalMinor;
  }

  Future<List<db.OrderModifier>> _findModifierRowsByLine(
    int transactionLineId,
  ) async {
    return (_database.select(_database.orderModifiers)
          ..where((db.$OrderModifiersTable t) {
            return t.transactionLineId.equals(transactionLineId);
          })
          ..orderBy(<OrderingTerm Function(db.$OrderModifiersTable)>[
            (db.$OrderModifiersTable t) => OrderingTerm.asc(t.sortKey),
            (db.$OrderModifiersTable t) => OrderingTerm.asc(t.id),
          ]))
        .get();
  }

  void _assertBreakfastRecomputeUsesCommittedPersistedRowsOnly({
    required db.TransactionLine lineRow,
    required List<db.OrderModifier> persistedModifiers,
    required BreakfastLineSnapshot expectedSnapshot,
    required int expectedModifierCount,
  }) {
    if (lineRow.pricingMode != 'set') {
      throw DatabaseException(
        'Breakfast snapshot recompute attempted before snapshot replacement was fully persisted for line ${lineRow.id}.',
      );
    }
    if (lineRow.removalDiscountTotalMinor !=
        expectedSnapshot.removalDiscountTotalMinor) {
      throw DatabaseException(
        'Breakfast snapshot recompute mismatch between persisted removal discount and expected line snapshot for line ${lineRow.id}.',
      );
    }
    if (persistedModifiers.length != expectedModifierCount) {
      throw DatabaseException(
        'Breakfast snapshot recompute attempted before snapshot replacement was fully persisted for line ${lineRow.id}: expected $expectedModifierCount modifiers, found ${persistedModifiers.length}.',
      );
    }
  }

  void _assertBreakfastSnapshotMatchesPersistedRows({
    required int transactionLineId,
    required BreakfastLineSnapshot expectedSnapshot,
    required int recomputedModifierTotalMinor,
    required int recomputedLineTotalMinor,
    required db.TransactionLine lineRow,
  }) {
    if (expectedSnapshot.pricingMode != TransactionLinePricingMode.set) {
      throw DatabaseException(
        'Breakfast snapshot recompute received an invalid recomputation source for line $transactionLineId.',
      );
    }
    if (expectedSnapshot.baseUnitPriceMinor != lineRow.unitPriceMinor) {
      throw DatabaseException(
        'Breakfast snapshot recompute mismatch between persisted base price and expected line snapshot for line $transactionLineId.',
      );
    }
    if (expectedSnapshot.modifierTotalMinor != recomputedModifierTotalMinor ||
        expectedSnapshot.lineTotalMinor != recomputedLineTotalMinor) {
      throw DatabaseException(
        'Breakfast snapshot recompute mismatch between recomputed totals and persisted line state for line $transactionLineId.',
      );
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

  Future<Map<int, String>> _loadProductNamesByIds(
    Iterable<int> productIds,
  ) async {
    final List<int> ids = productIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return <int, String>{};
    }

    final List<db.Product> rows = await (_database.select(
      _database.products,
    )..where((db.$ProductsTable t) => t.id.isIn(ids))).get();
    return <int, String>{for (final db.Product row in rows) row.id: row.name};
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
    return _persistenceMapper.transactionLineFromRow(row);
  }

  OrderModifier _mapModifier(db.OrderModifier row) {
    return _persistenceMapper.orderModifierFromRow(row);
  }

  BreakfastCookingInstructionRecord _mapBreakfastCookingInstruction(
    db.BreakfastCookingInstruction row,
  ) {
    return BreakfastCookingInstructionRecord(
      id: row.id,
      uuid: row.uuid,
      transactionLineId: row.transactionLineId,
      itemProductId: row.itemProductId,
      itemName: row.itemName,
      instructionCode: row.instructionCode,
      instructionLabel: row.instructionLabel,
      appliedQuantity: row.appliedQuantity,
      sortKey: row.sortKey,
    );
  }

  TransactionStatus _statusFromDb(String value) {
    switch (value) {
      case 'open':
        // Legacy compatibility only: older persisted rows may still carry
        // `open`, but migrations normalize that value to `sent`.
        return TransactionStatus.sent;
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

  String _modifierActionToDb(ModifierAction value) {
    switch (value) {
      case ModifierAction.remove:
        return 'remove';
      case ModifierAction.add:
        return 'add';
      case ModifierAction.choice:
        return 'choice';
    }
  }

  String? _modifierChargeReasonToDb(ModifierChargeReason? value) {
    switch (value) {
      case null:
        return null;
      case ModifierChargeReason.includedChoice:
        return 'included_choice';
      case ModifierChargeReason.freeSwap:
        return 'free_swap';
      case ModifierChargeReason.paidSwap:
        return 'paid_swap';
      case ModifierChargeReason.extraAdd:
        return 'extra_add';
      case ModifierChargeReason.removalDiscount:
        return 'removal_discount';
      case ModifierChargeReason.comboDiscount:
        return 'combo_discount';
    }
  }

  String? _modifierPriceBehaviorToDb(ModifierPriceBehavior? value) {
    switch (value) {
      case null:
        return null;
      case ModifierPriceBehavior.free:
        return 'free';
      case ModifierPriceBehavior.paid:
        return 'paid';
    }
  }

  String? _modifierUiSectionToDb(ModifierUiSection? value) {
    switch (value) {
      case null:
        return null;
      case ModifierUiSection.toppings:
        return 'toppings';
      case ModifierUiSection.sauces:
        return 'sauces';
      case ModifierUiSection.addIns:
        return 'add_ins';
    }
  }

  db.OrderModifiersCompanion _serializeBreakfastSnapshotModifier({
    required int transactionLineId,
    required BreakfastClassifiedModifier modifier,
  }) {
    _assertExpectedSemanticFields(modifier);
    final OrderModifier domainModifier = OrderModifier(
      id: 0,
      uuid: _uuidGenerator.v4(),
      transactionLineId: transactionLineId,
      action: modifier.action,
      itemName: modifier.displayName,
      extraPriceMinor: modifier.priceEffectMinor,
      chargeReason: modifier.chargeReason,
      itemProductId: modifier.itemProductId,
      sourceGroupId: modifier.sourceGroupId,
      quantity: modifier.quantity,
      unitPriceMinor: modifier.unitPriceMinor,
      priceEffectMinor: modifier.priceEffectMinor,
      sortKey: modifier.sortKey,
    );
    final db.OrderModifiersCompanion companion = _persistenceMapper
        .orderModifierToCompanion(domainModifier);
    _assertSerializedSemanticFieldsMatch(
      transactionLineId: transactionLineId,
      modifier: modifier,
      companion: companion,
    );
    return companion;
  }

  void _assertExpectedSemanticFields(BreakfastClassifiedModifier modifier) {
    final bool isExplicitNoneChoice =
        modifier.action == ModifierAction.choice &&
        modifier.chargeReason == ModifierChargeReason.includedChoice &&
        modifier.itemProductId == null;
    if (!isExplicitNoneChoice && modifier.itemProductId == null) {
      throw DatabaseException(
        'Breakfast snapshot row is missing item_product_id for ${modifier.displayName}.',
      );
    }
    if (modifier.quantity <= 0) {
      throw DatabaseException(
        'Breakfast snapshot row has invalid quantity ${modifier.quantity} for ${modifier.displayName}.',
      );
    }
    if (modifier.sortKey <= 0) {
      throw DatabaseException(
        'Breakfast snapshot row is missing sort_key for ${modifier.displayName}.',
      );
    }
    if (modifier.unitPriceMinor < 0 || modifier.priceEffectMinor < 0) {
      throw DatabaseException(
        'Breakfast snapshot row has negative semantic price fields for ${modifier.displayName}.',
      );
    }
    if (isExplicitNoneChoice &&
        (modifier.unitPriceMinor != 0 || modifier.priceEffectMinor != 0)) {
      throw DatabaseException(
        'Breakfast explicit-none choice row must persist zero semantic prices for ${modifier.displayName}.',
      );
    }
    if (modifier.action == ModifierAction.choice &&
        modifier.chargeReason != ModifierChargeReason.includedChoice) {
      throw DatabaseException(
        'Breakfast choice snapshot row must persist included_choice for ${modifier.displayName}.',
      );
    }
    if (modifier.action == ModifierAction.add &&
        modifier.chargeReason == null) {
      throw DatabaseException(
        'Breakfast add snapshot row is missing charge_reason for ${modifier.displayName}.',
      );
    }
    if (modifier.action == ModifierAction.remove &&
        modifier.chargeReason != null) {
      throw DatabaseException(
        'Breakfast remove snapshot row must not persist charge_reason for ${modifier.displayName}.',
      );
    }
  }

  void _assertSerializedSemanticFieldsMatch({
    required int transactionLineId,
    required BreakfastClassifiedModifier modifier,
    required db.OrderModifiersCompanion companion,
  }) {
    final String expectedAction = _modifierActionToDb(modifier.action);
    final String? expectedChargeReason = _modifierChargeReasonToDb(
      modifier.chargeReason,
    );

    if (!companion.transactionLineId.present ||
        companion.transactionLineId.value != transactionLineId) {
      throw DatabaseException(
        'Breakfast snapshot serializer changed transaction_line_id for ${modifier.displayName}.',
      );
    }
    if (!companion.action.present || companion.action.value != expectedAction) {
      throw DatabaseException(
        'Breakfast snapshot serializer mutated action for ${modifier.displayName}.',
      );
    }
    if (!companion.chargeReason.present ||
        companion.chargeReason.value != expectedChargeReason) {
      throw DatabaseException(
        'Breakfast snapshot serializer mutated charge_reason for ${modifier.displayName}.',
      );
    }
    if (!companion.itemProductId.present ||
        companion.itemProductId.value != modifier.itemProductId) {
      throw DatabaseException(
        'Breakfast snapshot serializer mutated item_product_id for ${modifier.displayName}.',
      );
    }
    if (!companion.quantity.present ||
        companion.quantity.value != modifier.quantity) {
      throw DatabaseException(
        'Breakfast snapshot serializer mutated quantity for ${modifier.displayName}.',
      );
    }
    if (!companion.unitPriceMinor.present ||
        companion.unitPriceMinor.value != modifier.unitPriceMinor) {
      throw DatabaseException(
        'Breakfast snapshot serializer mutated unit_price_minor for ${modifier.displayName}.',
      );
    }
    if (!companion.priceEffectMinor.present ||
        companion.priceEffectMinor.value != modifier.priceEffectMinor) {
      throw DatabaseException(
        'Breakfast snapshot serializer mutated price_effect_minor for ${modifier.displayName}.',
      );
    }
    if (!companion.sortKey.present ||
        companion.sortKey.value != modifier.sortKey) {
      throw DatabaseException(
        'Breakfast snapshot serializer mutated sort_key for ${modifier.displayName}.',
      );
    }
  }

  void _assertPersistedSemanticFieldsMatchCompanion({
    required db.OrderModifiersCompanion companion,
    required db.OrderModifier row,
  }) {
    if (row.transactionLineId != companion.transactionLineId.value ||
        row.action != companion.action.value ||
        row.chargeReason != companion.chargeReason.value ||
        row.itemProductId != companion.itemProductId.value ||
        row.quantity != companion.quantity.value ||
        row.unitPriceMinor != companion.unitPriceMinor.value ||
        row.priceEffectMinor != companion.priceEffectMinor.value ||
        row.sortKey != companion.sortKey.value) {
      throw DatabaseException(
        'Breakfast snapshot replace persisted mutated semantic fields for modifier ${row.uuid}.',
      );
    }
  }

  Future<int> _countSiblingModifierRows(int transactionLineId) async {
    final QueryRow row = await _database
        .customSelect(
          '''
      SELECT COUNT(*) AS sibling_count
      FROM order_modifiers
      WHERE transaction_line_id != ?
      ''',
          variables: <Variable<Object>>[Variable<int>(transactionLineId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.orderModifiers,
          },
        )
        .getSingle();
    return row.read<int>('sibling_count');
  }

  Future<void> _assertSiblingModifierRowsUnchanged({
    required int transactionLineId,
    required int expectedSiblingCount,
    required String phase,
  }) async {
    final int actualSiblingCount = await _countSiblingModifierRows(
      transactionLineId,
    );
    if (actualSiblingCount != expectedSiblingCount) {
      throw DatabaseException(
        'Breakfast snapshot replace touched sibling lines during $phase for line $transactionLineId.',
      );
    }
  }

  bool _isSemanticModifierRow(db.OrderModifier row) {
    return row.chargeReason != null ||
        row.action == 'choice' ||
        row.itemProductId != null ||
        row.sortKey > 0;
  }

  bool _isMealCustomizationSemanticModifierRow(db.OrderModifier row) {
    final String? chargeReason = row.chargeReason;
    return chargeReason == 'extra_add' ||
        chargeReason == 'free_swap' ||
        chargeReason == 'paid_swap' ||
        chargeReason == 'removal_discount' ||
        chargeReason == 'combo_discount';
  }

  Future<void> _deleteLineArtifactsInCurrentTransaction(
    int transactionLineId,
  ) async {
    await (_database.delete(_database.orderModifiers)
          ..where((db.$OrderModifiersTable t) {
            return t.transactionLineId.equals(transactionLineId);
          }))
        .go();
    await (_database.delete(_database.breakfastCookingInstructions)
          ..where((db.$BreakfastCookingInstructionsTable t) {
            return t.transactionLineId.equals(transactionLineId);
          }))
        .go();
    await _database.customUpdate(
      'DELETE FROM $_mealCustomizationSnapshotsTable WHERE transaction_line_id = ?',
      variables: <Variable<Object>>[Variable<int>(transactionLineId)],
      updates: <ResultSetImplementation<dynamic, dynamic>>{},
    );
  }

  bool _isUniqueIdempotencyViolation(SqliteException error) {
    final String message = error.message.toLowerCase();
    return error.extendedResultCode == 2067 &&
        message.contains('transactions.idempotency_key');
  }
}
