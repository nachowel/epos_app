import 'package:flutter_test/flutter_test.dart';

import '../../tool/destructive_migration_checker.dart';

void main() {
  group('findDestructiveMigrationWarnings', () {
    test('flags table drops and broad deletes as warnings', () {
      final List<DestructiveMigrationWarning> warnings =
          findDestructiveMigrationWarnings('''
await customStatement('DROP TABLE users;');
await customStatement('DELETE FROM product_modifiers WHERE product_id = ?');
await customStatement('DROP INDEX product_name_idx;');
''');

      expect(warnings, hasLength(2));
      expect(warnings[0].lineNumber, 1);
      expect(warnings[0].kind, DestructiveMigrationKind.dropTable);
      expect(warnings[1].lineNumber, 2);
      expect(warnings[1].kind, DestructiveMigrationKind.deleteFrom);
    });

    test('flags legacy table rebuild renames as review warnings', () {
      final List<DestructiveMigrationWarning> warnings =
          findDestructiveMigrationWarnings('''
await customStatement('ALTER TABLE payments RENAME TO payments_legacy_v37;');
await customStatement('ALTER TABLE products ADD COLUMN image_url TEXT NULL;');
''');

      expect(warnings, hasLength(1));
      expect(warnings.single.kind, DestructiveMigrationKind.legacyTableRename);
    });
  });
}
