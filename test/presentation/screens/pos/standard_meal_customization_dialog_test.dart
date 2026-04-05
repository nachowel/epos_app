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
    testWidgets('updates summary and price preview and returns cart selection',
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
      final Finder extraIncrementButton = find.byKey(
        ValueKey<String>('meal-extra-inc-${fixture.extraItemId}'),
      );
      await tester.ensureVisible(extraIncrementButton);
      await tester.tap(extraIncrementButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('No Fries'), findsWidgets);
      expect(find.text('Chicken Fillet → Beef Patty +£0.50'), findsWidgets);
      expect(find.text('Extra Cheese +£1.00'), findsOneWidget);
      expect(find.text('Removal discount -£0.50'), findsOneWidget);
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
        'No Fries · Chicken Fillet → Beef Patty +£0.50 · Extra Cheese +£1.00',
      );
    });

    testWidgets('invalid initial state shows explicit validation and blocks add',
        (WidgetTester tester) async {
      final db = createTestDatabase();
      addTearDown(db.close);

      final _DialogFixture fixture = await _seedDialogFixture(db);
      final MealCustomizationPosEditorData editorData = await fixture.service
          .loadEditorData(
            product: fixture.product,
            initialState: const MealCustomizationEditorState(
              removedComponentKeys: <String>['main'],
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
        find.byKey(
          const ValueKey<String>('meal-customization-invalid-message'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('cannot be removed'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey<String>('meal-customization-confirm')),
            )
            .onPressed,
        isNull,
      );
    });
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

Future<_DialogFixture> _seedDialogFixture(dynamic db) async {
  final int categoryId = await insertCategory(db, name: 'Meals');
  final int mealProductId = await insertProduct(
    db,
    categoryId: categoryId,
    name: 'Burger Meal',
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

  final DriftMealAdjustmentProfileRepository repository =
      DriftMealAdjustmentProfileRepository(db);
  final int profileId = await repository.saveProfileDraft(
    MealAdjustmentProfileDraft(
      name: 'Dialog profile',
      freeSwapLimit: 0,
      isActive: true,
      components: <MealAdjustmentComponentDraft>[
        MealAdjustmentComponentDraft(
          componentKey: 'main',
          displayName: 'Main',
          defaultItemProductId: defaultMainId,
          quantity: 1,
          canRemove: false,
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
          quantity: 1,
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
          isActive: true,
        ),
      ],
      pricingRules: <MealAdjustmentPricingRuleDraft>[
        MealAdjustmentPricingRuleDraft(
          name: 'No side discount',
          ruleType: MealAdjustmentPricingRuleType.removeOnly,
          priceDeltaMinor: -50,
          priority: 0,
          isActive: true,
          conditions: const <MealAdjustmentPricingRuleConditionDraft>[
            MealAdjustmentPricingRuleConditionDraft(
              conditionType:
                  MealAdjustmentPricingRuleConditionType.removedComponent,
              componentKey: 'side',
              quantity: 1,
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
  );
}

class _DialogFixture {
  const _DialogFixture({
    required this.service,
    required this.product,
    required this.swapItemId,
    required this.extraItemId,
  });

  final MealCustomizationPosService service;
  final Product product;
  final int swapItemId;
  final int extraItemId;
}
