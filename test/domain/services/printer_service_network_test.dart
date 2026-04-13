import 'dart:async';
import 'dart:io';

import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/printer_settings.dart';
import 'package:epos_app/domain/models/shift_report.dart';
import 'package:epos_app/domain/services/printer_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PrinterService ethernet transport', () {
    test('printTestPage sends ESC/POS bytes over raw TCP socket', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      final db = createTestDatabase();
      addTearDown(db.close);

      final PrinterService service = PrinterService(TransactionRepository(db));
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

      await service.printTestPage(
        deviceName: 'Ethernet Printer',
        deviceAddress: '127.0.0.1',
        paperWidth: 80,
        connectionType: PrinterConnectionType.ethernet,
        ipAddress: '127.0.0.1',
        port: server.port,
      );

      final List<int> payload = await receivedBytes.future.timeout(
        const Duration(seconds: 2),
      );

      expect(payload, isNotEmpty);
      expect(_containsAscii(payload, 'TEST PRINT'), isTrue);
    });

    test(
      'printTestPage surfaces network connect failures as printer errors',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final ServerSocket server = await ServerSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final int closedPort = server.port;
        await server.close();

        final PrinterService service = PrinterService(
          TransactionRepository(db),
        );

        await expectLater(
          service.printTestPage(
            deviceName: 'Ethernet Printer',
            deviceAddress: '127.0.0.1',
            paperWidth: 80,
            connectionType: PrinterConnectionType.ethernet,
            ipAddress: '127.0.0.1',
            port: closedPort,
          ),
          throwsA(
            isA<PrinterException>().having(
              (PrinterException error) => error.message,
              'message',
              contains('Failed to connect to network printer'),
            ),
          ),
        );
      },
    );

    test(
      'printTestPage surfaces network connect timeout as printer error',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final PrinterService service = PrinterService(
          TransactionRepository(db),
          socketConnector: (String host, int port, Duration timeout) async {
            await Future<void>.delayed(
              timeout + const Duration(milliseconds: 50),
            );
            throw StateError('unreachable');
          },
        );

        await expectLater(
          service.printTestPage(
            deviceName: 'Ethernet Printer',
            deviceAddress: '192.168.1.100',
            paperWidth: 80,
            connectionType: PrinterConnectionType.ethernet,
            ipAddress: '192.168.1.100',
            port: 9100,
          ),
          throwsA(
            isA<PrinterException>().having(
              (PrinterException error) => error.message,
              'message',
              contains('Timed out connecting to network printer'),
            ),
          ),
        );
      },
    );

    test(
      'same z report bytes are produced for bluetooth and ethernet transports',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final PrinterService service = PrinterService(
          TransactionRepository(db),
        );
        const ShiftReport report = ShiftReport(
          shiftId: 1,
          paidCount: 2,
          paidTotalMinor: 1000,
          openCount: 0,
          openTotalMinor: 0,
          cancelledCount: 0,
          cashCount: 1,
          cashTotalMinor: 500,
          cardCount: 1,
          cardTotalMinor: 500,
        );

        final List<int> bluetoothBytes = await service
            .buildZReportBytesForTesting(
              printer: const PrinterSettingsModel(
                id: 1,
                deviceName: 'Counter Printer',
                deviceAddress: 'AA:BB:CC',
                paperWidth: 80,
                isActive: true,
                connectionType: PrinterConnectionType.bluetooth,
              ),
              report: report,
            );
        final List<int> ethernetBytes = await service
            .buildZReportBytesForTesting(
              printer: const PrinterSettingsModel(
                id: 2,
                deviceName: 'Kitchen Ethernet',
                deviceAddress: '192.168.1.100',
                paperWidth: 80,
                isActive: true,
                connectionType: PrinterConnectionType.ethernet,
                ipAddress: '192.168.1.100',
                port: 9100,
              ),
              report: report,
            );

        expect(ethernetBytes, bluetoothBytes);
      },
    );
  });
}

bool _containsAscii(List<int> bytes, String value) {
  final List<int> pattern = value.codeUnits;
  for (int index = 0; index <= bytes.length - pattern.length; index += 1) {
    bool matches = true;
    for (int offset = 0; offset < pattern.length; offset += 1) {
      if (bytes[index + offset] != pattern[offset]) {
        matches = false;
        break;
      }
    }
    if (matches) {
      return true;
    }
  }
  return false;
}
