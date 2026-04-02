import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Migration v15 -> current', () {
    test(
      'fresh database creation seeds exactly one default menu_settings row',
      () async {
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final QueryRow row = await _readMenuSettingsSeedRow(db);

        expect(row.read<int>('row_count'), 1);
        expect(row.read<int>('free_swap_limit'), 2);
        expect(row.read<int>('max_swaps'), 4);
        expect(row.read<int?>('updated_by'), isNull);
        expect(row.read<int>('updated_at'), greaterThan(0));
      },
    );

    test(
      'existing menu-related rows survive migration and gain safe defaults',
      () async {
        final AppDatabase db = _createV15ThenMigrateToCurrent();
        addTearDown(db.close);

        final QueryRow categoryRow = await db.customSelect('''
          SELECT
            removal_discount_1_minor,
            removal_discount_2_minor
          FROM categories
          WHERE id = 1
        ''').getSingle();
        expect(categoryRow.read<int>('removal_discount_1_minor'), 0);
        expect(categoryRow.read<int>('removal_discount_2_minor'), 0);

        final QueryRow modifierRow = await db.customSelect('''
          SELECT
            product_id,
            group_id,
            type,
            extra_price_minor,
            is_active
          FROM product_modifiers
          WHERE id = 1
        ''').getSingle();
        expect(modifierRow.read<int>('product_id'), 1);
        expect(modifierRow.read<int?>('group_id'), isNull);
        expect(modifierRow.read<String>('type'), 'extra');
        expect(modifierRow.read<int>('extra_price_minor'), 150);
        expect(modifierRow.read<int>('is_active'), 1);

        final QueryRow lineRow = await db.customSelect('''
          SELECT
            pricing_mode,
            removal_discount_total_minor
          FROM transaction_lines
          WHERE id = 1
        ''').getSingle();
        expect(lineRow.read<String>('pricing_mode'), 'standard');
        expect(lineRow.read<int>('removal_discount_total_minor'), 0);

        final QueryRow orderModifierRow = await db.customSelect('''
          SELECT
            action,
            quantity,
            item_product_id,
            charge_reason,
            extra_price_minor
          FROM order_modifiers
          WHERE id = 1
        ''').getSingle();
        expect(orderModifierRow.read<String>('action'), 'add');
        expect(orderModifierRow.read<int>('quantity'), 1);
        expect(orderModifierRow.read<int?>('item_product_id'), isNull);
        expect(orderModifierRow.read<String?>('charge_reason'), isNull);
        expect(orderModifierRow.read<int>('extra_price_minor'), 150);

        final QueryRow menuSettingsRow = await _readMenuSettingsSeedRow(db);
        expect(menuSettingsRow.read<int>('row_count'), 1);
        expect(menuSettingsRow.read<int>('free_swap_limit'), 2);
        expect(menuSettingsRow.read<int>('max_swaps'), 4);
        expect(menuSettingsRow.read<int?>('updated_by'), isNull);
      },
    );

    test(
      'migrated categories rows load through the generated Drift mapper',
      () async {
        final AppDatabase db = _createV15ThenMigrateToCurrent();
        addTearDown(db.close);

        final List<Category> categories = await db.select(db.categories).get();

        expect(categories, hasLength(1));
        expect(categories.single.name, 'Breakfast');
        expect(categories.single.removalDiscount1Minor, 0);
        expect(categories.single.removalDiscount2Minor, 0);
      },
    );

    test(
      'existing v16 database keeps a single default menu_settings row after compatibility migration',
      () async {
        final AppDatabase db = _createV16ThenMigrateToCurrent();
        addTearDown(db.close);

        final QueryRow row = await _readMenuSettingsSeedRow(db);

        expect(row.read<int>('row_count'), 1);
        expect(row.read<int>('free_swap_limit'), 2);
        expect(row.read<int>('max_swaps'), 4);
        expect(row.read<int?>('updated_by'), isNull);
      },
    );

    test(
      'fresh and migrated schemas expose the same menu engine columns and indexes',
      () async {
        final AppDatabase freshDb = createTestDatabase();
        final AppDatabase migratedDb = _createV15ThenMigrateToCurrent();
        addTearDown(freshDb.close);
        addTearDown(migratedDb.close);

        final List<String> relevantTables = <String>[
          'categories',
          'menu_settings',
          'set_items',
          'modifier_groups',
          'product_modifiers',
          'transaction_lines',
          'order_modifiers',
        ];

        for (final String tableName in relevantTables) {
          final List<String> freshColumns = await _readTableColumns(
            freshDb,
            tableName,
          );
          final List<String> migratedColumns = await _readTableColumns(
            migratedDb,
            tableName,
          );
          expect(freshColumns, migratedColumns, reason: tableName);
        }

        final List<String> indexedTables = <String>[
          'menu_settings',
          'set_items',
          'modifier_groups',
          'product_modifiers',
          'order_modifiers',
        ];

        for (final String tableName in indexedTables) {
          final Map<String, ({bool unique, List<String> columns})>
          freshIndexes = await _readIndexColumns(freshDb, tableName);
          final Map<String, ({bool unique, List<String> columns})>
          migratedIndexes = await _readIndexColumns(migratedDb, tableName);

          expect(
            freshIndexes.keys.toSet(),
            migratedIndexes.keys.toSet(),
            reason: tableName,
          );
          for (final String indexName in freshIndexes.keys) {
            expect(
              freshIndexes[indexName]!.unique,
              migratedIndexes[indexName]!.unique,
              reason: '$tableName:$indexName',
            );
            expect(
              freshIndexes[indexName]!.columns,
              migratedIndexes[indexName]!.columns,
              reason: '$tableName:$indexName',
            );
          }
        }
      },
    );

    test(
      'migrated schema adds trigger-backed protection for new menu-engine foreign keys and checks',
      () async {
        final AppDatabase db = _createV15ThenMigrateToCurrent();
        addTearDown(db.close);

        final Set<String> setItemTriggers = await _readTriggers(
          db,
          'set_items',
        );
        final Set<String> productModifierTriggers = await _readTriggers(
          db,
          'product_modifiers',
        );
        final Set<String> orderModifierTriggers = await _readTriggers(
          db,
          'order_modifiers',
        );

        expect(setItemTriggers, contains('fk_set_items_product_id_insert'));
        expect(
          setItemTriggers,
          contains('fk_set_items_item_product_id_insert'),
        );
        expect(
          productModifierTriggers,
          contains('fk_product_modifiers_group_id_insert'),
        );
        expect(
          orderModifierTriggers,
          contains('fk_order_modifiers_item_product_id_insert'),
        );

        await expectLater(
          db.customStatement('''
            INSERT INTO set_items (
              product_id,
              item_product_id,
              is_removable,
              default_quantity
            ) VALUES (999, 999, 1, 1);
          '''),
          throwsException,
        );

        await expectLater(
          db.customStatement('''
            INSERT INTO modifier_groups (
              product_id,
              name,
              min_select,
              max_select,
              included_quantity
            ) VALUES (999, 'Invalid', 1, 1, 1);
          '''),
          throwsException,
        );

        await expectLater(
          db.customStatement('''
            INSERT INTO order_modifiers (
              uuid,
              transaction_line_id,
              action,
              item_name,
              quantity,
              item_product_id,
              extra_price_minor,
              charge_reason
            ) VALUES (
              'bad-item-product',
              1,
              'add',
              'Ghost item',
              1,
              999,
              100,
              'extra_add'
            );
          '''),
          throwsException,
        );

        await expectLater(
          db.customStatement('''
            INSERT INTO transaction_lines (
              uuid,
              transaction_id,
              product_id,
              product_name,
              unit_price_minor,
              quantity,
              line_total_minor,
              pricing_mode
            ) VALUES (
              'bad-pricing-mode',
              1,
              1,
              'Breakfast',
              1000,
              1,
              1000,
              'create_your_own'
            );
          '''),
          throwsException,
        );

        await expectLater(
          db.customStatement('''
            INSERT INTO order_modifiers (
              uuid,
              transaction_line_id,
              action,
              item_name,
              quantity,
              extra_price_minor,
              charge_reason
            ) VALUES (
              'bad-choice-charge',
              1,
              'choice',
              'Tea',
              1,
              0,
              'free_swap'
            );
          '''),
          throwsException,
        );
      },
    );
  });
}

AppDatabase _createV15ThenMigrateToCurrent() {
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
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      database.execute('''
        CREATE TABLE categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          image_url TEXT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');
      database.execute('''
        CREATE TABLE products (
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
      database.execute('''
        CREATE TABLE product_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('included','extra')),
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');
      database.execute('''
        CREATE TABLE shifts (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          opened_by INTEGER NOT NULL,
          opened_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
          closed_by INTEGER NULL,
          closed_at INTEGER NULL,
          cashier_previewed_by INTEGER NULL,
          cashier_previewed_at INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
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
      database.execute('''
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
      database.execute('''
        CREATE TABLE order_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_line_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (action IN ('remove','add')),
          item_name TEXT NOT NULL,
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0)
        );
      ''');

      database.execute(
        "INSERT INTO users (id, name, role, is_active, created_at) VALUES (1, 'Admin', 'admin', 1, 1710000000);",
      );
      database.execute(
        "INSERT INTO categories (id, name, sort_order, is_active) VALUES (1, 'Breakfast', 0, 1);",
      );
      database.execute('''
        INSERT INTO products (
          id,
          category_id,
          name,
          price_minor,
          has_modifiers,
          is_active,
          is_visible_on_pos,
          sort_order
        ) VALUES (1, 1, 'Set Breakfast', 1000, 1, 1, 1, 0);
      ''');
      database.execute(
        "INSERT INTO products (id, category_id, name, price_minor, has_modifiers, is_active, is_visible_on_pos, sort_order) VALUES (2, 1, 'Hash Brown', 150, 0, 1, 1, 1);",
      );
      database.execute('''
        INSERT INTO product_modifiers (
          id,
          product_id,
          name,
          type,
          extra_price_minor,
          is_active
        ) VALUES (1, 1, 'Hash Brown', 'extra', 150, 1);
      ''');
      database.execute(
        "INSERT INTO shifts (id, opened_by, opened_at, status) VALUES (1, 1, 1710000001, 'open');",
      );
      database.execute('''
        INSERT INTO transactions (
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
          updated_at,
          idempotency_key,
          kitchen_printed,
          receipt_printed
        ) VALUES (
          1,
          'tx-v15',
          1,
          1,
          7,
          'draft',
          1000,
          150,
          1150,
          1710000002,
          1710000002,
          'idem-v15',
          0,
          0
        );
      ''');
      database.execute('''
        INSERT INTO transaction_lines (
          id,
          uuid,
          transaction_id,
          product_id,
          product_name,
          unit_price_minor,
          quantity,
          line_total_minor
        ) VALUES (1, 'line-v15', 1, 1, 'Set Breakfast', 1000, 1, 1150);
      ''');
      database.execute('''
        INSERT INTO order_modifiers (
          id,
          uuid,
          transaction_line_id,
          action,
          item_name,
          extra_price_minor
        ) VALUES (1, 'modifier-v15', 1, 'add', 'Hash Brown', 150);
      ''');
      database.execute('PRAGMA user_version = 15;');
    },
  );

  return AppDatabase(rawDb);
}

AppDatabase _createV16ThenMigrateToCurrent() {
  final QueryExecutor rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
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
        CREATE TABLE product_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          group_id INTEGER NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('included','extra','choice')),
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          CHECK ((group_id IS NOT NULL AND type = 'choice') OR (group_id IS NULL AND type IN ('included','extra')))
        );
      ''');
      database.execute('''
        CREATE TABLE users (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NULL,
          password TEXT NULL,
          role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      database.execute('''
        CREATE TABLE menu_settings (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          free_swap_limit INTEGER NOT NULL DEFAULT 2 CHECK (free_swap_limit >= 0),
          updated_by INTEGER NULL,
          updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        );
      ''');
      database.execute('''
        INSERT INTO menu_settings (
          id,
          free_swap_limit,
          updated_by,
          updated_at
        ) VALUES (1, 2, NULL, 1710000000);
      ''');
      database.execute(
        "INSERT INTO categories (id, name, sort_order, is_active, removal_discount_1_minor, removal_discount_2_minor) VALUES (1, 'Set Breakfast', 0, 1, 0, 0);",
      );
      database.execute(
        "INSERT INTO products (id, category_id, name, price_minor, has_modifiers, is_active, is_visible_on_pos, sort_order) VALUES (1, 1, 'Set 4', 400, 1, 1, 1, 0);",
      );
      database.execute('''
        INSERT INTO product_modifiers (
          id,
          product_id,
          group_id,
          name,
          type,
          extra_price_minor,
          is_active
        ) VALUES (1, 1, NULL, 'Hash Brown', 'extra', 150, 1);
      ''');
      database.execute('PRAGMA user_version = 16;');
    },
  );

  return AppDatabase(rawDb);
}

Future<QueryRow> _readMenuSettingsSeedRow(AppDatabase db) {
  return db.customSelect('''
    SELECT
      COUNT(*) AS row_count,
      MIN(free_swap_limit) AS free_swap_limit,
      MIN(max_swaps) AS max_swaps,
      MIN(updated_by) AS updated_by,
      MIN(updated_at) AS updated_at
    FROM menu_settings
  ''').getSingle();
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

Future<Set<String>> _readTriggers(AppDatabase db, String tableName) async {
  final List<QueryRow> rows = await db
      .customSelect(
        '''
          SELECT name
          FROM sqlite_master
          WHERE type = 'trigger' AND tbl_name = ?
        ''',
        variables: <Variable<Object>>[Variable<String>(tableName)],
      )
      .get();
  return rows.map((QueryRow row) => row.read<String>('name')).toSet();
}
