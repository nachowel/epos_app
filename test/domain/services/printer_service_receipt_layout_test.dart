import 'package:drift/drift.dart' show Value, Variable;
import 'package:epos_app/data/database/app_database.dart' as db;
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrinterService receipt layout', () {
    test('receipt preview uses branded customer-facing layout', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      final int cashierId = await insertUser(
        database,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(database, openedBy: cashierId);
      final int categoryId = await insertCategory(database, name: 'Lunch');
      final int baguetteProductId = await insertProduct(
        database,
        categoryId: categoryId,
        name: 'Sausage & Egg Baguette',
        priceMinor: 580,
      );
      final int teaProductId = await insertProduct(
        database,
        categoryId: categoryId,
        name: 'Tea',
        priceMinor: 150,
      );

      final int transactionId = await insertTransaction(
        database,
        uuid: 'receipt-layout',
        shiftId: shiftId,
        userId: cashierId,
        status: 'paid',
        totalAmountMinor: 830,
        paidAt: DateTime(2026, 4, 14, 9, 45),
        updatedAt: DateTime(2026, 4, 14, 9, 45),
      );
      await database.customUpdate(
        '''
        UPDATE transactions
        SET
          subtotal_minor = ?,
          modifier_total_minor = ?,
          discount_type = ?,
          discount_value_minor = ?,
          discount_amount_minor = ?,
          discount_reason = ?,
          discount_applied_by = ?,
          total_amount_minor = ?
        WHERE id = ?
        ''',
        variables: <Variable<Object>>[
          Variable<int>(730),
          Variable<int>(200),
          Variable<String>('amount'),
          Variable<int>(100),
          Variable<int>(100),
          Variable<String>('Morning promo'),
          Variable<int>(cashierId),
          Variable<int>(830),
          Variable<int>(transactionId),
        ],
        updates: {database.transactions},
      );

      final int baguetteLineId = await database
          .into(database.transactionLines)
          .insert(
            db.TransactionLinesCompanion.insert(
              uuid: 'receipt-line-baguette',
              transactionId: transactionId,
              productId: baguetteProductId,
              productName: 'Sausage & Egg Baguette',
              unitPriceMinor: 580,
              quantity: const Value<int>(1),
              lineTotalMinor: 780,
            ),
          );
      await database
          .into(database.orderModifiers)
          .insert(
            db.OrderModifiersCompanion.insert(
              uuid: 'receipt-add-mushrooms',
              transactionLineId: baguetteLineId,
              action: 'add',
              itemName: 'Mushrooms',
              quantity: const Value<int>(1),
              extraPriceMinor: const Value<int>(200),
              priceEffectMinor: const Value<int>(200),
              sortKey: const Value<int>(10),
            ),
          );
      await database
          .into(database.orderModifiers)
          .insert(
            db.OrderModifiersCompanion.insert(
              uuid: 'receipt-remove-sausage',
              transactionLineId: baguetteLineId,
              action: 'remove',
              itemName: 'Sausage',
              quantity: const Value<int>(1),
              sortKey: const Value<int>(20),
            ),
          );
      await database
          .into(database.breakfastCookingInstructions)
          .insert(
            db.BreakfastCookingInstructionsCompanion.insert(
              uuid: 'receipt-note-egg',
              transactionLineId: baguetteLineId,
              itemProductId: baguetteProductId,
              itemName: 'Egg',
              instructionCode: 'runny',
              instructionLabel: 'Runny',
              appliedQuantity: const Value<int>(1),
              sortKey: const Value<int>(30),
            ),
          );

      await database
          .into(database.transactionLines)
          .insert(
            db.TransactionLinesCompanion.insert(
              uuid: 'receipt-line-tea',
              transactionId: transactionId,
              productId: teaProductId,
              productName: 'Tea',
              unitPriceMinor: 150,
              quantity: const Value<int>(1),
              lineTotalMinor: 150,
            ),
          );

      await insertPayment(
        database,
        uuid: 'receipt-payment',
        transactionId: transactionId,
        method: 'card',
        amountMinor: 830,
        paidAt: DateTime(2026, 4, 14, 9, 45),
      );

      final PrinterService service = PrinterService(
        TransactionRepository(database),
        paymentRepository: PaymentRepository(database),
      );

      final String printable = await service.buildReceiptPreviewForTesting(
        transactionId: transactionId,
      );

      expect(printable, contains('HALFWAY CAFE'));
      expect(printable, contains('176 Halfway St, Sidcup'));
      expect(printable, contains('020 3343 5303'));
      expect(printable, contains('Receipt'));
      expect(printable, contains('Order #1'));
      expect(printable, contains('14/04/2026 09:45'));
      expect(printable, contains('1x Sausage & Egg Baguette'));
      expect(printable, contains('  + Mushrooms'));
      expect(printable, contains('  - Sausage'));
      expect(printable, contains('1x Tea'));
      expect(printable, contains('Discount'));
      expect(printable, contains('£1.00'));
      expect(printable, contains('TOTAL'));
      expect(printable, contains('£8.30'));
      expect(printable, contains('Payment: CARD'));
      expect(printable, contains('Thank you for your visit!'));
      expect(printable, isNot(contains('(swap)')));
      expect(printable, isNot(contains('(+')));
      expect(printable, isNot(contains('Subtotal')));
      expect(printable, isNot(contains('Extras')));
      expect(printable, isNot(contains('£2.00')));
      expect(printable, isNot(contains('Table')));
      expect(printable, isNot(contains('Paid ')));
      expect(printable, isNot(contains('DA15 8DJ')));
    });

    test('receipt preview keeps custom sale lines visible', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      final int cashierId = await insertUser(
        database,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(database, openedBy: cashierId);
      final int categoryId = await insertCategory(database, name: 'Misc');
      final int customProductId = await insertProduct(
        database,
        categoryId: categoryId,
        name: 'Custom Sale',
        priceMinor: 0,
        isVisibleOnPos: false,
        isCustom: true,
      );

      final int transactionId = await insertTransaction(
        database,
        uuid: 'receipt-layout-custom-sale',
        shiftId: shiftId,
        userId: cashierId,
        status: 'paid',
        totalAmountMinor: 700,
        paidAt: DateTime(2026, 4, 14, 10, 15),
        updatedAt: DateTime(2026, 4, 14, 10, 15),
      );
      await database.customUpdate(
        '''
        UPDATE transactions
        SET subtotal_minor = ?, modifier_total_minor = ?, total_amount_minor = ?
        WHERE id = ?
        ''',
        variables: <Variable<Object>>[
          Variable<int>(700),
          Variable<int>(0),
          Variable<int>(700),
          Variable<int>(transactionId),
        ],
        updates: {database.transactions},
      );
      await database
          .into(database.transactionLines)
          .insert(
            db.TransactionLinesCompanion.insert(
              uuid: 'receipt-custom-sale-line',
              transactionId: transactionId,
              productId: customProductId,
              productName: 'Custom Sale',
              unitPriceMinor: 700,
              quantity: const Value<int>(1),
              lineTotalMinor: 700,
              customNote: const Value<String?>('Manual item'),
              createdByUserId: Value<int?>(cashierId),
            ),
          );
      await insertPayment(
        database,
        uuid: 'receipt-custom-sale-payment',
        transactionId: transactionId,
        method: 'card',
        amountMinor: 700,
        paidAt: DateTime(2026, 4, 14, 10, 15),
      );

      final PrinterService service = PrinterService(
        TransactionRepository(database),
        paymentRepository: PaymentRepository(database),
      );

      final String printable = await service.buildReceiptPreviewForTesting(
        transactionId: transactionId,
      );

      expect(printable, contains('1x Custom Sale'));
      expect(printable, contains('£7.00'));
      expect(printable, contains('TOTAL'));
    });
  });
}
