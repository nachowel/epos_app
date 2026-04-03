import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/admin_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('Admin product lifecycle hardening', () {
    test(
      'standard product with semantic references requires explicit confirmation',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int categoryId = await insertCategory(db, name: 'Breakfast');
        final int setProductId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Set Breakfast',
          priceMinor: 850,
        );
        final int baconId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Bacon',
          priceMinor: 200,
        );

        await db
            .into(db.setItems)
            .insert(
              app_db.SetItemsCompanion.insert(
                productId: setProductId,
                itemProductId: baconId,
              ),
            );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final AdminService service = container.read(adminServiceProvider);

        expect(
          () => service.deleteProduct(user: _adminUser(adminId), id: baconId),
          throwsA(
            isA<ValidationException>().having(
              (ValidationException error) => error.message,
              'message',
              'This product is used by other set configurations. Deleting it may affect those sets.',
            ),
          ),
        );

        final ProductDeleteOutcome outcome = await service.deleteProduct(
          user: _adminUser(adminId),
          id: baconId,
          confirmSemanticImpact: true,
        );
        expect(outcome, ProductDeleteOutcome.deleted);
        expect(await ProductRepository(db).getById(baconId), isNull);

        final List<app_db.SetItem> setItems = await db
            .select(db.setItems)
            .get();
        expect(setItems, isEmpty);
      },
    );

    test(
      'unused set product delete removes only the set root and its own config',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int categoryId = await insertCategory(db, name: 'Breakfast');
        final int setFourId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Set 4 Breakfast',
          priceMinor: 950,
        );
        final int setTwoId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Set 2 Breakfast',
          priceMinor: 750,
        );
        final int baconId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Bacon',
          priceMinor: 200,
        );
        final int teaId = await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Tea',
          priceMinor: 150,
        );

        await db
            .into(db.setItems)
            .insert(
              app_db.SetItemsCompanion.insert(
                productId: setFourId,
                itemProductId: baconId,
              ),
            );
        await db
            .into(db.setItems)
            .insert(
              app_db.SetItemsCompanion.insert(
                productId: setTwoId,
                itemProductId: baconId,
              ),
            );
        final int setFourDrinkGroupId = await db
            .into(db.modifierGroups)
            .insert(
              app_db.ModifierGroupsCompanion.insert(
                productId: setFourId,
                name: 'Drink',
              ),
            );
        await db
            .into(db.productModifiers)
            .insert(
              app_db.ProductModifiersCompanion.insert(
                productId: setFourId,
                groupId: Value<int?>(setFourDrinkGroupId),
                itemProductId: Value<int?>(teaId),
                name: 'Tea',
                type: 'choice',
              ),
            );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final AdminService service = container.read(adminServiceProvider);

        final ProductDeleteOutcome outcome = await service.deleteProduct(
          user: _adminUser(adminId),
          id: setFourId,
        );
        expect(outcome, ProductDeleteOutcome.deleted);

        expect(await ProductRepository(db).getById(setFourId), isNull);
        expect(await ProductRepository(db).getById(setTwoId), isNotNull);
        expect(await ProductRepository(db).getById(baconId), isNotNull);

        final List<app_db.SetItem> remainingSetItems = await db
            .select(db.setItems)
            .get();
        expect(
          remainingSetItems.where(
            (app_db.SetItem item) => item.productId == setFourId,
          ),
          isEmpty,
        );
        expect(
          remainingSetItems.where(
            (app_db.SetItem item) => item.productId == setTwoId,
          ),
          hasLength(1),
        );
      },
    );

    test('used set product is archived instead of hard deleted', () async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int categoryId = await insertCategory(db, name: 'Breakfast');
      final int setProductId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Set Breakfast',
        priceMinor: 850,
      );
      final int shiftId = await insertShift(db, openedBy: adminId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'historic-set-order',
        shiftId: shiftId,
        userId: adminId,
        status: 'paid',
        totalAmountMinor: 850,
        paidAt: DateTime.now(),
      );
      await db
          .into(db.transactionLines)
          .insert(
            app_db.TransactionLinesCompanion.insert(
              uuid: 'historic-set-line',
              transactionId: transactionId,
              productId: setProductId,
              productName: 'Set Breakfast',
              unitPriceMinor: 850,
              lineTotalMinor: 850,
            ),
          );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final AdminService service = container.read(adminServiceProvider);

      final ProductDeleteOutcome outcome = await service.deleteProduct(
        user: _adminUser(adminId),
        id: setProductId,
      );
      expect(outcome, ProductDeleteOutcome.deactivated);

      final product = await ProductRepository(db).getById(setProductId);
      expect(product, isNotNull);
      expect(product!.isActive, isFalse);
    });

    test(
      'category delete is blocked only by active products and archived products move to fallback category',
      () async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int activeCategoryId = await insertCategory(
          db,
          name: 'Breakfast',
        );
        final int archivedCategoryId = await insertCategory(
          db,
          name: 'Old Specials',
        );
        await insertProduct(
          db,
          categoryId: activeCategoryId,
          name: 'Fresh Bagel',
          priceMinor: 450,
        );
        final int archivedProductId = await insertProduct(
          db,
          categoryId: archivedCategoryId,
          name: 'Legacy Muffin',
          priceMinor: 300,
          isActive: false,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final AdminService service = container.read(adminServiceProvider);

        expect(
          () => service.deleteCategory(
            user: _adminUser(adminId),
            id: activeCategoryId,
          ),
          throwsA(
            isA<ValidationException>().having(
              (ValidationException error) => error.message,
              'message',
              'This category contains active products. Move, archive, or delete them first.',
            ),
          ),
        );

        await service.deleteCategory(
          user: _adminUser(adminId),
          id: archivedCategoryId,
        );

        expect(
          await CategoryRepository(db).getById(archivedCategoryId),
          isNull,
        );

        final product = await ProductRepository(db).getById(archivedProductId);
        expect(product, isNotNull);
        final fallbackCategory = await CategoryRepository(
          db,
        ).findByNameIgnoreCase(AdminService.archivedCategoryName);
        expect(fallbackCategory, isNotNull);
        expect(product!.categoryId, fallbackCategory!.id);
      },
    );
  });
}

User _adminUser(int id) => User(
  id: id,
  name: 'Admin',
  pin: '9999',
  password: null,
  role: UserRole.admin,
  isActive: true,
  createdAt: DateTime.now(),
);
