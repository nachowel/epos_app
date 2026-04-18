import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Migration v33 -> v34 custom sale foundation', () {
    test(
      'adds custom-sale columns, preserves non-null product_id, and seeds exactly one internal product',
      () async {
        final File file = await _createV33DatabaseFile();
        addTearDown(() async {
          if (await file.exists()) {
            await file.delete();
          }
        });

        final AppDatabase db = AppDatabase.forFile(file);
        addTearDown(db.close);

        final List<dynamic> productColumns = await db
            .customSelect('PRAGMA table_info(products);')
            .get();
        final List<dynamic> lineColumns = await db
            .customSelect('PRAGMA table_info(transaction_lines);')
            .get();
        final List<dynamic> menuColumns = await db
            .customSelect('PRAGMA table_info(menu_settings);')
            .get();

        expect(
          productColumns.map((dynamic row) => row.read<String>('name')).toSet(),
          contains('is_custom'),
        );
        expect(
          lineColumns.map((dynamic row) => row.read<String>('name')).toSet(),
          contains('custom_note'),
        );
        expect(
          menuColumns.map((dynamic row) => row.read<String>('name')).toSet(),
          contains('custom_sales_limit_minor'),
        );

        final dynamic productIdColumn = lineColumns.singleWhere(
          (dynamic row) => row.read<String>('name') == 'product_id',
        );
        expect(productIdColumn.read<int>('notnull'), 1);

        final dynamic menuRow = await db.customSelect('''
          SELECT custom_sales_limit_minor
          FROM menu_settings
          ORDER BY id ASC
          LIMIT 1
        ''').getSingle();
        expect(menuRow.read<int>('custom_sales_limit_minor'), 100000);

        final dynamic systemProduct = await db.customSelect('''
          SELECT
            p.id,
            p.name,
            p.price_minor,
            p.is_active,
            p.is_visible_on_pos,
            p.is_custom,
            c.name AS category_name
          FROM products p
          INNER JOIN categories c ON c.id = p.category_id
          WHERE p.is_custom = 1
          ORDER BY p.id ASC
          LIMIT 1
        ''').getSingle();
        expect(systemProduct.read<String>('name'), 'Custom Sale');
        expect(systemProduct.read<int>('price_minor'), 0);
        expect(systemProduct.read<int>('is_active'), 1);
        expect(systemProduct.read<int>('is_visible_on_pos'), 0);
        expect(systemProduct.read<int>('is_custom'), 1);
        expect(
          systemProduct.read<String>('category_name'),
          'Archived Products',
        );

        final dynamic customCount = await db.customSelect('''
          SELECT COUNT(*) AS cnt
          FROM products
          WHERE is_custom = 1
        ''').getSingle();
        expect(customCount.read<int>('cnt'), 1);

        final dynamic sameNameNormalCount = await db.customSelect('''
          SELECT COUNT(*) AS cnt
          FROM products
          WHERE name = 'Custom Sale'
            AND is_custom = 0
        ''').getSingle();
        expect(sameNameNormalCount.read<int>('cnt'), 1);

        expect(
          () => db.customStatement('''
            INSERT INTO products (
              category_id,
              name,
              price_minor,
              has_modifiers,
              is_active,
              is_visible_on_pos,
              is_custom,
              sort_order
            ) VALUES (1, 'Another Custom Sale', 0, 0, 1, 0, 1, 2);
          '''),
          throwsA(isA<Object>()),
        );
      },
    );
  });

  group('Current schema reopen custom sale startup invariant', () {
    test(
      'reopen enforces single-product invariant without rewriting non-critical custom product fields',
      () async {
        final File file = await _createExistingV34DatabaseFile();
        addTearDown(() async {
          if (await file.exists()) {
            await file.delete();
          }
        });

        final AppDatabase db = AppDatabase.forFile(file);
        addTearDown(db.close);

        final dynamic systemProduct = await db.customSelect('''
          SELECT
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
          FROM products
          WHERE is_custom = 1
          ORDER BY id ASC
          LIMIT 1
        ''').getSingle();

        expect(systemProduct.read<int>('category_id'), 2);
        expect(systemProduct.read<int?>('meal_adjustment_profile_id'), 91);
        expect(systemProduct.read<String>('name'), 'Weird Custom Alias');
        expect(systemProduct.read<int>('price_minor'), 345);
        expect(systemProduct.read<String?>('image_url'), 'custom.png');
        expect(systemProduct.read<int>('sort_order'), 77);
        expect(systemProduct.read<int>('is_custom'), 1);

        expect(
          () => db.customStatement('''
            INSERT INTO products (
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
            ) VALUES (1, NULL, 'Duplicate Custom', 0, NULL, 0, 1, 0, 1, 3);
          '''),
          throwsA(isA<Object>()),
        );
      },
    );
  });
}

Future<File> _createV33DatabaseFile() async {
  final Directory dir = await Directory.systemTemp.createTemp(
    'epos-migration-v33-v34-',
  );
  final File file = File('${dir.path}/migration.sqlite');
  final sqlite3.Database raw = sqlite3.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA user_version = 33;');
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
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    raw.execute('''
      CREATE TABLE menu_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        free_swap_limit INTEGER NOT NULL DEFAULT 2 CHECK (free_swap_limit >= 0),
        max_swaps INTEGER NOT NULL DEFAULT 4 CHECK (max_swaps >= 0),
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
        transaction_id INTEGER NOT NULL REFERENCES "transactions" ("id"),
        product_id INTEGER NOT NULL REFERENCES "products" ("id"),
        product_name TEXT NOT NULL,
        unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0),
        pricing_mode TEXT NOT NULL DEFAULT 'standard' CHECK (pricing_mode IN ('standard','set')),
        removal_discount_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (removal_discount_total_minor >= 0)
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
        sort_order
      ) VALUES (1, 1, NULL, 'Custom Sale', 250, NULL, 0, 1, 1, 0);
    ''');
    raw.execute('''
      INSERT INTO menu_settings (
        id,
        free_swap_limit,
        max_swaps,
        updated_by,
        updated_at
      ) VALUES (1, 2, 4, NULL, unixepoch());
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
        discount_type,
        discount_value_minor,
        discount_amount_minor,
        discount_reason,
        discount_applied_by,
        total_amount_minor,
        updated_at,
        idempotency_key,
        kitchen_printed,
        receipt_printed
      ) VALUES (
        1,
        'tx-v33',
        1,
        1,
        'draft',
        250,
        0,
        NULL,
        0,
        0,
        NULL,
        NULL,
        250,
        unixepoch(),
        'idem-v33',
        0,
        0
      );
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
        removal_discount_total_minor
      ) VALUES (
        1,
        'line-v33',
        1,
        1,
        'Custom Sale',
        250,
        1,
        250,
        'standard',
        0
      );
    ''');
  } finally {
    raw.dispose();
  }

  return file;
}

Future<File> _createExistingV34DatabaseFile() async {
  final Directory dir = await Directory.systemTemp.createTemp(
    'epos-existing-v34-custom-sale-',
  );
  final File file = File('${dir.path}/existing.sqlite');
  final sqlite3.Database raw = sqlite3.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA user_version = 34;');
    raw.execute('PRAGMA foreign_keys = OFF;');
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
      INSERT INTO categories (id, name, sort_order, is_active)
      VALUES
        (1, 'Drinks', 0, 1),
        (2, 'Weird Host', 1, 1);
    ''');
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
      ) VALUES (
        7,
        2,
        91,
        'Weird Custom Alias',
        345,
        'custom.png',
        1,
        1,
        1,
        1,
        77
      );
    ''');
  } finally {
    raw.dispose();
  }

  return file;
}
