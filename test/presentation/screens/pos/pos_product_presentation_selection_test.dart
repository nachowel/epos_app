import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/pos/pos_product_presentation_policy.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:epos_app/presentation/screens/pos/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets('POS uses visual presentation for curated breakfast-set categories',
      (WidgetTester tester) async {
    final ProviderContainer container = await _buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_localizedTestApp(container));
    await tester.pumpAndSettle();

    final ProductCard card = tester.widget<ProductCard>(find.byType(ProductCard));

    expect(card.presentationMode, ProductCardPresentationMode.visual);
    expect(find.text('Set 1'), findsOneWidget);
  });

  testWidgets(
    'switching category updates product card presentation mode and keeps the real product name',
    (WidgetTester tester) async {
      final ProviderContainer container = await _buildContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(_localizedTestApp(container));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ProductCard>(find.byType(ProductCard)).presentationMode,
        ProductCardPresentationMode.visual,
      );
      expect(find.text('Set 1'), findsOneWidget);

      await tester.tap(find.text('Drinks').first);
      await tester.pumpAndSettle();

      expect(
        tester.widget<ProductCard>(find.byType(ProductCard)).presentationMode,
        ProductCardPresentationMode.compact,
      );
      expect(find.text('Set 1'), findsOneWidget);
    },
  );
}

Future<ProviderContainer> _buildContainer() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final db = createTestDatabase();
  addTearDown(db.close);

  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  final int breakfastCategoryId = await insertCategory(
    db,
    name: 'Breakfast Sets',
    sortOrder: 0,
  );
  final int drinksCategoryId = await insertCategory(
    db,
    name: 'Drinks',
    sortOrder: 1,
  );
  await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set 1',
    priceMinor: 650,
  );
  await insertProduct(
    db,
    categoryId: drinksCategoryId,
    name: 'Set 1',
    priceMinor: 250,
  );
  await insertShift(db, openedBy: cashierId);

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      ordersNotifierProvider.overrideWith(
        (Ref ref) => _StaticOrdersNotifier(ref),
      ),
    ],
  );

  await container.read(authNotifierProvider.notifier).loadUserById(cashierId);
  await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
  return container;
}

class _StaticOrdersNotifier extends OrdersNotifier {
  _StaticOrdersNotifier(super.ref);

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: false, errorMessage: null);
  }
}

Widget _localizedTestApp(
  ProviderContainer container, {
  Locale locale = const Locale('en'),
}) {
  AppLocalizationService.instance.setLocale(locale);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const PosScreen(),
    ),
  );
}
