import 'product_modifier.dart';

enum ModifierAction { remove, add, choice }

enum ModifierChargeReason {
  includedChoice,
  freeSwap,
  paidSwap,
  extraAdd,
  removalDiscount,
  comboDiscount,
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
    this.priceBehavior,
    this.uiSection,
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
  final ModifierPriceBehavior? priceBehavior;
  final ModifierUiSection? uiSection;

  OrderModifier copyWith({
    int? id,
    String? uuid,
    int? transactionLineId,
    ModifierAction? action,
    String? itemName,
    int? extraPriceMinor,
    Object? chargeReason = _unsetChargeReason,
    Object? itemProductId = _unsetItemProductId,
    Object? sourceGroupId = _unsetSourceGroupId,
    int? quantity,
    int? unitPriceMinor,
    int? priceEffectMinor,
    int? sortKey,
    Object? priceBehavior = _unsetPriceBehavior,
    Object? uiSection = _unsetUiSection,
  }) {
    return OrderModifier(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionLineId: transactionLineId ?? this.transactionLineId,
      action: action ?? this.action,
      itemName: itemName ?? this.itemName,
      extraPriceMinor: extraPriceMinor ?? this.extraPriceMinor,
      chargeReason: identical(chargeReason, _unsetChargeReason)
          ? this.chargeReason
          : chargeReason as ModifierChargeReason?,
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
      priceBehavior: identical(priceBehavior, _unsetPriceBehavior)
          ? this.priceBehavior
          : priceBehavior as ModifierPriceBehavior?,
      uiSection: identical(uiSection, _unsetUiSection)
          ? this.uiSection
          : uiSection as ModifierUiSection?,
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
        other.sortKey == sortKey &&
        other.priceBehavior == priceBehavior &&
        other.uiSection == uiSection;
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
    priceBehavior,
    uiSection,
  );
}

const Object _unsetChargeReason = Object();
const Object _unsetItemProductId = Object();
const Object _unsetSourceGroupId = Object();
const Object _unsetPriceBehavior = Object();
const Object _unsetUiSection = Object();
