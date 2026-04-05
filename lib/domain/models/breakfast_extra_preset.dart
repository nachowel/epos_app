class BreakfastExtraPreset {
  const BreakfastExtraPreset({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final List<BreakfastExtraPresetItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class BreakfastExtraPresetItem {
  const BreakfastExtraPresetItem({
    required this.itemProductId,
    required this.itemName,
    required this.sortOrder,
  });

  final int itemProductId;
  final String itemName;
  final int sortOrder;
}
