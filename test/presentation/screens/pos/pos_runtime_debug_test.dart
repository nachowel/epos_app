import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:epos_app/presentation/screens/pos/widgets/cart_panel.dart';
import 'package:epos_app/presentation/screens/pos/widgets/category_bar.dart';
import 'package:epos_app/presentation/screens/pos/widgets/product_card.dart';
import 'package:epos_app/presentation/screens/pos/widgets/product_grid.dart';
import 'package:epos_app/presentation/widgets/section_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets(
    'POS runtime renders the live widget chain with dense product cards',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1600, 900));

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int categoryId = await insertCategory(db, name: 'Breakfast');
      for (int i = 0; i < 12; i++) {
        await insertProduct(
          db,
          categoryId: categoryId,
          name: 'Product $i',
          priceMinor: 300 + (i * 50),
          hasModifiers: i.isEven,
        );
      }
      await insertShift(db, openedBy: adminId);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith(
            (Ref ref) => _StaticOrdersNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_localizedTestApp(container));
      await tester.pumpAndSettle();

      expect(find.byType(PosScreen), findsOneWidget);
      expect(find.byType(SectionAppBar), findsOneWidget);
      expect(find.byType(CategoryBar), findsOneWidget);
      expect(find.byType(ProductGrid), findsOneWidget);
      expect(find.byType(ProductCard), findsWidgets);
      expect(find.byType(CartPanel), findsOneWidget);

      final Finder firstCardFinder = find.byType(ProductCard).first;
      final Size firstCardSize = tester.getSize(firstCardFinder);
      final Offset firstCardOffset = tester.getTopLeft(firstCardFinder);
      final Iterable<Element> cardElements = find
          .byType(ProductCard)
          .evaluate();
      final List<Offset> cardOffsets = cardElements
          .map(
            (Element element) =>
                (element.renderObject! as RenderBox).localToGlobal(Offset.zero),
          )
          .toList(growable: false);
      final int firstRowY = cardOffsets
          .map((Offset offset) => offset.dy.round())
          .reduce((int a, int b) => a < b ? a : b);
      final int firstRowCount = cardOffsets
          .where((Offset offset) => (offset.dy.round() - firstRowY).abs() <= 2)
          .length;
      final Set<int> rowStarts = cardOffsets
          .map((Offset offset) => offset.dy.round())
          .toSet();

      expect(firstCardSize.width, greaterThanOrEqualTo(140));
      expect(firstCardSize.height, lessThan(260));
      expect(firstCardOffset.dx, greaterThan(0));
      expect(firstRowCount, 6);
      expect(rowStarts.length, greaterThanOrEqualTo(2));
    },
  );

  testWidgets('POS cart panel narrows proportionally on medium-width layouts', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final db = createTestDatabase();
    addTearDown(db.close);

    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1200, 900));

    final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
    final int cashierId = await insertUser(
      db,
      name: 'Cashier',
      role: 'cashier',
    );
    final int categoryId = await insertCategory(db, name: 'Breakfast');
    for (int i = 0; i < 10; i++) {
      await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Product $i',
        priceMinor: 300 + (i * 50),
        hasModifiers: i.isEven,
      );
    }
    await insertShift(db, openedBy: adminId);

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ordersNotifierProvider.overrideWith(
          (Ref ref) => _StaticOrdersNotifier(ref),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.notifier).loadUserById(cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_localizedTestApp(container));
    await tester.pumpAndSettle();

    final Size cartPanelSize = tester.getSize(find.byType(CartPanel));
    final Size firstCardSize = tester.getSize(find.byType(ProductCard).first);

    expect(cartPanelSize.width, greaterThanOrEqualTo(264));
    expect(cartPanelSize.width, lessThan(320));
    expect(firstCardSize.width, greaterThanOrEqualTo(150));
    expect(firstCardSize.height, lessThan(260));
  });
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
