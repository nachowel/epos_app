import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Migration v22 -> current', () {
    test(
      'migrated database adds meal adjustment tables and products column',
      () async {
        final AppDatabase db = _createV22ThenMigrateToCurrent();
        addTearDown(db.close);

        expect(await _tableExists(db, 'meal_adjustment_profiles'), isTrue);
        expect(
          await _tableExists(db, 'meal_adjustment_profile_components'),
          isTrue,
        );
        expect(
          await _tableExists(db, 'meal_adjustment_component_options'),
          isTrue,
        );
        expect(
          await _tableExists(db, 'meal_adjustment_profile_extras'),
          isTrue,
        );
        expect(await _tableExists(db, 'meal_adjustment_pricing_rules'), isTrue);
        expect(
          await _tableExists(db, 'meal_adjustment_pricing_rule_conditions'),
          isTrue,
        );

        final List<String> productColumns = await _readTableColumns(
          db,
          'products',
        );
        expect(productColumns, contains('meal_adjustment_profile_id'));
      },
    );

    test(
      'fresh and migrated schemas expose the same meal adjustment table columns',
      () async {
        final AppDatabase freshDb = createTestDatabase();
        final AppDatabase migratedDb = _createV22ThenMigrateToCurrent();
        addTearDown(freshDb.close);
        addTearDown(migratedDb.close);

        final List<String> freshProfileColumns = await _readTableColumns(
          freshDb,
          'meal_adjustment_profiles',
        );
        final List<String> migratedProfileColumns = await _readTableColumns(
          migratedDb,
          'meal_adjustment_profiles',
        );
        final List<String> freshProductColumns = await _readTableColumns(
          freshDb,
          'products',
        );
        final List<String> migratedProductColumns = await _readTableColumns(
          migratedDb,
          'products',
        );

        expect(freshProfileColumns, unorderedEquals(migratedProfileColumns));
        expect(freshProductColumns, unorderedEquals(migratedProductColumns));
      },
    );

    test(
      'migrated products preserve legacy rows and nullable binding',
      () async {
        final AppDatabase db = _createV22ThenMigrateToCurrent();
        addTearDown(db.close);

        final QueryRow row = await db.customSelect('''
            SELECT
              id,
              category_id,
              name,
              price_minor,
              meal_adjustment_profile_id
            FROM products
            WHERE id = 1
            ''').getSingle();

        expect(row.read<int>('id'), 1);
        expect(row.read<int>('category_id'), 1);
        expect(row.read<String>('name'), 'Chicken Burger');
        expect(row.read<int>('price_minor'), 995);
        expect(row.readNullable<int>('meal_adjustment_profile_id'), isNull);
      },
    );
  });
}

AppDatabase _createV22ThenMigrateToCurrent() {
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
        INSERT INTO categories (
          id,
          name,
          image_url,
          sort_order,
          is_active,
          removal_discount_1_minor,
          removal_discount_2_minor
        ) VALUES (1, 'Mains', NULL, 0, 1, 0, 0);
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
        ) VALUES (1, 1, 'Chicken Burger', 995, NULL, 0, 1, 1, 0);
      ''');
      database.execute('PRAGMA user_version = 22;');
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

Future<bool> _tableExists(AppDatabase db, String tableName) async {
  final QueryRow? row = await db
      .customSelect(
        '''
        SELECT name
        FROM sqlite_master
        WHERE type = 'table' AND name = ?
        ''',
        variables: <Variable<Object>>[Variable<String>(tableName)],
      )
      .getSingleOrNull();
  return row != null;
}
