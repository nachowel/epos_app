import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/print_job.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/test_database.dart';

void main() {
  group('OrdersNotifier print safety', () {
    test('send order is not blocked when kitchen print fails', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int categoryId = await insertCategory(db, name: 'Food');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Soup',
        priceMinor: 950,
      );
      final int transactionId = await insertTransaction(
        db,
        uuid: 'orders-provider-print-warning',
        shiftId: shiftId,
        userId: cashierId,
        status: 'draft',
        totalAmountMinor: 950,
      );
      await TransactionRepository(db).addLine(
        transactionId: transactionId,
        productId: productId,
        quantity: 1,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          printerServiceProvider.overrideWithValue(
            _FailingKitchenPrinterService(TransactionRepository(db)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final OrdersNotifier notifier = container.read(
        ordersNotifierProvider.notifier,
      );
      final bool result = await notifier.sendOrder(
        transactionId: transactionId,
        currentUser: User(
          id: cashierId,
          name: 'Cashier',
          pin: null,
          password: null,
          role: UserRole.cashier,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      );

      final OrdersState state = container.read(ordersNotifierProvider);
      final transaction = await TransactionRepository(
        db,
      ).getById(transactionId);

      expect(result, isTrue);
      expect(transaction, isNotNull);
      expect(transaction!.status.name, 'sent');
      expect(state.errorMessage, AppStrings.kitchenPrintRetryRequired);
    });

    test('receipt reprint is blocked before printer call for sent order', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'orders-provider-receipt-blocked',
        shiftId: shiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 500,
      );

      final _TrackingPrinterService printer = _TrackingPrinterService(
        TransactionRepository(db),
      );
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          printerServiceProvider.overrideWithValue(printer),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authNotifierProvider.notifier).loadUserById(cashierId);

      final OrdersNotifier notifier = container.read(
        ordersNotifierProvider.notifier,
      );
      final bool result = await notifier.reprintReceipt(transactionId);

      expect(result, isFalse);
      expect(printer.receiptCalls, 0);
      expect(
        container.read(ordersNotifierProvider).errorMessage,
        contains('Receipt can be printed only for paid transactions.'),
      );
    });
  });
}

class _FailingKitchenPrinterService extends PrinterService {
  _FailingKitchenPrinterService(super.transactionRepository);

  @override
  Future<PrintJob> printKitchenTicket(
    int transactionId, {
    bool allowReprint = false,
    int? actorUserId,
  }) async {
    throw PrinterException('Kitchen printer offline');
  }
}

class _TrackingPrinterService extends PrinterService {
  _TrackingPrinterService(super.transactionRepository);

  int receiptCalls = 0;

  @override
  Future<PrintJob> printReceipt(
    int transactionId, {
    bool allowReprint = false,
    int? actorUserId,
  }) async {
    receiptCalls += 1;
    throw StateError('receipt printer should not be called');
  }
}
