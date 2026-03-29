enum ModifierType { included, extra }

class ProductModifier {
  const ProductModifier({
    required this.id,
    required this.productId,
    required this.name,
    required this.type,
    required this.extraPriceMinor,
    required this.isActive,
  });

  final int id;
  final int productId;
  final String name;
  final ModifierType type;
  final int extraPriceMinor;
  final bool isActive;

  ProductModifier copyWith({
    int? id,
    int? productId,
    String? name,
    ModifierType? type,
    int? extraPriceMinor,
    bool? isActive,
  }) {
    return ProductModifier(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      type: type ?? this.type,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
      isActive: isActive ?? this.isActive,
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
        other.isActive == isActive;
  }

  @override
  int get hashCode =>
      Object.hash(id, productId, name, type, extraPriceMinor, isActive);
}
