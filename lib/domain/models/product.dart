class Product {
  const Product({
    required this.id,
    required this.categoryId,
    this.mealAdjustmentProfileId,
    required this.name,
    required this.priceMinor,
    required this.imageUrl,
    required this.hasModifiers,
    required this.isActive,
    this.isVisibleOnPos = true,
    this.isCustom = false,
    required this.sortOrder,
  });

  final int id;
  final int categoryId;
  final int? mealAdjustmentProfileId;
  final String name;
  final int priceMinor;
  final String? imageUrl;
  final bool hasModifiers;
  final bool isActive;
  final bool isVisibleOnPos;
  final bool isCustom;
  final int sortOrder;

  Product copyWith({
    int? id,
    int? categoryId,
    Object? mealAdjustmentProfileId = _unset,
    String? name,
    int? priceMinor,
    Object? imageUrl = _unset,
    bool? hasModifiers,
    bool? isActive,
    bool? isVisibleOnPos,
    bool? isCustom,
    int? sortOrder,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      mealAdjustmentProfileId: mealAdjustmentProfileId == _unset
          ? this.mealAdjustmentProfileId
          : mealAdjustmentProfileId as int?,
      name: name ?? this.name,
      priceMinor: priceMinor ?? this.priceMinor,
      imageUrl: imageUrl == _unset ? this.imageUrl : imageUrl as String?,
      hasModifiers: hasModifiers ?? this.hasModifiers,
      isActive: isActive ?? this.isActive,
      isVisibleOnPos: isVisibleOnPos ?? this.isVisibleOnPos,
      isCustom: isCustom ?? this.isCustom,
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
        other.mealAdjustmentProfileId == mealAdjustmentProfileId &&
        other.name == name &&
        other.priceMinor == priceMinor &&
        other.imageUrl == imageUrl &&
        other.hasModifiers == hasModifiers &&
        other.isActive == isActive &&
        other.isVisibleOnPos == isVisibleOnPos &&
        other.isCustom == isCustom &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hash(
    id,
    categoryId,
    mealAdjustmentProfileId,
    name,
    priceMinor,
    imageUrl,
    hasModifiers,
    isActive,
    isVisibleOnPos,
    isCustom,
    sortOrder,
  );
}

const Object _unset = Object();
