import '../../core/errors/exceptions.dart';
import 'breakfast_cooking_instruction.dart';
import 'order_modifier.dart';
import 'transaction_line.dart';

const String breakfastNoneChoiceDisplayName = 'None';

class BreakfastRebuildInput {
  const BreakfastRebuildInput({
    required this.transactionLine,
    required this.setConfiguration,
    required this.requestedState,
  });

  final BreakfastTransactionLineInput transactionLine;
  final BreakfastSetConfiguration setConfiguration;
  final BreakfastRequestedState requestedState;
}

class BreakfastTransactionLineInput {
  const BreakfastTransactionLineInput({
    required this.lineId,
    required this.lineUuid,
    required this.rootProductId,
    required this.rootProductName,
    required this.baseUnitPriceMinor,
    required this.lineQuantity,
    this.pricingMode = TransactionLinePricingMode.set,
  });

  final int lineId;
  final String lineUuid;
  final int rootProductId;
  final String rootProductName;
  final int baseUnitPriceMinor;
  final int lineQuantity;
  final TransactionLinePricingMode pricingMode;
}

class BreakfastSetConfiguration {
  const BreakfastSetConfiguration({
    required this.setRootProductId,
    required this.setItems,
    required this.choiceGroups,
    required this.extras,
    required this.menuSettings,
    required this.catalogProductsById,
  });

  final int setRootProductId;
  final List<BreakfastSetItemConfig> setItems;
  final List<BreakfastChoiceGroupConfig> choiceGroups;
  final List<BreakfastExtraItemConfig> extras;
  final BreakfastMenuSettings menuSettings;
  final Map<int, BreakfastCatalogProduct> catalogProductsById;

  BreakfastSetConfiguration copyWith({
    int? setRootProductId,
    List<BreakfastSetItemConfig>? setItems,
    List<BreakfastChoiceGroupConfig>? choiceGroups,
    List<BreakfastExtraItemConfig>? extras,
    BreakfastMenuSettings? menuSettings,
    Map<int, BreakfastCatalogProduct>? catalogProductsById,
  }) {
    return BreakfastSetConfiguration(
      setRootProductId: setRootProductId ?? this.setRootProductId,
      setItems: setItems ?? this.setItems,
      choiceGroups: choiceGroups ?? this.choiceGroups,
      extras: extras ?? this.extras,
      menuSettings: menuSettings ?? this.menuSettings,
      catalogProductsById: catalogProductsById ?? this.catalogProductsById,
    );
  }

  Set<int> get extraProductIds =>
      extras.map((BreakfastExtraItemConfig item) => item.itemProductId).toSet();

  Set<int> get swapEligibleProductIds => extraProductIds;

  Set<int> get choiceCapableProductIds => choiceGroups
      .expand(
        (BreakfastChoiceGroupConfig group) => group.members.map(
          (BreakfastChoiceGroupMemberConfig member) => member.itemProductId,
        ),
      )
      .toSet();

  BreakfastChoiceGroupConfig? findGroup(int groupId) {
    for (final BreakfastChoiceGroupConfig group in choiceGroups) {
      if (group.groupId == groupId) {
        return group;
      }
    }
    return null;
  }

  BreakfastCatalogProduct? findCatalogProduct(int productId) {
    return catalogProductsById[productId];
  }

  BreakfastChoiceGroupConfig? findGroupByMemberProductId(int productId) {
    for (final BreakfastChoiceGroupConfig group in choiceGroups) {
      if (group.containsProduct(productId)) {
        return group;
      }
    }
    return null;
  }

  bool isExplicitExtraProduct(int productId) =>
      extraProductIds.contains(productId);
}

class BreakfastCatalogProduct {
  const BreakfastCatalogProduct({
    required this.id,
    required this.name,
    required this.priceMinor,
  });

  final int id;
  final String name;
  final int priceMinor;
}

class BreakfastSetItemConfig {
  const BreakfastSetItemConfig({
    required this.setItemId,
    required this.itemProductId,
    required this.itemName,
    required this.defaultQuantity,
    required this.isRemovable,
    required this.sortOrder,
  });

  final int setItemId;
  final int itemProductId;
  final String itemName;
  final int defaultQuantity;
  final bool isRemovable;
  final int sortOrder;
}

class BreakfastChoiceGroupConfig {
  const BreakfastChoiceGroupConfig({
    required this.groupId,
    required this.groupName,
    required this.minSelect,
    required this.maxSelect,
    required this.includedQuantity,
    required this.sortOrder,
    required this.members,
    this.explicitNoneLabel,
  });

  final int groupId;
  final String groupName;
  final int minSelect;
  final int maxSelect;
  final int includedQuantity;
  final int sortOrder;
  final List<BreakfastChoiceGroupMemberConfig> members;
  final String? explicitNoneLabel;

  bool get allowsExplicitNoneSelection =>
      explicitNoneLabel != null && explicitNoneLabel!.trim().isNotEmpty;

  String get explicitNoneDisplayLabel =>
      explicitNoneLabel?.trim().isNotEmpty == true
      ? explicitNoneLabel!.trim()
      : breakfastNoneChoiceDisplayName;

  bool containsProduct(int productId) {
    for (final BreakfastChoiceGroupMemberConfig member in members) {
      if (member.itemProductId == productId) {
        return true;
      }
    }
    return false;
  }

  BreakfastChoiceGroupMemberConfig? findMember(int productId) {
    for (final BreakfastChoiceGroupMemberConfig member in members) {
      if (member.itemProductId == productId) {
        return member;
      }
    }
    return null;
  }
}

class BreakfastChoiceGroupMemberConfig {
  const BreakfastChoiceGroupMemberConfig({
    required this.productModifierId,
    required this.itemProductId,
    required this.displayName,
  });

  final int productModifierId;
  final int itemProductId;
  final String displayName;
}

class BreakfastExtraItemConfig {
  const BreakfastExtraItemConfig({
    required this.productModifierId,
    required this.itemProductId,
    required this.itemName,
    required this.sortOrder,
  });

  final int productModifierId;
  final int itemProductId;
  final String itemName;
  final int sortOrder;
}

class BreakfastMenuSettings {
  const BreakfastMenuSettings({
    required this.freeSwapLimit,
    required this.maxSwaps,
  });

  final int freeSwapLimit;
  final int maxSwaps;
}

class BreakfastRequestedState {
  const BreakfastRequestedState({
    this.removedSetItems = const <BreakfastRemovedSetItemRequest>[],
    this.addedProducts = const <BreakfastAddedProductRequest>[],
    this.chosenGroups = const <BreakfastChosenGroupRequest>[],
    this.cookingInstructions = const <BreakfastCookingInstructionRequest>[],
  });

  final List<BreakfastRemovedSetItemRequest> removedSetItems;
  final List<BreakfastAddedProductRequest> addedProducts;
  final List<BreakfastChosenGroupRequest> chosenGroups;
  final List<BreakfastCookingInstructionRequest> cookingInstructions;

  BreakfastRequestedState copyWith({
    List<BreakfastRemovedSetItemRequest>? removedSetItems,
    List<BreakfastAddedProductRequest>? addedProducts,
    List<BreakfastChosenGroupRequest>? chosenGroups,
    List<BreakfastCookingInstructionRequest>? cookingInstructions,
  }) {
    return BreakfastRequestedState(
      removedSetItems: removedSetItems ?? this.removedSetItems,
      addedProducts: addedProducts ?? this.addedProducts,
      chosenGroups: chosenGroups ?? this.chosenGroups,
      cookingInstructions: cookingInstructions ?? this.cookingInstructions,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastRequestedState &&
        _listEquals(other.removedSetItems, removedSetItems) &&
        _listEquals(other.addedProducts, addedProducts) &&
        _listEquals(other.chosenGroups, chosenGroups) &&
        _listEquals(other.cookingInstructions, cookingInstructions);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(removedSetItems),
    Object.hashAll(addedProducts),
    Object.hashAll(chosenGroups),
    Object.hashAll(cookingInstructions),
  );
}

class BreakfastRemovedSetItemRequest {
  const BreakfastRemovedSetItemRequest({
    required this.itemProductId,
    required this.quantity,
  });

  final int itemProductId;
  final int quantity;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastRemovedSetItemRequest &&
        other.itemProductId == itemProductId &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(itemProductId, quantity);
}

class BreakfastAddedProductRequest {
  const BreakfastAddedProductRequest({
    required this.itemProductId,
    required this.quantity,
    this.orderHint = 0,
  });

  final int itemProductId;
  final int quantity;
  final int orderHint;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastAddedProductRequest &&
        other.itemProductId == itemProductId &&
        other.quantity == quantity &&
        other.orderHint == orderHint;
  }

  @override
  int get hashCode => Object.hash(itemProductId, quantity, orderHint);
}

class BreakfastChosenGroupRequest {
  const BreakfastChosenGroupRequest({
    required this.groupId,
    required this.selectedItemProductId,
    required this.requestedQuantity,
  });

  final int groupId;
  final int? selectedItemProductId;
  final int requestedQuantity;

  bool get isExplicitNone =>
      selectedItemProductId == null && requestedQuantity > 0;

  bool get hasSelection => requestedQuantity > 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastChosenGroupRequest &&
        other.groupId == groupId &&
        other.selectedItemProductId == selectedItemProductId &&
        other.requestedQuantity == requestedQuantity;
  }

  @override
  int get hashCode =>
      Object.hash(groupId, selectedItemProductId, requestedQuantity);
}

enum BreakfastModifierKind {
  setRemove,
  choiceIncluded,
  extraAdd,
  freeSwap,
  paidSwap,
}

class BreakfastClassifiedModifier {
  const BreakfastClassifiedModifier({
    required this.kind,
    required this.action,
    required this.itemProductId,
    required this.displayName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.priceEffectMinor,
    required this.sortKey,
    this.chargeReason,
    this.sourceGroupId,
    this.sourceSetItemId,
  });

  final BreakfastModifierKind kind;
  final ModifierAction action;
  final ModifierChargeReason? chargeReason;
  final int? itemProductId;
  final String displayName;
  final int quantity;
  final int unitPriceMinor;
  final int priceEffectMinor;
  final int sortKey;
  final int? sourceGroupId;
  final int? sourceSetItemId;

  BreakfastClassifiedModifier copyWith({
    BreakfastModifierKind? kind,
    ModifierAction? action,
    Object? chargeReason = _unsetChargeReason,
    Object? itemProductId = _unsetNullableInt,
    String? displayName,
    int? quantity,
    int? unitPriceMinor,
    int? priceEffectMinor,
    int? sortKey,
    Object? sourceGroupId = _unsetNullableInt,
    Object? sourceSetItemId = _unsetNullableInt,
  }) {
    return BreakfastClassifiedModifier(
      kind: kind ?? this.kind,
      action: action ?? this.action,
      chargeReason: identical(chargeReason, _unsetChargeReason)
          ? this.chargeReason
          : chargeReason as ModifierChargeReason?,
      itemProductId: identical(itemProductId, _unsetNullableInt)
          ? this.itemProductId
          : itemProductId as int?,
      displayName: displayName ?? this.displayName,
      quantity: quantity ?? this.quantity,
      unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
      priceEffectMinor: priceEffectMinor ?? this.priceEffectMinor,
      sortKey: sortKey ?? this.sortKey,
      sourceGroupId: identical(sourceGroupId, _unsetNullableInt)
          ? this.sourceGroupId
          : sourceGroupId as int?,
      sourceSetItemId: identical(sourceSetItemId, _unsetNullableInt)
          ? this.sourceSetItemId
          : sourceSetItemId as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastClassifiedModifier &&
        other.kind == kind &&
        other.action == action &&
        other.chargeReason == chargeReason &&
        other.itemProductId == itemProductId &&
        other.displayName == displayName &&
        other.quantity == quantity &&
        other.unitPriceMinor == unitPriceMinor &&
        other.priceEffectMinor == priceEffectMinor &&
        other.sortKey == sortKey &&
        other.sourceGroupId == sourceGroupId &&
        other.sourceSetItemId == sourceSetItemId;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    action,
    chargeReason,
    itemProductId,
    displayName,
    quantity,
    unitPriceMinor,
    priceEffectMinor,
    sortKey,
    sourceGroupId,
    sourceSetItemId,
  );
}

class BreakfastLineSnapshot {
  const BreakfastLineSnapshot({
    this.pricingMode = TransactionLinePricingMode.set,
    required this.baseUnitPriceMinor,
    required this.removalDiscountTotalMinor,
    required this.modifierTotalMinor,
    required this.lineTotalMinor,
  });

  final TransactionLinePricingMode pricingMode;
  final int baseUnitPriceMinor;
  final int removalDiscountTotalMinor;
  final int modifierTotalMinor;
  final int lineTotalMinor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastLineSnapshot &&
        other.pricingMode == pricingMode &&
        other.baseUnitPriceMinor == baseUnitPriceMinor &&
        other.removalDiscountTotalMinor == removalDiscountTotalMinor &&
        other.modifierTotalMinor == modifierTotalMinor &&
        other.lineTotalMinor == lineTotalMinor;
  }

  @override
  int get hashCode => Object.hash(
    pricingMode,
    baseUnitPriceMinor,
    removalDiscountTotalMinor,
    modifierTotalMinor,
    lineTotalMinor,
  );
}

class BreakfastPricingBreakdown {
  const BreakfastPricingBreakdown({
    required this.basePriceMinor,
    required this.extraAddTotalMinor,
    required this.paidSwapTotalMinor,
    required this.freeSwapTotalMinor,
    required this.includedChoiceTotalMinor,
    required this.removeTotalMinor,
    required this.removalDiscountTotalMinor,
    required this.finalLineTotalMinor,
  });

  final int basePriceMinor;
  final int extraAddTotalMinor;
  final int paidSwapTotalMinor;
  final int freeSwapTotalMinor;
  final int includedChoiceTotalMinor;
  final int removeTotalMinor;
  final int removalDiscountTotalMinor;
  final int finalLineTotalMinor;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastPricingBreakdown &&
        other.basePriceMinor == basePriceMinor &&
        other.extraAddTotalMinor == extraAddTotalMinor &&
        other.paidSwapTotalMinor == paidSwapTotalMinor &&
        other.freeSwapTotalMinor == freeSwapTotalMinor &&
        other.includedChoiceTotalMinor == includedChoiceTotalMinor &&
        other.removeTotalMinor == removeTotalMinor &&
        other.removalDiscountTotalMinor == removalDiscountTotalMinor &&
        other.finalLineTotalMinor == finalLineTotalMinor;
  }

  @override
  int get hashCode => Object.hash(
    basePriceMinor,
    extraAddTotalMinor,
    paidSwapTotalMinor,
    freeSwapTotalMinor,
    includedChoiceTotalMinor,
    removeTotalMinor,
    removalDiscountTotalMinor,
    finalLineTotalMinor,
  );
}

class BreakfastRebuildMetadata {
  const BreakfastRebuildMetadata({
    required this.replacementCount,
    required this.unmatchedRemovalCount,
  });

  final int replacementCount;
  final int unmatchedRemovalCount;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastRebuildMetadata &&
        other.replacementCount == replacementCount &&
        other.unmatchedRemovalCount == unmatchedRemovalCount;
  }

  @override
  int get hashCode => Object.hash(replacementCount, unmatchedRemovalCount);
}

class BreakfastRebuildResult {
  const BreakfastRebuildResult({
    required this.lineSnapshot,
    required this.classifiedModifiers,
    required this.pricingBreakdown,
    required this.validationErrors,
    required this.rebuildMetadata,
  });

  final BreakfastLineSnapshot lineSnapshot;
  final List<BreakfastClassifiedModifier> classifiedModifiers;
  final BreakfastPricingBreakdown pricingBreakdown;
  final List<BreakfastEditErrorCode> validationErrors;
  final BreakfastRebuildMetadata rebuildMetadata;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastRebuildResult &&
        other.lineSnapshot == lineSnapshot &&
        _listEquals(other.classifiedModifiers, classifiedModifiers) &&
        other.pricingBreakdown == pricingBreakdown &&
        _listEquals(other.validationErrors, validationErrors) &&
        other.rebuildMetadata == rebuildMetadata;
  }

  @override
  int get hashCode => Object.hash(
    lineSnapshot,
    Object.hashAll(classifiedModifiers),
    pricingBreakdown,
    Object.hashAll(validationErrors),
    rebuildMetadata,
  );
}

const Object _unsetNullableInt = Object();
const Object _unsetChargeReason = Object();

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}
