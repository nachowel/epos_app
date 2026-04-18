import 'package:epos_app/core/utils/currency_formatter.dart';
import 'package:epos_app/presentation/widgets/app_numeric_keypad_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currency-mode normalization handles common edge cases safely', () {
    const AppNumericValueOptions currencyOptions = AppNumericValueOptions(
      currencyMode: true,
    );

    expect(
      AppNumericInputLogic.normalizeForApply('.5', currencyOptions),
      '0.50',
    );
    expect(
      AppNumericInputLogic.normalizeForApply('0012.3', currencyOptions),
      '12.30',
    );
    expect(
      AppNumericInputLogic.normalizeForApply('12.', currencyOptions),
      '12.00',
    );
    expect(
      AppNumericInputLogic.normalizeForApply('1..2', currencyOptions),
      isNull,
    );
  });

  test('decimal max-length counts digits and not the separator', () {
    const AppNumericValueOptions decimalOptions = AppNumericValueOptions(
      allowDecimal: true,
      maxLength: 4,
      maxDecimalDigits: 2,
    );

    expect(
      AppNumericInputLogic.normalizeForApply('12.34', decimalOptions),
      '12.34',
    );
    expect(
      AppNumericInputLogic.normalizeForApply('12.345', decimalOptions),
      '12.34',
    );
    expect(
      AppNumericInputLogic.normalizeForApply('123.4', decimalOptions),
      '123.4',
    );
  });

  test('signed currency normalization round-trips deterministically', () {
    const AppNumericValueOptions signedCurrencyOptions = AppNumericValueOptions(
      currencyMode: true,
      allowNegative: true,
    );

    expect(
      AppNumericInputLogic.normalizeForApply('-001.2', signedCurrencyOptions),
      '-1.20',
    );
    expect(
      CurrencyFormatter.tryParseSignedEditableMajorInput(
        AppNumericInputLogic.normalizeForApply(
              '-1.20',
              signedCurrencyOptions,
            ) ??
            '',
      ),
      -120,
    );
  });

  testWidgets(
    'currency mode normalizes preview and prevents duplicate decimals',
    (WidgetTester tester) async {
      int? submittedMinor;

      await tester.pumpWidget(
        _testApp(
          child: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () async {
                  submittedMinor =
                      await AppNumericKeypadDialog.showCurrencyMinor(
                        context,
                        title: 'Enter price',
                        previewLabel: 'Price',
                        prefixText: '£ ',
                        emptyPreview: '0.00',
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

      await _tapKey(tester, 'app-numeric-keypad-digit-1');
      await _tapKey(tester, 'app-numeric-keypad-decimal');
      await _tapKey(tester, 'app-numeric-keypad-decimal');
      await _tapKey(tester, 'app-numeric-keypad-digit-2');
      await _tapKey(tester, 'app-numeric-keypad-digit-3');
      await _tapKey(tester, 'app-numeric-keypad-digit-4');

      expect(find.text('£ 1.23'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
      );
      await tester.pumpAndSettle();

      expect(submittedMinor, 123);
    },
  );

  testWidgets('empty value is blocked unless allowEmpty is enabled', (
    WidgetTester tester,
  ) async {
    String? submittedValue = 'sentinel';

    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return Column(
              children: <Widget>[
                ElevatedButton(
                  onPressed: () async {
                    submittedValue =
                        await AppNumericKeypadDialog.showNormalizedText(
                          context,
                        );
                  },
                  child: const Text('strict'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    submittedValue =
                        await AppNumericKeypadDialog.showNormalizedText(
                          context,
                          allowEmpty: true,
                        );
                  },
                  child: const Text('allow-empty'),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('strict'));
    await tester.pumpAndSettle();
    expect(_applyButton(tester).onPressed, isNull);
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-cancel')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('allow-empty'));
    await tester.pumpAndSettle();
    expect(_applyButton(tester).onPressed, isNotNull);
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.pumpAndSettle();

    expect(submittedValue, '');
  });

  testWidgets('integer mode respects maxLength and preset values', (
    WidgetTester tester,
  ) async {
    String? submittedValue;

    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                submittedValue =
                    await AppNumericKeypadDialog.showNormalizedText(
                      context,
                      allowDecimal: false,
                      maxLength: 3,
                      presets: const <AppNumericKeypadPreset>[
                        AppNumericKeypadPreset(label: '250', value: '250'),
                      ],
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

    final ElevatedButton decimalButton = tester.widget<ElevatedButton>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('app-numeric-keypad-decimal')),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(decimalButton.onPressed, isNull);

    await tester.tap(find.text('250'));
    await tester.pump();
    expect(find.text('250'), findsNWidgets(2));

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.pumpAndSettle();
    expect(submittedValue, '250');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _tapKey(tester, 'app-numeric-keypad-digit-1');
    await _tapKey(tester, 'app-numeric-keypad-digit-2');
    await _tapKey(tester, 'app-numeric-keypad-digit-3');
    await _tapKey(tester, 'app-numeric-keypad-digit-4');

    expect(find.text('123'), findsOneWidget);
  });

  testWidgets('preset values replace and the next digit replaces the preset', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () {
                AppNumericKeypadDialog.showNormalizedText(
                  context,
                  presets: const <AppNumericKeypadPreset>[
                    AppNumericKeypadPreset(label: '250', value: '250'),
                  ],
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
    await tester.tap(find.text('250'));
    await tester.pump();
    await _tapKey(tester, 'app-numeric-keypad-digit-1');

    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('app-numeric-keypad-preview')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('2501'), findsNothing);
  });

  testWidgets('desktop keyboard supports digits backspace and enter', (
    WidgetTester tester,
  ) async {
    String? submittedValue;

    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                submittedValue =
                    await AppNumericKeypadDialog.showNormalizedText(context);
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(submittedValue, '12');
  });

  testWidgets('normalized text keypad supports signed admin-style entry', (
    WidgetTester tester,
  ) async {
    String? submittedValue;

    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                submittedValue = await AppNumericKeypadDialog.showNormalizedText(
                  context,
                  title: 'Enter delta',
                  previewLabel: 'Delta',
                  prefixText: '£ ',
                  allowNegative: true,
                );
              },
              child: const Text('open-signed'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open-signed'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-toggle-sign')),
    );
    await tester.pump();
    await _tapKey(tester, 'app-numeric-keypad-digit-1');
    await _tapKey(tester, 'app-numeric-keypad-decimal');
    await _tapKey(tester, 'app-numeric-keypad-digit-2');
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.pumpAndSettle();

    expect(submittedValue, '-1.2');
    expect(
      CurrencyFormatter.tryParseSignedEditableMajorInput(submittedValue!),
      -120,
    );

    await tester.tap(find.text('open-signed'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(submittedValue, '-3');
    expect(
      CurrencyFormatter.tryParseSignedEditableMajorInput(submittedValue!),
      -300,
    );
  });

  testWidgets('normalized text keypad can clear and apply an empty value', (
    WidgetTester tester,
  ) async {
    String? submittedValue = 'sentinel';

    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                submittedValue = await AppNumericKeypadDialog.showNormalizedText(
                  context,
                  title: 'Enter optional amount',
                  previewLabel: 'Optional amount',
                  initialValue: '1.25',
                  prefixText: '£ ',
                  allowEmpty: true,
                );
              },
              child: const Text('open-optional'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open-optional'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-clear')),
    );
    await tester.pump();
    expect(_applyButton(tester).onPressed, isNotNull);
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.pumpAndSettle();

    expect(submittedValue, '');
  });

  testWidgets('escape cancels and focus is restored to the provided node', (
    WidgetTester tester,
  ) async {
    final FocusNode restoreFocusNode = FocusNode(debugLabel: 'restore-target');
    addTearDown(restoreFocusNode.dispose);
    String? submittedValue = 'sentinel';

    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return Column(
              children: <Widget>[
                TextField(focusNode: restoreFocusNode),
                ElevatedButton(
                  onPressed: () async {
                    submittedValue =
                        await AppNumericKeypadDialog.showNormalizedText(
                          context,
                          restoreFocusNode: restoreFocusNode,
                        );
                  },
                  child: const Text('open'),
                ),
              ],
            );
          },
        ),
      ),
    );

    restoreFocusNode.requestFocus();
    await tester.pump();
    expect(restoreFocusNode.hasPrimaryFocus, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(restoreFocusNode.hasPrimaryFocus, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.pump();

    expect(submittedValue, isNull);
    expect(restoreFocusNode.hasPrimaryFocus, isTrue);
  });

  testWidgets('rapid close and reopen does not break the next dialog session', (
    WidgetTester tester,
  ) async {
    String? submittedValue;

    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                submittedValue =
                    await AppNumericKeypadDialog.showNormalizedText(context);
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(submittedValue, '7');
  });

  testWidgets('disposed restore focus node is ignored safely', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(child: const _DisposedFocusHarness()));

    await tester.tap(find.byKey(const ValueKey<String>('disposed-focus-open')));
    await tester.pumpAndSettle();
    final Finder disposeButton = find.byKey(
      const ValueKey<String>('disposed-focus-dispose'),
    );
    await tester.ensureVisible(disposeButton);
    await tester.tap(disposeButton, warnIfMissed: false);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

Widget _testApp({required Widget child}) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

ElevatedButton _applyButton(WidgetTester tester) {
  return tester.widget<ElevatedButton>(
    find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
  );
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey<String>(key)));
  await tester.pump();
}

class _DisposedFocusHarness extends StatefulWidget {
  const _DisposedFocusHarness();

  @override
  State<_DisposedFocusHarness> createState() => _DisposedFocusHarnessState();
}

class _DisposedFocusHarnessState extends State<_DisposedFocusHarness> {
  FocusNode? _restoreFocusNode = FocusNode(
    debugLabel: 'temporary-restore-node',
  );

  @override
  void dispose() {
    _restoreFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_restoreFocusNode != null)
          SizedBox(width: 220, child: TextField(focusNode: _restoreFocusNode)),
        ElevatedButton(
          key: const ValueKey<String>('disposed-focus-open'),
          onPressed: () {
            AppNumericKeypadDialog.showNormalizedText(
              context,
              restoreFocusNode: _restoreFocusNode,
            );
          },
          child: const Text('open'),
        ),
        ElevatedButton(
          key: const ValueKey<String>('disposed-focus-dispose'),
          onPressed: () {
            final FocusNode? node = _restoreFocusNode;
            setState(() {
              _restoreFocusNode = null;
            });
            node?.dispose();
          },
          child: const Text('dispose-focus'),
        ),
      ],
    );
  }
}
