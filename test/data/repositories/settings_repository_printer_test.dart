import 'dart:io';

import 'package:epos_app/data/database/app_database.dart' as db;
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/domain/models/printer_settings.dart';
import 'package:drift/drift.dart' show QueryRow, Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  // Manual regression checklist for the temporary compatibility storage:
  // - save -> reopen -> edit -> save
  // - app restart -> read back
  // - bluetooth legacy kaydi bozulmuyor
  // - ethernet kaydi device name edit sonrasi bozulmuyor
  group('SettingsRepository printer persistence', () {
    test('bluetooth settings roundtrip without transport regression', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final SettingsRepository repository = SettingsRepository(db);
      await repository.savePrinterSettings(
        deviceName: 'Counter Printer',
        deviceAddress: 'AA:BB:CC',
        paperWidth: 80,
        connectionType: PrinterConnectionType.bluetooth,
      );

      final PrinterSettingsModel? printer = await repository
          .getActivePrinterSettings();

      expect(printer, isNotNull);
      expect(printer!.deviceName, 'Counter Printer');
      expect(printer.deviceAddress, 'AA:BB:CC');
      expect(printer.connectionType, PrinterConnectionType.bluetooth);
      expect(printer.port, isNull);
    });

    test(
      'ethernet settings roundtrip with raw host preserved in device address',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final SettingsRepository repository = SettingsRepository(db);
        await repository.savePrinterSettings(
          deviceName: 'Kitchen Ethernet',
          deviceAddress: 'printer.local',
          paperWidth: 80,
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: 'printer.local',
          port: 9100,
        );

        final PrinterSettingsModel? printer = await repository
            .getActivePrinterSettings();

        expect(printer, isNotNull);
        expect(printer!.deviceName, 'Kitchen Ethernet');
        expect(printer.deviceAddress, 'printer.local');
        expect(printer.ipAddress, 'printer.local');
        expect(printer.port, 9100);
        expect(printer.connectionType, PrinterConnectionType.ethernet);
      },
    );

    test(
      'manual: save -> reopen -> edit -> save keeps temporary ethernet metadata stable',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        final SettingsRepository repository = SettingsRepository(database);
        await repository.savePrinterSettings(
          deviceName: 'Kitchen Ethernet',
          deviceAddress: 'printer.local',
          paperWidth: 80,
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: 'printer.local',
          port: 9100,
        );

        final PrinterSettingsModel? reopened = await repository
            .getActivePrinterSettings();
        expect(reopened, isNotNull);
        expect(reopened!.deviceName, 'Kitchen Ethernet');

        await repository.savePrinterSettings(
          deviceName: 'Kitchen Ethernet Updated',
          deviceAddress: reopened.deviceAddress,
          paperWidth: reopened.paperWidth,
          connectionType: reopened.connectionType,
          ipAddress: reopened.ipAddress,
          port: reopened.port,
        );

        final PrinterSettingsModel? afterEdit = await repository
            .getActivePrinterSettings();
        final QueryRow storedRow = await _activePrinterRow(database);

        expect(afterEdit, isNotNull);
        expect(afterEdit!.deviceName, 'Kitchen Ethernet Updated');
        expect(afterEdit.connectionType, PrinterConnectionType.ethernet);
        expect(afterEdit.ipAddress, 'printer.local');
        expect(afterEdit.port, 9100);
        expect(
          storedRow.read<String>('device_name'),
          'Kitchen Ethernet Updated',
        );
        expect(storedRow.read<String>('connection_type'), 'ethernet');
        expect(storedRow.read<String?>('ip_address'), 'printer.local');
        expect(storedRow.read<int?>('port'), 9100);
      },
    );

    test(
      'manual: app restart -> read back preserves temporary ethernet metadata',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        await SettingsRepository(database).savePrinterSettings(
          deviceName: 'Restart Printer',
          deviceAddress: '192.168.1.50',
          paperWidth: 58,
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: '192.168.1.50',
          port: 9200,
        );

        final SettingsRepository reopenedRepository = SettingsRepository(
          database,
        );
        final PrinterSettingsModel? printer = await reopenedRepository
            .getActivePrinterSettings();

        expect(printer, isNotNull);
        expect(printer!.deviceName, 'Restart Printer');
        expect(printer.connectionType, PrinterConnectionType.ethernet);
        expect(printer.ipAddress, '192.168.1.50');
        expect(printer.port, 9200);
        expect(printer.paperWidth, 58);
      },
    );

    test('yeni ethernet kaydi restart sonrasi stabil', () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'printer-settings-restart-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final String path =
          '${directory.path}${Platform.pathSeparator}printer_settings.sqlite';

      final db.AppDatabase firstDb = createPersistentTestDatabase(path);
      await SettingsRepository(firstDb).savePrinterSettings(
        deviceName: 'Stable Ethernet',
        deviceAddress: 'printer.local',
        paperWidth: 80,
        connectionType: PrinterConnectionType.ethernet,
        ipAddress: 'printer.local',
        port: 9100,
      );
      await firstDb.close();

      final db.AppDatabase reopenedDb = createPersistentTestDatabase(path);
      addTearDown(reopenedDb.close);
      final SettingsRepository reopenedRepository = SettingsRepository(
        reopenedDb,
      );
      final PrinterSettingsModel? reopened = await reopenedRepository
          .getActivePrinterSettings();
      final QueryRow row = await _activePrinterRow(reopenedDb);

      expect(reopened, isNotNull);
      expect(reopened!.deviceName, 'Stable Ethernet');
      expect(reopened.connectionType, PrinterConnectionType.ethernet);
      expect(reopened.deviceAddress, 'printer.local');
      expect(reopened.ipAddress, 'printer.local');
      expect(reopened.port, 9100);
      expect(row.read<String>('device_name'), 'Stable Ethernet');
      expect(row.read<String>('device_address'), 'printer.local');
      expect(row.read<String>('connection_type'), 'ethernet');
      expect(row.read<String?>('ip_address'), 'printer.local');
      expect(row.read<int?>('port'), 9100);
    });

    test('manual: bluetooth legacy kaydi bozulmuyor', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      await database
          .into(database.printerSettings)
          .insert(
            db.PrinterSettingsCompanion.insert(
              deviceName: 'Counter Printer',
              deviceAddress: 'AA:BB:CC',
              paperWidth: const Value<int>(80),
              isActive: const Value<bool>(true),
            ),
          );

      final PrinterSettingsModel? printer = await SettingsRepository(
        database,
      ).getActivePrinterSettings();

      expect(printer, isNotNull);
      expect(printer!.deviceName, 'Counter Printer');
      expect(printer.connectionType, PrinterConnectionType.bluetooth);
      expect(printer.deviceAddress, 'AA:BB:CC');
      expect(printer.port, isNull);
    });

    test(
      'manual: ethernet kaydi device name edit sonrasi bozulmuyor',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        final SettingsRepository repository = SettingsRepository(database);
        await repository.savePrinterSettings(
          deviceName: 'Kitchen Ethernet',
          deviceAddress: '192.168.1.100',
          paperWidth: 80,
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: '192.168.1.100',
          port: 9100,
        );

        final PrinterSettingsModel? beforeEdit = await repository
            .getActivePrinterSettings();
        expect(beforeEdit, isNotNull);

        await repository.savePrinterSettings(
          // Simulates a stale/editable UI field accidentally sending the
          // storage envelope back instead of the visible name.
          deviceName: beforeEdit!.storageDeviceName,
          deviceAddress: beforeEdit.deviceAddress,
          paperWidth: beforeEdit.paperWidth,
          connectionType: beforeEdit.connectionType,
          ipAddress: beforeEdit.ipAddress,
          port: beforeEdit.port,
        );

        final PrinterSettingsModel? afterEdit = await repository
            .getActivePrinterSettings();

        expect(afterEdit, isNotNull);
        expect(afterEdit!.deviceName, 'Kitchen Ethernet');
        expect(afterEdit.connectionType, PrinterConnectionType.ethernet);
        expect(afterEdit.deviceAddress, '192.168.1.100');
        expect(afterEdit.port, 9100);
      },
    );

    test('malformed envelope falls back deterministically', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      await _insertActivePrinterRow(
        database,
        deviceName: 'printercfg:v2:%7Bbad-json',
        deviceAddress: 'printer.local',
      );

      final PrinterSettingsModel? printer = await SettingsRepository(
        database,
      ).getActivePrinterSettings();

      expect(printer, isNotNull);
      expect(printer!.deviceName, 'Ethernet Printer (printer.local)');
      expect(printer.connectionType, PrinterConnectionType.ethernet);
      expect(printer.ipAddress, 'printer.local');
      expect(printer.port, PrinterSettingsModel.defaultEthernetPort);
    });

    test('empty metadata falls back deterministically', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      await _insertActivePrinterRow(
        database,
        deviceName: 'printercfg:v2:%7B%7D',
        deviceAddress: 'printer.local',
      );

      final PrinterSettingsModel? printer = await SettingsRepository(
        database,
      ).getActivePrinterSettings();

      expect(printer, isNotNull);
      expect(printer!.deviceName, 'Ethernet Printer (printer.local)');
      expect(printer.connectionType, PrinterConnectionType.ethernet);
      expect(printer.ipAddress, 'printer.local');
      expect(printer.port, PrinterSettingsModel.defaultEthernetPort);
    });

    test('partial metadata falls back deterministically', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      await _insertActivePrinterRow(
        database,
        deviceName: 'printercfg:v2:%7B%22name%22%3A%22Kitchen%20Partial%22%7D',
        deviceAddress: 'printer.local',
      );

      final PrinterSettingsModel? printer = await SettingsRepository(
        database,
      ).getActivePrinterSettings();

      expect(printer, isNotNull);
      expect(printer!.deviceName, 'Kitchen Partial');
      expect(printer.connectionType, PrinterConnectionType.ethernet);
      expect(printer.ipAddress, 'printer.local');
      expect(printer.port, PrinterSettingsModel.defaultEthernetPort);
    });

    test('legacy bluetooth + corrupted envelope remains bluetooth', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      await _insertActivePrinterRow(
        database,
        deviceName:
            'printercfg:v2:%7B%22name%22%3A%22Counter%20Printer%22%2C%22connection_type%22%3A%22invalid%22%7D',
        deviceAddress: 'AA:BB:CC',
      );

      final PrinterSettingsModel? printer = await SettingsRepository(
        database,
      ).getActivePrinterSettings();

      expect(printer, isNotNull);
      expect(printer!.deviceName, 'Counter Printer');
      expect(printer.connectionType, PrinterConnectionType.bluetooth);
      expect(printer.deviceAddress, 'AA:BB:CC');
      expect(printer.port, isNull);
    });

    test(
      'corrupted envelope with no salvaged name creates distinguishable bluetooth fallback name',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        await _insertActivePrinterRow(
          database,
          deviceName: 'printercfg:v2:%7Bbad-json',
          deviceAddress: 'AA:BB:CC:DD',
        );

        final PrinterSettingsModel? printer = await SettingsRepository(
          database,
        ).getActivePrinterSettings();

        expect(printer, isNotNull);
        expect(printer!.deviceName, 'Bluetooth Printer (CCDD)');
        expect(printer.connectionType, PrinterConnectionType.bluetooth);
        expect(printer.deviceAddress, 'AA:BB:CC:DD');
      },
    );

    test(
      'ethernet + corrupted envelope does not downgrade to bluetooth',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        await _insertActivePrinterRow(
          database,
          deviceName:
              'printercfg:v2:%7B%22name%22%3A%22Kitchen%20Ethernet%22%2C%22connection_type%22%3A%22invalid%22%7D',
          deviceAddress: 'printer.local',
        );

        final PrinterSettingsModel? printer = await SettingsRepository(
          database,
        ).getActivePrinterSettings();

        expect(printer, isNotNull);
        expect(printer!.deviceName, 'Kitchen Ethernet');
        expect(printer.connectionType, PrinterConnectionType.ethernet);
        expect(printer.deviceAddress, 'printer.local');
        expect(printer.port, PrinterSettingsModel.defaultEthernetPort);
      },
    );

    test(
      'corrupted envelope with ambiguous opaque address stays on conservative bluetooth fallback',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        await _insertActivePrinterRow(
          database,
          deviceName: 'printercfg:v2:%7Bbad-json',
          deviceAddress: 'kitchen_printer',
        );

        final PrinterSettingsModel? printer = await SettingsRepository(
          database,
        ).getActivePrinterSettings();

        expect(printer, isNotNull);
        expect(printer!.deviceName, 'Bluetooth Printer');
        expect(printer.connectionType, PrinterConnectionType.bluetooth);
        expect(printer.deviceAddress, 'kitchen_printer');
        expect(printer.port, isNull);
      },
    );

    test('read -> normalize -> save roundtrip bozulmuyor', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      await _insertActivePrinterRow(
        database,
        deviceName:
            'printercfg:v2:%7B%22name%22%3A%22Kitchen%20Roundtrip%22%7D',
        deviceAddress: 'printer.local',
      );

      final SettingsRepository repository = SettingsRepository(database);
      final PrinterSettingsModel? readBack = await repository
          .getActivePrinterSettings();
      expect(readBack, isNotNull);

      await repository.savePrinterSettings(
        deviceName: readBack!.deviceName,
        deviceAddress: readBack.deviceAddress,
        paperWidth: readBack.paperWidth,
        connectionType: readBack.connectionType,
        ipAddress: readBack.ipAddress,
        port: readBack.port,
      );

      final PrinterSettingsModel? afterSave = await repository
          .getActivePrinterSettings();
      final QueryRow storedRow = await _activePrinterRow(database);

      expect(afterSave, isNotNull);
      expect(afterSave!.deviceName, 'Kitchen Roundtrip');
      expect(afterSave.connectionType, PrinterConnectionType.ethernet);
      expect(afterSave.ipAddress, 'printer.local');
      expect(afterSave.port, PrinterSettingsModel.defaultEthernetPort);
      expect(storedRow.read<String>('device_name'), 'Kitchen Roundtrip');
      expect(storedRow.read<String>('connection_type'), 'ethernet');
      expect(storedRow.read<String?>('ip_address'), 'printer.local');
      expect(
        storedRow.read<int?>('port'),
        PrinterSettingsModel.defaultEthernetPort,
      );
    });

    test(
      'corrupted envelope -> edit -> save -> reopen -> save remains stable',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        await _insertActivePrinterRow(
          database,
          deviceName: 'printercfg:v2:%7Bbad-json',
          deviceAddress: 'printer.local',
        );

        final SettingsRepository repository = SettingsRepository(database);
        final PrinterSettingsModel? firstRead = await repository
            .getActivePrinterSettings();
        expect(firstRead, isNotNull);
        expect(firstRead!.deviceName, 'Ethernet Printer (printer.local)');

        await repository.savePrinterSettings(
          deviceName: 'Kitchen Restored',
          deviceAddress: firstRead.deviceAddress,
          paperWidth: firstRead.paperWidth,
          connectionType: firstRead.connectionType,
          ipAddress: firstRead.ipAddress,
          port: firstRead.port,
        );

        final PrinterSettingsModel? reopened = await repository
            .getActivePrinterSettings();
        expect(reopened, isNotNull);
        expect(reopened!.deviceName, 'Kitchen Restored');
        expect(reopened.connectionType, PrinterConnectionType.ethernet);

        await repository.savePrinterSettings(
          deviceName: reopened.deviceName,
          deviceAddress: reopened.deviceAddress,
          paperWidth: reopened.paperWidth,
          connectionType: reopened.connectionType,
          ipAddress: reopened.ipAddress,
          port: reopened.port,
        );

        final PrinterSettingsModel? secondReopen = await repository
            .getActivePrinterSettings();
        expect(secondReopen, isNotNull);
        expect(secondReopen!.deviceName, 'Kitchen Restored');
        expect(secondReopen.connectionType, PrinterConnectionType.ethernet);
        expect(secondReopen.ipAddress, 'printer.local');
      },
    );

    test('ethernet host degisimi sonrasi roundtrip korunur', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      final SettingsRepository repository = SettingsRepository(database);
      await repository.savePrinterSettings(
        deviceName: 'Kitchen Ethernet',
        deviceAddress: 'printer-a.local',
        paperWidth: 80,
        connectionType: PrinterConnectionType.ethernet,
        ipAddress: 'printer-a.local',
        port: 9100,
      );

      final PrinterSettingsModel? beforeChange = await repository
          .getActivePrinterSettings();
      expect(beforeChange, isNotNull);

      await repository.savePrinterSettings(
        deviceName: beforeChange!.deviceName,
        deviceAddress: 'printer-b.local',
        paperWidth: beforeChange.paperWidth,
        connectionType: beforeChange.connectionType,
        ipAddress: 'printer-b.local',
        port: 9200,
      );

      final PrinterSettingsModel? afterChange = await repository
          .getActivePrinterSettings();
      expect(afterChange, isNotNull);
      expect(afterChange!.deviceName, 'Kitchen Ethernet');
      expect(afterChange.connectionType, PrinterConnectionType.ethernet);
      expect(afterChange.ipAddress, 'printer-b.local');
      expect(afterChange.port, 9200);

      await repository.savePrinterSettings(
        deviceName: afterChange.deviceName,
        deviceAddress: afterChange.deviceAddress,
        paperWidth: afterChange.paperWidth,
        connectionType: afterChange.connectionType,
        ipAddress: afterChange.ipAddress,
        port: afterChange.port,
      );

      final PrinterSettingsModel? reopened = await repository
          .getActivePrinterSettings();
      expect(reopened, isNotNull);
      expect(reopened!.ipAddress, 'printer-b.local');
      expect(reopened.port, 9200);
    });

    test(
      'bluetooth -> ethernet -> bluetooth gecislerinde persistence bozulmuyor',
      () async {
        final db.AppDatabase database = createTestDatabase();
        addTearDown(database.close);

        final SettingsRepository repository = SettingsRepository(database);
        await repository.savePrinterSettings(
          deviceName: 'Counter Printer',
          deviceAddress: 'AA:BB:CC:DD',
          paperWidth: 80,
          connectionType: PrinterConnectionType.bluetooth,
        );

        PrinterSettingsModel? printer = await repository
            .getActivePrinterSettings();
        expect(printer, isNotNull);
        expect(printer!.connectionType, PrinterConnectionType.bluetooth);
        expect(printer.deviceAddress, 'AA:BB:CC:DD');

        await repository.savePrinterSettings(
          deviceName: 'Kitchen Ethernet',
          deviceAddress: 'printer.local',
          paperWidth: 80,
          connectionType: PrinterConnectionType.ethernet,
          ipAddress: 'printer.local',
          port: 9100,
        );

        printer = await repository.getActivePrinterSettings();
        expect(printer, isNotNull);
        expect(printer!.connectionType, PrinterConnectionType.ethernet);
        expect(printer.ipAddress, 'printer.local');

        await repository.savePrinterSettings(
          deviceName: 'Counter Printer Restored',
          deviceAddress: '11:22:33:44',
          paperWidth: 58,
          connectionType: PrinterConnectionType.bluetooth,
        );

        printer = await repository.getActivePrinterSettings();
        expect(printer, isNotNull);
        expect(printer!.deviceName, 'Counter Printer Restored');
        expect(printer.connectionType, PrinterConnectionType.bluetooth);
        expect(printer.deviceAddress, '11:22:33:44');
        expect(printer.port, isNull);
      },
    );

    test('fallback name yeniden save edilince stabil kaliyor', () async {
      final db.AppDatabase database = createTestDatabase();
      addTearDown(database.close);

      await _insertActivePrinterRow(
        database,
        deviceName: 'printercfg:v2:%7B%7D',
        deviceAddress: 'printer.local',
      );

      final SettingsRepository repository = SettingsRepository(database);
      final PrinterSettingsModel? firstRead = await repository
          .getActivePrinterSettings();
      expect(firstRead, isNotNull);
      expect(firstRead!.deviceName, 'Ethernet Printer (printer.local)');

      await repository.savePrinterSettings(
        deviceName: firstRead.deviceName,
        deviceAddress: firstRead.deviceAddress,
        paperWidth: firstRead.paperWidth,
        connectionType: firstRead.connectionType,
        ipAddress: firstRead.ipAddress,
        port: firstRead.port,
      );

      final PrinterSettingsModel? reopened = await repository
          .getActivePrinterSettings();
      expect(reopened, isNotNull);
      expect(reopened!.deviceName, 'Ethernet Printer (printer.local)');
      expect(reopened.connectionType, PrinterConnectionType.ethernet);
      expect(reopened.ipAddress, 'printer.local');
    });
  });
}

Future<QueryRow> _activePrinterRow(db.AppDatabase database) {
  return database.customSelect('''
    SELECT
      id,
      device_name,
      device_address,
      paper_width,
      is_active,
      connection_type,
      ip_address,
      port
    FROM printer_settings
    WHERE is_active = 1
    ORDER BY id DESC
    LIMIT 1
  ''').getSingle();
}

Future<void> _insertActivePrinterRow(
  db.AppDatabase database, {
  required String deviceName,
  required String deviceAddress,
  int paperWidth = 80,
}) {
  return database
      .into(database.printerSettings)
      .insert(
        db.PrinterSettingsCompanion.insert(
          deviceName: deviceName,
          deviceAddress: deviceAddress,
          paperWidth: Value<int>(paperWidth),
          isActive: const Value<bool>(true),
        ),
      );
}
