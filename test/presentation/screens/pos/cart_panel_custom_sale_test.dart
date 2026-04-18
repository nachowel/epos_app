import 'package:epos_app/presentation/providers/cart_models.dart';
import 'package:epos_app/presentation/providers/cart_provider.dart';
import 'package:epos_app/presentation/screens/pos/widgets/cart_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'empty cart shows header custom sale action and large empty-state button',
    (WidgetTester tester) async {
      int addTapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 700,
              child: CartPanel(
                cartState: const CartState.initial(),
                panelWidth: 320,
                canCheckout: false,
                isCheckoutLoading: false,
                onAddCustomSale: () {
                  addTapCount += 1;
                },
                onIncreaseQuantity: _noopString,
                onDecreaseQuantity: _noopString,
                onRemoveLine: _noopString,
                onEditCustomSale: _noopString,
                onCheckout: _noop,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('cart-custom-sale-header-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('cart-custom-sale-empty-button')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('cart-custom-sale-empty-button')),
      );
      await tester.pump();

      expect(addTapCount, 1);
    },
  );

  testWidgets(
    'filled cart keeps header custom sale action and hides large empty-state button',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 700,
              child: CartPanel(
                cartState: const CartState(
                  items: <CartItem>[
                    CartItem(
                      localId: 'line-1',
                      productId: 1,
                      productName: 'Tea',
                      unitPriceMinor: 250,
                      hasModifiers: false,
                      quantity: 1,
                      modifiers: <CartModifier>[],
                    ),
                  ],
                ),
                panelWidth: 320,
                canCheckout: true,
                isCheckoutLoading: false,
                onAddCustomSale: _noop,
                onIncreaseQuantity: _noopString,
                onDecreaseQuantity: _noopString,
                onRemoveLine: _noopString,
                onEditCustomSale: _noopString,
                onCheckout: _noop,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('cart-custom-sale-header-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('cart-custom-sale-empty-button')),
        findsNothing,
      );
    },
  );
}

void _noop() {}

void _noopString(String _) {}
