import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/data/repositories/transaction_state_repository.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
import 'package:epos_app/domain/models/breakfast_cooking_instruction.dart';
import 'package:epos_app/domain/models/checkout_item.dart';
import 'package:epos_app/domain/models/checkout_modifier.dart';
import 'package:epos_app/domain/models/breakfast_line_edit.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/domain/models/transaction_line.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/breakfast_pos_service.dart';
import 'package:epos_app/domain/services/checkout_service.dart';
import 'package:epos_app/domain/services/order_service.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/domain/services/shift_session_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  test(
    'checkout persists semantic bundle selections through the semantic snapshot path',
    () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _CheckoutSemanticFixture fixture = await _seedCheckoutFixture(db);

      final BreakfastPosService posService = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      final selection = await posService.buildCartSelection(
        product: fixture.rootProduct,
        requestedState: BreakfastLineEdit.chooseGroup(
          groupId: fixture.drinkGroupId,
          selectedItemProductId: fixture.teaProductId,
          quantity: 1,
        ).applyTo(const BreakfastRequestedState()),
      );

      final OrderService orderService = OrderService(
        shiftSessionService: ShiftSessionService(fixture.shiftRepository),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      final CheckoutService checkoutService = CheckoutService(
        shiftSessionService: ShiftSessionService(fixture.shiftRepository),
        orderService: orderService,
        printerService: PrinterService(TransactionRepository(db)),
      );

      final transaction = await checkoutService.checkoutCart(
        currentUser: fixture.cashier,
        cartItems: <CheckoutItem>[
          CheckoutItem(
            productId: fixture.rootProduct.id,
            quantity: 1,
            modifiers: const <CheckoutModifier>[],
            breakfastSelection: selection,
          ),
        ],
        idempotencyKey: 'semantic-checkout-test',
        immediatePaymentMethod: null,
      );

      final List<TransactionLine> lines = await orderService.getOrderLines(
        transaction.id,
      );
      expect(lines, hasLength(1));
      expect(lines.single.pricingMode, TransactionLinePricingMode.set);
      expect(
        lines.single.lineTotalMinor,
        selection.rebuildResult.lineSnapshot.lineTotalMinor,
      );

      final List<OrderModifier> modifiers = await orderService.getLineModifiers(
        lines.single.id,
      );
      expect(
        modifiers,
        hasLength(selection.rebuildResult.classifiedModifiers.length),
      );
      expect(
        modifiers
            .singleWhere(
              (OrderModifier modifier) =>
                  modifier.action == ModifierAction.choice &&
                  modifier.itemProductId == fixture.teaProductId,
            )
            .chargeReason,
        ModifierChargeReason.includedChoice,
      );
      expect(
        transaction.modifierTotalMinor,
        selection.rebuildResult.lineSnapshot.modifierTotalMinor,
      );
    },
  );

  test(
    'checkout keeps swap classification when a pooled extra replaces a removed item',
    () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _CheckoutSemanticFixture fixture = await _seedCheckoutFixture(db);

      final BreakfastPosService posService = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      final BreakfastRequestedState requestedState =
          BreakfastLineEdit.setAddedQuantity(
            itemProductId: fixture.hashBrownProductId,
            quantity: 1,
          ).applyTo(
            BreakfastLineEdit.setRemovedQuantity(
              itemProductId: fixture.beansProductId,
              quantity: 1,
            ).applyTo(
              BreakfastLineEdit.chooseGroup(
                groupId: fixture.drinkGroupId,
                selectedItemProductId: fixture.teaProductId,
                quantity: 1,
              ).applyTo(const BreakfastRequestedState()),
            ),
          );
      final selection = await posService.buildCartSelection(
        product: fixture.rootProduct,
        requestedState: requestedState,
      );

      expect(
        selection.rebuildResult.classifiedModifiers.any(
          (BreakfastClassifiedModifier modifier) =>
              modifier.chargeReason == ModifierChargeReason.freeSwap &&
              modifier.itemProductId == fixture.hashBrownProductId,
        ),
        isTrue,
      );

      final OrderService orderService = OrderService(
        shiftSessionService: ShiftSessionService(fixture.shiftRepository),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      final CheckoutService checkoutService = CheckoutService(
        shiftSessionService: ShiftSessionService(fixture.shiftRepository),
        orderService: orderService,
        printerService: PrinterService(TransactionRepository(db)),
      );

      final transaction = await checkoutService.checkoutCart(
        currentUser: fixture.cashier,
        cartItems: <CheckoutItem>[
          CheckoutItem(
            productId: fixture.rootProduct.id,
            quantity: 1,
            modifiers: const <CheckoutModifier>[],
            breakfastSelection: selection,
          ),
        ],
        idempotencyKey: 'semantic-checkout-swap-test',
        immediatePaymentMethod: null,
      );

      final List<TransactionLine> lines = await orderService.getOrderLines(
        transaction.id,
      );
      final List<OrderModifier> modifiers = await orderService.getLineModifiers(
        lines.single.id,
      );

      expect(
        modifiers.any(
          (OrderModifier modifier) =>
              modifier.chargeReason == ModifierChargeReason.freeSwap &&
              modifier.itemProductId == fixture.hashBrownProductId,
        ),
        isTrue,
      );
    },
  );

  test(
    'checkout persists explicit none choices without pricing impact',
    () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _CheckoutSemanticFixture fixture = await _seedCheckoutFixture(db);

      final BreakfastPosService posService = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      final selection = await posService.buildCartSelection(
        product: fixture.rootProduct,
        requestedState: BreakfastLineEdit.chooseGroup(
          groupId: fixture.drinkGroupId,
          selectedItemProductId: null,
          quantity: 1,
        ).applyTo(const BreakfastRequestedState()),
      );

      final OrderService orderService = OrderService(
        shiftSessionService: ShiftSessionService(fixture.shiftRepository),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      final CheckoutService checkoutService = CheckoutService(
        shiftSessionService: ShiftSessionService(fixture.shiftRepository),
        orderService: orderService,
        printerService: PrinterService(TransactionRepository(db)),
      );

      final transaction = await checkoutService.checkoutCart(
        currentUser: fixture.cashier,
        cartItems: <CheckoutItem>[
          CheckoutItem(
            productId: fixture.rootProduct.id,
            quantity: 1,
            modifiers: const <CheckoutModifier>[],
            breakfastSelection: selection,
          ),
        ],
        idempotencyKey: 'semantic-checkout-none-test',
        immediatePaymentMethod: null,
      );

      final List<TransactionLine> lines = await orderService.getOrderLines(
        transaction.id,
      );
      final List<OrderModifier> modifiers = await orderService.getLineModifiers(
        lines.single.id,
      );

      expect(lines.single.lineTotalMinor, fixture.rootProduct.priceMinor);
      expect(modifiers, hasLength(1));
      expect(modifiers.single.itemProductId, isNull);
      expect(
        modifiers.single.chargeReason,
        ModifierChargeReason.includedChoice,
      );
      expect(modifiers.single.sourceGroupId, fixture.drinkGroupId);
      expect(transaction.modifierTotalMinor, 0);
    },
  );

  test(
    'checkout persists structured cooking instructions without changing pricing',
    () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _CheckoutSemanticFixture fixture = await _seedCheckoutFixture(db);

      final BreakfastPosService posService = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      final selection = await posService.buildCartSelection(
        product: fixture.rootProduct,
        requestedState:
            BreakfastLineEdit.setCookingInstruction(
              itemProductId: fixture.eggProductId,
              instructionCode: 'runny',
              instructionLabel: 'Runny',
            ).applyTo(
              BreakfastLineEdit.chooseGroup(
                groupId: fixture.drinkGroupId,
                selectedItemProductId: fixture.teaProductId,
                quantity: 1,
              ).applyTo(const BreakfastRequestedState()),
            ),
      );

      final OrderService orderService = OrderService(
        shiftSessionService: ShiftSessionService(fixture.shiftRepository),
        transactionRepository: TransactionRepository(db),
        transactionStateRepository: TransactionStateRepository(db),
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      final CheckoutService checkoutService = CheckoutService(
        shiftSessionService: ShiftSessionService(fixture.shiftRepository),
        orderService: orderService,
        printerService: PrinterService(TransactionRepository(db)),
      );

      final transaction = await checkoutService.checkoutCart(
        currentUser: fixture.cashier,
        cartItems: <CheckoutItem>[
          CheckoutItem(
            productId: fixture.rootProduct.id,
            quantity: 1,
            modifiers: const <CheckoutModifier>[],
            breakfastSelection: selection,
          ),
        ],
        idempotencyKey: 'semantic-checkout-cooking-test',
        immediatePaymentMethod: null,
      );

      final List<TransactionLine> lines = await orderService.getOrderLines(
        transaction.id,
      );
      final List<BreakfastCookingInstructionRecord> instructions =
          await orderService.getLineCookingInstructions(lines.single.id);

      expect(
        lines.single.lineTotalMinor,
        selection.rebuildResult.lineSnapshot.lineTotalMinor,
      );
      expect(
        transaction.modifierTotalMinor,
        selection.rebuildResult.lineSnapshot.modifierTotalMinor,
      );
      expect(instructions, hasLength(1));
      expect(instructions.single.itemProductId, fixture.eggProductId);
      expect(instructions.single.instructionCode, 'runny');
      expect(instructions.single.kitchenLabel, 'Egg x1 - RUNNY');
    },
  );
}

Future<_CheckoutSemanticFixture> _seedCheckoutFixture(
  app_db.AppDatabase db,
) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: cashierId);

  final int breakfastCategoryId = await insertCategory(
    db,
    name: 'Set Breakfast',
  );
  final int drinkCategoryId = await insertCategory(db, name: 'Drinks');

  final int rootProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set Breakfast',
    priceMinor: 600,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Egg',
    priceMinor: 120,
  );
  final int beansProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Beans',
    priceMinor: 80,
  );
  final int hashBrownProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Hash Brown',
    priceMinor: 130,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int coffeeProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Coffee',
    priceMinor: 170,
  );

  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: eggProductId,
          sortOrder: const Value<int>(1),
          isRemovable: const Value<bool>(false),
        ),
      );
  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: beansProductId,
          sortOrder: const Value<int>(2),
          isRemovable: const Value<bool>(true),
        ),
      );

  final int drinkGroupId = await db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: rootProductId,
          name: 'Drink choice',
          minSelect: const Value<int>(1),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );

  Future<void> insertChoiceMember({
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          app_db.ProductModifiersCompanion.insert(
            productId: rootProductId,
            groupId: Value<int?>(drinkGroupId),
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'choice',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertChoiceMember(itemProductId: teaProductId, label: 'Tea');
  await insertChoiceMember(itemProductId: coffeeProductId, label: 'Coffee');
  await db
      .into(db.productModifiers)
      .insert(
        app_db.ProductModifiersCompanion.insert(
          productId: rootProductId,
          itemProductId: Value<int?>(hashBrownProductId),
          name: 'Hash Brown',
          type: 'extra',
          extraPriceMinor: const Value<int>(0),
        ),
      );

  return _CheckoutSemanticFixture(
    shiftRepository: ShiftRepository(db),
    cashier: User(
      id: cashierId,
      name: 'Cashier',
      pin: null,
      password: null,
      role: UserRole.cashier,
      isActive: true,
      createdAt: DateTime.now(),
    ),
    rootProduct: Product(
      id: rootProductId,
      categoryId: breakfastCategoryId,
      name: 'Set Breakfast',
      priceMinor: 600,
      imageUrl: null,
      hasModifiers: false,
      isActive: true,
      isVisibleOnPos: true,
      sortOrder: 0,
    ),
    eggProductId: eggProductId,
    beansProductId: beansProductId,
    hashBrownProductId: hashBrownProductId,
    teaProductId: teaProductId,
    drinkGroupId: drinkGroupId,
  );
}

class _CheckoutSemanticFixture {
  const _CheckoutSemanticFixture({
    required this.shiftRepository,
    required this.cashier,
    required this.rootProduct,
    required this.eggProductId,
    required this.beansProductId,
    required this.hashBrownProductId,
    required this.teaProductId,
    required this.drinkGroupId,
  });

  final ShiftRepository shiftRepository;
  final User cashier;
  final Product rootProduct;
  final int eggProductId;
  final int beansProductId;
  final int hashBrownProductId;
  final int teaProductId;
  final int drinkGroupId;
}
