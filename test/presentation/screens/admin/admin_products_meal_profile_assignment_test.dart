import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/core/router/app_router.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/repositories/meal_adjustment_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

late SharedPreferences _testPrefs;

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _testPrefs = await SharedPreferences.getInstance();
  });

  testWidgets(
    'meal profile assignment shows profile types and sandwich summary',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
      final int categoryId = await insertCategory(db, name: 'Sandwiches');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Egg',
        priceMinor: 300,
      );

      final ProviderContainer container = _makeContainer(db);
      addTearDown(container.dispose);

      final MealAdjustmentProfileRepository repository = container.read(
        mealAdjustmentProfileRepositoryProvider,
      );
      await repository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'Omelette Profile',
          freeSwapLimit: 1,
          isActive: true,
        ),
      );
      await repository.saveProfileDraft(
        const MealAdjustmentProfileDraft(
          name: 'Sandwich Profile',
          kind: MealAdjustmentProfileKind.sandwich,
          freeSwapLimit: 0,
          isActive: true,
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const _TestRouterApp(),
        ),
      );
      await tester.pumpAndSettle();
      await _loginWithPin(tester, '9999');

      container.read(appRouterProvider).go('/admin/products');
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(ValueKey<String>('product-meal-engine-$productId')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('None'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Omelette Profile • STANDARD'), findsWidgets);
      expect(find.text('Sandwich Profile • SANDWICH'), findsWidgets);

      await tester.tap(find.text('Sandwich Profile • SANDWICH').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Sandwich Profile (SANDWICH)\nThis product will use configurable bread surcharges, free multi-select sauces, sandwich-only toast, and paid add-ins.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Roll uses the product price as the base price.'),
        findsOneWidget,
      );
    },
  );
}

ProviderContainer _makeContainer(AppDatabase db) {
  return ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
    ],
  );
}

class _TestRouterApp extends ConsumerWidget {
  const _TestRouterApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(routerConfig: ref.watch(appRouterProvider));
  }
}

Future<void> _loginWithPin(WidgetTester tester, String pin) async {
  await tester.enterText(find.byType(TextField), pin);
  await tester.tap(find.text(AppStrings.loginButton));
  await tester.pumpAndSettle();
}

void _setLargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
