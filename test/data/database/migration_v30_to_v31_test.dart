import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration v30 -> current', () {
    test(
      'maps legacy sandwich sauce text config to Sauces-category products and audits unmatched values',
      () async {
        final AppDatabase db = _createV30ThenMigrateToCurrent();
        addTearDown(db.close);

        final row = await db.customSelect('''
          SELECT sandwich_sauce_options_json
          FROM meal_adjustment_profiles
          WHERE id = 1
        ''').getSingle();
        expect(row.read<String>('sandwich_sauce_options_json'), '[10]');

        final auditRows = await db.customSelect('''
          SELECT legacy_value, matched_product_id, matched_product_name, status
          FROM sandwich_sauce_migration_audits
          WHERE profile_id = 1
          ORDER BY id ASC
        ''').get();

        expect(auditRows, hasLength(2));
        expect(auditRows[0].read<String>('legacy_value'), 'mayo');
        expect(auditRows[0].read<int?>('matched_product_id'), 10);
        expect(
          auditRows[0].read<String?>('matched_product_name'),
          'Mayonnaise',
        );
        expect(auditRows[0].read<String>('status'), 'mapped');
        expect(auditRows[1].read<String>('legacy_value'), 'mysterySauce');
        expect(auditRows[1].read<int?>('matched_product_id'), isNull);
        expect(auditRows[1].read<String>('status'), 'unmatched');
      },
    );
  });
}

AppDatabase _createV30ThenMigrateToCurrent() {
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
          sandwich_surcharge_minor INTEGER NOT NULL DEFAULT 100 CHECK (sandwich_surcharge_minor >= 0),
          baguette_surcharge_minor INTEGER NOT NULL DEFAULT 180 CHECK (baguette_surcharge_minor >= 0),
          sandwich_sauce_options_json TEXT NOT NULL DEFAULT '["ketchup","mayo","brownSauce","chilliSauce"]',
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (unixepoch()),
          updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
          CHECK (length(trim(name)) > 0)
        );
      ''');
      database.execute(
        "INSERT INTO categories (id, name, is_active) VALUES (1, 'Sauces', 1);",
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
        ) VALUES
          (10, 1, NULL, 'Mayonnaise', 0, NULL, 0, 1, 1, 0),
          (11, 1, NULL, 'Brown Sauce', 0, NULL, 0, 0, 1, 1)
      ''');
      database.execute('''
        INSERT INTO meal_adjustment_profiles (
          id,
          name,
          profile_kind,
          free_swap_limit,
          sandwich_sauce_options_json,
          is_active
        ) VALUES (
          1,
          'Sandwich Profile',
          'sandwich',
          0,
          '["mayo","mysterySauce"]',
          1
        )
      ''');
      database.execute('PRAGMA user_version = 30;');
    },
  );

  return AppDatabase(rawDb);
}
