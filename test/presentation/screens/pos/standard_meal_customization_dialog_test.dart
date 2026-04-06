import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/repositories/drift_meal_adjustment_profile_repository.dart';
import 'package:epos_app/data/repositories/product_repository.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/domain/models/meal_customization.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/domain/services/meal_adjustment_profile_validation_service.dart';
import 'package:epos_app/domain/services/meal_customization_pos_service.dart';
import 'package:epos_app/presentation/screens/pos/widgets/standard_meal_customization_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_database.dart';

void main() {
  group('StandardMealCustomizationDialog', () {
    testWidgets(
      'remove action is visible, updates summary, and returns cart selection',
      (WidgetTester tester) async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final _DialogFixture fixture = await _seedDialogFixture(db);
        final MealCustomizationPosEditorData editorData = await fixture.service
            .loadEditorData(product: fixture.product);
        MealCustomizationCartSelection? result;

        await tester.pumpWidget(
          _dialogHost(
            service: fixture.service,
            product: fixture.product,
            editorData: editorData,
            onResult: (MealCustomizationCartSelection? value) {
              result = value;
            },
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('open-meal-dialog')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('meal-component-remove-side')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('meal-component-remove-side')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(
            ValueKey<String>('meal-component-swap-main-${fixture.swapItemId}'),
          ),
        );
        await tester.pumpAndSettle();
        await _expandAddIns(tester);
        final Finder extraToggle = find.byKey(
          ValueKey<String>('meal-extra-toggle-${fixture.extraItemId}'),
        );
        await tester.ensureVisible(extraToggle);
        await tester.tap(extraToggle, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text('No Fries'), findsWidgets);
        expect(find.text('Chicken Fillet → Beef Patty'), findsWidgets);
        expect(find.text('Extra Cheese +£1.00'), findsOneWidget);
        expect(find.textContaining('discount'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('meal-customization-price-preview'),
            ),
            matching: find.text('+£1.00'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('meal-customization-price-preview'),
            ),
            matching: find.text('£11.00'),
          ),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('meal-customization-confirm')),
        );
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.perUnitAdjustmentMinor, 100);
        expect(result!.perUnitLineTotalMinor, 1100);
        expect(
          result!.compactSummary,
          'No Fries · Chicken Fillet → Beef Patty · Extra Cheese +£1.00',
        );
      },
    );

    testWidgets(
      'remove and swap stay mutually exclusive on the same component',
      (WidgetTester tester) async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final _DialogFixture fixture = await _seedDialogFixture(db);
        final MealCustomizationPosEditorData editorData = await fixture.service
            .loadEditorData(product: fixture.product);

        await tester.pumpWidget(
          _dialogHost(
            service: fixture.service,
            product: fixture.product,
            editorData: editorData,
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('open-meal-dialog')),
        );
        await tester.pumpAndSettle();

        final Finder removeMainButton = find.byKey(
          const ValueKey<String>('meal-component-remove-main'),
        );
        final Finder swapMainButton = find.byKey(
          ValueKey<String>('meal-component-swap-main-${fixture.swapItemId}'),
        );

        await tester.tap(removeMainButton);
        await tester.pumpAndSettle();
        expect(find.text('No Chicken Fillet'), findsWidgets);

        await tester.tap(swapMainButton);
        await tester.pumpAndSettle();
        expect(find.text('No Chicken Fillet'), findsNothing);
        expect(find.text('Chicken Fillet → Beef Patty'), findsWidgets);

        await tester.tap(removeMainButton);
        await tester.pumpAndSettle();
        expect(find.text('No Chicken Fillet'), findsWidgets);
        expect(find.text('Chicken Fillet → Beef Patty'), findsNothing);
      },
    );

    testWidgets('remove-only selection can be added to cart', (
      WidgetTester tester,
    ) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DialogFixture fixture = await _seedDialogFixture(db);
      final MealCustomizationPosEditorData editorData = await fixture.service
          .loadEditorData(product: fixture.product);
      MealCustomizationCartSelection? result;

      await tester.pumpWidget(
        _dialogHost(
          service: fixture.service,
          product: fixture.product,
          editorData: editorData,
          onResult: (MealCustomizationCartSelection? value) {
            result = value;
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-meal-dialog')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-component-remove-side')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('meal-customization-confirm')),
      );
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.perUnitAdjustmentMinor, -50);
      expect(result!.compactSummary, 'No Fries');
    });

    testWidgets('component selections preserve configured component quantity', (
      WidgetTester tester,
    ) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DialogFixture fixture = await _seedDialogFixture(
        db,
        mainQuantity: 2,
        sideQuantity: 2,
        removeRuleDeltaMinor: 0,
      );
      final MealCustomizationPosEditorData editorData = await fixture.service
          .loadEditorData(product: fixture.product);
      MealCustomizationCartSelection? result;

      await tester.pumpWidget(
        _dialogHost(
          service: fixture.service,
          product: fixture.product,
          editorData: editorData,
          onResult: (MealCustomizationCartSelection? value) {
            result = value;
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-meal-dialog')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-component-remove-side')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>('meal-component-swap-main-${fixture.swapItemId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Fries x2'), findsWidgets);
      expect(find.text('Chicken Fillet x2 → Beef Patty x2'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-customization-confirm')),
      );
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(
        result!.snapshot.resolvedComponentActions.map(
          (MealCustomizationSemanticAction action) => action.quantity,
        ),
        <int>[2, 2],
      );
      expect(result!.request.swapSelections.single.quantity, 2);
      expect(
        result!.compactSummary,
        'No Fries x2 · Chicken Fillet x2 → Beef Patty x2',
      );
    });

    testWidgets(
      'invalid initial state shows explicit validation and blocks add',
      (WidgetTester tester) async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final _DialogFixture fixture = await _seedDialogFixture(db);
        final MealCustomizationPosEditorData editorData = await fixture.service
            .loadEditorData(
              product: fixture.product,
              initialState: const MealCustomizationEditorState(
                componentSelections: <MealCustomizationComponentState>[
                  MealCustomizationComponentState(
                    componentKey: 'main',
                    mode: MealComponentSelectionMode.swap,
                    swapTargetItemProductId: 999999,
                  ),
                ],
              ),
            );

        await tester.pumpWidget(
          _dialogHost(
            service: fixture.service,
            product: fixture.product,
            editorData: editorData,
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('open-meal-dialog')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('meal-customization-invalid-message'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('not allowed'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(
                  const ValueKey<String>('meal-customization-confirm'),
                ),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets(
      'inactive profile extra does not appear in POS extras section',
      (WidgetTester tester) async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final _DialogFixture fixture = await _seedDialogFixture(
          db,
          extraIsActive: false,
        );
        final MealCustomizationPosEditorData editorData = await fixture.service
            .loadEditorData(product: fixture.product);

        await tester.pumpWidget(
          _dialogHost(
            service: fixture.service,
            product: fixture.product,
            editorData: editorData,
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('open-meal-dialog')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('meal-addins-section')),
          findsNothing,
        );
        expect(
          find.byKey(
            ValueKey<String>('meal-extra-toggle-${fixture.extraItemId}'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('add-ins are collapsed by default and expand on tap', (
      WidgetTester tester,
    ) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DialogFixture fixture = await _seedDialogFixture(db);
      final MealCustomizationPosEditorData editorData = await fixture.service
          .loadEditorData(product: fixture.product);

      await tester.pumpWidget(
        _dialogHost(
          service: fixture.service,
          product: fixture.product,
          editorData: editorData,
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-meal-dialog')));
      await tester.pumpAndSettle();

      expect(find.text('Add-ins (2)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('meal-addins-body')),
        findsNothing,
      );
      expect(find.text('Cheese'), findsNothing);

      await _expandAddIns(tester);

      expect(
        find.byKey(const ValueKey<String>('meal-addins-body')),
        findsOneWidget,
      );
      expect(find.text('Cheese'), findsOneWidget);
      expect(find.text('Tomato'), findsOneWidget);
    });

    testWidgets(
      'generic POS extra-category products do not appear unless configured as meal add-ins',
      (WidgetTester tester) async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final int extrasCategoryId = await insertCategory(db, name: 'Extras');
        await insertProduct(
          db,
          categoryId: extrasCategoryId,
          name: 'Burger',
          priceMinor: 280,
        );

        final _DialogFixture fixture = await _seedDialogFixture(db);
        final MealCustomizationPosEditorData editorData = await fixture.service
            .loadEditorData(product: fixture.product);

        await tester.pumpWidget(
          _dialogHost(
            service: fixture.service,
            product: fixture.product,
            editorData: editorData,
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('open-meal-dialog')),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Add-ins ('), findsOneWidget);
        await _expandAddIns(tester);
        expect(find.text('Cheese'), findsOneWidget);
        expect(find.text('Burger'), findsNothing);
      },
    );

    testWidgets('existing extra selection rehydrates when reopening editor', (
      WidgetTester tester,
    ) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DialogFixture fixture = await _seedDialogFixture(db);
      final MealCustomizationPosEditorData editorData = await fixture.service
          .loadEditorData(
            product: fixture.product,
            initialState: MealCustomizationEditorState(
              extraSelections: <MealCustomizationExtraSelection>[
                MealCustomizationExtraSelection(
                  itemProductId: fixture.extraItemId,
                  quantity: 1,
                ),
              ],
            ),
          );

      await tester.pumpWidget(
        _dialogHost(
          service: fixture.service,
          product: fixture.product,
          editorData: editorData,
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-meal-dialog')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('meal-addins-body')),
        findsOneWidget,
      );
      expect(find.text('Add-ins (1 selected)'), findsOneWidget);
      expect(find.text('Extra Cheese +£1.00'), findsWidgets);
      expect(
        find.byKey(
          ValueKey<String>('meal-extra-selected-${fixture.extraItemId}'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('collapsed add-ins header shows selected summary', (
      WidgetTester tester,
    ) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DialogFixture fixture = await _seedDialogFixture(db);
      final MealCustomizationPosEditorData editorData = await fixture.service
          .loadEditorData(product: fixture.product);

      await tester.pumpWidget(
        _dialogHost(
          service: fixture.service,
          product: fixture.product,
          editorData: editorData,
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-meal-dialog')));
      await tester.pumpAndSettle();

      await _expandAddIns(tester);
      final Finder cheeseToggle = find.byKey(
        ValueKey<String>('meal-extra-toggle-${fixture.extraItemId}'),
      );
      await tester.ensureVisible(cheeseToggle);
      await tester.tap(cheeseToggle);
      await tester.pumpAndSettle();
      final Finder tomatoToggle = find.byKey(
        ValueKey<String>('meal-extra-toggle-${fixture.secondExtraItemId}'),
      );
      await tester.ensureVisible(tomatoToggle);
      await tester.tap(tomatoToggle);
      await tester.pumpAndSettle();

      final Finder addInsToggle = find.byKey(
        const ValueKey<String>('meal-addins-toggle'),
      );
      await tester.ensureVisible(addInsToggle);
      await tester.tap(addInsToggle);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('meal-addins-body')),
        findsNothing,
      );
      expect(find.text('Add-ins (2 selected)'), findsOneWidget);
      expect(find.text('+Cheese, +Tomato'), findsOneWidget);
    });

    testWidgets('zero-priced remove still appears in summary alongside swaps', (
      WidgetTester tester,
    ) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DialogFixture fixture = await _seedDialogFixture(
        db,
        removeRuleDeltaMinor: 0,
      );
      final MealCustomizationPosEditorData editorData = await fixture.service
          .loadEditorData(product: fixture.product);
      MealCustomizationCartSelection? result;

      await tester.pumpWidget(
        _dialogHost(
          service: fixture.service,
          product: fixture.product,
          editorData: editorData,
          onResult: (MealCustomizationCartSelection? value) {
            result = value;
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey<String>('open-meal-dialog')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-component-remove-side')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>('meal-component-swap-main-${fixture.swapItemId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Fries'), findsWidgets);
      expect(find.text('Chicken Fillet → Beef Patty'), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-customization-confirm')),
      );
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.compactSummary, 'No Fries · Chicken Fillet → Beef Patty');
    });

    testWidgets(
      'sandwich flow requires bread and shows toast only for sandwich',
      (WidgetTester tester) async {
        final db = createTestDatabase();
        addTearDown(db.close);

        final _DialogFixture fixture = await _seedDialogFixture(
          db,
          kind: MealAdjustmentProfileKind.sandwich,
          mealProductName: 'Egg',
        );
        final MealCustomizationPosEditorData editorData = await fixture.service
            .loadEditorData(product: fixture.product);
        MealCustomizationCartSelection? result;

        await tester.pumpWidget(
          _dialogHost(
            service: fixture.service,
            product: fixture.product,
            editorData: editorData,
            onResult: (MealCustomizationCartSelection? value) {
              result = value;
            },
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('open-meal-dialog')),
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<ElevatedButton>(
                find.byKey(
                  const ValueKey<String>('meal-customization-confirm'),
                ),
              )
              .onPressed,
          isNull,
        );
        expect(
          find.byKey(const ValueKey<String>('meal-sandwich-toast-toasted')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('meal-sandwich-bread-sandwich')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('meal-sandwich-toast-toasted')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('meal-sandwich-sauce-mayo')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('meal-sandwich-sauce-brownSauce')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('meal-sandwich-toast-toasted')),
        );
        await tester.pumpAndSettle();
        await _expandAddIns(tester);
        await tester.tap(
          find.byKey(
            ValueKey<String>('meal-extra-toggle-${fixture.extraItemId}'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mayo'), findsWidgets);
        expect(find.text('Brown Sauce'), findsWidgets);
        expect(find.text('Toasted'), findsWidgets);
        expect(find.text('Extra Cheese +£1.00'), findsWidgets);

        await tester.tap(
          find.byKey(const ValueKey<String>('meal-customization-confirm')),
        );
        await tester.pumpAndSettle();

        expect(result, isNotNull);
        expect(result!.displayName, 'Egg Sandwich');
        expect(result!.perUnitAdjustmentMinor, 200);
        expect(result!.perUnitLineTotalMinor, 1200);

        final MealCustomizationPosEditorData reopenedEditorData = await fixture
            .service
            .loadEditorData(
              product: fixture.product,
              initialState: result!.snapshot.toEditorState(),
            );
        await tester.pumpWidget(
          _dialogHost(
            service: fixture.service,
            product: fixture.product,
            editorData: reopenedEditorData,
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('open-meal-dialog')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('meal-sandwich-toast-toasted')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('meal-sandwich-sauce-mayo')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('meal-sandwich-sauce-brownSauce')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey<String>('meal-sandwich-bread-roll')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('meal-sandwich-toast-toasted')),
          findsNothing,
        );
      },
    );
  });

  testWidgets('add-in cards toggle on and off with a single tap', (
    WidgetTester tester,
  ) async {
    final db = createTestDatabase();
    addTearDown(db.close);

    final _DialogFixture fixture = await _seedDialogFixture(db);
    final MealCustomizationPosEditorData editorData = await fixture.service
        .loadEditorData(product: fixture.product);

    await tester.pumpWidget(
      _dialogHost(
        service: fixture.service,
        product: fixture.product,
        editorData: editorData,
      ),
    );
    await tester.tap(find.byKey(const ValueKey<String>('open-meal-dialog')));
    await tester.pumpAndSettle();
    await _expandAddIns(tester);

    final Finder cheeseToggle = find.byKey(
      ValueKey<String>('meal-extra-toggle-${fixture.extraItemId}'),
    );
    await tester.ensureVisible(cheeseToggle);
    await tester.tap(cheeseToggle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        ValueKey<String>('meal-extra-selected-${fixture.extraItemId}'),
      ),
      findsOneWidget,
    );
    expect(find.text('Extra Cheese +£1.00'), findsWidgets);

    await tester.tap(cheeseToggle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        ValueKey<String>('meal-extra-selected-${fixture.extraItemId}'),
      ),
      findsNothing,
    );
    expect(find.text('Extra Cheese +£1.00'), findsNothing);
  });
}

Widget _dialogHost({
  required MealCustomizationPosService service,
  required Product product,
  required MealCustomizationPosEditorData editorData,
  ValueChanged<MealCustomizationCartSelection?>? onResult,
}) {
  return ProviderScope(
    overrides: <Override>[
      mealCustomizationPosServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (BuildContext context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey<String>('open-meal-dialog'),
                onPressed: () async {
                  final MealCustomizationCartSelection? result =
                      await showDialog<MealCustomizationCartSelection>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => StandardMealCustomizationDialog(
                          product: product,
                          initialEditorData: editorData,
                        ),
                      );
                  onResult?.call(result);
                },
                child: const Text('Open'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Future<_DialogFixture> _seedDialogFixture(
  dynamic db, {
  MealAdjustmentProfileKind kind = MealAdjustmentProfileKind.standard,
  String mealProductName = 'Burger Meal',
  bool extraIsActive = true,
  int mainQuantity = 1,
  int removeRuleDeltaMinor = -50,
  int sideQuantity = 1,
}) async {
  final int categoryId = await insertCategory(db, name: 'Meals');
  final int mealProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: mealProductName,
    priceMinor: 1000,
  );
  final int defaultMainId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Chicken Fillet',
    priceMinor: 0,
  );
  final int swapItemId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Beef Patty',
    priceMinor: 0,
  );
  final int sideItemId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Fries',
    priceMinor: 0,
  );
  final int extraItemId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Cheese',
    priceMinor: 0,
  );
  final int secondExtraItemId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Tomato',
    priceMinor: 0,
  );

  final DriftMealAdjustmentProfileRepository repository =
      DriftMealAdjustmentProfileRepository(db);
  final int profileId = await repository.saveProfileDraft(
    MealAdjustmentProfileDraft(
      name: 'Dialog profile',
      kind: kind,
      sandwichSettings: kind == MealAdjustmentProfileKind.sandwich
          ? const SandwichProfileSettings(
              sandwichSurchargeMinor: 100,
              baguetteSurchargeMinor: 180,
              sauceOptions: <SandwichSauceType>[
                SandwichSauceType.mayo,
                SandwichSauceType.brownSauce,
              ],
            )
          : const SandwichProfileSettings(),
      freeSwapLimit: 0,
      isActive: true,
      components: kind == MealAdjustmentProfileKind.sandwich
          ? const <MealAdjustmentComponentDraft>[]
          : <MealAdjustmentComponentDraft>[
              MealAdjustmentComponentDraft(
                componentKey: 'main',
                displayName: 'Main',
                defaultItemProductId: defaultMainId,
                quantity: mainQuantity,
                canRemove: true,
                sortOrder: 0,
                isActive: true,
                swapOptions: <MealAdjustmentComponentOptionDraft>[
                  MealAdjustmentComponentOptionDraft(
                    optionItemProductId: swapItemId,
                    fixedPriceDeltaMinor: 50,
                    sortOrder: 0,
                    isActive: true,
                  ),
                ],
              ),
              MealAdjustmentComponentDraft(
                componentKey: 'side',
                displayName: 'Side',
                defaultItemProductId: sideItemId,
                quantity: sideQuantity,
                canRemove: true,
                sortOrder: 1,
                isActive: true,
              ),
            ],
      extraOptions: <MealAdjustmentExtraOptionDraft>[
        MealAdjustmentExtraOptionDraft(
          itemProductId: extraItemId,
          fixedPriceDeltaMinor: 100,
          sortOrder: 0,
          isActive: extraIsActive,
        ),
        MealAdjustmentExtraOptionDraft(
          itemProductId: secondExtraItemId,
          fixedPriceDeltaMinor: 150,
          sortOrder: 1,
          isActive: extraIsActive,
        ),
      ],
      pricingRules: kind == MealAdjustmentProfileKind.sandwich
          ? const <MealAdjustmentPricingRuleDraft>[]
          : <MealAdjustmentPricingRuleDraft>[
              if (removeRuleDeltaMinor != 0)
                MealAdjustmentPricingRuleDraft(
                  name: 'No side discount',
                  ruleType: MealAdjustmentPricingRuleType.removeOnly,
                  priceDeltaMinor: removeRuleDeltaMinor,
                  priority: 0,
                  isActive: true,
                  conditions: <MealAdjustmentPricingRuleConditionDraft>[
                    MealAdjustmentPricingRuleConditionDraft(
                      conditionType: MealAdjustmentPricingRuleConditionType
                          .removedComponent,
                      componentKey: 'side',
                      quantity: sideQuantity,
                    ),
                  ],
                ),
            ],
    ),
  );
  await repository.assignProfileToProduct(
    productId: mealProductId,
    profileId: profileId,
  );

  final Product product = (await ProductRepository(db).getById(mealProductId))!;
  final MealCustomizationPosService service = MealCustomizationPosService(
    mealAdjustmentProfileRepository: repository,
    validationService: MealAdjustmentProfileValidationService(
      repository: repository,
    ),
    productRepository: ProductRepository(db),
  );

  return _DialogFixture(
    service: service,
    product: product,
    swapItemId: swapItemId,
    extraItemId: extraItemId,
    secondExtraItemId: secondExtraItemId,
  );
}

class _DialogFixture {
  const _DialogFixture({
    required this.service,
    required this.product,
    required this.swapItemId,
    required this.extraItemId,
    required this.secondExtraItemId,
  });

  final MealCustomizationPosService service;
  final Product product;
  final int swapItemId;
  final int extraItemId;
  final int secondExtraItemId;
}

Future<void> _expandAddIns(WidgetTester tester) async {
  final Finder addInsBody = find.byKey(
    const ValueKey<String>('meal-addins-body'),
  );
  if (addInsBody.evaluate().isEmpty) {
    final Finder addInsToggle = find.byKey(
      const ValueKey<String>('meal-addins-toggle'),
    );
    await tester.ensureVisible(addInsToggle);
    await tester.tap(addInsToggle);
    await tester.pumpAndSettle();
  }
}
