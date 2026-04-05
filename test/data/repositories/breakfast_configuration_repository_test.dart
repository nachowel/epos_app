import 'package:drift/drift.dart' show OrderingTerm, Value, Variable;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('BreakfastConfigurationRepository', () {
    test(
      'bootstrapBreakfastSetRoot seeds default breakfast choice groups and members once',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastConfigFixture fixture = await _seedFixture(db);
        final BreakfastConfigurationRepository repository =
            BreakfastConfigurationRepository(db);

        await repository.bootstrapBreakfastSetRoot(fixture.rootProductId);
        await repository.bootstrapBreakfastSetRoot(fixture.rootProductId);

        final List<app_db.ModifierGroup> groups =
            await (db.select(db.modifierGroups)
                  ..where(
                    (app_db.$ModifierGroupsTable t) =>
                        t.productId.equals(fixture.rootProductId),
                  )
                  ..orderBy(
                    <OrderingTerm Function(app_db.$ModifierGroupsTable)>[
                      (app_db.$ModifierGroupsTable t) =>
                          OrderingTerm.asc(t.sortOrder),
                      (app_db.$ModifierGroupsTable t) => OrderingTerm.asc(t.id),
                    ],
                  ))
                .get();

        expect(groups, hasLength(2));
        expect(groups.first.name, 'Tea or Coffee');
        expect(groups.first.minSelect, 1);
        expect(groups.first.maxSelect, 1);
        expect(groups.first.includedQuantity, 1);
        expect(groups.first.sortOrder, 1);
        expect(groups.last.name, 'Toast or Bread');
        expect(groups.last.minSelect, 1);
        expect(groups.last.maxSelect, 1);
        expect(groups.last.includedQuantity, 1);
        expect(groups.last.sortOrder, 2);

        final List<app_db.ProductModifier> choiceMembers =
            await (db.select(db.productModifiers)
                  ..where(
                    (app_db.$ProductModifiersTable t) =>
                        t.productId.equals(fixture.rootProductId),
                  )
                  ..where(
                    (app_db.$ProductModifiersTable t) =>
                        t.type.equals('choice'),
                  )
                  ..orderBy(
                    <OrderingTerm Function(app_db.$ProductModifiersTable)>[
                      (app_db.$ProductModifiersTable t) =>
                          OrderingTerm.asc(t.groupId),
                      (app_db.$ProductModifiersTable t) =>
                          OrderingTerm.asc(t.id),
                    ],
                  ))
                .get();
        expect(choiceMembers, hasLength(4));
        expect(
          choiceMembers.map((app_db.ProductModifier row) => row.name),
          <String>['Tea', 'Latte', 'Toasts', 'Breads'],
        );

        final profiles = await repository.loadConfigurationProfiles(<int>[
          fixture.rootProductId,
        ]);
        expect(profiles[fixture.rootProductId]?.hasSemanticSetConfig, isTrue);

        final draft = await repository.loadAdminConfigurationDraft(
          fixture.rootProductId,
        );
        expect(draft.setItems, isEmpty);
        expect(draft.choiceGroups, hasLength(2));
        expect(draft.choiceGroups.map((group) => group.name), <String>[
          'Tea or Coffee',
          'Toast or Bread',
        ]);
        expect(
          draft.choiceGroups.first.members.map((member) => member.itemName),
          <String>['Tea', 'Latte'],
        );
        expect(
          draft.choiceGroups.last.members.map((member) => member.itemName),
          <String>['Toasts', 'Breads'],
        );
      },
    );

    test(
      'bootstrapBreakfastSetRoot tolerates missing default products without crashing',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastConfigFixture fixture = await _seedFixture(
          db,
          includeLatte: false,
          includeToasts: false,
          includeBreads: false,
        );
        final BreakfastConfigurationRepository repository =
            BreakfastConfigurationRepository(db);

        await repository.bootstrapBreakfastSetRoot(fixture.rootProductId);

        final draft = await repository.loadAdminConfigurationDraft(
          fixture.rootProductId,
        );

        expect(draft.choiceGroups, hasLength(2));
        expect(
          draft.choiceGroups.first.members.map((member) => member.itemName),
          <String>['Tea'],
        );
        expect(draft.choiceGroups.last.members, isEmpty);
      },
    );

    test(
      'bootstrapBreakfastSetRoot does not mutate existing sets when template products change later',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastConfigFixture fixture = await _seedFixture(
          db,
          includeLatte: false,
          includeToasts: false,
          includeBreads: false,
        );
        final BreakfastConfigurationRepository repository =
            BreakfastConfigurationRepository(db);

        await repository.bootstrapBreakfastSetRoot(fixture.rootProductId);

        await insertProduct(
          db,
          categoryId: fixture.hotDrinkCategoryId,
          name: 'Latte',
          priceMinor: 180,
        );
        await insertProduct(
          db,
          categoryId: fixture.bakeryCategoryId,
          name: 'Toasts',
          priceMinor: 90,
        );
        await insertProduct(
          db,
          categoryId: fixture.bakeryCategoryId,
          name: 'Breads',
          priceMinor: 90,
        );

        await repository.bootstrapBreakfastSetRoot(fixture.rootProductId);

        final draft = await repository.loadAdminConfigurationDraft(
          fixture.rootProductId,
        );

        expect(
          draft.choiceGroups.first.members.map((member) => member.itemName),
          <String>['Tea'],
        );
        expect(draft.choiceGroups.last.members, isEmpty);
      },
    );

    test('loads a valid breakfast configuration snapshot', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastConfigFixture fixture = await _seedFixture(db);
      final BreakfastConfigurationRepository repository =
          BreakfastConfigurationRepository(db);

      await _insertSetItem(
        db,
        rootProductId: fixture.rootProductId,
        itemProductId: fixture.eggProductId,
        sortOrder: 1,
      );
      final int groupId = await _insertChoiceGroup(
        db,
        rootProductId: fixture.rootProductId,
      );
      await _insertChoiceMember(
        db,
        rootProductId: fixture.rootProductId,
        groupId: groupId,
        itemProductId: fixture.teaProductId,
        label: 'Tea',
      );

      final configuration = await repository.loadSetConfiguration(
        fixture.rootProductId,
      );

      expect(configuration, isNotNull);
      expect(configuration!.setRootProductId, fixture.rootProductId);
      expect(configuration.setItems.single.itemProductId, fixture.eggProductId);
      expect(configuration.choiceGroups.single.groupId, groupId);
      expect(
        configuration.choiceGroups.single.members.single.itemProductId,
        fixture.teaProductId,
      );
    });

    test('fails fast when the set root category is invalid', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastConfigFixture fixture = await _seedFixture(
        db,
        rootCategoryName: 'Breakfast',
      );
      final BreakfastConfigurationRepository repository =
          BreakfastConfigurationRepository(db);

      await _insertSetItem(
        db,
        rootProductId: fixture.rootProductId,
        itemProductId: fixture.eggProductId,
        sortOrder: 1,
      );
      final int groupId = await _insertChoiceGroup(
        db,
        rootProductId: fixture.rootProductId,
      );
      await _insertChoiceMember(
        db,
        rootProductId: fixture.rootProductId,
        groupId: groupId,
        itemProductId: fixture.teaProductId,
        label: 'Tea',
      );

      await expectLater(
        repository.loadSetConfiguration(fixture.rootProductId),
        throwsA(
          isA<BreakfastConfigurationInvalidException>()
              .having(
                (BreakfastConfigurationInvalidException error) => error.codes,
                'codes',
                contains(BreakfastConfigurationErrorCode.invalidSetRoot),
              )
              .having(
                (BreakfastConfigurationInvalidException error) =>
                    error.rootProductId,
                'rootProductId',
                fixture.rootProductId,
              ),
        ),
      );
    });

    test('fails when a choice group has no active members', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastConfigFixture fixture = await _seedFixture(db);
      final BreakfastConfigurationRepository repository =
          BreakfastConfigurationRepository(db);

      await _insertSetItem(
        db,
        rootProductId: fixture.rootProductId,
        itemProductId: fixture.eggProductId,
        sortOrder: 1,
      );
      final int groupId = await _insertChoiceGroup(
        db,
        rootProductId: fixture.rootProductId,
      );

      await expectLater(
        repository.loadSetConfiguration(fixture.rootProductId),
        throwsA(
          isA<BreakfastConfigurationInvalidException>()
              .having(
                (BreakfastConfigurationInvalidException error) => error.codes,
                'codes',
                contains(BreakfastConfigurationErrorCode.invalidChoiceGroup),
              )
              .having(
                (BreakfastConfigurationInvalidException error) =>
                    error.issues.single.groupId,
                'groupId',
                groupId,
              ),
        ),
      );
    });

    test('fails when a choice row is missing item_product_id', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastConfigFixture fixture = await _seedFixture(db);
      final BreakfastConfigurationRepository repository =
          BreakfastConfigurationRepository(db);

      await _insertSetItem(
        db,
        rootProductId: fixture.rootProductId,
        itemProductId: fixture.eggProductId,
        sortOrder: 1,
      );
      final int groupId = await _insertChoiceGroup(
        db,
        rootProductId: fixture.rootProductId,
      );
      await _insertMalformedChoiceRow(
        db,
        rootProductId: fixture.rootProductId,
        groupId: groupId,
        label: 'Broken choice',
      );

      await expectLater(
        repository.loadSetConfiguration(fixture.rootProductId),
        throwsA(
          isA<BreakfastConfigurationInvalidException>()
              .having(
                (BreakfastConfigurationInvalidException error) => error.codes,
                'codes',
                contains(BreakfastConfigurationErrorCode.missingItemProductId),
              )
              .having(
                (BreakfastConfigurationInvalidException error) =>
                    error.issues.single.productModifierId,
                'productModifierId',
                isPositive,
              ),
        ),
      );
    });

    test('fails when choice bounds are invalid', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastConfigFixture fixture = await _seedFixture(db);
      final BreakfastConfigurationRepository repository =
          BreakfastConfigurationRepository(db);

      await _insertSetItem(
        db,
        rootProductId: fixture.rootProductId,
        itemProductId: fixture.eggProductId,
        sortOrder: 1,
      );
      final int groupId = await _insertMalformedChoiceGroup(
        db,
        rootProductId: fixture.rootProductId,
        minSelect: 2,
        maxSelect: 1,
        includedQuantity: 1,
      );
      await _insertChoiceMember(
        db,
        rootProductId: fixture.rootProductId,
        groupId: groupId,
        itemProductId: fixture.teaProductId,
        label: 'Tea',
      );

      await expectLater(
        repository.loadSetConfiguration(fixture.rootProductId),
        throwsA(
          isA<BreakfastConfigurationInvalidException>().having(
            (BreakfastConfigurationInvalidException error) => error.codes,
            'codes',
            contains(BreakfastConfigurationErrorCode.invalidChoiceBounds),
          ),
        ),
      );
    });

    test('fails when included quantity is invalid', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastConfigFixture fixture = await _seedFixture(db);
      final BreakfastConfigurationRepository repository =
          BreakfastConfigurationRepository(db);

      await _insertSetItem(
        db,
        rootProductId: fixture.rootProductId,
        itemProductId: fixture.eggProductId,
        sortOrder: 1,
      );
      final int groupId = await _insertMalformedChoiceGroup(
        db,
        rootProductId: fixture.rootProductId,
        minSelect: 0,
        maxSelect: 1,
        includedQuantity: 2,
      );
      await _insertChoiceMember(
        db,
        rootProductId: fixture.rootProductId,
        groupId: groupId,
        itemProductId: fixture.teaProductId,
        label: 'Tea',
      );

      await expectLater(
        repository.loadSetConfiguration(fixture.rootProductId),
        throwsA(
          isA<BreakfastConfigurationInvalidException>().having(
            (BreakfastConfigurationInvalidException error) => error.codes,
            'codes',
            contains(BreakfastConfigurationErrorCode.invalidIncludedQuantity),
          ),
        ),
      );
    });

    test('fails when a set root is assigned as a set item', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _BreakfastConfigFixture fixture = await _seedFixture(db);
      final BreakfastConfigurationRepository repository =
          BreakfastConfigurationRepository(db);

      await _insertSetItem(
        db,
        rootProductId: fixture.rootProductId,
        itemProductId: fixture.rootProductId,
        sortOrder: 1,
      );
      final int groupId = await _insertChoiceGroup(
        db,
        rootProductId: fixture.rootProductId,
      );
      await _insertChoiceMember(
        db,
        rootProductId: fixture.rootProductId,
        groupId: groupId,
        itemProductId: fixture.teaProductId,
        label: 'Tea',
      );

      await expectLater(
        repository.loadSetConfiguration(fixture.rootProductId),
        throwsA(
          isA<BreakfastConfigurationInvalidException>()
              .having(
                (BreakfastConfigurationInvalidException error) => error.codes,
                'codes',
                contains(
                  BreakfastConfigurationErrorCode.wrongProductRoleAssignment,
                ),
              )
              .having(
                (BreakfastConfigurationInvalidException error) =>
                    error.issues.single.itemProductId,
                'itemProductId',
                fixture.rootProductId,
              ),
        ),
      );
    });

    test(
      'fails when a choice-capable product is configured as a set item',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _BreakfastConfigFixture fixture = await _seedFixture(db);
        final BreakfastConfigurationRepository repository =
            BreakfastConfigurationRepository(db);

        await _insertSetItem(
          db,
          rootProductId: fixture.rootProductId,
          itemProductId: fixture.teaProductId,
          sortOrder: 1,
        );
        final int groupId = await _insertChoiceGroup(
          db,
          rootProductId: fixture.rootProductId,
        );
        await _insertChoiceMember(
          db,
          rootProductId: fixture.rootProductId,
          groupId: groupId,
          itemProductId: fixture.teaProductId,
          label: 'Tea',
        );

        await expectLater(
          repository.loadSetConfiguration(fixture.rootProductId),
          throwsA(
            isA<BreakfastConfigurationInvalidException>()
                .having(
                  (BreakfastConfigurationInvalidException error) => error.codes,
                  'codes',
                  contains(
                    BreakfastConfigurationErrorCode
                        .choiceCapableProductInSetItems,
                  ),
                )
                .having(
                  (BreakfastConfigurationInvalidException error) =>
                      error.issues.single.itemProductId,
                  'itemProductId',
                  fixture.teaProductId,
                ),
          ),
        );
      },
    );
  });
}

Future<_BreakfastConfigFixture> _seedFixture(
  app_db.AppDatabase db, {
  String rootCategoryName = 'Set Breakfast',
  bool includeLatte = true,
  bool includeToasts = true,
  bool includeBreads = true,
}) async {
  final int rootCategoryId = await insertCategory(db, name: rootCategoryName);
  final int hotDrinkCategoryId = await insertCategory(db, name: 'Hot Drinks');
  final int bakeryCategoryId = await insertCategory(db, name: 'Bakery');

  final int rootProductId = await insertProduct(
    db,
    categoryId: rootCategoryId,
    name: 'Set 4',
    priceMinor: 400,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: rootCategoryId,
    name: 'Egg',
    priceMinor: 120,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: hotDrinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  if (includeLatte) {
    await insertProduct(
      db,
      categoryId: hotDrinkCategoryId,
      name: 'Latte',
      priceMinor: 180,
    );
  }
  if (includeToasts) {
    await insertProduct(
      db,
      categoryId: bakeryCategoryId,
      name: 'Toasts',
      priceMinor: 100,
    );
  }
  if (includeBreads) {
    await insertProduct(
      db,
      categoryId: bakeryCategoryId,
      name: 'Breads',
      priceMinor: 90,
    );
  }

  return _BreakfastConfigFixture(
    rootProductId: rootProductId,
    eggProductId: eggProductId,
    teaProductId: teaProductId,
    hotDrinkCategoryId: hotDrinkCategoryId,
    bakeryCategoryId: bakeryCategoryId,
  );
}

Future<void> _insertSetItem(
  app_db.AppDatabase db, {
  required int rootProductId,
  required int itemProductId,
  required int sortOrder,
}) async {
  await db
      .into(db.setItems)
      .insert(
        app_db.SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: itemProductId,
          sortOrder: Value<int>(sortOrder),
        ),
      );
}

Future<int> _insertChoiceGroup(
  app_db.AppDatabase db, {
  required int rootProductId,
}) {
  return db
      .into(db.modifierGroups)
      .insert(
        app_db.ModifierGroupsCompanion.insert(
          productId: rootProductId,
          name: 'Tea or Coffee',
          minSelect: const Value<int>(0),
          maxSelect: const Value<int>(1),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );
}

Future<int> _insertMalformedChoiceGroup(
  app_db.AppDatabase db, {
  required int rootProductId,
  required int minSelect,
  required int maxSelect,
  required int includedQuantity,
}) async {
  return _withIgnoredCheckConstraints<int>(db, () async {
    await db.customStatement('''
      INSERT INTO modifier_groups (
        product_id,
        name,
        min_select,
        max_select,
        included_quantity,
        sort_order
      ) VALUES (
        $rootProductId,
        'Tea or Coffee',
        $minSelect,
        $maxSelect,
        $includedQuantity,
        1
      )
    ''');
    final rows = await db
        .customSelect(
          '''
        SELECT id
        FROM modifier_groups
        WHERE product_id = ? AND name = 'Tea or Coffee'
        ORDER BY id DESC
        LIMIT 1
      ''',
          variables: <Variable<Object>>[Variable<int>(rootProductId)],
        )
        .getSingle();
    return rows.read<int>('id');
  });
}

Future<void> _insertChoiceMember(
  app_db.AppDatabase db, {
  required int rootProductId,
  required int groupId,
  required int itemProductId,
  required String label,
}) async {
  await db
      .into(db.productModifiers)
      .insert(
        app_db.ProductModifiersCompanion.insert(
          productId: rootProductId,
          groupId: Value<int?>(groupId),
          itemProductId: Value<int?>(itemProductId),
          name: label,
          type: 'choice',
          extraPriceMinor: const Value<int>(0),
        ),
      );
}

Future<void> _insertMalformedChoiceRow(
  app_db.AppDatabase db, {
  required int rootProductId,
  required int groupId,
  required String label,
}) {
  return _withIgnoredCheckConstraints<void>(db, () async {
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
        $rootProductId,
        $groupId,
        NULL,
        '$label',
        'choice',
        0,
        1
      )
    ''');
  });
}

Future<T> _withIgnoredCheckConstraints<T>(
  app_db.AppDatabase db,
  Future<T> Function() action,
) async {
  await db.customStatement('PRAGMA ignore_check_constraints = ON;');
  try {
    return await action();
  } finally {
    await db.customStatement('PRAGMA ignore_check_constraints = OFF;');
  }
}

class _BreakfastConfigFixture {
  const _BreakfastConfigFixture({
    required this.rootProductId,
    required this.eggProductId,
    required this.teaProductId,
    required this.hotDrinkCategoryId,
    required this.bakeryCategoryId,
  });

  final int rootProductId;
  final int eggProductId;
  final int teaProductId;
  final int hotDrinkCategoryId;
  final int bakeryCategoryId;
}
