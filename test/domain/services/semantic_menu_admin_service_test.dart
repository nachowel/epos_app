import 'package:drift/drift.dart';
import 'package:epos_app/core/logging/app_logger.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/domain/models/breakfast_extra_preset.dart';
import 'package:epos_app/domain/models/app_log_entry.dart';
import 'package:epos_app/domain/models/product.dart';
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

    test(
      'loadEditorData uses active Breakfast Items products when duplicate category names exist',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        await insertUser(db, name: 'Admin', role: 'admin');
        final int setBreakfastCategoryId = await insertCategory(
          db,
          name: 'Set Breakfast',
        );
        await insertCategory(db, name: 'Breakfast Items', isActive: false);
        final int activeBreakfastItemsCategoryId = await insertCategory(
          db,
          name: 'Breakfast Items',
        );
        final int drinksCategoryId = await insertCategory(db, name: 'Drinks');

        final int set1Id = await insertProduct(
          db,
          categoryId: setBreakfastCategoryId,
          name: 'Set 1',
          priceMinor: 500,
        );
        final int set3Id = await insertProduct(
          db,
          categoryId: setBreakfastCategoryId,
          name: 'Set 3',
          priceMinor: 700,
        );
        final int eggId = await insertProduct(
          db,
          categoryId: activeBreakfastItemsCategoryId,
          name: 'Egg',
          priceMinor: 100,
        );
        final int baconId = await insertProduct(
          db,
          categoryId: activeBreakfastItemsCategoryId,
          name: 'Bacon',
          priceMinor: 120,
        );
        await insertProduct(
          db,
          categoryId: drinksCategoryId,
          name: 'Tea',
          priceMinor: 150,
        );

        final SemanticMenuAdminService service = _createService(db);

        final SemanticProductConfigurationEditorData set1EditorData =
            await service.loadEditorData(set1Id);
        final SemanticProductConfigurationEditorData set3EditorData =
            await service.loadEditorData(set3Id);

        expect(
          set1EditorData.availableSetItemProducts.map(
            (Product product) => product.id,
          ),
          <int>[eggId, baconId],
        );
        expect(
          set3EditorData.availableSetItemProducts.map(
            (Product product) => product.id,
          ),
          <int>[eggId, baconId],
        );
      },
    );

    test(
      'loadEditorData includes active hidden-on-pos Breakfast Items products even when the source category is inactive',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        await insertUser(db, name: 'Admin', role: 'admin');
        final int setBreakfastCategoryId = await insertCategory(
          db,
          name: 'Set Breakfast',
        );
        final int hiddenBreakfastItemsCategoryId = await insertCategory(
          db,
          name: 'Breakfast Items',
          isActive: false,
        );
        final int rootProductId = await insertProduct(
          db,
          categoryId: setBreakfastCategoryId,
          name: 'Set 3',
          priceMinor: 700,
        );
        final int hiddenEggId = await insertProduct(
          db,
          categoryId: hiddenBreakfastItemsCategoryId,
          name: 'Hidden Egg',
          priceMinor: 100,
          isVisibleOnPos: false,
        );
        await insertProduct(
          db,
          categoryId: hiddenBreakfastItemsCategoryId,
          name: 'Inactive Bacon',
          priceMinor: 120,
          isActive: false,
          isVisibleOnPos: false,
        );

        final SemanticMenuAdminService service = _createService(db);

        final SemanticProductConfigurationEditorData editorData = await service
            .loadEditorData(rootProductId);

        expect(
          editorData.availableSetItemProducts.map(
            (Product product) => product.id,
          ),
          <int>[hiddenEggId],
        );
      },
    );

    test(
      'old and new sets both receive an empty included-item pool when Breakfast Items has no active products',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final MemoryAppLogSink sink = MemoryAppLogSink();
        final StructuredAppLogger logger = StructuredAppLogger(
          sinks: <AppLogSink>[sink],
          enableInfoLogs: true,
        );
        addTearDown(logger.dispose);

        await insertUser(db, name: 'Admin', role: 'admin');
        final int setBreakfastCategoryId = await insertCategory(
          db,
          name: 'Set Breakfast',
        );
        final int breakfastItemsCategoryId = await insertCategory(
          db,
          name: 'Breakfast Items',
        );

        final int set1Id = await insertProduct(
          db,
          categoryId: setBreakfastCategoryId,
          name: 'Set 1',
          priceMinor: 500,
        );
        final int set3Id = await insertProduct(
          db,
          categoryId: setBreakfastCategoryId,
          name: 'Set 3',
          priceMinor: 700,
        );
        final int inactiveEggId = await insertProduct(
          db,
          categoryId: breakfastItemsCategoryId,
          name: 'Egg',
          priceMinor: 100,
          isActive: false,
        );

        await db
            .into(db.setItems)
            .insert(
              app_db.SetItemsCompanion.insert(
                productId: set1Id,
                itemProductId: inactiveEggId,
                sortOrder: const Value<int>(0),
              ),
            );

        final SemanticMenuAdminService service = _createService(
          db,
          logger: logger,
        );

        final SemanticProductConfigurationEditorData set1EditorData =
            await service.loadEditorData(set1Id);
        final SemanticProductConfigurationEditorData set3EditorData =
            await service.loadEditorData(set3Id);

        expect(
          set1EditorData.configuration.setItems.map(
            (SemanticSetItemDraft item) => item.itemProductId,
          ),
          <int>[inactiveEggId],
        );
        expect(set1EditorData.availableSetItemProducts, isEmpty);
        expect(set3EditorData.availableSetItemProducts, isEmpty);

        final List<AppLogEntry> poolEvents = sink.entries
            .where(
              (AppLogEntry entry) =>
                  entry.eventType == 'breakfast_set_item_pool_resolved',
            )
            .toList(growable: false);
        expect(poolEvents, hasLength(2));
        for (final AppLogEntry entry in poolEvents) {
          expect(entry.metadata['matching_category_names'], <String>[
            'Breakfast Items',
          ]);
          expect(entry.metadata['active_product_count_before_filter'], 0);
          expect(entry.metadata['final_available_set_item_products_length'], 0);
        }
      },
    );

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

    test('creating and loading breakfast extras presets works', () async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _SemanticFixture fixture = await _seedSemanticFixture(db);
      final SemanticMenuAdminService service = _createService(db);

      final int presetId = await service.saveExtraPreset(
        user: fixture.adminUser,
        name: 'Standard Breakfast Extras',
        itemProductIds: <int>[fixture.baconProductId, fixture.coffeeProductId],
      );

      final List<BreakfastExtraPreset> presets = await service
          .loadExtraPresets();

      expect(presets, hasLength(1));
      expect(presets.single.id, presetId);
      expect(presets.single.name, 'Standard Breakfast Extras');
      expect(
        presets.single.items.map(
          (BreakfastExtraPresetItem item) => item.itemProductId,
        ),
        <int>[fixture.baconProductId, fixture.coffeeProductId],
      );
    });

    test(
      'editing an extras preset does not mutate already-saved set extras',
      () async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _SemanticFixture fixture = await _seedSemanticFixture(db);
        final SemanticMenuAdminService service = _createService(db);

        final int presetId = await service.saveExtraPreset(
          user: fixture.adminUser,
          name: 'Standard Breakfast Extras',
          itemProductIds: <int>[fixture.baconProductId],
        );
        final BreakfastExtraPreset preset =
            (await service.loadExtraPresets()).single;

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
                minSelect: 1,
                maxSelect: 1,
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
            extras: preset.items
                .map(
                  (BreakfastExtraPresetItem item) => SemanticExtraItemDraft(
                    itemProductId: item.itemProductId,
                    itemName: item.itemName,
                    sortOrder: item.sortOrder,
                  ),
                )
                .toList(growable: false),
          ),
        );

        await service.saveExtraPreset(
          user: fixture.adminUser,
          presetId: presetId,
          name: 'Standard Breakfast Extras',
          itemProductIds: <int>[
            fixture.baconProductId,
            fixture.coffeeProductId,
          ],
        );

        final SemanticProductConfigurationEditorData editorData = await service
            .loadEditorData(fixture.rootProductId);

        expect(
          editorData.configuration.extras.map(
            (SemanticExtraItemDraft extra) => extra.itemProductId,
          ),
          <int>[fixture.baconProductId],
        );
        expect(
          (await service.loadExtraPresets()).single.items.map(
            (BreakfastExtraPresetItem item) => item.itemProductId,
          ),
          <int>[fixture.baconProductId, fixture.coffeeProductId],
        );
      },
    );

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
      expect(
        group.members.map(
          (SemanticChoiceMemberDraft member) => member.itemProductId,
        ),
        <int>[fixture.teaProductId, fixture.coffeeProductId],
      );
    });

    test(
      'saving a second snapshot fully replaces prior persisted rows',
      () async {
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
              SemanticSetItemDraft(
                itemProductId: fixture.baconProductId,
                itemName: 'Bacon',
                defaultQuantity: 1,
                isRemovable: true,
                sortOrder: 1,
              ),
            ],
            choiceGroups: <SemanticChoiceGroupDraft>[
              SemanticChoiceGroupDraft(
                name: 'Drink',
                minSelect: 0,
                maxSelect: 1,
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
        );

        await service.saveConfiguration(
          user: fixture.adminUser,
          configuration: SemanticProductConfigurationDraft(
            productId: fixture.rootProductId,
            setItems: <SemanticSetItemDraft>[
              SemanticSetItemDraft(
                itemProductId: fixture.baconProductId,
                itemName: 'Bacon',
                defaultQuantity: 2,
                isRemovable: false,
                sortOrder: 0,
              ),
            ],
            choiceGroups: <SemanticChoiceGroupDraft>[
              SemanticChoiceGroupDraft(
                name: 'Hot Drink',
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

        final SemanticProductConfigurationEditorData editorData = await service
            .loadEditorData(fixture.rootProductId);

        expect(editorData.configuration.setItems, hasLength(1));
        expect(
          editorData.configuration.setItems.single.itemProductId,
          fixture.baconProductId,
        );
        expect(editorData.configuration.setItems.single.defaultQuantity, 2);
        expect(editorData.configuration.setItems.single.isRemovable, isFalse);
        expect(editorData.configuration.choiceGroups, hasLength(1));
        expect(editorData.configuration.choiceGroups.single.name, 'Hot Drink');
        expect(
          editorData
              .configuration
              .choiceGroups
              .single
              .members
              .single
              .itemProductId,
          fixture.coffeeProductId,
        );

        final List<app_db.SetItem> setRows =
            await (db.select(db.setItems)..where(
                  (app_db.$SetItemsTable t) =>
                      t.productId.equals(fixture.rootProductId),
                ))
                .get();
        final List<app_db.ModifierGroup> groupRows =
            await (db.select(db.modifierGroups)..where(
                  (app_db.$ModifierGroupsTable t) =>
                      t.productId.equals(fixture.rootProductId),
                ))
                .get();
        final List<app_db.ProductModifier> choiceRows =
            await (db.select(db.productModifiers)
                  ..where((app_db.$ProductModifiersTable t) {
                    return t.productId.equals(fixture.rootProductId) &
                        t.type.equals('choice');
                  }))
                .get();

        expect(setRows, hasLength(1));
        expect(setRows.single.itemProductId, fixture.baconProductId);
        expect(groupRows, hasLength(1));
        expect(groupRows.single.name, 'Hot Drink');
        expect(choiceRows, hasLength(1));
        expect(choiceRows.single.itemProductId, fixture.coffeeProductId);
        expect(
          setRows.any(
            (app_db.SetItem row) => row.itemProductId == fixture.eggProductId,
          ),
          isFalse,
        );
        expect(
          choiceRows.any(
            (app_db.ProductModifier row) =>
                row.itemProductId == fixture.teaProductId,
          ),
          isFalse,
        );
      },
    );

    test(
      'failed save rolls back delete-and-reinsert snapshot transaction',
      () async {
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
        );

        await db.customStatement('''
        CREATE TRIGGER fail_breakfast_choice_insert
        BEFORE INSERT ON product_modifiers
        FOR EACH ROW
        WHEN NEW.product_id = ${fixture.rootProductId} AND NEW.type = 'choice'
        BEGIN
          SELECT RAISE(ABORT, 'simulated_breakfast_save_failure');
        END;
      ''');

        await expectLater(
          () => service.saveConfiguration(
            user: fixture.adminUser,
            configuration: SemanticProductConfigurationDraft(
              productId: fixture.rootProductId,
              setItems: <SemanticSetItemDraft>[
                SemanticSetItemDraft(
                  itemProductId: fixture.baconProductId,
                  itemName: 'Bacon',
                  defaultQuantity: 2,
                  isRemovable: false,
                  sortOrder: 0,
                ),
              ],
              choiceGroups: <SemanticChoiceGroupDraft>[
                SemanticChoiceGroupDraft(
                  name: 'Hot Drink',
                  minSelect: 0,
                  maxSelect: 1,
                  includedQuantity: 1,
                  sortOrder: 0,
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
          ),
          throwsA(isA<Exception>()),
        );

        final SemanticProductConfigurationEditorData editorData = await service
            .loadEditorData(fixture.rootProductId);

        expect(editorData.configuration.setItems, hasLength(1));
        expect(
          editorData.configuration.setItems.single.itemProductId,
          fixture.eggProductId,
        );
        expect(editorData.configuration.choiceGroups, hasLength(1));
        expect(editorData.configuration.choiceGroups.single.name, 'Drink');
        expect(
          editorData
              .configuration
              .choiceGroups
              .single
              .members
              .single
              .itemProductId,
          fixture.teaProductId,
        );

        final List<app_db.SetItem> setRows =
            await (db.select(db.setItems)..where(
                  (app_db.$SetItemsTable t) =>
                      t.productId.equals(fixture.rootProductId),
                ))
                .get();
        final List<app_db.ModifierGroup> groupRows =
            await (db.select(db.modifierGroups)..where(
                  (app_db.$ModifierGroupsTable t) =>
                      t.productId.equals(fixture.rootProductId),
                ))
                .get();
        final List<app_db.ProductModifier> choiceRows =
            await (db.select(db.productModifiers)
                  ..where((app_db.$ProductModifiersTable t) {
                    return t.productId.equals(fixture.rootProductId) &
                        t.type.equals('choice');
                  }))
                .get();

        expect(setRows, hasLength(1));
        expect(setRows.single.itemProductId, fixture.eggProductId);
        expect(groupRows, hasLength(1));
        expect(groupRows.single.name, 'Drink');
        expect(choiceRows, hasLength(1));
        expect(choiceRows.single.itemProductId, fixture.teaProductId);
      },
    );

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
          categoryId: fixture.setBreakfastCategoryId,
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

SemanticMenuAdminService _createService(
  app_db.AppDatabase db, {
  AppLogger logger = const NoopAppLogger(),
}) {
  return SemanticMenuAdminService(
    productRepository: ProductRepository(db),
    categoryRepository: CategoryRepository(db),
    breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
    logger: logger,
  );
}

Future<_SemanticFixture> _seedSemanticFixture(app_db.AppDatabase db) async {
  final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
  final int setBreakfastCategoryId = await insertCategory(
    db,
    name: 'Set Breakfast',
  );
  final int breakfastItemsCategoryId = await insertCategory(
    db,
    name: 'Breakfast Items',
  );
  final int drinksCategoryId = await insertCategory(db, name: 'Drinks');

  final int rootProductId = await insertProduct(
    db,
    categoryId: setBreakfastCategoryId,
    name: 'Set Breakfast',
    priceMinor: 500,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastItemsCategoryId,
    name: 'Egg',
    priceMinor: 100,
  );
  final int baconProductId = await insertProduct(
    db,
    categoryId: breakfastItemsCategoryId,
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
    setBreakfastCategoryId: setBreakfastCategoryId,
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
    required this.setBreakfastCategoryId,
  });

  final User adminUser;
  final int rootProductId;
  final int eggProductId;
  final int baconProductId;
  final int teaProductId;
  final int coffeeProductId;
  final int setBreakfastCategoryId;
}
