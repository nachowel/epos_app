import '../models/meal_customization.dart';
import '../models/meal_optimization.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/product_repository.dart';

// Threshold constants
const double kHighRemovalThreshold = 0.60; // >60% → default issue
const double kHighDiscountFrequency = 0.40; // >40% → leakage risk
const double kHighFreeSwapUsageThreshold = 0.80; // >80% → always using free

/// Phase 9 — Meal Optimization Service
///
/// Generates revenue-impact analytics from persisted meal customization
/// snapshot data.  All analysis is deterministic — no LLM, no external calls.
/// Results are READ-ONLY for the admin; nothing is auto-applied.
///
/// Sections produced:
///   A. Discount leakage
///   B. Upsell opportunities (extras)
///   C. Swap behavior
///   D. Profile performance
///   E. Actionable recommendations
///   G. Data quality / confidence
class MealOptimizationService {
  const MealOptimizationService({
    required TransactionRepository transactionRepository,
    required ProductRepository productRepository,
  })  : _transactionRepository = transactionRepository,
        _productRepository = productRepository;

  final TransactionRepository _transactionRepository;
  final ProductRepository _productRepository;

  /// Generates a full [MealOptimizationReport] by analysing all products
  /// active in the given [lookbackDays] window.
  Future<MealOptimizationReport> generateReport({
    int lookbackDays = 30,
  }) async {
    final List<int> activeProductIds =
        await _transactionRepository.getMealCustomizationActiveProductIds(
          lookbackDays: lookbackDays,
        );

    // ── collect per-product snapshots once ──────────────────────────────────
    final Map<int, List<MealCustomizationPersistedSnapshotRecord>>
    snapshotsByProduct = <int, List<MealCustomizationPersistedSnapshotRecord>>{
    };
    final Map<int, String> productNames = <int, String>{};
    final List<String> dataQualityNotes = <String>[];

    for (final int productId in activeProductIds) {
      final List<MealCustomizationPersistedSnapshotRecord> snapshots =
          await _transactionRepository.getMealCustomizationSnapshotsByProduct(
            productId,
          );
      snapshotsByProduct[productId] = snapshots;

      final product = await _productRepository.getById(productId);
      if (product != null) {
        productNames[productId] = product.name;
      }

      final int legacyCount = await _transactionRepository
          .countLegacyMealCustomizationLines(productId);
      if (legacyCount > 0) {
        dataQualityNotes.add(
          'Product ${productNames[productId] ?? productId}: $legacyCount legacy line(s) exist without snapshot data.',
        );
      }
    }

    // ── resolve names from actions ──────────────────────────────────────────
    await _resolveNamesFromActions(snapshotsByProduct, productNames);

    // ── build per-section results ───────────────────────────────────────────
    final List<ProductDiscountLeakage> leakage = <ProductDiscountLeakage>[];
    final List<ProductUpsellOpportunity> upsells = <ProductUpsellOpportunity>[];
    final List<ProductSwapBehavior> swapBehaviors = <ProductSwapBehavior>[];

    final Map<int, _ProfileAccumulator> profileAccumulators =
        <int, _ProfileAccumulator>{};

    for (final int productId in activeProductIds) {
      final List<MealCustomizationPersistedSnapshotRecord> snapshots =
          snapshotsByProduct[productId] ?? <MealCustomizationPersistedSnapshotRecord>[];
      if (snapshots.isEmpty) continue;

      final String productName = productNames[productId] ?? 'Product $productId';
      final int legacyCount = await _transactionRepository
          .countLegacyMealCustomizationLines(productId);
      final bool hasLegacy = legacyCount > 0;

      final _ProductAccumulator acc = _ProductAccumulator();
      for (final MealCustomizationPersistedSnapshotRecord record in snapshots) {
        acc.accumulate(record.snapshot);

        // feed profile accumulator
        final int profileId = record.profileId;
        profileAccumulators.putIfAbsent(
          profileId,
          () => _ProfileAccumulator(profileId: profileId),
        );
        profileAccumulators[profileId]!.accumulate(record.snapshot);
      }

      leakage.add(
        acc.toDiscountLeakage(
          productId: productId,
          productName: productName,
          hasLegacyLines: hasLegacy,
        ),
      );
      upsells.add(
        acc.toUpsellOpportunity(
          productId: productId,
          productName: productName,
          productNamesById: productNames,
          hasLegacyLines: hasLegacy,
        ),
      );
      swapBehaviors.add(
        acc.toSwapBehavior(
          productId: productId,
          productName: productName,
          productNamesById: productNames,
          hasLegacyLines: hasLegacy,
        ),
      );
    }

    // ── profile performance ─────────────────────────────────────────────────
    final List<ProfilePerformance> profilePerformances = <ProfilePerformance>[];
    for (final _ProfileAccumulator acc in profileAccumulators.values) {
      final String profileName =
          await _resolveProfileName(acc.profileId) ??
          'Profile ${acc.profileId}';
      profilePerformances.add(
        acc.toProfilePerformance(profileName: profileName),
      );
    }
    profilePerformances.sort(
      (ProfilePerformance a, ProfilePerformance b) =>
          b.totalOrders.compareTo(a.totalOrders),
    );

    // sort leakage, upsells, swaps by order volume descending
    leakage.sort(
      (ProductDiscountLeakage a, ProductDiscountLeakage b) =>
          b.totalOrders.compareTo(a.totalOrders),
    );
    upsells.sort(
      (ProductUpsellOpportunity a, ProductUpsellOpportunity b) =>
          b.totalOrders.compareTo(a.totalOrders),
    );
    swapBehaviors.sort(
      (ProductSwapBehavior a, ProductSwapBehavior b) =>
          b.totalOrders.compareTo(a.totalOrders),
    );

    // ── recommendations ─────────────────────────────────────────────────────
    final List<MealOptimizationRecommendation> recommendations =
        _buildRecommendations(
          leakage: leakage,
          upsells: upsells,
          swapBehaviors: swapBehaviors,
          productNames: productNames,
        );

    return MealOptimizationReport(
      generatedAt: DateTime.now(),
      lookbackDays: lookbackDays,
      discountLeakage: leakage,
      upsellOpportunities: upsells,
      swapBehaviors: swapBehaviors,
      profilePerformances: profilePerformances,
      recommendations: recommendations,
      dataQualityNotes: dataQualityNotes,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Section E — Recommendations (deterministic threshold logic)
  // ─────────────────────────────────────────────────────────────────────────

  List<MealOptimizationRecommendation> _buildRecommendations({
    required List<ProductDiscountLeakage> leakage,
    required List<ProductUpsellOpportunity> upsells,
    required List<ProductSwapBehavior> swapBehaviors,
    required Map<int, String> productNames,
  }) {
    final List<MealOptimizationRecommendation> recommendations =
        <MealOptimizationRecommendation>[];

    // --- A. Discount leakage recommendations ---
    for (final ProductDiscountLeakage item in leakage) {
      if (item.confidence == InsightConfidence.low) continue;

      // High removal rate → consider removing from default
      for (final String componentKey in item.topRemovedComponents.take(1)) {
        // We only know the rate from the leakage flags; use the removal signal.
        if (item.flags.contains(DiscountLeakageFlag.highFrequency)) {
          recommendations.add(
            MealOptimizationRecommendation(
              type: RecommendationType.adjustDefaultComponent,
              severity: RecommendationSeverity.medium,
              description:
                  '"${item.productName}" has high removal frequency on component "$componentKey".',
              suggestedAction:
                  'Consider removing "$componentKey" from the default composition — customers frequently remove it.',
              affectedProductId: item.productId,
              affectedProductName: item.productName,
              affectedComponentKey: componentKey,
              confidence: item.confidence,
            ),
          );
        }
      }

      // High discount amount / frequency → leakage risk
      if (item.flags.contains(DiscountLeakageFlag.highAmount) ||
          (item.flags.contains(DiscountLeakageFlag.highFrequency) &&
              item.comboDiscountOrders > 0)) {
        recommendations.add(
          MealOptimizationRecommendation(
            type: RecommendationType.reduceDiscount,
            severity: RecommendationSeverity.high,
            description:
                '"${item.productName}" gives away ${_currencyLabel(item.totalDiscountMinor)} in discounts across ${item.totalOrders} orders.',
            suggestedAction:
                'Review pricing rules — high discount leakage detected. Consider increasing base price or tightening discount conditions.',
            affectedProductId: item.productId,
            affectedProductName: item.productName,
            confidence: item.confidence,
          ),
        );
      }
    }

    // --- B. Upsell recommendations ---
    for (final ProductUpsellOpportunity item in upsells) {
      if (item.confidence == InsightConfidence.low) continue;

      if (item.extraAttachRate < kLowExtraAttachThreshold * 100 &&
          item.totalOrders >= kMinOrdersForMediumConfidence) {
        final String extraLabel = item.topExtras.isNotEmpty
            ? 'extra item (id=${item.topExtras.first.itemProductId})'
            : 'extras';
        recommendations.add(
          MealOptimizationRecommendation(
            type: RecommendationType.promoteExtra,
            severity: RecommendationSeverity.medium,
            description:
                '"${item.productName}" has only a ${item.extraAttachRate.toStringAsFixed(1)}% extra attach rate.',
            suggestedAction:
                'Promote $extraLabel at POS — low conversion, high potential.',
            affectedProductId: item.productId,
            affectedProductName: item.productName,
            confidence: item.confidence,
          ),
        );
      }

      if (item.neverSelectedExtraProductIds.isNotEmpty) {
        recommendations.add(
          MealOptimizationRecommendation(
            type: RecommendationType.promoteExtra,
            severity: RecommendationSeverity.low,
            description:
                '"${item.productName}" has ${item.neverSelectedExtraProductIds.length} extra(s) never selected.',
            suggestedAction:
                'Review extras — consider removing or repricing those never chosen.',
            affectedProductId: item.productId,
            affectedProductName: item.productName,
            confidence: item.confidence,
          ),
        );
      }
    }

    // --- C. Swap recommendations ---
    for (final ProductSwapBehavior item in swapBehaviors) {
      if (item.confidence == InsightConfidence.low) continue;

      if (item.topSwapPairs.isNotEmpty) {
        final SwapPairStats top = item.topSwapPairs.first;
        if (top.frequencyPercent > kHighRemovalThreshold * 100) {
          recommendations.add(
            MealOptimizationRecommendation(
              type: RecommendationType.adjustDefaultComponent,
              severity: RecommendationSeverity.medium,
              description:
                  '"${item.productName}": customers swap component "${top.componentKey}" to id=${top.targetItemProductId} in ${top.frequencyPercent.toStringAsFixed(1)}% of orders.',
              suggestedAction:
                  'Consider making that item the default — the current default may not match customer preference.',
              affectedProductId: item.productId,
              affectedProductName: item.productName,
              affectedComponentKey: top.componentKey,
              affectedItemProductId: top.targetItemProductId,
              confidence: item.confidence,
            ),
          );
        }
      }

      if (item.freeSwapUsageRate > kHighFreeSwapUsageThreshold * 100) {
        recommendations.add(
          MealOptimizationRecommendation(
            type: RecommendationType.reviseSwapOptions,
            severity: RecommendationSeverity.low,
            description:
                '"${item.productName}": free swaps are used in ${item.freeSwapUsageRate.toStringAsFixed(1)}% of orders.',
            suggestedAction:
                'Review free swap limit — customers almost always fully use it, which may indicate mispricing.',
            affectedProductId: item.productId,
            affectedProductName: item.productName,
            confidence: item.confidence,
          ),
        );
      }
    }

    // Sort: high severity first, then medium, then low.
    recommendations.sort(
      (MealOptimizationRecommendation a, MealOptimizationRecommendation b) {
        final int severityOrder = _severityOrder(a.severity).compareTo(
          _severityOrder(b.severity),
        );
        if (severityOrder != 0) return severityOrder;
        return a.affectedProductId.compareTo(b.affectedProductId);
      },
    );
    return recommendations;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _resolveNamesFromActions(
    Map<int, List<MealCustomizationPersistedSnapshotRecord>> snapshotsByProduct,
    Map<int, String> productNames,
  ) async {
    final Set<int> toResolve = <int>{};
    for (final List<MealCustomizationPersistedSnapshotRecord> snapshots
        in snapshotsByProduct.values) {
      for (final MealCustomizationPersistedSnapshotRecord record in snapshots) {
        for (final MealCustomizationSemanticAction action
            in record.snapshot.actions) {
          if (action.itemProductId != null && !productNames.containsKey(action.itemProductId!)) {
            toResolve.add(action.itemProductId!);
          }
          if (action.sourceItemProductId != null &&
              !productNames.containsKey(action.sourceItemProductId!)) {
            toResolve.add(action.sourceItemProductId!);
          }
        }
      }
    }
    for (final int id in toResolve) {
      final product = await _productRepository.getById(id);
      if (product != null) productNames[id] = product.name;
    }
  }

  Future<String?> _resolveProfileName(int profileId) async {
    // ProfileRepository not injected here to keep scope narrow — return null
    // and the caller can fallback. We avoid cross-service coupling.
    return null;
  }

  static String _currencyLabel(int minor) {
    final double value = minor / 100.0;
    return '£${value.toStringAsFixed(2)}';
  }

  static int _severityOrder(RecommendationSeverity s) {
    switch (s) {
      case RecommendationSeverity.high:
        return 0;
      case RecommendationSeverity.medium:
        return 1;
      case RecommendationSeverity.low:
        return 2;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-product accumulator
// ─────────────────────────────────────────────────────────────────────────────

class _ProductAccumulator {
  int _orderCount = 0;

  // Discount tracking
  int _discountedOrders = 0;
  int _totalDiscountMinor = 0;
  int _comboDiscountOrders = 0;
  int _removeOnlyDiscountOrders = 0;

  // Removal tracking: componentKey → count
  final Map<String, int> _removalCounts = <String, int>{};

  // Extra tracking: itemProductId → (count, revenueMinor)
  final Map<int, _ExtraEntry> _extraEntries = <int, _ExtraEntry>{};
  int _ordersWithExtras = 0;
  int _totalExtraRevenueMinor = 0;

  // Swap tracking: key → SwapEntry
  final Map<String, _SwapEntry> _swapEntries = <String, _SwapEntry>{};
  int _ordersWithSwaps = 0;
  int _freeSwapOrders = 0;
  int _paidSwapOrders = 0;

  void accumulate(MealCustomizationResolvedSnapshot snapshot) {
    _orderCount += 1;

    // ── discounts ────────────────────────────────────────────────────────────
    bool thisOrderHasDiscount = false;
    bool thisOrderHasCombo = false;
    bool thisOrderHasRemoveOnly = false;
    for (final MealCustomizationSemanticAction action
        in snapshot.triggeredDiscounts) {
      thisOrderHasDiscount = true;
      _totalDiscountMinor += action.priceDeltaMinor.abs();
      if (action.chargeReason ==
          MealCustomizationChargeReason.comboDiscount) {
        thisOrderHasCombo = true;
      } else if (action.chargeReason ==
          MealCustomizationChargeReason.removalDiscount) {
        thisOrderHasRemoveOnly = true;
      }
    }
    if (thisOrderHasDiscount) _discountedOrders += 1;
    if (thisOrderHasCombo) _comboDiscountOrders += 1;
    if (thisOrderHasRemoveOnly) _removeOnlyDiscountOrders += 1;

    // ── removals ─────────────────────────────────────────────────────────────
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedComponentActions) {
      if (action.action == MealCustomizationAction.remove &&
          action.componentKey != null) {
        _removalCounts.update(
          action.componentKey!,
          (int c) => c + 1,
          ifAbsent: () => 1,
        );
      }
    }

    // ── extras ───────────────────────────────────────────────────────────────
    bool thisOrderHasExtra = false;
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedExtraActions) {
      if (action.itemProductId != null) {
        thisOrderHasExtra = true;
        final int rev = action.priceDeltaMinor;
        _totalExtraRevenueMinor += rev;
        _extraEntries.update(
          action.itemProductId!,
          (_ExtraEntry e) => _ExtraEntry(
            itemProductId: e.itemProductId,
            count: e.count + 1,
            revenueMinor: e.revenueMinor + rev,
          ),
          ifAbsent: () => _ExtraEntry(
            itemProductId: action.itemProductId!,
            count: 1,
            revenueMinor: rev,
          ),
        );
      }
    }
    if (thisOrderHasExtra) _ordersWithExtras += 1;

    // ── swaps ────────────────────────────────────────────────────────────────
    bool thisOrderHasSwap = false;
    bool thisOrderHasFreeSwap = false;
    bool thisOrderHasPaidSwap = false;
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedComponentActions) {
      if (action.action != MealCustomizationAction.swap) continue;
      if (action.componentKey == null || action.itemProductId == null) continue;
      thisOrderHasSwap = true;

      final bool isFree = action.chargeReason ==
          MealCustomizationChargeReason.freeSwap;
      if (isFree) {
        thisOrderHasFreeSwap = true;
      } else {
        thisOrderHasPaidSwap = true;
      }

      final String key =
          '${action.componentKey}:${action.sourceItemProductId}:${action.itemProductId}';
      _swapEntries.update(
        key,
        (_SwapEntry e) => _SwapEntry(
          componentKey: e.componentKey,
          sourceItemProductId: e.sourceItemProductId,
          targetItemProductId: e.targetItemProductId,
          count: e.count + 1,
          freeCount: e.freeCount + (isFree ? 1 : 0),
          paidCount: e.paidCount + (isFree ? 0 : 1),
        ),
        ifAbsent: () => _SwapEntry(
          componentKey: action.componentKey!,
          sourceItemProductId: action.sourceItemProductId,
          targetItemProductId: action.itemProductId!,
          count: 1,
          freeCount: isFree ? 1 : 0,
          paidCount: isFree ? 0 : 1,
        ),
      );
    }
    if (thisOrderHasSwap) _ordersWithSwaps += 1;
    if (thisOrderHasFreeSwap) _freeSwapOrders += 1;
    if (thisOrderHasPaidSwap) _paidSwapOrders += 1;
  }

  // ── build section results ─────────────────────────────────────────────────

  ProductDiscountLeakage toDiscountLeakage({
    required int productId,
    required String productName,
    required bool hasLegacyLines,
  }) {
    final InsightConfidence confidence = confidenceForSampleSize(_orderCount);
    final double freq = _orderCount == 0
        ? 0
        : (_discountedOrders / _orderCount) * 100;
    final int avgDiscount =
        _discountedOrders == 0 ? 0 : _totalDiscountMinor ~/ _discountedOrders;

    final List<MapEntry<String, int>> topRemoved = _removalCounts.entries
        .toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );

    final List<String> topRemovedKeys =
        topRemoved.map((MapEntry<String, int> e) => e.key).toList();

    final List<DiscountLeakageFlag> flags = <DiscountLeakageFlag>[];
    if (freq > kHighDiscountFrequency * 100) {
      flags.add(DiscountLeakageFlag.highFrequency);
    }
    if (_totalDiscountMinor > 0 && _orderCount > 0) {
      // Flag if average leakage per order is above £0.50
      if ((_totalDiscountMinor / _orderCount) > 50) {
        flags.add(DiscountLeakageFlag.highAmount);
      }
    }

    final List<String> insights = <String>[];
    if (confidence == InsightConfidence.low) {
      insights.add('Not enough data yet for reliable discount analysis.');
    } else {
      if (topRemovedKeys.isNotEmpty) {
        final String top = topRemovedKeys.first;
        final int cnt = _removalCounts[top]!;
        final double pct = _orderCount == 0 ? 0 : (cnt / _orderCount) * 100;
        insights.add(
          '"$top" is removed in ${pct.toStringAsFixed(0)}% of orders.',
        );
      }
      if (_totalDiscountMinor > 0 && _orderCount > 0) {
        insights.add(
          'This product gives ${MealOptimizationService._currencyLabel(avgDiscount)} discount on average per discounted order.',
        );
      }
      if (_comboDiscountOrders > 0 && _orderCount > 0) {
        final double comboRate = (_comboDiscountOrders / _orderCount) * 100;
        insights.add(
          'Combo discount is triggered in ${comboRate.toStringAsFixed(0)}% of orders.',
        );
      }
      if (hasLegacyLines) {
        insights.add('Partial data: legacy lines exist without snapshot data.');
      }
    }

    return ProductDiscountLeakage(
      productId: productId,
      productName: productName,
      totalOrders: _orderCount,
      discountedOrders: _discountedOrders,
      totalDiscountMinor: _totalDiscountMinor,
      avgDiscountPerOrderMinor: avgDiscount,
      discountRate: freq,
      discountFrequency: freq,
      topRemovedComponents: topRemovedKeys,
      comboDiscountOrders: _comboDiscountOrders,
      removeOnlyDiscountOrders: _removeOnlyDiscountOrders,
      flags: flags,
      insights: insights,
      confidence: confidence,
      hasLegacyLines: hasLegacyLines,
    );
  }

  ProductUpsellOpportunity toUpsellOpportunity({
    required int productId,
    required String productName,
    required Map<int, String> productNamesById,
    required bool hasLegacyLines,
  }) {
    final InsightConfidence confidence = confidenceForSampleSize(_orderCount);
    final double attachRate = _orderCount == 0
        ? 0
        : (_ordersWithExtras / _orderCount) * 100;
    final int avgExtraRev = _orderCount == 0
        ? 0
        : _totalExtraRevenueMinor ~/ _orderCount;

    final List<_ExtraEntry> sortedExtras = _extraEntries.values.toList()
      ..sort((_ExtraEntry a, _ExtraEntry b) => b.count.compareTo(a.count));
    final List<RankedExtraItem> topExtras = sortedExtras
        .map(
          (_ExtraEntry e) => RankedExtraItem(
            itemProductId: e.itemProductId,
            count: e.count,
            revenueMinor: e.revenueMinor,
          ),
        )
        .toList();

    final List<String> insights = <String>[];
    if (confidence == InsightConfidence.low) {
      insights.add('Not enough data yet for reliable upsell analysis.');
    } else {
      insights.add(
        'Extras are added in ${attachRate.toStringAsFixed(1)}% of orders.',
      );
      if (topExtras.isNotEmpty) {
        final String topName =
            productNamesById[topExtras.first.itemProductId] ??
            'item ${topExtras.first.itemProductId}';
        insights.add('"$topName" is the top upsell for this product.');
      }
      if (attachRate < kLowExtraAttachThreshold * 100 && _orderCount >= kMinOrdersForMediumConfidence) {
        insights.add(
          'Low extra attach rate — upsell potential may be unrealised.',
        );
      }
      if (hasLegacyLines) {
        insights.add('Partial data: legacy lines exist without snapshot data.');
      }
    }

    return ProductUpsellOpportunity(
      productId: productId,
      productName: productName,
      totalOrders: _orderCount,
      ordersWithExtras: _ordersWithExtras,
      extraAttachRate: attachRate,
      totalExtraRevenueMinor: _totalExtraRevenueMinor,
      extraRevenuePerOrderMinor: avgExtraRev,
      topExtras: topExtras,
      neverSelectedExtraProductIds: const <int>[], // resolved externally if profile available
      insights: insights,
      confidence: confidence,
      hasLegacyLines: hasLegacyLines,
    );
  }

  ProductSwapBehavior toSwapBehavior({
    required int productId,
    required String productName,
    required Map<int, String> productNamesById,
    required bool hasLegacyLines,
  }) {
    final InsightConfidence confidence = confidenceForSampleSize(_orderCount);
    final double freeSwapRate = _orderCount == 0
        ? 0
        : (_freeSwapOrders / _orderCount) * 100;

    final List<_SwapEntry> sortedSwaps = _swapEntries.values.toList()
      ..sort((_SwapEntry a, _SwapEntry b) => b.count.compareTo(a.count));
    final List<SwapPairStats> topPairs = sortedSwaps.take(5).map((_SwapEntry e) {
      final double pct = _orderCount == 0
          ? 0
          : (e.count / _orderCount) * 100;
      return SwapPairStats(
        componentKey: e.componentKey,
        sourceItemProductId: e.sourceItemProductId,
        targetItemProductId: e.targetItemProductId,
        occurrenceCount: e.count,
        freeCount: e.freeCount,
        paidCount: e.paidCount,
        frequencyPercent: pct,
      );
    }).toList();

    final List<String> insights = <String>[];
    if (confidence == InsightConfidence.low) {
      insights.add('Not enough data yet for reliable swap analysis.');
    } else {
      if (topPairs.isNotEmpty) {
        final SwapPairStats top = topPairs.first;
        final String targetName =
            productNamesById[top.targetItemProductId] ??
            'item ${top.targetItemProductId}';
        insights.add(
          'Customers often swap "${top.componentKey}" to "$targetName" (${top.frequencyPercent.toStringAsFixed(0)}% of orders).',
        );
      }
      if (freeSwapRate > kHighFreeSwapUsageThreshold * 100) {
        insights.add(
          'Free swaps are almost always fully used (${freeSwapRate.toStringAsFixed(0)}% of orders).',
        );
      }
      if (hasLegacyLines) {
        insights.add('Partial data: legacy lines exist without snapshot data.');
      }
    }

    return ProductSwapBehavior(
      productId: productId,
      productName: productName,
      totalOrders: _orderCount,
      ordersWithSwaps: _ordersWithSwaps,
      freeSwapOrders: _freeSwapOrders,
      paidSwapOrders: _paidSwapOrders,
      topSwapPairs: topPairs,
      freeSwapUsageRate: freeSwapRate,
      insights: insights,
      confidence: confidence,
      hasLegacyLines: hasLegacyLines,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Per-profile accumulator
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAccumulator {
  _ProfileAccumulator({required this.profileId});

  final int profileId;
  int _orderCount = 0;
  int _customizedOrders = 0;
  int _totalDiscountMinor = 0;
  int _totalExtraRevenueMinor = 0;
  int _totalAdjustmentMinor = 0;

  void accumulate(MealCustomizationResolvedSnapshot snapshot) {
    _orderCount += 1;
    _totalAdjustmentMinor += snapshot.totalAdjustmentMinor;

    bool customized = false;
    for (final MealCustomizationSemanticAction action
        in snapshot.triggeredDiscounts) {
      _totalDiscountMinor += action.priceDeltaMinor.abs();
      customized = true;
    }
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedExtraActions) {
      _totalExtraRevenueMinor += action.priceDeltaMinor;
      customized = true;
    }
    if (snapshot.resolvedComponentActions.isNotEmpty) customized = true;
    if (customized) _customizedOrders += 1;
  }

  ProfilePerformance toProfilePerformance({required String profileName}) {
    final InsightConfidence confidence = confidenceForSampleSize(_orderCount);
    final int avgDiscount =
        _orderCount == 0 ? 0 : _totalDiscountMinor ~/ _orderCount;
    final int avgExtraRev =
        _orderCount == 0 ? 0 : _totalExtraRevenueMinor ~/ _orderCount;
    final int avgNet =
        _orderCount == 0 ? 0 : _totalAdjustmentMinor ~/ _orderCount;
    final double customRate = _orderCount == 0
        ? 0
        : (_customizedOrders / _orderCount) * 100;

    // Health label classification
    final ProfileHealthLabel label = _classifyHealth(
      avgDiscountMinor: avgDiscount,
      avgExtraRevenueMinor: avgExtraRev,
      customizationRate: customRate,
    );

    final List<String> insights = <String>[];
    if (confidence == InsightConfidence.low) {
      insights.add('Not enough data yet for profile performance scoring.');
    } else {
      switch (label) {
        case ProfileHealthLabel.discountHeavy:
          insights.add(
            'This profile reduces revenue on most orders due to high discounts.',
          );
          break;
        case ProfileHealthLabel.upsellWeak:
          insights.add(
            'This profile rarely generates extra revenue — upsell is underperforming.',
          );
          break;
        case ProfileHealthLabel.overCustomized:
          insights.add(
            'Customers heavily modify products using this profile — consider reviewing defaults.',
          );
          break;
        case ProfileHealthLabel.balanced:
          insights.add(
            'This profile shows a balanced pattern of discounts and upsells.',
          );
          break;
      }
    }

    return ProfilePerformance(
      profileId: profileId,
      profileName: profileName,
      totalOrders: _orderCount,
      avgDiscountMinor: avgDiscount,
      avgExtraRevenueMinor: avgExtraRev,
      avgNetAdjustmentMinor: avgNet,
      customizationRate: customRate,
      healthLabel: label,
      insights: insights,
      confidence: confidence,
    );
  }

  /// Deterministic classification using thresholds.
  static ProfileHealthLabel _classifyHealth({
    required int avgDiscountMinor,
    required int avgExtraRevenueMinor,
    required double customizationRate,
  }) {
    // discount dominant: avg discount > avg extra by meaningful margin
    if (avgDiscountMinor > 0 && avgDiscountMinor > avgExtraRevenueMinor + 20) {
      return ProfileHealthLabel.discountHeavy;
    }
    // upsell weak: no meaningful extra revenue
    if (avgExtraRevenueMinor < 10 && avgDiscountMinor < 10) {
      // low both sides — check customization rate
      if (customizationRate > 70) return ProfileHealthLabel.overCustomized;
      return ProfileHealthLabel.upsellWeak;
    }
    if (customizationRate > 90) return ProfileHealthLabel.overCustomized;
    return ProfileHealthLabel.balanced;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal value objects
// ─────────────────────────────────────────────────────────────────────────────

class _ExtraEntry {
  const _ExtraEntry({
    required this.itemProductId,
    required this.count,
    required this.revenueMinor,
  });

  final int itemProductId;
  final int count;
  final int revenueMinor;
}

class _SwapEntry {
  const _SwapEntry({
    required this.componentKey,
    required this.sourceItemProductId,
    required this.targetItemProductId,
    required this.count,
    required this.freeCount,
    required this.paidCount,
  });

  final String componentKey;
  final int? sourceItemProductId;
  final int targetItemProductId;
  final int count;
  final int freeCount;
  final int paidCount;
}
