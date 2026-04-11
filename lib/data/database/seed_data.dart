import 'package:drift/drift.dart';

import '../../domain/services/auth_security.dart';
import 'app_database.dart';

class SeedData {
  const SeedData._();

  static Future<void> insertIfEmpty(AppDatabase db) async {
    final existingUsers = await (db.select(db.users)..limit(1)).get();
    if (existingUsers.isNotEmpty) {
      return;
    }

    await db.transaction(() async {
      final int adminId = await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              name: 'Admin',
              role: 'admin',
              pin: Value<String?>(
                AuthSecurity.hashPin(AuthSecurity.demoAdminPin),
              ),
            ),
          );
      final int cashierId = await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              name: 'Cashier',
              role: 'cashier',
              pin: Value<String?>(
                AuthSecurity.hashPin(AuthSecurity.demoCashierPin),
              ),
            ),
          );

      final breakfastId = await _insertCategory(
        db,
        name: 'Kahvaltı',
        sortOrder: 0,
      );
      final drinksId = await _insertCategory(
        db,
        name: 'İçecekler',
        sortOrder: 1,
      );
      final mainsId = await _insertCategory(
        db,
        name: 'Ana Yemekler',
        sortOrder: 2,
      );
      final dessertsId = await _insertCategory(
        db,
        name: 'Tatlılar',
        sortOrder: 3,
      );

      final se5BreakfastId = await _insertProduct(
        db,
        categoryId: breakfastId,
        name: 'SE5 Breakfast',
        priceMinor: 850,
        hasModifiers: true,
        sortOrder: 0,
      );
      await _insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Toast',
        priceMinor: 350,
        hasModifiers: false,
        sortOrder: 1,
      );
      await _insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Pancakes',
        priceMinor: 600,
        hasModifiers: false,
        sortOrder: 2,
      );
      final eggsBenedictId = await _insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Eggs Benedict',
        priceMinor: 750,
        hasModifiers: true,
        sortOrder: 3,
      );

      await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'Americano',
        priceMinor: 250,
        hasModifiers: false,
        sortOrder: 0,
      );
      final latteId = await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'Latte',
        priceMinor: 300,
        hasModifiers: true,
        sortOrder: 1,
      );
      final cappuccinoId = await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'Cappuccino',
        priceMinor: 300,
        hasModifiers: true,
        sortOrder: 2,
      );
      await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'Orange Juice',
        priceMinor: 200,
        hasModifiers: false,
        sortOrder: 3,
      );
      await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'English Tea',
        priceMinor: 200,
        hasModifiers: false,
        sortOrder: 4,
      );

      final burgerId = await _insertProduct(
        db,
        categoryId: mainsId,
        name: 'Burger',
        priceMinor: 900,
        hasModifiers: true,
        sortOrder: 0,
      );
      await _insertProduct(
        db,
        categoryId: mainsId,
        name: 'Fish & Chips',
        priceMinor: 800,
        hasModifiers: false,
        sortOrder: 1,
      );
      await _insertProduct(
        db,
        categoryId: mainsId,
        name: 'Caesar Salad',
        priceMinor: 750,
        hasModifiers: false,
        sortOrder: 2,
      );
      final chickenWrapId = await _insertProduct(
        db,
        categoryId: mainsId,
        name: 'Chicken Wrap',
        priceMinor: 700,
        hasModifiers: true,
        sortOrder: 3,
      );

      await _insertProduct(
        db,
        categoryId: dessertsId,
        name: 'Cheesecake',
        priceMinor: 550,
        hasModifiers: false,
        sortOrder: 0,
      );
      await _insertProduct(
        db,
        categoryId: dessertsId,
        name: 'Brownie',
        priceMinor: 450,
        hasModifiers: false,
        sortOrder: 1,
      );
      final iceCreamId = await _insertProduct(
        db,
        categoryId: dessertsId,
        name: 'Ice Cream',
        priceMinor: 350,
        hasModifiers: true,
        sortOrder: 2,
      );

      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Chips',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Beans',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Toast',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Hash Brown',
        type: 'extra',
        extraPriceMinor: 100,
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Extra Egg',
        type: 'extra',
        extraPriceMinor: 150,
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Bacon',
        type: 'extra',
        extraPriceMinor: 150,
      );

      await _insertModifier(
        db,
        productId: eggsBenedictId,
        name: 'Hollandaise',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: eggsBenedictId,
        name: 'Smoked Salmon',
        type: 'extra',
        extraPriceMinor: 200,
      );

      await _insertModifier(
        db,
        productId: latteId,
        name: 'Oat Milk',
        type: 'extra',
        extraPriceMinor: 50,
      );
      await _insertModifier(
        db,
        productId: latteId,
        name: 'Extra Shot',
        type: 'extra',
        extraPriceMinor: 60,
      );
      await _insertModifier(
        db,
        productId: latteId,
        name: 'Vanilla Syrup',
        type: 'extra',
        extraPriceMinor: 50,
      );

      await _insertModifier(
        db,
        productId: cappuccinoId,
        name: 'Oat Milk',
        type: 'extra',
        extraPriceMinor: 50,
      );
      await _insertModifier(
        db,
        productId: cappuccinoId,
        name: 'Extra Shot',
        type: 'extra',
        extraPriceMinor: 60,
      );

      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Fried onion',
        type: 'extra',
        priceBehavior: 'free',
        uiSection: 'toppings',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Salad',
        type: 'extra',
        priceBehavior: 'free',
        uiSection: 'toppings',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Ketchup',
        type: 'extra',
        priceBehavior: 'free',
        uiSection: 'sauces',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Brown sauce',
        type: 'extra',
        priceBehavior: 'free',
        uiSection: 'sauces',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Burger sauce',
        type: 'extra',
        priceBehavior: 'free',
        uiSection: 'sauces',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Mayonnaise',
        type: 'extra',
        priceBehavior: 'free',
        uiSection: 'sauces',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Chips',
        type: 'extra',
        extraPriceMinor: 110,
        priceBehavior: 'paid',
        uiSection: 'add_ins',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Beans',
        type: 'extra',
        extraPriceMinor: 80,
        priceBehavior: 'paid',
        uiSection: 'add_ins',
      );

      await _insertModifier(
        db,
        productId: chickenWrapId,
        name: 'Lettuce',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: chickenWrapId,
        name: 'Sauce',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: chickenWrapId,
        name: 'Cheese',
        type: 'extra',
        extraPriceMinor: 100,
      );
      await _insertModifier(
        db,
        productId: chickenWrapId,
        name: 'Avocado',
        type: 'extra',
        extraPriceMinor: 150,
      );

      await _insertModifier(
        db,
        productId: iceCreamId,
        name: 'Chocolate Sauce',
        type: 'extra',
        extraPriceMinor: 50,
      );
      await _insertModifier(
        db,
        productId: iceCreamId,
        name: 'Whipped Cream',
        type: 'extra',
        extraPriceMinor: 50,
      );
      await _insertModifier(
        db,
        productId: iceCreamId,
        name: 'Sprinkles',
        type: 'extra',
        extraPriceMinor: 30,
      );

      await db
          .into(db.reportSettings)
          .insert(
            ReportSettingsCompanion.insert(
              visibilityRatio: const Value<double>(1.0),
            ),
          );

      final DateTime now = DateTime.now();
      final int historicalShiftId = await _insertShift(
        db,
        openedBy: adminId,
        openedAt: now.subtract(const Duration(days: 1, hours: 6)),
        status: 'closed',
        closedBy: adminId,
        closedAt: now.subtract(const Duration(days: 1)),
      );
      final int activeShiftId = await _insertShift(
        db,
        openedBy: cashierId,
        openedAt: now.subtract(const Duration(hours: 4)),
      );

      final int draftOrderId = await _insertTransaction(
        db,
        uuid: 'seed-draft-order',
        shiftId: activeShiftId,
        userId: cashierId,
        status: 'draft',
        tableNumber: 2,
        createdAt: now.subtract(const Duration(hours: 3, minutes: 30)),
      );
      final int draftLineId = await _insertTransactionLine(
        db,
        transactionId: draftOrderId,
        productId: latteId,
        productName: 'Latte',
        unitPriceMinor: 300,
        quantity: 1,
        lineTotalMinor: 350,
      );
      await _insertOrderModifier(
        db,
        transactionLineId: draftLineId,
        itemName: 'Oat Milk',
        action: 'add',
        extraPriceMinor: 50,
      );
      await _updateTransactionTotals(
        db,
        transactionId: draftOrderId,
        subtotalMinor: 300,
        modifierTotalMinor: 50,
      );

      final int sentOrderId = await _insertTransaction(
        db,
        uuid: 'seed-sent-order',
        shiftId: activeShiftId,
        userId: cashierId,
        status: 'sent',
        tableNumber: 4,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 40)),
      );
      final int sentLineId = await _insertTransactionLine(
        db,
        transactionId: sentOrderId,
        productId: burgerId,
        productName: 'Burger',
        unitPriceMinor: 900,
        quantity: 1,
        lineTotalMinor: 1000,
      );
      await _insertOrderModifier(
        db,
        transactionLineId: sentLineId,
        itemName: 'Cheese',
        action: 'add',
        extraPriceMinor: 100,
      );
      await _updateTransactionTotals(
        db,
        transactionId: sentOrderId,
        subtotalMinor: 900,
        modifierTotalMinor: 100,
      );

      final int paidCashOrderId = await _insertTransaction(
        db,
        uuid: 'seed-paid-cash-order',
        shiftId: activeShiftId,
        userId: cashierId,
        status: 'paid',
        tableNumber: 1,
        createdAt: now.subtract(const Duration(hours: 2)),
        paidAt: now.subtract(const Duration(hours: 1, minutes: 45)),
      );
      final int paidCashLineId = await _insertTransactionLine(
        db,
        transactionId: paidCashOrderId,
        productId: se5BreakfastId,
        productName: 'SE5 Breakfast',
        unitPriceMinor: 850,
        quantity: 1,
        lineTotalMinor: 1000,
      );
      await _insertOrderModifier(
        db,
        transactionLineId: paidCashLineId,
        itemName: 'Extra Egg',
        action: 'add',
        extraPriceMinor: 150,
      );
      await _updateTransactionTotals(
        db,
        transactionId: paidCashOrderId,
        subtotalMinor: 850,
        modifierTotalMinor: 150,
      );
      await _insertPayment(
        db,
        uuid: 'seed-paid-cash-payment',
        transactionId: paidCashOrderId,
        method: 'cash',
        amountMinor: 1000,
        paidAt: now.subtract(const Duration(hours: 1, minutes: 45)),
      );

      final int paidCardOrderId = await _insertTransaction(
        db,
        uuid: 'seed-paid-card-order',
        shiftId: activeShiftId,
        userId: cashierId,
        status: 'paid',
        tableNumber: 6,
        createdAt: now.subtract(const Duration(hours: 1, minutes: 20)),
        paidAt: now.subtract(const Duration(hours: 1)),
      );
      final int paidCardLineId = await _insertTransactionLine(
        db,
        transactionId: paidCardOrderId,
        productId: chickenWrapId,
        productName: 'Chicken Wrap',
        unitPriceMinor: 700,
        quantity: 1,
        lineTotalMinor: 850,
      );
      await _insertOrderModifier(
        db,
        transactionLineId: paidCardLineId,
        itemName: 'Avocado',
        action: 'add',
        extraPriceMinor: 150,
      );
      await _updateTransactionTotals(
        db,
        transactionId: paidCardOrderId,
        subtotalMinor: 700,
        modifierTotalMinor: 150,
      );
      await _insertPayment(
        db,
        uuid: 'seed-paid-card-payment',
        transactionId: paidCardOrderId,
        method: 'card',
        amountMinor: 850,
        paidAt: now.subtract(const Duration(hours: 1)),
      );

      final int cancelledOrderId = await _insertTransaction(
        db,
        uuid: 'seed-cancelled-order',
        shiftId: activeShiftId,
        userId: cashierId,
        status: 'cancelled',
        tableNumber: 3,
        createdAt: now.subtract(const Duration(minutes: 50)),
        cancelledAt: now.subtract(const Duration(minutes: 35)),
        cancelledBy: cashierId,
      );
      final int cancelledLineId = await _insertTransactionLine(
        db,
        transactionId: cancelledOrderId,
        productId: iceCreamId,
        productName: 'Ice Cream',
        unitPriceMinor: 350,
        quantity: 1,
        lineTotalMinor: 400,
      );
      await _insertOrderModifier(
        db,
        transactionLineId: cancelledLineId,
        itemName: 'Chocolate Sauce',
        action: 'add',
        extraPriceMinor: 50,
      );
      await _updateTransactionTotals(
        db,
        transactionId: cancelledOrderId,
        subtotalMinor: 350,
        modifierTotalMinor: 50,
      );

      final int historyPaidOrderId = await _insertTransaction(
        db,
        uuid: 'seed-history-paid-order',
        shiftId: historicalShiftId,
        userId: adminId,
        status: 'paid',
        tableNumber: 8,
        createdAt: now.subtract(const Duration(days: 1, hours: 4)),
        paidAt: now.subtract(const Duration(days: 1, hours: 3, minutes: 40)),
      );
      await _insertTransactionLine(
        db,
        transactionId: historyPaidOrderId,
        productId: eggsBenedictId,
        productName: 'Eggs Benedict',
        unitPriceMinor: 750,
        quantity: 1,
        lineTotalMinor: 950,
      );
      await _updateTransactionTotals(
        db,
        transactionId: historyPaidOrderId,
        subtotalMinor: 750,
        modifierTotalMinor: 200,
      );
      await _insertPayment(
        db,
        uuid: 'seed-history-card-payment',
        transactionId: historyPaidOrderId,
        method: 'card',
        amountMinor: 950,
        paidAt: now.subtract(const Duration(days: 1, hours: 3, minutes: 40)),
      );
    });
  }

  static Future<int> _insertCategory(
    AppDatabase db, {
    required String name,
    required int sortOrder,
  }) {
    return db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            name: name,
            sortOrder: Value<int>(sortOrder),
          ),
        );
  }

  static Future<int> _insertProduct(
    AppDatabase db, {
    required int categoryId,
    required String name,
    required int priceMinor,
    required bool hasModifiers,
    required int sortOrder,
  }) {
    return db
        .into(db.products)
        .insert(
          ProductsCompanion.insert(
            categoryId: categoryId,
            name: name,
            priceMinor: priceMinor,
            hasModifiers: Value<bool>(hasModifiers),
            sortOrder: Value<int>(sortOrder),
          ),
        );
  }

  static Future<int> _insertModifier(
    AppDatabase db, {
    required int productId,
    required String name,
    required String type,
    int extraPriceMinor = 0,
    String? priceBehavior,
    String? uiSection,
  }) {
    return db
        .into(db.productModifiers)
        .insert(
          ProductModifiersCompanion.insert(
            productId: productId,
            name: name,
            type: type,
            extraPriceMinor: Value<int>(extraPriceMinor),
            priceBehavior: Value<String?>(priceBehavior),
            uiSection: Value<String?>(uiSection),
          ),
        );
  }

  static Future<int> _insertShift(
    AppDatabase db, {
    required int openedBy,
    required DateTime openedAt,
    String status = 'open',
    int? closedBy,
    DateTime? closedAt,
  }) {
    return db
        .into(db.shifts)
        .insert(
          ShiftsCompanion.insert(
            openedBy: openedBy,
            openedAt: Value<DateTime>(openedAt),
            status: Value<String>(status),
            closedBy: Value<int?>(closedBy),
            closedAt: Value<DateTime?>(closedAt),
          ),
        );
  }

  static Future<int> _insertTransaction(
    AppDatabase db, {
    required String uuid,
    required int shiftId,
    required int userId,
    required String status,
    int? tableNumber,
    required DateTime createdAt,
    DateTime? paidAt,
    DateTime? cancelledAt,
    int? cancelledBy,
  }) {
    return db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            uuid: uuid,
            shiftId: shiftId,
            userId: userId,
            tableNumber: Value<int?>(tableNumber),
            status: Value<String>(status),
            createdAt: Value<DateTime>(createdAt),
            paidAt: Value<DateTime?>(paidAt),
            updatedAt: paidAt ?? cancelledAt ?? createdAt,
            cancelledAt: Value<DateTime?>(cancelledAt),
            cancelledBy: Value<int?>(cancelledBy),
            idempotencyKey: '$uuid-idem',
          ),
        );
  }

  static Future<int> _insertTransactionLine(
    AppDatabase db, {
    required int transactionId,
    required int productId,
    required String productName,
    required int unitPriceMinor,
    required int quantity,
    required int lineTotalMinor,
  }) {
    return db
        .into(db.transactionLines)
        .insert(
          TransactionLinesCompanion.insert(
            uuid: 'line-$transactionId-$productId-$quantity',
            transactionId: transactionId,
            productId: productId,
            productName: productName,
            unitPriceMinor: unitPriceMinor,
            quantity: Value<int>(quantity),
            lineTotalMinor: lineTotalMinor,
          ),
        );
  }

  static Future<int> _insertOrderModifier(
    AppDatabase db, {
    required int transactionLineId,
    required String itemName,
    required String action,
    required int extraPriceMinor,
  }) {
    return db
        .into(db.orderModifiers)
        .insert(
          OrderModifiersCompanion.insert(
            uuid: 'modifier-$transactionLineId-$itemName',
            transactionLineId: transactionLineId,
            action: action,
            itemName: itemName,
            extraPriceMinor: Value<int>(extraPriceMinor),
          ),
        );
  }

  static Future<void> _updateTransactionTotals(
    AppDatabase db, {
    required int transactionId,
    required int subtotalMinor,
    required int modifierTotalMinor,
  }) async {
    await (db.update(
      db.transactions,
    )..where((t) => t.id.equals(transactionId))).write(
      TransactionsCompanion(
        subtotalMinor: Value<int>(subtotalMinor),
        modifierTotalMinor: Value<int>(modifierTotalMinor),
        totalAmountMinor: Value<int>(subtotalMinor + modifierTotalMinor),
      ),
    );
  }

  static Future<int> _insertPayment(
    AppDatabase db, {
    required String uuid,
    required int transactionId,
    required String method,
    required int amountMinor,
    required DateTime paidAt,
  }) {
    return db
        .into(db.payments)
        .insert(
          PaymentsCompanion.insert(
            uuid: uuid,
            transactionId: transactionId,
            method: method,
            amountMinor: amountMinor,
            paidAt: Value<DateTime>(paidAt),
          ),
        );
  }
}
