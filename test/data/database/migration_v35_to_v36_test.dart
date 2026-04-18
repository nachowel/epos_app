import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Migration v35 -> v36 products rebuild', () {
    test(
      'rebuilds products into canonical order and preserves data, indexes, and FK behavior',
      () async {
        final File file = await _createV35DatabaseFile();
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
        expect(
          productColumns
              .map((dynamic row) => row.read<String>('name'))
              .toList(),
          equals(<String>[
            'id',
            'category_id',
            'meal_adjustment_profile_id',
            'name',
            'price_minor',
            'image_url',
            'has_modifiers',
            'is_active',
            'is_visible_on_pos',
            'is_custom',
            'sort_order',
          ]),
        );

        final dynamic row = await db.customSelect('''
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
          WHERE id = 1
        ''').getSingle();
        expect(row.read<int>('id'), 1);
        expect(row.read<int>('category_id'), 1);
        expect(row.read<int?>('meal_adjustment_profile_id'), 50);
        expect(row.read<String>('name'), 'Burger');
        expect(row.read<int>('price_minor'), 900);
        expect(row.read<String?>('image_url'), 'burger.png');
        expect(row.read<int>('has_modifiers'), 1);
        expect(row.read<int>('is_active'), 1);
        expect(row.read<int>('is_visible_on_pos'), 1);
        expect(row.read<int>('is_custom'), 0);
        expect(row.read<int>('sort_order'), 4);

        final List<dynamic> indexRows = await db
            .customSelect('PRAGMA index_list(products);')
            .get();
        final Set<String> indexNames = indexRows
            .map((dynamic row) => row.read<String>('name'))
            .cast<String>()
            .toSet();
        expect(indexNames, contains('idx_products_category'));
        expect(indexNames, contains('idx_products_meal_adjustment_profile'));
        expect(indexNames, contains('ux_products_single_custom_product'));

        final List<dynamic> triggerRows = await db.customSelect('''
          SELECT name
          FROM sqlite_master
          WHERE type = 'trigger'
            AND tbl_name = 'products'
          ORDER BY name ASC
        ''').get();
        final Set<String> triggerNames = triggerRows
            .map((dynamic row) => row.read<String>('name'))
            .cast<String>()
            .toSet();
        expect(triggerNames, contains('fk_products_category_id_insert'));
        expect(triggerNames, contains('fk_products_category_id_update'));
        expect(
          triggerNames,
          contains('fk_products_meal_adjustment_profile_id_insert'),
        );
        expect(
          triggerNames,
          contains('fk_products_meal_adjustment_profile_id_update'),
        );

        await expectLater(
          db.customStatement('''
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
            ) VALUES (999, NULL, 'Broken Category', 100, NULL, 0, 1, 1, 0, 9);
          '''),
          throwsA(isA<Object>()),
        );

        await expectLater(
          db.customStatement('''
            UPDATE products
            SET meal_adjustment_profile_id = 999
            WHERE id = 1
          '''),
          throwsA(isA<Object>()),
        );

        await expectLater(
          db.customStatement('''
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
            ) VALUES (2, NULL, 'Duplicate Custom', 0, NULL, 0, 1, 0, 1, 0);
          '''),
          throwsA(isA<Object>()),
        );
      },
    );
  });
}

Future<File> _createV35DatabaseFile() async {
  final Directory dir = await Directory.systemTemp.createTemp(
    'epos-migration-v35-v36-',
  );
  final File file = File('${dir.path}/migration.sqlite');
  final sqlite3.Database raw = sqlite3.sqlite3.open(file.path);
  try {
    raw.execute('PRAGMA user_version = 35;');
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
      CREATE TABLE meal_adjustment_profiles (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NULL,
        profile_kind TEXT NOT NULL DEFAULT 'standard' CHECK (profile_kind IN ('standard','sandwich')),
        free_swap_limit INTEGER NOT NULL DEFAULT 0 CHECK (free_swap_limit >= 0),
        sandwich_surcharge_minor INTEGER NOT NULL DEFAULT 100 CHECK (sandwich_surcharge_minor >= 0),
        baguette_surcharge_minor INTEGER NOT NULL DEFAULT 180 CHECK (baguette_surcharge_minor >= 0),
        sandwich_sauce_options_json TEXT NOT NULL DEFAULT '[]',
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (unixepoch()),
        updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
        CHECK (length(trim(name)) > 0)
      );
    ''');
    raw.execute('''
      CREATE TABLE products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
        image_url TEXT NULL,
        has_modifiers INTEGER NOT NULL DEFAULT 0 CHECK (has_modifiers IN (0, 1)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        is_visible_on_pos INTEGER NOT NULL DEFAULT 1 CHECK (is_visible_on_pos IN (0, 1)),
        sort_order INTEGER NOT NULL DEFAULT 0,
        meal_adjustment_profile_id INTEGER NULL,
        is_custom INTEGER NOT NULL DEFAULT 0 CHECK (is_custom IN (0, 1))
      );
    ''');

    raw.execute('''
      INSERT INTO categories (id, name, sort_order, is_active)
      VALUES
        (1, 'Mains', 0, 1),
        (2, 'Archived Products', 9999, 1);
    ''');
    raw.execute('''
      INSERT INTO meal_adjustment_profiles (
        id,
        name,
        description,
        profile_kind,
        free_swap_limit,
        sandwich_surcharge_minor,
        baguette_surcharge_minor,
        sandwich_sauce_options_json,
        is_active,
        created_at,
        updated_at
      ) VALUES (
        50,
        'Lunch Profile',
        NULL,
        'standard',
        1,
        100,
        180,
        '[]',
        1,
        unixepoch(),
        unixepoch()
      );
    ''');
    raw.execute('''
      INSERT INTO products (
        id,
        category_id,
        name,
        price_minor,
        image_url,
        has_modifiers,
        is_active,
        is_visible_on_pos,
        sort_order,
        meal_adjustment_profile_id,
        is_custom
      ) VALUES
        (1, 1, 'Burger', 900, 'burger.png', 1, 1, 1, 4, 50, 0),
        (2, 2, 'Custom Sale', 0, NULL, 0, 1, 0, 0, NULL, 1);
    ''');
  } finally {
    raw.dispose();
  }

  return file;
}
