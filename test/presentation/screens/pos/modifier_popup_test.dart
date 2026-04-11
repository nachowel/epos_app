import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/constants/app_colors.dart';
import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart' as app_db;
import 'package:epos_app/data/repositories/category_repository.dart';
import 'package:epos_app/data/repositories/modifier_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/services/catalog_service.dart';
import 'package:epos_app/presentation/providers/cart_models.dart';
import 'package:epos_app/presentation/providers/pos_interaction_provider.dart';
import 'package:epos_app/presentation/screens/pos/widgets/modifier_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_database.dart';

void main() {
  group('ModifierPopup burger fixes', () {
    testWidgets('popup opens with Fried onion and Salad unselected', (
      WidgetTester tester,
    ) async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _StructuredBurgerFixture fixture = await _createStructuredBurger(
        db,
      );

      await _pumpPopup(tester, db: db, productId: fixture.burgerId);

      expect(find.text('FREE ADD-ONS'), findsOneWidget);
      expect(find.text('SAUCES'), findsOneWidget);
      expect(find.text('ADD-INS'), findsOneWidget);
      expect(find.text('Fried onion'), findsOneWidget);
      expect(find.text('Salad'), findsOneWidget);
      expect(find.text('Ketchup'), findsOneWidget);
      expect(find.text('Chips'), findsOneWidget);
      expect(find.text('+£1.10'), findsWidgets);
      expect(
        find.byKey(
          ValueKey<String>('burger-add-in-toggle-${fixture.chipsModifierId}'),
        ),
        findsOneWidget,
      );
      expect(find.text('Selected items'), findsOneWidget);
      expect(find.text('No burger options selected yet.'), findsNothing);
      expect(
        _buttonColor(tester, 'burger-free-add-on-${fixture.friedOnionId}'),
        AppColors.surfaceMuted,
      );
      expect(
        _buttonColor(tester, 'burger-free-add-on-${fixture.saladId}'),
        AppColors.surfaceMuted,
      );
    });

    testWidgets('free add-on button becomes active when pressed', (
      WidgetTester tester,
    ) async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _StructuredBurgerFixture fixture = await _createStructuredBurger(
        db,
      );

      await _pumpPopup(tester, db: db, productId: fixture.burgerId);

      final Finder friedOnionButton = find.byKey(
        ValueKey<String>('burger-free-add-on-${fixture.friedOnionId}'),
      );
      await tester.ensureVisible(friedOnionButton);
      await tester.tap(friedOnionButton);
      await tester.pumpAndSettle();

      expect(
        _buttonColor(tester, 'burger-free-add-on-${fixture.friedOnionId}'),
        AppColors.primaryStrong,
      );
      expect(find.text('Fried onion'), findsWidgets);
    });

    testWidgets('sauce button becomes active when pressed', (
      WidgetTester tester,
    ) async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);
      final _StructuredBurgerFixture fixture = await _createStructuredBurger(
        db,
      );

      await _pumpPopup(tester, db: db, productId: fixture.burgerId);

      final Finder ketchupButton = find.byKey(
        ValueKey<String>('burger-sauce-${fixture.ketchupId}'),
      );
      await tester.ensureVisible(ketchupButton);
      await tester.tap(ketchupButton);
      await tester.pumpAndSettle();

      expect(
        _buttonColor(tester, 'burger-sauce-${fixture.ketchupId}'),
        AppColors.primaryStrong,
      );
      expect(find.text('Ketchup'), findsWidgets);
    });

    testWidgets(
      'paid add-ins toggle on and off and never accumulate above one',
      (WidgetTester tester) async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _StructuredBurgerFixture fixture = await _createStructuredBurger(
          db,
        );

        await _pumpPopup(tester, db: db, productId: fixture.burgerId);

        final Finder toggle = find.byKey(
          ValueKey<String>('burger-add-in-toggle-${fixture.chipsModifierId}'),
        );

        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(find.text('+£1.10'), findsWidgets);
        expect(find.text('Chips £1.10'), findsOneWidget);
        expect(find.text('£2.20'), findsNothing);

        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(find.text('No burger options selected yet.'), findsNothing);
        expect(find.text('Chips £1.10'), findsNothing);
        expect(find.text('£2.20'), findsNothing);
      },
    );

    testWidgets(
      'submitting with no selections returns an empty modifier list',
      (WidgetTester tester) async {
        final app_db.AppDatabase db = createTestDatabase();
        addTearDown(db.close);
        final _StructuredBurgerFixture fixture = await _createStructuredBurger(
          db,
        );
        late Future<List<CartModifier>?> popupResult;

        await tester.pumpWidget(
          _buildTestHarness(
            db: db,
            child: MaterialApp(
              home: Builder(
                builder: (BuildContext context) {
                  return Scaffold(
                    body: Center(
                      child: FilledButton(
                        onPressed: () {
                          popupResult = showDialog<List<CartModifier>>(
                            context: context,
                            builder: (_) => ModifierPopup(
                              productId: fixture.burgerId,
                              productName: 'Burger',
                            ),
                          );
                        },
                        child: const Text('Open'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.addToCart));
        await tester.pumpAndSettle();

        final List<CartModifier>? result = await popupResult;
        expect(result, isNotNull);
        expect(result, isEmpty);
      },
    );

    testWidgets('mixed config products render only structured modifiers', (
      WidgetTester tester,
    ) async {
      final app_db.AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int categoryId = await insertCategory(db, name: 'Mains');
      final int burgerId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Burger',
        priceMinor: 900,
        hasModifiers: true,
      );
      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: burgerId,
              name: 'Lettuce',
              type: 'included',
            ),
          );
      await db
          .into(db.productModifiers)
          .insert(
            app_db.ProductModifiersCompanion.insert(
              productId: burgerId,
              name: 'Cheese',
              type: 'extra',
              extraPriceMinor: const Value<int>(90),
            ),
          );
      await _insertStructuredModifier(
        db,
        productId: burgerId,
        name: 'Ketchup',
        extraPriceMinor: 0,
        priceBehavior: 'free',
        uiSection: 'sauces',
      );
      await _insertStructuredModifier(
        db,
        productId: burgerId,
        name: 'Chips',
        extraPriceMinor: 110,
        priceBehavior: 'paid',
        uiSection: 'add_ins',
      );

      await _pumpPopup(tester, db: db, productId: burgerId);

      expect(find.text('SAUCES'), findsOneWidget);
      expect(find.text('ADD-INS'), findsOneWidget);
      expect(find.text('Ketchup'), findsOneWidget);
      expect(find.text('Chips'), findsOneWidget);
      expect(find.text(AppStrings.includedModifiers), findsNothing);
      expect(find.text(AppStrings.extraModifiers), findsNothing);
      expect(find.text('Lettuce'), findsNothing);
      expect(find.text('Cheese'), findsNothing);
    });
  });
}

Future<void> _pumpPopup(
  WidgetTester tester, {
  required app_db.AppDatabase db,
  required int productId,
}) async {
  await tester.pumpWidget(
    _buildTestHarness(
      db: db,
      child: MaterialApp(
        home: Scaffold(
          body: ModifierPopup(productId: productId, productName: 'Burger'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _buildTestHarness({
  required app_db.AppDatabase db,
  required Widget child,
}) {
  final CatalogService catalogService = CatalogService(
    categoryRepository: CategoryRepository(db),
    productRepository: ProductRepository(db),
    modifierRepository: ModifierRepository(db),
  );

  return ProviderScope(
    overrides: <Override>[
      catalogServiceProvider.overrideWithValue(catalogService),
      posInteractionProvider.overrideWithValue(
        const PosInteractionPolicy(
          effectiveShiftStatus: ShiftStatus.open,
          blockReason: null,
          canInteractWithPos: true,
          canMutateCart: true,
          canOpenModifierDialog: true,
          isSalesLocked: false,
          lockMessage: null,
          canCreateOrder: true,
          canTakePayment: true,
          canClearCart: true,
          isCheckoutBusy: false,
        ),
      ),
    ],
    child: child,
  );
}

Future<int> _insertStructuredModifier(
  app_db.AppDatabase db, {
  required int productId,
  required String name,
  required int extraPriceMinor,
  required String priceBehavior,
  required String uiSection,
}) {
  return db
      .into(db.productModifiers)
      .insert(
        app_db.ProductModifiersCompanion.insert(
          productId: productId,
          name: name,
          type: 'extra',
          extraPriceMinor: Value<int>(extraPriceMinor),
          priceBehavior: Value<String?>(priceBehavior),
          uiSection: Value<String?>(uiSection),
        ),
      );
}

Color? _buttonColor(WidgetTester tester, String key) {
  final Finder button = find.byKey(ValueKey<String>(key));
  final Finder container = find.descendant(
    of: button,
    matching: find.byType(AnimatedContainer),
  );
  final AnimatedContainer widget = tester.widget<AnimatedContainer>(
    container.first,
  );
  final BoxDecoration decoration = widget.decoration! as BoxDecoration;
  return decoration.color;
}

class _StructuredBurgerFixture {
  const _StructuredBurgerFixture({
    required this.burgerId,
    required this.friedOnionId,
    required this.saladId,
    required this.ketchupId,
    required this.chipsModifierId,
  });

  final int burgerId;
  final int friedOnionId;
  final int saladId;
  final int ketchupId;
  final int chipsModifierId;
}

Future<_StructuredBurgerFixture> _createStructuredBurger(
  app_db.AppDatabase db,
) async {
  final int categoryId = await insertCategory(db, name: 'Mains');
  final int burgerId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Burger',
    priceMinor: 900,
    hasModifiers: true,
  );
  final int friedOnionId = await _insertStructuredModifier(
    db,
    productId: burgerId,
    name: 'Fried onion',
    extraPriceMinor: 0,
    priceBehavior: 'free',
    uiSection: 'toppings',
  );
  final int saladId = await _insertStructuredModifier(
    db,
    productId: burgerId,
    name: 'Salad',
    extraPriceMinor: 0,
    priceBehavior: 'free',
    uiSection: 'toppings',
  );
  final int ketchupId = await _insertStructuredModifier(
    db,
    productId: burgerId,
    name: 'Ketchup',
    extraPriceMinor: 0,
    priceBehavior: 'free',
    uiSection: 'sauces',
  );
  await _insertStructuredModifier(
    db,
    productId: burgerId,
    name: 'Brown sauce',
    extraPriceMinor: 0,
    priceBehavior: 'free',
    uiSection: 'sauces',
  );
  await _insertStructuredModifier(
    db,
    productId: burgerId,
    name: 'Burger sauce',
    extraPriceMinor: 0,
    priceBehavior: 'free',
    uiSection: 'sauces',
  );
  await _insertStructuredModifier(
    db,
    productId: burgerId,
    name: 'Mayonnaise',
    extraPriceMinor: 0,
    priceBehavior: 'free',
    uiSection: 'sauces',
  );
  final int chipsModifierId = await _insertStructuredModifier(
    db,
    productId: burgerId,
    name: 'Chips',
    extraPriceMinor: 110,
    priceBehavior: 'paid',
    uiSection: 'add_ins',
  );
  await _insertStructuredModifier(
    db,
    productId: burgerId,
    name: 'Beans',
    extraPriceMinor: 80,
    priceBehavior: 'paid',
    uiSection: 'add_ins',
  );
  return _StructuredBurgerFixture(
    burgerId: burgerId,
    friedOnionId: friedOnionId,
    saladId: saladId,
    ketchupId: ketchupId,
    chipsModifierId: chipsModifierId,
  );
}
