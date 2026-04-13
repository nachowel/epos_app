import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/domain/models/printer_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Migration v31 -> current printer persistence', () {
    test(
      'adds first-class transport columns and backfills legacy printer rows deterministically',
      () async {
        final AppDatabase db = _createV31ThenMigrateToCurrent();
        addTearDown(db.close);

        final List<dynamic> rows = await db.customSelect('''
          SELECT
            id,
            device_name,
            device_address,
            connection_type,
            ip_address,
            port
          FROM printer_settings
          ORDER BY id ASC
        ''').get();

        expect(rows, hasLength(4));

        expect(rows[0].read<String>('device_name'), 'Kitchen Ethernet');
        expect(rows[0].read<String>('device_address'), 'printer.local');
        expect(rows[0].read<String>('connection_type'), 'ethernet');
        expect(rows[0].read<String?>('ip_address'), 'printer.local');
        expect(rows[0].read<int?>('port'), 9100);

        expect(rows[1].read<String>('device_name'), 'Legacy Ethernet');
        expect(rows[1].read<String>('device_address'), '192.168.1.55');
        expect(rows[1].read<String>('connection_type'), 'ethernet');
        expect(rows[1].read<String?>('ip_address'), '192.168.1.55');
        expect(rows[1].read<int?>('port'), 9200);

        expect(rows[2].read<String>('device_name'), 'Counter Printer');
        expect(rows[2].read<String>('device_address'), 'AA:BB:CC:DD');
        expect(rows[2].read<String>('connection_type'), 'bluetooth');
        expect(rows[2].read<String?>('ip_address'), isNull);
        expect(rows[2].read<int?>('port'), isNull);

        expect(
          rows[3].read<String>('device_name'),
          'Ethernet Printer (printer-fallback.local)',
        );
        expect(
          rows[3].read<String>('device_address'),
          'printer-fallback.local',
        );
        expect(rows[3].read<String>('connection_type'), 'ethernet');
        expect(rows[3].read<String?>('ip_address'), 'printer-fallback.local');
        expect(
          rows[3].read<int?>('port'),
          PrinterSettingsModel.defaultEthernetPort,
        );
      },
    );

    test(
      'migrate -> reopen -> save -> reopen keeps first-class columns stable',
      () async {
        final _MigrationDbFixture fixture =
            await _createV31DatabaseFixture(<_LegacyPrinterSeed>[
              _LegacyPrinterSeed(
                deviceName: 'Legacy Ethernet',
                deviceAddress: 'ethernet|printer.local|9100',
              ),
            ]);
        addTearDown(fixture.dispose);

        final AppDatabase migratedDb = _openFileDatabase(fixture.path);
        final PrinterSettingsModel? migratedPrinter = await SettingsRepository(
          migratedDb,
        ).getActivePrinterSettings();
        expect(migratedPrinter, isNotNull);
        expect(migratedPrinter!.deviceName, 'Legacy Ethernet');
        expect(migratedPrinter.connectionType, PrinterConnectionType.ethernet);
        await migratedDb.close();

        final AppDatabase reopenBeforeSave = _openFileDatabase(fixture.path);
        final SettingsRepository repository = SettingsRepository(
          reopenBeforeSave,
        );
        final PrinterSettingsModel? reopenedPrinter = await repository
            .getActivePrinterSettings();
        expect(reopenedPrinter, isNotNull);
        await repository.savePrinterSettings(
          deviceName: 'Legacy Ethernet Saved',
          deviceAddress: reopenedPrinter!.deviceAddress,
          paperWidth: reopenedPrinter.paperWidth,
          connectionType: reopenedPrinter.connectionType,
          ipAddress: reopenedPrinter.ipAddress,
          port: reopenedPrinter.port,
        );
        await reopenBeforeSave.close();

        final AppDatabase reopenAfterSave = _openFileDatabase(fixture.path);
        addTearDown(reopenAfterSave.close);
        final dynamic row = await _activePrinterRow(reopenAfterSave);

        expect(row.read<String>('device_name'), 'Legacy Ethernet Saved');
        expect(row.read<String>('device_address'), 'printer.local');
        expect(row.read<String>('connection_type'), 'ethernet');
        expect(row.read<String?>('ip_address'), 'printer.local');
        expect(row.read<int?>('port'), 9100);
      },
    );

    test(
      'legacy ethernet -> migrate -> edit -> save keeps host and port',
      () async {
        final _MigrationDbFixture fixture =
            await _createV31DatabaseFixture(<_LegacyPrinterSeed>[
              _LegacyPrinterSeed(
                deviceName: 'Legacy Ethernet',
                deviceAddress: 'ethernet|192.168.1.55|9200',
              ),
            ]);
        addTearDown(fixture.dispose);

        final AppDatabase db = _openFileDatabase(fixture.path);
        addTearDown(db.close);
        final SettingsRepository repository = SettingsRepository(db);
        final PrinterSettingsModel? migrated = await repository
            .getActivePrinterSettings();
        expect(migrated, isNotNull);
        expect(migrated!.connectionType, PrinterConnectionType.ethernet);
        expect(migrated.ipAddress, '192.168.1.55');
        expect(migrated.port, 9200);

        await repository.savePrinterSettings(
          deviceName: 'Legacy Ethernet Updated',
          deviceAddress: migrated.deviceAddress,
          paperWidth: migrated.paperWidth,
          connectionType: migrated.connectionType,
          ipAddress: migrated.ipAddress,
          port: migrated.port,
        );

        final dynamic row = await _activePrinterRow(db);
        expect(row.read<String>('device_name'), 'Legacy Ethernet Updated');
        expect(row.read<String>('device_address'), '192.168.1.55');
        expect(row.read<String>('connection_type'), 'ethernet');
        expect(row.read<String?>('ip_address'), '192.168.1.55');
        expect(row.read<int?>('port'), 9200);
      },
    );

    test(
      'corrupted salvage -> migrate -> edit -> save keeps normalized transport',
      () async {
        final _MigrationDbFixture fixture =
            await _createV31DatabaseFixture(<_LegacyPrinterSeed>[
              _LegacyPrinterSeed(
                deviceName: 'printercfg:v2:%7Bbad-json',
                deviceAddress: 'printer-fallback.local',
              ),
            ]);
        addTearDown(fixture.dispose);

        final AppDatabase db = _openFileDatabase(fixture.path);
        addTearDown(db.close);
        final SettingsRepository repository = SettingsRepository(db);
        final PrinterSettingsModel? migrated = await repository
            .getActivePrinterSettings();
        expect(migrated, isNotNull);
        expect(
          migrated!.deviceName,
          'Ethernet Printer (printer-fallback.local)',
        );
        expect(migrated.connectionType, PrinterConnectionType.ethernet);
        expect(migrated.ipAddress, 'printer-fallback.local');
        expect(migrated.port, PrinterSettingsModel.defaultEthernetPort);

        await repository.savePrinterSettings(
          deviceName: 'Recovered Printer',
          deviceAddress: migrated.deviceAddress,
          paperWidth: migrated.paperWidth,
          connectionType: migrated.connectionType,
          ipAddress: migrated.ipAddress,
          port: migrated.port,
        );

        final dynamic row = await _activePrinterRow(db);
        expect(row.read<String>('device_name'), 'Recovered Printer');
        expect(row.read<String>('device_address'), 'printer-fallback.local');
        expect(row.read<String>('connection_type'), 'ethernet');
        expect(row.read<String?>('ip_address'), 'printer-fallback.local');
        expect(
          row.read<int?>('port'),
          PrinterSettingsModel.defaultEthernetPort,
        );
      },
    );
  });
}

AppDatabase _createV31ThenMigrateToCurrent() {
  final NativeDatabase rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
      database.execute('''
        CREATE TABLE printer_settings (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          device_name TEXT NOT NULL,
          device_address TEXT NOT NULL,
          paper_width INTEGER NOT NULL DEFAULT 80 CHECK (paper_width IN (58,80)),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');

      final PrinterSettingsModel validEnvelopePrinter = PrinterSettingsModel(
        id: 1,
        deviceName: 'Kitchen Ethernet',
        deviceAddress: 'printer.local',
        paperWidth: 80,
        isActive: true,
        connectionType: PrinterConnectionType.ethernet,
        ipAddress: 'printer.local',
        port: 9100,
      );

      database.execute('''
        INSERT INTO printer_settings (
          id,
          device_name,
          device_address,
          paper_width,
          is_active
        ) VALUES
          (
            1,
            '${_escapeSql(validEnvelopePrinter.storageDeviceName)}',
            'printer.local',
            80,
            1
          ),
          (
            2,
            'Legacy Ethernet',
            'ethernet|192.168.1.55|9200',
            80,
            1
          ),
          (
            3,
            'Counter Printer',
            'AA:BB:CC:DD',
            58,
            1
          ),
          (
            4,
            'printercfg:v2:%7Bbad-json',
            'printer-fallback.local',
            80,
            1
          )
      ''');
      database.execute('PRAGMA user_version = 31;');
    },
  );

  return AppDatabase(rawDb);
}

AppDatabase _openFileDatabase(String path) =>
    AppDatabase(NativeDatabase(File(path)));

Future<dynamic> _activePrinterRow(AppDatabase db) {
  return db.customSelect('''
    SELECT
      device_name,
      device_address,
      connection_type,
      ip_address,
      port
    FROM printer_settings
    WHERE is_active = 1
    ORDER BY id DESC
    LIMIT 1
  ''').getSingle();
}

Future<_MigrationDbFixture> _createV31DatabaseFixture(
  List<_LegacyPrinterSeed> rows,
) async {
  final Directory directory = await Directory.systemTemp.createTemp(
    'printer-migration-v31-',
  );
  final String path =
      '${directory.path}${Platform.pathSeparator}printer_migration.sqlite';
  final sqlite3.Database database = sqlite3.sqlite3.open(path);
  database.execute('PRAGMA foreign_keys = OFF;');
  database.execute('''
    CREATE TABLE printer_settings (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      device_name TEXT NOT NULL,
      device_address TEXT NOT NULL,
      paper_width INTEGER NOT NULL DEFAULT 80 CHECK (paper_width IN (58,80)),
      is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
    );
  ''');
  for (int index = 0; index < rows.length; index++) {
    final _LegacyPrinterSeed row = rows[index];
    database.execute('''
      INSERT INTO printer_settings (
        id,
        device_name,
        device_address,
        paper_width,
        is_active
      ) VALUES (
        ${index + 1},
        '${_escapeSql(row.deviceName)}',
        '${_escapeSql(row.deviceAddress)}',
        ${row.paperWidth},
        ${row.isActive ? 1 : 0}
      )
    ''');
  }
  database.execute('PRAGMA user_version = 31;');
  database.dispose();
  return _MigrationDbFixture(directory: directory, path: path);
}

String _escapeSql(String value) => value.replaceAll("'", "''");

class _LegacyPrinterSeed {
  const _LegacyPrinterSeed({
    required this.deviceName,
    required this.deviceAddress,
    this.paperWidth = 80,
    this.isActive = true,
  });

  final String deviceName;
  final String deviceAddress;
  final int paperWidth;
  final bool isActive;
}

class _MigrationDbFixture {
  const _MigrationDbFixture({required this.directory, required this.path});

  final Directory directory;
  final String path;

  Future<void> dispose() => directory.delete(recursive: true);
}
