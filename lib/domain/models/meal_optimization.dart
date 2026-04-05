/// Phase 9 — Meal Optimization Domain Models
///
/// Data structures used by [MealOptimizationService] to surface revenue-
/// impacting insights to the admin.  All values are read-only aggregations
/// derived deterministically from snapshot data.  Nothing is auto-applied.

// ─────────────────────────────────────────────────────────────────────────────
// Confidence / data quality
// ─────────────────────────────────────────────────────────────────────────────

enum InsightConfidence { high, medium, low }

/// Minimum order count below which insights are considered LOW confidence.
const int kMinOrdersForHighConfidence = 30;
const int kMinOrdersForMediumConfidence = 10;

InsightConfidence confidenceForSampleSize(int orderCount) {
  if (orderCount >= kMinOrdersForHighConfidence) return InsightConfidence.high;
  if (orderCount >= kMinOrdersForMediumConfidence) {
    return InsightConfidence.medium;
  }
  return InsightConfidence.low;
}

// ─────────────────────────────────────────────────────────────────────────────
// A. Discount leakage
// ─────────────────────────────────────────────────────────────────────────────

/// Flags raised by the leakage detector.
enum DiscountLeakageFlag { highFrequency, highAmount }

/// Per-product discount leakage analysis.
class ProductDiscountLeakage {
  const ProductDiscountLeakage({
    required this.productId,
    required this.productName,
    required this.totalOrders,
    required this.discountedOrders,
    required this.totalDiscountMinor,
    required this.avgDiscountPerOrderMinor,
    required this.discountRate,
    required this.discountFrequency,
    required this.topRemovedComponents,
    required this.comboDiscountOrders,
    required this.removeOnlyDiscountOrders,
    required this.flags,
    required this.insights,
    required this.confidence,
    this.hasLegacyLines = false,
  });

  final int productId;
  final String productName;
  final int totalOrders;
  final int discountedOrders;

  /// Sum of all negative price deltas from discount actions (positive integer,
  /// i.e. the absolute value of money given away).
  final int totalDiscountMinor;

  /// Average discount per order in minor units.
  final int avgDiscountPerOrderMinor;

  /// discountedOrders / totalOrders expressed as 0–100.
  final double discountRate;

  /// Alias for [discountRate] — kept for clarity.
  final double discountFrequency;

  /// Component keys that appear in removal actions, sorted by occurrence.
  final List<String> topRemovedComponents;

  final int comboDiscountOrders;
  final int removeOnlyDiscountOrders;
  final List<DiscountLeakageFlag> flags;
  final List<String> insights;
  final InsightConfidence confidence;
  final bool hasLegacyLines;
}

// ─────────────────────────────────────────────────────────────────────────────
// B. Upsell opportunity
// ─────────────────────────────────────────────────────────────────────────────

enum UpsellFlag { lowAttachRate, neverSelected }

/// Per-product upsell opportunity analysis.
class ProductUpsellOpportunity {
  const ProductUpsellOpportunity({
    required this.productId,
    required this.productName,
    required this.totalOrders,
    required this.ordersWithExtras,
    required this.extraAttachRate,
    required this.totalExtraRevenueMinor,
    required this.extraRevenuePerOrderMinor,
    required this.topExtras,
    required this.neverSelectedExtraProductIds,
    required this.insights,
    required this.confidence,
    this.hasLegacyLines = false,
  });

  final int productId;
  final String productName;
  final int totalOrders;
  final int ordersWithExtras;

  /// ordersWithExtras / totalOrders expressed as 0–100.
  final double extraAttachRate;

  final int totalExtraRevenueMinor;
  final int extraRevenuePerOrderMinor;

  /// Extra item product IDs sorted by attach count descending.
  final List<_RankedItem> topExtras;

  /// Extra options in the profile that were never selected in the data window.
  final List<int> neverSelectedExtraProductIds;

  final List<String> insights;
  final InsightConfidence confidence;
  final bool hasLegacyLines;
}

// ─────────────────────────────────────────────────────────────────────────────
// C. Swap behavior
// ─────────────────────────────────────────────────────────────────────────────

/// A single (source → target) swap pair with its occurrence statistics.
class SwapPairStats {
  const SwapPairStats({
    required this.componentKey,
    required this.sourceItemProductId,
    required this.targetItemProductId,
    required this.occurrenceCount,
    required this.freeCount,
    required this.paidCount,
    required this.frequencyPercent,
  });

  final String componentKey;
  final int? sourceItemProductId;
  final int targetItemProductId;
  final int occurrenceCount;
  final int freeCount;
  final int paidCount;

  /// Percentage of total orders for the root product.
  final double frequencyPercent;
}

class ProductSwapBehavior {
  const ProductSwapBehavior({
    required this.productId,
    required this.productName,
    required this.totalOrders,
    required this.ordersWithSwaps,
    required this.freeSwapOrders,
    required this.paidSwapOrders,
    required this.topSwapPairs,
    required this.freeSwapUsageRate,
    required this.insights,
    required this.confidence,
    this.hasLegacyLines = false,
  });

  final int productId;
  final String productName;
  final int totalOrders;
  final int ordersWithSwaps;
  final int freeSwapOrders;
  final int paidSwapOrders;
  final List<SwapPairStats> topSwapPairs;

  /// Percentage of orders that used at least one free swap.
  final double freeSwapUsageRate;

  final List<String> insights;
  final InsightConfidence confidence;
  final bool hasLegacyLines;
}

// ─────────────────────────────────────────────────────────────────────────────
// D. Profile performance
// ─────────────────────────────────────────────────────────────────────────────

enum ProfileHealthLabel {
  balanced,
  discountHeavy,
  upsellWeak,
  overCustomized,
}

class ProfilePerformance {
  const ProfilePerformance({
    required this.profileId,
    required this.profileName,
    required this.totalOrders,
    required this.avgDiscountMinor,
    required this.avgExtraRevenueMinor,
    required this.avgNetAdjustmentMinor,
    required this.customizationRate,
    required this.healthLabel,
    required this.insights,
    required this.confidence,
  });

  final int profileId;
  final String profileName;
  final int totalOrders;
  final int avgDiscountMinor;
  final int avgExtraRevenueMinor;
  final int avgNetAdjustmentMinor;

  /// Percentage of orders using this profile that had any customization.
  final double customizationRate;

  final ProfileHealthLabel healthLabel;
  final List<String> insights;
  final InsightConfidence confidence;
}

// ─────────────────────────────────────────────────────────────────────────────
// E. Actionable recommendations
// ─────────────────────────────────────────────────────────────────────────────

enum RecommendationType {
  reduceDiscount,
  adjustDefaultComponent,
  promoteExtra,
  reviseSwapOptions,
  reviewProfileRules,
}

enum RecommendationSeverity { high, medium, low }

class MealOptimizationRecommendation {
  const MealOptimizationRecommendation({
    required this.type,
    required this.severity,
    required this.description,
    required this.suggestedAction,
    required this.affectedProductId,
    this.affectedProductName,
    this.affectedComponentKey,
    this.affectedItemProductId,
    this.confidence = InsightConfidence.high,
  });

  final RecommendationType type;
  final RecommendationSeverity severity;
  final String description;
  final String suggestedAction;
  final int affectedProductId;
  final String? affectedProductName;
  final String? affectedComponentKey;
  final int? affectedItemProductId;
  final InsightConfidence confidence;
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary container
// ─────────────────────────────────────────────────────────────────────────────

class MealOptimizationReport {
  const MealOptimizationReport({
    required this.generatedAt,
    required this.lookbackDays,
    required this.discountLeakage,
    required this.upsellOpportunities,
    required this.swapBehaviors,
    required this.profilePerformances,
    required this.recommendations,
    required this.dataQualityNotes,
  });

  final DateTime generatedAt;
  final int lookbackDays;
  final List<ProductDiscountLeakage> discountLeakage;
  final List<ProductUpsellOpportunity> upsellOpportunities;
  final List<ProductSwapBehavior> swapBehaviors;
  final List<ProfilePerformance> profilePerformances;
  final List<MealOptimizationRecommendation> recommendations;
  final List<String> dataQualityNotes;

  bool get isEmpty =>
      discountLeakage.isEmpty &&
      upsellOpportunities.isEmpty &&
      swapBehaviors.isEmpty &&
      profilePerformances.isEmpty &&
      recommendations.isEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────────────────────────────────────

class _RankedItem {
  const _RankedItem({
    required this.itemProductId,
    required this.count,
    required this.revenueMinor,
  });

  final int itemProductId;
  final int count;
  final int revenueMinor;
}

// Public alias used by the UI layer.
typedef RankedExtraItem = _RankedItem;
