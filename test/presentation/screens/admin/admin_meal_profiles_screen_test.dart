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

  testWidgets('meal profiles screen shows type badges and sandwich filter', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final ProviderContainer container = _makeContainer(db);
    addTearDown(container.dispose);

    final MealAdjustmentProfileRepository repository = container.read(
      mealAdjustmentProfileRepositoryProvider,
    );
    final int standardProfileId = await repository.saveProfileDraft(
      const MealAdjustmentProfileDraft(
        name: 'Omelette Profile',
        freeSwapLimit: 2,
        isActive: true,
      ),
    );
    final int sandwichProfileId = await repository.saveProfileDraft(
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

    container.read(appRouterProvider).go('/admin/meal-profiles');
    await tester.pumpAndSettle();

    expect(find.text('STANDARD'), findsOneWidget);
    expect(find.text('SANDWICH'), findsOneWidget);
    expect(
      find.byKey(ValueKey<String>('meal-profile-card-$standardProfileId')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey<String>('meal-profile-card-$sandwichProfileId')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('meal-profile-filter-sandwich')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey<String>('meal-profile-card-$standardProfileId')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey<String>('meal-profile-card-$sandwichProfileId')),
      findsOneWidget,
    );
  });

  testWidgets('new profile flow requires explicit type selection', (
    WidgetTester tester,
  ) async {
    _setLargeView(tester);
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    await insertUser(db, name: 'Admin', role: 'admin', pin: '9999');
    final ProviderContainer container = _makeContainer(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const _TestRouterApp(),
      ),
    );
    await tester.pumpAndSettle();
    await _loginWithPin(tester, '9999');

    container.read(appRouterProvider).go('/admin/meal-profiles');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('meal-profile-create-btn')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose Profile Type'), findsOneWidget);
    expect(find.text('Standard Meal Profile'), findsOneWidget);
    expect(find.text('Sandwich Profile'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('meal-profile-kind-sandwich')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Sandwich Profile'), findsOneWidget);
    expect(
      find.textContaining(
        'This sandwich profile defines editable bread surcharges, enabled free sauces, sandwich-only toast, and paid add-ins.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('meal-profile-create-swaps')),
      findsNothing,
    );
  });
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
