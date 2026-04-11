import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration v29 -> current', () {
    test(
      'adds structured flat modifier columns and upgrades the seeded burger config',
      () async {
        final AppDatabase db = _createV29ThenMigrateToCurrent();
        addTearDown(db.close);

        final QueryRow productModifierSchema = await db.customSelect('''
          SELECT sql
          FROM sqlite_master
          WHERE type = 'table' AND name = 'product_modifiers'
        ''').getSingle();
        final QueryRow orderModifierSchema = await db.customSelect('''
          SELECT sql
          FROM sqlite_master
          WHERE type = 'table' AND name = 'order_modifiers'
        ''').getSingle();

        expect(
          productModifierSchema.read<String>('sql'),
          contains('price_behavior'),
        );
        expect(
          productModifierSchema.read<String>('sql'),
          contains('ui_section'),
        );
        expect(
          orderModifierSchema.read<String>('sql'),
          contains('price_behavior'),
        );
        expect(orderModifierSchema.read<String>('sql'), contains('ui_section'));

        final List<QueryRow> burgerModifiers = await db.customSelect('''
          SELECT name, type, extra_price_minor, price_behavior, ui_section
          FROM product_modifiers
          WHERE product_id = 1
          ORDER BY id ASC
        ''').get();

        expect(
          burgerModifiers.map((QueryRow row) => row.read<String>('name')),
          <String>[
            'Fried onion',
            'Salad',
            'Ketchup',
            'Brown sauce',
            'Burger sauce',
            'Mayonnaise',
            'Chips',
            'Beans',
          ],
        );
        expect(
          burgerModifiers
              .take(6)
              .every(
                (QueryRow row) => row.read<String?>('price_behavior') == 'free',
              ),
          isTrue,
        );
        expect(
          burgerModifiers
              .take(2)
              .every(
                (QueryRow row) => row.read<String?>('ui_section') == 'toppings',
              ),
          isTrue,
        );
        expect(
          burgerModifiers
              .skip(2)
              .take(4)
              .every(
                (QueryRow row) => row.read<String?>('ui_section') == 'sauces',
              ),
          isTrue,
        );
        expect(
          burgerModifiers
              .skip(6)
              .every(
                (QueryRow row) => row.read<String?>('ui_section') == 'add_ins',
              ),
          isTrue,
        );
        expect(burgerModifiers[6].read<int>('extra_price_minor'), 110);
        expect(burgerModifiers[7].read<int>('extra_price_minor'), 80);
      },
    );
  });
}

AppDatabase _createV29ThenMigrateToCurrent() {
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
        CREATE TABLE product_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          group_id INTEGER NULL,
          item_product_id INTEGER NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('included','extra','choice')),
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          CHECK ((type = 'choice' AND group_id IS NOT NULL) OR (type IN ('included','extra') AND group_id IS NULL))
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
        "INSERT INTO categories (id, name, is_active) VALUES (1, 'Mains', 1);",
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
        ) VALUES (1, 1, NULL, 'Burger', 900, NULL, 1, 1, 1, 0)
      ''');
      database.execute('''
        INSERT INTO product_modifiers (
          product_id, group_id, item_product_id, name, type, extra_price_minor, is_active
        ) VALUES
          (1, NULL, NULL, 'Lettuce', 'included', 0, 1),
          (1, NULL, NULL, 'Tomato', 'included', 0, 1),
          (1, NULL, NULL, 'Onion', 'included', 0, 1),
          (1, NULL, NULL, 'Cheese', 'extra', 100, 1),
          (1, NULL, NULL, 'Bacon', 'extra', 150, 1),
          (1, NULL, NULL, 'Extra Patty', 'extra', 300, 1)
      ''');
      database.execute('PRAGMA user_version = 29;');
    },
  );

  return AppDatabase(rawDb);
}
