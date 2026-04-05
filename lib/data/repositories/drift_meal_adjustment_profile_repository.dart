import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/meal_adjustment_profile.dart';
import '../../domain/repositories/meal_adjustment_profile_repository.dart';
import '../database/app_database.dart' as db;

class DriftMealAdjustmentProfileRepository
    implements MealAdjustmentProfileRepository {
  const DriftMealAdjustmentProfileRepository(this._database);

  final db.AppDatabase _database;

  @override
  Future<List<MealAdjustmentProfile>> listProfiles({
    bool activeOnly = true,
  }) async {
    final query = _database.select(_database.mealAdjustmentProfiles)
      ..orderBy(<OrderingTerm Function(db.$MealAdjustmentProfilesTable)>[
        (db.$MealAdjustmentProfilesTable t) => OrderingTerm.asc(t.name),
        (db.$MealAdjustmentProfilesTable t) => OrderingTerm.asc(t.id),
      ]);
    if (activeOnly) {
      query.where(
        (db.$MealAdjustmentProfilesTable t) => t.isActive.equals(true),
      );
    }

    final List<db.MealAdjustmentProfile> rows = await query.get();
    return rows
        .map((db.MealAdjustmentProfile row) => _mapProfileRow(row))
        .toList(growable: false);
  }

  @override
  Future<List<MealAdjustmentProfile>> listProfilesForAdmin() {
    return listProfiles(activeOnly: false);
  }

  @override
  Future<MealAdjustmentProfile?> getProfileById(int id) async {
    final _ProfileGraph? graph = await _loadProfileGraph(id);
    if (graph == null) {
      return null;
    }

    return MealAdjustmentProfile(
      id: graph.profile.id,
      name: graph.profile.name,
      description: graph.profile.description,
      freeSwapLimit: graph.profile.freeSwapLimit,
      isActive: graph.profile.isActive,
      createdAt: graph.profile.createdAt,
      updatedAt: graph.profile.updatedAt,
      components: graph.components
          .map(
            (db.MealAdjustmentProfileComponent row) => MealAdjustmentComponent(
              id: row.id,
              profileId: row.profileId,
              componentKey: row.componentKey,
              displayName: row.displayName,
              defaultItemProductId: row.defaultItemProductId,
              quantity: row.quantity,
              canRemove: row.canRemove,
              sortOrder: row.sortOrder,
              isActive: row.isActive,
              swapOptions:
                  graph.optionsByComponentId[row.id] ??
                  const <MealAdjustmentComponentOption>[],
            ),
          )
          .toList(growable: false),
      extraOptions: graph.extras
          .map(
            (db.MealAdjustmentProfileExtra row) => MealAdjustmentExtraOption(
              id: row.id,
              profileId: row.profileId,
              itemProductId: row.itemProductId,
              fixedPriceDeltaMinor: row.fixedPriceDeltaMinor,
              sortOrder: row.sortOrder,
              isActive: row.isActive,
            ),
          )
          .toList(growable: false),
      pricingRules: graph.rules
          .map(
            (db.MealAdjustmentPricingRule row) => MealAdjustmentPricingRule(
              id: row.id,
              profileId: row.profileId,
              name: row.name,
              ruleType: _mapRuleTypeFromDb(row.ruleType),
              priceDeltaMinor: row.priceDeltaMinor,
              priority: row.priority,
              isActive: row.isActive,
              conditions:
                  graph.conditionsByRuleId[row.id] ??
                  const <MealAdjustmentPricingRuleCondition>[],
            ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<MealAdjustmentProfileDraft?> loadProfileDraft(int id) async {
    final _ProfileGraph? graph = await _loadProfileGraph(id);
    if (graph == null) {
      return null;
    }

    return MealAdjustmentProfileDraft(
      id: graph.profile.id,
      name: graph.profile.name,
      description: graph.profile.description,
      freeSwapLimit: graph.profile.freeSwapLimit,
      isActive: graph.profile.isActive,
      components: graph.components
          .map(
            (db.MealAdjustmentProfileComponent row) =>
                MealAdjustmentComponentDraft(
                  id: row.id,
                  componentKey: row.componentKey,
                  displayName: row.displayName,
                  defaultItemProductId: row.defaultItemProductId,
                  quantity: row.quantity,
                  canRemove: row.canRemove,
                  sortOrder: row.sortOrder,
                  isActive: row.isActive,
                  swapOptions:
                      graph.optionDraftsByComponentId[row.id] ??
                      const <MealAdjustmentComponentOptionDraft>[],
                ),
          )
          .toList(growable: false),
      extraOptions: graph.extras
          .map(
            (db.MealAdjustmentProfileExtra row) =>
                MealAdjustmentExtraOptionDraft(
                  id: row.id,
                  itemProductId: row.itemProductId,
                  fixedPriceDeltaMinor: row.fixedPriceDeltaMinor,
                  sortOrder: row.sortOrder,
                  isActive: row.isActive,
                ),
          )
          .toList(growable: false),
      pricingRules: graph.rules
          .map(
            (db.MealAdjustmentPricingRule row) =>
                MealAdjustmentPricingRuleDraft(
                  id: row.id,
                  name: row.name,
                  ruleType: _mapRuleTypeFromDb(row.ruleType),
                  priceDeltaMinor: row.priceDeltaMinor,
                  priority: row.priority,
                  isActive: row.isActive,
                  conditions:
                      graph.conditionDraftsByRuleId[row.id] ??
                      const <MealAdjustmentPricingRuleConditionDraft>[],
                ),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<int> saveProfileDraft(MealAdjustmentProfileDraft draft) {
    return _database.transaction(() async {
      final DateTime now = DateTime.now();
      final int effectiveProfileId;
      if (draft.id == null) {
        effectiveProfileId = await _database
            .into(_database.mealAdjustmentProfiles)
            .insert(
              db.MealAdjustmentProfilesCompanion.insert(
                name: draft.name,
                description: Value<String?>(draft.description),
                freeSwapLimit: Value<int>(draft.freeSwapLimit),
                isActive: Value<bool>(draft.isActive),
                createdAt: Value<DateTime>(now),
                updatedAt: Value<DateTime>(now),
              ),
            );
      } else {
        final int updatedCount =
            await (_database.update(_database.mealAdjustmentProfiles)..where(
                  (db.$MealAdjustmentProfilesTable t) => t.id.equals(draft.id!),
                ))
                .write(
                  db.MealAdjustmentProfilesCompanion(
                    name: Value<String>(draft.name),
                    description: Value<String?>(draft.description),
                    freeSwapLimit: Value<int>(draft.freeSwapLimit),
                    isActive: Value<bool>(draft.isActive),
                    updatedAt: Value<DateTime>(now),
                  ),
                );
        if (updatedCount == 0) {
          throw NotFoundException(
            'Meal adjustment profile not found: ${draft.id}',
          );
        }
        effectiveProfileId = draft.id!;
        await _deleteNestedProfileRows(effectiveProfileId);
      }

      await _insertProfileComponents(
        profileId: effectiveProfileId,
        components: draft.components,
      );
      await _insertProfileExtras(
        profileId: effectiveProfileId,
        extras: draft.extraOptions,
      );
      await _insertPricingRules(
        profileId: effectiveProfileId,
        rules: draft.pricingRules,
      );

      return effectiveProfileId;
    });
  }

  @override
  Future<bool> deleteProfile(int profileId) {
    return _database.transaction(() async {
      // Unassign all products using this profile first.
      await (_database.update(_database.products)..where(
            (db.$ProductsTable t) =>
                t.mealAdjustmentProfileId.equals(profileId),
          ))
          .write(
            const db.ProductsCompanion(
              mealAdjustmentProfileId: Value<int?>(null),
            ),
          );
      await _deleteNestedProfileRows(profileId);
      final int deletedCount = await (_database.delete(
            _database.mealAdjustmentProfiles,
          )..where(
            (db.$MealAdjustmentProfilesTable t) => t.id.equals(profileId),
          ))
          .go();
      return deletedCount > 0;
    });
  }

  @override
  Future<bool> assignProfileToProduct({
    required int productId,
    int? profileId,
  }) async {
    final int updatedCount =
        await (_database.update(
          _database.products,
        )..where((db.$ProductsTable t) => t.id.equals(productId))).write(
          db.ProductsCompanion(mealAdjustmentProfileId: Value<int?>(profileId)),
        );
    return updatedCount > 0;
  }

  @override
  Future<List<MealAdjustmentProductSummary>> listProductsByProfile(
    int profileId, {
    bool activeOnly = false,
  }) async {
    final List<QueryRow> rows = await _database
        .customSelect(
          '''
          SELECT
            p.id,
            p.category_id,
            p.name,
            p.is_active,
            p.meal_adjustment_profile_id,
            c.name AS category_name
          FROM products p
          INNER JOIN categories c ON c.id = p.category_id
          WHERE p.meal_adjustment_profile_id = ?
            ${activeOnly ? 'AND p.is_active = 1' : ''}
          ORDER BY p.sort_order ASC, p.id ASC
          ''',
          variables: <Variable<Object>>[Variable<int>(profileId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.products,
            _database.categories,
          },
        )
        .get();

    return rows
        .map((QueryRow row) => _mapProductSummaryRow(row))
        .toList(growable: false);
  }

  @override
  Future<Map<int, MealAdjustmentProductSummary>> loadProductSummariesByIds(
    Iterable<int> productIds,
  ) async {
    final List<int> ids = productIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return <int, MealAdjustmentProductSummary>{};
    }

    final List<QueryRow> rows = await _database
        .customSelect(
          '''
          SELECT
            p.id,
            p.category_id,
            p.name,
            p.is_active,
            p.meal_adjustment_profile_id,
            c.name AS category_name
          FROM products p
          INNER JOIN categories c ON c.id = p.category_id
          WHERE p.id IN (${ids.join(',')})
          ORDER BY p.id ASC
          ''',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.products,
            _database.categories,
          },
        )
        .get();

    final Map<int, MealAdjustmentProductSummary> summaries =
        <int, MealAdjustmentProductSummary>{};
    for (final QueryRow row in rows) {
      final MealAdjustmentProductSummary summary = _mapProductSummaryRow(row);
      summaries[summary.id] = summary;
    }
    return summaries;
  }

  @override
  Future<Set<int>> loadBreakfastSemanticProductIds(
    Iterable<int> productIds,
  ) async {
    final List<int> ids = productIds.toSet().toList(growable: false);
    if (ids.isEmpty) {
      return <int>{};
    }

    final List<QueryRow> rows = await _database
        .customSelect(
          '''
          SELECT product_id
          FROM (
            SELECT product_id
            FROM set_items
            WHERE product_id IN (${ids.join(',')})
            UNION
            SELECT item_product_id AS product_id
            FROM set_items
            WHERE item_product_id IN (${ids.join(',')})
            UNION
            SELECT product_id
            FROM modifier_groups
            WHERE product_id IN (${ids.join(',')})
            UNION
            SELECT product_id
            FROM product_modifiers
            WHERE product_id IN (${ids.join(',')})
            UNION
            SELECT item_product_id AS product_id
            FROM product_modifiers
            WHERE item_product_id IN (${ids.join(',')})
          )
          ''',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.setItems,
            _database.modifierGroups,
            _database.productModifiers,
          },
        )
        .get();

    return rows.map((QueryRow row) => row.read<int>('product_id')).toSet();
  }

  Future<void> _deleteNestedProfileRows(int profileId) async {
    final List<db.MealAdjustmentPricingRule> existingRules =
        await (_database.select(_database.mealAdjustmentPricingRules)..where(
              (db.$MealAdjustmentPricingRulesTable t) =>
                  t.profileId.equals(profileId),
            ))
            .get();
    final List<int> ruleIds = existingRules
        .map((db.MealAdjustmentPricingRule row) => row.id)
        .toList(growable: false);
    if (ruleIds.isNotEmpty) {
      await (_database.delete(_database.mealAdjustmentPricingRuleConditions)
            ..where(
              (db.$MealAdjustmentPricingRuleConditionsTable t) =>
                  t.ruleId.isIn(ruleIds),
            ))
          .go();
    }

    final List<db.MealAdjustmentProfileComponent> existingComponents =
        await (_database.select(_database.mealAdjustmentProfileComponents)
              ..where(
                (db.$MealAdjustmentProfileComponentsTable t) =>
                    t.profileId.equals(profileId),
              ))
            .get();
    final List<int> componentIds = existingComponents
        .map((db.MealAdjustmentProfileComponent row) => row.id)
        .toList(growable: false);
    if (componentIds.isNotEmpty) {
      await (_database.delete(_database.mealAdjustmentComponentOptions)..where(
            (db.$MealAdjustmentComponentOptionsTable t) =>
                t.profileComponentId.isIn(componentIds),
          ))
          .go();
    }

    await (_database.delete(_database.mealAdjustmentPricingRules)..where(
          (db.$MealAdjustmentPricingRulesTable t) =>
              t.profileId.equals(profileId),
        ))
        .go();
    await (_database.delete(_database.mealAdjustmentProfileExtras)..where(
          (db.$MealAdjustmentProfileExtrasTable t) =>
              t.profileId.equals(profileId),
        ))
        .go();
    await (_database.delete(_database.mealAdjustmentProfileComponents)..where(
          (db.$MealAdjustmentProfileComponentsTable t) =>
              t.profileId.equals(profileId),
        ))
        .go();
  }

  Future<void> _insertProfileComponents({
    required int profileId,
    required List<MealAdjustmentComponentDraft> components,
  }) async {
    final List<MealAdjustmentComponentDraft> sortedComponents =
        List<MealAdjustmentComponentDraft>.from(components)..sort((
          MealAdjustmentComponentDraft a,
          MealAdjustmentComponentDraft b,
        ) {
          final int sortCompare = a.sortOrder.compareTo(b.sortOrder);
          if (sortCompare != 0) {
            return sortCompare;
          }
          return a.componentKey.compareTo(b.componentKey);
        });

    for (final MealAdjustmentComponentDraft component in sortedComponents) {
      final int componentId = await _database
          .into(_database.mealAdjustmentProfileComponents)
          .insert(
            db.MealAdjustmentProfileComponentsCompanion.insert(
              profileId: profileId,
              componentKey: component.componentKey,
              displayName: component.displayName,
              defaultItemProductId: component.defaultItemProductId,
              quantity: Value<int>(component.quantity),
              canRemove: Value<bool>(component.canRemove),
              sortOrder: Value<int>(component.sortOrder),
              isActive: Value<bool>(component.isActive),
            ),
          );

      final List<MealAdjustmentComponentOptionDraft> sortedOptions =
          List<MealAdjustmentComponentOptionDraft>.from(component.swapOptions)
            ..sort((
              MealAdjustmentComponentOptionDraft a,
              MealAdjustmentComponentOptionDraft b,
            ) {
              final int sortCompare = a.sortOrder.compareTo(b.sortOrder);
              if (sortCompare != 0) {
                return sortCompare;
              }
              return a.optionItemProductId.compareTo(b.optionItemProductId);
            });
      for (final MealAdjustmentComponentOptionDraft option in sortedOptions) {
        await _database
            .into(_database.mealAdjustmentComponentOptions)
            .insert(
              db.MealAdjustmentComponentOptionsCompanion.insert(
                profileComponentId: componentId,
                optionItemProductId: option.optionItemProductId,
                optionType: _mapOptionType(option.type),
                fixedPriceDeltaMinor: Value<int?>(option.fixedPriceDeltaMinor),
                sortOrder: Value<int>(option.sortOrder),
                isActive: Value<bool>(option.isActive),
              ),
            );
      }
    }
  }

  Future<void> _insertProfileExtras({
    required int profileId,
    required List<MealAdjustmentExtraOptionDraft> extras,
  }) async {
    final List<MealAdjustmentExtraOptionDraft> sortedExtras =
        List<MealAdjustmentExtraOptionDraft>.from(extras)..sort((
          MealAdjustmentExtraOptionDraft a,
          MealAdjustmentExtraOptionDraft b,
        ) {
          final int sortCompare = a.sortOrder.compareTo(b.sortOrder);
          if (sortCompare != 0) {
            return sortCompare;
          }
          return a.itemProductId.compareTo(b.itemProductId);
        });

    for (final MealAdjustmentExtraOptionDraft extra in sortedExtras) {
      await _database
          .into(_database.mealAdjustmentProfileExtras)
          .insert(
            db.MealAdjustmentProfileExtrasCompanion.insert(
              profileId: profileId,
              itemProductId: extra.itemProductId,
              fixedPriceDeltaMinor: extra.fixedPriceDeltaMinor,
              sortOrder: Value<int>(extra.sortOrder),
              isActive: Value<bool>(extra.isActive),
            ),
          );
    }
  }

  Future<void> _insertPricingRules({
    required int profileId,
    required List<MealAdjustmentPricingRuleDraft> rules,
  }) async {
    final List<MealAdjustmentPricingRuleDraft> sortedRules =
        List<MealAdjustmentPricingRuleDraft>.from(rules)..sort((
          MealAdjustmentPricingRuleDraft a,
          MealAdjustmentPricingRuleDraft b,
        ) {
          final int priorityCompare = a.priority.compareTo(b.priority);
          if (priorityCompare != 0) {
            return priorityCompare;
          }
          return a.name.compareTo(b.name);
        });

    for (final MealAdjustmentPricingRuleDraft rule in sortedRules) {
      final int ruleId = await _database
          .into(_database.mealAdjustmentPricingRules)
          .insert(
            db.MealAdjustmentPricingRulesCompanion.insert(
              profileId: profileId,
              name: rule.name,
              ruleType: _mapRuleType(rule.ruleType),
              priceDeltaMinor: rule.priceDeltaMinor,
              priority: Value<int>(rule.priority),
              isActive: Value<bool>(rule.isActive),
            ),
          );

      final List<MealAdjustmentPricingRuleConditionDraft> sortedConditions =
          List<MealAdjustmentPricingRuleConditionDraft>.from(rule.conditions)
            ..sort((
              MealAdjustmentPricingRuleConditionDraft a,
              MealAdjustmentPricingRuleConditionDraft b,
            ) {
              final int typeCompare = a.conditionType.name.compareTo(
                b.conditionType.name,
              );
              if (typeCompare != 0) {
                return typeCompare;
              }
              final int componentCompare = (a.componentKey ?? '').compareTo(
                b.componentKey ?? '',
              );
              if (componentCompare != 0) {
                return componentCompare;
              }
              final int itemCompare = (a.itemProductId ?? -1).compareTo(
                b.itemProductId ?? -1,
              );
              if (itemCompare != 0) {
                return itemCompare;
              }
              return a.quantity.compareTo(b.quantity);
            });
      for (final MealAdjustmentPricingRuleConditionDraft condition
          in sortedConditions) {
        await _database
            .into(_database.mealAdjustmentPricingRuleConditions)
            .insert(
              db.MealAdjustmentPricingRuleConditionsCompanion.insert(
                ruleId: ruleId,
                conditionType: _mapConditionType(condition.conditionType),
                componentKey: Value<String?>(condition.componentKey),
                itemProductId: Value<int?>(condition.itemProductId),
                quantity: Value<int>(condition.quantity),
              ),
            );
      }
    }
  }

  MealAdjustmentProfile _mapProfileRow(db.MealAdjustmentProfile row) {
    return MealAdjustmentProfile(
      id: row.id,
      name: row.name,
      description: row.description,
      freeSwapLimit: row.freeSwapLimit,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  MealAdjustmentProductSummary _mapProductSummaryRow(QueryRow row) {
    return MealAdjustmentProductSummary(
      id: row.read<int>('id'),
      categoryId: row.read<int>('category_id'),
      categoryName: row.read<String>('category_name'),
      name: row.read<String>('name'),
      isActive: row.read<int>('is_active') == 1,
      mealAdjustmentProfileId: row.readNullable<int>(
        'meal_adjustment_profile_id',
      ),
    );
  }

  String _mapOptionType(MealAdjustmentComponentOptionType value) {
    switch (value) {
      case MealAdjustmentComponentOptionType.swap:
        return 'swap';
    }
  }

  MealAdjustmentComponentOptionType _mapOptionTypeFromDb(String value) {
    switch (value) {
      case 'swap':
        return MealAdjustmentComponentOptionType.swap;
    }
    throw StateError('Unknown meal adjustment component option type: $value');
  }

  String _mapRuleType(MealAdjustmentPricingRuleType value) {
    switch (value) {
      case MealAdjustmentPricingRuleType.removeOnly:
        return 'remove_only';
      case MealAdjustmentPricingRuleType.combo:
        return 'combo';
      case MealAdjustmentPricingRuleType.swap:
        return 'swap';
      case MealAdjustmentPricingRuleType.extra:
        return 'extra';
    }
  }

  MealAdjustmentPricingRuleType _mapRuleTypeFromDb(String value) {
    switch (value) {
      case 'remove_only':
        return MealAdjustmentPricingRuleType.removeOnly;
      case 'combo':
        return MealAdjustmentPricingRuleType.combo;
      case 'swap':
        return MealAdjustmentPricingRuleType.swap;
      case 'extra':
        return MealAdjustmentPricingRuleType.extra;
    }
    throw StateError('Unknown meal adjustment pricing rule type: $value');
  }

  String _mapConditionType(MealAdjustmentPricingRuleConditionType value) {
    switch (value) {
      case MealAdjustmentPricingRuleConditionType.removedComponent:
        return 'removed_component';
      case MealAdjustmentPricingRuleConditionType.swapToItem:
        return 'swap_to_item';
      case MealAdjustmentPricingRuleConditionType.extraItem:
        return 'extra_item';
    }
  }

  MealAdjustmentPricingRuleConditionType _mapConditionTypeFromDb(String value) {
    switch (value) {
      case 'removed_component':
        return MealAdjustmentPricingRuleConditionType.removedComponent;
      case 'swap_to_item':
        return MealAdjustmentPricingRuleConditionType.swapToItem;
      case 'extra_item':
        return MealAdjustmentPricingRuleConditionType.extraItem;
    }
    throw StateError(
      'Unknown meal adjustment pricing rule condition type: $value',
    );
  }

  Future<_ProfileGraph?> _loadProfileGraph(int id) async {
    final db.MealAdjustmentProfile? profileRow =
        await (_database.select(_database.mealAdjustmentProfiles)
              ..where((db.$MealAdjustmentProfilesTable t) => t.id.equals(id)))
            .getSingleOrNull();
    if (profileRow == null) {
      return null;
    }

    final List<db.MealAdjustmentProfileComponent> componentRows =
        await (_database.select(_database.mealAdjustmentProfileComponents)
              ..where(
                (db.$MealAdjustmentProfileComponentsTable t) =>
                    t.profileId.equals(id),
              )
              ..orderBy(<
                OrderingTerm Function(db.$MealAdjustmentProfileComponentsTable)
              >[
                (db.$MealAdjustmentProfileComponentsTable t) =>
                    OrderingTerm.asc(t.sortOrder),
                (db.$MealAdjustmentProfileComponentsTable t) =>
                    OrderingTerm.asc(t.id),
              ]))
            .get();
    final List<int> componentIds = componentRows
        .map((db.MealAdjustmentProfileComponent row) => row.id)
        .toList(growable: false);

    final List<db.MealAdjustmentComponentOption> optionRows =
        componentIds.isEmpty
        ? const <db.MealAdjustmentComponentOption>[]
        : await (_database.select(_database.mealAdjustmentComponentOptions)
                ..where(
                  (db.$MealAdjustmentComponentOptionsTable t) =>
                      t.profileComponentId.isIn(componentIds),
                )
                ..orderBy(<
                  OrderingTerm Function(db.$MealAdjustmentComponentOptionsTable)
                >[
                  (db.$MealAdjustmentComponentOptionsTable t) =>
                      OrderingTerm.asc(t.sortOrder),
                  (db.$MealAdjustmentComponentOptionsTable t) =>
                      OrderingTerm.asc(t.id),
                ]))
              .get();

    final List<db.MealAdjustmentProfileExtra> extraRows =
        await (_database.select(_database.mealAdjustmentProfileExtras)
              ..where(
                (db.$MealAdjustmentProfileExtrasTable t) =>
                    t.profileId.equals(id),
              )
              ..orderBy(
                <OrderingTerm Function(db.$MealAdjustmentProfileExtrasTable)>[
                  (db.$MealAdjustmentProfileExtrasTable t) =>
                      OrderingTerm.asc(t.sortOrder),
                  (db.$MealAdjustmentProfileExtrasTable t) =>
                      OrderingTerm.asc(t.id),
                ],
              ))
            .get();

    final List<db.MealAdjustmentPricingRule> ruleRows =
        await (_database.select(_database.mealAdjustmentPricingRules)
              ..where(
                (db.$MealAdjustmentPricingRulesTable t) =>
                    t.profileId.equals(id),
              )
              ..orderBy(
                <OrderingTerm Function(db.$MealAdjustmentPricingRulesTable)>[
                  (db.$MealAdjustmentPricingRulesTable t) =>
                      OrderingTerm.asc(t.priority),
                  (db.$MealAdjustmentPricingRulesTable t) =>
                      OrderingTerm.asc(t.id),
                ],
              ))
            .get();
    final List<int> ruleIds = ruleRows
        .map((db.MealAdjustmentPricingRule row) => row.id)
        .toList(growable: false);

    final List<db.MealAdjustmentPricingRuleCondition> conditionRows =
        ruleIds.isEmpty
        ? const <db.MealAdjustmentPricingRuleCondition>[]
        : await (_database.select(_database.mealAdjustmentPricingRuleConditions)
                ..where(
                  (db.$MealAdjustmentPricingRuleConditionsTable t) =>
                      t.ruleId.isIn(ruleIds),
                )
                ..orderBy(<
                  OrderingTerm Function(
                    db.$MealAdjustmentPricingRuleConditionsTable,
                  )
                >[
                  (db.$MealAdjustmentPricingRuleConditionsTable t) =>
                      OrderingTerm.asc(t.id),
                ]))
              .get();

    final Map<int, List<MealAdjustmentComponentOption>> optionsByComponentId =
        <int, List<MealAdjustmentComponentOption>>{};
    final Map<int, List<MealAdjustmentComponentOptionDraft>>
    optionDraftsByComponentId =
        <int, List<MealAdjustmentComponentOptionDraft>>{};
    for (final db.MealAdjustmentComponentOption optionRow in optionRows) {
      final MealAdjustmentComponentOptionType optionType = _mapOptionTypeFromDb(
        optionRow.optionType,
      );
      optionsByComponentId
          .putIfAbsent(
            optionRow.profileComponentId,
            () => <MealAdjustmentComponentOption>[],
          )
          .add(
            MealAdjustmentComponentOption(
              id: optionRow.id,
              profileComponentId: optionRow.profileComponentId,
              optionItemProductId: optionRow.optionItemProductId,
              type: optionType,
              fixedPriceDeltaMinor: optionRow.fixedPriceDeltaMinor,
              sortOrder: optionRow.sortOrder,
              isActive: optionRow.isActive,
            ),
          );
      optionDraftsByComponentId
          .putIfAbsent(
            optionRow.profileComponentId,
            () => <MealAdjustmentComponentOptionDraft>[],
          )
          .add(
            MealAdjustmentComponentOptionDraft(
              id: optionRow.id,
              optionItemProductId: optionRow.optionItemProductId,
              type: optionType,
              fixedPriceDeltaMinor: optionRow.fixedPriceDeltaMinor,
              sortOrder: optionRow.sortOrder,
              isActive: optionRow.isActive,
            ),
          );
    }

    final Map<int, List<MealAdjustmentPricingRuleCondition>>
    conditionsByRuleId = <int, List<MealAdjustmentPricingRuleCondition>>{};
    final Map<int, List<MealAdjustmentPricingRuleConditionDraft>>
    conditionDraftsByRuleId =
        <int, List<MealAdjustmentPricingRuleConditionDraft>>{};
    for (final db.MealAdjustmentPricingRuleCondition conditionRow
        in conditionRows) {
      final MealAdjustmentPricingRuleConditionType conditionType =
          _mapConditionTypeFromDb(conditionRow.conditionType);
      conditionsByRuleId
          .putIfAbsent(
            conditionRow.ruleId,
            () => <MealAdjustmentPricingRuleCondition>[],
          )
          .add(
            MealAdjustmentPricingRuleCondition(
              id: conditionRow.id,
              ruleId: conditionRow.ruleId,
              conditionType: conditionType,
              componentKey: conditionRow.componentKey,
              itemProductId: conditionRow.itemProductId,
              quantity: conditionRow.quantity,
            ),
          );
      conditionDraftsByRuleId
          .putIfAbsent(
            conditionRow.ruleId,
            () => <MealAdjustmentPricingRuleConditionDraft>[],
          )
          .add(
            MealAdjustmentPricingRuleConditionDraft(
              id: conditionRow.id,
              conditionType: conditionType,
              componentKey: conditionRow.componentKey,
              itemProductId: conditionRow.itemProductId,
              quantity: conditionRow.quantity,
            ),
          );
    }

    return _ProfileGraph(
      profile: profileRow,
      components: componentRows,
      extras: extraRows,
      rules: ruleRows,
      optionsByComponentId: optionsByComponentId,
      optionDraftsByComponentId: optionDraftsByComponentId,
      conditionsByRuleId: conditionsByRuleId,
      conditionDraftsByRuleId: conditionDraftsByRuleId,
    );
  }
}

class _ProfileGraph {
  const _ProfileGraph({
    required this.profile,
    required this.components,
    required this.extras,
    required this.rules,
    required this.optionsByComponentId,
    required this.optionDraftsByComponentId,
    required this.conditionsByRuleId,
    required this.conditionDraftsByRuleId,
  });

  final db.MealAdjustmentProfile profile;
  final List<db.MealAdjustmentProfileComponent> components;
  final List<db.MealAdjustmentProfileExtra> extras;
  final List<db.MealAdjustmentPricingRule> rules;
  final Map<int, List<MealAdjustmentComponentOption>> optionsByComponentId;
  final Map<int, List<MealAdjustmentComponentOptionDraft>>
  optionDraftsByComponentId;
  final Map<int, List<MealAdjustmentPricingRuleCondition>> conditionsByRuleId;
  final Map<int, List<MealAdjustmentPricingRuleConditionDraft>>
  conditionDraftsByRuleId;
}
