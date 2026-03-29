class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.priceMinor,
    required this.imageUrl,
    required this.hasModifiers,
    required this.isActive,
    this.isVisibleOnPos = true,
    required this.sortOrder,
  });

  final int id;
  final int categoryId;
  final String name;
  final int priceMinor;
  final String? imageUrl;
  final bool hasModifiers;
  final bool isActive;
  final bool isVisibleOnPos;
  final int sortOrder;

  Product copyWith({
    int? id,
    int? categoryId,
    String? name,
    int? priceMinor,
    Object? imageUrl = _unset,
    bool? hasModifiers,
    bool? isActive,
    bool? isVisibleOnPos,
    int? sortOrder,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      priceMinor: priceMinor ?? this.priceMinor,
      imageUrl: imageUrl == _unset ? this.imageUrl : imageUrl as String?,
      hasModifiers: hasModifiers ?? this.hasModifiers,
      isActive: isActive ?? this.isActive,
      isVisibleOnPos: isVisibleOnPos ?? this.isVisibleOnPos,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Product &&
        other.id == id &&
        other.categoryId == categoryId &&
        other.name == name &&
        other.priceMinor == priceMinor &&
        other.imageUrl == imageUrl &&
        other.hasModifiers == hasModifiers &&
        other.isActive == isActive &&
        other.isVisibleOnPos == isVisibleOnPos &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    name,
    priceMinor,
    imageUrl,
    hasModifiers,
    isActive,
    isVisibleOnPos,
    sortOrder,
  );
}

const Object _unset = Object();
