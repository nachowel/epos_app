import 'package:drift/drift.dart';

import '../../domain/models/sandwich.dart';
import '../../domain/models/product.dart';
import '../database/app_database.dart' as db;

class MealAdjustmentProductReferenceSummary {
  const MealAdjustmentProductReferenceSummary({
    required this.componentDefaultCount,
    required this.swapOptionCount,
    required this.extraOptionCount,
    required this.pricingRuleItemCount,
    required this.affectedProfileCount,
  });

  final int componentDefaultCount;
  final int swapOptionCount;
  final int extraOptionCount;
  final int pricingRuleItemCount;
  final int affectedProfileCount;

  bool get hasReferences =>
      componentDefaultCount > 0 ||
      swapOptionCount > 0 ||
      extraOptionCount > 0 ||
      pricingRuleItemCount > 0;
}

class ProductRepository {
  const ProductRepository(this._database);

  final db.AppDatabase _database;

  Future<List<Product>> getAll({
    bool activeOnly = true,
    bool visibleOnPosOnly = false,
  }) async {
    final query = _database.select(_database.products)
      ..orderBy(<OrderingTerm Function(db.$ProductsTable)>[
        (db.$ProductsTable t) => OrderingTerm.asc(t.sortOrder),
        (db.$ProductsTable t) => OrderingTerm.asc(t.id),
      ]);

    if (activeOnly) {
      query.where((db.$ProductsTable t) => t.isActive.equals(true));
    }
    if (visibleOnPosOnly) {
      query.where((db.$ProductsTable t) => t.isVisibleOnPos.equals(true));
    }

    final List<db.Product> rows = await query.get();
    return rows.map(_mapProduct).toList(growable: false);
  }

  Future<List<Product>> getByCategory(
    int categoryId, {
    bool activeOnly = true,
    bool visibleOnPosOnly = false,
  }) async {
    final query = _database.select(_database.products)
      ..where((db.$ProductsTable t) => t.categoryId.equals(categoryId))
      ..orderBy(<OrderingTerm Function(db.$ProductsTable)>[
        (db.$ProductsTable t) => OrderingTerm.asc(t.sortOrder),
        (db.$ProductsTable t) => OrderingTerm.asc(t.id),
      ]);

    if (activeOnly) {
      query.where((db.$ProductsTable t) => t.isActive.equals(true));
    }
    if (visibleOnPosOnly) {
      query.where((db.$ProductsTable t) => t.isVisibleOnPos.equals(true));
    }

    final List<db.Product> rows = await query.get();
    return rows.map(_mapProduct).toList(growable: false);
  }

  Future<List<Product>> getActiveCatalogProducts({int? categoryId}) async {
    final JoinedSelectStatement<HasResultSet, dynamic> activeCategoriesQuery =
        _database.selectOnly(_database.categories)
          ..addColumns(<Expression<Object>>[_database.categories.id])
          ..where(_database.categories.isActive.equals(true));
    final SimpleSelectStatement<db.$ProductsTable, db.Product> query =
        _database.select(_database.products)
          ..where(
            (db.$ProductsTable t) =>
                t.isActive.equals(true) &
                t.isVisibleOnPos.equals(true) &
                t.categoryId.isInQuery(activeCategoriesQuery),
          )
          ..orderBy(<OrderingTerm Function(db.$ProductsTable)>[
            (db.$ProductsTable t) => OrderingTerm.asc(t.sortOrder),
            (db.$ProductsTable t) => OrderingTerm.asc(t.id),
          ]);

    if (categoryId != null) {
      query.where((db.$ProductsTable t) => t.categoryId.equals(categoryId));
    }

    final List<db.Product> rows = await query.get();
    return rows.map(_mapProduct).toList(growable: false);
  }

  Future<List<Product>> getSandwichSauceProducts({
    bool activeOnly = true,
  }) async {
    final StringBuffer sql = StringBuffer('''
      SELECT
        p.id,
        p.category_id,
        p.meal_adjustment_profile_id,
        p.name,
        p.price_minor,
        p.image_url,
        p.has_modifiers,
        p.is_active,
        p.is_visible_on_pos,
        p.sort_order
      FROM products p
      INNER JOIN categories c ON c.id = p.category_id
      WHERE lower(trim(c.name)) = lower(trim(?))
    ''');
    if (activeOnly) {
      sql.write(' AND p.is_active = 1');
    }
    sql.write(' ORDER BY p.sort_order ASC, p.id ASC');

    final List<QueryRow> rows = await _database
        .customSelect(
          sql.toString(),
          variables: <Variable<Object>>[Variable<String>(kSaucesCategoryName)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.products,
            _database.categories,
          },
        )
        .get();
    return rows
        .map(
          (QueryRow row) => Product(
            id: row.read<int>('id'),
            categoryId: row.read<int>('category_id'),
            mealAdjustmentProfileId: row.readNullable<int>(
              'meal_adjustment_profile_id',
            ),
            name: row.read<String>('name'),
            priceMinor: row.read<int>('price_minor'),
            imageUrl: row.readNullable<String>('image_url'),
            hasModifiers: row.read<int>('has_modifiers') == 1,
            isActive: row.read<int>('is_active') == 1,
            isVisibleOnPos: row.read<int>('is_visible_on_pos') == 1,
            sortOrder: row.read<int>('sort_order'),
          ),
        )
        .toList(growable: false);
  }

  Future<Product?> getById(int id) async {
    final db.Product? row = await (_database.select(
      _database.products,
    )..where((db.$ProductsTable t) => t.id.equals(id))).getSingleOrNull();

    return row == null ? null : _mapProduct(row);
  }

  Future<int> insert({
    required int categoryId,
    required String name,
    required int priceMinor,
    String? imageUrl,
    bool hasModifiers = false,
    bool isActive = true,
    bool isVisibleOnPos = true,
    int sortOrder = 0,
  }) {
    return _database
        .into(_database.products)
        .insert(
          db.ProductsCompanion.insert(
            categoryId: categoryId,
            name: name,
            priceMinor: priceMinor,
            imageUrl: Value<String?>(imageUrl),
            hasModifiers: Value<bool>(hasModifiers),
            isActive: Value<bool>(isActive),
            isVisibleOnPos: Value<bool>(isVisibleOnPos),
            sortOrder: Value<int>(sortOrder),
          ),
        );
  }

  Future<bool> updateProduct({
    required int id,
    int? categoryId,
    String? name,
    int? priceMinor,
    String? imageUrl,
    bool? hasModifiers,
    bool? isActive,
    bool? isVisibleOnPos,
    int? sortOrder,
  }) async {
    final int updatedCount =
        await (_database.update(
          _database.products,
        )..where((db.$ProductsTable t) => t.id.equals(id))).write(
          db.ProductsCompanion(
            categoryId: categoryId == null
                ? const Value<int>.absent()
                : Value<int>(categoryId),
            name: name == null
                ? const Value<String>.absent()
                : Value<String>(name),
            priceMinor: priceMinor == null
                ? const Value<int>.absent()
                : Value<int>(priceMinor),
            imageUrl: imageUrl == null
                ? const Value<String?>.absent()
                : Value<String?>(imageUrl),
            hasModifiers: hasModifiers == null
                ? const Value<bool>.absent()
                : Value<bool>(hasModifiers),
            isActive: isActive == null
                ? const Value<bool>.absent()
                : Value<bool>(isActive),
            isVisibleOnPos: isVisibleOnPos == null
                ? const Value<bool>.absent()
                : Value<bool>(isVisibleOnPos),
            sortOrder: sortOrder == null
                ? const Value<int>.absent()
                : Value<int>(sortOrder),
          ),
        );

    return updatedCount > 0;
  }

  Future<bool> toggleActive(int id, bool isActive) async {
    final int updatedCount =
        await (_database.update(_database.products)
              ..where((db.$ProductsTable t) => t.id.equals(id)))
            .write(db.ProductsCompanion(isActive: Value<bool>(isActive)));

    return updatedCount > 0;
  }

  Future<bool> toggleVisibilityOnPos(int id, bool isVisibleOnPos) async {
    final int updatedCount =
        await (_database.update(
          _database.products,
        )..where((db.$ProductsTable t) => t.id.equals(id))).write(
          db.ProductsCompanion(isVisibleOnPos: Value<bool>(isVisibleOnPos)),
        );

    return updatedCount > 0;
  }

  Future<bool> hasHistoricalUsage(int id) async {
    final QueryRow row = await _database
        .customSelect(
          '''
      SELECT CASE
        WHEN EXISTS(
          SELECT 1
          FROM transaction_lines
          WHERE product_id = ?
          LIMIT 1
        ) OR EXISTS(
          SELECT 1
          FROM order_modifiers
          WHERE item_product_id = ?
          LIMIT 1
        )
        THEN 1
        ELSE 0
      END AS has_usage
      ''',
          variables: <Variable<Object>>[Variable<int>(id), Variable<int>(id)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.transactionLines,
            _database.orderModifiers,
          },
        )
        .getSingle();
    return row.read<int>('has_usage') == 1;
  }

  Future<bool> hasOwnedSemanticConfiguration(int id) async {
    final QueryRow row = await _database
        .customSelect(
          '''
      SELECT CASE
        WHEN EXISTS(
          SELECT 1 FROM set_items WHERE product_id = ? LIMIT 1
        ) OR EXISTS(
          SELECT 1 FROM modifier_groups WHERE product_id = ? LIMIT 1
        ) OR EXISTS(
          SELECT 1
          FROM product_modifiers
          WHERE product_id = ?
            AND type = 'choice'
          LIMIT 1
        )
        THEN 1
        ELSE 0
      END AS has_semantic_config
      ''',
          variables: <Variable<Object>>[
            Variable<int>(id),
            Variable<int>(id),
            Variable<int>(id),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.setItems,
            _database.modifierGroups,
            _database.productModifiers,
          },
        )
        .getSingle();
    return row.read<int>('has_semantic_config') == 1;
  }

  Future<({int setConfigCount, int requiredChoiceCount, int extrasPoolCount})>
  loadSemanticReferenceSummary(int id) async {
    final QueryRow row = await _database
        .customSelect(
          '''
      SELECT
        (SELECT COUNT(DISTINCT product_id)
         FROM set_items
         WHERE item_product_id = ?) AS set_config_count,
        (SELECT COUNT(*)
         FROM product_modifiers
         WHERE type = 'choice'
           AND item_product_id = ?) AS required_choice_count,
        (SELECT COUNT(*)
         FROM product_modifiers
         WHERE type = 'extra'
           AND item_product_id = ?) AS extras_pool_count
      ''',
          variables: <Variable<Object>>[
            Variable<int>(id),
            Variable<int>(id),
            Variable<int>(id),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.setItems,
            _database.productModifiers,
          },
        )
        .getSingle();
    return (
      setConfigCount: row.read<int>('set_config_count'),
      requiredChoiceCount: row.read<int>('required_choice_count'),
      extrasPoolCount: row.read<int>('extras_pool_count'),
    );
  }

  Future<MealAdjustmentProductReferenceSummary>
  loadMealAdjustmentReferenceSummary(int id) async {
    final QueryRow row = await _database
        .customSelect(
          '''
      SELECT
        (SELECT COUNT(*)
         FROM meal_adjustment_profile_components component
         INNER JOIN meal_adjustment_profiles profile
           ON profile.id = component.profile_id
         WHERE component.default_item_product_id = ?
           AND component.is_active = 1
           AND profile.is_active = 1) AS component_default_count,
        (SELECT COUNT(*)
         FROM meal_adjustment_component_options option_row
         INNER JOIN meal_adjustment_profile_components component
           ON component.id = option_row.profile_component_id
         INNER JOIN meal_adjustment_profiles profile
           ON profile.id = component.profile_id
         WHERE option_row.option_item_product_id = ?
           AND option_row.is_active = 1
           AND component.is_active = 1
           AND profile.is_active = 1) AS swap_option_count,
        (SELECT COUNT(*)
         FROM meal_adjustment_profile_extras extra_row
         INNER JOIN meal_adjustment_profiles profile
           ON profile.id = extra_row.profile_id
         WHERE extra_row.item_product_id = ?
           AND extra_row.is_active = 1
           AND profile.is_active = 1) AS extra_option_count,
        (SELECT COUNT(*)
         FROM meal_adjustment_pricing_rule_conditions condition_row
         INNER JOIN meal_adjustment_pricing_rules rule_row
           ON rule_row.id = condition_row.rule_id
         INNER JOIN meal_adjustment_profiles profile
           ON profile.id = rule_row.profile_id
         WHERE condition_row.item_product_id = ?
           AND rule_row.is_active = 1
           AND profile.is_active = 1) AS pricing_rule_item_count,
        (SELECT COUNT(DISTINCT profile_id)
         FROM (
           SELECT component.profile_id AS profile_id
           FROM meal_adjustment_profile_components component
           INNER JOIN meal_adjustment_profiles profile
             ON profile.id = component.profile_id
           WHERE component.default_item_product_id = ?
             AND component.is_active = 1
             AND profile.is_active = 1
           UNION
           SELECT component.profile_id AS profile_id
           FROM meal_adjustment_component_options option_row
           INNER JOIN meal_adjustment_profile_components component
             ON component.id = option_row.profile_component_id
           INNER JOIN meal_adjustment_profiles profile
             ON profile.id = component.profile_id
           WHERE option_row.option_item_product_id = ?
             AND option_row.is_active = 1
             AND component.is_active = 1
             AND profile.is_active = 1
           UNION
           SELECT extra_row.profile_id AS profile_id
           FROM meal_adjustment_profile_extras extra_row
           INNER JOIN meal_adjustment_profiles profile
             ON profile.id = extra_row.profile_id
           WHERE extra_row.item_product_id = ?
             AND extra_row.is_active = 1
             AND profile.is_active = 1
           UNION
           SELECT rule_row.profile_id AS profile_id
           FROM meal_adjustment_pricing_rule_conditions condition_row
           INNER JOIN meal_adjustment_pricing_rules rule_row
             ON rule_row.id = condition_row.rule_id
           INNER JOIN meal_adjustment_profiles profile
             ON profile.id = rule_row.profile_id
           WHERE condition_row.item_product_id = ?
             AND rule_row.is_active = 1
             AND profile.is_active = 1
         )) AS affected_profile_count
      ''',
          variables: <Variable<Object>>[
            Variable<int>(id),
            Variable<int>(id),
            Variable<int>(id),
            Variable<int>(id),
            Variable<int>(id),
            Variable<int>(id),
            Variable<int>(id),
            Variable<int>(id),
          ],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _database.mealAdjustmentProfiles,
            _database.mealAdjustmentProfileComponents,
            _database.mealAdjustmentComponentOptions,
            _database.mealAdjustmentProfileExtras,
            _database.mealAdjustmentPricingRules,
            _database.mealAdjustmentPricingRuleConditions,
          },
        )
        .getSingle();
    return MealAdjustmentProductReferenceSummary(
      componentDefaultCount: row.read<int>('component_default_count'),
      swapOptionCount: row.read<int>('swap_option_count'),
      extraOptionCount: row.read<int>('extra_option_count'),
      pricingRuleItemCount: row.read<int>('pricing_rule_item_count'),
      affectedProfileCount: row.read<int>('affected_profile_count'),
    );
  }

  Future<bool> deleteStandardProduct(int id) async {
    return _database.transaction(() async {
      await (_database.delete(_database.productModifiers)
            ..where((db.$ProductModifiersTable t) {
              return t.productId.equals(id) | t.itemProductId.equals(id);
            }))
          .go();
      await (_database.delete(
        _database.modifierGroups,
      )..where((db.$ModifierGroupsTable t) => t.productId.equals(id))).go();
      await (_database.delete(_database.setItems)..where((db.$SetItemsTable t) {
            return t.productId.equals(id) | t.itemProductId.equals(id);
          }))
          .go();

      final int deletedCount = await (_database.delete(
        _database.products,
      )..where((db.$ProductsTable t) => t.id.equals(id))).go();
      return deletedCount > 0;
    });
  }

  Future<bool> deleteSetProduct(int id) async {
    return _database.transaction(() async {
      await (_database.delete(
        _database.productModifiers,
      )..where((db.$ProductModifiersTable t) => t.productId.equals(id))).go();
      await (_database.delete(
        _database.modifierGroups,
      )..where((db.$ModifierGroupsTable t) => t.productId.equals(id))).go();
      await (_database.delete(
        _database.setItems,
      )..where((db.$SetItemsTable t) => t.productId.equals(id))).go();

      final int deletedCount = await (_database.delete(
        _database.products,
      )..where((db.$ProductsTable t) => t.id.equals(id))).go();
      return deletedCount > 0;
    });
  }

  Product _mapProduct(db.Product row) {
    return Product(
      id: row.id,
      categoryId: row.categoryId,
      mealAdjustmentProfileId: row.mealAdjustmentProfileId,
      name: row.name,
      priceMinor: row.priceMinor,
      imageUrl: row.imageUrl,
      hasModifiers: row.hasModifiers,
      isActive: row.isActive,
      isVisibleOnPos: row.isVisibleOnPos,
      sortOrder: row.sortOrder,
    );
  }
}
