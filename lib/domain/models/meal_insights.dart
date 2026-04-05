enum MealSuggestionKind { swap, remove, extra, discount }

class MealSuggestionStat {
  const MealSuggestionStat({
    required this.kind,
    required this.productId,
    required this.productName,
    required this.label,
    required this.usageCount,
    this.componentKey,
    this.itemProductId,
    this.sourceItemProductId,
    this.targetItemProductId,
    this.chargeReasonLabel,
  });

  final MealSuggestionKind kind;
  final int productId;
  final String productName;
  final String label;
  final int usageCount;
  final String? componentKey;
  final int? itemProductId;
  final int? sourceItemProductId;
  final int? targetItemProductId;
  final String? chargeReasonLabel;

  @override
  bool operator ==(Object other) {
    return other is MealSuggestionStat &&
        other.kind == kind &&
        other.productId == productId &&
        other.productName == productName &&
        other.label == label &&
        other.usageCount == usageCount &&
        other.componentKey == componentKey &&
        other.itemProductId == itemProductId &&
        other.sourceItemProductId == sourceItemProductId &&
        other.targetItemProductId == targetItemProductId &&
        other.chargeReasonLabel == chargeReasonLabel;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    productId,
    productName,
    label,
    usageCount,
    componentKey,
    itemProductId,
    sourceItemProductId,
    targetItemProductId,
    chargeReasonLabel,
  );
}

class ProductMealInsights {
  const ProductMealInsights({
    required this.productId,
    required this.productName,
    required this.customizationCount,
    required this.legacyLineCount,
    this.topSwaps = const <MealSuggestionStat>[],
    this.topExtras = const <MealSuggestionStat>[],
    this.topRemovals = const <MealSuggestionStat>[],
    this.topDiscountPatterns = const <MealSuggestionStat>[],
    this.operationalNotes = const <String>[],
  });

  final int productId;
  final String productName;
  final int customizationCount;
  final int legacyLineCount;
  final List<MealSuggestionStat> topSwaps;
  final List<MealSuggestionStat> topExtras;
  final List<MealSuggestionStat> topRemovals;
  final List<MealSuggestionStat> topDiscountPatterns;
  final List<String> operationalNotes;

  @override
  bool operator ==(Object other) {
    return other is ProductMealInsights &&
        other.productId == productId &&
        other.productName == productName &&
        other.customizationCount == customizationCount &&
        other.legacyLineCount == legacyLineCount &&
        _listEquals(other.topSwaps, topSwaps) &&
        _listEquals(other.topExtras, topExtras) &&
        _listEquals(other.topRemovals, topRemovals) &&
        _listEquals(other.topDiscountPatterns, topDiscountPatterns) &&
        _listEquals(other.operationalNotes, operationalNotes);
  }

  @override
  int get hashCode => Object.hash(
    productId,
    productName,
    customizationCount,
    legacyLineCount,
    Object.hashAll(topSwaps),
    Object.hashAll(topExtras),
    Object.hashAll(topRemovals),
    Object.hashAll(topDiscountPatterns),
    Object.hashAll(operationalNotes),
  );
}

class MealInsightsSummary {
  const MealInsightsSummary({
    required this.generatedAt,
    required this.lookbackDays,
    this.topSwaps = const <MealSuggestionStat>[],
    this.topExtras = const <MealSuggestionStat>[],
    this.topRemovals = const <MealSuggestionStat>[],
    this.topDiscountPatterns = const <MealSuggestionStat>[],
    this.productsByActivity = const <ProductMealInsights>[],
  });

  final DateTime generatedAt;
  final int lookbackDays;
  final List<MealSuggestionStat> topSwaps;
  final List<MealSuggestionStat> topExtras;
  final List<MealSuggestionStat> topRemovals;
  final List<MealSuggestionStat> topDiscountPatterns;
  final List<ProductMealInsights> productsByActivity;
}

/// Per-line or per-product semantic revenue breakdown for meal customizations.
/// Replaces ambiguous `modifier_total` with clear component breakdown.
class MealRevenueBreakdown {
  const MealRevenueBreakdown({
    required this.baseMinor,
    required this.extrasMinor,
    required this.paidSwapsMinor,
    required this.discountsMinor,
    required this.netMinor,
  });

  /// Constructs a breakdown from raw totals.
  factory MealRevenueBreakdown.fromTotals({
    required int baseMinor,
    required int extrasMinor,
    required int paidSwapsMinor,
    required int discountsMinor,
  }) {
    return MealRevenueBreakdown(
      baseMinor: baseMinor,
      extrasMinor: extrasMinor,
      paidSwapsMinor: paidSwapsMinor,
      discountsMinor: discountsMinor,
      netMinor: baseMinor + extrasMinor + paidSwapsMinor - discountsMinor,
    );
  }

  final int baseMinor;
  final int extrasMinor;
  final int paidSwapsMinor;
  final int discountsMinor;
  final int netMinor;

  @override
  bool operator ==(Object other) {
    return other is MealRevenueBreakdown &&
        other.baseMinor == baseMinor &&
        other.extrasMinor == extrasMinor &&
        other.paidSwapsMinor == paidSwapsMinor &&
        other.discountsMinor == discountsMinor &&
        other.netMinor == netMinor;
  }

  @override
  int get hashCode => Object.hash(
    baseMinor,
    extrasMinor,
    paidSwapsMinor,
    discountsMinor,
    netMinor,
  );
}

/// Aggregated impact of a meal rule across multiple transactions.
class MealRuleImpactSummary {
  const MealRuleImpactSummary({
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
    return other is MealRuleImpactSummary &&
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

bool _listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (int index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
