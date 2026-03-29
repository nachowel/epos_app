import 'package:drift/drift.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/data/repositories/settings_repository.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/domain/models/report_settings_policy.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/settings_provider.dart';
import 'package:epos_app/presentation/screens/admin/admin_report_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  group('AdminReportSettingsScreen', () {
    testWidgets(
      'cap amount field shows editable currency value instead of raw minor units',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        await SettingsRepository(db).updateReportSettingsPolicy(
          const ReportSettingsPolicy(
            cashierReportMode: CashierReportMode.capAmount,
            visibilityRatio: 1.0,
            maxVisibleTotalMinor: 1250,
          ),
          userId: adminId,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(adminId);
        await container.read(settingsNotifierProvider.notifier).load();

        await tester.pumpWidget(_adminSettingsApp(container));
        await tester.pumpAndSettle();

        expect(find.byType(AdminReportSettingsScreen), findsOneWidget);
        expect(find.widgetWithText(TextField, '12.50'), findsOneWidget);
        expect(find.text('1250'), findsNothing);
      },
    );

    testWidgets(
      'projection preview normalizes Turkish category names to English',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final AppDatabase db = createTestDatabase();
        addTearDown(db.close);

        final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
        final int shiftId = await insertShift(db, openedBy: adminId);
        final int breakfastId = await insertCategory(db, name: 'Kahvaltı');
        final int mainCoursesId = await insertCategory(
          db,
          name: 'Ana Yemekler',
        );
        final int simitId = await insertProduct(
          db,
          categoryId: breakfastId,
          name: 'Simit',
          priceMinor: 650,
        );
        final int kofteId = await insertProduct(
          db,
          categoryId: mainCoursesId,
          name: 'Kofte',
          priceMinor: 1350,
        );
        final int breakfastOrderId = await insertTransaction(
          db,
          uuid: 'admin-settings-breakfast-paid',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 650,
          paidAt: DateTime(2026, 3, 28, 9, 0),
        );
        final int mainsOrderId = await insertTransaction(
          db,
          uuid: 'admin-settings-mains-paid',
          shiftId: shiftId,
          userId: adminId,
          status: 'paid',
          totalAmountMinor: 1350,
          paidAt: DateTime(2026, 3, 28, 13, 0),
        );

        await db
            .into(db.transactionLines)
            .insert(
              TransactionLinesCompanion.insert(
                uuid: 'admin-settings-line-breakfast',
                transactionId: breakfastOrderId,
                productId: simitId,
                productName: 'Simit',
                unitPriceMinor: 650,
                lineTotalMinor: 650,
              ),
            );
        await db
            .into(db.transactionLines)
            .insert(
              TransactionLinesCompanion.insert(
                uuid: 'admin-settings-line-main',
                transactionId: mainsOrderId,
                productId: kofteId,
                productName: 'Kofte',
                unitPriceMinor: 1350,
                lineTotalMinor: 1350,
              ),
            );
        await insertPayment(
          db,
          uuid: 'admin-settings-payment-breakfast',
          transactionId: breakfastOrderId,
          method: 'cash',
          amountMinor: 650,
          paidAt: DateTime(2026, 3, 28, 9, 0),
        );
        await insertPayment(
          db,
          uuid: 'admin-settings-payment-main',
          transactionId: mainsOrderId,
          method: 'card',
          amountMinor: 1350,
          paidAt: DateTime(2026, 3, 28, 13, 0),
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(authNotifierProvider.notifier)
            .loadUserById(adminId);
        await container.read(settingsNotifierProvider.notifier).load();

        final settingsState = container.read(settingsNotifierProvider);
        expect(settingsState.projectionPreview.hasSourceReport, isTrue);
        expect(settingsState.projectionPreview.categoryBreakdown, isNotEmpty);

        await tester.pumpWidget(_adminSettingsApp(container));
        await tester.pumpAndSettle();

        expect(find.byType(AdminReportSettingsScreen), findsOneWidget);
        expect(find.text('Category Breakdown'), findsOneWidget);
        expect(find.text('Breakfast'), findsOneWidget);
        expect(find.text('Main Courses'), findsOneWidget);
        expect(find.text('Kahvaltı'), findsNothing);
        expect(find.text('Ana Yemekler'), findsNothing);
        expect(find.text('£6.50'), findsWidgets);
        expect(find.text('£13.50'), findsWidgets);
      },
    );
  });
}

Widget _adminSettingsApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: const AdminReportSettingsScreen(),
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
