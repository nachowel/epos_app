import 'package:drift/drift.dart';

import '../../domain/models/breakfast_rebuild.dart';
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

    return BreakfastSetConfiguration(
      setRootProductId: rootProductId,
      setItems: setItemConfigs,
      choiceGroups: groupConfigs,
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
}
