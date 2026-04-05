import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Migration v21 -> current', () {
    test(
      'migrated database adds breakfast_cooking_instructions table',
      () async {
        final AppDatabase db = _createV21ThenMigrateToCurrent();
        addTearDown(db.close);

        final List<String> columns = await _readTableColumns(
          db,
          'breakfast_cooking_instructions',
        );
        expect(
          columns,
          containsAll(<String>[
            'uuid',
            'transaction_line_id',
            'item_product_id',
            'item_name',
            'instruction_code',
            'instruction_label',
            'applied_quantity',
            'sort_key',
          ]),
        );
      },
    );

    test(
      'fresh and migrated breakfast_cooking_instructions schemas expose the same columns',
      () async {
        final AppDatabase freshDb = createTestDatabase();
        final AppDatabase migratedDb = _createV21ThenMigrateToCurrent();
        addTearDown(freshDb.close);
        addTearDown(migratedDb.close);

        final List<String> freshColumns = await _readTableColumns(
          freshDb,
          'breakfast_cooking_instructions',
        );
        final List<String> migratedColumns = await _readTableColumns(
          migratedDb,
          'breakfast_cooking_instructions',
        );

        expect(freshColumns, unorderedEquals(migratedColumns));
      },
    );

    test(
      'migrated schema rejects invalid transaction_line_id values',
      () async {
        final AppDatabase db = _createV21ThenMigrateToCurrent();
        addTearDown(db.close);

        await expectLater(
          db.customStatement('''
          INSERT INTO breakfast_cooking_instructions (
            uuid,
            transaction_line_id,
            item_product_id,
            item_name,
            instruction_code,
            instruction_label,
            applied_quantity,
            sort_key
          ) VALUES (
            'instruction-invalid-line',
            999,
            1,
            'Egg',
            'runny',
            'Runny',
            1,
            1
          );
        '''),
          throwsException,
        );
      },
    );
  });
}

AppDatabase _createV21ThenMigrateToCurrent() {
  final QueryExecutor rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
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
        INSERT INTO products (
          id,
          category_id,
          name,
          price_minor,
          image_url,
          has_modifiers,
          is_active,
          is_visible_on_pos,
          sort_order
        ) VALUES (1, 1, 'Egg', 120, NULL, 0, 1, 1, 0);
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
          line_total_minor,
          pricing_mode,
          removal_discount_total_minor
        ) VALUES (1, 'line-1', 1, 1, 'Set Breakfast', 600, 1, 600, 'set', 0);
      ''');
      database.execute('PRAGMA user_version = 21;');
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
