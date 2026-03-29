class Category {
  const Category({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String name;
  final String? imageUrl;
  final int sortOrder;
  final bool isActive;

  Category copyWith({
    int? id,
    String? name,
    Object? imageUrl = _unset,
    int? sortOrder,
    bool? isActive,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl == _unset ? this.imageUrl : imageUrl as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Category &&
        other.id == id &&
        other.name == name &&
        other.imageUrl == imageUrl &&
        other.sortOrder == sortOrder &&
        other.isActive == isActive;
  }

  @override
  int get hashCode => Object.hash(id, name, imageUrl, sortOrder, isActive);
}

const Object _unset = Object();
