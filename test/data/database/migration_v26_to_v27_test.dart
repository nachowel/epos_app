import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration v26 -> current', () {
    test(
      'adds sandwich settings columns with empty product-linked defaults',
      () async {
        final AppDatabase db = _createV26ThenMigrateToCurrent();
        addTearDown(db.close);

        final row = await db.customSelect('''
        SELECT
          sandwich_surcharge_minor,
          baguette_surcharge_minor,
          sandwich_sauce_options_json
        FROM meal_adjustment_profiles
        WHERE id = 1
        ''').getSingle();

        expect(row.read<int>('sandwich_surcharge_minor'), 100);
        expect(row.read<int>('baguette_surcharge_minor'), 180);
        expect(row.read<String>('sandwich_sauce_options_json'), '[]');
      },
    );
  });
}

AppDatabase _createV26ThenMigrateToCurrent() {
  final NativeDatabase rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
      database.execute('''
        CREATE TABLE categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          image_url TEXT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          removal_discount_1_minor INTEGER NOT NULL DEFAULT 0,
          removal_discount_2_minor INTEGER NOT NULL DEFAULT 0
        );
      ''');
      database.execute('''
        CREATE TABLE products (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          category_id INTEGER NOT NULL,
          meal_adjustment_profile_id INTEGER NULL,
          name TEXT NOT NULL,
          price_minor INTEGER NOT NULL DEFAULT 0,
          image_url TEXT NULL,
          has_modifiers INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          is_visible_on_pos INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0
        );
      ''');
      database.execute('''
        CREATE TABLE meal_adjustment_profiles (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT NULL,
          profile_kind TEXT NOT NULL DEFAULT 'standard' CHECK (profile_kind IN ('standard','sandwich')),
          free_swap_limit INTEGER NOT NULL DEFAULT 0 CHECK (free_swap_limit >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (unixepoch()),
          updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
          CHECK (length(trim(name)) > 0)
        );
      ''');
      database.execute('''
        CREATE TABLE modifier_groups (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          min_select INTEGER NOT NULL DEFAULT 1,
          max_select INTEGER NOT NULL DEFAULT 1,
          included_quantity INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0
        );
      ''');
      database.execute('''
        CREATE TABLE product_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          group_id INTEGER NULL,
          item_product_id INTEGER NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('included','extra','choice')),
          extra_price_minor INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          CHECK ((type = 'choice' AND group_id IS NOT NULL) OR (type IN ('included','extra') AND group_id IS NULL))
        );
      ''');
      database.execute('''
        CREATE TABLE transaction_lines (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          product_name TEXT NOT NULL,
          unit_price_minor INTEGER NOT NULL DEFAULT 0,
          quantity INTEGER NOT NULL DEFAULT 1,
          line_total_minor INTEGER NOT NULL DEFAULT 0,
          pricing_mode TEXT NOT NULL DEFAULT 'standard',
          removal_discount_total_minor INTEGER NOT NULL DEFAULT 0
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
          charge_reason TEXT NULL CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount','combo_discount')),
          unit_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (unit_price_minor >= 0),
          price_effect_minor INTEGER NOT NULL DEFAULT 0,
          sort_key INTEGER NOT NULL DEFAULT 0,
          CHECK (action != 'choice' OR charge_reason = 'included_choice')
        );
      ''');
      database.execute(
        "INSERT INTO meal_adjustment_profiles (id, name, profile_kind, free_swap_limit, is_active) VALUES (1, 'Sandwich Profile', 'sandwich', 0, 1);",
      );
      database.execute('PRAGMA user_version = 26;');
    },
  );

  return AppDatabase(rawDb);
}
