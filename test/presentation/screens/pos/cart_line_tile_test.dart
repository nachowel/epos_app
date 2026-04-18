import 'package:epos_app/domain/models/custom_sale.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/presentation/providers/cart_models.dart';
import 'package:epos_app/presentation/screens/pos/widgets/cart_line_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'meal customization cart lines render each pricing explanation on its own line',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: Material(
                child: CartLineTile(
                  item: CartItem(
                    localId: 'cart-1',
                    productId: 1,
                    productName: 'Plain Omelette',
                    unitPriceMinor: 600,
                    hasModifiers: false,
                    quantity: 1,
                    modifiers: const <CartModifier>[],
                    mealCustomizationSelection:
                        const MealCustomizationCartSelection(
                          request: MealCustomizationRequest(productId: 1),
                          snapshot: MealCustomizationResolvedSnapshot(
                            productId: 1,
                            profileId: 10,
                          ),
                          stableIdentityKey: 'stable-key',
                          summaryLines: <String>[
                            'No Beans',
                            'No Chips',
                            'Beans + Chips removed (-£2.00)',
                          ],
                          compactSummary:
                              'No Beans · No Chips · Beans + Chips removed (-£2.00)',
                          perUnitAdjustmentMinor: -200,
                          perUnitLineTotalMinor: 400,
                        ),
                  ),
                  onIncrease: _noop,
                  onDecrease: _noop,
                  onDelete: _noop,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Beans · No Chips'), findsOneWidget);
      expect(find.text('Beans + Chips removed'), findsOneWidget);
      expect(
        find.text('No Beans · No Chips · Beans + Chips removed (-£2.00)'),
        findsNothing,
      );
    },
  );

  testWidgets('meal customization display name overrides base product title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Material(
              child: CartLineTile(
                item: CartItem(
                  localId: 'cart-2',
                  productId: 2,
                  productName: 'Egg',
                  unitPriceMinor: 350,
                  hasModifiers: false,
                  quantity: 1,
                  modifiers: const <CartModifier>[],
                  mealCustomizationSelection:
                      const MealCustomizationCartSelection(
                        request: MealCustomizationRequest(productId: 2),
                        snapshot: MealCustomizationResolvedSnapshot(
                          productId: 2,
                          profileId: 20,
                        ),
                        stableIdentityKey: 'sandwich-key',
                        summaryLines: <String>[
                          'Mayo',
                          'Chilli Sauce',
                          'Toasted',
                        ],
                        compactSummary: 'Mayo · Chilli Sauce · Toasted',
                        displayName: 'Egg Sandwich',
                        perUnitAdjustmentMinor: 100,
                        perUnitLineTotalMinor: 450,
                      ),
                ),
                onIncrease: _noop,
                onDecrease: _noop,
                onDelete: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Egg Sandwich'), findsOneWidget);
    expect(find.text('Egg'), findsNothing);
    expect(find.text('Mayo · Chilli Sauce'), findsOneWidget);
    expect(find.text('Toasted'), findsOneWidget);
  });

  testWidgets('custom sale cart lines render manual label and note', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: Material(
              child: CartLineTile(
                item: const CartItem(
                  localId: 'cart-custom',
                  productId: 0,
                  productName: 'Ignored',
                  unitPriceMinor: 1250,
                  hasModifiers: false,
                  quantity: 1,
                  modifiers: <CartModifier>[],
                  customSaleRequest: CustomSaleWriteRequest(
                    amountMinor: 1250,
                    note: 'Damaged barcode',
                  ),
                ),
                onIncrease: _noop,
                onDecrease: _noop,
                onDelete: _noop,
                onEdit: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('⚠ Custom Sale'), findsOneWidget);
    expect(
      find.text('Manual price item · Note: Damaged barcode'),
      findsOneWidget,
    );
    expect(find.text('Ignored'), findsNothing);
  });
}

void _noop() {}
