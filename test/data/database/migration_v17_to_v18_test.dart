import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Migration v17 -> current', () {
    test(
      'migrated database preserves legacy product_modifiers rows and adds item_product_id',
      () async {
        final AppDatabase db = _createV17ThenMigrateToCurrent();
        addTearDown(db.close);

        final List<String> columns = await _readTableColumns(
          db,
          'product_modifiers',
        );
        expect(columns, contains('item_product_id'));

        final QueryRow legacyRow = await db.customSelect('''
          SELECT
            product_id,
            group_id,
            item_product_id,
            type,
            name,
            extra_price_minor,
            is_active
          FROM product_modifiers
          WHERE id = 1
        ''').getSingle();

        expect(legacyRow.read<int>('product_id'), 1);
        expect(legacyRow.read<int?>('group_id'), isNull);
        expect(legacyRow.read<int?>('item_product_id'), isNull);
        expect(legacyRow.read<String>('type'), 'extra');
        expect(legacyRow.read<String>('name'), 'Hash Brown');
        expect(legacyRow.read<int>('extra_price_minor'), 150);
        expect(legacyRow.read<int>('is_active'), 1);
      },
    );

    test(
      'choice rows require a real product reference after migration',
      () async {
        final AppDatabase db = _createV17ThenMigrateToCurrent();
        addTearDown(db.close);

        await expectLater(
          db.customStatement('''
            INSERT INTO product_modifiers (
              product_id,
              group_id,
              name,
              type,
              extra_price_minor,
              is_active
            ) VALUES (1, 1, 'Tea', 'choice', 0, 1);
          '''),
          throwsException,
        );

        await expectLater(
          db.customStatement('''
            INSERT INTO product_modifiers (
              product_id,
              item_product_id,
              name,
              type,
              extra_price_minor,
              is_active
            ) VALUES (1, 2, 'Tea', 'choice', 0, 1);
          '''),
          throwsException,
        );

        await db.customStatement('''
          INSERT INTO product_modifiers (
            product_id,
            group_id,
            item_product_id,
            name,
            type,
            extra_price_minor,
            is_active
          ) VALUES (1, 1, 2, 'Tea', 'choice', 0, 1);
        ''');

        final QueryRow choiceRow = await db.customSelect('''
          SELECT
            product_id,
            group_id,
            item_product_id,
            type,
            extra_price_minor
          FROM product_modifiers
          WHERE type = 'choice'
          ORDER BY id DESC
          LIMIT 1
        ''').getSingle();

        expect(choiceRow.read<int>('product_id'), 1);
        expect(choiceRow.read<int>('group_id'), 1);
        expect(choiceRow.read<int>('item_product_id'), 2);
        expect(choiceRow.read<String>('type'), 'choice');
        expect(choiceRow.read<int>('extra_price_minor'), 0);
      },
    );

    test(
      'non-choice rows remain valid with null item_product_id after migration',
      () async {
        final AppDatabase db = _createV17ThenMigrateToCurrent();
        addTearDown(db.close);

        await db.customStatement('''
          INSERT INTO product_modifiers (
            product_id,
            group_id,
            item_product_id,
            name,
            type,
            extra_price_minor,
            is_active
          ) VALUES (1, NULL, NULL, 'Extra Bacon', 'extra', 200, 1);
        ''');

        final QueryRow row = await db.customSelect('''
          SELECT
            group_id,
            item_product_id,
            type
          FROM product_modifiers
          WHERE name = 'Extra Bacon'
        ''').getSingle();

        expect(row.read<int?>('group_id'), isNull);
        expect(row.read<int?>('item_product_id'), isNull);
        expect(row.read<String>('type'), 'extra');
      },
    );

    test(
      'fresh and migrated product_modifiers schemas expose the same columns',
      () async {
        final AppDatabase freshDb = createTestDatabase();
        final AppDatabase migratedDb = _createV17ThenMigrateToCurrent();
        addTearDown(freshDb.close);
        addTearDown(migratedDb.close);

        final List<String> freshColumns = await _readTableColumns(
          freshDb,
          'product_modifiers',
        );
        final List<String> migratedColumns = await _readTableColumns(
          migratedDb,
          'product_modifiers',
        );

        expect(freshColumns, migratedColumns);
      },
    );
  });
}

AppDatabase _createV17ThenMigrateToCurrent() {
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
          min_select INTEGER NOT NULL DEFAULT 0 CHECK (min_select >= 0),
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
      database.execute(
        "INSERT INTO categories (id, name, sort_order, is_active, removal_discount_1_minor, removal_discount_2_minor) VALUES (1, 'Set Breakfast', 0, 1, 0, 0);",
      );
      database.execute(
        "INSERT INTO categories (id, name, sort_order, is_active, removal_discount_1_minor, removal_discount_2_minor) VALUES (2, 'Hot Drink', 1, 1, 0, 0);",
      );
      database.execute(
        "INSERT INTO products (id, category_id, name, price_minor, has_modifiers, is_active, is_visible_on_pos, sort_order) VALUES (1, 1, 'Set 4', 400, 1, 1, 1, 0);",
      );
      database.execute(
        "INSERT INTO products (id, category_id, name, price_minor, has_modifiers, is_active, is_visible_on_pos, sort_order) VALUES (2, 2, 'Tea', 150, 0, 1, 1, 0);",
      );
      database.execute(
        "INSERT INTO modifier_groups (id, product_id, name, min_select, max_select, included_quantity, sort_order) VALUES (1, 1, 'Tea or Coffee', 0, 1, 1, 1);",
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
      database.execute('PRAGMA user_version = 17;');
    },
  );

  return AppDatabase(rawDb);
}

Future<List<String>> _readTableColumns(AppDatabase db, String tableName) async {
  final List<QueryRow> rows = await db
      .customSelect('PRAGMA table_info($tableName)')
      .get();
  return rows
      .map((QueryRow row) => row.read<String>('name'))
      .toList(growable: false);
}
