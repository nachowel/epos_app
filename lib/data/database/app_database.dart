import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/migration_log_entry.dart';

part 'app_database.g.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get pin => text().nullable()();

  TextColumn get password => text().nullable()();

  TextColumn get role => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (role IN ('admin','cashier'))",
  ];
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get imageUrl => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId =>
      integer().customConstraint('NOT NULL REFERENCES "categories" ("id")')();

  TextColumn get name => text()();

  IntColumn get priceMinor => integer()();

  TextColumn get imageUrl => text().nullable()();

  BoolColumn get hasModifiers => boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  BoolColumn get isVisibleOnPos =>
      boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>['CHECK (price_minor >= 0)'];
}

class ProductModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId =>
      integer().customConstraint('NOT NULL REFERENCES "products" ("id")')();

  TextColumn get name => text()();

  TextColumn get type => text()();

  IntColumn get extraPriceMinor => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (type IN ('included','extra'))",
    'CHECK (extra_price_minor >= 0)',
  ];
}

class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();

  @ReferenceName('openedShifts')
  IntColumn get openedBy =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();

  @ReferenceName('closedShifts')
  IntColumn get closedBy =>
      integer().nullable().customConstraint('REFERENCES "users" ("id")')();

  DateTimeColumn get closedAt => dateTime().nullable()();

  @ReferenceName('cashierPreviewedShifts')
  IntColumn get cashierPreviewedBy =>
      integer().nullable().customConstraint('REFERENCES "users" ("id")')();

  DateTimeColumn get cashierPreviewedAt => dateTime().nullable()();

  TextColumn get status => text().withDefault(const Constant('draft'))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (status IN ('open','closed'))",
  ];
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get shiftId =>
      integer().customConstraint('NOT NULL REFERENCES "shifts" ("id")')();

  @ReferenceName('createdTransactions')
  IntColumn get userId =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  IntColumn get tableNumber => integer().nullable()();

  TextColumn get status => text().withDefault(const Constant('open'))();

  IntColumn get subtotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get modifierTotalMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get paidAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get cancelledAt => dateTime().nullable()();

  @ReferenceName('cancelledTransactions')
  IntColumn get cancelledBy =>
      integer().nullable().customConstraint('REFERENCES "users" ("id")')();

  TextColumn get idempotencyKey => text().unique()();

  BoolColumn get kitchenPrinted =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get receiptPrinted =>
      boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (status IN ('draft','sent','paid','cancelled'))",
    'CHECK (subtotal_minor >= 0)',
    'CHECK (modifier_total_minor >= 0)',
    'CHECK (total_amount_minor >= 0)',
  ];
}

class TransactionLines extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionId =>
      integer().customConstraint('NOT NULL REFERENCES "transactions" ("id")')();

  IntColumn get productId =>
      integer().customConstraint('NOT NULL REFERENCES "products" ("id")')();

  TextColumn get productName => text()();

  IntColumn get unitPriceMinor => integer()();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  IntColumn get lineTotalMinor => integer()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (unit_price_minor >= 0)',
    'CHECK (quantity > 0)',
    'CHECK (line_total_minor >= 0)',
  ];
}

class OrderModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionLineId => integer().customConstraint(
    'NOT NULL REFERENCES "transaction_lines" ("id")',
  )();

  TextColumn get action => text()();

  TextColumn get itemName => text()();

  IntColumn get extraPriceMinor => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (\"action\" IN ('remove','add'))",
    'CHECK (extra_price_minor >= 0)',
  ];
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionId => integer().customConstraint(
    'UNIQUE NOT NULL REFERENCES "transactions" ("id")',
  )();

  TextColumn get method => text()();

  IntColumn get amountMinor => integer()();

  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (method IN ('cash','card'))",
    'CHECK (amount_minor > 0)',
  ];
}

class PaymentAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get paymentId => integer().customConstraint(
    'UNIQUE NOT NULL REFERENCES "payments" ("id")',
  )();

  IntColumn get transactionId =>
      integer().customConstraint('NOT NULL REFERENCES "transactions" ("id")')();

  TextColumn get type => text().withDefault(const Constant('refund'))();

  TextColumn get status => text().withDefault(const Constant('completed'))();

  IntColumn get amountMinor => integer()();

  TextColumn get reason => text()();

  IntColumn get createdBy =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (type IN ('refund','reversal'))",
    "CHECK (status IN ('completed'))",
    'CHECK (amount_minor > 0)',
  ];
}

class ShiftReconciliations extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get shiftId =>
      integer().customConstraint('NOT NULL REFERENCES "shifts" ("id")')();

  TextColumn get kind => text().withDefault(const Constant('final_close'))();

  IntColumn get expectedCashMinor => integer()();

  IntColumn get countedCashMinor => integer()();

  IntColumn get varianceMinor => integer()();

  TextColumn get countedCashSource =>
      text().withDefault(const Constant('entered'))();

  IntColumn get countedBy =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  DateTimeColumn get countedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (kind IN ('final_close'))",
    "CHECK (counted_cash_source IN ('entered','compatibility_fallback'))",
    'CHECK (expected_cash_minor >= 0)',
    'CHECK (counted_cash_minor >= 0)',
    'UNIQUE(shift_id, kind)',
  ];
}

class CashMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get shiftId =>
      integer().customConstraint('NOT NULL REFERENCES "shifts" ("id")')();

  TextColumn get type => text()();

  TextColumn get category => text()();

  IntColumn get amountMinor => integer()();

  TextColumn get paymentMethod => text()();

  TextColumn get note => text().nullable()();

  IntColumn get createdByUserId =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (type IN ('income','expense'))",
    'CHECK (length(trim(category)) > 0)',
    'CHECK (amount_minor > 0)',
    "CHECK (payment_method IN ('cash','card','other'))",
  ];
}

class AuditLogs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get actorUserId =>
      integer().customConstraint('NOT NULL REFERENCES "users" ("id")')();

  TextColumn get action => text()();

  TextColumn get entityType => text()();

  TextColumn get entityId => text()();

  TextColumn get metadataJson => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (length(trim("action")) > 0)',
    'CHECK (length(trim(entity_type)) > 0)',
    'CHECK (length(trim(entity_id)) > 0)',
  ];
}

class PrintJobs extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get transactionId =>
      integer().customConstraint('NOT NULL REFERENCES "transactions" ("id")')();

  TextColumn get target => text()();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  DateTimeColumn get completedAt => dateTime().nullable()();

  TextColumn get lastError => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (target IN ('kitchen','receipt'))",
    "CHECK (status IN ('pending','printing','printed','failed'))",
    'UNIQUE(transaction_id, target)',
  ];
}

class ReportSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get cashierReportMode =>
      text().withDefault(const Constant('percentage'))();

  RealColumn get visibilityRatio => real().withDefault(const Constant(1.0))();

  IntColumn get maxVisibleTotalMinor => integer().nullable()();

  TextColumn get businessName => text().nullable()();

  TextColumn get businessAddress => text().nullable()();

  IntColumn get updatedBy =>
      integer().nullable().customConstraint('REFERENCES "users" ("id")')();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (cashier_report_mode IN ('percentage','cap_amount'))",
    'CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0)',
    'CHECK (max_visible_total_minor IS NULL OR max_visible_total_minor >= 0)',
  ];
}

class PrinterSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get deviceName => text()();

  TextColumn get deviceAddress => text()();

  IntColumn get paperWidth => integer().withDefault(const Constant(80))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (paper_width IN (58,80))',
  ];
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get queueTableName => text().named('table_name')();

  TextColumn get recordUuid => text()();

  TextColumn get operation => text().withDefault(const Constant('upsert'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  DateTimeColumn get syncedAt => dateTime().nullable()();

  TextColumn get errorMessage => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments'))",
    "CHECK (operation IN ('upsert'))",
    "CHECK (status IN ('pending','processing','synced','failed'))",
  ];
}

@DriftDatabase(
  tables: <Type>[
    Users,
    Categories,
    Products,
    ProductModifiers,
    Shifts,
    Transactions,
    TransactionLines,
    OrderModifiers,
    Payments,
    PaymentAdjustments,
    ShiftReconciliations,
    CashMovements,
    AuditLogs,
    PrintJobs,
    ReportSettings,
    PrinterSettings,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// Opens a database from an existing file (e.g. for backup verification).
  factory AppDatabase.forFile(File file) {
    return AppDatabase(NativeDatabase(file));
  }

  static const int currentSchemaVersion = 15;
  final List<MigrationLogEntry> _migrationHistory = <MigrationLogEntry>[];
  MigrationLogEntry? _lastMigrationFailure;

  List<MigrationLogEntry> get migrationHistory =>
      List<MigrationLogEntry>.unmodifiable(_migrationHistory);

  MigrationLogEntry? get lastMigrationFailure => _lastMigrationFailure;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await _runMigrationStep(
        step: 'create_schema',
        fromVersion: 0,
        toVersion: schemaVersion,
        action: () async {
          try {
            await m.createAll();
          } on Object {
            // Drift's generated CREATE TABLE statements with inline REFERENCES
            // are not reliable on every SQLite runtime we support. Fall back to
            // the explicit bootstrap SQL and trigger-backed FK enforcement so
            // fresh databases remain usable and consistent with upgraded ones.
            await _createBaseTables();
            await _createFreshPathFkEmulation();
          }
          await _createIndexes();
        },
      );
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await _runMigrationStep(
          step: 'migrate_v2',
          fromVersion: from,
          toVersion: 2,
          action: _migrateToV2,
        );
      }
      if (from < 3) {
        await _runMigrationStep(
          step: 'migrate_v3',
          fromVersion: from < 2 ? 2 : from,
          toVersion: 3,
          action: _migrateToV3,
        );
      }
      if (from < 4) {
        await _runMigrationStep(
          step: 'migrate_v4',
          fromVersion: from < 3 ? 3 : from,
          toVersion: 4,
          action: _migrateToV4,
        );
      }
      if (from < 5) {
        await _runMigrationStep(
          step: 'migrate_v5',
          fromVersion: from < 4 ? 4 : from,
          toVersion: 5,
          action: _migrateToV5,
        );
      }
      if (from < 6) {
        await _runMigrationStep(
          step: 'migrate_v6',
          fromVersion: from < 5 ? 5 : from,
          toVersion: 6,
          action: () => _migrateToV6(m),
        );
      }
      if (from < 7) {
        await _runMigrationStep(
          step: 'migrate_v7',
          fromVersion: from < 6 ? 6 : from,
          toVersion: 7,
          action: _migrateToV7,
        );
      }
      if (from < 8) {
        await _runMigrationStep(
          step: 'migrate_v8',
          fromVersion: from < 7 ? 7 : from,
          toVersion: 8,
          action: _migrateToV8,
        );
      }
      if (from < 9) {
        await _runMigrationStep(
          step: 'migrate_v9',
          fromVersion: from < 8 ? 8 : from,
          toVersion: 9,
          action: _migrateToV9,
        );
      }
      if (from < 10) {
        await _runMigrationStep(
          step: 'migrate_v10',
          fromVersion: from < 9 ? 9 : from,
          toVersion: 10,
          action: _migrateToV10,
        );
      }
      if (from < 11) {
        await _runMigrationStep(
          step: 'migrate_v11',
          fromVersion: from < 10 ? 10 : from,
          toVersion: 11,
          action: _migrateToV11,
        );
      }
      if (from < 12) {
        await _runMigrationStep(
          step: 'migrate_v12',
          fromVersion: from < 11 ? 11 : from,
          toVersion: 12,
          action: _migrateToV12,
        );
      }
      if (from < 13) {
        await _runMigrationStep(
          step: 'migrate_v13',
          fromVersion: from < 12 ? 12 : from,
          toVersion: 13,
          action: _migrateToV13,
        );
      }
      if (from < 14) {
        await _runMigrationStep(
          step: 'migrate_v14',
          fromVersion: from < 13 ? 13 : from,
          toVersion: 14,
          action: _migrateToV14,
        );
      }
      if (from < 15) {
        await _runMigrationStep(
          step: 'migrate_v15',
          fromVersion: from < 14 ? 14 : from,
          toVersion: 15,
          action: _migrateToV15,
        );
      }
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      _migrationHistory.add(
        MigrationLogEntry(
          timestamp: DateTime.now().toUtc(),
          step: 'database_open',
          fromVersion: details.wasCreated
              ? 0
              : details.versionBefore ?? details.versionNow,
          toVersion: details.versionNow,
          status: MigrationLogStatus.succeeded,
          message: details.hadUpgrade
              ? 'Database opened after upgrade.'
              : 'Database opened.',
        ),
      );
    },
  );

  Future<void> _createBaseTables() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pin TEXT NULL,
        password TEXT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        image_url TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
        image_url TEXT NULL,
        has_modifiers INTEGER NOT NULL DEFAULT 0 CHECK (has_modifiers IN (0, 1)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        is_visible_on_pos INTEGER NOT NULL DEFAULT 1 CHECK (is_visible_on_pos IN (0, 1)),
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS product_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('included','extra')),
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        opened_by INTEGER NOT NULL,
        opened_at INTEGER NOT NULL DEFAULT (unixepoch()),
        closed_by INTEGER NULL,
        closed_at INTEGER NULL,
        cashier_previewed_at INTEGER NULL,
        cashier_previewed_by INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        table_number INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
        subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
        modifier_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (modifier_total_minor >= 0),
        total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        paid_at INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        cancelled_at INTEGER NULL,
        cancelled_by INTEGER NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
        receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS transaction_lines (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS order_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_line_id INTEGER NOT NULL,
        action TEXT NOT NULL CHECK (action IN ('remove','add')),
        item_name TEXT NOT NULL,
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL UNIQUE,
        method TEXT NOT NULL CHECK (method IN ('cash','card')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        paid_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS payment_adjustments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        payment_id INTEGER NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'refund' CHECK (type IN ('refund','reversal')),
        status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        reason TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS shift_reconciliations (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        kind TEXT NOT NULL DEFAULT 'final_close' CHECK (kind IN ('final_close')),
        expected_cash_minor INTEGER NOT NULL CHECK (expected_cash_minor >= 0),
        counted_cash_minor INTEGER NOT NULL CHECK (counted_cash_minor >= 0),
        variance_minor INTEGER NOT NULL,
        counted_cash_source TEXT NOT NULL DEFAULT 'entered' CHECK (counted_cash_source IN ('entered','compatibility_fallback')),
        counted_by INTEGER NOT NULL,
        counted_at INTEGER NOT NULL DEFAULT (unixepoch()),
        UNIQUE(shift_id, kind)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cash_movements (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income','expense')),
        category TEXT NOT NULL CHECK (length(trim(category)) > 0),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        payment_method TEXT NOT NULL CHECK (payment_method IN ('cash','card','other')),
        note TEXT NULL,
        created_by_user_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        actor_user_id INTEGER NOT NULL,
        action TEXT NOT NULL CHECK (length(trim(action)) > 0),
        entity_type TEXT NOT NULL CHECK (length(trim(entity_type)) > 0),
        entity_id TEXT NOT NULL CHECK (length(trim(entity_id)) > 0),
        metadata_json TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS print_jobs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        target TEXT NOT NULL CHECK (target IN ('kitchen','receipt')),
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','printing','printed','failed')),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at INTEGER NULL,
        completed_at INTEGER NULL,
        last_error TEXT NULL,
        UNIQUE(transaction_id, target)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS report_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        cashier_report_mode TEXT NOT NULL DEFAULT 'percentage' CHECK (cashier_report_mode IN ('percentage','cap_amount')),
        visibility_ratio REAL NOT NULL DEFAULT 1.0 CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0),
        max_visible_total_minor INTEGER NULL CHECK (max_visible_total_minor IS NULL OR max_visible_total_minor >= 0),
        business_name TEXT NULL,
        business_address TEXT NULL,
        updated_by INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS printer_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        device_name TEXT NOT NULL,
        device_address TEXT NOT NULL,
        paper_width INTEGER NOT NULL DEFAULT 80 CHECK (paper_width IN (58,80)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments')),
        record_uuid TEXT NOT NULL,
        operation TEXT NOT NULL DEFAULT 'upsert' CHECK (operation IN ('upsert')),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','synced','failed')),
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at INTEGER NULL,
        synced_at INTEGER NULL,
        error_message TEXT NULL
      );
    ''');
    await _createSyncRootSnapshotTable();
  }

  Future<void> _createFreshPathFkEmulation() async {
    await _createMigrationFkTrigger(
      table: 'products',
      column: 'category_id',
      referencedTable: 'categories',
    );
    await _createMigrationFkTrigger(
      table: 'product_modifiers',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'shifts',
      column: 'opened_by',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'shifts',
      column: 'closed_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'shifts',
      column: 'cashier_previewed_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'transactions',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createMigrationFkTrigger(
      table: 'transactions',
      column: 'user_id',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'transactions',
      column: 'cancelled_by',
      referencedTable: 'users',
      nullable: true,
    );
    await _createMigrationFkTrigger(
      table: 'transaction_lines',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createMigrationFkTrigger(
      table: 'transaction_lines',
      column: 'product_id',
      referencedTable: 'products',
    );
    await _createMigrationFkTrigger(
      table: 'order_modifiers',
      column: 'transaction_line_id',
      referencedTable: 'transaction_lines',
    );
    await _createMigrationFkTrigger(
      table: 'payments',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createMigrationFkTrigger(
      table: 'payment_adjustments',
      column: 'payment_id',
      referencedTable: 'payments',
    );
    await _createMigrationFkTrigger(
      table: 'payment_adjustments',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createMigrationFkTrigger(
      table: 'payment_adjustments',
      column: 'created_by',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'shift_reconciliations',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createMigrationFkTrigger(
      table: 'shift_reconciliations',
      column: 'counted_by',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'cash_movements',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createMigrationFkTrigger(
      table: 'cash_movements',
      column: 'created_by_user_id',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'audit_logs',
      column: 'actor_user_id',
      referencedTable: 'users',
    );
    await _createMigrationFkTrigger(
      table: 'print_jobs',
      column: 'transaction_id',
      referencedTable: 'transactions',
    );
    await _createMigrationFkTrigger(
      table: 'report_settings',
      column: 'updated_by',
      referencedTable: 'users',
      nullable: true,
    );
  }

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id, is_active, is_visible_on_pos, sort_order);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_product_modifiers_prod ON product_modifiers(product_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_shift ON transactions(shift_id, status, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transaction_lines_tx ON transaction_lines(transaction_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_order_modifiers_line ON order_modifiers(transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payments_tx ON payments(transaction_id);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_payment_adjustments_unique_payment ON payment_adjustments(payment_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payment_adjustments_transaction ON payment_adjustments(transaction_id, created_at);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_shift_reconciliations_shift_kind ON shift_reconciliations(shift_id, kind);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shift_reconciliations_counted_at ON shift_reconciliations(counted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_shift ON cash_movements(shift_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_actor ON cash_movements(created_by_user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_print_jobs_status ON print_jobs(status, updated_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shifts_status ON shifts(status, opened_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_root_graph_snapshots_tx_uuid ON sync_queue_root_graph_snapshots(transaction_uuid, queue_id);',
    );
    // SQLite partial unique index destegi oldugu icin tek-acik-shift kurali DB seviyesinde enforce edilir.
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_shifts_single_open ON shifts(status) WHERE status = 'open';",
    );
  }

  Future<void> _migrateToV2() async {
    await customStatement('PRAGMA foreign_keys = OFF;');

    try {
      await customStatement(
        'ALTER TABLE shifts ADD COLUMN cashier_previewed_by INTEGER NULL;',
      );
      await customStatement(
        'ALTER TABLE shifts ADD COLUMN cashier_previewed_at INTEGER NULL;',
      );

      await customStatement('''
        CREATE TABLE users_v2 (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NULL,
          password TEXT NULL,
          role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');

      await customStatement('''
        INSERT INTO users_v2 (id, name, pin, password, role, is_active, created_at)
        SELECT
          id,
          name,
          pin,
          password,
          CASE
            WHEN role = 'staff' THEN 'cashier'
            ELSE role
          END,
          is_active,
          created_at
        FROM users;
      ''');

      await customStatement('DROP TABLE users;');
      await customStatement('ALTER TABLE users_v2 RENAME TO users;');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV3() async {
    // Reserved migration slot from an abandoned role-naming revision.
    // Intentionally left as a no-op so upgrades do not reintroduce `staff`.
  }

  Future<void> _migrateToV4() async {
    await customStatement('PRAGMA foreign_keys = OFF;');

    try {
      await customStatement('''
        CREATE TABLE users_v4 (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NULL,
          password TEXT NULL,
          role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');

      await customStatement('''
        INSERT INTO users_v4 (id, name, pin, password, role, is_active, created_at)
        SELECT
          id,
          name,
          pin,
          password,
          CASE
            WHEN role = 'staff' THEN 'cashier'
            ELSE role
          END,
          is_active,
          created_at
        FROM users;
      ''');

      await customStatement('DROP TABLE users;');
      await customStatement('ALTER TABLE users_v4 RENAME TO users;');
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV5() async {
    await customStatement('PRAGMA foreign_keys = OFF;');

    try {
      await customStatement('DROP INDEX IF EXISTS idx_transactions_shift;');
      await customStatement('DROP INDEX IF EXISTS idx_transactions_user;');

      await customStatement('''
        CREATE TABLE transactions_v5 (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          shift_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          table_number INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
          subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
          modifier_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (modifier_total_minor >= 0),
          total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
          created_at INTEGER NOT NULL DEFAULT (unixepoch()),
          paid_at INTEGER NULL,
          updated_at INTEGER NOT NULL,
          cancelled_at INTEGER NULL,
          cancelled_by INTEGER NULL,
          idempotency_key TEXT NOT NULL UNIQUE,
          kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
          receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
        );
      ''');

      await customStatement('''
        INSERT INTO transactions_v5 (
          id,
          uuid,
          shift_id,
          user_id,
          table_number,
          status,
          subtotal_minor,
          modifier_total_minor,
          total_amount_minor,
          created_at,
          paid_at,
          updated_at,
          cancelled_at,
          cancelled_by,
          idempotency_key,
          kitchen_printed,
          receipt_printed
        )
        SELECT
          id,
          uuid,
          shift_id,
          user_id,
          table_number,
          CASE
            WHEN status = 'open' THEN 'sent'
            ELSE status
          END,
          subtotal_minor,
          modifier_total_minor,
          total_amount_minor,
          created_at,
          paid_at,
          updated_at,
          cancelled_at,
          cancelled_by,
          idempotency_key,
          kitchen_printed,
          receipt_printed
        FROM transactions;
      ''');

      await customStatement('DROP TABLE transactions;');
      await customStatement(
        'ALTER TABLE transactions_v5 RENAME TO transactions;',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_shift ON transactions(shift_id, status, created_at);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id, created_at);',
      );
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV6(Migrator _) async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS print_jobs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        target TEXT NOT NULL CHECK (target IN ('kitchen','receipt')),
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','printing','printed','failed')),
        created_at INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL DEFAULT 0,
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at INTEGER NULL,
        completed_at INTEGER NULL,
        last_error TEXT NULL,
        UNIQUE(transaction_id, target)
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_print_jobs_status ON print_jobs(status, updated_at);',
    );

    await customStatement('''
      INSERT OR IGNORE INTO print_jobs (
        transaction_id,
        target,
        status,
        created_at,
        updated_at,
        completed_at
      )
      SELECT
        id,
        'kitchen',
        CASE
          WHEN kitchen_printed = 1 THEN 'printed'
          ELSE 'pending'
        END,
        updated_at,
        updated_at,
        CASE
          WHEN kitchen_printed = 1 THEN updated_at
          ELSE NULL
        END
      FROM transactions
      WHERE status IN ('sent', 'paid') OR kitchen_printed = 1;
    ''');

    await customStatement('''
      INSERT OR IGNORE INTO print_jobs (
        transaction_id,
        target,
        status,
        created_at,
        updated_at,
        completed_at
      )
      SELECT
        id,
        'receipt',
        CASE
          WHEN receipt_printed = 1 THEN 'printed'
          ELSE 'pending'
        END,
        COALESCE(paid_at, updated_at),
        COALESCE(paid_at, updated_at),
        CASE
          WHEN receipt_printed = 1 THEN COALESCE(paid_at, updated_at)
          ELSE NULL
        END
      FROM transactions
      WHERE status = 'paid';
    ''');
  }

  Future<void> _migrateToV7() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS payment_adjustments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        payment_id INTEGER NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'refund' CHECK (type IN ('refund','reversal')),
        status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN ('completed')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        reason TEXT NOT NULL,
        created_by INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS shift_reconciliations (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        kind TEXT NOT NULL DEFAULT 'final_close' CHECK (kind IN ('final_close')),
        expected_cash_minor INTEGER NOT NULL CHECK (expected_cash_minor >= 0),
        counted_cash_minor INTEGER NOT NULL CHECK (counted_cash_minor >= 0),
        variance_minor INTEGER NOT NULL,
        counted_by INTEGER NOT NULL,
        counted_at INTEGER NOT NULL DEFAULT (unixepoch()),
        UNIQUE(shift_id, kind)
      );
    ''');
    await customStatement('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        actor_id INTEGER NOT NULL,
        action_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        metadata_json TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_payment_adjustments_unique_payment ON payment_adjustments(payment_id);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_payment_adjustments_transaction ON payment_adjustments(transaction_id, created_at);',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_shift_reconciliations_shift_kind ON shift_reconciliations(shift_id, kind);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_shift_reconciliations_counted_at ON shift_reconciliations(counted_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);',
    );
  }

  Future<void> _migrateToV8() async {
    await customStatement('''
      ALTER TABLE shift_reconciliations
      ADD COLUMN counted_cash_source TEXT NOT NULL DEFAULT 'compatibility_fallback'
      CHECK (counted_cash_source IN ('entered','compatibility_fallback'));
    ''');
  }

  Future<void> _migrateToV9() async {
    await customStatement('''
      ALTER TABLE products
      ADD COLUMN is_visible_on_pos INTEGER NOT NULL DEFAULT 1
      CHECK (is_visible_on_pos IN (0, 1));
    ''');
    await customStatement('DROP INDEX IF EXISTS idx_products_category;');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id, is_active, is_visible_on_pos, sort_order);',
    );
  }

  Future<void> _migrateToV10() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS cash_movements (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('income','expense')),
        category TEXT NOT NULL CHECK (length(trim(category)) > 0),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        payment_method TEXT NOT NULL CHECK (payment_method IN ('cash','card','other')),
        note TEXT NULL,
        created_by_user_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_shift ON cash_movements(shift_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_actor ON cash_movements(created_by_user_id, created_at);',
    );
  }

  Future<void> _migrateToV11() async {
    final QueryRow legacyAuditRow = await customSelect(
      'SELECT COUNT(*) AS row_count FROM audit_logs WHERE actor_id IS NULL;',
    ).getSingle();
    final int legacyRowsWithoutActor = legacyAuditRow.read<int>('row_count');
    if (legacyRowsWithoutActor > 0) {
      throw DatabaseException(
        'Legacy audit_logs rows without actor_id cannot be migrated to schema v11.',
      );
    }

    await customStatement('PRAGMA foreign_keys = OFF;');
    try {
      await customStatement('DROP INDEX IF EXISTS idx_audit_logs_created_at;');
      await customStatement('DROP INDEX IF EXISTS idx_audit_logs_entity;');
      await customStatement('DROP INDEX IF EXISTS idx_audit_logs_actor;');

      await customStatement(
        'ALTER TABLE audit_logs RENAME TO audit_logs_legacy_v11;',
      );
      // Drift table creation with a real FK on actor_user_id was not reliable
      // on this legacy upgrade path. v12 adds DB-level trigger enforcement for
      // migrated databases so the upgraded table has explicit FK-equivalent
      // protection even when SQLite rebuild syntax differs from fresh creation.
      await customStatement('''
        CREATE TABLE audit_logs (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          actor_user_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (length(trim("action")) > 0),
          entity_type TEXT NOT NULL CHECK (length(trim(entity_type)) > 0),
          entity_id TEXT NOT NULL CHECK (length(trim(entity_id)) > 0),
          metadata_json TEXT NOT NULL,
          created_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');

      await customStatement('''
        INSERT INTO audit_logs (
          id,
          "actor_user_id",
          "action",
          "entity_type",
          "entity_id",
          "metadata_json",
          "created_at"
        )
        SELECT
          id,
          actor_id,
          action_type,
          entity_type,
          entity_id,
          COALESCE(NULLIF(TRIM(metadata_json), ''), '{}'),
          created_at
        FROM audit_logs_legacy_v11;
      ''');

      await customStatement('DROP TABLE audit_logs_legacy_v11;');
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id, created_at);',
      );
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV12() async {
    // Fresh databases already get canonical FK constraints from Drift table
    // definitions. On legacy upgrade paths, rebuilding these tables with inline
    // REFERENCES clauses was not reliable on the SQLite migration path used by
    // this project. v12 therefore makes the mismatch explicit and installs
    // trigger-based FK enforcement for upgraded databases.
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_shift ON cash_movements(shift_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cash_movements_actor ON cash_movements(created_by_user_id, created_at);',
    );
    await _createMigrationFkTrigger(
      table: 'cash_movements',
      column: 'shift_id',
      referencedTable: 'shifts',
    );
    await _createMigrationFkTrigger(
      table: 'cash_movements',
      column: 'created_by_user_id',
      referencedTable: 'users',
    );

    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_user_id, created_at);',
    );
    await _createMigrationFkTrigger(
      table: 'audit_logs',
      column: 'actor_user_id',
      referencedTable: 'users',
    );
  }

  Future<void> _migrateToV13() async {
    await customStatement('PRAGMA foreign_keys = OFF;');
    try {
      await customStatement(
        'DROP TRIGGER IF EXISTS fk_report_settings_updated_by_insert;',
      );
      await customStatement(
        'DROP TRIGGER IF EXISTS fk_report_settings_updated_by_update;',
      );
      await customStatement(
        'ALTER TABLE report_settings RENAME TO report_settings_legacy_v13;',
      );
      await customStatement('''
        CREATE TABLE report_settings (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          cashier_report_mode TEXT NOT NULL DEFAULT 'percentage'
            CHECK (cashier_report_mode IN ('percentage','cap_amount')),
          visibility_ratio REAL NOT NULL DEFAULT 1.0
            CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0),
          max_visible_total_minor INTEGER NULL
            CHECK (max_visible_total_minor IS NULL OR max_visible_total_minor >= 0),
          updated_by INTEGER NULL,
          updated_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');

      await customStatement('''
        INSERT INTO report_settings (
          id,
          cashier_report_mode,
          visibility_ratio,
          max_visible_total_minor,
          updated_by,
          updated_at
        )
        SELECT
          id,
          'percentage',
          visibility_ratio,
          NULL,
          updated_by,
          updated_at
        FROM report_settings_legacy_v13;
      ''');

      await customStatement('DROP TABLE report_settings_legacy_v13;');
      await _createMigrationFkTrigger(
        table: 'report_settings',
        column: 'updated_by',
        referencedTable: 'users',
        nullable: true,
      );
    } finally {
      await customStatement('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _migrateToV14() async {
    await customStatement(
      'ALTER TABLE report_settings ADD COLUMN business_name TEXT NULL;',
    );
    await customStatement(
      'ALTER TABLE report_settings ADD COLUMN business_address TEXT NULL;',
    );
  }

  Future<void> _migrateToV15() async {
    await _createSyncRootSnapshotTable();
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_queue_root_graph_snapshots_tx_uuid ON sync_queue_root_graph_snapshots(transaction_uuid, queue_id);',
    );
  }

  Future<void> _createSyncRootSnapshotTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS sync_queue_root_graph_snapshots (
        queue_id INTEGER NOT NULL PRIMARY KEY,
        transaction_uuid TEXT NOT NULL,
        graph_checksum TEXT NOT NULL,
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
  }

  Future<void> _createMigrationFkTrigger({
    required String table,
    required String column,
    required String referencedTable,
    bool nullable = false,
  }) async {
    final String condition =
        '${nullable ? 'NEW.$column IS NOT NULL AND ' : ''}'
        '(SELECT id FROM $referencedTable WHERE id = NEW.$column) IS NULL';
    final String message = 'fk_$table.$column->$referencedTable.id';

    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS fk_${table}_${column}_insert
      BEFORE INSERT ON $table
      FOR EACH ROW
      WHEN $condition
      BEGIN
        SELECT RAISE(ABORT, '$message');
      END;
    ''');
    await customStatement('''
      CREATE TRIGGER IF NOT EXISTS fk_${table}_${column}_update
      BEFORE UPDATE OF $column ON $table
      FOR EACH ROW
      WHEN $condition
      BEGIN
        SELECT RAISE(ABORT, '$message');
      END;
    ''');
  }

  Future<void> _runMigrationStep({
    required String step,
    required int fromVersion,
    required int toVersion,
    required Future<void> Function() action,
  }) async {
    _migrationHistory.add(
      MigrationLogEntry(
        timestamp: DateTime.now().toUtc(),
        step: step,
        fromVersion: fromVersion,
        toVersion: toVersion,
        status: MigrationLogStatus.started,
        message: null,
      ),
    );

    try {
      await action();
      _migrationHistory.add(
        MigrationLogEntry(
          timestamp: DateTime.now().toUtc(),
          step: step,
          fromVersion: fromVersion,
          toVersion: toVersion,
          status: MigrationLogStatus.succeeded,
          message: null,
        ),
      );
    } catch (error) {
      final MigrationLogEntry failure = MigrationLogEntry(
        timestamp: DateTime.now().toUtc(),
        step: step,
        fromVersion: fromVersion,
        toVersion: toVersion,
        status: MigrationLogStatus.failed,
        message: error.toString(),
      );
      _migrationHistory.add(failure);
      _lastMigrationFailure = failure;
      rethrow;
    }
  }

  static Future<File> resolveDefaultDatabaseFile() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final File databaseFile = File(
      p.join(documentsDirectory.path, 'epos.sqlite'),
    );
    debugPrint('[AppDatabase] Resolved SQLite path: ${databaseFile.path}');
    return databaseFile;
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final File databaseFile = await AppDatabase.resolveDefaultDatabaseFile();

    return NativeDatabase.createInBackground(databaseFile);
  });
}
