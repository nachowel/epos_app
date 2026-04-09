import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/product.dart';
import '../../domain/models/product_modifier.dart';
import '../database/app_database.dart' as db;

class BulkModifierInsertResult {
  const BulkModifierInsertResult({
    required this.createdCount,
    required this.skippedCount,
  });

  final int createdCount;
  final int skippedCount;
}

class ModifierRepository {
  const ModifierRepository(this._database);

  final db.AppDatabase _database;

  Future<List<ProductModifier>> getByProductId(
    int productId, {
    bool activeOnly = true,
  }) async {
    final query = _database.select(_database.productModifiers)
      ..where((db.$ProductModifiersTable t) => t.productId.equals(productId))
      ..orderBy(<OrderingTerm Function(db.$ProductModifiersTable)>[
        (db.$ProductModifiersTable t) => OrderingTerm.asc(t.id),
      ]);

    if (activeOnly) {
      query.where((db.$ProductModifiersTable t) => t.isActive.equals(true));
    }

    final List<db.ProductModifier> rows = await query.get();
    return rows.map(_mapModifier).toList(growable: false);
  }

  Future<int> insert({
    required int productId,
    required String name,
    required ModifierType type,
    int extraPriceMinor = 0,
    bool isActive = true,
    int? groupId,
    int? itemProductId,
    ModifierPriceBehavior? priceBehavior,
    ModifierUiSection? uiSection,
  }) {
    _validateGenericModifierWrite(
      type,
      priceBehavior: priceBehavior,
      uiSection: uiSection,
    );
    return _database
        .into(_database.productModifiers)
        .insert(
          db.ProductModifiersCompanion.insert(
            productId: productId,
            groupId: Value<int?>(groupId),
            itemProductId: Value<int?>(itemProductId),
            name: name,
            type: _typeToDb(type),
            extraPriceMinor: Value<int>(
              type == ModifierType.extra ? extraPriceMinor : 0,
            ),
            priceBehavior: Value<String?>(_priceBehaviorToDb(priceBehavior)),
            uiSection: Value<String?>(_uiSectionToDb(uiSection)),
            isActive: Value<bool>(isActive),
          ),
        );
  }

  Future<BulkModifierInsertResult> insertBulkLinkedProducts({
    required int productId,
    required Iterable<Product> linkedProducts,
    required ModifierType type,
    required bool isActive,
    ModifierPriceBehavior? priceBehavior,
    ModifierUiSection? uiSection,
  }) async {
    _validateGenericModifierWrite(
      type,
      priceBehavior: priceBehavior,
      uiSection: uiSection,
    );

    final List<Product> requestedProducts = linkedProducts
        .where((Product product) => product.isActive)
        .toList(growable: false);
    if (requestedProducts.isEmpty) {
      return const BulkModifierInsertResult(createdCount: 0, skippedCount: 0);
    }

    return _database.transaction(() async {
      final Set<int> existingLinkedProductIds =
          await _loadLinkedProductIdsForParent(productId);
      final Set<int> seenProductIds = <int>{};
      final List<db.ProductModifiersCompanion> companions =
          <db.ProductModifiersCompanion>[];
      int skippedCount = 0;

      for (final Product linkedProduct in requestedProducts) {
        if (!seenProductIds.add(linkedProduct.id)) {
          continue;
        }
        if (existingLinkedProductIds.contains(linkedProduct.id)) {
          skippedCount += 1;
          continue;
        }
        companions.add(
          db.ProductModifiersCompanion.insert(
            productId: productId,
            itemProductId: Value<int?>(linkedProduct.id),
            name: linkedProduct.name,
            type: _typeToDb(type),
            extraPriceMinor: Value<int>(
              type == ModifierType.extra &&
                      priceBehavior != ModifierPriceBehavior.free
                  ? linkedProduct.priceMinor
                  : 0,
            ),
            priceBehavior: Value<String?>(_priceBehaviorToDb(priceBehavior)),
            uiSection: Value<String?>(_uiSectionToDb(uiSection)),
            isActive: Value<bool>(isActive),
          ),
        );
      }

      if (companions.isNotEmpty) {
        await _database.batch((Batch batch) {
          batch.insertAll(
            _database.productModifiers,
            companions,
            mode: InsertMode.insertOrIgnore,
          );
        });
      }

      return BulkModifierInsertResult(
        createdCount: companions.length,
        skippedCount: skippedCount,
      );
    });
  }

  Future<bool> updateModifier({
    required int id,
    int? productId,
    String? name,
    ModifierType? type,
    int? extraPriceMinor,
    bool? isActive,
    Object? itemProductId = _unsetModifierField,
    Object? priceBehavior = _unsetModifierField,
    Object? uiSection = _unsetModifierField,
  }) async {
    if (type == ModifierType.choice ||
        !identical(priceBehavior, _unsetModifierField) ||
        !identical(uiSection, _unsetModifierField)) {
      _validateGenericModifierWrite(
        type ?? await _loadModifierType(id),
        priceBehavior: identical(priceBehavior, _unsetModifierField)
            ? null
            : priceBehavior as ModifierPriceBehavior?,
        uiSection: identical(uiSection, _unsetModifierField)
            ? null
            : uiSection as ModifierUiSection?,
      );
    }
    final int updatedCount =
        await (_database.update(
          _database.productModifiers,
        )..where((db.$ProductModifiersTable t) => t.id.equals(id))).write(
          db.ProductModifiersCompanion(
            productId: productId == null
                ? const Value<int>.absent()
                : Value<int>(productId),
            name: name == null
                ? const Value<String>.absent()
                : Value<String>(name),
            type: type == null
                ? const Value<String>.absent()
                : Value<String>(_typeToDb(type)),
            extraPriceMinor: extraPriceMinor == null
                ? const Value<int>.absent()
                : Value<int>(extraPriceMinor),
            itemProductId: identical(itemProductId, _unsetModifierField)
                ? const Value<int?>.absent()
                : Value<int?>(itemProductId as int?),
            priceBehavior: identical(priceBehavior, _unsetModifierField)
                ? const Value<String?>.absent()
                : Value<String?>(
                    _priceBehaviorToDb(priceBehavior as ModifierPriceBehavior?),
                  ),
            uiSection: identical(uiSection, _unsetModifierField)
                ? const Value<String?>.absent()
                : Value<String?>(
                    _uiSectionToDb(uiSection as ModifierUiSection?),
                  ),
            isActive: isActive == null
                ? const Value<bool>.absent()
                : Value<bool>(isActive),
          ),
        );

    return updatedCount > 0;
  }

  void _validateGenericModifierWrite(
    ModifierType type, {
    ModifierPriceBehavior? priceBehavior,
    ModifierUiSection? uiSection,
  }) {
    if (type == ModifierType.choice) {
      throw ValidationException(
        'Grouped choice modifiers must be managed through breakfast set configuration.',
      );
    }
    if ((priceBehavior == null) != (uiSection == null)) {
      throw ValidationException(
        'Structured flat modifiers must provide both price behavior and UI section together.',
      );
    }
    if ((priceBehavior != null || uiSection != null) &&
        type != ModifierType.extra) {
      throw ValidationException(
        'Structured flat modifiers are supported only on additive extra rows.',
      );
    }
  }

  Future<bool> toggleActive(int id, bool isActive) async {
    final int updatedCount =
        await (_database.update(
          _database.productModifiers,
        )..where((db.$ProductModifiersTable t) => t.id.equals(id))).write(
          db.ProductModifiersCompanion(isActive: Value<bool>(isActive)),
        );

    return updatedCount > 0;
  }

  Future<bool> deleteModifier(int id) async {
    final int deletedCount = await (_database.delete(
      _database.productModifiers,
    )..where((db.$ProductModifiersTable t) => t.id.equals(id))).go();
    return deletedCount > 0;
  }

  ProductModifier _mapModifier(db.ProductModifier row) {
    return ProductModifier(
      id: row.id,
      productId: row.productId,
      groupId: row.groupId,
      itemProductId: row.itemProductId,
      name: row.name,
      type: _typeFromDb(row.type),
      extraPriceMinor: row.extraPriceMinor,
      isActive: row.isActive,
      priceBehavior: _priceBehaviorFromDb(row.priceBehavior),
      uiSection: _uiSectionFromDb(row.uiSection),
    );
  }

  Future<Set<int>> _loadLinkedProductIdsForParent(int productId) async {
    final List<db.ProductModifier> existingRows =
        await (_database.select(_database.productModifiers)..where(
              (db.$ProductModifiersTable t) => t.productId.equals(productId),
            ))
            .get();
    return existingRows
        .map((db.ProductModifier row) => row.itemProductId)
        .whereType<int>()
        .toSet();
  }

  Future<ModifierType> _loadModifierType(int id) async {
    final db.ProductModifier? row =
        await (_database.select(_database.productModifiers)
              ..where((db.$ProductModifiersTable t) => t.id.equals(id)))
            .getSingleOrNull();
    if (row == null) {
      throw NotFoundException('Modifier not found: $id');
    }
    return _typeFromDb(row.type);
  }

  ModifierType _typeFromDb(String value) {
    switch (value) {
      case 'included':
        return ModifierType.included;
      case 'extra':
        return ModifierType.extra;
      case 'choice':
        return ModifierType.choice;
      default:
        throw DatabaseException('Unknown modifier type: $value');
    }
  }

  String _typeToDb(ModifierType type) {
    switch (type) {
      case ModifierType.included:
        return 'included';
      case ModifierType.extra:
        return 'extra';
      case ModifierType.choice:
        return 'choice';
    }
  }

  ModifierPriceBehavior? _priceBehaviorFromDb(String? value) {
    switch (value) {
      case null:
        return null;
      case 'free':
        return ModifierPriceBehavior.free;
      case 'paid':
        return ModifierPriceBehavior.paid;
      default:
        throw DatabaseException('Unknown modifier price behavior: $value');
    }
  }

  String? _priceBehaviorToDb(ModifierPriceBehavior? value) {
    switch (value) {
      case null:
        return null;
      case ModifierPriceBehavior.free:
        return 'free';
      case ModifierPriceBehavior.paid:
        return 'paid';
    }
  }

  ModifierUiSection? _uiSectionFromDb(String? value) {
    switch (value) {
      case null:
        return null;
      case 'toppings':
        return ModifierUiSection.toppings;
      case 'sauces':
        return ModifierUiSection.sauces;
      case 'add_ins':
        return ModifierUiSection.addIns;
      default:
        throw DatabaseException('Unknown modifier UI section: $value');
    }
  }

  String? _uiSectionToDb(ModifierUiSection? value) {
    switch (value) {
      case null:
        return null;
      case ModifierUiSection.toppings:
        return 'toppings';
      case ModifierUiSection.sauces:
        return 'sauces';
      case ModifierUiSection.addIns:
        return 'add_ins';
    }
  }
}

const Object _unsetModifierField = Object();
