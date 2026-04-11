import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/data/repositories/breakfast_configuration_repository.dart';
import 'package:epos_app/domain/models/breakfast_rebuild.dart';
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
    'included item chip keeps cook icon separate from remove toggle',
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
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-102')),
        findsNothing,
      );
      expect(find.text('1 removed'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-cooking-trigger-101')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('semantic-cooking-selector-101')),
        findsOneWidget,
      );
      expect(find.text('1 removed'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('semantic-include-101')),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 removed'), findsOneWidget);
    },
  );
}
