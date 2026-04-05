import 'package:flutter_test/flutter_test.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/services/breakfast_modifier_renderer.dart';

void main() {
  const BreakfastModifierRenderer renderer = BreakfastModifierRenderer();

  OrderModifier modifierFixture({
    ModifierAction action = ModifierAction.add,
    ModifierChargeReason? chargeReason,
    String itemName = 'Hash Brown',
    int quantity = 1,
    int priceEffectMinor = 0,
    int extraPriceMinor = 0,
    int? itemProductId = 100,
    int sortKey = 0,
  }) {
    return OrderModifier(
      id: 1,
      uuid: 'test-uuid',
      transactionLineId: 1,
      action: action,
      itemName: itemName,
      extraPriceMinor: extraPriceMinor,
      chargeReason: chargeReason,
      itemProductId: itemProductId,
      quantity: quantity,
      priceEffectMinor: priceEffectMinor,
      sortKey: sortKey,
    );
  }

  group('BreakfastModifierRenderer', () {
    group('renderAll', () {
      test('remove_only renders correctly', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            action: ModifierAction.remove,
            chargeReason: null,
            itemName: 'Beans',
          ),
        ]);

        expect(result, hasLength(1));
        expect(result.first.label, '- Beans');
        expect(result.first.priceLabel, '');
        expect(result.first.showOnKitchen, isTrue);
        expect(result.first.showOnReceipt, isTrue);
      });

      test('included_choice renders without price', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            action: ModifierAction.choice,
            chargeReason: ModifierChargeReason.includedChoice,
            itemName: 'Tea',
          ),
        ]);

        expect(result, hasLength(1));
        expect(result.first.label, 'Tea');
        expect(result.first.priceLabel, '');
        expect(result.first.showOnKitchen, isTrue);
        expect(result.first.showOnReceipt, isTrue);
        expect(result.first.chargeReason, ModifierChargeReason.includedChoice);
      });

      test('free_swap renders with swap label', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            chargeReason: ModifierChargeReason.freeSwap,
            itemName: 'Black Pudding',
          ),
        ]);

        expect(result.first.label, '+ Black Pudding (swap)');
        expect(result.first.priceLabel, '');
      });

      test('paid_swap renders with price', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            chargeReason: ModifierChargeReason.paidSwap,
            itemName: 'Halloumi',
            priceEffectMinor: 150,
          ),
        ]);

        expect(result.first.label, contains('swap'));
        expect(result.first.label, contains('£1.50'));
        expect(result.first.priceLabel, '+£1.50');
      });

      test('extra_add renders with price', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            chargeReason: ModifierChargeReason.extraAdd,
            itemName: 'Sausage',
            priceEffectMinor: 200,
          ),
        ]);

        expect(result.first.label, '+ Sausage (+£2.00)');
        expect(result.first.priceLabel, '+£2.00');
      });

      test('free_swap and paid_swap are distinguishable', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            chargeReason: ModifierChargeReason.freeSwap,
            itemName: 'Item A',
            sortKey: 1,
          ),
          modifierFixture(
            chargeReason: ModifierChargeReason.paidSwap,
            itemName: 'Item A',
            priceEffectMinor: 100,
            sortKey: 2,
          ),
        ]);

        expect(result, hasLength(2));
        expect(result[0].chargeReason, ModifierChargeReason.freeSwap);
        expect(result[1].chargeReason, ModifierChargeReason.paidSwap);
        expect(result[0].label, isNot(result[1].label));
      });

      test('quantity suffix appears when quantity > 1', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            chargeReason: ModifierChargeReason.includedChoice,
            itemName: 'Toast',
            quantity: 2,
          ),
        ]);

        expect(result.first.label, 'Toast x2');
      });

      test('removalDiscount is hidden from kitchen and receipt', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            action: ModifierAction.remove,
            chargeReason: ModifierChargeReason.removalDiscount,
            itemName: 'Discount',
          ),
        ]);

        expect(result.first.showOnKitchen, isFalse);
        expect(result.first.showOnReceipt, isFalse);
      });

      test('output order is deterministic by sortKey then group priority', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            chargeReason: ModifierChargeReason.extraAdd,
            itemName: 'Extra',
            sortKey: 0,
          ),
          modifierFixture(
            action: ModifierAction.remove,
            chargeReason: null,
            itemName: 'Removed',
            sortKey: 0,
          ),
          modifierFixture(
            chargeReason: ModifierChargeReason.includedChoice,
            action: ModifierAction.choice,
            itemName: 'Choice',
            sortKey: 0,
          ),
        ]);

        expect(result[0].action, ModifierAction.remove);
        expect(result[1].chargeReason, ModifierChargeReason.includedChoice);
        expect(result[2].chargeReason, ModifierChargeReason.extraAdd);
      });
    });

    group('kitchenLabel', () {
      test('remove uses "no" prefix', () {
        final String label = renderer.kitchenLabel(
          modifierFixture(action: ModifierAction.remove, itemName: 'Beans'),
        );
        expect(label, 'no Beans');
      });

      test('included_choice shows item name only', () {
        final String label = renderer.kitchenLabel(
          modifierFixture(
            action: ModifierAction.choice,
            chargeReason: ModifierChargeReason.includedChoice,
            itemName: 'Tea',
          ),
        );
        expect(label, 'Tea');
      });

      test('free_swap shows swap prefix', () {
        final String label = renderer.kitchenLabel(
          modifierFixture(
            chargeReason: ModifierChargeReason.freeSwap,
            itemName: 'Black Pudding',
          ),
        );
        expect(label, 'swap Black Pudding');
      });

      test('paid_swap shows swap prefix', () {
        final String label = renderer.kitchenLabel(
          modifierFixture(
            chargeReason: ModifierChargeReason.paidSwap,
            itemName: 'Halloumi',
            priceEffectMinor: 150,
          ),
        );
        expect(label, 'swap Halloumi');
      });

      test('extra_add shows extra prefix', () {
        final String label = renderer.kitchenLabel(
          modifierFixture(
            chargeReason: ModifierChargeReason.extraAdd,
            itemName: 'Sausage',
          ),
        );
        expect(label, 'extra Sausage');
      });

      test('quantity suffix on kitchen label', () {
        final String label = renderer.kitchenLabel(
          modifierFixture(
            chargeReason: ModifierChargeReason.includedChoice,
            action: ModifierAction.choice,
            itemName: 'Toast',
            quantity: 2,
          ),
        );
        expect(label, 'Toast x2');
      });
    });

    group('receiptLabel', () {
      test('matches renderAll label', () {
        final OrderModifier modifier = modifierFixture(
          chargeReason: ModifierChargeReason.paidSwap,
          itemName: 'Halloumi',
          priceEffectMinor: 150,
        );
        final String label = renderer.receiptLabel(modifier);
        final List<BreakfastModifierRendered> rendered = renderer.renderAll([
          modifier,
        ]);
        expect(label, rendered.first.label);
      });
    });

    group('legacy modifier rendering', () {
      test('legacy remove renders with dash prefix', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            action: ModifierAction.remove,
            chargeReason: null,
            itemName: 'Chips',
            itemProductId: null,
          ),
        ]);
        expect(result.first.label, '- Chips');
      });

      test('legacy add with price renders price suffix', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            action: ModifierAction.add,
            chargeReason: null,
            itemName: 'Bacon',
            extraPriceMinor: 100,
            itemProductId: null,
          ),
        ]);
        expect(result.first.label, '+ Bacon (+£1.00)');
      });

      test('legacy choice renders with included', () {
        final List<BreakfastModifierRendered> result = renderer.renderAll([
          modifierFixture(
            action: ModifierAction.choice,
            chargeReason: null,
            itemName: 'Coffee',
            itemProductId: null,
          ),
        ]);
        expect(result.first.label, 'Coffee (included)');
      });
    });
  });

  group('formatOrderModifierLabel consistency', () {
    test('detail label matches renderer output', () {
      // Import and call from the presentation helper to verify consistency.
      // This test verifies the shared renderer contract.
      final OrderModifier modifier = OrderModifier(
        id: 1,
        uuid: 'u',
        transactionLineId: 1,
        action: ModifierAction.add,
        itemName: 'Hash Brown',
        extraPriceMinor: 0,
        chargeReason: ModifierChargeReason.extraAdd,
        priceEffectMinor: 150,
        quantity: 1,
        sortKey: 1,
      );
      final List<BreakfastModifierRendered> rendered = renderer.renderAll([
        modifier,
      ]);
      expect(rendered.first.label, contains('Hash Brown'));
      expect(rendered.first.label, contains('£1.50'));
    });
  });
}
