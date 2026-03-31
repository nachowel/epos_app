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
    await tester.enterText(find.byType(TextField), '1250');
    await tester.tap(
      find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
    );
    await tester.pumpAndSettle();

    expect(submittedCountedCashMinor, 1250);
    expect(find.byType(CountedCashDialog), findsNothing);
  });

  testWidgets('final close dialog rejects negative counted cash', (
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
    await tester.enterText(find.byType(TextField), '-10');
    await tester.tap(
      find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.countedCashInvalid), findsOneWidget);
    expect(find.byType(CountedCashDialog), findsOneWidget);
  });

  testWidgets(
    'final close dialog rejects non-numeric and extremely large counted cash',
    (WidgetTester tester) async {
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
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.tap(
        find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.countedCashInvalid), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        '999999999999999999999999999999999999',
      );
      await tester.tap(
        find.widgetWithText(ElevatedButton, AppStrings.adminFinalClose),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.countedCashInvalid), findsOneWidget);
      expect(find.byType(CountedCashDialog), findsOneWidget);
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
