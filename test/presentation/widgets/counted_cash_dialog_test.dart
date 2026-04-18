import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/widgets/counted_cash_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppLocalizationService.instance.setLocale(const Locale('en'));
  });

  testWidgets('final close dialog requires counted cash before submit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () {
                showDialog<int>(
                  context: context,
                  builder: (_) =>
                      const CountedCashDialog(expectedCashMinor: 1200),
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
    await tester.tap(
      find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.countedCashRequired), findsOneWidget);
    expect(find.byType(CountedCashDialog), findsOneWidget);
  });

  testWidgets('final close dialog returns entered counted cash', (
    WidgetTester tester,
  ) async {
    int? submittedCountedCashMinor;

    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                submittedCountedCashMinor = await showDialog<int>(
                  context: context,
                  builder: (_) =>
                      const CountedCashDialog(expectedCashMinor: 1200),
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
    final TextField field = tester.widget<TextField>(find.byType(TextField));
    expect(field.readOnly, isTrue);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await _enterKeypadValue(tester, '12.5');
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
    );
    await tester.pumpAndSettle();

    expect(submittedCountedCashMinor, 1250);
    expect(find.byType(CountedCashDialog), findsNothing);
  });

  testWidgets('final close dialog accepts zero counted cash', (
    WidgetTester tester,
  ) async {
    int? submittedCountedCashMinor;

    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () async {
                submittedCountedCashMinor = await showDialog<int>(
                  context: context,
                  builder: (_) =>
                      const CountedCashDialog(expectedCashMinor: 1200),
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
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-digit-0')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
    );
    await tester.pumpAndSettle();

    expect(submittedCountedCashMinor, 0);
    expect(find.byType(CountedCashDialog), findsNothing);
  });

  testWidgets('counted cash keypad cancel keeps dialog open', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        child: Builder(
          builder: (BuildContext context) {
            return ElevatedButton(
              onPressed: () {
                showDialog<int>(
                  context: context,
                  builder: (_) =>
                      const CountedCashDialog(expectedCashMinor: 1200),
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
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-cancel')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CountedCashDialog), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
      findsOneWidget,
    );
  });
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
