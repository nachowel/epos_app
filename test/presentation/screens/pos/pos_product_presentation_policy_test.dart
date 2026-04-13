import 'package:epos_app/domain/models/category.dart';
import 'package:epos_app/presentation/screens/pos/pos_product_presentation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all seeded POS categories resolve through explicit registry mappings', () {
    const List<({String name, ProductCardPresentationMode mode})>
    seededExpectations = <({String name, ProductCardPresentationMode mode})>[
      (
        name: 'Kahvaltı',
        mode: ProductCardPresentationMode.visual,
      ),
      (
        name: 'İçecekler',
        mode: ProductCardPresentationMode.compact,
      ),
      (
        name: 'Ana Yemekler',
        mode: ProductCardPresentationMode.compact,
      ),
      (
        name: 'Tatlılar',
        mode: ProductCardPresentationMode.compact,
      ),
    ];

    for (int index = 0; index < seededExpectations.length; index++) {
      final ({String name, ProductCardPresentationMode mode}) expectation =
          seededExpectations[index];
      final Category category = Category(
        id: index + 1,
        name: expectation.name,
        imageUrl: null,
        sortOrder: 0,
        isActive: true,
      );
      final PosProductPresentationDecision decision =
          PosProductPresentationPolicy.resolveDecisionForCategory(category);

      expect(decision.mode, expectation.mode, reason: expectation.name);
      expect(
        decision.source,
        PosPresentationMatchSource.exactRegistry,
        reason: expectation.name,
      );
    }
  });

  test('policy keeps curated breakfast sets explicit', () {
    const Category category = Category(
      id: 10,
      name: 'Breakfast Sets',
      imageUrl: null,
      sortOrder: 0,
      isActive: true,
    );

    final PosProductPresentationDecision decision =
        PosProductPresentationPolicy.resolveDecisionForCategory(category);

    expect(decision.mode, ProductCardPresentationMode.visual);
    expect(decision.source, PosPresentationMatchSource.exactRegistry);
  });

  test('policy supports narrow alias rules for known visual families', () {
    const Category category = Category(
      id: 11,
      name: 'Chef Breakfast Combo Board',
      imageUrl: null,
      sortOrder: 1,
      isActive: true,
    );

    final PosProductPresentationDecision decision =
        PosProductPresentationPolicy.resolveDecisionForCategory(category);

    expect(decision.mode, ProductCardPresentationMode.visual);
    expect(decision.source, PosPresentationMatchSource.aliasRule);
    expect(decision.ruleId, 'alias.breakfast_combo');
  });

  test('unknown categories stay on an isolated compact fallback path', () {
    const Category category = Category(
      id: 12,
      name: 'Seasonal Specials',
      imageUrl: null,
      sortOrder: 2,
      isActive: true,
    );

    final PosProductPresentationDecision decision =
        PosProductPresentationPolicy.resolveDecisionForCategory(category);

    expect(decision.mode, ProductCardPresentationMode.compact);
    expect(decision.source, PosPresentationMatchSource.fallback);
    expect(decision.ruleId, 'fallback.compact');
  });
}
