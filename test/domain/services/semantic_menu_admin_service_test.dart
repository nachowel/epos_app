import 'package:drift/drift.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/domain/models/product_modifier.dart';
import 'package:epos_app/domain/models/semantic_product_configuration.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/domain/services/semantic_menu_admin_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  group('SemanticMenuAdminService', () {
    test('saving and loading set items works', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _SemanticFixture fixture = await _seedSemanticFixture(db);
      final SemanticMenuAdminService service = _createService(db);

      await service.saveConfiguration(
        user: fixture.adminUser,
        configuration: SemanticProductConfigurationDraft(
          productId: fixture.rootProductId,
          setItems: <SemanticSetItemDraft>[
            SemanticSetItemDraft(
              itemProductId: fixture.eggProductId,
              itemName: 'Egg',
              defaultQuantity: 1,
              isRemovable: true,
              sortOrder: 1,
            ),
            SemanticSetItemDraft(
              itemProductId: fixture.baconProductId,
              itemName: 'Bacon',
              defaultQuantity: 2,
              isRemovable: false,
              sortOrder: 2,
            ),
          ],
          choiceGroups: const <SemanticChoiceGroupDraft>[],
        ),
      );

      final SemanticProductConfigurationEditorData editorData = await service
          .loadEditorData(fixture.rootProductId);

      expect(editorData.configuration.setItems, hasLength(2));
      expect(
        editorData.configuration.setItems.first.itemProductId,
        fixture.eggProductId,
      );
      expect(
        editorData.configuration.setItems.last.itemProductId,
        fixture.baconProductId,
      );
      expect(editorData.configuration.setItems.last.defaultQuantity, 2);
      expect(editorData.configuration.setItems.last.isRemovable, isFalse);
    });

    test('saving and loading explicit extras pool works', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _SemanticFixture fixture = await _seedSemanticFixture(db);
      final SemanticMenuAdminService service = _createService(db);

      await service.saveConfiguration(
        user: fixture.adminUser,
        configuration: SemanticProductConfigurationDraft(
          productId: fixture.rootProductId,
          setItems: <SemanticSetItemDraft>[
            SemanticSetItemDraft(
              itemProductId: fixture.eggProductId,
              itemName: 'Egg',
              defaultQuantity: 1,
              isRemovable: true,
              sortOrder: 0,
            ),
          ],
          choiceGroups: const <SemanticChoiceGroupDraft>[],
          extras: <SemanticExtraItemDraft>[
            SemanticExtraItemDraft(
              itemProductId: fixture.baconProductId,
              itemName: 'Bacon',
              sortOrder: 0,
            ),
            SemanticExtraItemDraft(
              itemProductId: fixture.coffeeProductId,
              itemName: 'Coffee',
              sortOrder: 1,
            ),
          ],
        ),
      );

      final SemanticProductConfigurationEditorData editorData = await service
          .loadEditorData(fixture.rootProductId);

      expect(editorData.configuration.extras, hasLength(2));
      expect(
        editorData.configuration.extras.map(
          (SemanticExtraItemDraft extra) => extra.itemProductId,
        ),
        <int>[fixture.baconProductId, fixture.coffeeProductId],
      );

      final Map<int, ProductMenuConfigurationProfile> profiles = await service
          .getProductProfiles(<int>[fixture.rootProductId]);
      expect(
        profiles[fixture.rootProductId]?.type,
        ProductMenuConfigType.semanticSet,
      );
      expect(profiles[fixture.rootProductId]?.flatModifierCount, 0);
      expect(profiles[fixture.rootProductId]?.extraPoolCount, 2);
    });

    test('saving and loading modifier groups works', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _SemanticFixture fixture = await _seedSemanticFixture(db);
      final SemanticMenuAdminService service = _createService(db);

      await service.saveConfiguration(
        user: fixture.adminUser,
        configuration: SemanticProductConfigurationDraft(
          productId: fixture.rootProductId,
          setItems: <SemanticSetItemDraft>[
            SemanticSetItemDraft(
              itemProductId: fixture.eggProductId,
              itemName: 'Egg',
              defaultQuantity: 1,
              isRemovable: true,
              sortOrder: 0,
            ),
          ],
          choiceGroups: <SemanticChoiceGroupDraft>[
            SemanticChoiceGroupDraft(
              name: 'Drink',
              minSelect: 0,
              maxSelect: 1,
              includedQuantity: 1,
              sortOrder: 3,
              members: <SemanticChoiceMemberDraft>[
                SemanticChoiceMemberDraft(
                  itemProductId: fixture.teaProductId,
                  itemName: 'Tea',
                  position: 0,
                ),
              ],
            ),
          ],
        ),
      );

      final SemanticProductConfigurationEditorData editorData = await service
          .loadEditorData(fixture.rootProductId);

      expect(editorData.configuration.choiceGroups, hasLength(1));
      final SemanticChoiceGroupDraft group =
          editorData.configuration.choiceGroups.single;
      expect(group.name, 'Drink');
      expect(group.minSelect, 0);
      expect(group.maxSelect, 1);
      expect(group.includedQuantity, 1);
      expect(group.sortOrder, 3);
    });

    test('saving grouped choice members persists real choice rows', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _SemanticFixture fixture = await _seedSemanticFixture(db);
      final SemanticMenuAdminService service = _createService(db);

      await service.saveConfiguration(
        user: fixture.adminUser,
        configuration: SemanticProductConfigurationDraft(
          productId: fixture.rootProductId,
          setItems: <SemanticSetItemDraft>[
            SemanticSetItemDraft(
              itemProductId: fixture.eggProductId,
              itemName: 'Egg',
              defaultQuantity: 1,
              isRemovable: true,
              sortOrder: 0,
            ),
          ],
          choiceGroups: <SemanticChoiceGroupDraft>[
            SemanticChoiceGroupDraft(
              name: 'Drink',
              minSelect: 0,
              maxSelect: 1,
              includedQuantity: 1,
              sortOrder: 1,
              members: <SemanticChoiceMemberDraft>[
                SemanticChoiceMemberDraft(
                  itemProductId: fixture.teaProductId,
                  itemName: 'Tea',
                  position: 0,
                ),
                SemanticChoiceMemberDraft(
                  itemProductId: fixture.coffeeProductId,
                  itemName: 'Coffee',
                  position: 1,
                ),
              ],
            ),
          ],
        ),
      );

      final List<app_db.ProductModifier> rows =
          await (db.select(db.productModifiers)
                ..where((app_db.$ProductModifiersTable t) {
                  return t.productId.equals(fixture.rootProductId) &
                      t.type.equals('choice');
                })
                ..orderBy(
                  <OrderingTerm Function(app_db.$ProductModifiersTable)>[
                    (app_db.$ProductModifiersTable t) => OrderingTerm.asc(t.id),
                  ],
                ))
              .get();

      expect(rows, hasLength(2));
      expect(
        rows.every((app_db.ProductModifier row) => row.type == 'choice'),
        isTrue,
      );
      expect(
        rows.every((app_db.ProductModifier row) => row.groupId != null),
        isTrue,
      );
      expect(
        rows.map((app_db.ProductModifier row) => row.itemProductId),
        containsAll(<int?>[fixture.teaProductId, fixture.coffeeProductId]),
      );
    });

    test('validation rejects duplicate extras before persistence', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _SemanticFixture fixture = await _seedSemanticFixture(db);
      final SemanticMenuAdminService service = _createService(db);

      await expectLater(
        () => service.saveConfiguration(
          user: fixture.adminUser,
          configuration: SemanticProductConfigurationDraft(
            productId: fixture.rootProductId,
            setItems: <SemanticSetItemDraft>[
              SemanticSetItemDraft(
                itemProductId: fixture.eggProductId,
                itemName: 'Egg',
                defaultQuantity: 1,
                isRemovable: true,
                sortOrder: 0,
              ),
            ],
            choiceGroups: const <SemanticChoiceGroupDraft>[],
            extras: <SemanticExtraItemDraft>[
              SemanticExtraItemDraft(
                itemProductId: fixture.baconProductId,
                itemName: 'Bacon',
                sortOrder: 0,
              ),
              SemanticExtraItemDraft(
                itemProductId: fixture.baconProductId,
                itemName: 'Bacon',
                sortOrder: 1,
              ),
            ],
          ),
        ),
        throwsA(
          isA<SemanticProductConfigurationValidationException>().having(
            (SemanticProductConfigurationValidationException error) =>
                error.message,
            'message',
            contains('Extras cannot contain duplicate products.'),
          ),
        ),
      );
    });

    test(
      'validation fails for broken group rules before persistence',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _SemanticFixture fixture = await _seedSemanticFixture(db);
        final SemanticMenuAdminService service = _createService(db);

        await expectLater(
          () => service.saveConfiguration(
            user: fixture.adminUser,
            configuration: SemanticProductConfigurationDraft(
              productId: fixture.rootProductId,
              setItems: const <SemanticSetItemDraft>[],
              choiceGroups: const <SemanticChoiceGroupDraft>[
                SemanticChoiceGroupDraft(
                  name: 'Broken Group',
                  minSelect: 2,
                  maxSelect: 1,
                  includedQuantity: 1,
                  sortOrder: 0,
                  members: <SemanticChoiceMemberDraft>[],
                ),
              ],
            ),
          ),
          throwsA(
            isA<SemanticProductConfigurationValidationException>().having(
              (SemanticProductConfigurationValidationException error) =>
                  error.message,
              'message',
              allOf(
                contains('maximum selection'),
                contains('Choice groups must contain at least one member'),
              ),
            ),
          ),
        );

        final SemanticProductConfigurationEditorData editorData = await service
            .loadEditorData(fixture.rootProductId);
        expect(editorData.configuration.choiceGroups, isEmpty);
      },
    );

    test(
      'validation fails for broken set item rules before persistence',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _SemanticFixture fixture = await _seedSemanticFixture(db);
        final SemanticMenuAdminService service = _createService(db);

        await expectLater(
          () => service.saveConfiguration(
            user: fixture.adminUser,
            configuration: SemanticProductConfigurationDraft(
              productId: fixture.rootProductId,
              setItems: <SemanticSetItemDraft>[
                SemanticSetItemDraft(
                  itemProductId: fixture.rootProductId,
                  itemName: 'Set Breakfast',
                  defaultQuantity: 1,
                  isRemovable: true,
                  sortOrder: 0,
                ),
                SemanticSetItemDraft(
                  itemProductId: fixture.rootProductId,
                  itemName: 'Set Breakfast',
                  defaultQuantity: 0,
                  isRemovable: true,
                  sortOrder: 1,
                ),
              ],
              choiceGroups: const <SemanticChoiceGroupDraft>[],
            ),
          ),
          throwsA(
            isA<SemanticProductConfigurationValidationException>().having(
              (SemanticProductConfigurationValidationException error) =>
                  error.message,
              'message',
              allOf(
                contains('cannot reference itself'),
                contains('quantity must be greater than zero'),
                contains('cannot contain duplicate products'),
              ),
            ),
          ),
        );

        final List<app_db.SetItem> setItems = await db
            .select(db.setItems)
            .get();
        expect(setItems, isEmpty);
      },
    );

    test('validation rejects included quantity above group maximum', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _SemanticFixture fixture = await _seedSemanticFixture(db);
      final SemanticMenuAdminService service = _createService(db);

      await expectLater(
        () => service.saveConfiguration(
          user: fixture.adminUser,
          configuration: SemanticProductConfigurationDraft(
            productId: fixture.rootProductId,
            setItems: <SemanticSetItemDraft>[
              SemanticSetItemDraft(
                itemProductId: fixture.eggProductId,
                itemName: 'Egg',
                defaultQuantity: 1,
                isRemovable: true,
                sortOrder: 0,
              ),
            ],
            choiceGroups: <SemanticChoiceGroupDraft>[
              SemanticChoiceGroupDraft(
                name: 'Drink',
                minSelect: 0,
                maxSelect: 1,
                includedQuantity: 2,
                sortOrder: 0,
                members: <SemanticChoiceMemberDraft>[
                  SemanticChoiceMemberDraft(
                    itemProductId: fixture.teaProductId,
                    itemName: 'Tea',
                    position: 0,
                  ),
                ],
              ),
            ],
          ),
        ),
        throwsA(
          isA<SemanticProductConfigurationValidationException>().having(
            (SemanticProductConfigurationValidationException error) =>
                error.message,
            'message',
            contains('included quantity must be less than or equal'),
          ),
        ),
      );
    });

    test('validation rejects unsupported multi-select groups', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _SemanticFixture fixture = await _seedSemanticFixture(db);
      final SemanticMenuAdminService service = _createService(db);

      await expectLater(
        () => service.saveConfiguration(
          user: fixture.adminUser,
          configuration: SemanticProductConfigurationDraft(
            productId: fixture.rootProductId,
            setItems: <SemanticSetItemDraft>[
              SemanticSetItemDraft(
                itemProductId: fixture.eggProductId,
                itemName: 'Egg',
                defaultQuantity: 1,
                isRemovable: true,
                sortOrder: 0,
              ),
            ],
            choiceGroups: <SemanticChoiceGroupDraft>[
              SemanticChoiceGroupDraft(
                name: 'Drink',
                minSelect: 1,
                maxSelect: 2,
                includedQuantity: 1,
                sortOrder: 0,
                members: <SemanticChoiceMemberDraft>[
                  SemanticChoiceMemberDraft(
                    itemProductId: fixture.teaProductId,
                    itemName: 'Tea',
                    position: 0,
                  ),
                ],
              ),
            ],
          ),
        ),
        throwsA(
          isA<SemanticProductConfigurationValidationException>().having(
            (SemanticProductConfigurationValidationException error) =>
                error.message,
            'message',
            contains('POS currently supports one selection per group.'),
          ),
        ),
      );
    });

    test('set item and group sort order fields are preserved', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _SemanticFixture fixture = await _seedSemanticFixture(db);
      final SemanticMenuAdminService service = _createService(db);

      await service.saveConfiguration(
        user: fixture.adminUser,
        configuration: SemanticProductConfigurationDraft(
          productId: fixture.rootProductId,
          setItems: <SemanticSetItemDraft>[
            SemanticSetItemDraft(
              itemProductId: fixture.baconProductId,
              itemName: 'Bacon',
              defaultQuantity: 1,
              isRemovable: true,
              sortOrder: 5,
            ),
            SemanticSetItemDraft(
              itemProductId: fixture.eggProductId,
              itemName: 'Egg',
              defaultQuantity: 1,
              isRemovable: true,
              sortOrder: 2,
            ),
          ],
          choiceGroups: <SemanticChoiceGroupDraft>[
            SemanticChoiceGroupDraft(
              name: 'Bread',
              minSelect: 0,
              maxSelect: 1,
              includedQuantity: 1,
              sortOrder: 7,
              members: <SemanticChoiceMemberDraft>[
                SemanticChoiceMemberDraft(
                  itemProductId: fixture.teaProductId,
                  itemName: 'Tea',
                  position: 0,
                ),
              ],
            ),
            SemanticChoiceGroupDraft(
              name: 'Drink',
              minSelect: 0,
              maxSelect: 1,
              includedQuantity: 1,
              sortOrder: 1,
              members: <SemanticChoiceMemberDraft>[
                SemanticChoiceMemberDraft(
                  itemProductId: fixture.coffeeProductId,
                  itemName: 'Coffee',
                  position: 0,
                ),
              ],
            ),
          ],
        ),
      );

      final List<app_db.SetItem> setRows =
          await (db.select(db.setItems)
                ..where(
                  (app_db.$SetItemsTable t) =>
                      t.productId.equals(fixture.rootProductId),
                )
                ..orderBy(<OrderingTerm Function(app_db.$SetItemsTable)>[
                  (app_db.$SetItemsTable t) => OrderingTerm.asc(t.sortOrder),
                ]))
              .get();
      final List<app_db.ModifierGroup> groupRows =
          await (db.select(db.modifierGroups)
                ..where(
                  (app_db.$ModifierGroupsTable t) =>
                      t.productId.equals(fixture.rootProductId),
                )
                ..orderBy(<OrderingTerm Function(app_db.$ModifierGroupsTable)>[
                  (app_db.$ModifierGroupsTable t) =>
                      OrderingTerm.asc(t.sortOrder),
                ]))
              .get();

      expect(setRows.map((app_db.SetItem row) => row.sortOrder), <int>[2, 5]);
      expect(groupRows.map((app_db.ModifierGroup row) => row.sortOrder), <int>[
        1,
        7,
      ]);
    });

    test(
      'legacy flat admin flow still works and profile remains legacy flat',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _SemanticFixture fixture = await _seedSemanticFixture(db);
        final SemanticMenuAdminService service = _createService(db);
        final ModifierRepository modifierRepository = ModifierRepository(db);

        await modifierRepository.insert(
          productId: fixture.rootProductId,
          name: 'Butter',
          type: ModifierType.included,
        );
        await modifierRepository.insert(
          productId: fixture.rootProductId,
          name: 'Hash Brown',
          type: ModifierType.extra,
          extraPriceMinor: 125,
        );

        await service.saveConfiguration(
          user: fixture.adminUser,
          configuration: SemanticProductConfigurationDraft(
            productId: fixture.rootProductId,
            setItems: const <SemanticSetItemDraft>[],
            choiceGroups: const <SemanticChoiceGroupDraft>[],
          ),
        );

        final Map<int, ProductMenuConfigurationProfile> profiles = await service
            .getProductProfiles(<int>[fixture.rootProductId]);
        final List<ProductModifier> flatModifiers = await modifierRepository
            .getByProductId(fixture.rootProductId, activeOnly: false);

        expect(
          profiles[fixture.rootProductId]?.type,
          ProductMenuConfigType.legacyFlat,
        );
        expect(
          flatModifiers.map((ProductModifier modifier) => modifier.type),
          containsAll(<ModifierType>[
            ModifierType.included,
            ModifierType.extra,
          ]),
        );
      },
    );

    test(
      'validation rejects mixed legacy flat modifiers with semantic structure',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _SemanticFixture fixture = await _seedSemanticFixture(db);
        final SemanticMenuAdminService service = _createService(db);
        final ModifierRepository modifierRepository = ModifierRepository(db);

        await modifierRepository.insert(
          productId: fixture.rootProductId,
          name: 'Butter',
          type: ModifierType.included,
        );

        await expectLater(
          () => service.saveConfiguration(
            user: fixture.adminUser,
            configuration: SemanticProductConfigurationDraft(
              productId: fixture.rootProductId,
              setItems: <SemanticSetItemDraft>[
                SemanticSetItemDraft(
                  itemProductId: fixture.eggProductId,
                  itemName: 'Egg',
                  defaultQuantity: 1,
                  isRemovable: true,
                  sortOrder: 0,
                ),
              ],
              choiceGroups: const <SemanticChoiceGroupDraft>[],
            ),
          ),
          throwsA(
            isA<SemanticProductConfigurationValidationException>().having(
              (SemanticProductConfigurationValidationException error) =>
                  error.message,
              'message',
              contains(
                'Remove legacy flat modifiers before saving a semantic set configuration',
              ),
            ),
          ),
        );
      },
    );

    test(
      'validation rejects products already used as choice members becoming set roots',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _SemanticFixture fixture = await _seedSemanticFixture(db);
        final SemanticMenuAdminService service = _createService(db);

        final int otherRootId = await insertProduct(
          db,
          categoryId: fixture.breakfastCategoryId,
          name: 'Other Set',
          priceMinor: 650,
        );
        final int otherGroupId = await db
            .into(db.modifierGroups)
            .insert(
              app_db.ModifierGroupsCompanion.insert(
                productId: otherRootId,
                name: 'Drink',
                minSelect: const Value<int>(1),
                maxSelect: const Value<int>(1),
                includedQuantity: const Value<int>(1),
              ),
            );
        await db
            .into(db.productModifiers)
            .insert(
              app_db.ProductModifiersCompanion.insert(
                productId: otherRootId,
                groupId: Value<int?>(otherGroupId),
                itemProductId: Value<int?>(fixture.rootProductId),
                name: 'Set Breakfast',
                type: 'choice',
              ),
            );

        await expectLater(
          () => service.saveConfiguration(
            user: fixture.adminUser,
            configuration: SemanticProductConfigurationDraft(
              productId: fixture.rootProductId,
              setItems: <SemanticSetItemDraft>[
                SemanticSetItemDraft(
                  itemProductId: fixture.eggProductId,
                  itemName: 'Egg',
                  defaultQuantity: 1,
                  isRemovable: true,
                  sortOrder: 0,
                ),
              ],
              choiceGroups: const <SemanticChoiceGroupDraft>[],
            ),
          ),
          throwsA(
            isA<SemanticProductConfigurationValidationException>().having(
              (SemanticProductConfigurationValidationException error) =>
                  error.message,
              'message',
              contains(
                'already used as a choice option in another set and cannot become a set root',
              ),
            ),
          ),
        );
      },
    );
  });
}

SemanticMenuAdminService _createService(app_db.AppDatabase db) {
  return SemanticMenuAdminService(
    productRepository: ProductRepository(db),
    breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
  );
}

Future<_SemanticFixture> _seedSemanticFixture(app_db.AppDatabase db) async {
  final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
  final int breakfastCategoryId = await insertCategory(db, name: 'Breakfast');
  final int drinksCategoryId = await insertCategory(db, name: 'Drinks');

  final int rootProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set Breakfast',
    priceMinor: 500,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Egg',
    priceMinor: 100,
  );
  final int baconProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Bacon',
    priceMinor: 120,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: drinksCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int coffeeProductId = await insertProduct(
    db,
    categoryId: drinksCategoryId,
    name: 'Coffee',
    priceMinor: 160,
  );

  return _SemanticFixture(
    adminUser: User(
      id: adminId,
      name: 'Admin',
      pin: null,
      password: null,
      role: UserRole.admin,
      isActive: true,
      createdAt: DateTime.now(),
    ),
    rootProductId: rootProductId,
    eggProductId: eggProductId,
    baconProductId: baconProductId,
    teaProductId: teaProductId,
    coffeeProductId: coffeeProductId,
    breakfastCategoryId: breakfastCategoryId,
  );
}

class _SemanticFixture {
  const _SemanticFixture({
    required this.adminUser,
    required this.rootProductId,
    required this.eggProductId,
    required this.baconProductId,
    required this.teaProductId,
    required this.coffeeProductId,
    required this.breakfastCategoryId,
  });

  final User adminUser;
  final int rootProductId;
  final int eggProductId;
  final int baconProductId;
  final int teaProductId;
  final int coffeeProductId;
  final int breakfastCategoryId;
}
