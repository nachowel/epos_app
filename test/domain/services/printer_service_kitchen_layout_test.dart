import 'package:drift/drift.dart' show Value, Variable;
import 'package:epos_app/data/database/app_database.dart' as db;
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrinterService kitchen layout', () {
    test(
      'kitchen ticket renders semantic breakfast blocks deterministically',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        final int cashierId = await insertUser(
          database,
          name: 'Cashier',
          role: 'cashier',
        );
        final int shiftId = await insertShift(database, openedBy: cashierId);
        final int categoryId = await insertCategory(
          database,
          name: 'Breakfast',
        );
        final int breakfastProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Big Breakfast',
          priceMinor: 1095,
        );
        final int drinkProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Cappuccino',
          priceMinor: 0,
        );
        final int breadProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Toast',
          priceMinor: 0,
        );
        final int baconProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Bacon',
          priceMinor: 0,
        );
        final int sausageProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Sausage',
          priceMinor: 0,
        );
        final int extraProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Hash Brown',
          priceMinor: 0,
        );
        final int transactionId = await insertTransaction(
          database,
          uuid: 'kitchen-layout-ticket',
          shiftId: shiftId,
          userId: cashierId,
          status: 'sent',
          totalAmountMinor: 1095,
        );
        await database.customUpdate(
          '''
        UPDATE transactions
        SET created_at = ?, updated_at = ?
        WHERE id = ?
        ''',
          variables: <Variable<Object>>[
            Variable<DateTime>(DateTime(2026, 4, 13, 9, 5)),
            Variable<DateTime>(DateTime(2026, 4, 13, 9, 5)),
            Variable<int>(transactionId),
          ],
          updates: {database.transactions},
        );

        final int drinkGroupId = await database
            .into(database.modifierGroups)
            .insert(
              db.ModifierGroupsCompanion.insert(
                productId: breakfastProductId,
                name: 'Drink',
              ),
            );
        final int breadGroupId = await database
            .into(database.modifierGroups)
            .insert(
              db.ModifierGroupsCompanion.insert(
                productId: breakfastProductId,
                name: 'Bread',
              ),
            );
        final int proteinGroupId = await database
            .into(database.modifierGroups)
            .insert(
              db.ModifierGroupsCompanion.insert(
                productId: breakfastProductId,
                name: 'Protein',
              ),
            );

        final int lineId = await database
            .into(database.transactionLines)
            .insert(
              db.TransactionLinesCompanion.insert(
                uuid: 'line-kitchen-layout',
                transactionId: transactionId,
                productId: breakfastProductId,
                productName: 'Big Breakfast',
                unitPriceMinor: 1095,
                quantity: const Value<int>(1),
                lineTotalMinor: 1095,
                pricingMode: const Value<String>('set'),
              ),
            );

        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'choice-drink',
                transactionLineId: lineId,
                action: 'choice',
                itemName: 'Cappuccino',
                quantity: const Value<int>(1),
                itemProductId: Value<int?>(drinkProductId),
                sourceGroupId: Value<int?>(drinkGroupId),
                chargeReason: const Value<String?>('included_choice'),
                sortKey: const Value<int>(10),
              ),
            );
        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'choice-bread',
                transactionLineId: lineId,
                action: 'choice',
                itemName: 'Toast',
                quantity: const Value<int>(1),
                itemProductId: Value<int?>(breadProductId),
                sourceGroupId: Value<int?>(breadGroupId),
                chargeReason: const Value<String?>('included_choice'),
                sortKey: const Value<int>(20),
              ),
            );
        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'remove-bacon',
                transactionLineId: lineId,
                action: 'remove',
                itemName: 'Bacon',
                quantity: const Value<int>(1),
                itemProductId: Value<int?>(baconProductId),
                sourceGroupId: Value<int?>(proteinGroupId),
                sortKey: const Value<int>(30),
              ),
            );
        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'swap-sausage',
                transactionLineId: lineId,
                action: 'add',
                itemName: 'Sausage',
                quantity: const Value<int>(1),
                itemProductId: Value<int?>(sausageProductId),
                sourceGroupId: Value<int?>(proteinGroupId),
                chargeReason: const Value<String?>('free_swap'),
                sortKey: const Value<int>(31),
              ),
            );
        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'extra-hash-brown',
                transactionLineId: lineId,
                action: 'add',
                itemName: 'Hash Brown',
                quantity: const Value<int>(1),
                itemProductId: Value<int?>(extraProductId),
                chargeReason: const Value<String?>('extra_add'),
                extraPriceMinor: const Value<int>(0),
                priceEffectMinor: const Value<int>(0),
                sortKey: const Value<int>(40),
              ),
            );
        await database
            .into(database.breakfastCookingInstructions)
            .insert(
              db.BreakfastCookingInstructionsCompanion.insert(
                uuid: 'instruction-bacon',
                transactionLineId: lineId,
                itemProductId: baconProductId,
                itemName: 'Bacon',
                instructionCode: 'extra_crispy',
                instructionLabel: 'Extra Crispy',
                appliedQuantity: const Value<int>(2),
                sortKey: const Value<int>(50),
              ),
            );

        final PrinterService service = PrinterService(
          TransactionRepository(database),
        );
        final String printable = await service
            .buildKitchenTicketPreviewForTesting(transactionId: transactionId);

        final List<String> lines = printable.split('\n');

        expect(printable, contains('HALFWAY CAFE'));
        expect(lines.first, '                  HALFWAY CAFE');
        expect(lines[1], '------------------------------------------------');
        expect(
          lines[2],
          matches(RegExp(r'^KITCHEN TICKET\s+Order #1  09:05$')),
        );
        expect(lines[3], '                                      13/04/2026');
        expect(lines[4], '------------------------------------------------');
        expect(printable, contains('1x BIG BREAKFAST'));
        expect(printable, contains('£10.95'));
        expect(printable, contains('CAPPUCCINO | TOAST'));
        expect(printable, contains('  CAPPUCCINO | TOAST\n\n  - BACON'));
        expect(printable, contains('+ SAUSAGE'));
        expect(printable, contains('  >>> BACON - EXTRA CRISPY <<<'));
        expect(
          printable,
          contains(
            '  >>> BACON - EXTRA CRISPY <<<\n\n  EXTRAS:\n    + HASH BROWN',
          ),
        );
        expect(printable, isNot(contains('—')));
        expect(printable, isNot(contains('x2 - EXTRA CRISPY')));
        expect(printable, isNot(contains('TOTAL')));
        expect(printable, isNot(contains('TABLE')));
        expect(printable, isNot(contains('DRINK:')));
        expect(printable, isNot(contains('BREAD:')));
      },
    );

    test(
      'kitchen ticket keeps 48-char width, avoids data loss, and separates sauce and extras blocks',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        final int cashierId = await insertUser(
          database,
          name: 'Cashier',
          role: 'cashier',
        );
        final int shiftId = await insertShift(database, openedBy: cashierId);
        final int categoryId = await insertCategory(database, name: 'Lunch');
        final int burgerProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Cheese Burger',
          priceMinor: 610,
        );
        final int baguetteProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Bacon Baguette',
          priceMinor: 480,
        );
        final int potatoProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Jacket Potato Tuna Sweetcorn',
          priceMinor: 850,
        );
        final int transactionId = await insertTransaction(
          database,
          uuid: 'kitchen-layout-width',
          shiftId: shiftId,
          userId: cashierId,
          status: 'sent',
          totalAmountMinor: 1460,
        );
        await database.customUpdate(
          '''
        UPDATE transactions
        SET created_at = ?, updated_at = ?
        WHERE id = ?
        ''',
          variables: <Variable<Object>>[
            Variable<DateTime>(DateTime(2026, 4, 13, 20, 49)),
            Variable<DateTime>(DateTime(2026, 4, 13, 20, 49)),
            Variable<int>(transactionId),
          ],
          updates: {database.transactions},
        );

        final int burgerLineId = await database
            .into(database.transactionLines)
            .insert(
              db.TransactionLinesCompanion.insert(
                uuid: 'line-cheese-burger',
                transactionId: transactionId,
                productId: burgerProductId,
                productName: 'Cheese Burger',
                unitPriceMinor: 610,
                quantity: const Value<int>(1),
                lineTotalMinor: 610,
              ),
            );
        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'burger-extra-onion',
                transactionLineId: burgerLineId,
                action: 'add',
                itemName: 'Fried Onion',
                quantity: const Value<int>(1),
                extraPriceMinor: const Value<int>(0),
                sortKey: const Value<int>(10),
              ),
            );
        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'burger-extra-chips',
                transactionLineId: burgerLineId,
                action: 'add',
                itemName: 'Chips',
                quantity: const Value<int>(1),
                extraPriceMinor: const Value<int>(0),
                sortKey: const Value<int>(20),
              ),
            );
        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'burger-sauce-burger',
                transactionLineId: burgerLineId,
                action: 'add',
                itemName: 'Burger Sauce',
                quantity: const Value<int>(1),
                extraPriceMinor: const Value<int>(0),
                uiSection: const Value<String?>('sauces'),
                sortKey: const Value<int>(30),
              ),
            );

        final int baguetteLineId = await database
            .into(database.transactionLines)
            .insert(
              db.TransactionLinesCompanion.insert(
                uuid: 'line-bacon-baguette',
                transactionId: transactionId,
                productId: baguetteProductId,
                productName: 'Bacon Baguette',
                unitPriceMinor: 480,
                quantity: const Value<int>(1),
                lineTotalMinor: 480,
              ),
            );
        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'baguette-sauce-brown',
                transactionLineId: baguetteLineId,
                action: 'add',
                itemName: 'Brown Sauce',
                quantity: const Value<int>(1),
                extraPriceMinor: const Value<int>(0),
                uiSection: const Value<String?>('sauces'),
                sortKey: const Value<int>(40),
              ),
            );
        await database
            .into(database.orderModifiers)
            .insert(
              db.OrderModifiersCompanion.insert(
                uuid: 'baguette-sauce-burger',
                transactionLineId: baguetteLineId,
                action: 'add',
                itemName: 'Burger Sauce',
                quantity: const Value<int>(1),
                extraPriceMinor: const Value<int>(0),
                uiSection: const Value<String?>('sauces'),
                sortKey: const Value<int>(50),
              ),
            );

        await database
            .into(database.transactionLines)
            .insert(
              db.TransactionLinesCompanion.insert(
                uuid: 'line-jacket-potato',
                transactionId: transactionId,
                productId: potatoProductId,
                productName: 'Jacket Potato Tuna Sweetcorn',
                unitPriceMinor: 850,
                quantity: const Value<int>(1),
                lineTotalMinor: 850,
              ),
            );

        final PrinterService service = PrinterService(
          TransactionRepository(database),
        );
        final String printable = await service
            .buildKitchenTicketPreviewForTesting(transactionId: transactionId);

        expect(printable, contains('1x CHEESE BURGER'));
        expect(
          printable,
          contains(
            '  EXTRAS:\n    + FRIED ONION\n    + CHIPS\n\n  SAUCE:\n    + BURGER SAUCE',
          ),
        );
        expect(printable, contains('1x BACON BAGUETTE'));
        expect(printable, contains('1x BACON BAGUETTE'));
        expect(
          printable,
          contains('  SAUCE:\n    + BROWN SAUCE\n    + BURGER SAUCE'),
        );
        expect(printable, isNot(contains('1x BACON\nBAGUETTE')));
        expect(printable, contains('1x JACKET POTATO TUNA SWEETCORN'));
        expect(printable, isNot(contains('...')));
        expect(printable, contains('£8.50'));
        expect(printable, isNot(contains('TOTAL')));
        expect(printable, isNot(contains('—')));
      },
    );
  });
}
