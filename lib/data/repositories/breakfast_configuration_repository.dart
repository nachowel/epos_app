import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/breakfast_rebuild.dart';
import '../../domain/models/breakfast_extra_preset.dart';
import '../../domain/models/semantic_product_configuration.dart';
import '../database/app_database.dart' as db;

class BreakfastConfigurationRepository {
  const BreakfastConfigurationRepository(this._database);

  final db.AppDatabase _database;

  Future<void> bootstrapBreakfastSetRoot(int rootProductId) {
    return _database.transaction(() async {
      final List<db.ModifierGroup> existingGroups =
          await (_database.select(_database.modifierGroups)..where(
                (db.$ModifierGroupsTable t) =>
                    t.productId.equals(rootProductId),
              ))
              .get();
      if (existingGroups.isNotEmpty) {
        return;
      }

      final List<_BreakfastBootstrapCatalogProduct> availableProducts =
          await _loadBootstrapCatalogProducts();

      for (final _BreakfastBootstrapChoiceGroupTemplate groupTemplate
          in _defaultBreakfastChoiceGroupTemplates) {
        final int groupId = await _database
            .into(_database.modifierGroups)
            .insert(
              db.ModifierGroupsCompanion.insert(
                productId: rootProductId,
                name: groupTemplate.name,
                minSelect: Value<int>(groupTemplate.minSelect),
                maxSelect: Value<int>(groupTemplate.maxSelect),
                includedQuantity: Value<int>(groupTemplate.includedQuantity),
                sortOrder: Value<int>(groupTemplate.sortOrder),
              ),
            );
        for (final _BreakfastBootstrapChoiceMemberTemplate memberTemplate
            in groupTemplate.members) {
          final _BreakfastBootstrapCatalogProduct? product =
              _findBootstrapProduct(
                availableProducts: availableProducts,
                normalizedNames: memberTemplate.normalizedNames,
              );
          if (product == null) {
            continue;
          }
          await _database
              .into(_database.productModifiers)
              .insert(
                db.ProductModifiersCompanion.insert(
                  productId: rootProductId,
                  groupId: Value<int?>(groupId),
                  itemProductId: Value<int?>(product.id),
                  name: product.name,
                  type: 'choice',
                  extraPriceMinor: const Value<int>(0),
                  isActive: const Value<bool>(true),
                ),
              );
        }
      }
    });
  }

  Future<List<_BreakfastBootstrapCatalogProduct>>
  _loadBootstrapCatalogProducts() async {
    final List<QueryRow> rows = await _database
        .customSelect(
          '''
      SELECT p.id, p.name
      FROM products p
      INNER JOIN categories c ON c.id = p.category_id
      WHERE p.is_active = 1
        AND LOWER(TRIM(c.name)) != 'set breakfast'
      ORDER BY p.sort_order ASC, p.id ASC
      ''',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.products,
            _database.categories,
          },
        )
        .get();
    return rows
        .map(
          (QueryRow row) => _BreakfastBootstrapCatalogProduct(
            id: row.read<int>('id'),
            name: row.read<String>('name'),
          ),
        )
        .toList(growable: false);
  }

  _BreakfastBootstrapCatalogProduct? _findBootstrapProduct({
    required List<_BreakfastBootstrapCatalogProduct> availableProducts,
    required Set<String> normalizedNames,
  }) {
    for (final _BreakfastBootstrapCatalogProduct product in availableProducts) {
      if (normalizedNames.contains(product.normalizedName)) {
        return product;
      }
    }
    return null;
  }

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
    final bool hasSemanticFootprint =
        setItems.isNotEmpty || groups.isNotEmpty || productModifiers.isNotEmpty;
    if (!hasSemanticFootprint) {
      return null;
    }

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
    final _BreakfastConfigProductContext? rootProduct =
        await _loadProductContext(rootProductId);
    final Set<int> setRootProductIds = await loadSetRootProductIds();
    final List<BreakfastConfigurationIssue> issues = _validateRuntimeSnapshot(
      rootProductId: rootProductId,
      rootProduct: rootProduct,
      setItems: setItems,
      groups: groups,
      productModifiers: productModifiers,
      setRootProductIds: setRootProductIds,
    );
    if (issues.isNotEmpty) {
      throw BreakfastConfigurationInvalidException(
        rootProductId: rootProductId,
        issues: issues,
      );
    }

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

  List<BreakfastConfigurationIssue> _validateRuntimeSnapshot({
    required int rootProductId,
    required _BreakfastConfigProductContext? rootProduct,
    required List<db.SetItem> setItems,
    required List<db.ModifierGroup> groups,
    required List<db.ProductModifier> productModifiers,
    required Set<int> setRootProductIds,
  }) {
    final List<BreakfastConfigurationIssue> issues =
        <BreakfastConfigurationIssue>[];
    if (rootProduct == null || !_isSetBreakfastCategory(rootProduct.category)) {
      issues.add(
        const BreakfastConfigurationIssue(
          code: BreakfastConfigurationErrorCode.invalidSetRoot,
        ),
      );
    }

    final Map<int, db.ModifierGroup> groupsById = <int, db.ModifierGroup>{
      for (final db.ModifierGroup group in groups) group.id: group,
    };
    final Set<int> localChoiceMemberProductIds = <int>{};
    for (final db.ModifierGroup group in groups) {
      if (group.minSelect < 0 ||
          group.maxSelect <= 0 ||
          group.maxSelect < group.minSelect) {
        issues.add(
          BreakfastConfigurationIssue(
            code: BreakfastConfigurationErrorCode.invalidChoiceBounds,
            groupId: group.id,
          ),
        );
      }
      if (group.includedQuantity <= 0 ||
          group.includedQuantity > group.maxSelect) {
        issues.add(
          BreakfastConfigurationIssue(
            code: BreakfastConfigurationErrorCode.invalidIncludedQuantity,
            groupId: group.id,
          ),
        );
      }
    }

    final Set<int> groupsWithMembers = <int>{};
    for (final db.ProductModifier modifier in productModifiers) {
      final int? groupId = modifier.groupId;
      final int? itemProductId = modifier.itemProductId;
      if (groupId == null || !groupsById.containsKey(groupId)) {
        issues.add(
          BreakfastConfigurationIssue(
            code: BreakfastConfigurationErrorCode.invalidChoiceGroup,
            groupId: groupId,
            productModifierId: modifier.id,
          ),
        );
      } else {
        groupsWithMembers.add(groupId);
      }
      if (itemProductId == null) {
        issues.add(
          BreakfastConfigurationIssue(
            code: BreakfastConfigurationErrorCode.missingItemProductId,
            groupId: groupId,
            productModifierId: modifier.id,
          ),
        );
        continue;
      }
      localChoiceMemberProductIds.add(itemProductId);
      if (itemProductId == rootProductId ||
          setRootProductIds.contains(itemProductId)) {
        issues.add(
          BreakfastConfigurationIssue(
            code: BreakfastConfigurationErrorCode.wrongProductRoleAssignment,
            groupId: groupId,
            itemProductId: itemProductId,
            productModifierId: modifier.id,
          ),
        );
      }
    }

    for (final db.ModifierGroup group in groups) {
      if (!groupsWithMembers.contains(group.id)) {
        issues.add(
          BreakfastConfigurationIssue(
            code: BreakfastConfigurationErrorCode.invalidChoiceGroup,
            groupId: group.id,
          ),
        );
      }
    }

    for (final db.SetItem item in setItems) {
      if (item.itemProductId == rootProductId ||
          setRootProductIds.contains(item.itemProductId)) {
        issues.add(
          BreakfastConfigurationIssue(
            code: BreakfastConfigurationErrorCode.wrongProductRoleAssignment,
            itemProductId: item.itemProductId,
          ),
        );
      }
      if (localChoiceMemberProductIds.contains(item.itemProductId)) {
        issues.add(
          BreakfastConfigurationIssue(
            code:
                BreakfastConfigurationErrorCode.choiceCapableProductInSetItems,
            itemProductId: item.itemProductId,
          ),
        );
      }
    }

    return issues;
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

  Future<List<BreakfastExtraPreset>> loadExtraPresets() async {
    final List<db.BreakfastExtraPreset> presetRows =
        await (_database.select(_database.breakfastExtraPresets)
              ..orderBy(<OrderingTerm Function(db.$BreakfastExtraPresetsTable)>[
                (db.$BreakfastExtraPresetsTable t) => OrderingTerm.asc(t.name),
                (db.$BreakfastExtraPresetsTable t) =>
                    OrderingTerm.desc(t.updatedAt),
                (db.$BreakfastExtraPresetsTable t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    if (presetRows.isEmpty) {
      return const <BreakfastExtraPreset>[];
    }

    final List<int> presetIds = presetRows
        .map((db.BreakfastExtraPreset preset) => preset.id)
        .toList(growable: false);
    final List<db.BreakfastExtraPresetItem> itemRows =
        await (_database.select(_database.breakfastExtraPresetItems)
              ..where(
                (db.$BreakfastExtraPresetItemsTable t) =>
                    t.presetId.isIn(presetIds),
              )
              ..orderBy(
                <OrderingTerm Function(db.$BreakfastExtraPresetItemsTable)>[
                  (db.$BreakfastExtraPresetItemsTable t) =>
                      OrderingTerm.asc(t.presetId),
                  (db.$BreakfastExtraPresetItemsTable t) =>
                      OrderingTerm.asc(t.sortOrder),
                  (db.$BreakfastExtraPresetItemsTable t) =>
                      OrderingTerm.asc(t.id),
                ],
              ))
            .get();

    final Map<int, BreakfastCatalogProduct> productsById =
        await loadCatalogProductsByIds(
          itemRows.map((db.BreakfastExtraPresetItem row) => row.itemProductId),
        );
    final Map<int, List<BreakfastExtraPresetItem>> itemsByPresetId =
        <int, List<BreakfastExtraPresetItem>>{};
    for (final db.BreakfastExtraPresetItem row in itemRows) {
      final BreakfastCatalogProduct? product = productsById[row.itemProductId];
      itemsByPresetId
          .putIfAbsent(row.presetId, () => <BreakfastExtraPresetItem>[])
          .add(
            BreakfastExtraPresetItem(
              itemProductId: row.itemProductId,
              itemName: product?.name ?? 'Product ${row.itemProductId}',
              sortOrder: row.sortOrder,
            ),
          );
    }

    return presetRows
        .map((db.BreakfastExtraPreset row) {
          return BreakfastExtraPreset(
            id: row.id,
            name: row.name,
            items: List<BreakfastExtraPresetItem>.unmodifiable(
              itemsByPresetId[row.id] ?? const <BreakfastExtraPresetItem>[],
            ),
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          );
        })
        .toList(growable: false);
  }

  Future<int> saveExtraPreset({
    int? presetId,
    required String name,
    required List<int> itemProductIds,
  }) {
    return _database.transaction(() async {
      final DateTime now = DateTime.now();
      late final int effectivePresetId;
      if (presetId == null) {
        effectivePresetId = await _database
            .into(_database.breakfastExtraPresets)
            .insert(
              db.BreakfastExtraPresetsCompanion.insert(
                name: name,
                createdAt: Value<DateTime>(now),
                updatedAt: Value<DateTime>(now),
              ),
            );
      } else {
        final int updatedCount =
            await (_database.update(_database.breakfastExtraPresets)
                  ..where((db.$BreakfastExtraPresetsTable t) {
                    return t.id.equals(presetId);
                  }))
                .write(
                  db.BreakfastExtraPresetsCompanion(
                    name: Value<String>(name),
                    updatedAt: Value<DateTime>(now),
                  ),
                );
        if (updatedCount == 0) {
          throw NotFoundException('Breakfast extras preset not found.');
        }
        effectivePresetId = presetId;
        await (_database.delete(_database.breakfastExtraPresetItems)..where(
              (db.$BreakfastExtraPresetItemsTable t) =>
                  t.presetId.equals(effectivePresetId),
            ))
            .go();
      }

      for (int index = 0; index < itemProductIds.length; index += 1) {
        await _database
            .into(_database.breakfastExtraPresetItems)
            .insert(
              db.BreakfastExtraPresetItemsCompanion.insert(
                presetId: effectivePresetId,
                itemProductId: itemProductIds[index],
                sortOrder: Value<int>(index),
              ),
            );
      }
      return effectivePresetId;
    });
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

  Future<_BreakfastConfigProductContext?> _loadProductContext(
    int productId,
  ) async {
    final List<QueryRow> rows = await _database
        .customSelect(
          '''
        SELECT p.id, p.name, c.name AS category_name
        FROM products p
        INNER JOIN categories c ON c.id = p.category_id
        WHERE p.id = ?
        LIMIT 1
      ''',
          variables: <Variable<Object>>[Variable<int>(productId)],
        )
        .get();
    if (rows.isEmpty) {
      return null;
    }

    final QueryRow row = rows.single;
    return _BreakfastConfigProductContext(
      id: row.read<int>('id'),
      name: row.read<String>('name'),
      category: row.read<String>('category_name'),
    );
  }

  bool _isSetBreakfastCategory(String categoryName) =>
      categoryName.trim().toLowerCase() == 'set breakfast';
}

class _BreakfastConfigProductContext {
  const _BreakfastConfigProductContext({
    required this.id,
    required this.name,
    required this.category,
  });

  final int id;
  final String name;
  final String category;
}

class _BreakfastBootstrapChoiceGroupTemplate {
  const _BreakfastBootstrapChoiceGroupTemplate({
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.includedQuantity,
    required this.sortOrder,
    required this.members,
  });

  final String name;
  final int minSelect;
  final int maxSelect;
  final int includedQuantity;
  final int sortOrder;
  final List<_BreakfastBootstrapChoiceMemberTemplate> members;
}

class _BreakfastBootstrapChoiceMemberTemplate {
  const _BreakfastBootstrapChoiceMemberTemplate(this.normalizedNames);

  final Set<String> normalizedNames;
}

class _BreakfastBootstrapCatalogProduct {
  const _BreakfastBootstrapCatalogProduct({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  String get normalizedName => name.trim().toLowerCase();
}

const List<_BreakfastBootstrapChoiceGroupTemplate>
_defaultBreakfastChoiceGroupTemplates =
    <_BreakfastBootstrapChoiceGroupTemplate>[
      _BreakfastBootstrapChoiceGroupTemplate(
        name: 'Tea or Coffee',
        minSelect: 1,
        maxSelect: 1,
        includedQuantity: 1,
        sortOrder: 1,
        members: <_BreakfastBootstrapChoiceMemberTemplate>[
          _BreakfastBootstrapChoiceMemberTemplate(<String>{'tea'}),
          _BreakfastBootstrapChoiceMemberTemplate(<String>{
            'cappucino',
            'cappuccino',
            'latte',
          }),
        ],
      ),
      _BreakfastBootstrapChoiceGroupTemplate(
        name: 'Toast or Bread',
        minSelect: 1,
        maxSelect: 1,
        includedQuantity: 1,
        sortOrder: 2,
        members: <_BreakfastBootstrapChoiceMemberTemplate>[
          _BreakfastBootstrapChoiceMemberTemplate(<String>{'toasts', 'toast'}),
          _BreakfastBootstrapChoiceMemberTemplate(<String>{'breads', 'bread'}),
        ],
      ),
    ];
