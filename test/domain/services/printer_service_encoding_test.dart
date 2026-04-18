import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:epos_app/data/database/app_database.dart' as db;
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/print_job_repository.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/print_job.dart';
import 'package:epos_app/domain/models/printer_settings.dart';
import 'package:epos_app/domain/models/shift_report.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrinterService ESC/POS encoding', () {
    test(
      'kitchen ticket sets CP1252 and preserves repeated pound values',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        final int cashierId = await insertUser(
          database,
          name: 'Cashier',
          role: 'cashier',
        );
        final int shiftId = await insertShift(database, openedBy: cashierId);
        final int categoryId = await insertCategory(database, name: 'Kitchen');
        final int teaProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 1250,
        );
        final int cakeProductId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Cake',
          priceMinor: 1250,
        );
        final int transactionId = await insertTransaction(
          database,
          uuid: 'kitchen-encoding',
          shiftId: shiftId,
          userId: cashierId,
          status: 'sent',
          totalAmountMinor: 2500,
        );

        await database
            .into(database.transactionLines)
            .insert(
              db.TransactionLinesCompanion.insert(
                uuid: 'line-kitchen-tea',
                transactionId: transactionId,
                productId: teaProductId,
                productName: 'Tea',
                unitPriceMinor: 1250,
                quantity: const Value<int>(1),
                lineTotalMinor: 1250,
              ),
            );
        await database
            .into(database.transactionLines)
            .insert(
              db.TransactionLinesCompanion.insert(
                uuid: 'line-kitchen-cake',
                transactionId: transactionId,
                productId: cakeProductId,
                productName: 'Cake',
                unitPriceMinor: 1250,
                quantity: const Value<int>(1),
                lineTotalMinor: 1250,
              ),
            );

        final PrinterService service = PrinterService(
          TransactionRepository(database),
        );

        final List<int> payload = await service
            .buildKitchenTicketBytesForTesting(
              printer: _encodingPrinter,
              transactionId: transactionId,
            );

        expect(payload.take(2), orderedEquals(<int>[0x1B, 0x40]));
        expect(_countPattern(payload, _codeTableCommand), greaterThan(0));
        expect(
          _countPattern(payload, _pound1250Pattern),
          greaterThanOrEqualTo(2),
        );
      },
    );

    test(
      'z report sets CP1252 and preserves pound values across totals',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        final PrinterService service = PrinterService(
          TransactionRepository(database),
        );
        const ShiftReport report = ShiftReport(
          shiftId: 7,
          paidCount: 2,
          paidTotalMinor: 1250,
          refundCount: 0,
          refundTotalMinor: 0,
          netSalesMinor: 1250,
          openCount: 1,
          openTotalMinor: 1250,
          cancelledCount: 0,
          cashCount: 1,
          cashTotalMinor: 1250,
          cardCount: 1,
          cardTotalMinor: 1250,
        );

        final List<int> payload = await service.buildZReportBytesForTesting(
          printer: _encodingPrinter,
          report: report,
        );

        expect(payload.take(2), orderedEquals(<int>[0x1B, 0x40]));
        expect(_countPattern(payload, _codeTableCommand), greaterThan(0));
        expect(
          _countPattern(payload, _pound1250Pattern),
          greaterThanOrEqualTo(4),
        );
      },
    );

    test(
      'receipt pipeline sends pound values with the configured code table',
      () async {
        final ServerSocket server = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(server.close);

        final Completer<List<int>> receivedBytes = Completer<List<int>>();
        unawaited(
          server.listen((Socket client) {
            final List<int> buffer = <int>[];
            client.listen(
              buffer.addAll,
              onDone: () {
                if (!receivedBytes.isCompleted) {
                  receivedBytes.complete(buffer);
                }
              },
              onError: receivedBytes.completeError,
            );
          }).asFuture<void>(),
        );

        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        final int cashierId = await insertUser(
          database,
          name: 'Cashier',
          role: 'cashier',
        );
        final int shiftId = await insertShift(database, openedBy: cashierId);
        final int categoryId = await insertCategory(database, name: 'Receipt');
        final int productId = await insertProduct(
          database,
          categoryId: categoryId,
          name: 'Breakfast Roll',
          priceMinor: 1250,
        );
        final int transactionId = await insertTransaction(
          database,
          uuid: 'receipt-encoding',
          shiftId: shiftId,
          userId: cashierId,
          status: 'paid',
          totalAmountMinor: 1250,
          paidAt: DateTime(2026, 4, 13, 10, 0),
        );
        await database
            .into(database.transactionLines)
            .insert(
              db.TransactionLinesCompanion.insert(
                uuid: 'line-receipt-roll',
                transactionId: transactionId,
                productId: productId,
                productName: 'Breakfast Roll',
                unitPriceMinor: 1250,
                quantity: const Value<int>(1),
                lineTotalMinor: 1250,
              ),
            );
        await insertPayment(
          database,
          uuid: 'payment-receipt-encoding',
          transactionId: transactionId,
          method: 'card',
          amountMinor: 1250,
          paidAt: DateTime(2026, 4, 13, 10, 0),
        );
        await insertPrintJob(
          database,
          transactionId: transactionId,
          target: PrintJobTarget.receipt,
          status: 'pending',
        );
        await SettingsRepository(database).savePrinterSettings(
          deviceName: 'Encoding Printer',
          deviceAddress: '127.0.0.1',
          paperWidth: 80,
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: '127.0.0.1',
          port: server.port,
        );

        final PrinterService service = PrinterService(
          TransactionRepository(database),
          paymentRepository: PaymentRepository(database),
          printJobRepository: PrintJobRepository(database),
          settingsRepository: SettingsRepository(database),
        );

        await service.printReceipt(transactionId);

        final List<int> payload = await receivedBytes.future.timeout(
          const Duration(seconds: 2),
        );

        expect(payload.take(2), orderedEquals(<int>[0x1B, 0x40]));
        expect(_countPattern(payload, _codeTableCommand), greaterThan(0));
        expect(
          _countPattern(payload, _pound1250Pattern),
          greaterThanOrEqualTo(2),
        );
      },
    );
  });
}

const PrinterSettingsModel _encodingPrinter = PrinterSettingsModel(
  id: 1,
  deviceName: 'Encoding Printer',
  deviceAddress: 'AA:BB:CC',
  paperWidth: 80,
  isActive: true,
  connectionType: PrinterConnectionType.bluetooth,
);

const List<int> _codeTableCommand = <int>[0x1B, 0x74, 0x10];
const List<int> _pound1250Pattern = <int>[0xA3, 0x31, 0x32, 0x2E, 0x35, 0x30];

int _countPattern(List<int> bytes, List<int> pattern) {
  int count = 0;
  for (int index = 0; index <= bytes.length - pattern.length; index += 1) {
    bool matches = true;
    for (int offset = 0; offset < pattern.length; offset += 1) {
      if (bytes[index + offset] != pattern[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      count += 1;
    }
  }
  return count;
}
