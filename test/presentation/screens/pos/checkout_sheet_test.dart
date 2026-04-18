import 'package:epos_app/core/constants/app_colors.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_discount.dart';
import 'package:epos_app/presentation/screens/pos/widgets/checkout_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'checkout sheet keeps required controls visible without scroll at 1280x720',
    (WidgetTester tester) async {
      _setCheckoutView(tester, size: const Size(1280, 720));

      await tester.pumpWidget(_buildCheckoutSheet());
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.text(AppStrings.cash), findsOneWidget);
      expect(find.text(AppStrings.card), findsOneWidget);
      expect(
        find.byKey(const Key('checkout-custom-discount-toggle')),
        findsOneWidget,
      );
      expect(find.text('£0.50'), findsOneWidget);
      expect(find.text('£1'), findsOneWidget);
      expect(find.text('£2'), findsOneWidget);
      expect(find.text('£3'), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text(AppStrings.subtotal), findsOneWidget);
      expect(find.byKey(const Key('checkout-pay-button')), findsOneWidget);
      expect(find.text(AppStrings.saveAsOpenOrder), findsOneWidget);
      expect(find.text(AppStrings.clearCart), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opening custom discount editor keeps pay visible without scroll at 1280x720',
    (WidgetTester tester) async {
      _setCheckoutView(tester, size: const Size(1280, 720));

      await tester.pumpWidget(_buildCheckoutSheet());
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('checkout-custom-discount-toggle')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(find.text('Value (£)'), findsOneWidget);
      expect(
        find.byKey(const Key('checkout-discount-reason-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('checkout-discount-apply-button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('checkout-pay-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preset discount applies immediately', (
    WidgetTester tester,
  ) async {
    _setCheckoutView(tester);
    TransactionDiscountInput? appliedDiscount;

    await tester.pumpWidget(
      _buildCheckoutSheet(
        onApplyDiscount: (TransactionDiscountInput discount) {
          appliedDiscount = discount;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('checkout-discount-value-field')),
      findsNothing,
    );
    expect(find.text('£0.50'), findsOneWidget);
    expect(find.text('£1'), findsOneWidget);
    expect(find.text('£2'), findsOneWidget);
    expect(find.text('£3'), findsOneWidget);

    await tester.tap(find.text('£1'));
    await tester.pumpAndSettle();

    expect(appliedDiscount, isNotNull);
    expect(appliedDiscount!.type, TransactionDiscountType.amount);
    expect(appliedDiscount!.valueMinor, 100);
    expect(appliedDiscount!.reason, isNull);
    expect(
      find.byKey(const Key('checkout-applied-discount-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('checkout-applied-discount-label')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('checkout-applied-discount-amount')),
      findsOneWidget,
    );
    expect(find.text('-£1.00'), findsNWidgets(2));
    expect(find.text('${AppStrings.payAction} £9.00'), findsOneWidget);
    expect(find.textContaining('Applied amount discount'), findsNothing);

    expect(
      find.byKey(const ValueKey<String>('checkout-discount-preset-amount-100')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('checkout-discount-preset-amount-50')),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(
        find.byKey(
          const ValueKey<String>('checkout-discount-preset-amount-100'),
        ),
      ),
      isA<FilledButton>(),
    );
    expect(
      tester.widget<OutlinedButton>(
        find.byKey(
          const ValueKey<String>('checkout-discount-preset-amount-50'),
        ),
      ),
      isA<OutlinedButton>(),
    );

    await tester.tap(find.text('£0.50'));
    await tester.pumpAndSettle();

    expect(appliedDiscount!.valueMinor, 50);
    expect(
      find.byKey(const Key('checkout-applied-discount-amount')),
      findsOneWidget,
    );
    expect(find.text('-£0.50'), findsNWidgets(2));
    expect(
      tester.widget<FilledButton>(
        find.byKey(
          const ValueKey<String>('checkout-discount-preset-amount-50'),
        ),
      ),
      isA<FilledButton>(),
    );
    expect(
      tester.widget<OutlinedButton>(
        find.byKey(
          const ValueKey<String>('checkout-discount-preset-amount-100'),
        ),
      ),
      isA<OutlinedButton>(),
    );
  });

  testWidgets(
    'custom amount discount accepts pound input and maps to minor units',
    (WidgetTester tester) async {
      _setCheckoutView(tester);
      TransactionDiscountInput? appliedDiscount;

      await tester.pumpWidget(
        _buildCheckoutSheet(
          onApplyDiscount: (TransactionDiscountInput discount) {
            appliedDiscount = discount;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('checkout-custom-discount-toggle')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Value (£)'), findsOneWidget);
      expect(find.text('Value (pence)'), findsNothing);
      final TextField amountField = tester.widget<TextField>(
        find.byKey(const Key('checkout-discount-value-field')),
      );
      expect(amountField.readOnly, isTrue);

      await tester.tap(find.byKey(const Key('checkout-discount-value-field')));
      await tester.pumpAndSettle();
      await _enterKeypadValue(tester, '1.5');
      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout-discount-apply-button')));
      await tester.pumpAndSettle();

      expect(appliedDiscount, isNotNull);
      expect(appliedDiscount!.type, TransactionDiscountType.amount);
      expect(appliedDiscount!.valueMinor, 150);
      expect(
        find.byKey(const Key('checkout-applied-discount-row')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('checkout-applied-discount-amount')),
        findsOneWidget,
      );
      expect(find.text('-£1.50'), findsNWidgets(2));
      expect(
        find.byKey(const Key('checkout-discount-value-field')),
        findsNothing,
      );
    },
  );

  testWidgets('custom percent discount keeps whole-number percent input', (
    WidgetTester tester,
  ) async {
    _setCheckoutView(tester);
    TransactionDiscountInput? appliedDiscount;

    await tester.pumpWidget(
      _buildCheckoutSheet(
        onApplyDiscount: (TransactionDiscountInput discount) {
          appliedDiscount = discount;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('checkout-custom-discount-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Percent'));
    await tester.pumpAndSettle();

    expect(find.text('Value (%)'), findsOneWidget);
    final TextField percentField = tester.widget<TextField>(
      find.byKey(const Key('checkout-discount-value-field')),
    );
    expect(percentField.readOnly, isTrue);

    await tester.tap(find.byKey(const Key('checkout-discount-value-field')));
    await tester.pumpAndSettle();
    await _enterKeypadValue(tester, '12');
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('checkout-discount-apply-button')));
    await tester.pumpAndSettle();

    expect(appliedDiscount, isNotNull);
    expect(appliedDiscount!.type, TransactionDiscountType.percent);
    expect(appliedDiscount!.valueMinor, 12);
    expect(
      find.byKey(const Key('checkout-applied-discount-row')),
      findsOneWidget,
    );
    expect(find.text('-£1.20'), findsNWidgets(2));
  });

  testWidgets('active discount shows compact row and remove action', (
    WidgetTester tester,
  ) async {
    _setCheckoutView(tester);
    bool removed = false;

    await tester.pumpWidget(
      _buildCheckoutSheet(
        discount: const TransactionDiscountInput(
          type: TransactionDiscountType.amount,
          valueMinor: 200,
        ),
        onRemoveDiscount: () {
          removed = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('checkout-discount-value-field')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('checkout-applied-discount-row')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('checkout-applied-discount-amount')),
      findsOneWidget,
    );
    expect(find.text('-£2.00'), findsNWidgets(2));
    expect(find.textContaining('Applied amount discount'), findsNothing);

    await tester.tap(find.byKey(const Key('checkout-discount-remove-button')));
    await tester.pumpAndSettle();

    expect(removed, isTrue);
    expect(
      find.byKey(const Key('checkout-applied-discount-row')),
      findsNothing,
    );
  });

  testWidgets('checkout header and actions match single-column hierarchy', (
    WidgetTester tester,
  ) async {
    _setCheckoutView(tester, size: const Size(1280, 720));

    await tester.pumpWidget(_buildCheckoutSheet());
    await tester.pumpAndSettle();

    expect(find.text('TOTAL DUE'), findsOneWidget);

    final Size paySize = tester.getSize(
      find.byKey(const Key('checkout-pay-button')),
    );
    final Size openOrderSize = tester.getSize(
      find.byKey(const Key('checkout-open-order-button')),
    );
    expect(paySize.height, greaterThan(openOrderSize.height));

    final double paymentTop = tester
        .getTopLeft(find.text(AppStrings.paymentTitle))
        .dy;
    final double discountTop = tester.getTopLeft(find.text('Discount')).dy;
    final double subtotalTop = tester
        .getTopLeft(find.text(AppStrings.subtotal))
        .dy;
    final double payTop = tester
        .getTopLeft(find.byKey(const Key('checkout-pay-button')))
        .dy;
    final double openOrderTop = tester
        .getTopLeft(find.byKey(const Key('checkout-open-order-button')))
        .dy;
    final double clearTop = tester
        .getTopLeft(find.byKey(const Key('checkout-clear-button')))
        .dy;

    expect(paymentTop, lessThan(discountTop));
    expect(discountTop, lessThan(subtotalTop));
    expect(subtotalTop, lessThan(payTop));
    expect(payTop, lessThan(openOrderTop));
    expect(openOrderTop, lessThan(clearTop));

    final TextButton clearButton = tester.widget<TextButton>(
      find.byKey(const Key('checkout-clear-button')),
    );
    expect(
      clearButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      AppColors.dangerStrong,
    );
    expect(
      clearButton.style?.backgroundColor?.resolve(<WidgetState>{}),
      isNull,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('checkout-clear-button')),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
  });
}

void _setCheckoutView(
  WidgetTester tester, {
  Size size = const Size(1280, 1800),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _enterKeypadValue(WidgetTester tester, String value) async {
  for (final String character in value.split('')) {
    final String key = switch (character) {
      '.' => 'app-numeric-keypad-decimal',
      _ => 'app-numeric-keypad-digit-$character',
    };
    await tester.tap(find.byKey(ValueKey<String>(key)));
    await tester.pump();
  }
}

Widget _buildCheckoutSheet({
  TransactionDiscountInput? discount,
  void Function(TransactionDiscountInput discount)? onApplyDiscount,
  VoidCallback? onRemoveDiscount,
}) {
  return MaterialApp(
    home: Scaffold(
      body: CheckoutSheet(
        cartTotalMinor: 1000,
        subtotalMinor: 1000,
        modifierTotalMinor: 0,
        discount: discount,
        canPayNow: true,
        canCreateOrder: true,
        canClearCart: true,
        canEditDiscount: true,
        isBusy: false,
        onPay: (PaymentMethod method) async => false,
        onCreateOrder: () async => false,
        onClearCart: () async => false,
        onApplyDiscount: onApplyDiscount ?? (_) {},
        onRemoveDiscount: onRemoveDiscount ?? () {},
      ),
    ),
  );
}
