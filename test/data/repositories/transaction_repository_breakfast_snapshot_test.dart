import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/mappers/transaction_persistence_mapper.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/breakfast_cooking_instruction.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('TransactionRepository breakfast snapshot replace', () {
    test('replace also persists structured cooking instructions', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      await fixture.repository.replaceBreakfastLineSnapshot(
        transactionLineId: fixture.targetLineId,
        rebuildResult: fixture.validRebuildResult,
        cookingInstructions: <BreakfastCookingInstructionRecord>[
          BreakfastCookingInstructionRecord(
            id: 0,
            uuid: 'instruction-1',
            transactionLineId: 0,
            itemProductId: fixture.eggProductId,
            itemName: 'Egg',
            instructionCode: 'runny',
            instructionLabel: 'Runny',
            appliedQuantity: 1,
            sortKey: 1,
          ),
        ],
      );

      final List<BreakfastCookingInstructionRecord> instructions = await fixture
          .repository
          .getBreakfastCookingInstructionsByLine(fixture.targetLineId);

      expect(instructions, hasLength(1));
      expect(instructions.single.itemProductId, fixture.eggProductId);
      expect(instructions.single.instructionCode, 'runny');
      expect(instructions.single.kitchenLabel, 'Egg x1 - RUNNY');
    });

    test('recompute_uses_committed_persisted_rows_only', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      await fixture.repository.replaceBreakfastLineSnapshot(
        transactionLineId: fixture.targetLineId,
        rebuildResult: fixture.validRebuildResult,
      );

      final app_db.TransactionLine line = await _lineById(
        fixture.db,
        fixture.targetLineId,
      );
      final Transaction transaction = (await fixture.repository.getById(
        fixture.transactionId,
      ))!;

      expect(line.lineTotalMinor, 560);
      expect(line.removalDiscountTotalMinor, 0);
      expect(transaction.subtotalMinor, 800);
      expect(transaction.modifierTotalMinor, 325);
      expect(transaction.totalAmountMinor, 1125);
    });

    test('recompute_rejects_incremental_deltas', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      await expectLater(
        fixture.repository.replaceBreakfastLineSnapshot(
          transactionLineId: fixture.targetLineId,
          rebuildResult: _rebuildResult(
            modifiers: fixture.validRebuildResult.classifiedModifiers,
            lineTotalMinor: 635,
          ),
        ),
        throwsA(
          isA<DatabaseException>().having(
            (DatabaseException error) => error.message,
            'message',
            contains(
              'mismatch between recomputed totals and persisted line state',
            ),
          ),
        ),
      );

      final app_db.TransactionLine line = await _lineById(
        fixture.db,
        fixture.targetLineId,
      );
      expect(line.lineTotalMinor, 400);
      expect(
        await _modifierUuidsByLine(fixture.db, fixture.targetLineId),
        fixture.originalTargetModifierUuids,
      );
    });

    test('recompute_rejects_stale_cached_totals', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      await fixture.db.customStatement('''
        UPDATE transactions
        SET subtotal_minor = 9999,
            modifier_total_minor = 8888,
            total_amount_minor = 7777
        WHERE id = ${fixture.transactionId}
        ''');

      await fixture.repository.replaceBreakfastLineSnapshot(
        transactionLineId: fixture.targetLineId,
        rebuildResult: fixture.validRebuildResult,
      );

      final Transaction transaction = (await fixture.repository.getById(
        fixture.transactionId,
      ))!;
      expect(transaction.subtotalMinor, 800);
      expect(transaction.modifierTotalMinor, 325);
      expect(transaction.totalAmountMinor, 1125);
    });

    test('recompute_rejects_intermediate_delete_state', () async {
      final _SnapshotFixture fixture = await _createFixture(
        beforeBreakfastSnapshotFinancialRecompute:
            (app_db.AppDatabase database, int transactionLineId, _) async {
              await (database.delete(database.orderModifiers)
                    ..where((app_db.$OrderModifiersTable t) {
                      return t.transactionLineId.equals(transactionLineId);
                    }))
                  .go();
            },
      );
      addTearDown(fixture.db.close);

      await expectLater(
        fixture.repository.replaceBreakfastLineSnapshot(
          transactionLineId: fixture.targetLineId,
          rebuildResult: fixture.validRebuildResult,
        ),
        throwsA(
          isA<DatabaseException>().having(
            (DatabaseException error) => error.message,
            'message',
            contains('fully persisted'),
          ),
        ),
      );

      expect(
        await _modifierUuidsByLine(fixture.db, fixture.targetLineId),
        fixture.originalTargetModifierUuids,
      );
    });

    test('recompute_uses_price_effect_minor_not_extra_price_minor', () async {
      final _SnapshotFixture fixture = await _createFixture(
        beforeBreakfastSnapshotFinancialRecompute:
            (app_db.AppDatabase database, int transactionLineId, _) async {
              await database.customStatement('''
                UPDATE order_modifiers
                SET extra_price_minor = 9999
                WHERE transaction_line_id = $transactionLineId
                  AND charge_reason = 'extra_add'
                ''');
            },
      );
      addTearDown(fixture.db.close);

      await fixture.repository.replaceBreakfastLineSnapshot(
        transactionLineId: fixture.targetLineId,
        rebuildResult: fixture.validRebuildResult,
      );

      final Transaction transaction = (await fixture.repository.getById(
        fixture.transactionId,
      ))!;
      expect(transaction.modifierTotalMinor, 325);
      expect(transaction.totalAmountMinor, 1125);
    });

    test('recompute_matches_replaced_breakfast_snapshot_state', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      await fixture.repository.replaceBreakfastLineSnapshot(
        transactionLineId: fixture.targetLineId,
        rebuildResult: fixture.validRebuildResult,
      );

      final app_db.TransactionLine line = await _lineById(
        fixture.db,
        fixture.targetLineId,
      );
      expect(
        line.lineTotalMinor,
        fixture.validRebuildResult.lineSnapshot.lineTotalMinor,
      );
      expect(
        line.removalDiscountTotalMinor,
        fixture.validRebuildResult.lineSnapshot.removalDiscountTotalMinor,
      );
    });

    test('recompute_safe_with_mixed_semantic_and_legacy_rows', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      await fixture.repository.replaceBreakfastLineSnapshot(
        transactionLineId: fixture.targetLineId,
        rebuildResult: fixture.validRebuildResult,
      );

      final Transaction transaction = (await fixture.repository.getById(
        fixture.transactionId,
      ))!;
      expect(transaction.modifierTotalMinor, 325);
      expect(transaction.totalAmountMinor, 1125);

      final List<OrderModifier> siblingModifiers = await fixture.repository
          .getModifiersByLine(fixture.siblingLineId);
      expect(siblingModifiers, hasLength(3));
      expect(siblingModifiers[0].chargeReason, isNull);
      expect(siblingModifiers[0].unitPriceMinor, 0);
      expect(siblingModifiers[0].priceEffectMinor, 0);

      expect(siblingModifiers[1].chargeReason, isNull);
      expect(siblingModifiers[1].unitPriceMinor, 75);
      expect(siblingModifiers[1].priceEffectMinor, 75);

      expect(
        siblingModifiers[2].chargeReason,
        ModifierChargeReason.includedChoice,
      );
      expect(siblingModifiers[2].sortKey, 11);
    });

    test('rollback_or_fail_fast_on_invalid_recompute_source', () async {
      final _SnapshotFixture fixture = await _createFixture(
        beforeBreakfastSnapshotFinancialRecompute:
            (app_db.AppDatabase database, int transactionLineId, _) async {
              await database.customStatement('''
                UPDATE order_modifiers
                SET charge_reason = NULL,
                    item_product_id = NULL,
                    sort_key = 0
                WHERE transaction_line_id = $transactionLineId
                  AND charge_reason = 'extra_add'
                ''');
            },
      );
      addTearDown(fixture.db.close);

      await expectLater(
        fixture.repository.replaceBreakfastLineSnapshot(
          transactionLineId: fixture.targetLineId,
          rebuildResult: fixture.validRebuildResult,
        ),
        throwsA(
          isA<DatabaseException>().having(
            (DatabaseException error) => error.message,
            'message',
            contains('invalid recomputation source'),
          ),
        ),
      );

      final app_db.TransactionLine line = await _lineById(
        fixture.db,
        fixture.targetLineId,
      );
      expect(line.lineTotalMinor, 400);
      expect(
        await _modifierUuidsByLine(fixture.db, fixture.targetLineId),
        fixture.originalTargetModifierUuids,
      );
    });

    test('replace_snapshot_scoped_to_one_line_only', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      await fixture.repository.replaceBreakfastLineSnapshot(
        transactionLineId: fixture.targetLineId,
        rebuildResult: fixture.validRebuildResult,
      );

      expect(
        await _modifierUuidsByLine(fixture.db, fixture.targetLineId),
        hasLength(3),
      );
      expect(
        await _modifierUuidsByLine(fixture.db, fixture.siblingLineId),
        fixture.originalSiblingModifierUuids,
      );
      expect(
        await _modifierUuidsByLine(fixture.db, fixture.externalLineId),
        fixture.originalExternalModifierUuids,
      );
    });

    test('delete_then_insert_occurs_in_single_transaction', () async {
      final _SnapshotFixture fixture = await _createFixture(
        mapper: const _DuplicateModifierUuidMapper(),
      );
      addTearDown(fixture.db.close);

      await expectLater(
        fixture.repository.replaceBreakfastLineSnapshot(
          transactionLineId: fixture.targetLineId,
          rebuildResult: fixture.validRebuildResult,
        ),
        throwsA(isA<Exception>()),
      );

      expect(
        await _modifierUuidsByLine(fixture.db, fixture.targetLineId),
        fixture.originalTargetModifierUuids,
      );
      expect(
        await _modifierUuidsByLine(fixture.db, fixture.siblingLineId),
        fixture.originalSiblingModifierUuids,
      );
    });

    test('sibling_lines_unchanged_after_replace', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);
      final List<Map<String, Object?>> siblingBefore = await _modifierSnapshots(
        fixture.db,
        fixture.siblingLineId,
      );

      await fixture.repository.replaceBreakfastLineSnapshot(
        transactionLineId: fixture.targetLineId,
        rebuildResult: fixture.validRebuildResult,
      );

      expect(
        await _modifierSnapshots(fixture.db, fixture.siblingLineId),
        siblingBefore,
      );
    });

    test('repository_does_not_mutate_classification_fields', () async {
      final _SnapshotFixture fixture = await _createFixture(
        mapper: const _MutatingChargeReasonMapper(),
      );
      addTearDown(fixture.db.close);

      await expectLater(
        fixture.repository.replaceBreakfastLineSnapshot(
          transactionLineId: fixture.targetLineId,
          rebuildResult: fixture.validRebuildResult,
        ),
        throwsA(
          isA<DatabaseException>().having(
            (DatabaseException error) => error.message,
            'message',
            contains('mutated charge_reason'),
          ),
        ),
      );

      expect(
        await _modifierUuidsByLine(fixture.db, fixture.targetLineId),
        fixture.originalTargetModifierUuids,
      );
    });

    test('replace_rolls_back_on_insert_failure', () async {
      final _SnapshotFixture fixture = await _createFixture(
        mapper: const _DuplicateModifierUuidMapper(),
      );
      addTearDown(fixture.db.close);

      await expectLater(
        fixture.repository.replaceBreakfastLineSnapshot(
          transactionLineId: fixture.targetLineId,
          rebuildResult: fixture.validRebuildResult,
        ),
        throwsA(isA<Exception>()),
      );

      final app_db.TransactionLine targetLine = await _lineById(
        fixture.db,
        fixture.targetLineId,
      );
      expect(targetLine.pricingMode, 'standard');
      expect(targetLine.lineTotalMinor, 400);
      expect(
        await _modifierSnapshots(fixture.db, fixture.targetLineId),
        fixture.originalTargetModifierSnapshots,
      );
    });

    test('sort_key_preserved_on_replace', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      await fixture.repository.replaceBreakfastLineSnapshot(
        transactionLineId: fixture.targetLineId,
        rebuildResult: fixture.unsortedRebuildResult,
      );

      final List<OrderModifier> modifiers = await fixture.repository
          .getModifiersByLine(fixture.targetLineId);

      expect(
        modifiers.map((OrderModifier modifier) => modifier.sortKey).toList(),
        <int>[10, 20, 30],
      );
      expect(
        modifiers.map((OrderModifier modifier) => modifier.itemName).toList(),
        <String>['Egg', 'Tea', 'Beans'],
      );
    });

    test('semantic_rows_require_expected_fields', () async {
      final _SnapshotFixture fixture = await _createFixture();
      addTearDown(fixture.db.close);

      await expectLater(
        fixture.repository.replaceBreakfastLineSnapshot(
          transactionLineId: fixture.targetLineId,
          rebuildResult: _rebuildResult(
            modifiers: <BreakfastClassifiedModifier>[
              BreakfastClassifiedModifier(
                kind: BreakfastModifierKind.extraAdd,
                action: ModifierAction.add,
                chargeReason: null,
                itemProductId: null,
                displayName: 'Broken Add',
                quantity: 1,
                unitPriceMinor: 80,
                priceEffectMinor: 80,
                sortKey: 0,
              ),
            ],
            lineTotalMinor: 480,
          ),
        ),
        throwsA(
          isA<DatabaseException>().having(
            (DatabaseException error) => error.message,
            'message',
            contains('missing item_product_id'),
          ),
        ),
      );

      expect(
        await _modifierUuidsByLine(fixture.db, fixture.targetLineId),
        fixture.originalTargetModifierUuids,
      );
    });

    test(
      'explicit none choice rows persist with null item_product_id',
      () async {
        final _SnapshotFixture fixture = await _createFixture();
        addTearDown(fixture.db.close);

        await fixture.repository.replaceBreakfastLineSnapshot(
          transactionLineId: fixture.targetLineId,
          rebuildResult: _rebuildResult(
            modifiers: <BreakfastClassifiedModifier>[
              BreakfastClassifiedModifier(
                kind: BreakfastModifierKind.choiceIncluded,
                action: ModifierAction.choice,
                chargeReason: ModifierChargeReason.includedChoice,
                itemProductId: null,
                displayName: breakfastNoneChoiceDisplayName,
                quantity: 1,
                unitPriceMinor: 0,
                priceEffectMinor: 0,
                sortKey: 20,
                sourceGroupId: fixture.groupId,
              ),
            ],
            lineTotalMinor: 400,
          ),
        );

        final List<Map<String, Object?>> snapshots = await _modifierSnapshots(
          fixture.db,
          fixture.targetLineId,
        );
        expect(snapshots, hasLength(1));
        expect(snapshots.single['item_product_id'], isNull);
        expect(snapshots.single['charge_reason'], 'included_choice');
        expect(snapshots.single['source_group_id'], fixture.groupId);
        expect(snapshots.single['unit_price_minor'], 0);
        expect(snapshots.single['price_effect_minor'], 0);
      },
    );
  });
}

Future<_SnapshotFixture> _createFixture({
  TransactionPersistenceMapper mapper = const TransactionPersistenceMapper(),
  Future<void> Function(
    app_db.AppDatabase database,
    int transactionLineId,
    int transactionId,
  )?
  beforeBreakfastSnapshotFinancialRecompute,
}) async {
  final app_db.AppDatabase db = createTestDatabase();
  final int breakfastCategoryId = await insertCategory(
    db,
    name: 'Set Breakfast',
  );
  final int hotDrinkCategoryId = await insertCategory(db, name: 'Hot Drinks');
  final int extrasCategoryId = await insertCategory(db, name: 'Extras');

  final int setProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set 4',
    priceMinor: 400,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Egg',
    priceMinor: 120,
  );
  final int beansProductId = await insertProduct(
    db,
    categoryId: extrasCategoryId,
    name: 'Beans',
    priceMinor: 80,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: hotDrinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int shiftId = await insertShift(db, openedBy: cashierId);
  final int transactionId = await insertTransaction(
    db,
    uuid: 'tx-breakfast-replace',
    shiftId: shiftId,
    userId: cashierId,
    status: 'draft',
    totalAmountMinor: 1200,
  );
  final int secondTransactionId = await insertTransaction(
    db,
    uuid: 'tx-breakfast-external',
    shiftId: shiftId,
    userId: cashierId,
    status: 'draft',
    totalAmountMinor: 400,
  );

  final int groupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: setProductId,
          name: 'Tea or Coffee',
          minSelect: const Value<int>(0),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );

  final int targetLineId = await db
      .into(db.transactionLines)
      .insert(
        app_db.TransactionLinesCompanion.insert(
          uuid: 'line-target',
          transactionId: transactionId,
          productId: setProductId,
          productName: 'Set 4',
          unitPriceMinor: 400,
          quantity: const Value<int>(1),
          lineTotalMinor: 400,
          pricingMode: const Value<String>('standard'),
        ),
      );
  final int siblingLineId = await db
      .into(db.transactionLines)
      .insert(
        app_db.TransactionLinesCompanion.insert(
          uuid: 'line-sibling',
          transactionId: transactionId,
          productId: setProductId,
          productName: 'Set 4',
          unitPriceMinor: 400,
          quantity: const Value<int>(1),
          lineTotalMinor: 475,
          pricingMode: const Value<String>('set'),
        ),
      );
  final int externalLineId = await db
      .into(db.transactionLines)
      .insert(
        app_db.TransactionLinesCompanion.insert(
          uuid: 'line-external',
          transactionId: secondTransactionId,
          productId: setProductId,
          productName: 'Set 4',
          unitPriceMinor: 400,
          quantity: const Value<int>(1),
          lineTotalMinor: 475,
          pricingMode: const Value<String>('set'),
        ),
      );

  await _insertRawModifier(
    db,
    uuid: 'target-old-1',
    transactionLineId: targetLineId,
    action: 'add',
    itemName: 'Old Extra',
    quantity: 1,
    itemProductId: null,
    sourceGroupId: null,
    extraPriceMinor: 75,
    chargeReason: null,
    unitPriceMinor: 0,
    priceEffectMinor: 0,
    sortKey: 0,
  );
  await _insertRawModifier(
    db,
    uuid: 'target-old-2',
    transactionLineId: targetLineId,
    action: 'choice',
    itemName: 'Old Tea',
    quantity: 1,
    itemProductId: teaProductId,
    sourceGroupId: groupId,
    extraPriceMinor: 0,
    chargeReason: 'included_choice',
    unitPriceMinor: 150,
    priceEffectMinor: 0,
    sortKey: 11,
  );

  await _insertRawModifier(
    db,
    uuid: 'sibling-legacy',
    transactionLineId: siblingLineId,
    action: 'add',
    itemName: 'Legacy Extra',
    quantity: 1,
    itemProductId: null,
    sourceGroupId: null,
    extraPriceMinor: 90,
    chargeReason: null,
    unitPriceMinor: 0,
    priceEffectMinor: 0,
    sortKey: 0,
  );
  await _insertRawModifier(
    db,
    uuid: 'sibling-migrated',
    transactionLineId: siblingLineId,
    action: 'add',
    itemName: 'Migrated Legacy',
    quantity: 1,
    itemProductId: null,
    sourceGroupId: null,
    extraPriceMinor: 75,
    chargeReason: null,
    unitPriceMinor: 75,
    priceEffectMinor: 75,
    sortKey: 0,
  );
  await _insertRawModifier(
    db,
    uuid: 'sibling-semantic',
    transactionLineId: siblingLineId,
    action: 'choice',
    itemName: 'Tea',
    quantity: 1,
    itemProductId: teaProductId,
    sourceGroupId: groupId,
    extraPriceMinor: 0,
    chargeReason: 'included_choice',
    unitPriceMinor: 150,
    priceEffectMinor: 0,
    sortKey: 11,
  );

  await _insertRawModifier(
    db,
    uuid: 'external-legacy',
    transactionLineId: externalLineId,
    action: 'add',
    itemName: 'External Legacy',
    quantity: 1,
    itemProductId: null,
    sourceGroupId: null,
    extraPriceMinor: 55,
    chargeReason: null,
    unitPriceMinor: 0,
    priceEffectMinor: 0,
    sortKey: 0,
  );

  final List<String> originalTargetModifierUuids = await _modifierUuidsByLine(
    db,
    targetLineId,
  );
  final List<Map<String, Object?>> originalTargetModifierSnapshots =
      await _modifierSnapshots(db, targetLineId);
  final List<String> originalSiblingModifierUuids = await _modifierUuidsByLine(
    db,
    siblingLineId,
  );
  final List<String> originalExternalModifierUuids = await _modifierUuidsByLine(
    db,
    externalLineId,
  );

  return _SnapshotFixture(
    db: db,
    repository: TransactionRepository(
      db,
      beforeBreakfastSnapshotFinancialRecompute:
          beforeBreakfastSnapshotFinancialRecompute,
      persistenceMapper: mapper,
    ),
    transactionId: transactionId,
    targetLineId: targetLineId,
    siblingLineId: siblingLineId,
    externalLineId: externalLineId,
    groupId: groupId,
    eggProductId: eggProductId,
    beansProductId: beansProductId,
    teaProductId: teaProductId,
    originalTargetModifierUuids: originalTargetModifierUuids,
    originalTargetModifierSnapshots: originalTargetModifierSnapshots,
    originalSiblingModifierUuids: originalSiblingModifierUuids,
    originalExternalModifierUuids: originalExternalModifierUuids,
  );
}

Future<void> _insertRawModifier(
  app_db.AppDatabase db, {
  required String uuid,
  required int transactionLineId,
  required String action,
  required String itemName,
  required int quantity,
  required int? itemProductId,
  required int? sourceGroupId,
  required int extraPriceMinor,
  required String? chargeReason,
  required int unitPriceMinor,
  required int priceEffectMinor,
  required int sortKey,
}) async {
  await db
      .into(db.orderModifiers)
      .insert(
        app_db.OrderModifiersCompanion.insert(
          uuid: uuid,
          transactionLineId: transactionLineId,
          action: action,
          itemName: itemName,
          quantity: Value<int>(quantity),
          itemProductId: Value<int?>(itemProductId),
          sourceGroupId: Value<int?>(sourceGroupId),
          extraPriceMinor: Value<int>(extraPriceMinor),
          chargeReason: Value<String?>(chargeReason),
          unitPriceMinor: Value<int>(unitPriceMinor),
          priceEffectMinor: Value<int>(priceEffectMinor),
          sortKey: Value<int>(sortKey),
        ),
      );
}

BreakfastRebuildResult _rebuildResult({
  required List<BreakfastClassifiedModifier> modifiers,
  required int lineTotalMinor,
}) {
  final int modifierTotalMinor = modifiers.fold<int>(
    0,
    (int total, BreakfastClassifiedModifier modifier) =>
        total + modifier.priceEffectMinor,
  );
  return BreakfastRebuildResult(
    lineSnapshot: BreakfastLineSnapshot(
      baseUnitPriceMinor: 400,
      removalDiscountTotalMinor: 0,
      modifierTotalMinor: modifierTotalMinor,
      lineTotalMinor: lineTotalMinor,
    ),
    classifiedModifiers: modifiers,
    pricingBreakdown: BreakfastPricingBreakdown(
      basePriceMinor: 400,
      extraAddTotalMinor: modifierTotalMinor,
      paidSwapTotalMinor: 0,
      freeSwapTotalMinor: 0,
      includedChoiceTotalMinor: 0,
      removeTotalMinor: 0,
      removalDiscountTotalMinor: 0,
      finalLineTotalMinor: lineTotalMinor,
    ),
    validationErrors: const <BreakfastEditErrorCode>[],
    rebuildMetadata: const BreakfastRebuildMetadata(
      replacementCount: 0,
      unmatchedRemovalCount: 0,
    ),
  );
}

Future<List<String>> _modifierUuidsByLine(
  app_db.AppDatabase db,
  int transactionLineId,
) async {
  final List<app_db.OrderModifier> rows =
      await (db.select(db.orderModifiers)
            ..where(
              (app_db.$OrderModifiersTable t) =>
                  t.transactionLineId.equals(transactionLineId),
            )
            ..orderBy(<OrderingTerm Function(app_db.$OrderModifiersTable)>[
              (app_db.$OrderModifiersTable t) => OrderingTerm.asc(t.sortKey),
              (app_db.$OrderModifiersTable t) => OrderingTerm.asc(t.id),
            ]))
          .get();
  return rows
      .map((app_db.OrderModifier row) => row.uuid)
      .toList(growable: false);
}

Future<List<Map<String, Object?>>> _modifierSnapshots(
  app_db.AppDatabase db,
  int transactionLineId,
) async {
  final List<app_db.OrderModifier> rows =
      await (db.select(db.orderModifiers)
            ..where(
              (app_db.$OrderModifiersTable t) =>
                  t.transactionLineId.equals(transactionLineId),
            )
            ..orderBy(<OrderingTerm Function(app_db.$OrderModifiersTable)>[
              (app_db.$OrderModifiersTable t) => OrderingTerm.asc(t.sortKey),
              (app_db.$OrderModifiersTable t) => OrderingTerm.asc(t.id),
            ]))
          .get();

  return rows
      .map(
        (app_db.OrderModifier row) => <String, Object?>{
          'uuid': row.uuid,
          'action': row.action,
          'item_name': row.itemName,
          'quantity': row.quantity,
          'item_product_id': row.itemProductId,
          'source_group_id': row.sourceGroupId,
          'extra_price_minor': row.extraPriceMinor,
          'charge_reason': row.chargeReason,
          'unit_price_minor': row.unitPriceMinor,
          'price_effect_minor': row.priceEffectMinor,
          'sort_key': row.sortKey,
        },
      )
      .toList(growable: false);
}

Future<app_db.TransactionLine> _lineById(app_db.AppDatabase db, int id) {
  return (db.select(
    db.transactionLines,
  )..where((app_db.$TransactionLinesTable t) => t.id.equals(id))).getSingle();
}

class _SnapshotFixture {
  const _SnapshotFixture({
    required this.db,
    required this.repository,
    required this.transactionId,
    required this.targetLineId,
    required this.siblingLineId,
    required this.externalLineId,
    required this.groupId,
    required this.eggProductId,
    required this.beansProductId,
    required this.teaProductId,
    required this.originalTargetModifierUuids,
    required this.originalTargetModifierSnapshots,
    required this.originalSiblingModifierUuids,
    required this.originalExternalModifierUuids,
  });

  final app_db.AppDatabase db;
  final TransactionRepository repository;
  final int transactionId;
  final int targetLineId;
  final int siblingLineId;
  final int externalLineId;
  final int groupId;
  final int eggProductId;
  final int beansProductId;
  final int teaProductId;
  final List<String> originalTargetModifierUuids;
  final List<Map<String, Object?>> originalTargetModifierSnapshots;
  final List<String> originalSiblingModifierUuids;
  final List<String> originalExternalModifierUuids;

  BreakfastRebuildResult get validRebuildResult => _rebuildResult(
    modifiers: <BreakfastClassifiedModifier>[
      BreakfastClassifiedModifier(
        kind: BreakfastModifierKind.setRemove,
        action: ModifierAction.remove,
        itemProductId: eggProductId,
        displayName: 'Egg',
        quantity: 1,
        unitPriceMinor: 0,
        priceEffectMinor: 0,
        sortKey: 10,
      ),
      BreakfastClassifiedModifier(
        kind: BreakfastModifierKind.choiceIncluded,
        action: ModifierAction.choice,
        chargeReason: ModifierChargeReason.includedChoice,
        itemProductId: teaProductId,
        displayName: 'Tea',
        quantity: 1,
        unitPriceMinor: 150,
        priceEffectMinor: 0,
        sortKey: 20,
        sourceGroupId: groupId,
      ),
      BreakfastClassifiedModifier(
        kind: BreakfastModifierKind.extraAdd,
        action: ModifierAction.add,
        chargeReason: ModifierChargeReason.extraAdd,
        itemProductId: beansProductId,
        displayName: 'Beans',
        quantity: 2,
        unitPriceMinor: 80,
        priceEffectMinor: 160,
        sortKey: 30,
      ),
    ],
    lineTotalMinor: 560,
  );

  BreakfastRebuildResult get unsortedRebuildResult => _rebuildResult(
    modifiers: <BreakfastClassifiedModifier>[
      BreakfastClassifiedModifier(
        kind: BreakfastModifierKind.extraAdd,
        action: ModifierAction.add,
        chargeReason: ModifierChargeReason.extraAdd,
        itemProductId: beansProductId,
        displayName: 'Beans',
        quantity: 2,
        unitPriceMinor: 80,
        priceEffectMinor: 160,
        sortKey: 30,
      ),
      BreakfastClassifiedModifier(
        kind: BreakfastModifierKind.setRemove,
        action: ModifierAction.remove,
        itemProductId: eggProductId,
        displayName: 'Egg',
        quantity: 1,
        unitPriceMinor: 0,
        priceEffectMinor: 0,
        sortKey: 10,
      ),
      BreakfastClassifiedModifier(
        kind: BreakfastModifierKind.choiceIncluded,
        action: ModifierAction.choice,
        chargeReason: ModifierChargeReason.includedChoice,
        itemProductId: teaProductId,
        displayName: 'Tea',
        quantity: 1,
        unitPriceMinor: 150,
        priceEffectMinor: 0,
        sortKey: 20,
        sourceGroupId: groupId,
      ),
    ],
    lineTotalMinor: 560,
  );
}

class _DuplicateModifierUuidMapper extends TransactionPersistenceMapper {
  const _DuplicateModifierUuidMapper();

  @override
  app_db.OrderModifiersCompanion orderModifierToCompanion(
    OrderModifier modifier, {
    bool includeId = false,
  }) {
    final app_db.OrderModifiersCompanion companion = super
        .orderModifierToCompanion(modifier, includeId: includeId);
    return app_db.OrderModifiersCompanion(
      id: companion.id,
      uuid: const Value<String>('duplicate-modifier-uuid'),
      transactionLineId: companion.transactionLineId,
      action: companion.action,
      itemName: companion.itemName,
      quantity: companion.quantity,
      itemProductId: companion.itemProductId,
      sourceGroupId: companion.sourceGroupId,
      extraPriceMinor: companion.extraPriceMinor,
      chargeReason: companion.chargeReason,
      unitPriceMinor: companion.unitPriceMinor,
      priceEffectMinor: companion.priceEffectMinor,
      sortKey: companion.sortKey,
    );
  }
}

class _MutatingChargeReasonMapper extends TransactionPersistenceMapper {
  const _MutatingChargeReasonMapper();

  @override
  app_db.OrderModifiersCompanion orderModifierToCompanion(
    OrderModifier modifier, {
    bool includeId = false,
  }) {
    final app_db.OrderModifiersCompanion companion = super
        .orderModifierToCompanion(modifier, includeId: includeId);
    return app_db.OrderModifiersCompanion(
      id: companion.id,
      uuid: companion.uuid,
      transactionLineId: companion.transactionLineId,
      action: companion.action,
      itemName: companion.itemName,
      quantity: companion.quantity,
      itemProductId: companion.itemProductId,
      sourceGroupId: companion.sourceGroupId,
      extraPriceMinor: companion.extraPriceMinor,
      chargeReason:
          companion.chargeReason.present &&
              companion.chargeReason.value == 'extra_add'
          ? const Value<String?>('free_swap')
          : companion.chargeReason,
      unitPriceMinor: companion.unitPriceMinor,
      priceEffectMinor: companion.priceEffectMinor,
      sortKey: companion.sortKey,
    );
  }
}
