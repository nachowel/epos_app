import 'package:flutter_test/flutter_test.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/services/breakfast_analytics_extractor.dart';

void main() {
  const BreakfastAnalyticsExtractor extractor = BreakfastAnalyticsExtractor();

  OrderModifier modifierFixture({
    ModifierAction action = ModifierAction.add,
    ModifierChargeReason? chargeReason,
    String itemName = 'Item',
    int quantity = 1,
    int priceEffectMinor = 0,
    int? itemProductId = 100,
    int sortKey = 0,
  }) {
    return OrderModifier(
      id: 1,
      uuid: 'test-uuid',
      transactionLineId: 1,
      action: action,
      itemName: itemName,
      extraPriceMinor: 0,
      chargeReason: chargeReason,
      itemProductId: itemProductId,
      quantity: quantity,
      priceEffectMinor: priceEffectMinor,
      sortKey: sortKey,
    );
  }

  group('BreakfastAnalyticsExtractor', () {
    test(
      'same product under different charge_reason produces separate entries',
      () {
        final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
          modifierFixture(
            action: ModifierAction.choice,
            chargeReason: ModifierChargeReason.includedChoice,
            itemName: 'Toast',
            itemProductId: 50,
            quantity: 2,
          ),
          modifierFixture(
            chargeReason: ModifierChargeReason.extraAdd,
            itemName: 'Toast',
            itemProductId: 50,
            quantity: 2,
            priceEffectMinor: 200,
          ),
        ]);

        expect(snapshot.entries, hasLength(2));
        final BreakfastModifierAnalyticsEntry included = snapshot.entries
            .firstWhere(
              (e) => e.chargeReason == ModifierChargeReason.includedChoice,
            );
        final BreakfastModifierAnalyticsEntry extra = snapshot.entries
            .firstWhere((e) => e.chargeReason == ModifierChargeReason.extraAdd);

        expect(included.itemProductId, 50);
        expect(included.totalQuantity, 2);
        expect(included.totalRevenueMinor, 0);

        expect(extra.itemProductId, 50);
        expect(extra.totalQuantity, 2);
        expect(extra.totalRevenueMinor, 200);
      },
    );

    test('item_product_id is preserved', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
        modifierFixture(
          chargeReason: ModifierChargeReason.freeSwap,
          itemProductId: 77,
          itemName: 'Black Pudding',
        ),
      ]);

      expect(snapshot.entries.first.itemProductId, 77);
    });

    test('paid_swap revenue sums correctly', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
        modifierFixture(
          chargeReason: ModifierChargeReason.paidSwap,
          itemProductId: 10,
          priceEffectMinor: 150,
          quantity: 1,
        ),
        modifierFixture(
          chargeReason: ModifierChargeReason.paidSwap,
          itemProductId: 20,
          priceEffectMinor: 200,
          quantity: 1,
        ),
      ]);

      expect(snapshot.paidSwapRevenueMinor, 350);
      expect(snapshot.paidSwapCount, 2);
    });

    test('extra_add revenue sums correctly', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
        modifierFixture(
          chargeReason: ModifierChargeReason.extraAdd,
          itemProductId: 30,
          priceEffectMinor: 100,
          quantity: 2,
        ),
      ]);

      expect(snapshot.extraAddRevenueMinor, 100);
      expect(snapshot.extraAddCount, 2);
    });

    test('does not merge included_choice and extra_add', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
        modifierFixture(
          action: ModifierAction.choice,
          chargeReason: ModifierChargeReason.includedChoice,
          itemProductId: 50,
          quantity: 1,
        ),
        modifierFixture(
          chargeReason: ModifierChargeReason.extraAdd,
          itemProductId: 50,
          quantity: 1,
          priceEffectMinor: 100,
        ),
      ]);

      expect(snapshot.includedChoiceCount, 1);
      expect(snapshot.extraAddCount, 1);
      expect(snapshot.entries, hasLength(2));
    });

    test('does not merge free_swap and paid_swap', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
        modifierFixture(
          chargeReason: ModifierChargeReason.freeSwap,
          itemProductId: 60,
          quantity: 1,
        ),
        modifierFixture(
          chargeReason: ModifierChargeReason.paidSwap,
          itemProductId: 60,
          quantity: 1,
          priceEffectMinor: 150,
        ),
      ]);

      expect(snapshot.freeSwapCount, 1);
      expect(snapshot.paidSwapCount, 1);
      expect(snapshot.entries, hasLength(2));
    });

    test('counts removed items', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
        modifierFixture(
          action: ModifierAction.remove,
          chargeReason: null,
          itemProductId: 40,
          quantity: 2,
        ),
      ]);

      expect(snapshot.removedItemCount, 2);
    });

    test('skips modifiers without item_product_id', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
        modifierFixture(
          chargeReason: ModifierChargeReason.extraAdd,
          itemProductId: null,
          priceEffectMinor: 100,
        ),
      ]);

      expect(snapshot.entries, isEmpty);
    });

    test('skips modifiers without charge_reason', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
        modifierFixture(
          chargeReason: null,
          itemProductId: 100,
          priceEffectMinor: 100,
        ),
      ]);

      expect(snapshot.entries, isEmpty);
    });

    test('removalDiscount entries are excluded from analytics entries', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
        modifierFixture(
          action: ModifierAction.remove,
          chargeReason: ModifierChargeReason.removalDiscount,
          itemProductId: 40,
          quantity: 1,
        ),
      ]);

      expect(snapshot.entries, isEmpty);
    });

    test('empty input produces empty snapshot', () {
      final BreakfastAnalyticsSnapshot snapshot = extractor.extract([]);
      expect(snapshot.entries, isEmpty);
      expect(snapshot.removedItemCount, 0);
      expect(snapshot.paidSwapRevenueMinor, 0);
      expect(snapshot.extraAddRevenueMinor, 0);
    });

    test(
      'same product same charge_reason across multiple modifiers aggregates',
      () {
        final BreakfastAnalyticsSnapshot snapshot = extractor.extract([
          modifierFixture(
            chargeReason: ModifierChargeReason.extraAdd,
            itemProductId: 10,
            priceEffectMinor: 100,
            quantity: 1,
          ),
          modifierFixture(
            chargeReason: ModifierChargeReason.extraAdd,
            itemProductId: 10,
            priceEffectMinor: 100,
            quantity: 2,
          ),
        ]);

        expect(snapshot.entries, hasLength(1));
        expect(snapshot.entries.first.totalQuantity, 3);
        expect(snapshot.entries.first.totalRevenueMinor, 200);
      },
    );
  });
}
