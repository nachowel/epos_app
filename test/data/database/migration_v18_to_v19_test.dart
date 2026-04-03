import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Migration v18 -> current', () {
    test(
      'migrated database preserves legacy order_modifiers rows and adds semantic columns',
      () async {
        final AppDatabase db = _createV18ThenMigrateToCurrent();
        addTearDown(db.close);

        final List<String> columns = await _readTableColumns(
          db,
          'order_modifiers',
        );
        expect(
          columns,
          containsAll(<String>[
            'unit_price_minor',
            'price_effect_minor',
            'sort_key',
            'source_group_id',
          ]),
        );

        final QueryRow row = await db.customSelect('''
          SELECT
            action,
            item_name,
            quantity,
            item_product_id,
            extra_price_minor,
            charge_reason,
            unit_price_minor,
            price_effect_minor,
            sort_key,
            source_group_id
          FROM order_modifiers
          WHERE id = 1
        ''').getSingle();

        expect(row.read<String>('action'), 'add');
        expect(row.read<String>('item_name'), 'Extra Bacon');
        expect(row.read<int>('quantity'), 1);
        expect(row.read<int?>('item_product_id'), isNull);
        expect(row.read<int>('extra_price_minor'), 150);
        expect(row.read<String?>('charge_reason'), isNull);
        expect(row.read<int>('unit_price_minor'), 150);
        expect(row.read<int>('price_effect_minor'), 150);
        expect(row.read<int>('sort_key'), 0);
        expect(row.read<int?>('source_group_id'), isNull);
      },
    );

    test(
      'fresh and migrated order_modifiers schemas expose the same columns',
      () async {
        final AppDatabase freshDb = createTestDatabase();
        final AppDatabase migratedDb = _createV18ThenMigrateToCurrent();
        addTearDown(freshDb.close);
        addTearDown(migratedDb.close);

        final List<String> freshColumns = await _readTableColumns(
          freshDb,
          'order_modifiers',
        );
        final List<String> migratedColumns = await _readTableColumns(
          migratedDb,
          'order_modifiers',
        );

        expect(freshColumns, unorderedEquals(migratedColumns));
      },
    );
  });
}

AppDatabase _createV18ThenMigrateToCurrent() {
  final QueryExecutor rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
      database.execute('''
        CREATE TABLE order_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_line_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (action IN ('remove','add','choice')),
          item_name TEXT NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
          item_product_id INTEGER NULL,
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          charge_reason TEXT NULL CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount')),
          CHECK (action != 'choice' OR charge_reason = 'included_choice')
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
      database.execute(
        "INSERT INTO transaction_lines (id, uuid, transaction_id, product_id, product_name, unit_price_minor, quantity, line_total_minor, pricing_mode, removal_discount_total_minor) VALUES (1, 'line-1', 1, 1, 'Set 4', 400, 1, 550, 'set', 0);",
      );
      database.execute(
        "INSERT INTO order_modifiers (id, uuid, transaction_line_id, action, item_name, quantity, item_product_id, extra_price_minor, charge_reason) VALUES (1, 'modifier-1', 1, 'add', 'Extra Bacon', 1, NULL, 150, NULL);",
      );
      database.execute(
        'CREATE INDEX idx_order_modifiers_line ON order_modifiers(transaction_line_id);',
      );
      database.execute(
        'CREATE INDEX idx_order_modifiers_item_product ON order_modifiers(item_product_id, charge_reason);',
      );
      database.execute('PRAGMA user_version = 18;');
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
