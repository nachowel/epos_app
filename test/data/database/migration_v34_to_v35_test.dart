import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Migration v34 -> v35 custom sale ownership metadata', () {
    test(
      'adds creator and override columns to transaction_lines and enforces user FKs',
      () async {
        final File file = await _createV34DatabaseFile();
        addTearDown(() async {
          if (await file.exists()) {
            await file.delete();
          }
        });

        final AppDatabase db = AppDatabase.forFile(file);
        addTearDown(db.close);

        final List<dynamic> lineColumns = await db
            .customSelect('PRAGMA table_info(transaction_lines);')
            .get();

        expect(
          lineColumns.map((dynamic row) => row.read<String>('name')).toSet(),
          containsAll(<String>{'created_by_user_id', 'admin_override_user_id'}),
        );

        final dynamic row = await db.customSelect('''
        SELECT
          created_by_user_id,
          admin_override_user_id
        FROM transaction_lines
        WHERE id = 1
      ''').getSingle();
        expect(row.read<int?>('created_by_user_id'), isNull);
        expect(row.read<int?>('admin_override_user_id'), isNull);

        await expectLater(
          db.customStatement('''
          UPDATE transaction_lines
          SET created_by_user_id = 999
          WHERE id = 1
        '''),
          throwsA(isA<Object>()),
        );

        await expectLater(
          db.customStatement('''
          UPDATE transaction_lines
          SET admin_override_user_id = 999
          WHERE id = 1
        '''),
          throwsA(isA<Object>()),
        );
      },
    );
  });
}

Future<File> _createV34DatabaseFile() async {
  final Directory dir = await Directory.systemTemp.createTemp(
    'epos-migration-v34-v35-',
  );
  final File file = File('${dir.path}/migration.sqlite');
  final sqlite3.Database raw = sqlite3.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA user_version = 34;');
    raw.execute('PRAGMA foreign_keys = OFF;');
    raw.execute('''
      CREATE TABLE users (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pin TEXT NULL,
        password TEXT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    raw.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        image_url TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        removal_discount_1_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_1_minor >= 0),
        removal_discount_2_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_2_minor >= 0)
      );
    ''');
    raw.execute('''
      CREATE TABLE products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        meal_adjustment_profile_id INTEGER NULL,
        name TEXT NOT NULL,
        price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
        image_url TEXT NULL,
        has_modifiers INTEGER NOT NULL DEFAULT 0 CHECK (has_modifiers IN (0, 1)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        is_visible_on_pos INTEGER NOT NULL DEFAULT 1 CHECK (is_visible_on_pos IN (0, 1)),
        is_custom INTEGER NOT NULL DEFAULT 0 CHECK (is_custom IN (0, 1)),
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute('''
      CREATE TABLE menu_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        free_swap_limit INTEGER NOT NULL DEFAULT 2 CHECK (free_swap_limit >= 0),
        max_swaps INTEGER NOT NULL DEFAULT 4 CHECK (max_swaps >= 0),
        custom_sales_limit_minor INTEGER NOT NULL DEFAULT 100000 CHECK (custom_sales_limit_minor >= 0),
        updated_by INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (unixepoch())
      );
    ''');
    raw.execute('''
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        table_number INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','sent','paid','cancelled')),
        subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
        modifier_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (modifier_total_minor >= 0),
        discount_type TEXT NULL CHECK (discount_type IS NULL OR discount_type IN ('amount','percent')),
        discount_value_minor INTEGER NOT NULL DEFAULT 0 CHECK (discount_value_minor >= 0),
        discount_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (discount_amount_minor >= 0 AND discount_amount_minor <= subtotal_minor + modifier_total_minor),
        discount_reason TEXT NULL,
        discount_applied_by INTEGER NULL,
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
    raw.execute('''
      CREATE TABLE transaction_lines (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0),
        pricing_mode TEXT NOT NULL DEFAULT 'standard' CHECK (pricing_mode IN ('standard','set')),
        removal_discount_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_total_minor >= 0),
        custom_note TEXT NULL
      );
    ''');

    raw.execute(
      "INSERT INTO users (id, name, role, is_active, created_at) VALUES (1, 'Admin', 'admin', 1, unixepoch());",
    );
    raw.execute(
      "INSERT INTO categories (id, name, sort_order, is_active) VALUES (1, 'Drinks', 0, 1);",
    );
    raw.execute('''
      INSERT INTO products (
        id,
        category_id,
        meal_adjustment_profile_id,
        name,
        price_minor,
        image_url,
        has_modifiers,
        is_active,
        is_visible_on_pos,
        is_custom,
        sort_order
      ) VALUES (1, 1, NULL, 'Custom Sale', 0, NULL, 0, 1, 0, 1, 0);
    ''');
    raw.execute('''
      INSERT INTO menu_settings (
        id,
        free_swap_limit,
        max_swaps,
        custom_sales_limit_minor,
        updated_by,
        updated_at
      ) VALUES (1, 2, 4, 100000, NULL, unixepoch());
    ''');
    raw.execute('''
      INSERT INTO transactions (
        id,
        uuid,
        shift_id,
        user_id,
        status,
        subtotal_minor,
        modifier_total_minor,
        total_amount_minor,
        updated_at,
        idempotency_key,
        kitchen_printed,
        receipt_printed
      ) VALUES (1, 'tx-v34', 1, 1, 'draft', 300, 0, 300, unixepoch(), 'idem-v34', 0, 0);
    ''');
    raw.execute('''
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
        removal_discount_total_minor,
        custom_note
      ) VALUES (1, 'line-v34', 1, 1, 'Custom Sale', 300, 1, 300, 'standard', 0, 'Legacy note');
    ''');
  } finally {
    raw.dispose();
  }

  return file;
}
