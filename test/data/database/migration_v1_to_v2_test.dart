import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart' show AppDatabase;
import 'package:epos_app/data/repositories/payment_repository.dart';
import 'package:epos_app/data/repositories/print_job_repository.dart';
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/print_job.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

/// Simulates legacy v1 migration through the current schema.
/// 1. Creating the v1 schema + seed data in a raw SQLite database
/// 2. Opening it with AppDatabase (current schema version) which triggers onUpgrade
AppDatabase _createV1ThenMigrateToCurrent({double? reportVisibilityRatio}) {
  // Use a shared in-memory database so we can write raw SQL first,
  // then hand it to AppDatabase.
  final rawDb = NativeDatabase.memory(
    setup: (db) {
      db.execute('PRAGMA foreign_keys = ON;');
      // v1 schema: 'staff' role, no cashier_previewed_by/at columns.
      db.execute('''
      CREATE TABLE users (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pin TEXT NULL,
        password TEXT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin','staff')),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      );
    ''');
      db.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        image_url TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
      db.execute('''
      CREATE TABLE products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
        image_url TEXT NULL,
        has_modifiers INTEGER NOT NULL DEFAULT 0 CHECK (has_modifiers IN (0, 1)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
      db.execute('''
      CREATE TABLE product_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('included','extra')),
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
      // v1 shifts: no cashier_previewed_by, no cashier_previewed_at
      db.execute('''
      CREATE TABLE shifts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        opened_by INTEGER NOT NULL,
        opened_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        closed_by INTEGER NULL,
        closed_at INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
      );
    ''');
      db.execute('''
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        table_number INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','paid','cancelled')),
        subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
        modifier_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (modifier_total_minor >= 0),
        total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        paid_at INTEGER NULL,
        updated_at INTEGER NOT NULL,
        cancelled_at INTEGER NULL,
        cancelled_by INTEGER NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
        receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
      );
    ''');
      db.execute('''
      CREATE TABLE transaction_lines (
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
      db.execute('''
      CREATE TABLE order_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_line_id INTEGER NOT NULL,
        action TEXT NOT NULL CHECK (action IN ('remove','add')),
        item_name TEXT NOT NULL,
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0)
      );
    ''');
      db.execute('''
      CREATE TABLE payments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL UNIQUE,
        method TEXT NOT NULL CHECK (method IN ('cash','card')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        paid_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      );
    ''');
      db.execute('''
      CREATE TABLE report_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        visibility_ratio REAL NOT NULL DEFAULT 1.0 CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0),
        updated_by INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      );
    ''');
      if (reportVisibilityRatio != null) {
        db.execute(
          "INSERT INTO report_settings (visibility_ratio, updated_by) VALUES ($reportVisibilityRatio, 2);",
        );
      }
      db.execute('''
      CREATE TABLE printer_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        device_name TEXT NOT NULL,
        device_address TEXT NOT NULL,
        paper_width INTEGER NOT NULL DEFAULT 80 CHECK (paper_width IN (58,80)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
      db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments')),
        record_uuid TEXT NOT NULL,
        operation TEXT NOT NULL DEFAULT 'upsert' CHECK (operation IN ('upsert')),
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','synced','failed')),
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at INTEGER NULL,
        synced_at INTEGER NULL,
        error_message TEXT NULL
      );
    ''');
      db.execute(
        "CREATE UNIQUE INDEX ux_shifts_single_open ON shifts(status) WHERE status = 'open';",
      );

      // Seed v1 data with 'staff' role
      db.execute(
        "INSERT INTO users (name, pin, role) VALUES ('Legacy Staff', '1234', 'staff');",
      );
      db.execute(
        "INSERT INTO users (name, password, role) VALUES ('Admin', 'secret', 'admin');",
      );
      db.execute("INSERT INTO shifts (opened_by) VALUES (1);");
      final int unixNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      db.execute(
        "INSERT INTO transactions (uuid, shift_id, user_id, status, subtotal_minor, total_amount_minor, idempotency_key, updated_at) "
        "VALUES ('tx-v1', 1, 1, 'open', 500, 500, 'idem-v1', $unixNow);",
      );

      // Set the user_version to 1 so drift knows to run onUpgrade(1→current)
      db.execute('PRAGMA user_version = 1;');
    },
  );

  return AppDatabase(rawDb);
}

void main() {
  group('Migration v1 → current', () {
    test(
      'legacy staff role is normalized to cashier after migration',
      () async {
        final db = _createV1ThenMigrateToCurrent();
        addTearDown(db.close);

        final rows = await db
            .customSelect(
              'SELECT role FROM users WHERE name = ?',
              variables: [Variable<String>('Legacy Staff')],
            )
            .get();

        expect(rows, hasLength(1));
        expect(rows.first.read<String>('role'), 'cashier');
      },
    );

    test('admin role is preserved after migration', () async {
      final db = _createV1ThenMigrateToCurrent();
      addTearDown(db.close);

      final rows = await db
          .customSelect(
            'SELECT role FROM users WHERE name = ?',
            variables: [Variable<String>('Admin')],
          )
          .get();

      expect(rows, hasLength(1));
      expect(rows.first.read<String>('role'), 'admin');
    });

    test(
      'shifts table gains nullable cashier_previewed_by and cashier_previewed_at',
      () async {
        final db = _createV1ThenMigrateToCurrent();
        addTearDown(db.close);

        final ShiftRepository shiftRepo = ShiftRepository(db);
        final Shift? openShift = await shiftRepo.getOpenShift();

        expect(openShift, isNotNull);
        expect(openShift!.cashierPreviewedBy, isNull);
        expect(openShift.cashierPreviewedAt, isNull);
        expect(openShift.hasCashierPreview, isFalse);
      },
    );

    test(
      'old shift records can be read and preview can be marked post-migration',
      () async {
        final db = _createV1ThenMigrateToCurrent();
        addTearDown(db.close);

        final ShiftRepository shiftRepo = ShiftRepository(db);
        final Shift? openShift = await shiftRepo.getOpenShift();
        expect(openShift, isNotNull);

        final Shift previewed = await shiftRepo.markCashierPreview(
          shiftId: openShift!.id,
          userId: 1,
        );

        expect(previewed.hasCashierPreview, isTrue);
        expect(previewed.cashierPreviewedBy, 1);
        expect(previewed.cashierPreviewedAt, isNotNull);
      },
    );

    test(
      'legacy report_settings rows gain projection and business identity fields with safe defaults',
      () async {
        final db = _createV1ThenMigrateToCurrent(reportVisibilityRatio: 0.35);
        addTearDown(db.close);

        final row = await db.customSelect('''
            SELECT
              cashier_report_mode,
              visibility_ratio,
              max_visible_total_minor,
              business_name,
              business_address
            FROM report_settings
            ORDER BY id ASC
            LIMIT 1
          ''').getSingle();

        expect(row.read<String>('cashier_report_mode'), 'percentage');
        expect(row.read<double>('visibility_ratio'), 0.35);
        expect(row.read<int?>('max_visible_total_minor'), isNull);
        expect(row.read<String?>('business_name'), isNull);
        expect(row.read<String?>('business_address'), isNull);
      },
    );

    test(
      'fresh report_settings inserts receive projection and business identity defaults',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        await db.customStatement('INSERT INTO report_settings DEFAULT VALUES;');
        final row = await db.customSelect('''
            SELECT
              cashier_report_mode,
              visibility_ratio,
              max_visible_total_minor,
              business_name,
              business_address
            FROM report_settings
            ORDER BY id DESC
            LIMIT 1
          ''').getSingle();

        expect(row.read<String>('cashier_report_mode'), 'percentage');
        expect(row.read<double>('visibility_ratio'), 1.0);
        expect(row.read<int?>('max_visible_total_minor'), isNull);
        expect(row.read<String?>('business_name'), isNull);
        expect(row.read<String?>('business_address'), isNull);
      },
    );

    test('existing transactions survive migration and are readable', () async {
      final db = _createV1ThenMigrateToCurrent();
      addTearDown(db.close);

      final TransactionRepository txRepo = TransactionRepository(db);
      final Transaction? tx = await txRepo.getByUuid('tx-v1');

      expect(tx, isNotNull);
      expect(tx!.status, TransactionStatus.sent);
      expect(tx.totalAmountMinor, 500);
    });

    test('order creation flow works on post-migration database', () async {
      final db = _createV1ThenMigrateToCurrent();
      addTearDown(db.close);

      // Insert a product (required for addLine)
      await db.customStatement(
        "INSERT INTO categories (name) VALUES ('TestCat');",
      );
      await db.customStatement(
        "INSERT INTO products (category_id, name, price_minor) VALUES (1, 'Tea', 250);",
      );

      final TransactionRepository txRepo = TransactionRepository(db);

      final created = await txRepo.createTransaction(
        shiftId: 1,
        userId: 1,
        uuid: 'tx-post-migration',
        idempotencyKey: 'idem-post-migration',
      );
      await txRepo.addLine(
        transactionId: created.id,
        productId: 1,
        quantity: 2,
      );
      await txRepo.recalculateTotals(created.id);
      final refreshed = await txRepo.getById(created.id);

      expect(refreshed, isNotNull);
      expect(refreshed!.totalAmountMinor, 500);

      final lines = await txRepo.getLines(created.id);
      expect(lines, hasLength(1));
      expect(lines.first.lineTotalMinor, 500);
    });

    test(
      'fresh and migrated print_jobs schema expose the same critical columns and indexes',
      () async {
        final AppDatabase freshDb = createTestDatabase();
        final AppDatabase migratedDb = _createV1ThenMigrateToCurrent();
        addTearDown(freshDb.close);
        addTearDown(migratedDb.close);
        final List<String> freshColumns = await _readTableColumns(
          freshDb,
          'print_jobs',
        );
        final List<String> migratedColumns = await _readTableColumns(
          migratedDb,
          'print_jobs',
        );
        final Map<String, ({bool unique, List<String> columns})> freshIndexes =
            await _readIndexColumns(freshDb, 'print_jobs');
        final Map<String, ({bool unique, List<String> columns})>
        migratedIndexes = await _readIndexColumns(migratedDb, 'print_jobs');

        expect(freshColumns, migratedColumns);
        expect(freshIndexes.keys.toSet(), migratedIndexes.keys.toSet());
        for (final String indexName in freshIndexes.keys) {
          expect(
            freshIndexes[indexName]!.unique,
            migratedIndexes[indexName]!.unique,
          );
          expect(
            freshIndexes[indexName]!.columns,
            migratedIndexes[indexName]!.columns,
          );
        }
      },
    );

    for (final _SchemaScenario scenario in _schemaScenarios) {
      test(
        'print job repository lifecycle stays consistent on ${scenario.name} schema',
        () async {
          final AppDatabase db = await scenario.createDatabase();
          addTearDown(db.close);
          final _SchemaFixture fixture = await _prepareSchemaFixture(
            db,
            transactionUuid: scenario.transactionUuid,
          );
          final PrintJobRepository repository = PrintJobRepository(db);
          final DateTime startedAt = DateTime(2026, 1, 2, 9, 0, 0);

          await repository.ensureQueued(
            transactionId: fixture.transaction.id,
            target: PrintJobTarget.kitchen,
            now: startedAt,
          );
          final PrintJob inProgress = await repository.markInProgress(
            transactionId: fixture.transaction.id,
            target: PrintJobTarget.kitchen,
            allowReprint: false,
            now: startedAt,
          );
          await repository.markFailed(
            transactionId: fixture.transaction.id,
            target: PrintJobTarget.kitchen,
            error: 'offline',
            now: startedAt.add(const Duration(seconds: 1)),
          );
          final PrintJob retried = await repository.markInProgress(
            transactionId: fixture.transaction.id,
            target: PrintJobTarget.kitchen,
            allowReprint: true,
            now: startedAt.add(const Duration(seconds: 2)),
          );
          final PrintJob printed = await repository.markPrinted(
            transactionId: fixture.transaction.id,
            target: PrintJobTarget.kitchen,
            now: startedAt.add(const Duration(seconds: 3)),
          );

          expect(inProgress.status, PrintJobStatus.printing);
          expect(retried.attemptCount, 2);
          expect(printed.status, PrintJobStatus.printed);
        },
      );

      test(
        'payment uniqueness behaves the same on ${scenario.name} schema',
        () async {
          final AppDatabase db = await scenario.createDatabase();
          addTearDown(db.close);
          final _SchemaFixture fixture = await _prepareSchemaFixture(
            db,
            transactionUuid: scenario.transactionUuid,
          );
          final PaymentRepository paymentRepository = PaymentRepository(db);

          final Payment first = await paymentRepository.createPayment(
            transactionId: fixture.transaction.id,
            uuid: 'payment-${scenario.name}-first',
            method: PaymentMethod.card,
            amountMinor: fixture.transaction.totalAmountMinor,
          );

          await expectLater(
            paymentRepository.createPayment(
              transactionId: fixture.transaction.id,
              uuid: 'payment-${scenario.name}-second',
              method: PaymentMethod.card,
              amountMinor: fixture.transaction.totalAmountMinor,
            ),
            throwsA(isA<DuplicatePaymentException>()),
          );

          final List<Payment> payments = await paymentRepository.getByShift(
            fixture.transaction.shiftId,
          );
          expect(first.transactionId, fixture.transaction.id);
          expect(
            payments
                .where(
                  (Payment payment) =>
                      payment.transactionId == fixture.transaction.id,
                )
                .length,
            1,
          );
        },
      );
    }
  });
}

class _SchemaScenario {
  const _SchemaScenario({
    required this.name,
    required this.createDatabase,
    required this.transactionUuid,
  });

  final String name;
  final Future<AppDatabase> Function() createDatabase;
  final String transactionUuid;
}

class _SchemaFixture {
  const _SchemaFixture({required this.transaction});

  final Transaction transaction;
}

final List<_SchemaScenario> _schemaScenarios = <_SchemaScenario>[
  _SchemaScenario(
    name: 'fresh',
    createDatabase: () async => createTestDatabase(),
    transactionUuid: 'fresh-schema-tx',
  ),
  _SchemaScenario(
    name: 'migrated',
    createDatabase: () async => _createV1ThenMigrateToCurrent(),
    transactionUuid: 'tx-v1',
  ),
];

Future<_SchemaFixture> _prepareSchemaFixture(
  AppDatabase db, {
  required String transactionUuid,
}) async {
  final TransactionRepository transactionRepository = TransactionRepository(db);
  final Transaction? existing = await transactionRepository.getByUuid(
    transactionUuid,
  );
  if (existing != null) {
    return _SchemaFixture(transaction: existing);
  }

  final int userId = await insertUser(db, name: 'Schema User', role: 'admin');
  final int shiftId = await insertShift(db, openedBy: userId);
  final int transactionId = await insertTransaction(
    db,
    uuid: transactionUuid,
    shiftId: shiftId,
    userId: userId,
    status: 'sent',
    totalAmountMinor: 500,
  );

  final Transaction created =
      await transactionRepository.getById(transactionId) ??
      (throw StateError('Expected transaction to exist after seeding.'));
  return _SchemaFixture(transaction: created);
}

Future<List<String>> _readTableColumns(AppDatabase db, String tableName) async {
  final List<QueryRow> rows = await db
      .customSelect('PRAGMA table_info($tableName)')
      .get();
  return rows
      .map((QueryRow row) => row.read<String>('name'))
      .toList(growable: false);
}

Future<Map<String, ({bool unique, List<String> columns})>> _readIndexColumns(
  AppDatabase db,
  String tableName,
) async {
  final List<QueryRow> indexes = await db
      .customSelect('PRAGMA index_list($tableName)')
      .get();
  final Map<String, ({bool unique, List<String> columns})> result =
      <String, ({bool unique, List<String> columns})>{};

  for (final QueryRow index in indexes) {
    final String name = index.read<String>('name');
    final bool unique = index.read<int>('unique') == 1;
    final List<QueryRow> columns = await db
        .customSelect('PRAGMA index_info($name)')
        .get();
    result[name] = (
      unique: unique,
      columns: columns
          .map((QueryRow row) => row.read<String>('name'))
          .toList(growable: false),
    );
  }

  return result;
}
