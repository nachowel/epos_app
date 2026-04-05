import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration v24 -> current', () {
    test('migrates meal customization snapshot table with FK guardrails',
        () async {
      final AppDatabase db = _createV24ThenMigrateToCurrent();
      addTearDown(db.close);

      await db.customStatement('''
        INSERT INTO meal_customization_line_snapshots (
          transaction_line_id,
          product_id,
          profile_id,
          customization_key,
          snapshot_json,
          total_adjustment_minor,
          free_swap_count_used,
          paid_swap_count_used
        ) VALUES (
          1,
          1,
          1,
          'stable-key',
          '{"product_id":1,"profile_id":1,"resolved_component_actions":[],"resolved_extra_actions":[],"triggered_discounts":[],"applied_rules":[],"total_adjustment_minor":0,"free_swap_count_used":0,"paid_swap_count_used":0}',
          0,
          0,
          0
        )
      ''');

      final row = await db.customSelect(
        '''
        SELECT customization_key, transaction_line_id
        FROM meal_customization_line_snapshots
        WHERE transaction_line_id = 1
        ''',
      ).getSingle();

      expect(row.read<String>('customization_key'), 'stable-key');
      expect(row.read<int>('transaction_line_id'), 1);

      await expectLater(
        () => db.customStatement('''
          INSERT INTO meal_customization_line_snapshots (
            transaction_line_id,
            product_id,
            profile_id,
            customization_key,
            snapshot_json,
            total_adjustment_minor,
            free_swap_count_used,
            paid_swap_count_used
          ) VALUES (
            999,
            1,
            1,
            'broken-key',
            '{}',
            0,
            0,
            0
          )
        '''),
        throwsA(isA<Object>()),
      );
    });
  });
}

AppDatabase _createV24ThenMigrateToCurrent() {
  final NativeDatabase rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
      database.execute('''
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
      database.execute('''
        CREATE TABLE shifts (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          opened_by INTEGER NOT NULL,
          opened_at INTEGER NOT NULL DEFAULT (unixepoch()),
          closed_by INTEGER NULL,
          closed_at INTEGER NULL,
          cashier_previewed_by INTEGER NULL,
          cashier_previewed_at INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
        );
      ''');
      database.execute('''
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
      database.execute('''
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
          sort_order INTEGER NOT NULL DEFAULT 0
        );
      ''');
      database.execute('''
        CREATE TABLE meal_adjustment_profiles (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT NULL,
          free_swap_limit INTEGER NOT NULL DEFAULT 0 CHECK (free_swap_limit >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (unixepoch()),
          updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
          CHECK (length(trim(name)) > 0)
        );
      ''');
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
          transaction_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL,
          unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
          quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
          line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0),
          pricing_mode TEXT NOT NULL DEFAULT 'standard' CHECK (pricing_mode IN ('standard','set')),
          removal_discount_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_total_minor >= 0)
        );
      ''');
      database.execute(
        "INSERT INTO users (id, name, role, is_active) VALUES (1, 'Admin', 'admin', 1);",
      );
      database.execute(
        "INSERT INTO shifts (id, opened_by, status) VALUES (1, 1, 'open');",
      );
      database.execute(
        "INSERT INTO categories (id, name, is_active) VALUES (1, 'Meals', 1);",
      );
      database.execute(
        "INSERT INTO meal_adjustment_profiles (id, name, free_swap_limit, is_active) VALUES (1, 'Profile', 0, 1);",
      );
      database.execute(
        "INSERT INTO products (id, category_id, meal_adjustment_profile_id, name, price_minor, has_modifiers, is_active, is_visible_on_pos, sort_order) VALUES (1, 1, 1, 'Burger Meal', 1000, 0, 1, 1, 0);",
      );
      database.execute(
        "INSERT INTO transactions (id, uuid, shift_id, user_id, status, subtotal_minor, modifier_total_minor, total_amount_minor, updated_at, idempotency_key, kitchen_printed, receipt_printed) VALUES (1, 'tx-v24', 1, 1, 'draft', 1000, 0, 1000, unixepoch(), 'idem-v24', 0, 0);",
      );
      database.execute(
        "INSERT INTO transaction_lines (id, uuid, transaction_id, product_id, product_name, unit_price_minor, quantity, line_total_minor, pricing_mode, removal_discount_total_minor) VALUES (1, 'line-v24', 1, 1, 'Burger Meal', 1000, 1, 1000, 'standard', 0);",
      );
      database.execute('PRAGMA user_version = 24;');
    },
  );

  return AppDatabase(rawDb);
}
