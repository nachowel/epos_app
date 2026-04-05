import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/breakfast_cooking_instruction.dart';
import 'package:epos_app/domain/models/breakfast_line_edit.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/breakfast_rebuild_engine.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('OrderService breakfast orchestration', () {
    test('order_service_is_only_breakfast_edit_entry_point', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _ObservingTransactionRepository repository =
          _ObservingTransactionRepository(db);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(
        db,
        transactionRepository: repository,
      );

      final Transaction order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
      );

      await fixture.service.editBreakfastLine(
        transactionLineId: line.id,
        edit: BreakfastLineEdit.chooseGroup(
          groupId: fixture.hotDrinkGroupId,
          selectedItemProductId: fixture.teaProductId,
          quantity: 1,
        ),
      );

      expect(repository.replaceBreakfastLineSnapshotCalls, 1);
      expect(repository.replacedTransactionLineIds, <int>[line.id]);
    });

    test('draft_edit_allowed_sent_paid_cancelled_rejected', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final Transaction draftOrder = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine draftLine = await fixture.service.addProductToOrder(
        transactionId: draftOrder.id,
        productId: fixture.set4ProductId,
      );
      final TransactionLine editedDraftLine = await fixture.service
          .editBreakfastLine(
            transactionLineId: draftLine.id,
            edit: BreakfastLineEdit.chooseGroup(
              groupId: fixture.hotDrinkGroupId,
              selectedItemProductId: fixture.teaProductId,
              quantity: 1,
            ),
          );
      expect(editedDraftLine.pricingMode, TransactionLinePricingMode.set);

      final Transaction sentOrder = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine sentLine = await fixture.service.addProductToOrder(
        transactionId: sentOrder.id,
        productId: fixture.set4ProductId,
      );
      await db.customStatement(
        "UPDATE transactions SET status = 'sent' WHERE id = ${sentOrder.id}",
      );
      await expectLater(
        fixture.service.editBreakfastLine(
          transactionLineId: sentLine.id,
          edit: BreakfastLineEdit.setRemovedQuantity(
            itemProductId: fixture.eggProductId,
            quantity: 1,
          ),
        ),
        throwsA(
          isA<BreakfastLineNotEditableException>().having(
            (BreakfastLineNotEditableException error) => error.reason,
            'reason',
            BreakfastEditBlockedReason.sent,
          ),
        ),
      );

      final Transaction paidOrder = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine paidLine = await fixture.service.addProductToOrder(
        transactionId: paidOrder.id,
        productId: fixture.set4ProductId,
      );
      await db.customStatement(
        "UPDATE transactions SET status = 'paid' WHERE id = ${paidOrder.id}",
      );
      await expectLater(
        fixture.service.editBreakfastLine(
          transactionLineId: paidLine.id,
          edit: BreakfastLineEdit.setRemovedQuantity(
            itemProductId: fixture.eggProductId,
            quantity: 1,
          ),
        ),
        throwsA(
          isA<BreakfastLineNotEditableException>().having(
            (BreakfastLineNotEditableException error) => error.reason,
            'reason',
            BreakfastEditBlockedReason.paid,
          ),
        ),
      );

      final Transaction cancelledOrder = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine cancelledLine = await fixture.service
          .addProductToOrder(
            transactionId: cancelledOrder.id,
            productId: fixture.set4ProductId,
          );
      await db.customStatement('''
        UPDATE transactions
        SET status = 'cancelled'
        WHERE id = ${cancelledOrder.id}
        ''');
      await expectLater(
        fixture.service.editBreakfastLine(
          transactionLineId: cancelledLine.id,
          edit: BreakfastLineEdit.setRemovedQuantity(
            itemProductId: fixture.eggProductId,
            quantity: 1,
          ),
        ),
        throwsA(
          isA<BreakfastLineNotEditableException>().having(
            (BreakfastLineNotEditableException error) => error.reason,
            'reason',
            BreakfastEditBlockedReason.cancelled,
          ),
        ),
      );
    });

    test(
      'every_successful_edit_rebuilds_from_current_requested_state',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

        final Transaction order = await fixture.service.createOrder(
          currentUser: fixture.cashier,
        );
        final TransactionLine line = await fixture.service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.set4ProductId,
        );

        await fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.chooseGroup(
            groupId: fixture.toastBreadGroupId,
            selectedItemProductId: fixture.toastProductId,
            quantity: 4,
          ),
        );

        final TransactionLine clearedLine = await fixture.service
            .editBreakfastLine(
              transactionLineId: line.id,
              edit: BreakfastLineEdit.clearGroup(
                groupId: fixture.toastBreadGroupId,
              ),
            );

        final List<OrderModifier> modifiers = await fixture.service
            .getLineModifiers(clearedLine.id);
        final Transaction refreshedOrder = (await fixture.service.getOrderById(
          order.id,
        ))!;
        expect(modifiers, isEmpty);
        expect(clearedLine.lineTotalMinor, 400);
        expect(refreshedOrder.modifierTotalMinor, 0);
        expect(refreshedOrder.totalAmountMinor, 400);
      },
    );

    test('requested_state_strict_path_used_in_runtime_edit_flow', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _ObservingTransactionRepository repository =
          _ObservingTransactionRepository(db);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(
        db,
        transactionRepository: repository,
      );

      final Transaction order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
      );
      await _insertRawModifier(
        db,
        uuid: 'strict-gap-choice',
        transactionLineId: line.id,
        action: 'choice',
        itemName: 'Tea',
        quantity: 1,
        itemProductId: fixture.teaProductId,
        sourceGroupId: null,
        extraPriceMinor: 0,
        chargeReason: 'included_choice',
        unitPriceMinor: 150,
        priceEffectMinor: 0,
        sortKey: 11,
      );
      await db.customStatement('''
        UPDATE transaction_lines
        SET pricing_mode = 'set',
            line_total_minor = 400
        WHERE id = ${line.id}
        ''');

      await expectLater(
        fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.setRemovedQuantity(
            itemProductId: fixture.eggProductId,
            quantity: 1,
          ),
        ),
        throwsA(
          isA<BreakfastEditRejectedException>().having(
            (BreakfastEditRejectedException error) => error.codes,
            'codes',
            contains(BreakfastEditErrorCode.unsupportedLineSplitState),
          ),
        ),
      );
      expect(repository.replaceBreakfastLineSnapshotCalls, 0);
    });

    test('rebuild_engine_called_with_pricing_mode_set', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _CapturingBreakfastRebuildEngine rebuildEngine =
          _CapturingBreakfastRebuildEngine();
      final _BreakfastFixture fixture = await _seedBreakfastFixture(
        db,
        breakfastRebuildEngine: rebuildEngine,
      );

      final Transaction order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
      );

      await fixture.service.editBreakfastLine(
        transactionLineId: line.id,
        edit: BreakfastLineEdit.chooseGroup(
          groupId: fixture.hotDrinkGroupId,
          selectedItemProductId: fixture.teaProductId,
          quantity: 1,
        ),
      );

      expect(
        rebuildEngine.lastInput!.transactionLine.pricingMode,
        TransactionLinePricingMode.set,
      );
    });

    test('validation_errors_abort_before_persistence', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _ObservingTransactionRepository repository =
          _ObservingTransactionRepository(db);
      final _RejectingBreakfastRebuildEngine rebuildEngine =
          _RejectingBreakfastRebuildEngine(
            rejectionCode: BreakfastEditErrorCode.invalidChoiceGroup,
          );
      final _BreakfastFixture fixture = await _seedBreakfastFixture(
        db,
        transactionRepository: repository,
        breakfastRebuildEngine: rebuildEngine,
      );

      final Transaction order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
      );
      final DateTime frozenUpdatedAt = DateTime(2026, 1, 1, 10, 0, 0);
      await db.customStatement(
        '''
        UPDATE transactions
        SET updated_at = ?
        WHERE id = ?
        ''',
        <Object?>[frozenUpdatedAt.millisecondsSinceEpoch ~/ 1000, order.id],
      );

      await expectLater(
        fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.chooseGroup(
            groupId: fixture.hotDrinkGroupId,
            selectedItemProductId: fixture.teaProductId,
            quantity: 1,
          ),
        ),
        throwsA(
          isA<BreakfastEditRejectedException>().having(
            (BreakfastEditRejectedException error) => error.codes,
            'codes',
            contains(BreakfastEditErrorCode.invalidChoiceGroup),
          ),
        ),
      );

      final TransactionLine refreshedLine =
          (await fixture.service.getOrderLines(order.id)).single;
      final Transaction refreshedOrder = (await fixture.service.getOrderById(
        order.id,
      ))!;
      expect(repository.replaceBreakfastLineSnapshotCalls, 0);
      expect(refreshedLine.lineTotalMinor, 400);
      expect(await fixture.service.getLineModifiers(refreshedLine.id), isEmpty);
      expect(refreshedOrder.updatedAt, frozenUpdatedAt);
    });

    test('successful_edit_replaces_snapshot_and_recomputes_totals', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final Transaction order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
      );

      final TransactionLine updatedLine = await fixture.service
          .editBreakfastLine(
            transactionLineId: line.id,
            edit: BreakfastLineEdit.chooseGroup(
              groupId: fixture.toastBreadGroupId,
              selectedItemProductId: fixture.toastProductId,
              quantity: 4,
            ),
          );

      final List<OrderModifier> modifiers = await fixture.service
          .getLineModifiers(updatedLine.id);
      final Transaction refreshedOrder = (await fixture.service.getOrderById(
        order.id,
      ))!;
      expect(modifiers, hasLength(2));
      expect(updatedLine.lineTotalMinor, 600);
      expect(refreshedOrder.modifierTotalMinor, 200);
      expect(refreshedOrder.totalAmountMinor, 600);
    });

    test('timestamp_updates_only_on_success', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final Transaction successOrder = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine successLine = await fixture.service
          .addProductToOrder(
            transactionId: successOrder.id,
            productId: fixture.set4ProductId,
          );
      final DateTime successOldUpdatedAt = DateTime(2026, 1, 1, 9, 0, 0);
      await db.customStatement(
        'UPDATE transactions SET updated_at = ? WHERE id = ?',
        <Object?>[
          successOldUpdatedAt.millisecondsSinceEpoch ~/ 1000,
          successOrder.id,
        ],
      );

      await fixture.service.editBreakfastLine(
        transactionLineId: successLine.id,
        edit: BreakfastLineEdit.chooseGroup(
          groupId: fixture.hotDrinkGroupId,
          selectedItemProductId: fixture.teaProductId,
          quantity: 1,
        ),
      );

      final Transaction refreshedSuccessOrder = (await fixture.service
          .getOrderById(successOrder.id))!;
      expect(
        refreshedSuccessOrder.updatedAt.isAfter(successOldUpdatedAt),
        isTrue,
      );

      final Transaction failedOrder = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine failedLine = await fixture.service
          .addProductToOrder(
            transactionId: failedOrder.id,
            productId: fixture.set4ProductId,
          );
      final DateTime failedOldUpdatedAt = DateTime(2026, 1, 1, 9, 30, 0);
      await db.customStatement(
        'UPDATE transactions SET updated_at = ? WHERE id = ?',
        <Object?>[
          failedOldUpdatedAt.millisecondsSinceEpoch ~/ 1000,
          failedOrder.id,
        ],
      );

      await expectLater(
        fixture.service.editBreakfastLine(
          transactionLineId: failedLine.id,
          edit: BreakfastLineEdit.setRemovedQuantity(
            itemProductId: fixture.eggProductId,
            quantity: 2,
          ),
        ),
        throwsA(isA<BreakfastEditRejectedException>()),
      );

      final Transaction refreshedFailedOrder = (await fixture.service
          .getOrderById(failedOrder.id))!;
      expect(refreshedFailedOrder.updatedAt, failedOldUpdatedAt);
    });

    test('stale_or_concurrent_edit_fails_safely', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final Transaction order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
      );
      final DateTime sharedUpdatedAt = DateTime(2026, 1, 1, 8, 0, 0);
      await db.customStatement(
        'UPDATE transactions SET updated_at = ? WHERE id = ?',
        <Object?>[sharedUpdatedAt.millisecondsSinceEpoch ~/ 1000, order.id],
      );

      await fixture.service.editBreakfastLine(
        transactionLineId: line.id,
        edit: BreakfastLineEdit.chooseGroup(
          groupId: fixture.hotDrinkGroupId,
          selectedItemProductId: fixture.teaProductId,
          quantity: 1,
        ),
        expectedTransactionUpdatedAt: sharedUpdatedAt,
      );

      await expectLater(
        fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.setAddedQuantity(
            itemProductId: fixture.beansProductId,
            quantity: 1,
          ),
          expectedTransactionUpdatedAt: sharedUpdatedAt,
        ),
        throwsA(
          isA<StaleBreakfastEditException>().having(
            (StaleBreakfastEditException error) => error.transactionLineId,
            'transactionLineId',
            line.id,
          ),
        ),
      );

      final List<OrderModifier> modifiers = await fixture.service
          .getLineModifiers(line.id);
      final Transaction refreshedOrder = (await fixture.service.getOrderById(
        order.id,
      ))!;
      expect(
        modifiers.where(
          (OrderModifier modifier) =>
              modifier.chargeReason == ModifierChargeReason.includedChoice,
        ),
        hasLength(1),
      );
      expect(refreshedOrder.totalAmountMinor, 400);
    });

    test('missing_stale_token_behavior_is_explicit', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final Transaction order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
      );
      final DateTime staleUpdatedAt = DateTime(2026, 1, 1, 7, 0, 0);
      final DateTime newerUpdatedAt = DateTime(2026, 1, 1, 7, 5, 0);
      await db.customStatement(
        'UPDATE transactions SET updated_at = ? WHERE id = ?',
        <Object?>[staleUpdatedAt.millisecondsSinceEpoch ~/ 1000, order.id],
      );
      await db.customStatement(
        'UPDATE transactions SET updated_at = ? WHERE id = ?',
        <Object?>[newerUpdatedAt.millisecondsSinceEpoch ~/ 1000, order.id],
      );

      final TransactionLine updatedLine = await fixture.service
          .editBreakfastLine(
            transactionLineId: line.id,
            edit: BreakfastLineEdit.chooseGroup(
              groupId: fixture.hotDrinkGroupId,
              selectedItemProductId: fixture.teaProductId,
              quantity: 1,
            ),
          );

      expect(updatedLine.pricingMode, TransactionLinePricingMode.set);
      final List<OrderModifier> modifiers = await fixture.service
          .getLineModifiers(line.id);
      expect(
        modifiers.where(
          (OrderModifier modifier) =>
              modifier.chargeReason == ModifierChargeReason.includedChoice,
        ),
        hasLength(1),
      );
    });

    test('no_partial_state_after_failed_edit', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final Transaction order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final TransactionLine line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
      );

      await expectLater(
        fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.setRemovedQuantity(
            itemProductId: fixture.eggProductId,
            quantity: 2,
          ),
        ),
        throwsA(isA<BreakfastEditRejectedException>()),
      );

      final List<OrderModifier> modifiers = await fixture.service
          .getLineModifiers(line.id);
      final TransactionLine refreshedLine =
          (await fixture.service.getOrderLines(order.id)).single;
      final Transaction refreshedOrder = (await fixture.service.getOrderById(
        order.id,
      ))!;
      expect(modifiers, isEmpty);
      expect(refreshedLine.lineTotalMinor, 400);
      expect(refreshedOrder.modifierTotalMinor, 0);
      expect(refreshedOrder.totalAmountMinor, 400);
    });
  });
}

Future<_BreakfastFixture> _seedBreakfastFixture(
  app_db.AppDatabase db, {
  TransactionRepository? transactionRepository,
  BreakfastRebuildEngine breakfastRebuildEngine =
      const BreakfastRebuildEngine(),
}) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: cashierId);

  final int breakfastCategoryId = await insertCategory(
    db,
    name: 'Set Breakfast',
  );
  final int hotDrinkCategoryId = await insertCategory(db, name: 'Hot Drink');
  final int extrasCategoryId = await insertCategory(
    db,
    name: 'Breakfast Extras',
  );

  final int set4ProductId = await insertProduct(
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
  final int baconProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Bacon',
    priceMinor: 150,
  );
  final int sausageProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Sausage',
    priceMinor: 180,
  );
  final int chipsProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Chips',
    priceMinor: 110,
  );
  final int beansProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Beans',
    priceMinor: 80,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: hotDrinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int coffeeProductId = await insertProduct(
    db,
    categoryId: hotDrinkCategoryId,
    name: 'Coffee',
    priceMinor: 160,
  );
  final int toastProductId = await insertProduct(
    db,
    categoryId: extrasCategoryId,
    name: 'Toast',
    priceMinor: 100,
  );
  final int breadProductId = await insertProduct(
    db,
    categoryId: extrasCategoryId,
    name: 'Bread',
    priceMinor: 90,
  );

  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: set4ProductId,
          itemProductId: eggProductId,
          sortOrder: const Value<int>(1),
        ),
      );
  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: set4ProductId,
          itemProductId: baconProductId,
          sortOrder: const Value<int>(2),
        ),
      );
  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: set4ProductId,
          itemProductId: sausageProductId,
          sortOrder: const Value<int>(3),
        ),
      );
  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: set4ProductId,
          itemProductId: chipsProductId,
          sortOrder: const Value<int>(4),
        ),
      );
  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: set4ProductId,
          itemProductId: beansProductId,
          sortOrder: const Value<int>(5),
        ),
      );

  final int hotDrinkGroupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: set4ProductId,
          name: 'Tea or Coffee',
          minSelect: const Value<int>(0),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );
  final int toastBreadGroupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: set4ProductId,
          name: 'Toast or Bread',
          minSelect: const Value<int>(0),
          maxSelect: const Value<int>(2),
          includedQuantity: const Value<int>(2),
          sortOrder: const Value<int>(2),
        ),
      );

  Future<void> insertChoiceMember({
    required int groupId,
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          app_db.ProductModifiersCompanion.insert(
            productId: set4ProductId,
            groupId: Value<int?>(groupId),
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'choice',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertChoiceMember(
    groupId: hotDrinkGroupId,
    itemProductId: teaProductId,
    label: 'Tea',
  );
  await insertChoiceMember(
    groupId: hotDrinkGroupId,
    itemProductId: coffeeProductId,
    label: 'Coffee',
  );
  await insertChoiceMember(
    groupId: toastBreadGroupId,
    itemProductId: toastProductId,
    label: 'Toast',
  );
  await insertChoiceMember(
    groupId: toastBreadGroupId,
    itemProductId: breadProductId,
    label: 'Bread',
  );

  Future<void> insertExtra({
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          app_db.ProductModifiersCompanion.insert(
            productId: set4ProductId,
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'extra',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertExtra(itemProductId: baconProductId, label: 'Bacon');
  await insertExtra(itemProductId: sausageProductId, label: 'Sausage');
  await insertExtra(itemProductId: beansProductId, label: 'Beans');

  final TransactionRepository repository =
      transactionRepository ?? TransactionRepository(db);
  final OrderService service = OrderService(
    shiftSessionService: ShiftSessionService(ShiftRepository(db)),
    transactionRepository: repository,
    transactionStateRepository: TransactionStateRepository(db),
    breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
    breakfastRebuildEngine: breakfastRebuildEngine,
  );

  return _BreakfastFixture(
    service: service,
    cashier: User(
      id: cashierId,
      name: 'Cashier',
      pin: null,
      password: null,
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime.now(),
    ),
    set4ProductId: set4ProductId,
    eggProductId: eggProductId,
    beansProductId: beansProductId,
    teaProductId: teaProductId,
    toastProductId: toastProductId,
    hotDrinkGroupId: hotDrinkGroupId,
    toastBreadGroupId: toastBreadGroupId,
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

class _BreakfastFixture {
  const _BreakfastFixture({
    required this.service,
    required this.cashier,
    required this.set4ProductId,
    required this.eggProductId,
    required this.beansProductId,
    required this.teaProductId,
    required this.toastProductId,
    required this.hotDrinkGroupId,
    required this.toastBreadGroupId,
  });

  final OrderService service;
  final User cashier;
  final int set4ProductId;
  final int eggProductId;
  final int beansProductId;
  final int teaProductId;
  final int toastProductId;
  final int hotDrinkGroupId;
  final int toastBreadGroupId;
}

class _ObservingTransactionRepository extends TransactionRepository {
  _ObservingTransactionRepository(super.db);

  int replaceBreakfastLineSnapshotCalls = 0;
  final List<int> replacedTransactionLineIds = <int>[];

  @override
  Future<void> replaceBreakfastLineSnapshot({
    required int transactionLineId,
    required BreakfastRebuildResult rebuildResult,
    List<BreakfastCookingInstructionRecord> cookingInstructions =
        const <BreakfastCookingInstructionRecord>[],
  }) async {
    replaceBreakfastLineSnapshotCalls += 1;
    replacedTransactionLineIds.add(transactionLineId);
    await super.replaceBreakfastLineSnapshot(
      transactionLineId: transactionLineId,
      rebuildResult: rebuildResult,
      cookingInstructions: cookingInstructions,
    );
  }
}

class _CapturingBreakfastRebuildEngine extends BreakfastRebuildEngine {
  BreakfastRebuildInput? lastInput;

  @override
  BreakfastRebuildResult rebuild(BreakfastRebuildInput input) {
    lastInput = input;
    return super.rebuild(input);
  }
}

class _RejectingBreakfastRebuildEngine extends BreakfastRebuildEngine {
  const _RejectingBreakfastRebuildEngine({required this.rejectionCode});

  final BreakfastEditErrorCode rejectionCode;

  @override
  BreakfastRebuildResult rebuild(BreakfastRebuildInput input) {
    final int basePriceMinor =
        input.transactionLine.baseUnitPriceMinor *
        input.transactionLine.lineQuantity;
    return BreakfastRebuildResult(
      lineSnapshot: BreakfastLineSnapshot(
        pricingMode: TransactionLinePricingMode.set,
        baseUnitPriceMinor: input.transactionLine.baseUnitPriceMinor,
        removalDiscountTotalMinor: 0,
        modifierTotalMinor: 0,
        lineTotalMinor: basePriceMinor,
      ),
      classifiedModifiers: const <BreakfastClassifiedModifier>[],
      pricingBreakdown: BreakfastPricingBreakdown(
        basePriceMinor: basePriceMinor,
        extraAddTotalMinor: 0,
        paidSwapTotalMinor: 0,
        freeSwapTotalMinor: 0,
        includedChoiceTotalMinor: 0,
        removeTotalMinor: 0,
        removalDiscountTotalMinor: 0,
        finalLineTotalMinor: basePriceMinor,
      ),
      validationErrors: <BreakfastEditErrorCode>[rejectionCode],
      rebuildMetadata: const BreakfastRebuildMetadata(
        replacementCount: 0,
        unmatchedRemovalCount: 0,
      ),
    );
  }
}
