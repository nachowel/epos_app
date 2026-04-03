enum ModifierAction { remove, add, choice }

enum ModifierChargeReason {
  includedChoice,
  freeSwap,
  paidSwap,
  extraAdd,
  removalDiscount,
}

class OrderModifier {
  const OrderModifier({
    required this.id,
    required this.uuid,
    required this.transactionLineId,
    required this.action,
    required this.itemName,
    required this.extraPriceMinor,
    this.chargeReason,
    this.itemProductId,
    this.sourceGroupId,
    this.quantity = 1,
    this.unitPriceMinor = 0,
    this.priceEffectMinor = 0,
    this.sortKey = 0,
  });

  final int id;
  final String uuid;
  final int transactionLineId;
  final ModifierAction action;
  final String itemName;
  final int extraPriceMinor;
  final ModifierChargeReason? chargeReason;
  final int? itemProductId;
  final int? sourceGroupId;
  final int quantity;
  final int unitPriceMinor;
  final int priceEffectMinor;
  final int sortKey;

  OrderModifier copyWith({
    int? id,
    String? uuid,
    int? transactionLineId,
    ModifierAction? action,
    String? itemName,
    int? extraPriceMinor,
    ModifierChargeReason? chargeReason,
    Object? itemProductId = _unsetItemProductId,
    Object? sourceGroupId = _unsetSourceGroupId,
    int? quantity,
    int? unitPriceMinor,
    int? priceEffectMinor,
    int? sortKey,
  }) {
    return OrderModifier(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionLineId: transactionLineId ?? this.transactionLineId,
      action: action ?? this.action,
      itemName: itemName ?? this.itemName,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
      chargeReason: chargeReason ?? this.chargeReason,
      itemProductId: identical(itemProductId, _unsetItemProductId)
          ? this.itemProductId
          : itemProductId as int?,
      sourceGroupId: identical(sourceGroupId, _unsetSourceGroupId)
          ? this.sourceGroupId
          : sourceGroupId as int?,
      quantity: quantity ?? this.quantity,
      unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
      priceEffectMinor: priceEffectMinor ?? this.priceEffectMinor,
      sortKey: sortKey ?? this.sortKey,
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
        other.extraPriceMinor == extraPriceMinor &&
        other.chargeReason == chargeReason &&
        other.itemProductId == itemProductId &&
        other.sourceGroupId == sourceGroupId &&
        other.quantity == quantity &&
        other.unitPriceMinor == unitPriceMinor &&
        other.priceEffectMinor == priceEffectMinor &&
        other.sortKey == sortKey;
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    transactionLineId,
    action,
    itemName,
    extraPriceMinor,
    chargeReason,
    itemProductId,
    sourceGroupId,
    quantity,
    unitPriceMinor,
    priceEffectMinor,
    sortKey,
  );
}

const Object _unsetItemProductId = Object();
const Object _unsetSourceGroupId = Object();
