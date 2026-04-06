import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/product_modifier.dart';
import '../database/app_database.dart' as db;

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
  }) {
    _validateGenericModifierWrite(type);
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
            isActive: Value<bool>(isActive),
          ),
        );
  }

  Future<bool> updateModifier({
    required int id,
    int? productId,
    String? name,
    ModifierType? type,
    int? extraPriceMinor,
    bool? isActive,
  }) async {
    if (type == ModifierType.choice) {
      _validateGenericModifierWrite(type!);
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
            isActive: isActive == null
                ? const Value<bool>.absent()
                : Value<bool>(isActive),
          ),
        );

    return updatedCount > 0;
  }

  void _validateGenericModifierWrite(ModifierType type) {
    if (type == ModifierType.choice) {
      throw ValidationException(
        'Grouped choice modifiers must be managed through breakfast set configuration.',
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
    );
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
}
