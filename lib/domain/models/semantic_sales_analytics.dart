import 'order_modifier.dart';

class SemanticSalesAnalytics {
  const SemanticSalesAnalytics({
    this.rootProducts = const <SemanticRootProductAnalytics>[],
    this.choiceSelections = const <SemanticChoiceSelectionAnalytics>[],
    this.addedItems = const <SemanticItemBehaviorAnalytics>[],
    this.removedItems = const <SemanticItemBehaviorAnalytics>[],
    this.chargeReasonBreakdown = const <SemanticChargeReasonAnalytics>[],
    this.mealRevenueBreakdown = const <SemanticMealRevenueAnalytics>[],
    this.appliedMealRules = const <SemanticMealAppliedRuleAnalytics>[],
    this.bundleVariants = const <SemanticBundleVariantAnalytics>[],
    this.dataQualityNotes = const <String>[],
  });

  const SemanticSalesAnalytics.empty()
    : rootProducts = const <SemanticRootProductAnalytics>[],
      choiceSelections = const <SemanticChoiceSelectionAnalytics>[],
      addedItems = const <SemanticItemBehaviorAnalytics>[],
      removedItems = const <SemanticItemBehaviorAnalytics>[],
      chargeReasonBreakdown = const <SemanticChargeReasonAnalytics>[],
      mealRevenueBreakdown = const <SemanticMealRevenueAnalytics>[],
      appliedMealRules = const <SemanticMealAppliedRuleAnalytics>[],
      bundleVariants = const <SemanticBundleVariantAnalytics>[],
      dataQualityNotes = const <String>[];

  final List<SemanticRootProductAnalytics> rootProducts;
  final List<SemanticChoiceSelectionAnalytics> choiceSelections;
  final List<SemanticItemBehaviorAnalytics> addedItems;
  final List<SemanticItemBehaviorAnalytics> removedItems;
  final List<SemanticChargeReasonAnalytics> chargeReasonBreakdown;
  final List<SemanticMealRevenueAnalytics> mealRevenueBreakdown;
  final List<SemanticMealAppliedRuleAnalytics> appliedMealRules;
  final List<SemanticBundleVariantAnalytics> bundleVariants;
  final List<String> dataQualityNotes;

  bool get isEmpty =>
      rootProducts.isEmpty &&
      choiceSelections.isEmpty &&
      addedItems.isEmpty &&
      removedItems.isEmpty &&
      chargeReasonBreakdown.isEmpty &&
      mealRevenueBreakdown.isEmpty &&
      appliedMealRules.isEmpty &&
      bundleVariants.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SemanticSalesAnalytics &&
        _listEquals(other.rootProducts, rootProducts) &&
        _listEquals(other.choiceSelections, choiceSelections) &&
        _listEquals(other.addedItems, addedItems) &&
        _listEquals(other.removedItems, removedItems) &&
        _listEquals(other.chargeReasonBreakdown, chargeReasonBreakdown) &&
        _listEquals(other.mealRevenueBreakdown, mealRevenueBreakdown) &&
        _listEquals(other.appliedMealRules, appliedMealRules) &&
        _listEquals(other.bundleVariants, bundleVariants) &&
        _listEquals(other.dataQualityNotes, dataQualityNotes);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(rootProducts),
    Object.hashAll(choiceSelections),
    Object.hashAll(addedItems),
    Object.hashAll(removedItems),
    Object.hashAll(chargeReasonBreakdown),
    Object.hashAll(mealRevenueBreakdown),
    Object.hashAll(appliedMealRules),
    Object.hashAll(bundleVariants),
    Object.hashAll(dataQualityNotes),
  );
}

class SemanticRootProductAnalytics {
  const SemanticRootProductAnalytics({
    required this.rootProductId,
    required this.rootProductName,
    required this.quantitySold,
    required this.revenueMinor,
  });

  final int rootProductId;
  final String rootProductName;
  final int quantitySold;
  final int revenueMinor;

  @override
  bool operator ==(Object other) {
    return other is SemanticRootProductAnalytics &&
        other.rootProductId == rootProductId &&
        other.rootProductName == rootProductName &&
        other.quantitySold == quantitySold &&
        other.revenueMinor == revenueMinor;
  }

  @override
  int get hashCode =>
      Object.hash(rootProductId, rootProductName, quantitySold, revenueMinor);
}

class SemanticChoiceSelectionAnalytics {
  const SemanticChoiceSelectionAnalytics({
    required this.rootProductId,
    required this.rootProductName,
    required this.groupId,
    required this.groupName,
    required this.itemProductId,
    required this.itemName,
    required this.selectionCount,
    required this.totalSelectedQuantity,
    required this.distributionPercent,
    required this.trend,
  });

  final int rootProductId;
  final String rootProductName;
  final int groupId;
  final String groupName;
  final int itemProductId;
  final String itemName;
  final int selectionCount;
  final int totalSelectedQuantity;
  final double distributionPercent;
  final List<SemanticAnalyticsTrendPoint> trend;

  @override
  bool operator ==(Object other) {
    return other is SemanticChoiceSelectionAnalytics &&
        other.rootProductId == rootProductId &&
        other.rootProductName == rootProductName &&
        other.groupId == groupId &&
        other.groupName == groupName &&
        other.itemProductId == itemProductId &&
        other.itemName == itemName &&
        other.selectionCount == selectionCount &&
        other.totalSelectedQuantity == totalSelectedQuantity &&
        other.distributionPercent == distributionPercent &&
        _listEquals(other.trend, trend);
  }

  @override
  int get hashCode => Object.hash(
    rootProductId,
    rootProductName,
    groupId,
    groupName,
    itemProductId,
    itemName,
    selectionCount,
    totalSelectedQuantity,
    distributionPercent,
    Object.hashAll(trend),
  );
}

class SemanticAnalyticsTrendPoint {
  const SemanticAnalyticsTrendPoint({
    required this.date,
    required this.count,
    required this.quantity,
  });

  final DateTime date;
  final int count;
  final int quantity;

  @override
  bool operator ==(Object other) {
    return other is SemanticAnalyticsTrendPoint &&
        other.date == date &&
        other.count == count &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(date, count, quantity);
}

class SemanticItemBehaviorAnalytics {
  const SemanticItemBehaviorAnalytics({
    required this.rootProductId,
    required this.rootProductName,
    required this.itemProductId,
    required this.itemName,
    required this.occurrenceCount,
    required this.totalQuantity,
    required this.revenueMinor,
    required this.percentageOfRootSales,
  });

  final int rootProductId;
  final String rootProductName;
  final int itemProductId;
  final String itemName;
  final int occurrenceCount;
  final int totalQuantity;
  final int revenueMinor;
  final double percentageOfRootSales;

  @override
  bool operator ==(Object other) {
    return other is SemanticItemBehaviorAnalytics &&
        other.rootProductId == rootProductId &&
        other.rootProductName == rootProductName &&
        other.itemProductId == itemProductId &&
        other.itemName == itemName &&
        other.occurrenceCount == occurrenceCount &&
        other.totalQuantity == totalQuantity &&
        other.revenueMinor == revenueMinor &&
        other.percentageOfRootSales == percentageOfRootSales;
  }

  @override
  int get hashCode => Object.hash(
    rootProductId,
    rootProductName,
    itemProductId,
    itemName,
    occurrenceCount,
    totalQuantity,
    revenueMinor,
    percentageOfRootSales,
  );
}

class SemanticChargeReasonAnalytics {
  const SemanticChargeReasonAnalytics({
    required this.chargeReason,
    required this.eventCount,
    required this.totalQuantity,
    required this.revenueMinor,
  });

  final ModifierChargeReason chargeReason;
  final int eventCount;
  final int totalQuantity;
  final int revenueMinor;

  @override
  bool operator ==(Object other) {
    return other is SemanticChargeReasonAnalytics &&
        other.chargeReason == chargeReason &&
        other.eventCount == eventCount &&
        other.totalQuantity == totalQuantity &&
        other.revenueMinor == revenueMinor;
  }

  @override
  int get hashCode =>
      Object.hash(chargeReason, eventCount, totalQuantity, revenueMinor);
}

class SemanticMealRevenueAnalytics {
  const SemanticMealRevenueAnalytics({
    required this.rootProductId,
    required this.rootProductName,
    required this.quantitySold,
    required this.baseRevenueMinor,
    required this.extraRevenueMinor,
    required this.paidSwapRevenueMinor,
    required this.freeSwapCount,
    required this.discountTotalMinor,
    required this.netRevenueMinor,
    required this.removeActionCount,
    required this.swapActionCount,
    required this.extraActionCount,
    required this.discountActionCount,
  });

  final int rootProductId;
  final String rootProductName;
  final int quantitySold;
  final int baseRevenueMinor;
  final int extraRevenueMinor;
  final int paidSwapRevenueMinor;
  final int freeSwapCount;
  final int discountTotalMinor;
  final int netRevenueMinor;
  final int removeActionCount;
  final int swapActionCount;
  final int extraActionCount;
  final int discountActionCount;

  @override
  bool operator ==(Object other) {
    return other is SemanticMealRevenueAnalytics &&
        other.rootProductId == rootProductId &&
        other.rootProductName == rootProductName &&
        other.quantitySold == quantitySold &&
        other.baseRevenueMinor == baseRevenueMinor &&
        other.extraRevenueMinor == extraRevenueMinor &&
        other.paidSwapRevenueMinor == paidSwapRevenueMinor &&
        other.freeSwapCount == freeSwapCount &&
        other.discountTotalMinor == discountTotalMinor &&
        other.netRevenueMinor == netRevenueMinor &&
        other.removeActionCount == removeActionCount &&
        other.swapActionCount == swapActionCount &&
        other.extraActionCount == extraActionCount &&
        other.discountActionCount == discountActionCount;
  }

  @override
  int get hashCode => Object.hash(
    rootProductId,
    rootProductName,
    quantitySold,
    baseRevenueMinor,
    extraRevenueMinor,
    paidSwapRevenueMinor,
    freeSwapCount,
    discountTotalMinor,
    netRevenueMinor,
    removeActionCount,
    swapActionCount,
    extraActionCount,
    discountActionCount,
  );
}

class SemanticMealAppliedRuleAnalytics {
  const SemanticMealAppliedRuleAnalytics({
    required this.ruleId,
    required this.ruleType,
    required this.applicationCount,
    required this.totalImpactMinor,
  });

  final int ruleId;
  final String ruleType;
  final int applicationCount;
  final int totalImpactMinor;

  @override
  bool operator ==(Object other) {
    return other is SemanticMealAppliedRuleAnalytics &&
        other.ruleId == ruleId &&
        other.ruleType == ruleType &&
        other.applicationCount == applicationCount &&
        other.totalImpactMinor == totalImpactMinor;
  }

  @override
  int get hashCode => Object.hash(
    ruleId,
    ruleType,
    applicationCount,
    totalImpactMinor,
  );
}

class SemanticBundleVariantAnalytics {
  const SemanticBundleVariantAnalytics({
    required this.rootProductId,
    required this.rootProductName,
    required this.variantKey,
    required this.orderCount,
    required this.revenueMinor,
    required this.chosenItemProductIds,
    required this.chosenItemNames,
    required this.removedItemProductIds,
    required this.removedItemNames,
    required this.addedItemProductIds,
    required this.addedItemNames,
  });

  final int rootProductId;
  final String rootProductName;
  final String variantKey;
  final int orderCount;
  final int revenueMinor;
  final List<int> chosenItemProductIds;
  final List<String> chosenItemNames;
  final List<int> removedItemProductIds;
  final List<String> removedItemNames;
  final List<int> addedItemProductIds;
  final List<String> addedItemNames;

  @override
  bool operator ==(Object other) {
    return other is SemanticBundleVariantAnalytics &&
        other.rootProductId == rootProductId &&
        other.rootProductName == rootProductName &&
        other.variantKey == variantKey &&
        other.orderCount == orderCount &&
        other.revenueMinor == revenueMinor &&
        _listEquals(other.chosenItemProductIds, chosenItemProductIds) &&
        _listEquals(other.chosenItemNames, chosenItemNames) &&
        _listEquals(other.removedItemProductIds, removedItemProductIds) &&
        _listEquals(other.removedItemNames, removedItemNames) &&
        _listEquals(other.addedItemProductIds, addedItemProductIds) &&
        _listEquals(other.addedItemNames, addedItemNames);
  }

  @override
  int get hashCode => Object.hash(
    rootProductId,
    rootProductName,
    variantKey,
    orderCount,
    revenueMinor,
    Object.hashAll(chosenItemProductIds),
    Object.hashAll(chosenItemNames),
    Object.hashAll(removedItemProductIds),
    Object.hashAll(removedItemNames),
    Object.hashAll(addedItemProductIds),
    Object.hashAll(addedItemNames),
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
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
