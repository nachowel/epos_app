import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:epos_app/domain/models/transaction_discount.dart';
import 'package:epos_app/presentation/screens/pos/widgets/checkout_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('preset discount applies immediately', (
    WidgetTester tester,
  ) async {
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
      final EditableText amountField = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const Key('checkout-discount-value-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(amountField.focusNode.hasFocus, isTrue);

      await tester.enterText(
        find.byKey(const Key('checkout-discount-value-field')),
        '1.50',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
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

    await tester.enterText(
      find.byKey(const Key('checkout-discount-value-field')),
      '12',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
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
