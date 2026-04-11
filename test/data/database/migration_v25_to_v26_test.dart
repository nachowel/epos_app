import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration v25 -> current', () {
    test('adds meal profile kind with standard default', () async {
      final AppDatabase db = _createV25ThenMigrateToCurrent();
      addTearDown(db.close);

      final row = await db.customSelect('''
        SELECT profile_kind
        FROM meal_adjustment_profiles
        WHERE id = 1
        ''').getSingle();

      expect(row.read<String>('profile_kind'), 'standard');

      await db.customStatement('''
        INSERT INTO meal_adjustment_profiles (
          id,
          name,
          profile_kind,
          free_swap_limit,
          is_active
        ) VALUES (
          2,
          'Sandwich Profile',
          'sandwich',
          0,
          1
        )
      ''');

      final inserted = await db.customSelect('''
        SELECT profile_kind
        FROM meal_adjustment_profiles
        WHERE id = 2
        ''').getSingle();

      expect(inserted.read<String>('profile_kind'), 'sandwich');
    });
  });
}

AppDatabase _createV25ThenMigrateToCurrent() {
  final NativeDatabase rawDb = NativeDatabase.memory(
    setup: (database) {
      database.execute('PRAGMA foreign_keys = OFF;');
      database.execute('''
        CREATE TABLE meal_adjustment_profiles (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT NULL,
          free_swap_limit INTEGER NOT NULL DEFAULT 0 CHECK (free_swap_limit >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (unixepoch()),
          updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
          CHECK (length(trim(name)) > 0)
        );
      ''');
      database.execute(
        "INSERT INTO meal_adjustment_profiles (id, name, free_swap_limit, is_active) VALUES (1, 'Profile', 0, 1);",
      );
      database.execute('PRAGMA user_version = 25;');
    },
  );

  return AppDatabase(rawDb);
}
