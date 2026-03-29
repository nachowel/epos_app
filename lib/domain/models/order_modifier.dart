enum ModifierAction { remove, add }

class OrderModifier {
  const OrderModifier({
    required this.id,
    required this.uuid,
    required this.transactionLineId,
    required this.action,
    required this.itemName,
    required this.extraPriceMinor,
  });

  final int id;
  final String uuid;
  final int transactionLineId;
  final ModifierAction action;
  final String itemName;
  final int extraPriceMinor;

  OrderModifier copyWith({
    int? id,
    String? uuid,
    int? transactionLineId,
    ModifierAction? action,
    String? itemName,
    int? extraPriceMinor,
  }) {
    return OrderModifier(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionLineId: transactionLineId ?? this.transactionLineId,
      action: action ?? this.action,
      itemName: itemName ?? this.itemName,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OrderModifier &&
        other.id == id &&
        other.uuid == uuid &&
        other.transactionLineId == transactionLineId &&
        other.action == action &&
        other.itemName == itemName &&
        other.extraPriceMinor == extraPriceMinor;
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    transactionLineId,
    action,
    itemName,
    extraPriceMinor,
  );
}
