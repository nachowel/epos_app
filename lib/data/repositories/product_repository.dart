import 'package:drift/drift.dart';

import '../../domain/models/product.dart';
import '../database/app_database.dart' as db;

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
            AND (
              type = 'choice'
              OR (type = 'extra' AND item_product_id IS NOT NULL)
            )
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
