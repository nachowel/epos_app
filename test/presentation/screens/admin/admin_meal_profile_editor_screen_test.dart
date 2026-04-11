import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/domain/models/meal_adjustment_profile.dart';
import 'package:epos_app/presentation/screens/admin/admin_meal_profile_editor_screen.dart';
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
    'add component opens editable state and supports editing core fields',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int sidesCategoryId = await insertCategory(db, name: 'Sides');
      final int beansId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Beans',
        priceMinor: 120,
      );
      await insertProduct(
        db,
        categoryId: sidesCategoryId,
        name: 'Peas',
        priceMinor: 130,
      );
      await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Old Beans',
        priceMinor: 120,
        isActive: false,
      );

      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            const MealAdjustmentProfileDraft(
              name: 'Omelette Profile',
              freeSwapLimit: 0,
              isActive: false,
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();
      await _openComponentsTab(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-add-component')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('component-display-name-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('component-default-product-0')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('component-display-name-0')),
        'Beans',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('component-key-0')),
        'beans',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('component-qty-inc-0')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('component-removable-0')),
      );
      await tester.pumpAndSettle();

      await _chooseProduct(
        tester,
        fieldKey: const ValueKey<String>('component-default-product-0'),
        query: 'beans',
        productId: beansId,
      );

      expect(find.text('Old Beans'), findsNothing);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey<String>('component-qty-input-0')),
            )
            .controller!
            .text,
        '2',
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey<String>('component-removable-0')),
            )
            .value,
        isFalse,
      );

      final ElevatedButton saveButtonBefore = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('meal-profile-editor-save')),
      );
      expect(saveButtonBefore.onPressed, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-editor-save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'swap management adds, blocks invalid selections, and removes swaps',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int vegCategoryId = await insertCategory(db, name: 'Veg');
      final int beansId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Beans',
        priceMinor: 120,
      );
      final int peasId = await insertProduct(
        db,
        categoryId: vegCategoryId,
        name: 'Peas',
        priceMinor: 130,
      );
      final int saladId = await insertProduct(
        db,
        categoryId: vegCategoryId,
        name: 'Salad',
        priceMinor: 140,
      );

      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            MealAdjustmentProfileDraft(
              name: 'Omelette Profile',
              freeSwapLimit: 0,
              isActive: false,
              components: <MealAdjustmentComponentDraft>[
                MealAdjustmentComponentDraft(
                  componentKey: 'beans',
                  displayName: 'Beans',
                  defaultItemProductId: beansId,
                  quantity: 1,
                  canRemove: true,
                  sortOrder: 0,
                  isActive: true,
                ),
              ],
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();
      await _openComponentsTab(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('component-expand-0')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('component-add-swap-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('meal-profile-product-option-$peasId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Swap 1'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('component-add-swap-0')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey<String>('meal-profile-product-option-$peasId')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Swap option duplicates existing item'), findsOneWidget);

      await _chooseProduct(
        tester,
        fieldKey: const ValueKey<String>('component-swap-product-0-0'),
        query: 'beans',
        productId: beansId,
      );

      expect(
        find.text('Swap option cannot match default product'),
        findsOneWidget,
      );

      await _chooseProduct(
        tester,
        fieldKey: const ValueKey<String>('component-swap-product-0-0'),
        query: 'salad',
        productId: saladId,
      );

      expect(
        find.text('Swap option cannot match default product'),
        findsNothing,
      );
      expect(find.text('Swap option duplicates existing item'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('component-swap-remove-0-0')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No swap options yet.'), findsOneWidget);
    },
  );

  testWidgets(
    'invalid component shows inline errors, disables save, and updates badges',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertCategory(db, name: 'Breakfast Items');
      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            const MealAdjustmentProfileDraft(
              name: 'Omelette Profile',
              freeSwapLimit: 0,
              isActive: false,
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();
      await _openComponentsTab(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-add-component')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Default product required'), findsOneWidget);
      expect(find.text('Display name required'), findsOneWidget);

      final ElevatedButton saveButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('meal-profile-editor-save')),
      );
      expect(saveButton.onPressed, isNull);

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('meal-profile-tab-badge-components'),
          ),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('meal-profile-tab-badge-validation'),
          ),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'add extra opens editable state and supports product price and active editing',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int extrasCategoryId = await insertCategory(db, name: 'Extras');
      final int eggId = await insertProduct(
        db,
        categoryId: extrasCategoryId,
        name: 'Egg',
        priceMinor: 150,
      );

      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            const MealAdjustmentProfileDraft(
              name: 'Omelette Profile',
              freeSwapLimit: 0,
              isActive: false,
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();
      await _openAddInsTab(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-add-extra')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('extra-product-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('extra-delta-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('extra-active-0')),
        findsOneWidget,
      );
      expect(find.text('Add-ins'), findsWidgets);
      expect(
        find.textContaining('Add-ins are items added into the meal itself.'),
        findsOneWidget,
      );

      await _chooseProduct(
        tester,
        fieldKey: const ValueKey<String>('extra-product-0'),
        query: 'egg',
        productId: eggId,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('extra-delta-0')),
        '1.50',
      );
      await tester.tap(find.byKey(const ValueKey<String>('extra-active-0')));
      await tester.pumpAndSettle();

      expect(find.text('Egg'), findsWidgets);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey<String>('extra-delta-0')),
            )
            .controller!
            .text,
        '1.50',
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey<String>('extra-active-0')),
            )
            .value,
        isFalse,
      );

      final ElevatedButton saveButtonBefore = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('meal-profile-editor-save')),
      );
      expect(saveButtonBefore.onPressed, isNotNull);
    },
  );

  testWidgets(
    'duplicate or negative extra shows inline errors and disables save',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int extrasCategoryId = await insertCategory(db, name: 'Extras');
      final int eggId = await insertProduct(
        db,
        categoryId: extrasCategoryId,
        name: 'Egg',
        priceMinor: 150,
      );

      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            MealAdjustmentProfileDraft(
              name: 'Omelette Profile',
              freeSwapLimit: 0,
              isActive: false,
              extraOptions: <MealAdjustmentExtraOptionDraft>[
                MealAdjustmentExtraOptionDraft(
                  itemProductId: eggId,
                  fixedPriceDeltaMinor: 150,
                  sortOrder: 0,
                  isActive: true,
                ),
              ],
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();
      await _openAddInsTab(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-add-extra')),
      );
      await tester.pumpAndSettle();

      await _chooseProduct(
        tester,
        fieldKey: const ValueKey<String>('extra-product-1'),
        query: 'egg',
        productId: eggId,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('extra-delta-1')),
        '-1.00',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Add-in product duplicates another entry'),
        findsWidgets,
      );
      expect(find.text('Add-in price cannot be negative'), findsWidgets);

      final ElevatedButton saveButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('meal-profile-editor-save')),
      );
      expect(saveButton.onPressed, isNull);

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('meal-profile-tab-badge-extras'),
          ),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('meal-profile-tab-badge-validation'),
          ),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'add-in chooser refreshes newly created products and excludes root meal products',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int omelettesCategoryId = await insertCategory(
        db,
        name: 'Omelettes',
      );
      final int extrasCategoryId = await insertCategory(db, name: 'Extras');
      final int mealsCategoryId = await insertCategory(db, name: 'Meals');
      final int setBreakfastCategoryId = await insertCategory(
        db,
        name: 'Set Breakfast',
      );
      final int breakfastItemId = await insertProduct(
        db,
        categoryId: extrasCategoryId,
        name: 'Hash Brown',
        priceMinor: 120,
      );
      final int breakfastRootId = await insertProduct(
        db,
        categoryId: setBreakfastCategoryId,
        name: 'All Day Breakfast',
        priceMinor: 850,
      );
      await db.customStatement(
        '''
        INSERT INTO set_items (
          product_id,
          item_product_id,
          is_removable,
          default_quantity,
          sort_order
        ) VALUES (?, ?, 1, 1, 0)
        ''',
        <Object>[breakfastRootId, breakfastItemId],
      );

      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int mealRootProfileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            const MealAdjustmentProfileDraft(
              name: 'Meal root profile',
              freeSwapLimit: 0,
              isActive: true,
            ),
          );
      await insertProduct(
        db,
        categoryId: mealsCategoryId,
        name: 'Burger Meal',
        priceMinor: 900,
        mealAdjustmentProfileId: mealRootProfileId,
      );
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            const MealAdjustmentProfileDraft(
              name: 'Omelette Profile',
              freeSwapLimit: 0,
              isActive: false,
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();
      await _openAddInsTab(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-add-extra')),
      );
      await tester.pumpAndSettle();

      final int cheeseOmeletteId = await insertProduct(
        db,
        categoryId: omelettesCategoryId,
        name: 'Cheese',
        priceMinor: 100,
      );
      final int cheeseExtrasId = await insertProduct(
        db,
        categoryId: extrasCategoryId,
        name: 'Cheese',
        priceMinor: 120,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('extra-product-0')),
          matching: find.text('Choose'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey<String>('meal-profile-product-option-$cheeseOmeletteId'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>('meal-profile-product-option-$cheeseExtrasId'),
        ),
        findsOneWidget,
      );
      expect(find.text('Cheese'), findsNWidgets(2));
      expect(find.text('All Day Breakfast'), findsNothing);
      expect(find.text('Burger Meal'), findsNothing);
    },
  );

  testWidgets(
    'pricing rule add opens editable state and supports core editing',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int vegCategoryId = await insertCategory(db, name: 'Veg');
      final int beansId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Beans',
        priceMinor: 120,
      );
      final int peasId = await insertProduct(
        db,
        categoryId: vegCategoryId,
        name: 'Peas',
        priceMinor: 130,
      );
      final int extraSaladId = await insertProduct(
        db,
        categoryId: vegCategoryId,
        name: 'Extra Salad',
        priceMinor: 160,
      );

      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            MealAdjustmentProfileDraft(
              name: 'Omelette Profile',
              freeSwapLimit: 0,
              isActive: false,
              components: <MealAdjustmentComponentDraft>[
                MealAdjustmentComponentDraft(
                  componentKey: 'beans',
                  displayName: 'Beans',
                  defaultItemProductId: beansId,
                  quantity: 1,
                  canRemove: true,
                  sortOrder: 0,
                  isActive: true,
                  swapOptions: <MealAdjustmentComponentOptionDraft>[
                    MealAdjustmentComponentOptionDraft(
                      optionItemProductId: peasId,
                      sortOrder: 0,
                      isActive: true,
                    ),
                  ],
                ),
              ],
              extraOptions: <MealAdjustmentExtraOptionDraft>[
                MealAdjustmentExtraOptionDraft(
                  itemProductId: extraSaladId,
                  fixedPriceDeltaMinor: 160,
                  sortOrder: 0,
                  isActive: true,
                ),
              ],
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();
      await _openPricingRulesTab(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-add-rule')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('rule-name-0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('rule-type-0')), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('rule-delta-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('rule-priority-0')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('rule-name-0')),
        'No Beans',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('rule-delta-0')),
        '-1.00',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('rule-priority-0')),
        '7',
      );
      await _selectDropdownOption(
        tester,
        fieldKey: const ValueKey<String>('rule-condition-component-0-0'),
        optionText: 'Beans (beans)',
      );

      await tester.tap(find.byKey(const ValueKey<String>('rule-active-0')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey<String>('rule-active-0')),
            )
            .value,
        isFalse,
      );
      expect(
        find.text('If Beans is removed, reduce price by £1.00.'),
        findsWidgets,
      );

      final ElevatedButton saveButtonBefore = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('meal-profile-editor-save')),
      );
      expect(saveButtonBefore.onPressed, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-editor-save')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile saved.'), findsOneWidget);
    },
  );

  testWidgets(
    'pricing rule builder supports combo swap extra and blocks duplicates',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int vegCategoryId = await insertCategory(db, name: 'Veg');
      final int beansId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Beans',
        priceMinor: 120,
      );
      final int chipsId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Chips',
        priceMinor: 150,
      );
      final int peasId = await insertProduct(
        db,
        categoryId: vegCategoryId,
        name: 'Peas',
        priceMinor: 130,
      );
      final int saladId = await insertProduct(
        db,
        categoryId: vegCategoryId,
        name: 'Extra Salad',
        priceMinor: 160,
      );

      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            MealAdjustmentProfileDraft(
              name: 'Omelette Profile',
              freeSwapLimit: 0,
              isActive: false,
              components: <MealAdjustmentComponentDraft>[
                MealAdjustmentComponentDraft(
                  componentKey: 'beans',
                  displayName: 'Beans',
                  defaultItemProductId: beansId,
                  quantity: 1,
                  canRemove: true,
                  sortOrder: 0,
                  isActive: true,
                  swapOptions: <MealAdjustmentComponentOptionDraft>[
                    MealAdjustmentComponentOptionDraft(
                      optionItemProductId: peasId,
                      sortOrder: 0,
                      isActive: true,
                    ),
                  ],
                ),
                MealAdjustmentComponentDraft(
                  componentKey: 'chips',
                  displayName: 'Chips',
                  defaultItemProductId: chipsId,
                  quantity: 1,
                  canRemove: true,
                  sortOrder: 1,
                  isActive: true,
                ),
              ],
              extraOptions: <MealAdjustmentExtraOptionDraft>[
                MealAdjustmentExtraOptionDraft(
                  itemProductId: saladId,
                  fixedPriceDeltaMinor: 160,
                  sortOrder: 0,
                  isActive: true,
                ),
              ],
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();
      await _openPricingRulesTab(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-add-rule')),
      );
      await tester.pumpAndSettle();

      await _selectDropdownOption(
        tester,
        fieldKey: const ValueKey<String>('rule-type-0'),
        optionText: 'Combo',
      );
      await _selectDropdownOption(
        tester,
        fieldKey: const ValueKey<String>('rule-condition-component-0-0'),
        optionText: 'Beans (beans)',
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('rule-add-condition-0')),
      );
      await tester.pumpAndSettle();
      await _selectDropdownOption(
        tester,
        fieldKey: const ValueKey<String>('rule-condition-component-0-1'),
        optionText: 'Beans (beans)',
      );

      expect(
        find.text(
          'Duplicate conditions with the same semantic meaning are not allowed.',
        ),
        findsWidgets,
      );

      await _selectDropdownOption(
        tester,
        fieldKey: const ValueKey<String>('rule-condition-component-0-1'),
        optionText: 'Chips (chips)',
      );

      expect(
        find.text(
          'If Beans is removed and Chips is removed, price stays the same.',
        ),
        findsWidgets,
      );

      await _selectDropdownOption(
        tester,
        fieldKey: const ValueKey<String>('rule-type-0'),
        optionText: 'Swap',
      );
      await _selectDropdownOption(
        tester,
        fieldKey: const ValueKey<String>('rule-condition-component-0-0'),
        optionText: 'Beans (beans)',
      );
      await _chooseProduct(
        tester,
        fieldKey: const ValueKey<String>('rule-condition-item-0-0'),
        query: 'peas',
        productId: peasId,
      );

      expect(
        find.text('If Beans is swapped to Peas, price stays the same.'),
        findsWidgets,
      );

      await _selectDropdownOption(
        tester,
        fieldKey: const ValueKey<String>('rule-type-0'),
        optionText: 'Add-in',
      );
      await _chooseProduct(
        tester,
        fieldKey: const ValueKey<String>('rule-condition-item-0-0'),
        query: 'salad',
        productId: saladId,
      );

      expect(
        find.text(
          'If Extra Salad is added into the meal, price stays the same.',
        ),
        findsWidgets,
      );
    },
  );

  testWidgets(
    'invalid pricing rule shows inline errors disables save and aligns badges',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final int breakfastItemsCategoryId = await insertCategory(
        db,
        name: 'Breakfast Items',
      );
      final int beansId = await insertProduct(
        db,
        categoryId: breakfastItemsCategoryId,
        name: 'Beans',
        priceMinor: 120,
      );

      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            MealAdjustmentProfileDraft(
              name: 'Omelette Profile',
              freeSwapLimit: 0,
              isActive: false,
              components: <MealAdjustmentComponentDraft>[
                MealAdjustmentComponentDraft(
                  componentKey: 'beans',
                  displayName: 'Beans',
                  defaultItemProductId: beansId,
                  quantity: 1,
                  canRemove: true,
                  sortOrder: 0,
                  isActive: true,
                ),
              ],
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();
      await _openPricingRulesTab(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-add-rule')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('rule-name-0')),
        '',
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('rule-delta-0')),
        '1.00',
      );
      await tester.pumpAndSettle();

      expect(find.text('Rule name required'), findsOneWidget);
      expect(
        find.text('Remove-only rules cannot use positive deltas'),
        findsWidgets,
      );
      expect(
        find.text(
          'Complete the condition fields required by this condition type.',
        ),
        findsWidgets,
      );

      final ElevatedButton saveButton = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('meal-profile-editor-save')),
      );
      expect(saveButton.onPressed, isNull);

      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('meal-profile-tab-badge-rules'),
          ),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(
            const ValueKey<String>('meal-profile-tab-badge-validation'),
          ),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(find.text('This rule is incomplete.'), findsWidgets);
    },
  );

  testWidgets(
    'sandwich profile editor exposes real sandwich settings with add-ins separate',
    (WidgetTester tester) async {
      _setLargeView(tester);
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      await insertCategory(db, name: 'Extras');
      final int saucesCategoryId = await insertCategory(db, name: 'Sauces');
      final int ketchupSauceId = await insertProduct(
        db,
        categoryId: saucesCategoryId,
        name: 'Ketchup',
        priceMinor: 0,
      );
      final int mayoSauceId = await insertProduct(
        db,
        categoryId: saucesCategoryId,
        name: 'Mayonnaise',
        priceMinor: 0,
      );

      final ProviderContainer container = _container(db);
      addTearDown(container.dispose);
      final int profileId = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .saveProfileDraft(
            MealAdjustmentProfileDraft(
              name: 'Sandwich Profile',
              kind: MealAdjustmentProfileKind.sandwich,
              freeSwapLimit: 0,
              isActive: true,
            ),
          );

      await tester.pumpWidget(_testApp(container, profileId));
      await tester.pumpAndSettle();

      expect(find.text('Components'), findsNothing);
      expect(find.text('Pricing Rules'), findsNothing);
      expect(find.text('Sandwich Settings'), findsOneWidget);
      expect(find.text('Add-ins'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('sandwich-profile-guidance')),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'This profile controls editable bread surcharges, enabled sauces, sandwich-only toast, and paid add-ins.',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('meal-profile-editor-swaps')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('meal-profile-editor-kind')),
        findsNothing,
      );

      await tester.tap(find.text('Sandwich Settings').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('sandwich-settings-help')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('meal-profile-editor-sandwich-surcharge'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>('meal-profile-editor-baguette-surcharge'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('sandwich-profile-sauce-$ketchupSauceId')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<String>('sandwich-profile-sauce-$mayoSauceId')),
        findsOneWidget,
      );
      expect(find.text('Roll'), findsOneWidget);
      expect(find.text('Base price'), findsOneWidget);

      await tester.enterText(
        find.byKey(
          const ValueKey<String>('meal-profile-editor-sandwich-surcharge'),
        ),
        '1.25',
      );
      await tester.enterText(
        find.byKey(
          const ValueKey<String>('meal-profile-editor-baguette-surcharge'),
        ),
        '2.20',
      );
      await tester.tap(
        find.byKey(ValueKey<String>('sandwich-profile-sauce-$ketchupSauceId')),
      );
      await tester.pumpAndSettle();

      await _openAddInsTab(tester);
      expect(find.text('No add-ins configured yet.'), findsOneWidget);
      expect(
        find.text(
          'Add paid extras that can be added to sandwich products using this profile. Sauces stay separate as free multi-select options.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Validation').first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey<String>('sandwich-validation-success')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Sandwich profile is valid. Metadata, sandwich settings, and add-ins are ready.',
        ),
        findsOneWidget,
      );
      expect(find.text('No issues found. Profile is valid.'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('meal-profile-editor-save')),
      );
      await tester.pumpAndSettle();

      final MealAdjustmentProfileDraft? savedDraft = await container
          .read(mealAdjustmentProfileRepositoryProvider)
          .loadProfileDraft(profileId);
      expect(savedDraft, isNotNull);
      expect(savedDraft!.sandwichSettings.sandwichSurchargeMinor, 125);
      expect(savedDraft.sandwichSettings.baguetteSurchargeMinor, 220);
      expect(
        savedDraft.sandwichSettings.sauceProductIds.contains(ketchupSauceId),
        isTrue,
      );
    },
  );
}

ProviderContainer _container(AppDatabase db) {
  return ProviderContainer(
    overrides: <Override>[
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(_testPrefs),
    ],
  );
}

Widget _testApp(ProviderContainer container, int profileId) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: AdminMealProfileEditorScreen(profileId: profileId),
    ),
  );
}

Future<void> _openComponentsTab(WidgetTester tester) async {
  await tester.tap(find.text('Components').first);
  await tester.pumpAndSettle();
}

Future<void> _openAddInsTab(WidgetTester tester) async {
  await tester.tap(find.text('Add-ins').first);
  await tester.pumpAndSettle();
}

Future<void> _openPricingRulesTab(WidgetTester tester) async {
  await tester.tap(find.text('Pricing Rules').first);
  await tester.pumpAndSettle();
}

Future<void> _chooseProduct(
  WidgetTester tester, {
  required ValueKey<String> fieldKey,
  required String query,
  required int productId,
}) async {
  await tester.tap(
    find.descendant(of: find.byKey(fieldKey), matching: find.text('Choose')),
  );
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey<String>('meal-profile-product-search')),
    query,
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ValueKey<String>('meal-profile-product-option-$productId')),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectDropdownOption(
  WidgetTester tester, {
  required ValueKey<String> fieldKey,
  required String optionText,
}) async {
  await tester.ensureVisible(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

void _setLargeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
