import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/domain/models/custom_sale.dart';
import 'package:epos_app/presentation/screens/pos/widgets/custom_sale_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('price display is keypad-driven and note is hidden by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CustomSaleDialog(onValidateRequest: (_) async {})),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('custom-sale-price-field')),
      findsOneWidget,
    );
    expect(find.text('£0.00'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('custom-sale-keypad-digit-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('custom-sale-note-field')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('custom-sale-show-note-button')),
      findsOneWidget,
    );
    expect(find.text('+ Add note'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('custom-sale-admin-pin-field')),
      findsNothing,
    );
  });

  testWidgets('price preview stays in currency format', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CustomSaleDialog(onValidateRequest: (_) async {})),
      ),
    );

    await _enterPriceThroughKeypad(tester, '7');

    expect(find.text('£7.00'), findsOneWidget);
  });

  testWidgets('primary add action is larger than cancel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CustomSaleDialog(onValidateRequest: (_) async {})),
      ),
    );

    final Size addSize = tester.getSize(
      find.byKey(const ValueKey<String>('custom-sale-submit-button')),
    );
    final Size cancelSize = tester.getSize(
      find.byKey(const ValueKey<String>('custom-sale-cancel-button')),
    );

    expect(addSize.height, greaterThan(cancelSize.height));
  });

  testWidgets(
    'expanded state keeps dialog width stable and lower actions visible',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomSaleDialog(
              customSalesLimitMinor: 1000,
              onValidateRequest: (_) async {},
            ),
          ),
        ),
      );

      final double initialWidth = tester.getSize(find.byType(Dialog)).width;

      await _enterPriceThroughKeypad(tester, '12.50');

      final double expandedWidth = tester.getSize(find.byType(Dialog)).width;
      final Rect addRect = tester.getRect(
        find.byKey(const ValueKey<String>('custom-sale-submit-button')),
      );
      final Rect cancelRect = tester.getRect(
        find.byKey(const ValueKey<String>('custom-sale-cancel-button')),
      );

      expect(expandedWidth, closeTo(initialWidth, 0.1));
      expect(addRect.bottom, lessThanOrEqualTo(600));
      expect(cancelRect.bottom, lessThanOrEqualTo(600));
    },
  );

  testWidgets(
    'tight height keeps keypad, add, and cancel within the dialog without overflow',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1280, 620);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomSaleDialog(
              customSalesLimitMinor: 1000,
              onValidateRequest: (_) async {},
            ),
          ),
        ),
      );

      await _enterPriceThroughKeypad(tester, '12.50');
      await tester.pumpAndSettle();

      final Rect dialogRect = tester.getRect(find.byType(Dialog));
      final Rect addRect = tester.getRect(
        find.byKey(const ValueKey<String>('custom-sale-submit-button')),
      );
      final Rect cancelRect = tester.getRect(
        find.byKey(const ValueKey<String>('custom-sale-cancel-button')),
      );

      expect(addRect.bottom, lessThanOrEqualTo(dialogRect.bottom));
      expect(cancelRect.bottom, lessThanOrEqualTo(dialogRect.bottom));
      expect(
        find.byKey(const ValueKey<String>('custom-sale-keypad-digit-0')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'over-limit amount reveals note and admin pin together before submit',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomSaleDialog(
              customSalesLimitMinor: 1000,
              onValidateRequest: (_) async {},
            ),
          ),
        ),
      );

      await _enterPriceThroughKeypad(tester, '12.50');

      expect(
        find.byKey(const ValueKey<String>('custom-sale-note-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('custom-sale-admin-pin-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('custom-sale-show-note-button')),
        findsNothing,
      );
    },
  );

  testWidgets('domain note-required error expands note field inline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSaleDialog(
            onValidateRequest: (_) async {
              throw const ValidationException(
                'Custom Sale note is required when amount exceeds the configured limit.',
              );
            },
          ),
        ),
      ),
    );

    await _enterPriceThroughKeypad(tester, '12.50');
    await tester.tap(
      find.byKey(const ValueKey<String>('custom-sale-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('custom-sale-note-field')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Custom Sale note is required when amount exceeds the configured limit.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('domain admin-approval error expands admin pin field inline', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSaleDialog(
            onValidateRequest: (_) async {
              throw const ValidationException(
                'Custom Sale admin PIN approval is required when amount exceeds the configured limit.',
              );
            },
          ),
        ),
      ),
    );

    await _enterPriceThroughKeypad(tester, '12.50');
    await tester.tap(
      find.byKey(const ValueKey<String>('custom-sale-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('custom-sale-note-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('custom-sale-admin-pin-field')),
      findsOneWidget,
    );
  });

  testWidgets('submits existing custom sale request through validator', (
    WidgetTester tester,
  ) async {
    CustomSaleWriteRequest? capturedRequest;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSaleDialog(
            initialRequest: const CustomSaleWriteRequest(
              amountMinor: 1250,
              note: 'Damaged barcode',
            ),
            onValidateRequest: (CustomSaleWriteRequest request) async {
              capturedRequest = request;
            },
          ),
        ),
      ),
    );

    await _enterPriceThroughKeypad(tester, '13.50');
    await tester.tap(
      find.byKey(const ValueKey<String>('custom-sale-submit-button')),
    );
    await tester.pump();

    expect(capturedRequest?.amountMinor, 1350);
    expect(capturedRequest?.note, 'Damaged barcode');
  });

  testWidgets('zero value keeps existing custom sale business validation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomSaleDialog(
            onValidateRequest: (CustomSaleWriteRequest request) async {
              if (request.amountMinor <= 0) {
                throw const ValidationException(
                  'Custom Sale amount must be greater than zero.',
                );
              }
            },
          ),
        ),
      ),
    );

    await _enterPriceThroughKeypad(tester, '0');
    await tester.tap(
      find.byKey(const ValueKey<String>('custom-sale-submit-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Custom Sale amount must be greater than zero.'),
      findsOneWidget,
    );
  });
}

Future<void> _enterPriceThroughKeypad(WidgetTester tester, String value) async {
  for (final String character in value.split('')) {
    final Key key = character == '.'
        ? const ValueKey<String>('custom-sale-keypad-decimal')
        : ValueKey<String>('custom-sale-keypad-digit-$character');
    await tester.tap(find.byKey(key));
    await tester.pump();
  }
}
