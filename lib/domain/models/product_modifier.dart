enum ModifierType { included, extra, choice }

enum ModifierPriceBehavior { free, paid }

enum ModifierUiSection { toppings, sauces, addIns }

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
    this.priceBehavior,
    this.uiSection,
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
  final ModifierPriceBehavior? priceBehavior;
  final ModifierUiSection? uiSection;

  bool get isChoice => type == ModifierType.choice;
  bool get hasStructuredUi => uiSection != null && priceBehavior != null;
  bool get isLegacyFlat => legacyFlatTypes.contains(type) && !hasStructuredUi;
  bool get isFreeOptionalAdd =>
      type == ModifierType.extra &&
      priceBehavior == ModifierPriceBehavior.free &&
      uiSection != null;
  bool get isPaidOptionalAdd =>
      type == ModifierType.extra &&
      priceBehavior == ModifierPriceBehavior.paid &&
      uiSection != null;
  bool get isLegacyIncludedDefault =>
      type == ModifierType.included && !hasStructuredUi;
  bool get isLegacyPaidExtra => type == ModifierType.extra && !hasStructuredUi;

  ProductModifier copyWith({
    int? id,
    int? productId,
    String? name,
    ModifierType? type,
    int? extraPriceMinor,
    bool? isActive,
    Object? groupId = _unsetNullableField,
    Object? itemProductId = _unsetNullableField,
    Object? priceBehavior = _unsetNullableField,
    Object? uiSection = _unsetNullableField,
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
      priceBehavior: identical(priceBehavior, _unsetNullableField)
          ? this.priceBehavior
          : priceBehavior as ModifierPriceBehavior?,
      uiSection: identical(uiSection, _unsetNullableField)
          ? this.uiSection
          : uiSection as ModifierUiSection?,
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
        other.itemProductId == itemProductId &&
        other.priceBehavior == priceBehavior &&
        other.uiSection == uiSection;
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
    priceBehavior,
    uiSection,
  );
}

const Object _unsetNullableField = Object();
