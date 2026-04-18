import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/screens/admin/admin_cash_movements_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets('amount field uses shared keypad and records manual movement', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
    await insertShift(db, openedBy: adminId);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.notifier).loadUserById(adminId);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    final TextField amountField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('admin-cash-movement-amount-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(amountField.readOnly, isTrue);

    await tester.enterText(
      find.byKey(const Key('admin-cash-movement-category-field')),
      'Safe Drop',
    );

    await tester.tap(find.byKey(const Key('admin-cash-movement-amount-field')));
    await tester.pumpAndSettle();
    await _enterKeypadValue(tester, '12.5');
    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('app-numeric-keypad-apply')),
    );
    await tester.pumpAndSettle();

    expect(
      _fieldText(
        tester,
        find.byKey(const Key('admin-cash-movement-amount-field')),
      ),
      '12.50',
    );

    await tester.ensureVisible(find.text('Record Movement'));
    await tester.tap(find.text('Record Movement'));
    await tester.pumpAndSettle();

    expect(find.text('Manual cash movement recorded.'), findsOneWidget);
    expect(find.text('Safe Drop'), findsOneWidget);
    expect(find.text('£12.50'), findsOneWidget);
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

String _fieldText(WidgetTester tester, Finder fieldFinder) {
  final EditableText editableText = tester.widget<EditableText>(
    find.descendant(of: fieldFinder, matching: find.byType(EditableText)),
  );
  return editableText.controller.text;
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: const AdminCashMovementsScreen(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}
