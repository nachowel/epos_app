import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration v23 -> current', () {
    test(
      'migrated database allows signed modifier totals and combo discount rows',
      () async {
        final AppDatabase db = _createV23ThenMigrateToCurrent();
        addTearDown(db.close);

        await db.customStatement('''
          UPDATE transactions
          SET modifier_total_minor = -50,
              total_amount_minor = 950
          WHERE id = 1
        ''');

        await db.customStatement('''
          INSERT INTO order_modifiers (
            uuid,
            transaction_line_id,
            action,
            item_name,
            quantity,
            item_product_id,
            source_group_id,
            extra_price_minor,
            charge_reason,
            unit_price_minor,
            price_effect_minor,
            sort_key
          ) VALUES (
            'combo-discount-row',
            1,
            'add',
            'Meal combo discount',
            1,
            NULL,
            NULL,
            0,
            'combo_discount',
            0,
            -50,
            10
          )
        ''');

        final QueryRow transactionRow = await db.customSelect(
          '''
          SELECT modifier_total_minor
          FROM transactions
          WHERE id = 1
          ''',
        ).getSingle();
        final QueryRow modifierRow = await db.customSelect(
          '''
          SELECT charge_reason, price_effect_minor
          FROM order_modifiers
          WHERE uuid = 'combo-discount-row'
          ''',
        ).getSingle();

        expect(transactionRow.read<int>('modifier_total_minor'), -50);
        expect(modifierRow.read<String>('charge_reason'), 'combo_discount');
        expect(modifierRow.read<int>('price_effect_minor'), -50);
      },
    );
  });
}

AppDatabase _createV23ThenMigrateToCurrent() {
  final QueryExecutor rawDb = NativeDatabase.memory(
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
        CREATE TABLE modifier_groups (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          min_select INTEGER NOT NULL DEFAULT 1 CHECK (min_select >= 0),
          max_select INTEGER NOT NULL DEFAULT 1 CHECK (max_select > 0),
          included_quantity INTEGER NOT NULL DEFAULT 1 CHECK (included_quantity > 0),
          sort_order INTEGER NOT NULL DEFAULT 0,
          CHECK (max_select >= min_select),
          UNIQUE(product_id, name)
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
      database.execute('''
        CREATE TABLE order_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_line_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (action IN ('remove','add','choice')),
          item_name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
          item_product_id INTEGER NULL,
          source_group_id INTEGER NULL,
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          charge_reason TEXT NULL CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount')),
          unit_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (unit_price_minor >= 0),
          price_effect_minor INTEGER NOT NULL DEFAULT 0 CHECK (price_effect_minor >= 0),
          sort_key INTEGER NOT NULL DEFAULT 0,
          CHECK (action != 'choice' OR charge_reason = 'included_choice')
        );
      ''');
      database.execute("INSERT INTO users (id, name, role, is_active) VALUES (1, 'Admin', 'admin', 1);");
      database.execute("INSERT INTO shifts (id, opened_by, status) VALUES (1, 1, 'open');");
      database.execute("INSERT INTO categories (id, name, is_active) VALUES (1, 'Meals', 1);");
      database.execute(
        "INSERT INTO products (id, category_id, meal_adjustment_profile_id, name, price_minor, has_modifiers, is_active, is_visible_on_pos, sort_order) VALUES (1, 1, NULL, 'Burger Meal', 1000, 0, 1, 1, 0);",
      );
      database.execute(
        "INSERT INTO transactions (id, uuid, shift_id, user_id, status, subtotal_minor, modifier_total_minor, total_amount_minor, updated_at, idempotency_key, kitchen_printed, receipt_printed) VALUES (1, 'tx-v23', 1, 1, 'draft', 1000, 0, 1000, unixepoch(), 'idem-v23', 0, 0);",
      );
      database.execute(
        "INSERT INTO transaction_lines (id, uuid, transaction_id, product_id, product_name, unit_price_minor, quantity, line_total_minor, pricing_mode, removal_discount_total_minor) VALUES (1, 'line-v23', 1, 1, 'Burger Meal', 1000, 1, 1000, 'standard', 0);",
      );
      database.execute('PRAGMA user_version = 23;');
    },
  );

  return AppDatabase(rawDb);
}
