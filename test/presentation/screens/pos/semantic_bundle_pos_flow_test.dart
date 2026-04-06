import 'package:drift/drift.dart' show Value;
import 'package:epos_app/core/errors/exceptions.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/database/app_database.dart';
import 'package:epos_app/domain/models/breakfast_cooking_instruction.dart';
import 'package:epos_app/domain/models/breakfast_cart_selection.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/cart_provider.dart';
import 'package:epos_app/presentation/providers/cart_models.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:epos_app/presentation/screens/pos/widgets/cart_line_tile.dart';
import 'package:epos_app/presentation/screens/pos/widgets/modifier_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets(
    'row-local cooking trigger captures structured cooking intent for applicable items only',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _PosSemanticFixture fixture = await _seedPosSemanticFixture(db);
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
          .loadUserById(fixture.cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Breakfast').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey<String>('semantic-cooking-trigger-${fixture.eggProductId}'),
        ),
        findsOneWidget,
      );
      expect(find.text('Drink: Missing'), findsNothing);
      expect(
        find.byKey(
          ValueKey<String>(
            'semantic-sticky-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Cook'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey<String>(
            'semantic-cooking-trigger-${fixture.beansProductId}',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-cooking-selector-${fixture.eggProductId}'),
        ),
        findsNothing,
      );

      final Finder eggCookingTrigger = find.byKey(
        ValueKey<String>('semantic-cooking-trigger-${fixture.eggProductId}'),
      );
      await tester.ensureVisible(eggCookingTrigger);
      await tester.tap(eggCookingTrigger, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey<String>('semantic-cooking-selector-${fixture.eggProductId}'),
        ),
        findsOneWidget,
      );

      final Finder runnyOption = find.byKey(
        ValueKey<String>(
          'semantic-cooking-option-${fixture.eggProductId}-runny',
        ),
      );
      await tester.ensureVisible(runnyOption);
      await tester.tap(runnyOption, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey<String>('semantic-cooking-status-${fixture.eggProductId}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-cooking-selector-${fixture.eggProductId}'),
        ),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(
                ValueKey<String>(
                  'semantic-cooking-status-${fixture.eggProductId}',
                ),
              ),
            )
            .data,
        'Egg — Runny',
      );
      expect(find.text('Drink: Missing'), findsNothing);
      expect(find.text('Runny'), findsWidgets);

      final Finder teaChoice = find.byKey(
        ValueKey<String>(
          'semantic-sticky-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
        ),
      );
      await tester.ensureVisible(teaChoice);
      await tester.tap(teaChoice, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                ValueKey<String>(
                  'semantic-sticky-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
                ),
              ),
            )
            .onPressed,
        isNotNull,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      await tester.pumpAndSettle();

      final List<BreakfastCookingInstructionRequest> instructions = container
          .read(cartNotifierProvider)
          .items
          .single
          .breakfastSelection!
          .requestedState
          .cookingInstructions;
      expect(instructions, hasLength(1));
      expect(instructions.single.itemProductId, fixture.eggProductId);
      expect(instructions.single.instructionCode, 'runny');
      expect(instructions.single.instructionLabel, 'Runny');
    },
  );

  testWidgets(
    'cart summary shows structured breakfast lines without swap terminology',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: CartLineTile(
              item: CartItem(
                localId: 'cart-1',
                productId: 1,
                productName: 'Set Breakfast',
                unitPriceMinor: 600,
                hasModifiers: false,
                quantity: 1,
                modifiers: const <CartModifier>[],
                breakfastSelection: const BreakfastCartSelection(
                  requestedState: BreakfastRequestedState(),
                  rebuildResult: BreakfastRebuildResult(
                    lineSnapshot: BreakfastLineSnapshot(
                      baseUnitPriceMinor: 600,
                      removalDiscountTotalMinor: 0,
                      modifierTotalMinor: 0,
                      lineTotalMinor: 600,
                    ),
                    classifiedModifiers: <BreakfastClassifiedModifier>[],
                    pricingBreakdown: BreakfastPricingBreakdown(
                      basePriceMinor: 600,
                      extraAddTotalMinor: 0,
                      paidSwapTotalMinor: 0,
                      freeSwapTotalMinor: 0,
                      includedChoiceTotalMinor: 0,
                      removeTotalMinor: 0,
                      removalDiscountTotalMinor: 0,
                      finalLineTotalMinor: 600,
                    ),
                    validationErrors: <BreakfastEditErrorCode>[],
                    rebuildMetadata: BreakfastRebuildMetadata(
                      replacementCount: 0,
                      unmatchedRemovalCount: 0,
                    ),
                  ),
                  modifierDisplayLines: <BreakfastCartModifierDisplayLine>[
                    BreakfastCartModifierDisplayLine(
                      prefix: '-',
                      itemName: 'Sausage',
                      tone: BreakfastCartModifierTone.removed,
                    ),
                    BreakfastCartModifierDisplayLine(
                      prefix: '+',
                      itemName: 'Egg',
                      tone: BreakfastCartModifierTone.added,
                    ),
                    BreakfastCartModifierDisplayLine(
                      prefix: '+',
                      itemName: 'Hash Brown',
                      tone: BreakfastCartModifierTone.added,
                    ),
                  ],
                  choiceDisplayLines: <BreakfastCartChoiceDisplayLine>[
                    BreakfastCartChoiceDisplayLine(
                      groupName: 'Drink',
                      selectedLabel: 'Tea',
                    ),
                    BreakfastCartChoiceDisplayLine(
                      groupName: 'Bread',
                      selectedLabel: 'Toast',
                    ),
                  ],
                  cookingDisplayLines: <BreakfastCookingInstructionDisplayLine>[
                    BreakfastCookingInstructionDisplayLine(
                      itemName: 'Egg',
                      instructionLabel: 'RUNNY',
                    ),
                    BreakfastCookingInstructionDisplayLine(
                      itemName: 'Bacon',
                      instructionLabel: 'CRISPY',
                    ),
                  ],
                ),
              ),
              onIncrease: () {},
              onDecrease: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('- Sausage'), findsOneWidget);
      expect(find.text('+ Egg'), findsOneWidget);
      expect(find.text('+ Hash Brown'), findsOneWidget);
      expect(find.text('Tea · Toast'), findsOneWidget);
      expect(find.text('Drink: Tea'), findsNothing);
      expect(find.text('Bread: Toast'), findsNothing);
      expect(find.text('Egg: RUNNY'), findsOneWidget);
      expect(find.text('Bacon: CRISPY'), findsOneWidget);
    },
  );

  testWidgets(
    'removing an included item clears stale cooking display and intent',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _PosSemanticFixture fixture = await _seedPosSemanticFixture(db);
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
          .loadUserById(fixture.cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Breakfast').last);
      await tester.pumpAndSettle();

      final Finder eggCookingTrigger = find.byKey(
        ValueKey<String>('semantic-cooking-trigger-${fixture.eggProductId}'),
      );
      await tester.ensureVisible(eggCookingTrigger);
      await tester.tap(eggCookingTrigger, warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>(
            'semantic-cooking-option-${fixture.eggProductId}-runny',
          ),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.text('Egg — Runny'), findsOneWidget);

      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-include-${fixture.eggProductId}'),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-include-remove-${fixture.eggProductId}-2'),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey<String>('semantic-cooking-trigger-${fixture.eggProductId}'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-cooking-status-${fixture.eggProductId}'),
        ),
        findsNothing,
      );

      final Finder teaChoice = find.byKey(
        ValueKey<String>(
          'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
        ),
      );
      await tester.ensureVisible(teaChoice);
      await tester.tap(teaChoice, warnIfMissed: false);
      await tester.pumpAndSettle();

      final Finder confirmButton = find.byKey(
        const ValueKey<String>('semantic-bundle-confirm'),
      );
      await tester.ensureVisible(confirmButton);
      expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNotNull);
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      final cartState = container.read(cartNotifierProvider);
      expect(cartState.items, hasLength(1));
      expect(
        cartState
            .items
            .single
            .breakfastSelection!
            .requestedState
            .cookingInstructions,
        isEmpty,
      );
      expect(find.text('Egg: Runny'), findsNothing);
    },
  );

  testWidgets(
    'semantic product preselects breakfast defaults and allows immediate confirm',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _PosSemanticFixture fixture = await _seedPosSemanticFixture(
        db,
        includeBreadGroup: true,
        includeLatteOption: true,
      );
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
          .loadUserById(fixture.cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Breakfast').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
        findsOneWidget,
      );
      expect(find.byType(ModifierPopup), findsNothing);

      final ElevatedButton enabledConfirm = tester.widget<ElevatedButton>(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      expect(enabledConfirm.onPressed, isNotNull);
      expect(
        find.byKey(const ValueKey<String>('semantic-required-summary-bar')),
        findsOneWidget,
      );
      final Finder cancelButton = find.byKey(
        const ValueKey<String>('semantic-bundle-cancel'),
      );
      final Finder confirmButton = find.byKey(
        const ValueKey<String>('semantic-bundle-confirm'),
      );
      expect(cancelButton, findsOneWidget);
      expect(confirmButton, findsOneWidget);
      expect(tester.getSize(cancelButton).height, greaterThanOrEqualTo(54));
      expect(tester.getSize(confirmButton).height, greaterThanOrEqualTo(58));
      expect(tester.getSize(confirmButton).width, greaterThanOrEqualTo(188));
      expect(
        tester.getTopLeft(confirmButton).dx -
            tester.getTopRight(cancelButton).dx,
        greaterThanOrEqualTo(12),
      );
      expect(find.text('Drink: Missing'), findsNothing);
      expect(find.text('1 choice pending'), findsNothing);
      expect(find.text('Finish required choices to continue'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('semantic-scroll-required-choices')),
        findsNothing,
      );
      expect(
        find.byKey(
          ValueKey<String>(
            'semantic-sticky-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>(
            'semantic-sticky-choice-select-${fixture.drinkGroupId}-${fixture.latteProductId!}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>(
            'semantic-sticky-choice-select-${fixture.breadGroupId!}-${fixture.toastProductId!}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>(
            'semantic-sticky-choice-none-${fixture.drinkGroupId}',
          ),
        ),
        findsOneWidget,
      );
      final Finder includedSection = find.byKey(
        const ValueKey<String>('semantic-section-included-items'),
      );
      final Finder extrasSection = find.byKey(
        const ValueKey<String>('semantic-section-extras'),
      );
      final Finder requiredChoicesSection = find.byKey(
        const ValueKey<String>('semantic-section-required-choices'),
      );
      expect(includedSection, findsOneWidget);
      expect(extrasSection, findsOneWidget);
      expect(requiredChoicesSection, findsOneWidget);
      expect(
        tester.getTopLeft(includedSection).dy,
        lessThan(tester.getTopLeft(extrasSection).dy),
      );
      expect(
        tester.getTopLeft(extrasSection).dy,
        lessThan(tester.getTopLeft(requiredChoicesSection).dy),
      );

      await tester.ensureVisible(
        find.byKey(
          ValueKey<String>('semantic-include-${fixture.beansProductId}'),
        ),
      );
      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-include-${fixture.beansProductId}'),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey<String>(
            'semantic-include-remove-${fixture.beansProductId}-1',
          ),
        ),
        findsNothing,
      );

      expect(
        find.byKey(
          ValueKey<String>('semantic-add-inc-${fixture.hashBrownProductId}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-add-inc-${fixture.teaProductId}'),
        ),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(
          ValueKey<String>('semantic-add-inc-${fixture.hashBrownProductId}'),
        ),
      );
      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-add-inc-${fixture.hashBrownProductId}'),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      await tester.pumpAndSettle();

      final cartState = container.read(cartNotifierProvider);
      expect(cartState.items, hasLength(1));
      final item = cartState.items.single;
      expect(item.breakfastSelection, isNotNull);
      expect(
        item.breakfastSelection!.requestedState.chosenGroups,
        containsAll(<Matcher>[
          isA<BreakfastChosenGroupRequest>()
              .having(
                (BreakfastChosenGroupRequest group) => group.groupId,
                'groupId',
                fixture.drinkGroupId,
              )
              .having(
                (BreakfastChosenGroupRequest group) =>
                    group.selectedItemProductId,
                'selectedItemProductId',
                fixture.latteProductId,
              ),
          isA<BreakfastChosenGroupRequest>()
              .having(
                (BreakfastChosenGroupRequest group) => group.groupId,
                'groupId',
                fixture.breadGroupId,
              )
              .having(
                (BreakfastChosenGroupRequest group) =>
                    group.selectedItemProductId,
                'selectedItemProductId',
                fixture.toastProductId,
              ),
        ]),
      );
      expect(
        item
            .breakfastSelection!
            .requestedState
            .removedSetItems
            .single
            .itemProductId,
        fixture.beansProductId,
      );
      expect(
        item
            .breakfastSelection!
            .requestedState
            .addedProducts
            .single
            .itemProductId,
        fixture.hashBrownProductId,
      );
      expect(find.text('Cappuccino/Latte · Toast'), findsOneWidget);
      expect(find.text('Drink: Cappuccino/Latte'), findsNothing);
      expect(find.text('Bread: Toast'), findsNothing);
    },
  );

  testWidgets(
    'breakfast defaults fall back to the first available option when preferred items are unavailable',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _PosSemanticFixture fixture = await _seedPosSemanticFixture(
        db,
        includeBreadGroup: true,
      );
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
          .loadUserById(fixture.cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Breakfast').last);
      await tester.pumpAndSettle();

      final Finder confirmButton = find.byKey(
        const ValueKey<String>('semantic-bundle-confirm'),
      );
      expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNotNull);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      final List<BreakfastChosenGroupRequest> chosenGroups = container
          .read(cartNotifierProvider)
          .items
          .single
          .breakfastSelection!
          .requestedState
          .chosenGroups;
      expect(
        chosenGroups,
        containsAll(<Matcher>[
          isA<BreakfastChosenGroupRequest>()
              .having(
                (BreakfastChosenGroupRequest group) => group.groupId,
                'groupId',
                fixture.drinkGroupId,
              )
              .having(
                (BreakfastChosenGroupRequest group) =>
                    group.selectedItemProductId,
                'selectedItemProductId',
                fixture.teaProductId,
              ),
          isA<BreakfastChosenGroupRequest>()
              .having(
                (BreakfastChosenGroupRequest group) => group.groupId,
                'groupId',
                fixture.breadGroupId,
              )
              .having(
                (BreakfastChosenGroupRequest group) =>
                    group.selectedItemProductId,
                'selectedItemProductId',
                fixture.toastProductId,
              ),
        ]),
      );
      expect(find.text('Tea · Toast'), findsOneWidget);
      expect(find.text('Drink: Tea'), findsNothing);
      expect(find.text('Bread: Toast'), findsNothing);
    },
  );

  testWidgets(
    'breakfast defaults resolve against live group names and label variants',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _PosSemanticFixture fixture = await _seedPosSemanticFixture(
        db,
        includeBreadGroup: true,
        includeLatteOption: true,
        drinkGroupName: 'Tea or Coffee',
        breadGroupName: 'Toast or Bread',
        latteChoiceLabel: 'Latte',
        toastChoiceLabel: 'Toasts',
        breadChoiceLabel: 'Breads',
      );
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
          .loadUserById(fixture.cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Breakfast').last);
      await tester.pumpAndSettle();

      final Finder confirmButton = find.byKey(
        const ValueKey<String>('semantic-bundle-confirm'),
      );
      expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNotNull);
      expect(find.text('2 pending'), findsNothing);
      expect(find.text('Pending'), findsNothing);
      expect(find.text('Finish required choices to continue'), findsNothing);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                ValueKey<String>(
                  'semantic-sticky-choice-select-${fixture.drinkGroupId}-${fixture.latteProductId!}',
                ),
              ),
            )
            .style
            ?.backgroundColor
            ?.resolve(<WidgetState>{WidgetState.selected}),
        isNotNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(
                ValueKey<String>(
                  'semantic-sticky-choice-select-${fixture.breadGroupId!}-${fixture.toastProductId!}',
                ),
              ),
            )
            .style
            ?.backgroundColor
            ?.resolve(<WidgetState>{WidgetState.selected}),
        isNotNull,
      );
      expect(find.text('Latte'), findsWidgets);
      expect(find.text('Toasts'), findsWidgets);

      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      final List<BreakfastChosenGroupRequest> chosenGroups = container
          .read(cartNotifierProvider)
          .items
          .single
          .breakfastSelection!
          .requestedState
          .chosenGroups;
      expect(
        chosenGroups,
        containsAll(<Matcher>[
          isA<BreakfastChosenGroupRequest>()
              .having(
                (BreakfastChosenGroupRequest group) => group.groupId,
                'groupId',
                fixture.drinkGroupId,
              )
              .having(
                (BreakfastChosenGroupRequest group) =>
                    group.selectedItemProductId,
                'selectedItemProductId',
                fixture.latteProductId,
              ),
          isA<BreakfastChosenGroupRequest>()
              .having(
                (BreakfastChosenGroupRequest group) => group.groupId,
                'groupId',
                fixture.breadGroupId,
              )
              .having(
                (BreakfastChosenGroupRequest group) =>
                    group.selectedItemProductId,
                'selectedItemProductId',
                fixture.toastProductId,
              ),
        ]),
      );
      expect(find.text('Latte · Toasts'), findsOneWidget);
      expect(find.text('Tea or Coffee: Latte'), findsNothing);
      expect(find.text('Toast or Bread: Toasts'), findsNothing);
    },
  );

  testWidgets(
    'multi-quantity included items capture unit-level removal intent before writing requested state',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final AppDatabase db = createTestDatabase();
      addTearDown(db.close);

      final _PosSemanticFixture fixture = await _seedPosSemanticFixture(db);
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
          .loadUserById(fixture.cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(_testApp(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set Breakfast').last);
      await tester.pumpAndSettle();

      final Finder eggRow = find.byKey(
        ValueKey<String>('semantic-include-${fixture.eggProductId}'),
      );

      expect(
        find.byKey(
          ValueKey<String>('semantic-include-status-${fixture.eggProductId}'),
        ),
        findsOneWidget,
      );
      expect(find.text('2 included'), findsOneWidget);

      await tester.ensureVisible(eggRow);
      await tester.tap(eggRow, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey<String>('semantic-include-remove-${fixture.eggProductId}-1'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-include-remove-${fixture.eggProductId}-2'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-include-remove-${fixture.eggProductId}-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 removed · 1 left'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey<String>('semantic-include-selector-${fixture.eggProductId}'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-include-remove-${fixture.eggProductId}-1'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-include-change-${fixture.eggProductId}'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-include-change-${fixture.eggProductId}'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 removed · 1 left'), findsOneWidget);
      expect(
        find.byKey(
          ValueKey<String>('semantic-include-selector-${fixture.eggProductId}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-include-remove-${fixture.eggProductId}-1'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey<String>('semantic-include-remove-${fixture.eggProductId}-2'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          ValueKey<String>('semantic-include-remove-${fixture.eggProductId}-1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(
          ValueKey<String>(
            'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
          ),
        ),
      );
      await tester.tap(
        find.byKey(
          ValueKey<String>(
            'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
          ),
        ),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      await tester.pumpAndSettle();

      final cartState = container.read(cartNotifierProvider);
      expect(cartState.items, hasLength(1));
      expect(
        cartState
            .items
            .single
            .breakfastSelection!
            .requestedState
            .removedSetItems,
        contains(
          isA<BreakfastRemovedSetItemRequest>()
              .having(
                (BreakfastRemovedSetItemRequest item) => item.itemProductId,
                'itemProductId',
                fixture.eggProductId,
              )
              .having(
                (BreakfastRemovedSetItemRequest item) => item.quantity,
                'quantity',
                1,
              ),
        ),
      );
    },
  );

  testWidgets('re-enabling a multi-quantity included item resets removed intent', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final _PosSemanticFixture fixture = await _seedPosSemanticFixture(db);
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
        .loadUserById(fixture.cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Breakfast').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(ValueKey<String>('semantic-include-${fixture.eggProductId}')),
    );
    await tester.tap(
      find.byKey(ValueKey<String>('semantic-include-${fixture.eggProductId}')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        ValueKey<String>('semantic-include-remove-${fixture.eggProductId}-2'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 removed'), findsOneWidget);
    expect(
      find.byKey(
        ValueKey<String>('semantic-include-selector-${fixture.eggProductId}'),
      ),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(ValueKey<String>('semantic-include-${fixture.eggProductId}')),
    );
    await tester.tap(
      find.byKey(ValueKey<String>('semantic-include-${fixture.eggProductId}')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.byKey(
              ValueKey<String>(
                'semantic-include-status-${fixture.eggProductId}',
              ),
            ),
          )
          .data,
      '2 included',
    );
    expect(
      find.byKey(
        ValueKey<String>('semantic-include-selector-${fixture.eggProductId}'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        ValueKey<String>('semantic-include-change-${fixture.eggProductId}'),
      ),
      findsNothing,
    );

    await tester.ensureVisible(
      find.byKey(
        ValueKey<String>(
          'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
        ),
      ),
    );
    final Finder teaChoice = find.byKey(
      ValueKey<String>(
        'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
      ),
    );
    await tester.ensureVisible(teaChoice);
    await tester.tap(teaChoice, warnIfMissed: false);
    await tester.pumpAndSettle();

    final Finder confirmButton = find.byKey(
      const ValueKey<String>('semantic-bundle-confirm'),
    );
    await tester.ensureVisible(confirmButton);
    expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNotNull);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    final cartState = container.read(cartNotifierProvider);
    expect(cartState.items, hasLength(1));
    expect(
      cartState.items.single.breakfastSelection!.requestedState.removedSetItems
          .where(
            (BreakfastRemovedSetItemRequest item) =>
                item.itemProductId == fixture.eggProductId,
          ),
      isEmpty,
    );
  });

  testWidgets('extras increment and decrement still map to requested intent', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final _PosSemanticFixture fixture = await _seedPosSemanticFixture(db);
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
        .loadUserById(fixture.cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Breakfast').last);
    await tester.pumpAndSettle();

    final Finder teaChoice = find.byKey(
      ValueKey<String>(
        'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
      ),
    );
    await tester.ensureVisible(teaChoice);
    await tester.tap(teaChoice, warnIfMissed: false);
    await tester.pumpAndSettle();

    final Finder hashBrownCard = find.byKey(
      ValueKey<String>('semantic-add-card-${fixture.hashBrownProductId}'),
    );
    final Finder hashBrownDecrease = find.byKey(
      ValueKey<String>('semantic-add-dec-${fixture.hashBrownProductId}'),
    );
    await tester.ensureVisible(hashBrownCard);
    await tester.tap(hashBrownCard);
    await tester.pumpAndSettle();
    await tester.ensureVisible(hashBrownCard);
    await tester.tap(hashBrownCard);
    await tester.pumpAndSettle();
    await tester.ensureVisible(hashBrownDecrease);
    await tester.tap(hashBrownDecrease);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(
              ValueKey<String>(
                'semantic-add-status-${fixture.hashBrownProductId}',
              ),
            ),
          )
          .data,
      '1 added',
    );

    final Finder confirmButton = find.byKey(
      const ValueKey<String>('semantic-bundle-confirm'),
    );
    await tester.ensureVisible(confirmButton);
    expect(tester.widget<ElevatedButton>(confirmButton).onPressed, isNotNull);
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    final cartState = container.read(cartNotifierProvider);
    expect(cartState.items, hasLength(1));
    expect(
      cartState.items.single.breakfastSelection!.requestedState.addedProducts,
      contains(
        isA<BreakfastAddedProductRequest>()
            .having(
              (BreakfastAddedProductRequest item) => item.itemProductId,
              'itemProductId',
              fixture.hashBrownProductId,
            )
            .having(
              (BreakfastAddedProductRequest item) => item.quantity,
              'quantity',
              1,
            ),
      ),
    );
  });

  testWidgets('semantic editor shows explicit no-answer options for required choices', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final _PosSemanticFixture fixture = await _seedPosSemanticFixture(db);
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
        .loadUserById(fixture.cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Breakfast').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        ValueKey<String>('semantic-choice-none-${fixture.drinkGroupId}'),
      ),
      findsOneWidget,
    );
    expect(find.text('No drink'), findsWidgets);

    final ElevatedButton disabledConfirm = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
    );
    expect(disabledConfirm.onPressed, isNotNull);

    final Finder teaChoice = find.byKey(
      ValueKey<String>(
        'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
      ),
    );
    await tester.ensureVisible(teaChoice);
    await tester.tap(teaChoice, warnIfMissed: false);
    await tester.pumpAndSettle();

    final ElevatedButton enabledConfirm = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
    );
    expect(enabledConfirm.onPressed, isNotNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
    );
    await tester.pumpAndSettle();

    final cartState = container.read(cartNotifierProvider);
    expect(cartState.items, hasLength(1));
    final chosenGroup = cartState
        .items
        .single
        .breakfastSelection!
        .requestedState
        .chosenGroups
        .single;
    expect(chosenGroup.groupId, fixture.drinkGroupId);
    expect(chosenGroup.selectedItemProductId, fixture.teaProductId);
    expect(chosenGroup.requestedQuantity, 1);
  });

  testWidgets('semantic editor requires answers for every required group', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final _PosSemanticFixture fixture = await _seedPosSemanticFixture(
      db,
      includeBreadGroup: true,
    );
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
        .loadUserById(fixture.cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Breakfast').last);
    await tester.pumpAndSettle();

    expect(find.text('Drink choice'), findsOneWidget);
    expect(find.text('Bread choice'), findsOneWidget);
    expect(find.text('Drink: Missing'), findsNothing);
    expect(find.text('Bread: Missing'), findsNothing);
    expect(find.text('2 pending'), findsNothing);
    expect(find.text('Pending'), findsNothing);
    expect(
      find.byKey(
        ValueKey<String>(
          'semantic-sticky-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey<String>('semantic-sticky-choice-none-${fixture.drinkGroupId}'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey<String>(
          'semantic-sticky-choice-none-${fixture.breadGroupId!}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey<String>('semantic-choice-none-${fixture.drinkGroupId}'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey<String>('semantic-choice-none-${fixture.breadGroupId!}'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey<String>(
          'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Coffee'), findsWidgets);
    expect(find.text('Toast'), findsWidgets);
    expect(find.text('Bread'), findsWidgets);

    ElevatedButton confirm = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
    );
    expect(confirm.onPressed, isNotNull);

    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'semantic-choice-select-${fixture.drinkGroupId}-${fixture.teaProductId}',
        ),
      ),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    confirm = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
    );
    expect(confirm.onPressed, isNotNull);

    await tester.tap(
      find.byKey(
        ValueKey<String>(
          'semantic-choice-select-${fixture.breadGroupId!}-${fixture.toastProductId!}',
        ),
      ),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    confirm = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
    );
    expect(confirm.onPressed, isNotNull);

    await tester.tap(
      find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
    );
    await tester.pumpAndSettle();

    final cartState = container.read(cartNotifierProvider);
    expect(cartState.items, hasLength(1));
    expect(
      cartState.items.single.breakfastSelection!.requestedState.chosenGroups,
      hasLength(2),
    );
    expect(
      cartState.items.single.breakfastSelection!.requestedState.chosenGroups
          .every(
            (group) =>
                group.selectedItemProductId != null &&
                group.requestedQuantity == 1,
          ),
      isTrue,
    );
  });

  testWidgets('flat modifier products still use the legacy popup path', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final _PosSemanticFixture fixture = await _seedPosSemanticFixture(db);
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
        .loadUserById(fixture.cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drinks').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flat Tea'));
    await tester.pumpAndSettle();

    expect(find.byType(ModifierPopup), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
      findsNothing,
    );
  });

  testWidgets('invalid semantic config blocks sale without opening dialog', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppDatabase db = createTestDatabase();
    addTearDown(db.close);

    final _PosSemanticFixture fixture = await _seedPosSemanticFixture(
      db,
      groupMaxSelect: 2,
    );
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
        .loadUserById(fixture.cashierId);
    await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

    await tester.pumpWidget(_testApp(container));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set Breakfast').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('semantic-bundle-dialog')),
      findsNothing,
    );
    expect(find.byType(ModifierPopup), findsNothing);
    expect(
      find.textContaining('POS currently supports one selection per group.'),
      findsOneWidget,
    );
  });
}

Future<_PosSemanticFixture> _seedPosSemanticFixture(
  AppDatabase db, {
  int groupMaxSelect = 1,
  bool includeBreadGroup = false,
  bool includeLatteOption = false,
  String drinkGroupName = 'Drink choice',
  String breadGroupName = 'Bread choice',
  String teaChoiceLabel = 'Tea',
  String coffeeChoiceLabel = 'Coffee',
  String latteChoiceLabel = 'Cappuccino/Latte',
  String toastChoiceLabel = 'Toast',
  String breadChoiceLabel = 'Bread',
  String drinkNoneLabel = 'No drink',
  String breadNoneLabel = 'No toast/bread',
}) async {
  final int cashierId = await insertUser(db, name: 'Cashier', role: 'cashier');
  await insertShift(db, openedBy: cashierId);

  final int breakfastCategoryId = await insertCategory(
    db,
    name: 'Set Breakfast',
  );
  final int drinkCategoryId = await insertCategory(db, name: 'Drinks');

  final int rootProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Set Breakfast',
    priceMinor: 600,
  );
  final int beansProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Beans',
    priceMinor: 80,
  );
  final int eggProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Egg',
    priceMinor: 120,
  );
  final int teaProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Tea',
    priceMinor: 150,
  );
  final int coffeeProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Coffee',
    priceMinor: 170,
  );
  int? latteProductId;
  if (includeLatteOption) {
    latteProductId = await insertProduct(
      db,
      categoryId: drinkCategoryId,
      name: 'Cappuccino/Latte',
      priceMinor: 180,
    );
  }
  final int flatProductId = await insertProduct(
    db,
    categoryId: drinkCategoryId,
    name: 'Flat Tea',
    priceMinor: 250,
    hasModifiers: true,
  );
  final int hashBrownProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Hash Brown',
    priceMinor: 130,
  );
  final int toastProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Toast',
    priceMinor: 100,
  );
  final int breadProductId = await insertProduct(
    db,
    categoryId: breakfastCategoryId,
    name: 'Bread',
    priceMinor: 90,
  );

  await db
      .into(db.setItems)
      .insert(
        SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: eggProductId,
          defaultQuantity: const Value<int>(2),
          sortOrder: const Value<int>(1),
          isRemovable: const Value<bool>(true),
        ),
      );
  await db
      .into(db.setItems)
      .insert(
        SetItemsCompanion.insert(
          productId: rootProductId,
          itemProductId: beansProductId,
          sortOrder: const Value<int>(2),
          isRemovable: const Value<bool>(true),
        ),
      );

  final int drinkGroupId = await db
      .into(db.modifierGroups)
      .insert(
        ModifierGroupsCompanion.insert(
          productId: rootProductId,
          name: drinkGroupName,
          minSelect: const Value<int>(1),
          maxSelect: Value<int>(groupMaxSelect),
          includedQuantity: const Value<int>(1),
          sortOrder: const Value<int>(1),
        ),
      );

  Future<void> insertChoiceMember({
    required int itemProductId,
    required String label,
  }) async {
    await db
        .into(db.productModifiers)
        .insert(
          ProductModifiersCompanion.insert(
            productId: rootProductId,
            groupId: Value<int?>(drinkGroupId),
            itemProductId: Value<int?>(itemProductId),
            name: label,
            type: 'choice',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }

  await insertChoiceMember(itemProductId: teaProductId, label: teaChoiceLabel);
  await insertChoiceMember(
    itemProductId: coffeeProductId,
    label: coffeeChoiceLabel,
  );
  if (latteProductId != null) {
    await insertChoiceMember(
      itemProductId: latteProductId,
      label: latteChoiceLabel,
    );
  }
  await db
      .into(db.productModifiers)
      .insert(
        ProductModifiersCompanion.insert(
          productId: rootProductId,
          groupId: Value<int?>(drinkGroupId),
          itemProductId: const Value<int?>(null),
          name: drinkNoneLabel,
          type: 'choice',
          extraPriceMinor: const Value<int>(0),
        ),
      );

  int? breadGroupId;
  if (includeBreadGroup) {
    breadGroupId = await db
        .into(db.modifierGroups)
        .insert(
          ModifierGroupsCompanion.insert(
            productId: rootProductId,
            name: breadGroupName,
            minSelect: const Value<int>(1),
            maxSelect: const Value<int>(1),
            includedQuantity: const Value<int>(1),
            sortOrder: const Value<int>(2),
          ),
        );

    Future<void> insertBreadChoiceMember({
      required int itemProductId,
      required String label,
    }) async {
      await db
          .into(db.productModifiers)
          .insert(
            ProductModifiersCompanion.insert(
              productId: rootProductId,
              groupId: Value<int?>(breadGroupId),
              itemProductId: Value<int?>(itemProductId),
              name: label,
              type: 'choice',
              extraPriceMinor: const Value<int>(0),
            ),
          );
    }

    await insertBreadChoiceMember(
      itemProductId: toastProductId,
      label: toastChoiceLabel,
    );
    await insertBreadChoiceMember(
      itemProductId: breadProductId,
      label: breadChoiceLabel,
    );
    await db
        .into(db.productModifiers)
        .insert(
          ProductModifiersCompanion.insert(
            productId: rootProductId,
            groupId: Value<int?>(breadGroupId),
            itemProductId: const Value<int?>(null),
            name: breadNoneLabel,
            type: 'choice',
            extraPriceMinor: const Value<int>(0),
          ),
        );
  }
  await db
      .into(db.productModifiers)
      .insert(
        ProductModifiersCompanion.insert(
          productId: rootProductId,
          itemProductId: Value<int?>(hashBrownProductId),
          name: 'Hash Brown',
          type: 'extra',
          extraPriceMinor: const Value<int>(0),
        ),
      );

  await db
      .into(db.productModifiers)
      .insert(
        ProductModifiersCompanion.insert(
          productId: flatProductId,
          name: 'Lemon',
          type: 'extra',
          extraPriceMinor: const Value<int>(20),
        ),
      );

  return _PosSemanticFixture(
    cashierId: cashierId,
    drinkGroupId: drinkGroupId,
    breadGroupId: breadGroupId,
    teaProductId: teaProductId,
    latteProductId: latteProductId,
    eggProductId: eggProductId,
    beansProductId: beansProductId,
    hashBrownProductId: hashBrownProductId,
    toastProductId: toastProductId,
  );
}

class _PosSemanticFixture {
  const _PosSemanticFixture({
    required this.cashierId,
    required this.drinkGroupId,
    required this.breadGroupId,
    required this.teaProductId,
    required this.latteProductId,
    required this.eggProductId,
    required this.beansProductId,
    required this.hashBrownProductId,
    required this.toastProductId,
  });

  final int cashierId;
  final int drinkGroupId;
  final int? breadGroupId;
  final int teaProductId;
  final int? latteProductId;
  final int eggProductId;
  final int beansProductId;
  final int hashBrownProductId;
  final int? toastProductId;
}

class _StaticOrdersNotifier extends OrdersNotifier {
  _StaticOrdersNotifier(super.ref);

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: false, errorMessage: null);
  }
}

Widget _testApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
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
