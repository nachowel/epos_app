import 'package:drift/drift.dart';

import '../../domain/models/category.dart';
import '../database/app_database.dart' as db;

class CategoryRepository {
  const CategoryRepository(this._database);

  final db.AppDatabase _database;

  Future<List<Category>> getAll({bool activeOnly = true}) async {
    final query = _database.select(_database.categories)
      ..orderBy(<OrderingTerm Function(db.$CategoriesTable)>[
        (db.$CategoriesTable t) => OrderingTerm.asc(t.sortOrder),
        (db.$CategoriesTable t) => OrderingTerm.asc(t.id),
      ]);

    if (activeOnly) {
      query.where((db.$CategoriesTable t) => t.isActive.equals(true));
    }

    final List<db.Category> rows = await query.get();
    return rows.map(_mapCategory).toList(growable: false);
  }

  Future<List<Category>> getActiveCatalogCategories() async {
    final JoinedSelectStatement<HasResultSet, dynamic> visibleProductsQuery =
        _database.selectOnly(_database.products)
          ..addColumns(<Expression<Object>>[_database.products.categoryId])
          ..where(
            _database.products.isActive.equals(true) &
                _database.products.isVisibleOnPos.equals(true),
          );

    final query = _database.select(_database.categories)
      ..where(
        (db.$CategoriesTable t) =>
            t.isActive.equals(true) & t.id.isInQuery(visibleProductsQuery),
      )
      ..orderBy(<OrderingTerm Function(db.$CategoriesTable)>[
        (db.$CategoriesTable t) => OrderingTerm.asc(t.sortOrder),
        (db.$CategoriesTable t) => OrderingTerm.asc(t.id),
      ]);

    final List<db.Category> rows = await query.get();
    return rows.map(_mapCategory).toList(growable: false);
  }

  Future<Category?> getById(int id) async {
    final db.Category? row = await (_database.select(
      _database.categories,
    )..where((db.$CategoriesTable t) => t.id.equals(id))).getSingleOrNull();

    return row == null ? null : _mapCategory(row);
  }

  Future<int> insert({
    required String name,
    String? imageUrl,
    int sortOrder = 0,
    bool isActive = true,
  }) {
    return _database
        .into(_database.categories)
        .insert(
          db.CategoriesCompanion.insert(
            name: name,
            imageUrl: Value<String?>(imageUrl),
            sortOrder: Value<int>(sortOrder),
            isActive: Value<bool>(isActive),
          ),
        );
  }

  Future<bool> nameExistsIgnoreCase(
    String name, {
    int? excludeCategoryId,
  }) async {
    final String normalizedName = name.trim().toLowerCase();
    final List<db.Category> rows = await _database
        .select(_database.categories)
        .get();
    for (final db.Category row in rows) {
      if (excludeCategoryId != null && row.id == excludeCategoryId) {
        continue;
      }
      if (row.name.trim().toLowerCase() == normalizedName) {
        return true;
      }
    }
    return false;
  }

  Future<Category?> findByNameIgnoreCase(
    String name, {
    int? excludeCategoryId,
  }) async {
    final String normalizedName = name.trim().toLowerCase();
    final List<db.Category> rows = await _database
        .select(_database.categories)
        .get();
    for (final db.Category row in rows) {
      if (excludeCategoryId != null && row.id == excludeCategoryId) {
        continue;
      }
      if (row.name.trim().toLowerCase() == normalizedName) {
        return _mapCategory(row);
      }
    }
    return null;
  }

  Future<bool> updateCategory({
    required int id,
    String? name,
    Object? imageUrl = _unset,
    int? sortOrder,
    bool? isActive,
  }) async {
    final int updatedCount =
        await (_database.update(
          _database.categories,
        )..where((db.$CategoriesTable t) => t.id.equals(id))).write(
          db.CategoriesCompanion(
            name: name == null
                ? const Value<String>.absent()
                : Value<String>(name),
            imageUrl: imageUrl == _unset
                ? const Value<String?>.absent()
                : Value<String?>(imageUrl as String?),
            sortOrder: sortOrder == null
                ? const Value<int>.absent()
                : Value<int>(sortOrder),
            isActive: isActive == null
                ? const Value<bool>.absent()
                : Value<bool>(isActive),
          ),
        );

    return updatedCount > 0;
  }

  Future<void> reorder(List<int> orderedIds) async {
    await _database.transaction(() async {
      for (int index = 0; index < orderedIds.length; index++) {
        final int id = orderedIds[index];
        await (_database.update(_database.categories)
              ..where((db.$CategoriesTable t) => t.id.equals(id)))
            .write(db.CategoriesCompanion(sortOrder: Value<int>(index)));
      }
    });
  }

  Future<bool> toggleActive(int id, bool isActive) async {
    final int updatedCount =
        await (_database.update(_database.categories)
              ..where((db.$CategoriesTable t) => t.id.equals(id)))
            .write(db.CategoriesCompanion(isActive: Value<bool>(isActive)));

    return updatedCount > 0;
  }

  Future<bool> hasProducts(int id) async {
    final int count =
        await (_database.selectOnly(_database.products)
              ..addColumns(<Expression<Object>>[_database.products.id.count()])
              ..where(_database.products.categoryId.equals(id)))
            .map(
              (TypedResult row) => row.read(_database.products.id.count()) ?? 0,
            )
            .getSingle();
    return count > 0;
  }

  Future<bool> hasActiveProducts(int id) async {
    final int count =
        await (_database.selectOnly(_database.products)
              ..addColumns(<Expression<Object>>[_database.products.id.count()])
              ..where(
                _database.products.categoryId.equals(id) &
                    _database.products.isActive.equals(true),
              ))
            .map(
              (TypedResult row) => row.read(_database.products.id.count()) ?? 0,
            )
            .getSingle();
    return count > 0;
  }

  Future<bool> deleteCategory(int id) async {
    final int deletedCount = await (_database.delete(
      _database.categories,
    )..where((db.$CategoriesTable t) => t.id.equals(id))).go();
    return deletedCount > 0;
  }

  Category _mapCategory(db.Category row) {
    return Category(
      id: row.id,
      name: row.name,
      imageUrl: row.imageUrl,
      sortOrder: row.sortOrder,
      isActive: row.isActive,
    );
  }
}

const Object _unset = Object();
