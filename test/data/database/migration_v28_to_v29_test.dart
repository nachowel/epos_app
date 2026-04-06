import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration v28 -> current', () {
    test(
      'rebuilds product_modifiers with relaxed choice nullability and preserves FK enforcement',
      () async {
        final AppDatabase db = _createV28ThenMigrateToCurrent();
        addTearDown(db.close);

        final QueryRow schemaRow = await db.customSelect('''
          SELECT sql
          FROM sqlite_master
          WHERE type = 'table' AND name = 'product_modifiers'
        ''').getSingle();
        final String schemaSql = schemaRow.read<String>('sql');
        expect(
          schemaSql,
          contains("CHECK ((type = 'choice' AND group_id IS NOT NULL)"),
        );
        expect(schemaSql, isNot(contains('item_product_id IS NOT NULL')));

        final List<QueryRow> triggerRows = await db.customSelect('''
          SELECT name
          FROM sqlite_master
          WHERE type = 'trigger'
            AND tbl_name = 'product_modifiers'
          ORDER BY name
        ''').get();
        expect(
          triggerRows.map((QueryRow row) => row.read<String>('name')),
          containsAll(<String>[
            'fk_product_modifiers_product_id_insert',
            'fk_product_modifiers_product_id_update',
            'fk_product_modifiers_group_id_insert',
            'fk_product_modifiers_group_id_update',
            'fk_product_modifiers_item_product_id_insert',
            'fk_product_modifiers_item_product_id_update',
          ]),
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
          ) VALUES (
            1,
            1,
            NULL,
            'No drink',
            'choice',
            0,
            1
          )
        ''');

        final QueryRow explicitNoneRow = await db.customSelect('''
          SELECT item_product_id, name
          FROM product_modifiers
          WHERE name = 'No drink'
        ''').getSingle();
        expect(explicitNoneRow.read<int?>('item_product_id'), isNull);

        await expectLater(
          () => db.customStatement('''
            INSERT INTO product_modifiers (
              product_id,
              group_id,
              item_product_id,
              name,
              type,
              extra_price_minor,
              is_active
            ) VALUES (
              999,
              1,
              NULL,
              'Broken root',
              'choice',
              0,
              1
            )
          '''),
          throwsA(isA<Object>()),
        );
        await expectLater(
          () => db.customStatement('''
            INSERT INTO product_modifiers (
              product_id,
              group_id,
              item_product_id,
              name,
              type,
              extra_price_minor,
              is_active
            ) VALUES (
              1,
              999,
              NULL,
              'Broken group',
              'choice',
              0,
              1
            )
          '''),
          throwsA(isA<Object>()),
        );
        await expectLater(
          () => db.customStatement('''
            INSERT INTO product_modifiers (
              product_id,
              group_id,
              item_product_id,
              name,
              type,
              extra_price_minor,
              is_active
            ) VALUES (
              1,
              1,
              999,
              'Broken member',
              'choice',
              0,
              1
            )
          '''),
          throwsA(isA<Object>()),
        );
      },
    );
  });
}

AppDatabase _createV28ThenMigrateToCurrent() {
  final NativeDatabase rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
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
        CREATE TABLE modifier_groups (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          min_select INTEGER NOT NULL DEFAULT 0,
          max_select INTEGER NOT NULL DEFAULT 1,
          included_quantity INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0,
          UNIQUE(product_id, name)
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
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          CHECK ((type = 'choice' AND group_id IS NOT NULL AND item_product_id IS NOT NULL) OR (type IN ('included','extra') AND group_id IS NULL))
        );
      ''');
      database.execute(
        'CREATE INDEX idx_product_modifiers_prod ON product_modifiers(product_id, is_active);',
      );
      database.execute(
        'CREATE INDEX idx_product_modifiers_group ON product_modifiers(group_id, is_active);',
      );
      database.execute(
        'CREATE INDEX idx_product_modifiers_item_product ON product_modifiers(item_product_id, type);',
      );
      database.execute('''
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
        ) VALUES (1, 1, NULL, 'Set Breakfast', 600, NULL, 0, 1, 1, 0)
      ''');
      database.execute('''
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
        ) VALUES (2, 1, NULL, 'Tea', 150, NULL, 0, 1, 1, 1)
      ''');
      database.execute('''
        INSERT INTO modifier_groups (
          id,
          product_id,
          name,
          min_select,
          max_select,
          included_quantity,
          sort_order
        ) VALUES (1, 1, 'Drink choice', 1, 1, 1, 0)
      ''');
      database.execute('''
        INSERT INTO product_modifiers (
          id,
          product_id,
          group_id,
          item_product_id,
          name,
          type,
          extra_price_minor,
          is_active
        ) VALUES (1, 1, 1, 2, 'Tea', 'choice', 0, 1)
      ''');
      database.execute('PRAGMA user_version = 28;');
    },
  );

  return AppDatabase(rawDb);
}
