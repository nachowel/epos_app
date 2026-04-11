import 'package:epos_app/domain/models/product_modifier.dart';
import 'package:epos_app/presentation/screens/pos/widgets/pos_operator_speed_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildPinnedModifierPresentation', () {
    test(
      'pinned modifiers do not duplicate base options and base order stays stable',
      () {
        final List<ProductModifier> modifiers = <ProductModifier>[
          _modifier(1, 'A'),
          _modifier(2, 'B'),
          _modifier(3, 'C'),
          _modifier(4, 'D'),
          _modifier(5, 'E'),
          _modifier(6, 'F'),
          _modifier(7, 'G'),
          _modifier(8, 'H'),
        ];

        final PinnedModifierPresentation presentation =
            buildPinnedModifierPresentation(
              modifiers: modifiers,
              usageCounts: const <int, int>{4: 3, 2: 2, 7: 1, 5: 1},
              maxPinned: 3,
            );

        expect(
          presentation.pinned.map((ProductModifier modifier) => modifier.id),
          <int>[4, 2, 5],
        );
        expect(
          presentation.base.map((ProductModifier modifier) => modifier.id),
          <int>[1, 3, 6, 7, 8],
        );
        expect(
          presentation.base.any(
            (ProductModifier modifier) =>
                presentation.pinned.contains(modifier),
          ),
          isFalse,
        );
      },
    );

    test('base list remains unchanged when no usage data exists', () {
      final List<ProductModifier> modifiers = <ProductModifier>[
        _modifier(11, 'Ketchup'),
        _modifier(12, 'Brown sauce'),
        _modifier(13, 'Burger sauce'),
        _modifier(14, 'Mayonnaise'),
        _modifier(15, 'Mustard'),
        _modifier(16, 'Relish'),
        _modifier(17, 'Garlic sauce'),
      ];

      final PinnedModifierPresentation presentation =
          buildPinnedModifierPresentation(
            modifiers: modifiers,
            usageCounts: const <int, int>{},
          );

      expect(presentation.pinned, isEmpty);
      expect(presentation.base, modifiers);
    });
  });

  group('buildModifierScanGroups', () {
    test(
      'base options are grouped by stable leading character without reordering',
      () {
        final List<ProductModifier> modifiers = <ProductModifier>[
          _modifier(1, 'Aioli'),
          _modifier(2, 'BBQ'),
          _modifier(3, 'Brown sauce'),
          _modifier(4, 'Chilli'),
          _modifier(5, '2x Cheese'),
        ];

        final List<ModifierScanGroup> groups = buildModifierScanGroups(
          modifiers,
        );

        expect(groups.map((ModifierScanGroup group) => group.label), <String>[
          'A',
          'B',
          'C',
          '2',
        ]);
        expect(
          groups[1].modifiers.map((ProductModifier modifier) => modifier.name),
          <String>['BBQ', 'Brown sauce'],
        );
      },
    );
  });

  group('CartActiveEditContext', () {
    test('repeated quantity corrections keep the same active context', () {
      CartActiveEditContext context = const CartActiveEditContext().focusItem(
        'line-1',
      );

      context = context.beginQuantityCorrection('line-1');
      context = context.beginQuantityCorrection('line-1');
      context = context.beginQuantityCorrection('line-1');

      expect(context.selectedLocalId, 'line-1');
      expect(context.activeCorrectionLocalId, 'line-1');
      expect(context.activeCorrectionTapCount, 3);
    });

    test(
      'prune removes stale active context when the item leaves the cart',
      () {
        final CartActiveEditContext context = const CartActiveEditContext()
            .focusItem('line-1', resetCorrectionSequence: false)
            .beginQuantityCorrection('line-1')
            .prune(const <String>['line-2']);

        expect(context.selectedLocalId, isNull);
        expect(context.activeCorrectionLocalId, isNull);
        expect(context.activeCorrectionTapCount, 0);
      },
    );

    test('adjacent selection returns the next cart line in edit mode', () {
      final CartActiveEditContext context = const CartActiveEditContext(
        selectedLocalId: 'line-2',
      );

      expect(
        context.adjacentSelection(const <String>[
          'line-1',
          'line-2',
          'line-3',
        ], 1),
        'line-3',
      );
      expect(
        context.adjacentSelection(const <String>[
          'line-1',
          'line-2',
          'line-3',
        ], -1),
        'line-1',
      );
    });
  });
}

ProductModifier _modifier(int id, String name) {
  return ProductModifier(
    id: id,
    productId: 100,
    name: name,
    type: ModifierType.extra,
    extraPriceMinor: 0,
    isActive: true,
    priceBehavior: ModifierPriceBehavior.free,
    uiSection: ModifierUiSection.sauces,
  );
}
