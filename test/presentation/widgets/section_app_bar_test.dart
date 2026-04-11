import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/user.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/widgets/section_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const List<String> cashierNavLabels = <String>[
    'Dashboard',
    'Categories',
    'POS',
    'Open Orders',
    'Reports',
    'Shift Management',
  ];
  final User cashier = User(
    id: 1,
    name: 'Cashier',
    pin: '1234',
    password: null,
    role: UserRole.cashier,
    isActive: true,
    createdAt: DateTime(2024),
  );
  final Shift openShift = Shift(
    id: 5,
    openedBy: 1,
    openedAt: DateTime(2024, 1, 1),
    closedBy: null,
    closedAt: null,
    cashierPreviewedBy: null,
    cashierPreviewedAt: null,
    status: ShiftStatus.open,
  );

  test('wide widths stay inline before any collapse', () {
    expect(
      SectionAppBar.debugNavigationStage(
        viewportWidth: 1800,
        compactVisual: false,
        navLabels: cashierNavLabels,
        logoutLabel: 'Logout',
      ),
      'wide',
    );
  });

  test('medium widths use the compact inline navigation stage', () {
    expect(
      SectionAppBar.debugNavigationStage(
        viewportWidth: 1120,
        compactVisual: false,
        navLabels: cashierNavLabels,
        logoutLabel: 'Logout',
      ),
      'compact',
    );
    expect(
      SectionAppBar.debugNavigationStage(
        viewportWidth: 1080,
        compactVisual: true,
        navLabels: cashierNavLabels,
        logoutLabel: 'Logout',
      ),
      'compact',
    );
  });

  testWidgets('narrow layouts collapse into the structured navigation sheet', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(760, 900));

    await tester.pumpWidget(
      _buildTestApp(
        child: Scaffold(
          appBar: SectionAppBar(
            title: 'POS',
            currentRoute: '/pos',
            currentUser: cashier,
            currentShift: openShift,
            onLogout: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('section_app_bar_nav_menu_button')),
      findsOneWidget,
    );
    expect(find.text('EPOS'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('section_app_bar_nav_menu_button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('section_app_bar_nav_menu_sheet')),
      findsOneWidget,
    );
    expect(find.text('Navigation'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('section_app_bar_menu_nav_/dashboard')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('section_app_bar_menu_nav_/pos/categories'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('section_app_bar_menu_nav_/orders')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('section_app_bar_menu_nav_/shifts')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('section_app_bar_menu_logout')),
      findsOneWidget,
    );
  });
}

Widget _buildTestApp({required Widget child}) {
  const Locale locale = Locale('en');
  AppLocalizationService.instance.setLocale(locale);

  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}
