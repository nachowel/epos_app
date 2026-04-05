import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderModifier.copyWith', () {
    test('can clear nullable semantic fields explicitly', () {
      const OrderModifier modifier = OrderModifier(
        id: 1,
        uuid: 'modifier-1',
        transactionLineId: 10,
        action: ModifierAction.add,
        itemName: 'Tea',
        extraPriceMinor: 100,
        chargeReason: ModifierChargeReason.extraAdd,
        itemProductId: 20,
        sourceGroupId: 30,
        quantity: 2,
        unitPriceMinor: 100,
        priceEffectMinor: 200,
        sortKey: 5,
      );

      final OrderModifier cleared = modifier.copyWith(
        chargeReason: null,
        itemProductId: null,
        sourceGroupId: null,
      );

      expect(cleared.chargeReason, isNull);
      expect(cleared.itemProductId, isNull);
      expect(cleared.sourceGroupId, isNull);
      expect(cleared.quantity, 2);
      expect(cleared.unitPriceMinor, 100);
      expect(cleared.priceEffectMinor, 200);
      expect(cleared.sortKey, 5);
    });
  });
}
