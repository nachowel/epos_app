import 'package:drift/drift.dart';

import '../../domain/models/breakfast_rebuild.dart';
import '../../domain/models/semantic_product_configuration.dart';
import '../database/app_database.dart' as db;

class BreakfastConfigurationRepository {
  const BreakfastConfigurationRepository(this._database);

  final db.AppDatabase _database;

  Future<bool> hasSetConfiguration(int rootProductId) async {
    final db.SetItem? row =
        await (_database.select(_database.setItems)
              ..where(
                (db.$SetItemsTable t) => t.productId.equals(rootProductId),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<BreakfastSetConfiguration?> loadSetConfiguration(
    int rootProductId,
  ) async {
    final List<db.SetItem> setItems =
        await (_database.select(_database.setItems)
              ..where(
                (db.$SetItemsTable t) => t.productId.equals(rootProductId),
              )
              ..orderBy(<OrderingTerm Function(db.$SetItemsTable)>[
                (db.$SetItemsTable t) => OrderingTerm.asc(t.sortOrder),
                (db.$SetItemsTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    if (setItems.isEmpty) {
      return null;
    }

    final List<db.ModifierGroup> groups =
        await (_database.select(_database.modifierGroups)
              ..where((db.$ModifierGroupsTable t) {
                return t.productId.equals(rootProductId);
              })
              ..orderBy(<OrderingTerm Function(db.$ModifierGroupsTable)>[
                (db.$ModifierGroupsTable t) => OrderingTerm.asc(t.sortOrder),
                (db.$ModifierGroupsTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    final List<db.ProductModifier> productModifiers =
        await (_database.select(_database.productModifiers)
              ..where((db.$ProductModifiersTable t) {
                return t.productId.equals(rootProductId) &
                    t.type.equals('choice') &
                    t.isActive.equals(true);
              })
              ..orderBy(<OrderingTerm Function(db.$ProductModifiersTable)>[
                (db.$ProductModifiersTable t) => OrderingTerm.asc(t.groupId),
                (db.$ProductModifiersTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final List<db.ProductModifier> extraRows =
        await (_database.select(_database.productModifiers)
              ..where((db.$ProductModifiersTable t) {
                return t.productId.equals(rootProductId) &
                    t.type.equals('extra') &
                    t.itemProductId.isNotNull() &
                    t.isActive.equals(true);
              })
              ..orderBy(<OrderingTerm Function(db.$ProductModifiersTable)>[
                (db.$ProductModifiersTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    final db.MenuSetting? menuSettingsRow =
        await (_database.select(_database.menuSettings)
              ..orderBy(<OrderingTerm Function(db.$MenuSettingsTable)>[
                (db.$MenuSettingsTable t) => OrderingTerm.asc(t.id),
              ]))
            .getSingleOrNull();

    final Set<int> relatedProductIds = <int>{};
    for (final db.SetItem item in setItems) {
      relatedProductIds.add(item.itemProductId);
    }
    for (final db.ProductModifier modifier in productModifiers) {
      final int? itemProductId = modifier.itemProductId;
      if (itemProductId != null) {
        relatedProductIds.add(itemProductId);
      }
    }
    for (final db.ProductModifier modifier in extraRows) {
      final int? itemProductId = modifier.itemProductId;
      if (itemProductId != null) {
        relatedProductIds.add(itemProductId);
      }
    }

    final Map<int, BreakfastCatalogProduct> catalogProductsById =
        await loadCatalogProductsByIds(relatedProductIds);

    final List<BreakfastSetItemConfig> setItemConfigs = setItems
        .map((db.SetItem item) {
          final BreakfastCatalogProduct? product =
              catalogProductsById[item.itemProductId];
          return BreakfastSetItemConfig(
            setItemId: item.id,
            itemProductId: item.itemProductId,
            itemName: product?.name ?? 'Product ${item.itemProductId}',
            defaultQuantity: item.defaultQuantity,
            isRemovable: item.isRemovable,
            sortOrder: item.sortOrder,
          );
        })
        .toList(growable: false);

    final Map<int, List<BreakfastChoiceGroupMemberConfig>> membersByGroupId =
        <int, List<BreakfastChoiceGroupMemberConfig>>{};
    for (final db.ProductModifier modifier in productModifiers) {
      final int? groupId = modifier.groupId;
      final int? itemProductId = modifier.itemProductId;
      if (groupId == null || itemProductId == null) {
        continue;
      }
      membersByGroupId
          .putIfAbsent(groupId, () => <BreakfastChoiceGroupMemberConfig>[])
          .add(
            BreakfastChoiceGroupMemberConfig(
              productModifierId: modifier.id,
              itemProductId: itemProductId,
              displayName: modifier.name,
            ),
          );
    }

    final List<BreakfastChoiceGroupConfig> groupConfigs = groups
        .map((db.ModifierGroup group) {
          return BreakfastChoiceGroupConfig(
            groupId: group.id,
            groupName: group.name,
            minSelect: group.minSelect,
            maxSelect: group.maxSelect,
            includedQuantity: group.includedQuantity,
            sortOrder: group.sortOrder,
            members: List<BreakfastChoiceGroupMemberConfig>.unmodifiable(
              membersByGroupId[group.id] ??
                  const <BreakfastChoiceGroupMemberConfig>[],
            ),
          );
        })
        .toList(growable: false);
    final List<BreakfastExtraItemConfig> extraConfigs =
        List<BreakfastExtraItemConfig>.generate(extraRows.length, (int index) {
          final db.ProductModifier modifier = extraRows[index];
          final int itemProductId = modifier.itemProductId!;
          final BreakfastCatalogProduct? product =
              catalogProductsById[itemProductId];
          return BreakfastExtraItemConfig(
            productModifierId: modifier.id,
            itemProductId: itemProductId,
            itemName: product?.name ?? modifier.name,
            sortOrder: index,
          );
        }, growable: false);

    return BreakfastSetConfiguration(
      setRootProductId: rootProductId,
      setItems: setItemConfigs,
      choiceGroups: groupConfigs,
      extras: extraConfigs,
      menuSettings: BreakfastMenuSettings(
        freeSwapLimit: menuSettingsRow?.freeSwapLimit ?? 2,
        maxSwaps: menuSettingsRow?.maxSwaps ?? 4,
      ),
      catalogProductsById: catalogProductsById,
    );
  }

  Future<Map<int, BreakfastCatalogProduct>> loadCatalogProductsByIds(
    Iterable<int> productIds,
  ) async {
    final List<int> ids = productIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return <int, BreakfastCatalogProduct>{};
    }

    final List<db.Product> rows = await (_database.select(
      _database.products,
    )..where((db.$ProductsTable t) => t.id.isIn(ids))).get();
    final Map<int, BreakfastCatalogProduct> productsById =
        <int, BreakfastCatalogProduct>{};
    for (final db.Product row in rows) {
      productsById[row.id] = BreakfastCatalogProduct(
        id: row.id,
        name: row.name,
        priceMinor: row.priceMinor,
      );
    }
    return productsById;
  }

  Future<Map<int, ProductMenuConfigurationProfile>> loadConfigurationProfiles(
    Iterable<int> productIds,
  ) async {
    final List<int> ids = productIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return <int, ProductMenuConfigurationProfile>{};
    }

    final Map<int, int> flatCounts = await _loadGroupedCounts(
      tableName: 'product_modifiers',
      productIds: ids,
      whereClause: "type IN ('included','extra') AND item_product_id IS NULL",
    );
    final Map<int, int> setItemCounts = await _loadGroupedCounts(
      tableName: 'set_items',
      productIds: ids,
    );
    final Map<int, int> groupCounts = await _loadGroupedCounts(
      tableName: 'modifier_groups',
      productIds: ids,
    );
    final Map<int, int> choiceMemberCounts = await _loadGroupedCounts(
      tableName: 'product_modifiers',
      productIds: ids,
      whereClause: "type = 'choice'",
    );
    final Map<int, int> extraPoolCounts = await _loadGroupedCounts(
      tableName: 'product_modifiers',
      productIds: ids,
      whereClause: "type = 'extra' AND item_product_id IS NOT NULL",
    );

    final Map<int, ProductMenuConfigurationProfile> profiles =
        <int, ProductMenuConfigurationProfile>{};
    for (final int productId in ids) {
      profiles[productId] = ProductMenuConfigurationProfile(
        productId: productId,
        flatModifierCount: flatCounts[productId] ?? 0,
        setItemCount: setItemCounts[productId] ?? 0,
        choiceGroupCount: groupCounts[productId] ?? 0,
        choiceMemberCount: choiceMemberCounts[productId] ?? 0,
        extraPoolCount: extraPoolCounts[productId] ?? 0,
      );
    }
    return profiles;
  }

  Future<SemanticProductConfigurationDraft> loadAdminConfigurationDraft(
    int rootProductId,
  ) async {
    final List<db.SetItem> setItems =
        await (_database.select(_database.setItems)
              ..where(
                (db.$SetItemsTable t) => t.productId.equals(rootProductId),
              )
              ..orderBy(<OrderingTerm Function(db.$SetItemsTable)>[
                (db.$SetItemsTable t) => OrderingTerm.asc(t.sortOrder),
                (db.$SetItemsTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    final List<db.ModifierGroup> groups =
        await (_database.select(_database.modifierGroups)
              ..where(
                (db.$ModifierGroupsTable t) =>
                    t.productId.equals(rootProductId),
              )
              ..orderBy(<OrderingTerm Function(db.$ModifierGroupsTable)>[
                (db.$ModifierGroupsTable t) => OrderingTerm.asc(t.sortOrder),
                (db.$ModifierGroupsTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    final List<db.ProductModifier> choiceRows =
        await (_database.select(_database.productModifiers)
              ..where((db.$ProductModifiersTable t) {
                return t.productId.equals(rootProductId) &
                    t.type.equals('choice');
              })
              ..orderBy(<OrderingTerm Function(db.$ProductModifiersTable)>[
                (db.$ProductModifiersTable t) => OrderingTerm.asc(t.groupId),
                (db.$ProductModifiersTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    final List<db.ProductModifier> extraRows =
        await (_database.select(_database.productModifiers)
              ..where((db.$ProductModifiersTable t) {
                return t.productId.equals(rootProductId) &
                    t.type.equals('extra') &
                    t.itemProductId.isNotNull();
              })
              ..orderBy(<OrderingTerm Function(db.$ProductModifiersTable)>[
                (db.$ProductModifiersTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    final Set<int> relatedProductIds = <int>{};
    for (final db.SetItem item in setItems) {
      relatedProductIds.add(item.itemProductId);
    }
    for (final db.ProductModifier modifier in choiceRows) {
      if (modifier.itemProductId != null) {
        relatedProductIds.add(modifier.itemProductId!);
      }
    }
    for (final db.ProductModifier modifier in extraRows) {
      if (modifier.itemProductId != null) {
        relatedProductIds.add(modifier.itemProductId!);
      }
    }

    final Map<int, BreakfastCatalogProduct> productsById =
        await loadCatalogProductsByIds(relatedProductIds);

    final List<SemanticSetItemDraft> setItemDrafts = setItems
        .map((db.SetItem item) {
          final BreakfastCatalogProduct? product =
              productsById[item.itemProductId];
          return SemanticSetItemDraft(
            id: item.id,
            itemProductId: item.itemProductId,
            itemName: product?.name ?? 'Product ${item.itemProductId}',
            defaultQuantity: item.defaultQuantity,
            isRemovable: item.isRemovable,
            sortOrder: item.sortOrder,
          );
        })
        .toList(growable: false);

    final Map<int, List<SemanticChoiceMemberDraft>> membersByGroupId =
        <int, List<SemanticChoiceMemberDraft>>{};
    for (int index = 0; index < choiceRows.length; index += 1) {
      final db.ProductModifier modifier = choiceRows[index];
      final int? groupId = modifier.groupId;
      final int? itemProductId = modifier.itemProductId;
      if (groupId == null || itemProductId == null) {
        continue;
      }
      final BreakfastCatalogProduct? product = productsById[itemProductId];
      membersByGroupId
          .putIfAbsent(groupId, () => <SemanticChoiceMemberDraft>[])
          .add(
            SemanticChoiceMemberDraft(
              id: modifier.id,
              itemProductId: itemProductId,
              itemName: product?.name ?? modifier.name,
              position: membersByGroupId[groupId]?.length ?? 0,
            ),
          );
    }

    final List<SemanticChoiceGroupDraft> groupDrafts = groups
        .map((db.ModifierGroup group) {
          return SemanticChoiceGroupDraft(
            id: group.id,
            name: group.name,
            minSelect: group.minSelect,
            maxSelect: group.maxSelect,
            includedQuantity: group.includedQuantity,
            sortOrder: group.sortOrder,
            members: List<SemanticChoiceMemberDraft>.unmodifiable(
              membersByGroupId[group.id] ?? const <SemanticChoiceMemberDraft>[],
            ),
          );
        })
        .toList(growable: false);
    final List<SemanticExtraItemDraft> extraDrafts =
        List<SemanticExtraItemDraft>.generate(extraRows.length, (int index) {
          final db.ProductModifier modifier = extraRows[index];
          final int itemProductId = modifier.itemProductId!;
          final BreakfastCatalogProduct? product = productsById[itemProductId];
          return SemanticExtraItemDraft(
            id: modifier.id,
            itemProductId: itemProductId,
            itemName: product?.name ?? modifier.name,
            sortOrder: index,
          );
        }, growable: false);

    return SemanticProductConfigurationDraft(
      productId: rootProductId,
      setItems: List<SemanticSetItemDraft>.unmodifiable(setItemDrafts),
      choiceGroups: List<SemanticChoiceGroupDraft>.unmodifiable(groupDrafts),
      extras: List<SemanticExtraItemDraft>.unmodifiable(extraDrafts),
    );
  }

  Future<void> replaceAdminConfiguration(
    SemanticProductConfigurationDraft configuration,
  ) {
    return _database.transaction(() async {
      await (_database.delete(_database.productModifiers)..where(
            (db.$ProductModifiersTable t) =>
                t.productId.equals(configuration.productId) &
                (t.type.equals('choice') |
                    (t.type.equals('extra') & t.itemProductId.isNotNull())),
          ))
          .go();
      await (_database.delete(_database.modifierGroups)..where(
            (db.$ModifierGroupsTable t) =>
                t.productId.equals(configuration.productId),
          ))
          .go();
      await (_database.delete(_database.setItems)..where(
            (db.$SetItemsTable t) =>
                t.productId.equals(configuration.productId),
          ))
          .go();

      for (final SemanticSetItemDraft item in configuration.setItems) {
        await _database
            .into(_database.setItems)
            .insert(
              db.SetItemsCompanion.insert(
                productId: configuration.productId,
                itemProductId: item.itemProductId,
                isRemovable: Value<bool>(item.isRemovable),
                defaultQuantity: Value<int>(item.defaultQuantity),
                sortOrder: Value<int>(item.sortOrder),
              ),
            );
      }

      for (final SemanticChoiceGroupDraft group in configuration.choiceGroups) {
        final int groupId = await _database
            .into(_database.modifierGroups)
            .insert(
              db.ModifierGroupsCompanion.insert(
                productId: configuration.productId,
                name: group.name,
                minSelect: Value<int>(group.minSelect),
                maxSelect: Value<int>(group.maxSelect),
                includedQuantity: Value<int>(group.includedQuantity),
                sortOrder: Value<int>(group.sortOrder),
              ),
            );

        for (final SemanticChoiceMemberDraft member in group.members) {
          await _database
              .into(_database.productModifiers)
              .insert(
                db.ProductModifiersCompanion.insert(
                  productId: configuration.productId,
                  groupId: Value<int?>(groupId),
                  itemProductId: Value<int?>(member.itemProductId),
                  name: member.itemName,
                  type: 'choice',
                  extraPriceMinor: const Value<int>(0),
                  isActive: const Value<bool>(true),
                ),
              );
        }
      }

      final List<SemanticExtraItemDraft> extras =
          List<SemanticExtraItemDraft>.from(configuration.extras)..sort(
            (SemanticExtraItemDraft a, SemanticExtraItemDraft b) =>
                a.sortOrder.compareTo(b.sortOrder),
          );
      for (final SemanticExtraItemDraft extra in extras) {
        await _database
            .into(_database.productModifiers)
            .insert(
              db.ProductModifiersCompanion.insert(
                productId: configuration.productId,
                groupId: const Value<int?>(null),
                itemProductId: Value<int?>(extra.itemProductId),
                name: extra.itemName,
                type: 'extra',
                extraPriceMinor: const Value<int>(0),
                isActive: const Value<bool>(true),
              ),
            );
      }
    });
  }

  Future<Set<int>> loadSetRootProductIds() async {
    final Set<int> ids = <int>{};
    ids.addAll(await _loadProductIdsFromTable('set_items'));
    ids.addAll(await _loadProductIdsFromTable('modifier_groups'));
    ids.addAll(
      await _loadProductIdsFromTable(
        'product_modifiers',
        whereClause: "type = 'choice'",
      ),
    );
    return ids;
  }

  Future<Set<int>> loadChoiceMemberProductIds() async {
    final List<QueryRow> rows = await _database.customSelect('''
        SELECT DISTINCT item_product_id
        FROM product_modifiers
        WHERE type = 'choice' AND item_product_id IS NOT NULL
      ''').get();
    return rows.map((QueryRow row) => row.read<int>('item_product_id')).toSet();
  }

  Future<Map<int, int>> _loadGroupedCounts({
    required String tableName,
    required List<int> productIds,
    String? whereClause,
  }) async {
    final String where = whereClause == null || whereClause.trim().isEmpty
        ? ''
        : ' AND $whereClause';
    final List<QueryRow> rows = await _database.customSelect('''
        SELECT product_id, COUNT(*) AS row_count
        FROM $tableName
        WHERE product_id IN (${productIds.join(',')})$where
        GROUP BY product_id
      ''').get();

    final Map<int, int> counts = <int, int>{};
    for (final QueryRow row in rows) {
      counts[row.read<int>('product_id')] = row.read<int>('row_count');
    }
    return counts;
  }

  Future<Set<int>> _loadProductIdsFromTable(
    String tableName, {
    String? whereClause,
  }) async {
    final String where = whereClause == null || whereClause.trim().isEmpty
        ? ''
        : ' WHERE $whereClause';
    final List<QueryRow> rows = await _database
        .customSelect('SELECT DISTINCT product_id FROM $tableName$where')
        .get();
    return rows.map((QueryRow row) => row.read<int>('product_id')).toSet();
  }
}
