import '../models/order_modifier.dart';

/// A single analytics entry representing one product under one charge_reason.
///
/// The same product appearing as both `includedChoice` and `extraAdd` produces
/// two separate entries. Identity is (itemProductId, chargeReason).
class BreakfastModifierAnalyticsEntry {
  const BreakfastModifierAnalyticsEntry({
    required this.itemProductId,
    required this.displayName,
    required this.chargeReason,
    required this.totalQuantity,
    required this.totalRevenueMinor,
  });

  final int itemProductId;
  final String displayName;
  final ModifierChargeReason chargeReason;
  final int totalQuantity;
  final int totalRevenueMinor;
}

/// Aggregated breakdown of a breakfast line's modifiers for analytics.
class BreakfastAnalyticsSnapshot {
  const BreakfastAnalyticsSnapshot({
    required this.entries,
    required this.removedItemCount,
    required this.includedChoiceCount,
    required this.freeSwapCount,
    required this.paidSwapCount,
    required this.extraAddCount,
    required this.paidSwapRevenueMinor,
    required this.extraAddRevenueMinor,
  });

  final List<BreakfastModifierAnalyticsEntry> entries;
  final int removedItemCount;
  final int includedChoiceCount;
  final int freeSwapCount;
  final int paidSwapCount;
  final int extraAddCount;
  final int paidSwapRevenueMinor;
  final int extraAddRevenueMinor;
}

/// Extracts analytics-facing data from persisted breakfast modifier snapshots.
///
/// Uses [itemProductId] as the identity key, not display name.
/// Same product under different [chargeReason] produces separate entries.
/// Does not merge [includedChoice] with [extraAdd], or [freeSwap] with [paidSwap].
class BreakfastAnalyticsExtractor {
  const BreakfastAnalyticsExtractor();

  /// Extracts analytics from a list of modifiers belonging to one or more
  /// breakfast lines. Only modifiers with non-null [chargeReason] and
  /// non-null [itemProductId] are included.
  BreakfastAnalyticsSnapshot extract(List<OrderModifier> modifiers) {
    final Map<_AnalyticsKey, _AnalyticsAccumulator> buckets =
        <_AnalyticsKey, _AnalyticsAccumulator>{};

    int removedItemCount = 0;
    int includedChoiceCount = 0;
    int freeSwapCount = 0;
    int paidSwapCount = 0;
    int extraAddCount = 0;
    int paidSwapRevenueMinor = 0;
    int extraAddRevenueMinor = 0;

    for (final OrderModifier modifier in modifiers) {
      // Count removes regardless of chargeReason — remove rows may have
      // chargeReason == null in the persisted snapshot.
      if (modifier.action == ModifierAction.remove &&
          modifier.itemProductId != null) {
        removedItemCount += modifier.quantity;
      }

      if (modifier.itemProductId == null || modifier.chargeReason == null) {
        continue;
      }

      final ModifierChargeReason reason = modifier.chargeReason!;
      final int productId = modifier.itemProductId!;

      switch (reason) {
        case ModifierChargeReason.removalDiscount:
        case ModifierChargeReason.comboDiscount:
          break;
        case ModifierChargeReason.includedChoice:
          includedChoiceCount += modifier.quantity;
        case ModifierChargeReason.freeSwap:
          freeSwapCount += modifier.quantity;
        case ModifierChargeReason.paidSwap:
          paidSwapCount += modifier.quantity;
          paidSwapRevenueMinor += modifier.priceEffectMinor;
        case ModifierChargeReason.extraAdd:
          extraAddCount += modifier.quantity;
          extraAddRevenueMinor += modifier.priceEffectMinor;
      }

      if (reason == ModifierChargeReason.removalDiscount) {
        continue;
      }

      final _AnalyticsKey key = _AnalyticsKey(
        itemProductId: productId,
        chargeReason: reason,
      );
      final _AnalyticsAccumulator accumulator = buckets.putIfAbsent(
        key,
        () => _AnalyticsAccumulator(
          displayName: modifier.itemName,
        ),
      );
      accumulator.totalQuantity += modifier.quantity;
      accumulator.totalRevenueMinor += modifier.priceEffectMinor;
    }

    final List<BreakfastModifierAnalyticsEntry> entries = buckets.entries
        .map(
          (MapEntry<_AnalyticsKey, _AnalyticsAccumulator> entry) =>
              BreakfastModifierAnalyticsEntry(
                itemProductId: entry.key.itemProductId,
                displayName: entry.value.displayName,
                chargeReason: entry.key.chargeReason,
                totalQuantity: entry.value.totalQuantity,
                totalRevenueMinor: entry.value.totalRevenueMinor,
              ),
        )
        .toList(growable: false);

    return BreakfastAnalyticsSnapshot(
      entries: entries,
      removedItemCount: removedItemCount,
      includedChoiceCount: includedChoiceCount,
      freeSwapCount: freeSwapCount,
      paidSwapCount: paidSwapCount,
      extraAddCount: extraAddCount,
      paidSwapRevenueMinor: paidSwapRevenueMinor,
      extraAddRevenueMinor: extraAddRevenueMinor,
    );
  }
}

class _AnalyticsKey {
  const _AnalyticsKey({
    required this.itemProductId,
    required this.chargeReason,
  });

  final int itemProductId;
  final ModifierChargeReason chargeReason;

  @override
  bool operator ==(Object other) {
    return other is _AnalyticsKey &&
        other.itemProductId == itemProductId &&
        other.chargeReason == chargeReason;
  }

  @override
  int get hashCode => Object.hash(itemProductId, chargeReason);
}

class _AnalyticsAccumulator {
  _AnalyticsAccumulator({required this.displayName});

  final String displayName;
  int totalQuantity = 0;
  int totalRevenueMinor = 0;
}
