import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/domain/models/breakfast_cart_selection.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
import 'package:epos_app/domain/models/order_modifier.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/domain/models/semantic_product_configuration.dart';
import 'package:epos_app/domain/services/breakfast_pos_service.dart';
import 'package:epos_app/presentation/screens/pos/widgets/semantic_bundle_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets(
    'Egg customization panel is hidden initially and cook icon does not remove item',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = createTestDatabase();
      addTearDown(db.close);

      final BreakfastPosService service = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );

      const Product product = Product(
        id: 1,
        categoryId: 1,
        name: 'Set Breakfast',
        priceMinor: 650,
        imageUrl: null,
        hasModifiers: false,
        isActive: true,
        sortOrder: 0,
      );

      const BreakfastSetConfiguration configuration = BreakfastSetConfiguration(
        setRootProductId: 1,
        setItems: <BreakfastSetItemConfig>[
          BreakfastSetItemConfig(
            setItemId: 1,
            itemProductId: 101,
            itemName: 'Egg',
            defaultQuantity: 1,
            isRemovable: true,
            sortOrder: 0,
          ),
          BreakfastSetItemConfig(
            setItemId: 2,
            itemProductId: 102,
            itemName: 'Beans',
            defaultQuantity: 1,
            isRemovable: true,
            sortOrder: 1,
          ),
        ],
        choiceGroups: <BreakfastChoiceGroupConfig>[],
        extras: <BreakfastExtraItemConfig>[],
        menuSettings: BreakfastMenuSettings(freeSwapLimit: 0, maxSwaps: 0),
        catalogProductsById: <int, BreakfastCatalogProduct>{
          101: BreakfastCatalogProduct(id: 101, name: 'Egg', priceMinor: 0),
          102: BreakfastCatalogProduct(id: 102, name: 'Beans', priceMinor: 0),
        },
      );

      final BreakfastPosSelectionPreview preview = service.previewSelection(
        product: product,
        configuration: configuration,
        requestedState: const BreakfastRequestedState(),
      );

      final BreakfastPosEditorData editorData = BreakfastPosEditorData(
        product: product,
        profile: const ProductMenuConfigurationProfile(
          productId: 1,
          flatModifierCount: 0,
          setItemCount: 2,
          choiceGroupCount: 0,
          choiceMemberCount: 0,
        ),
        configuration: configuration,
        preview: preview,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            breakfastPosServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SemanticBundleEditorDialog(
                  product: product,
                  initialEditorData: editorData,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('semantic-egg-customization-101')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-102')),
        findsNothing,
      );
      expect(find.text('1 removed'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-101')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-egg-customization-101')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('semantic-cooking-selector-101')),
        findsNothing,
      );
      expect(find.text('1 removed'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-include-101')),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 removed'), findsOneWidget);
    },
  );

  testWidgets(
    'Set 1 Egg customization panel expands collapses and emits modifiers',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = createTestDatabase();
      addTearDown(db.close);
      final BreakfastPosService service = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      const Product product = Product(
        id: 1,
        categoryId: 1,
        name: 'Set 1',
        priceMinor: 850,
        imageUrl: null,
        hasModifiers: false,
        isActive: true,
        sortOrder: 0,
      );
      const BreakfastSetConfiguration configuration = BreakfastSetConfiguration(
        setRootProductId: 1,
        setItems: <BreakfastSetItemConfig>[
          BreakfastSetItemConfig(
            setItemId: 1,
            itemProductId: 101,
            itemName: 'Egg',
            defaultQuantity: 1,
            isRemovable: true,
            sortOrder: 0,
          ),
          BreakfastSetItemConfig(
            setItemId: 2,
            itemProductId: 102,
            itemName: 'Bacon',
            defaultQuantity: 1,
            isRemovable: true,
            sortOrder: 1,
          ),
        ],
        choiceGroups: <BreakfastChoiceGroupConfig>[],
        extras: <BreakfastExtraItemConfig>[],
        menuSettings: BreakfastMenuSettings(freeSwapLimit: 0, maxSwaps: 0),
        catalogProductsById: <int, BreakfastCatalogProduct>{
          101: BreakfastCatalogProduct(id: 101, name: 'Egg', priceMinor: 0),
          102: BreakfastCatalogProduct(id: 102, name: 'Bacon', priceMinor: 0),
        },
      );
      final BreakfastPosSelectionPreview preview = service.previewSelection(
        product: product,
        configuration: configuration,
        requestedState: const BreakfastRequestedState(),
      );
      final BreakfastPosEditorData editorData = BreakfastPosEditorData(
        product: product,
        profile: const ProductMenuConfigurationProfile(
          productId: 1,
          flatModifierCount: 0,
          setItemCount: 2,
          choiceGroupCount: 0,
          choiceMemberCount: 0,
        ),
        configuration: configuration,
        preview: preview,
      );

      late Future<BreakfastCartSelection?> dialogResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            breakfastPosServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: FilledButton(
                    onPressed: () {
                      dialogResult = showDialog<BreakfastCartSelection>(
                        context: context,
                        builder: (_) => SemanticBundleEditorDialog(
                          product: product,
                          initialEditorData: editorData,
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-egg-customization-101')),
        findsNothing,
      );
      expect(find.text('Egg Type'), findsNothing);
      expect(find.text('Poached Egg'), findsNothing);
      expect(find.text('Scrambled Egg'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-101')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-egg-customization-101')),
        findsOneWidget,
      );
      expect(find.text('Egg Type'), findsOneWidget);
      expect(find.text('Fried Egg'), findsOneWidget);
      expect(find.text('Poached Egg'), findsOneWidget);
      expect(find.text('Scrambled Egg'), findsOneWidget);
      expect(find.text('Cook Preference'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Runny'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Well done'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-101')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-egg-customization-101')),
        findsNothing,
      );
      expect(find.text('Poached Egg'), findsNothing);
      expect(find.text('Scrambled Egg'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-101')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-egg-type-101-poached')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-egg-cook-101-well_done')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      await tester.pumpAndSettle();

      final BreakfastCartSelection? result = await dialogResult;
      expect(result, isNotNull);
      final List<BreakfastClassifiedModifier> modifiers =
          result!.rebuildResult.classifiedModifiers;
      expect(
        modifiers.map(
          (BreakfastClassifiedModifier modifier) => modifier.action,
        ),
        everyElement(ModifierAction.add),
      );
      expect(
        modifiers.map(
          (BreakfastClassifiedModifier modifier) => modifier.displayName,
        ),
        containsAll(<String>['Egg: Poached Egg', 'Cook: Well done']),
      );
      expect(
        modifiers.map(
          (BreakfastClassifiedModifier modifier) => modifier.priceEffectMinor,
        ),
        everyElement(0),
      );
    },
  );

  testWidgets(
    'Bread Type customization is collapsed persists selection and emits non-default modifier',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = createTestDatabase();
      addTearDown(db.close);
      final BreakfastPosService service = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      const Product product = Product(
        id: 1,
        categoryId: 1,
        name: 'Set 1',
        priceMinor: 850,
        imageUrl: null,
        hasModifiers: false,
        isActive: true,
        sortOrder: 0,
      );
      const BreakfastSetConfiguration configuration = BreakfastSetConfiguration(
        setRootProductId: 1,
        setItems: <BreakfastSetItemConfig>[
          BreakfastSetItemConfig(
            setItemId: 1,
            itemProductId: 101,
            itemName: 'Egg',
            defaultQuantity: 1,
            isRemovable: true,
            sortOrder: 0,
          ),
          BreakfastSetItemConfig(
            setItemId: 2,
            itemProductId: 103,
            itemName: 'Bread',
            defaultQuantity: 1,
            isRemovable: true,
            sortOrder: 1,
          ),
        ],
        choiceGroups: <BreakfastChoiceGroupConfig>[],
        extras: <BreakfastExtraItemConfig>[],
        menuSettings: BreakfastMenuSettings(freeSwapLimit: 0, maxSwaps: 0),
        catalogProductsById: <int, BreakfastCatalogProduct>{
          101: BreakfastCatalogProduct(id: 101, name: 'Egg', priceMinor: 0),
          103: BreakfastCatalogProduct(id: 103, name: 'Bread', priceMinor: 0),
        },
      );
      final BreakfastPosSelectionPreview preview = service.previewSelection(
        product: product,
        configuration: configuration,
        requestedState: const BreakfastRequestedState(),
      );
      final BreakfastPosEditorData editorData = BreakfastPosEditorData(
        product: product,
        profile: const ProductMenuConfigurationProfile(
          productId: 1,
          flatModifierCount: 0,
          setItemCount: 2,
          choiceGroupCount: 0,
          choiceMemberCount: 0,
        ),
        configuration: configuration,
        preview: preview,
      );

      late Future<BreakfastCartSelection?> dialogResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            breakfastPosServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: FilledButton(
                    onPressed: () {
                      dialogResult = showDialog<BreakfastCartSelection>(
                        context: context,
                        builder: (_) => SemanticBundleEditorDialog(
                          product: product,
                          initialEditorData: editorData,
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-bread-customization-103')),
        findsNothing,
      );
      expect(find.text('Bread Type'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-103')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-103')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-bread-customization-103')),
        findsOneWidget,
      );
      expect(find.text('Bread Type'), findsOneWidget);
      expect(find.text('Crusty Bread'), findsOneWidget);
      expect(find.text('Normal Bread'), findsOneWidget);
      expect(find.text('Brown Bread'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-bread-type-103-brown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-101')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-bread-customization-103')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('semantic-egg-customization-101')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-103')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-egg-customization-101')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('semantic-bread-customization-103')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      await tester.pumpAndSettle();

      final BreakfastCartSelection? result = await dialogResult;
      expect(result, isNotNull);
      expect(
        result!.requestedState.customModifiers,
        const <BreakfastCustomModifierRequest>[
          BreakfastCustomModifierRequest(
            itemProductId: 103,
            itemName: 'Bread: Brown Bread',
            sortKey: 3,
          ),
        ],
      );
      expect(
        result.rebuildResult.classifiedModifiers.map(
          (BreakfastClassifiedModifier modifier) => modifier.displayName,
        ),
        contains('Bread: Brown Bread'),
      );
      expect(
        result.rebuildResult.classifiedModifiers.single.priceEffectMinor,
        0,
      );
    },
  );

  testWidgets('Bread Type default emits no modifier', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = createTestDatabase();
    addTearDown(db.close);
    final BreakfastPosService service = BreakfastPosService(
      breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
    );
    const Product product = Product(
      id: 1,
      categoryId: 1,
      name: 'Set 1',
      priceMinor: 850,
      imageUrl: null,
      hasModifiers: false,
      isActive: true,
      sortOrder: 0,
    );
    const BreakfastSetConfiguration configuration = BreakfastSetConfiguration(
      setRootProductId: 1,
      setItems: <BreakfastSetItemConfig>[
        BreakfastSetItemConfig(
          setItemId: 1,
          itemProductId: 103,
          itemName: 'Bread',
          defaultQuantity: 1,
          isRemovable: true,
          sortOrder: 1,
        ),
      ],
      choiceGroups: <BreakfastChoiceGroupConfig>[],
      extras: <BreakfastExtraItemConfig>[],
      menuSettings: BreakfastMenuSettings(freeSwapLimit: 0, maxSwaps: 0),
      catalogProductsById: <int, BreakfastCatalogProduct>{
        103: BreakfastCatalogProduct(id: 103, name: 'Bread', priceMinor: 0),
      },
    );
    final BreakfastPosSelectionPreview preview = service.previewSelection(
      product: product,
      configuration: configuration,
      requestedState: const BreakfastRequestedState(),
    );
    final BreakfastPosEditorData editorData = BreakfastPosEditorData(
      product: product,
      profile: const ProductMenuConfigurationProfile(
        productId: 1,
        flatModifierCount: 0,
        setItemCount: 1,
        choiceGroupCount: 0,
        choiceMemberCount: 0,
      ),
      configuration: configuration,
      preview: preview,
    );

    late Future<BreakfastCartSelection?> dialogResult;
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          breakfastPosServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () {
                    dialogResult = showDialog<BreakfastCartSelection>(
                      context: context,
                      builder: (_) => SemanticBundleEditorDialog(
                        product: product,
                        initialEditorData: editorData,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('semantic-cooking-trigger-103')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('semantic-bread-type-103-crusty')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
    );
    await tester.pumpAndSettle();

    final BreakfastCartSelection? result = await dialogResult;
    expect(result, isNotNull);
    expect(result!.requestedState.customModifiers, isEmpty);
    expect(result.rebuildResult.classifiedModifiers, isEmpty);
  });

  testWidgets(
    'Bread choice options show Bread Type only after customization icon tap',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = createTestDatabase();
      addTearDown(db.close);
      final BreakfastPosService service = BreakfastPosService(
        breakfastConfigurationRepository: BreakfastConfigurationRepository(db),
      );
      const Product product = Product(
        id: 1,
        categoryId: 1,
        name: 'Set 1',
        priceMinor: 850,
        imageUrl: null,
        hasModifiers: false,
        isActive: true,
        sortOrder: 0,
      );
      const int breadGroupId = 7;
      const int toastProductId = 201;
      const int breadProductId = 202;
      const BreakfastSetConfiguration configuration = BreakfastSetConfiguration(
        setRootProductId: 1,
        setItems: <BreakfastSetItemConfig>[],
        choiceGroups: <BreakfastChoiceGroupConfig>[
          BreakfastChoiceGroupConfig(
            groupId: breadGroupId,
            groupName: 'Bread',
            minSelect: 1,
            maxSelect: 1,
            includedQuantity: 1,
            sortOrder: 1,
            members: <BreakfastChoiceGroupMemberConfig>[
              BreakfastChoiceGroupMemberConfig(
                productModifierId: 1,
                itemProductId: toastProductId,
                displayName: 'Toasts',
              ),
              BreakfastChoiceGroupMemberConfig(
                productModifierId: 2,
                itemProductId: breadProductId,
                displayName: 'Breads',
              ),
            ],
          ),
        ],
        extras: <BreakfastExtraItemConfig>[],
        menuSettings: BreakfastMenuSettings(freeSwapLimit: 0, maxSwaps: 0),
        catalogProductsById: <int, BreakfastCatalogProduct>{
          toastProductId: BreakfastCatalogProduct(
            id: toastProductId,
            name: 'Toasts',
            priceMinor: 0,
          ),
          breadProductId: BreakfastCatalogProduct(
            id: breadProductId,
            name: 'Breads',
            priceMinor: 0,
          ),
        },
      );
      final BreakfastPosSelectionPreview preview = service.previewSelection(
        product: product,
        configuration: configuration,
        requestedState: const BreakfastRequestedState(),
      );
      final BreakfastPosEditorData editorData = BreakfastPosEditorData(
        product: product,
        profile: const ProductMenuConfigurationProfile(
          productId: 1,
          flatModifierCount: 0,
          setItemCount: 0,
          choiceGroupCount: 1,
          choiceMemberCount: 2,
        ),
        configuration: configuration,
        preview: preview,
      );

      late Future<BreakfastCartSelection?> dialogResult;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            breakfastPosServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: FilledButton(
                    onPressed: () {
                      dialogResult = showDialog<BreakfastCartSelection>(
                        context: context,
                        builder: (_) => SemanticBundleEditorDialog(
                          product: product,
                          initialEditorData: editorData,
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Bread Type'), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>(
            'semantic-choice-customize-$breadGroupId-$toastProductId',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey<String>(
            'semantic-choice-customize-$breadGroupId-$breadProductId',
          ),
        ),
        findsOneWidget,
      );
      final double toastsLabelCenterY = tester
          .getCenter(find.text('Toasts').last)
          .dy;
      final double toastsCustomizeCenterY = tester
          .getCenter(
            find.byKey(
              const ValueKey<String>(
                'semantic-choice-customize-$breadGroupId-$toastProductId',
              ),
            ),
          )
          .dy;
      expect((toastsLabelCenterY - toastsCustomizeCenterY).abs(), lessThan(8));

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'semantic-choice-customize-$breadGroupId-$toastProductId',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bread Type'), findsOneWidget);
      expect(find.text('Crusty Bread'), findsOneWidget);
      expect(find.text('Normal Bread'), findsOneWidget);
      expect(find.text('Brown Bread'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey<String>(
            'semantic-choice-customize-$breadGroupId-$breadProductId',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey<String>('semantic-bread-type-$breadProductId-normal'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-bundle-confirm')),
      );
      await tester.pumpAndSettle();

      final BreakfastCartSelection? result = await dialogResult;
      expect(result, isNotNull);
      expect(
        result!.requestedState.chosenGroups,
        const <BreakfastChosenGroupRequest>[
          BreakfastChosenGroupRequest(
            groupId: breadGroupId,
            selectedItemProductId: breadProductId,
            requestedQuantity: 1,
          ),
        ],
      );
      expect(
        result.requestedState.customModifiers,
        const <BreakfastCustomModifierRequest>[
          BreakfastCustomModifierRequest(
            itemProductId: breadProductId,
            itemName: 'Bread: Normal Bread',
            sortKey: 3,
          ),
        ],
      );
    },
  );
}
