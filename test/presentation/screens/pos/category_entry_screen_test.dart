import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/screens/pos/category_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  group('CategoryEntryScreen', () {
    testWidgets(
      'renders first three categories in the featured row and does not repeat them below',
      (WidgetTester tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1440, 1800);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final db = createTestDatabase();
        addTearDown(db.close);

        final List<int> categoryIds = <int>[];
        for (int index = 0; index < 6; index++) {
          final int categoryId = await insertCategory(
            db,
            name: index == 0
                ? 'Very Long Breakfast Category Name That Should Stay Stable'
                : 'Category ${index + 1}',
            sortOrder: index,
          );
          categoryIds.add(categoryId);
          await insertProduct(
            db,
            categoryId: categoryId,
            name: 'Product ${index + 1}',
            priceMinor: 100 + index,
          );
        }

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_routerApp(container));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('category-entry-featured-grid')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('category-entry-remaining-grid')),
          findsOneWidget,
        );

        for (final int categoryId in categoryIds.take(3)) {
          expect(
            find.descendant(
              of: find.byKey(const Key('category-entry-featured-grid')),
              matching: find.byKey(
                ValueKey<String>('category-entry-card-$categoryId'),
              ),
            ),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('category-entry-remaining-grid')),
              matching: find.byKey(
                ValueKey<String>('category-entry-card-$categoryId'),
              ),
            ),
            findsNothing,
          );
        }

        for (final int categoryId in categoryIds.skip(3)) {
          expect(
            find.descendant(
              of: find.byKey(const Key('category-entry-remaining-grid')),
              matching: find.byKey(
                ValueKey<String>('category-entry-card-$categoryId'),
              ),
            ),
            findsOneWidget,
          );
        }

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tapping a category routes to POS with categoryId query param',
      (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        final db = createTestDatabase();
        addTearDown(db.close);

        final int drinksId = await insertCategory(
          db,
          name: 'Drinks',
          sortOrder: 0,
        );
        await insertProduct(
          db,
          categoryId: drinksId,
          name: 'Tea',
          priceMinor: 250,
        );

        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[
            appDatabaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(_routerApp(container));
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(ValueKey<String>('category-entry-card-$drinksId')),
        );
        await tester.pumpAndSettle();

        expect(find.text('POS TARGET $drinksId'), findsOneWidget);
      },
    );

    testWidgets('renders network image when category imageUrl is present', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int bakeryId = await insertCategory(
        db,
        name: 'Bakery',
        imageUrl: ' https://cdn.example.com/categories/bakery.png ',
        sortOrder: 0,
      );
      await insertProduct(
        db,
        categoryId: bakeryId,
        name: 'Croissant',
        priceMinor: 320,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_routerApp(container));
      await tester.pump();

      final Finder imageFinder = find.byKey(
        ValueKey<String>('category-entry-image-$bakeryId'),
      );
      expect(imageFinder, findsOneWidget);

      final Image image = tester.widget<Image>(imageFinder);
      expect((image.image as NetworkImage).url,
          'https://cdn.example.com/categories/bakery.png');
    });

    testWidgets('empty catalog shows a stable empty state', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_routerApp(container));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('category-entry-empty-state')),
        findsOneWidget,
      );
      expect(find.text(AppStrings.noCategories), findsOneWidget);
    });
  });
}

Widget _routerApp(ProviderContainer container) {
  final GoRouter router = GoRouter(
    initialLocation: '/pos/categories',
    routes: <RouteBase>[
      GoRoute(
        path: '/pos/categories',
        builder: (_, __) => const CategoryEntryScreen(),
      ),
      GoRoute(
        path: '/pos',
        builder: (_, GoRouterState state) => Scaffold(
          body: Center(
            child: Text(
              'POS TARGET ${state.uri.queryParameters['categoryId'] ?? 'missing'}',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/orders',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/reports',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/shifts',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/admin',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );

  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      routerConfig: router,
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
