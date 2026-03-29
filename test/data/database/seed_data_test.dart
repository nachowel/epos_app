import 'package:epos_app/data/database/seed_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('SeedData', () {
    test(
      'inserts hashed demo credentials only once into an empty database',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        await SeedData.insertIfEmpty(db);
        await SeedData.insertIfEmpty(db);

        final users = await db.select(db.users).get();
        final categories = await db.select(db.categories).get();
        final products = await db.select(db.products).get();
        final modifiers = await db.select(db.productModifiers).get();
        final reportSettings = await db.select(db.reportSettings).get();

        expect(users, hasLength(2));
        expect(
          users.every((user) => user.pin?.startsWith('sha256:') ?? false),
          isTrue,
        );
        expect(
          users.any((user) => user.pin == '1234' || user.pin == '0000'),
          isFalse,
        );
        expect(categories.length, 4);
        expect(products.length, greaterThanOrEqualTo(15));
        expect(modifiers.length, greaterThanOrEqualTo(20));
        expect(reportSettings, hasLength(1));
      },
    );
  });
}
