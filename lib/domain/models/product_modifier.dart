enum ModifierType { included, extra, choice }

class ProductModifier {
  const ProductModifier({
    required this.id,
    required this.productId,
    required this.name,
    required this.type,
    required this.extraPriceMinor,
    required this.isActive,
    this.groupId,
    this.itemProductId,
  });

  static const List<ModifierType> legacyFlatTypes = <ModifierType>[
    ModifierType.included,
    ModifierType.extra,
  ];

  final int id;
  final int productId;
  final String name;
  final ModifierType type;
  final int extraPriceMinor;
  final bool isActive;
  final int? groupId;
  final int? itemProductId;

  bool get isChoice => type == ModifierType.choice;
  bool get isLegacyFlat => legacyFlatTypes.contains(type);

  ProductModifier copyWith({
    int? id,
    int? productId,
    String? name,
    ModifierType? type,
    int? extraPriceMinor,
    bool? isActive,
    Object? groupId = _unsetNullableField,
    Object? itemProductId = _unsetNullableField,
  }) {
    return ProductModifier(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      type: type ?? this.type,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
      isActive: isActive ?? this.isActive,
      groupId: identical(groupId, _unsetNullableField)
          ? this.groupId
          : groupId as int?,
      itemProductId: identical(itemProductId, _unsetNullableField)
          ? this.itemProductId
          : itemProductId as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ProductModifier &&
        other.id == id &&
        other.productId == productId &&
        other.name == name &&
        other.type == type &&
        other.extraPriceMinor == extraPriceMinor &&
        other.isActive == isActive &&
        other.groupId == groupId &&
        other.itemProductId == itemProductId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    name,
    type,
    extraPriceMinor,
    isActive,
    groupId,
    itemProductId,
  );
}

const Object _unsetNullableField = Object();
