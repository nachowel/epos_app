import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration v27 -> current', () {
    test(
      'repairs transaction child tables that still reference transactions_legacy_v24',
      () async {
        final AppDatabase db = _createBrokenV27ThenMigrateToCurrent();
        addTearDown(db.close);

        final List<Map<String, Object?>> legacyReferences = await db
            .customSelect('''
              SELECT type, name, tbl_name, sql
              FROM sqlite_master
              WHERE sql LIKE '%transactions_legacy_v24%'
              ''')
            .get()
            .then(
              (rows) => rows
                  .map(
                    (row) => <String, Object?>{
                      'type': row.data['type'],
                      'name': row.data['name'],
                      'tbl_name': row.data['tbl_name'],
                      'sql': row.data['sql'],
                    },
                  )
                  .toList(),
            );

        expect(legacyReferences, isEmpty);

        final transactionLineSchema = await db.customSelect('''
          SELECT sql
          FROM sqlite_master
          WHERE type = 'table' AND name = 'transaction_lines'
          ''').getSingle();
        expect(
          transactionLineSchema.read<String>('sql'),
          contains('REFERENCES "transactions"'),
        );

        final paymentSchema = await db.customSelect('''
          SELECT sql
          FROM sqlite_master
          WHERE type = 'table' AND name = 'payments'
          ''').getSingle();
        expect(
          paymentSchema.read<String>('sql'),
          contains('REFERENCES "transactions"'),
        );

        await db.customStatement('''
          INSERT INTO transaction_lines (
            id,
            uuid,
            transaction_id,
            product_id,
            product_name,
            unit_price_minor,
            quantity,
            line_total_minor,
            pricing_mode,
            removal_discount_total_minor
          ) VALUES (
            2,
            'line-v28',
            1,
            1,
            'Burger Meal',
            1000,
            1,
            1000,
            'standard',
            0
          )
        ''');

        await db.customStatement('''
          INSERT INTO payments (
            id,
            uuid,
            transaction_id,
            method,
            amount_minor,
            paid_at
          ) VALUES (
            1,
            'payment-v28',
            1,
            'cash',
            1000,
            unixepoch()
          )
        ''');

        final lineRow = await db.customSelect('''
          SELECT transaction_id
          FROM transaction_lines
          WHERE id = 2
          ''').getSingle();
        expect(lineRow.read<int>('transaction_id'), 1);

        final paymentRow = await db.customSelect('''
          SELECT transaction_id
          FROM payments
          WHERE id = 1
          ''').getSingle();
        expect(paymentRow.read<int>('transaction_id'), 1);
      },
    );
  });
}

AppDatabase _createBrokenV27ThenMigrateToCurrent() {
  final NativeDatabase rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
      database.execute('PRAGMA legacy_alter_table = ON;');
      database.execute('''
        CREATE TABLE transactions (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          shift_id INTEGER NOT NULL,
          user_id INTEGER NOT NULL,
          table_number INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
          subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
          modifier_total_minor INTEGER NOT NULL DEFAULT 0,
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
      database.execute('''
        CREATE TABLE transaction_lines (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_id INTEGER NOT NULL REFERENCES "transactions_legacy_v24" ("id"),
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL,
          unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
          quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
          line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0),
          pricing_mode TEXT NOT NULL DEFAULT 'standard' CHECK (pricing_mode IN ('standard','set')),
          removal_discount_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_total_minor >= 0)
        );
      ''');
      database.execute('''
        CREATE TABLE payments (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_id INTEGER UNIQUE NOT NULL REFERENCES "transactions_legacy_v24" ("id"),
          method TEXT NOT NULL CHECK (method IN ('cash','card')),
          amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
          paid_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');
      database.execute(
        "INSERT INTO transactions (id, uuid, shift_id, user_id, status, subtotal_minor, modifier_total_minor, total_amount_minor, updated_at, idempotency_key, kitchen_printed, receipt_printed) VALUES (1, 'tx-v27', 1, 1, 'draft', 1000, 0, 1000, unixepoch(), 'idem-v27', 0, 0);",
      );
      database.execute('PRAGMA user_version = 27;');
    },
  );

  return AppDatabase(rawDb);
}
