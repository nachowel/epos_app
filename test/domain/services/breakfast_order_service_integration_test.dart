import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/breakfast_line_edit.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Breakfast runtime integration', () {
    test(
      'choice overflow persists semantic rows and recalculates totals',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

        final order = await fixture.service.createOrder(
          currentUser: fixture.cashier,
        );
        final line = await fixture.service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.set4ProductId,
        );

        final updatedLine = await fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.chooseGroup(
            groupId: fixture.toastBreadGroupId,
            selectedItemProductId: fixture.toastProductId,
            quantity: 4,
          ),
        );

        final modifiers = await fixture.service.getLineModifiers(
          updatedLine.id,
        );
        expect(modifiers, hasLength(2));

        final OrderModifier includedChoice = modifiers.firstWhere(
          (OrderModifier modifier) =>
              modifier.action == ModifierAction.choice &&
              modifier.chargeReason == ModifierChargeReason.includedChoice,
        );
        final OrderModifier overflow = modifiers.firstWhere(
          (OrderModifier modifier) =>
              modifier.action == ModifierAction.add &&
              modifier.chargeReason == ModifierChargeReason.extraAdd,
        );

        expect(includedChoice.itemProductId, fixture.toastProductId);
        expect(includedChoice.quantity, 2);
        expect(includedChoice.unitPriceMinor, 100);
        expect(includedChoice.priceEffectMinor, 0);

        expect(overflow.itemProductId, fixture.toastProductId);
        expect(overflow.quantity, 2);
        expect(overflow.unitPriceMinor, 100);
        expect(overflow.priceEffectMinor, 200);
        expect(overflow.extraPriceMinor, 200);

        final refreshedOrder = await fixture.service.getOrderById(order.id);
        expect(updatedLine.lineTotalMinor, 600);
        expect(refreshedOrder!.modifierTotalMinor, 200);
        expect(refreshedOrder.totalAmountMinor, 600);
      },
    );

    test(
      'rebuild clears prior classified rows instead of patching incrementally',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

        final order = await fixture.service.createOrder(
          currentUser: fixture.cashier,
        );
        final line = await fixture.service.addProductToOrder(
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
        final TransactionLine afterClear = await fixture.service
            .editBreakfastLine(
              transactionLineId: line.id,
              edit: BreakfastLineEdit.clearGroup(
                groupId: fixture.toastBreadGroupId,
              ),
            );

        final modifiers = await fixture.service.getLineModifiers(afterClear.id);
        final refreshedOrder = await fixture.service.getOrderById(order.id);
        expect(modifiers, isEmpty);
        expect(afterClear.lineTotalMinor, 400);
        expect(refreshedOrder!.modifierTotalMinor, 0);
        expect(refreshedOrder.totalAmountMinor, 400);
      },
    );

    test(
      'explicit none choice survives round-trip persistence for later edits',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

        final order = await fixture.service.createOrder(
          currentUser: fixture.cashier,
        );
        final line = await fixture.service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.set4ProductId,
        );

        final TransactionLine updatedLine = await fixture.service
            .editBreakfastLine(
              transactionLineId: line.id,
              edit: BreakfastLineEdit.chooseGroup(
                groupId: fixture.hotDrinkGroupId,
                selectedItemProductId: null,
                quantity: 1,
              ),
            );

        final List<OrderModifier> modifiers = await fixture.service
            .getLineModifiers(updatedLine.id);
        expect(modifiers, hasLength(1));
        expect(modifiers.single.itemProductId, isNull);
        expect(modifiers.single.sourceGroupId, fixture.hotDrinkGroupId);
        expect(
          modifiers.single.chargeReason,
          ModifierChargeReason.includedChoice,
        );
        expect(updatedLine.lineTotalMinor, 400);

        final TransactionLine afterSwitchToTea = await fixture.service
            .editBreakfastLine(
              transactionLineId: updatedLine.id,
              edit: BreakfastLineEdit.chooseGroup(
                groupId: fixture.hotDrinkGroupId,
                selectedItemProductId: fixture.teaProductId,
                quantity: 1,
              ),
            );
        final List<OrderModifier> refreshed = await fixture.service
            .getLineModifiers(afterSwitchToTea.id);
        expect(
          refreshed.any(
            (OrderModifier modifier) =>
                modifier.itemProductId == fixture.teaProductId &&
                modifier.chargeReason == ModifierChargeReason.includedChoice,
          ),
          isTrue,
        );
      },
    );

    test(
      'third replacement persists as paid_swap and totals use price_effect_minor',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

        final order = await fixture.service.createOrder(
          currentUser: fixture.cashier,
        );
        final line = await fixture.service.addProductToOrder(
          transactionId: order.id,
          productId: fixture.set4ProductId,
        );

        await fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.setRemovedQuantity(
            itemProductId: fixture.eggProductId,
            quantity: 1,
          ),
        );
        await fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.setRemovedQuantity(
            itemProductId: fixture.baconProductId,
            quantity: 1,
          ),
        );
        await fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.setRemovedQuantity(
            itemProductId: fixture.sausageProductId,
            quantity: 1,
          ),
        );
        await fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.setAddedQuantity(
            itemProductId: fixture.baconProductId,
            quantity: 1,
          ),
        );
        await fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.setAddedQuantity(
            itemProductId: fixture.sausageProductId,
            quantity: 1,
          ),
        );
        final TransactionLine updatedLine = await fixture.service
            .editBreakfastLine(
              transactionLineId: line.id,
              edit: BreakfastLineEdit.setAddedQuantity(
                itemProductId: fixture.beansProductId,
                quantity: 1,
              ),
            );

        final modifiers = await fixture.service.getLineModifiers(
          updatedLine.id,
        );
        expect(
          modifiers.where(
            (OrderModifier modifier) =>
                modifier.chargeReason == ModifierChargeReason.freeSwap,
          ),
          hasLength(2),
        );
        final OrderModifier paidSwap = modifiers.singleWhere(
          (OrderModifier modifier) =>
              modifier.chargeReason == ModifierChargeReason.paidSwap,
        );
        expect(paidSwap.itemProductId, fixture.beansProductId);
        expect(paidSwap.unitPriceMinor, 80);
        expect(paidSwap.priceEffectMinor, 80);

        await db.customStatement('''
        UPDATE order_modifiers
        SET extra_price_minor = 9999
        WHERE id = ${paidSwap.id}
      ''');
        await fixture.service.recalculateOrderTotals(order.id);

        final refreshedOrder = await fixture.service.getOrderById(order.id);
        expect(refreshedOrder!.modifierTotalMinor, 80);
        expect(refreshedOrder.totalAmountMinor, 480);
      },
    );

    test('extra outside pool is rejected during edit', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
      );

      await fixture.service.editBreakfastLine(
        transactionLineId: line.id,
        edit: BreakfastLineEdit.setRemovedQuantity(
          itemProductId: fixture.eggProductId,
          quantity: 1,
        ),
      );
      await expectLater(
        fixture.service.editBreakfastLine(
          transactionLineId: line.id,
          edit: BreakfastLineEdit.setAddedQuantity(
            itemProductId: fixture.teaProductId,
            quantity: 1,
          ),
        ),
        throwsA(
          isA<BreakfastEditRejectedException>().having(
            (BreakfastEditRejectedException error) => error.codes,
            'codes',
            contains(BreakfastEditErrorCode.swapCandidateNotSwapEligible),
          ),
        ),
      );
    });

    test('invalid edit rolls back atomically', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final line = await fixture.service.addProductToOrder(
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

      final modifiers = await fixture.service.getLineModifiers(line.id);
      final refreshedLine = await fixture.service.getOrderLines(order.id);
      final refreshedOrder = await fixture.service.getOrderById(order.id);
      expect(modifiers, isEmpty);
      expect(refreshedLine.single.lineTotalMinor, 400);
      expect(refreshedOrder!.modifierTotalMinor, 0);
      expect(refreshedOrder.totalAmountMinor, 400);
    });

    test('paid and cancelled breakfast lines are not editable', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final paidOrder = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final paidLine = await fixture.service.addProductToOrder(
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

      final cancelledOrder = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final cancelledLine = await fixture.service.addProductToOrder(
        transactionId: cancelledOrder.id,
        productId: fixture.set4ProductId,
      );
      await db.customStatement(
        "UPDATE transactions SET status = 'cancelled' WHERE id = ${cancelledOrder.id}",
      );

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

    test('different breakfast configs split into separate lines', () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastFixture fixture = await _seedBreakfastFixture(db);

      final order = await fixture.service.createOrder(
        currentUser: fixture.cashier,
      );
      final line = await fixture.service.addProductToOrder(
        transactionId: order.id,
        productId: fixture.set4ProductId,
        quantity: 2,
      );

      final TransactionLine customizedLine = await fixture.service
          .editBreakfastLine(
            transactionLineId: line.id,
            edit: BreakfastLineEdit.chooseGroup(
              groupId: fixture.hotDrinkGroupId,
              selectedItemProductId: fixture.teaProductId,
              quantity: 1,
            ),
          );

      final lines = await fixture.service.getOrderLines(order.id);
      expect(lines, hasLength(2));
      expect(customizedLine.id, isNot(line.id));
      expect(
        lines.map((TransactionLine item) => item.quantity),
        everyElement(1),
      );
    });
  });
}

Future<_BreakfastFixture> _seedBreakfastFixture(app_db.AppDatabase db) async {
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

  final service = OrderService(
    shiftSessionService: ShiftSessionService(ShiftRepository(db)),
    transactionRepository: TransactionRepository(db),
    transactionStateRepository: TransactionStateRepository(db),
    breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
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
    baconProductId: baconProductId,
    sausageProductId: sausageProductId,
    beansProductId: beansProductId,
    teaProductId: teaProductId,
    toastProductId: toastProductId,
    hotDrinkGroupId: hotDrinkGroupId,
    toastBreadGroupId: toastBreadGroupId,
  );
}

class _BreakfastFixture {
  const _BreakfastFixture({
    required this.service,
    required this.cashier,
    required this.set4ProductId,
    required this.eggProductId,
    required this.baconProductId,
    required this.sausageProductId,
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
  final int baconProductId;
  final int sausageProductId;
  final int beansProductId;
  final int teaProductId;
  final int toastProductId;
  final int hotDrinkGroupId;
  final int toastBreadGroupId;
}
