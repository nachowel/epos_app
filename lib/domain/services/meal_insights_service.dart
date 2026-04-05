import '../models/meal_customization.dart';
import '../models/meal_insights.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/product_repository.dart';

/// Aggregates meal customization snapshot data into operational insights:
/// top swaps, extras, removals, discount patterns, and operational notes.
///
/// Used by:
/// - POS dialog: quick suggestions for common customizations
/// - Admin surface: meal insight summaries per product
///
/// This service reads from persisted snapshot data. It does NOT use LLM or
/// external services — all insights are deterministic aggregations.
///
/// Suggestion results are cached in-memory per productId with a short TTL
/// to avoid repeated DB queries during POS interactions. Cache is
/// invalidated on order finalize, manual refresh, or TTL expiry.
class MealInsightsService {
  MealInsightsService({
    required TransactionRepository transactionRepository,
    required ProductRepository productRepository,
    Duration suggestionCacheTtl = const Duration(minutes: 5),
    int maxCacheSize = 50,
  })  : _transactionRepository = transactionRepository,
        _productRepository = productRepository,
        _suggestionCacheTtl = suggestionCacheTtl,
        _maxCacheSize = maxCacheSize;

  final TransactionRepository _transactionRepository;
  final ProductRepository _productRepository;
  final Duration _suggestionCacheTtl;
  final int _maxCacheSize;

  /// In-memory suggestion cache keyed by productId.
  /// Eviction: oldest-first when size exceeds [_maxCacheSize].
  final Map<int, _SuggestionCacheEntry> _suggestionCache =
      <int, _SuggestionCacheEntry>{};

  /// Tracks in-flight prefetch product IDs to prevent duplicate requests.
  final Set<int> _inflightPrefetchIds = <int>{};

  /// Generates quick suggestions for a product based on historical snapshot data.
  /// Returns top suggestions ordered by usage count descending, capped at [limit].
  ///
  /// Results are served from cache when available and not expired.
  Future<List<MealQuickSuggestion>> loadSuggestionsForProduct({
    required int productId,
    required Map<int, String> productNamesById,
    int limit = 5,
  }) async {
    final _SuggestionCacheEntry? cached = _suggestionCache[productId];
    if (cached != null && !cached.isExpired(_suggestionCacheTtl)) {
      return cached.suggestions.take(limit).toList(growable: false);
    }

    final List<MealQuickSuggestion> suggestions =
        await _loadSuggestionsFromDb(
          productId: productId,
          productNamesById: productNamesById,
        );
    _putCache(productId, suggestions);
    return suggestions.take(limit).toList(growable: false);
  }

  /// Prefetches suggestions for a list of product IDs, warming the cache.
  /// Intended to be called on category switch or POS grid load.
  /// Failures for individual products are swallowed — prefetch is best-effort.
  ///
  /// Hardening (Phase 8):
  /// - Skips products already cached and not expired.
  /// - Skips products with an in-flight prefetch to prevent duplicate DB hits.
  /// - Only prefetches products present in [productNamesById] (visibility-scoped).
  Future<void> prefetchSuggestions({
    required List<int> productIds,
    required Map<int, String> productNamesById,
  }) async {
    for (final int productId in productIds) {
      // Visibility scope: only prefetch products the caller knows about.
      if (!productNamesById.containsKey(productId)) {
        continue;
      }
      final _SuggestionCacheEntry? cached = _suggestionCache[productId];
      if (cached != null && !cached.isExpired(_suggestionCacheTtl)) {
        continue;
      }
      // Inflight dedup: skip if another prefetch for this product is running.
      if (!_inflightPrefetchIds.add(productId)) {
        continue;
      }
      try {
        final List<MealQuickSuggestion> suggestions =
            await _loadSuggestionsFromDb(
              productId: productId,
              productNamesById: productNamesById,
            );
        _putCache(productId, suggestions);
      } catch (_) {
        // Prefetch is best-effort — never block or throw.
      } finally {
        _inflightPrefetchIds.remove(productId);
      }
    }
  }

  /// Invalidates the entire suggestion cache. Call after order finalize
  /// or when significant new data is recorded.
  void invalidateSuggestionCache() {
    _suggestionCache.clear();
  }

  /// Invalidates cached suggestions for a single product.
  void invalidateSuggestionCacheForProduct(int productId) {
    _suggestionCache.remove(productId);
  }

  /// Whether the cache currently holds a valid (non-expired) entry for [productId].
  bool hasCachedSuggestions(int productId) {
    final _SuggestionCacheEntry? cached = _suggestionCache[productId];
    return cached != null && !cached.isExpired(_suggestionCacheTtl);
  }

  /// Current number of entries in the suggestion cache (for monitoring/testing).
  int get currentCacheSize => _suggestionCache.length;

  /// Stores a cache entry and evicts the oldest entries if the cache exceeds
  /// [_maxCacheSize]. Eviction removes the oldest (by cachedAt) entries first.
  void _putCache(int productId, List<MealQuickSuggestion> suggestions) {
    _suggestionCache[productId] = _SuggestionCacheEntry(
      suggestions: suggestions,
      cachedAt: DateTime.now(),
    );
    _evictIfNeeded();
  }

  void _evictIfNeeded() {
    if (_suggestionCache.length <= _maxCacheSize) {
      return;
    }
    // Evict oldest entries first until we're at or under maxCacheSize.
    final List<MapEntry<int, _SuggestionCacheEntry>> entries =
        _suggestionCache.entries.toList(growable: false)
          ..sort(
            (MapEntry<int, _SuggestionCacheEntry> a,
             MapEntry<int, _SuggestionCacheEntry> b) =>
                a.value.cachedAt.compareTo(b.value.cachedAt),
          );
    final int toRemove = _suggestionCache.length - _maxCacheSize;
    for (int i = 0; i < toRemove; i++) {
      _suggestionCache.remove(entries[i].key);
    }
  }

  Future<List<MealQuickSuggestion>> _loadSuggestionsFromDb({
    required int productId,
    required Map<int, String> productNamesById,
  }) async {
    final List<MealCustomizationPersistedSnapshotRecord> snapshots =
        await _transactionRepository.getMealCustomizationSnapshotsByProduct(
          productId,
        );
    if (snapshots.isEmpty) {
      return const <MealQuickSuggestion>[];
    }

    final _SuggestionAccumulator accumulator = _SuggestionAccumulator();
    for (final MealCustomizationPersistedSnapshotRecord record in snapshots) {
      accumulator.accumulateSnapshot(record.snapshot);
    }
    return accumulator.toSuggestions(
      productNamesById: productNamesById,
    );
  }

  /// Generates insights summary for a specific product.
  Future<ProductMealInsights?> loadProductInsights({
    required int productId,
  }) async {
    final product = await _productRepository.getById(productId);
    if (product == null) return null;

    final List<MealCustomizationPersistedSnapshotRecord> snapshots =
        await _transactionRepository.getMealCustomizationSnapshotsByProduct(
          productId,
        );
    final int legacyCount = await _transactionRepository
        .countLegacyMealCustomizationLines(productId);

    if (snapshots.isEmpty && legacyCount == 0) return null;

    final _InsightAccumulator accumulator = _InsightAccumulator();
    for (final MealCustomizationPersistedSnapshotRecord record in snapshots) {
      accumulator.accumulateSnapshot(record.snapshot);
    }

    final Map<int, String> productNames = await _loadProductNamesFromSnapshots(
      snapshots,
    );

    return accumulator.toProductInsights(
      productId: productId,
      productName: product.name,
      legacyLineCount: legacyCount,
      productNamesById: productNames,
    );
  }

  /// Returns legacy meal line counts grouped by product ID.
  /// Lightweight query intended for admin visibility badges.
  Future<Map<int, int>> getLegacyLineCountsByProduct() {
    return _transactionRepository.getLegacyMealCustomizationLineCountsByProduct();
  }

  /// Generates full insights summary across all meal products.
  Future<MealInsightsSummary> loadSummary({
    int lookbackDays = 30,
    int topLimit = 10,
  }) async {
    final List<int> activeProductIds =
        await _transactionRepository.getMealCustomizationActiveProductIds(
          lookbackDays: lookbackDays,
        );

    final _InsightAccumulator globalAccumulator = _InsightAccumulator();
    final List<ProductMealInsights> productInsights = <ProductMealInsights>[];
    final Map<int, String> allProductNames = <int, String>{};

    for (final int productId in activeProductIds) {
      final ProductMealInsights? insights = await loadProductInsights(
        productId: productId,
      );
      if (insights != null) {
        productInsights.add(insights);
      }

      final List<MealCustomizationPersistedSnapshotRecord> snapshots =
          await _transactionRepository.getMealCustomizationSnapshotsByProduct(
            productId,
          );
      for (final MealCustomizationPersistedSnapshotRecord record in snapshots) {
        globalAccumulator.accumulateSnapshot(record.snapshot);
      }
      allProductNames.addAll(
        await _loadProductNamesFromSnapshots(snapshots),
      );
    }

    productInsights.sort(
      (ProductMealInsights a, ProductMealInsights b) =>
          b.customizationCount.compareTo(a.customizationCount),
    );

    return MealInsightsSummary(
      generatedAt: DateTime.now(),
      lookbackDays: lookbackDays,
      topSwaps: globalAccumulator.topSwaps(
        productNamesById: allProductNames,
        limit: topLimit,
      ),
      topExtras: globalAccumulator.topExtras(
        productNamesById: allProductNames,
        limit: topLimit,
      ),
      topRemovals: globalAccumulator.topRemovals(
        productNamesById: allProductNames,
        limit: topLimit,
      ),
      topDiscountPatterns: globalAccumulator.topDiscountPatterns(
        productNamesById: allProductNames,
        limit: topLimit,
      ),
      productsByActivity: productInsights.take(topLimit).toList(growable: false),
    );
  }

  Future<Map<int, String>> _loadProductNamesFromSnapshots(
    List<MealCustomizationPersistedSnapshotRecord> snapshots,
  ) async {
    final Set<int> productIds = <int>{};
    for (final MealCustomizationPersistedSnapshotRecord record in snapshots) {
      for (final MealCustomizationSemanticAction action
          in record.snapshot.actions) {
        if (action.itemProductId != null) productIds.add(action.itemProductId!);
        if (action.sourceItemProductId != null) {
          productIds.add(action.sourceItemProductId!);
        }
      }
      productIds.add(record.productId);
    }
    final Map<int, String> names = <int, String>{};
    for (final int id in productIds) {
      final product = await _productRepository.getById(id);
      if (product != null) names[id] = product.name;
    }
    return names;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestion accumulator — aggregates snapshot actions into quick suggestions
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionAccumulator {
  final Map<String, _SuggestionEntry> _entries = <String, _SuggestionEntry>{};

  void accumulateSnapshot(MealCustomizationResolvedSnapshot snapshot) {
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedComponentActions) {
      switch (action.action) {
        case MealCustomizationAction.remove:
          if (action.componentKey != null) {
            final String key = 'remove:${action.componentKey}';
            _entries.update(
              key,
              (_SuggestionEntry entry) => entry.increment(),
              ifAbsent: () => _SuggestionEntry(
                kind: MealSuggestionActionKind.remove,
                componentKey: action.componentKey,
                itemProductId: action.itemProductId,
              ),
            );
          }
          break;
        case MealCustomizationAction.swap:
          if (action.componentKey != null && action.itemProductId != null) {
            final String key =
                'swap:${action.componentKey}:${action.itemProductId}';
            _entries.update(
              key,
              (_SuggestionEntry entry) => entry.increment(),
              ifAbsent: () => _SuggestionEntry(
                kind: MealSuggestionActionKind.swap,
                componentKey: action.componentKey,
                targetItemProductId: action.itemProductId,
                sourceItemProductId: action.sourceItemProductId,
              ),
            );
          }
          break;
        case MealCustomizationAction.extra:
        case MealCustomizationAction.discount:
          break;
      }
    }
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedExtraActions) {
      if (action.itemProductId != null) {
        final String key = 'extra:${action.itemProductId}';
        _entries.update(
          key,
          (_SuggestionEntry entry) => entry.increment(),
          ifAbsent: () => _SuggestionEntry(
            kind: MealSuggestionActionKind.addExtra,
            itemProductId: action.itemProductId,
          ),
        );
      }
    }
  }

  List<MealQuickSuggestion> toSuggestions({
    required Map<int, String> productNamesById,
    int limit = 5,
  }) {
    final List<_SuggestionEntry> sorted = _entries.values
        .toList(growable: false)
      ..sort((_SuggestionEntry a, _SuggestionEntry b) {
        final int countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) return countCompare;
        return a._labelForSort().compareTo(b._labelForSort());
      });

    return sorted.take(limit).map((_SuggestionEntry entry) {
      return entry.toSuggestion(productNamesById: productNamesById);
    }).toList(growable: false);
  }
}

class _SuggestionEntry {
  _SuggestionEntry({
    required this.kind,
    this.componentKey,
    this.targetItemProductId,
    this.sourceItemProductId,
    this.itemProductId,
  });

  final MealSuggestionActionKind kind;
  final String? componentKey;
  final int? targetItemProductId;
  final int? sourceItemProductId;
  final int? itemProductId;
  int count = 1;

  _SuggestionEntry increment() {
    count += 1;
    return this;
  }

  String _labelForSort() {
    return '${kind.name}:${componentKey ?? ''}:${targetItemProductId ?? ''}:${itemProductId ?? ''}';
  }

  MealQuickSuggestion toSuggestion({
    required Map<int, String> productNamesById,
  }) {
    final String label;
    switch (kind) {
      case MealSuggestionActionKind.remove:
        final String name = _resolveName(itemProductId, productNamesById);
        label = 'No $name';
        break;
      case MealSuggestionActionKind.swap:
        final String source = _resolveName(sourceItemProductId, productNamesById);
        final String target = _resolveName(targetItemProductId, productNamesById);
        label = '$source\u2192$target';
        break;
      case MealSuggestionActionKind.addExtra:
        final String name = _resolveName(itemProductId, productNamesById);
        label = 'Extra $name';
        break;
    }
    return MealQuickSuggestion(
      label: label,
      kind: kind,
      componentKey: componentKey,
      targetItemProductId: targetItemProductId,
      itemProductId: itemProductId,
      usageCount: count,
    );
  }

  String _resolveName(int? productId, Map<int, String> productNamesById) {
    if (productId == null) return 'Unknown';
    return productNamesById[productId] ?? 'Product $productId';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Insight accumulator — aggregates snapshot actions into operational insights
// ─────────────────────────────────────────────────────────────────────────────

class _InsightAccumulator {
  int _customizationCount = 0;
  final Map<String, _InsightEntry> _swaps = <String, _InsightEntry>{};
  final Map<String, _InsightEntry> _extras = <String, _InsightEntry>{};
  final Map<String, _InsightEntry> _removals = <String, _InsightEntry>{};
  final Map<String, _InsightEntry> _discounts = <String, _InsightEntry>{};

  void accumulateSnapshot(MealCustomizationResolvedSnapshot snapshot) {
    _customizationCount += 1;
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedComponentActions) {
      switch (action.action) {
        case MealCustomizationAction.remove:
          if (action.componentKey != null) {
            _removals.update(
              action.componentKey!,
              (_InsightEntry entry) => entry..count += 1,
              ifAbsent: () => _InsightEntry(
                componentKey: action.componentKey,
                itemProductId: action.itemProductId,
              ),
            );
          }
          break;
        case MealCustomizationAction.swap:
          if (action.componentKey != null && action.itemProductId != null) {
            final String key =
                '${action.componentKey}:${action.sourceItemProductId}:${action.itemProductId}';
            _swaps.update(
              key,
              (_InsightEntry entry) => entry..count += 1,
              ifAbsent: () => _InsightEntry(
                componentKey: action.componentKey,
                sourceItemProductId: action.sourceItemProductId,
                targetItemProductId: action.itemProductId,
                chargeReasonLabel: action.chargeReason?.name,
              ),
            );
          }
          break;
        case MealCustomizationAction.extra:
        case MealCustomizationAction.discount:
          break;
      }
    }
    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedExtraActions) {
      if (action.itemProductId != null) {
        final String key = '${action.itemProductId}';
        _extras.update(
          key,
          (_InsightEntry entry) => entry..count += 1,
          ifAbsent: () => _InsightEntry(
            itemProductId: action.itemProductId,
            chargeReasonLabel: action.chargeReason?.name,
          ),
        );
      }
    }
    for (final MealCustomizationSemanticAction action
        in snapshot.triggeredDiscounts) {
      final String key =
          '${action.chargeReason?.name ?? 'discount'}:${action.appliedRuleIds.join(',')}';
      _discounts.update(
        key,
        (_InsightEntry entry) => entry..count += 1,
        ifAbsent: () => _InsightEntry(
          chargeReasonLabel: action.chargeReason?.name ?? 'discount',
          ruleIds: action.appliedRuleIds,
        ),
      );
    }
  }

  List<MealSuggestionStat> topSwaps({
    required Map<int, String> productNamesById,
    int limit = 5,
  }) {
    return _toStats(
      entries: _swaps.values,
      kind: MealSuggestionKind.swap,
      productNamesById: productNamesById,
      limit: limit,
    );
  }

  List<MealSuggestionStat> topExtras({
    required Map<int, String> productNamesById,
    int limit = 5,
  }) {
    return _toStats(
      entries: _extras.values,
      kind: MealSuggestionKind.extra,
      productNamesById: productNamesById,
      limit: limit,
    );
  }

  List<MealSuggestionStat> topRemovals({
    required Map<int, String> productNamesById,
    int limit = 5,
  }) {
    return _toStats(
      entries: _removals.values,
      kind: MealSuggestionKind.remove,
      productNamesById: productNamesById,
      limit: limit,
    );
  }

  List<MealSuggestionStat> topDiscountPatterns({
    required Map<int, String> productNamesById,
    int limit = 5,
  }) {
    return _toStats(
      entries: _discounts.values,
      kind: MealSuggestionKind.discount,
      productNamesById: productNamesById,
      limit: limit,
    );
  }

  ProductMealInsights toProductInsights({
    required int productId,
    required String productName,
    required int legacyLineCount,
    required Map<int, String> productNamesById,
  }) {
    final List<MealSuggestionStat> swaps = topSwaps(
      productNamesById: productNamesById,
    );
    final List<MealSuggestionStat> extras = topExtras(
      productNamesById: productNamesById,
    );
    final List<MealSuggestionStat> removals = topRemovals(
      productNamesById: productNamesById,
    );
    final List<MealSuggestionStat> discounts = topDiscountPatterns(
      productNamesById: productNamesById,
    );

    final List<String> notes = _generateOperationalNotes(
      productName: productName,
      swaps: swaps,
      extras: extras,
      removals: removals,
      legacyLineCount: legacyLineCount,
    );

    return ProductMealInsights(
      productId: productId,
      productName: productName,
      customizationCount: _customizationCount,
      legacyLineCount: legacyLineCount,
      topSwaps: swaps,
      topExtras: extras,
      topRemovals: removals,
      topDiscountPatterns: discounts,
      operationalNotes: notes,
    );
  }

  List<MealSuggestionStat> _toStats({
    required Iterable<_InsightEntry> entries,
    required MealSuggestionKind kind,
    required Map<int, String> productNamesById,
    int limit = 5,
  }) {
    final List<_InsightEntry> sorted = entries.toList(growable: false)
      ..sort((_InsightEntry a, _InsightEntry b) {
        final int countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) return countCompare;
        return (a.componentKey ?? '').compareTo(b.componentKey ?? '');
      });

    return sorted.take(limit).map((_InsightEntry entry) {
      return entry.toStat(kind: kind, productNamesById: productNamesById);
    }).toList(growable: false);
  }

  List<String> _generateOperationalNotes({
    required String productName,
    required List<MealSuggestionStat> swaps,
    required List<MealSuggestionStat> extras,
    required List<MealSuggestionStat> removals,
    required int legacyLineCount,
  }) {
    final List<String> notes = <String>[];
    if (swaps.isNotEmpty) {
      notes.add(
        'Customers often swap ${swaps.first.label} on $productName.',
      );
    }
    if (extras.isNotEmpty) {
      notes.add(
        'Extra ${extras.first.label} is the most common upsell on $productName.',
      );
    }
    if (removals.isNotEmpty) {
      notes.add(
        '${removals.first.label} is the most commonly removed item on $productName.',
      );
    }
    if (legacyLineCount > 0) {
      notes.add(
        '$legacyLineCount legacy meal line(s) exist for $productName without snapshot data.',
      );
    }
    return notes;
  }
}

class _InsightEntry {
  _InsightEntry({
    this.componentKey,
    this.itemProductId,
    this.sourceItemProductId,
    this.targetItemProductId,
    this.chargeReasonLabel,
    this.ruleIds = const <int>[],
  });

  final String? componentKey;
  final int? itemProductId;
  final int? sourceItemProductId;
  final int? targetItemProductId;
  final String? chargeReasonLabel;
  final List<int> ruleIds;
  int count = 1;

  MealSuggestionStat toStat({
    required MealSuggestionKind kind,
    required Map<int, String> productNamesById,
  }) {
    final String label;
    switch (kind) {
      case MealSuggestionKind.remove:
        final String name = _resolveName(itemProductId, productNamesById);
        label = name;
        break;
      case MealSuggestionKind.swap:
        final String source =
            _resolveName(sourceItemProductId, productNamesById);
        final String target =
            _resolveName(targetItemProductId, productNamesById);
        label = '$source\u2192$target';
        break;
      case MealSuggestionKind.extra:
        final String name = _resolveName(itemProductId, productNamesById);
        label = name;
        break;
      case MealSuggestionKind.discount:
        label = chargeReasonLabel ?? 'discount';
        break;
    }
    return MealSuggestionStat(
      kind: kind,
      productId: itemProductId ?? sourceItemProductId ?? 0,
      productName: _resolveName(
        itemProductId ?? sourceItemProductId,
        productNamesById,
      ),
      label: label,
      usageCount: count,
      componentKey: componentKey,
      itemProductId: itemProductId,
      sourceItemProductId: sourceItemProductId,
      targetItemProductId: targetItemProductId,
      chargeReasonLabel: chargeReasonLabel,
    );
  }

  String _resolveName(int? productId, Map<int, String> productNamesById) {
    if (productId == null) return 'Unknown';
    return productNamesById[productId] ?? 'Product $productId';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggestion cache entry
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionCacheEntry {
  _SuggestionCacheEntry({
    required this.suggestions,
    required this.cachedAt,
  });

  final List<MealQuickSuggestion> suggestions;
  final DateTime cachedAt;

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}
