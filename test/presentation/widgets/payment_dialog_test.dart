import 'dart:async';

import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/screens/pos/widgets/payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppLocalizationService.instance.setLocale(const Locale('en'));
  });

  testWidgets(
    'cash field is read-only, numeric-display only, and prefilled with exact total',
    (WidgetTester tester) async {
      await _pumpPaymentDialog(tester: tester, totalAmountMinor: 2880);

      final TextField field = _receivedAmountField(tester);
      expect(field.readOnly, isTrue);
      expect(field.keyboardType, TextInputType.none);
      expect(field.enableInteractiveSelection, isFalse);
      expect(field.controller!.text, '28.80');
    },
  );

  testWidgets('quick cash presets use rounded cashier-friendly values', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(tester: tester, totalAmountMinor: 2880);

    expect(find.byKey(const ValueKey<String>('quick-cash-exact')), findsOne);
    expect(find.text('£30'), findsOneWidget);
    expect(find.text('£40'), findsOneWidget);
    expect(find.text('£50'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('cash-helper-clear')), findsNothing);
  });

  testWidgets('card mode hides cash entry controls entirely', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(
      tester: tester,
      totalAmountMinor: 1450,
      initialPaymentMethod: PaymentMethod.card,
    );

    expect(_receivedAmountFieldFinder, findsNothing);
    expect(find.byKey(const ValueKey<String>('payment-keypad-1')), findsNothing);
    expect(find.byKey(const ValueKey<String>('quick-cash-exact')), findsNothing);
    expect(find.textContaining('Insufficient by'), findsNothing);
    expect(find.textContaining('${AppStrings.change}:'), findsNothing);
  });

  testWidgets('card mode uses large vertical pay and cancel actions', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(
      tester: tester,
      totalAmountMinor: 2810,
      initialPaymentMethod: PaymentMethod.card,
    );

    final Size paySize = tester.getSize(_payButtonFinder);
    final Size cancelSize = tester.getSize(find.byKey(const ValueKey<String>('payment-cancel')));

    expect(paySize.height, 64);
    expect(cancelSize.height, 56);
    expect(find.byIcon(Icons.credit_card_rounded), findsOneWidget);
  });

  testWidgets('cash keypad and helper actions update amount without text entry', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(tester: tester, totalAmountMinor: 1450);

    await _tapVisibleKey(tester, 'payment-keypad-2');
    await _tapVisibleKey(tester, 'payment-keypad-0');

    expect(_receivedAmountField(tester).controller!.text, '20');
    expect(find.text('Change: £5.50'), findsOneWidget);

    await tester.tap(find.text('£30'));
    await tester.pump();

    expect(_receivedAmountField(tester).controller!.text, '30.00');
    expect(find.text('Change: £15.50'), findsOneWidget);
  });

  testWidgets('insufficient cash state disables pay until enough is entered', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(tester: tester, totalAmountMinor: 1450);

    await _tapVisibleKey(tester, 'payment-keypad-1');
    await _tapVisibleKey(tester, 'payment-keypad-0');

    expect(_receivedAmountField(tester).controller!.text, '10');
    expect(find.text('Insufficient by £4.50'), findsOneWidget);
    expect(_payButton(tester).onPressed, isNull);

    await _tapVisibleText(tester, '£20');

    expect(_receivedAmountField(tester).controller!.text, '20.00');
    expect(find.text('Change: £5.50'), findsOneWidget);
    expect(_payButton(tester).onPressed, isNotNull);
  });

  testWidgets(
    'payment dialog disables pay action during submission to prevent double tap',
    (WidgetTester tester) async {
      final Completer<String?> completer = Completer<String?>();
      int submissionCount = 0;

      await _pumpPaymentDialog(
        tester: tester,
        totalAmountMinor: 500,
        initialPaymentMethod: PaymentMethod.card,
        onSubmit: (_) {
          submissionCount += 1;
          return completer.future;
        },
      );

      final Finder payButtonFinder = _payButtonFinder;
      await tester.tap(payButtonFinder);
      await tester.pump();

      final ElevatedButton payButton = tester.widget<ElevatedButton>(
        payButtonFinder,
      );
      expect(submissionCount, 1);
      expect(payButton.onPressed, isNull);
      expect(
        find.descendant(
          of: payButtonFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      completer.complete(null);
      await tester.pumpAndSettle();

      expect(find.byType(PaymentDialog), findsNothing);
    },
  );
}

Widget _testApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Center(child: child)),
  );
}

Future<void> _pumpPaymentDialog({
  required WidgetTester tester,
  required int totalAmountMinor,
  PaymentMethod initialPaymentMethod = PaymentMethod.cash,
  PaymentSubmitCallback? onSubmit,
}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(900, 1100));
  await tester.pumpWidget(
    _testApp(
      child: Builder(
        builder: (BuildContext context) {
          return ElevatedButton(
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (_) => PaymentDialog(
                  totalAmountMinor: totalAmountMinor,
                  initialPaymentMethod: initialPaymentMethod,
                  onSubmit: onSubmit ?? (_) async => null,
                ),
              );
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

final Finder _receivedAmountFieldFinder = find.byKey(
  const ValueKey<String>('payment-received-amount-field'),
);

TextField _receivedAmountField(WidgetTester tester) =>
    tester.widget<TextField>(_receivedAmountFieldFinder);

final Finder _payButtonFinder = find.byKey(
  const ValueKey<String>('payment-submit'),
);

ElevatedButton _payButton(WidgetTester tester) =>
    tester.widget<ElevatedButton>(_payButtonFinder);

Future<void> _tapVisibleKey(WidgetTester tester, String keyValue) async {
  final Finder finder = find.byKey(ValueKey<String>(keyValue));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _tapVisibleText(WidgetTester tester, String text) async {
  final Finder finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}
