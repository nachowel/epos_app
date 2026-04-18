import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/domain/models/custom_sale.dart';
import 'package:epos_app/presentation/screens/pos/widgets/custom_sale_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('price field is autofocus and note is hidden by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CustomSaleDialog(onValidateRequest: (_) async {})),
      ),
    );

    final TextField priceField = tester.widget(
      find.byKey(const ValueKey<String>('custom-sale-price-field')),
    );

    expect(priceField.autofocus, isTrue);
    expect(
      find.byKey(const ValueKey<String>('custom-sale-note-field')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('custom-sale-show-note-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('custom-sale-admin-pin-field')),
      findsNothing,
    );
  });

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

      await tester.enterText(
        find.byKey(const ValueKey<String>('custom-sale-price-field')),
        '12.50',
      );
      await tester.pump();

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

    await tester.enterText(
      find.byKey(const ValueKey<String>('custom-sale-price-field')),
      '12.50',
    );
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

    await tester.enterText(
      find.byKey(const ValueKey<String>('custom-sale-price-field')),
      '12.50',
    );
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

    await tester.enterText(
      find.byKey(const ValueKey<String>('custom-sale-price-field')),
      '13.50',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('custom-sale-submit-button')),
    );
    await tester.pump();

    expect(capturedRequest?.amountMinor, 1350);
    expect(capturedRequest?.note, 'Damaged barcode');
  });
}
