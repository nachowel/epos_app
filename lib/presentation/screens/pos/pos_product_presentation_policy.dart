import 'package:flutter/foundation.dart' show debugPrint;

import '../../../domain/models/category.dart';

enum ProductCardPresentationMode { visual, compact }

enum PosPresentationMatchSource { exactRegistry, aliasRule, fallback }

class PosProductPresentationDecision {
  const PosProductPresentationDecision({
    required this.mode,
    required this.source,
    required this.ruleId,
    this.categoryName,
  });

  final ProductCardPresentationMode mode;
  final PosPresentationMatchSource source;
  final String ruleId;
  final String? categoryName;
}

class PosCategoryPresentationRule {
  PosCategoryPresentationRule.exact({
    required this.id,
    required this.label,
    required this.mode,
    required String exactName,
  }) : source = PosPresentationMatchSource.exactRegistry,
       exactNames = <String>[exactName],
       requiredTokenGroups = const <List<String>>[];

  PosCategoryPresentationRule.alias({
    required this.id,
    required this.label,
    required this.mode,
    this.exactNames = const <String>[],
    this.requiredTokenGroups = const <List<String>>[],
  }) : source = PosPresentationMatchSource.aliasRule;

  final String id;
  final String label;
  final ProductCardPresentationMode mode;
  final PosPresentationMatchSource source;
  final List<String> exactNames;
  final List<List<String>> requiredTokenGroups;

  bool matches({
    required String normalizedName,
    required Set<String> tokens,
  }) {
    if (exactNames.contains(normalizedName)) {
      return true;
    }

    for (final List<String> tokenGroup in requiredTokenGroups) {
      if (tokenGroup.every(tokens.contains)) {
        return true;
      }
    }

    return false;
  }
}

class PosProductPresentationPolicy {
  const PosProductPresentationPolicy._();

  static const ProductCardPresentationMode defaultMode =
      ProductCardPresentationMode.compact;

  static const PosProductPresentationDecision fallbackDecision =
      PosProductPresentationDecision(
        mode: defaultMode,
        source: PosPresentationMatchSource.fallback,
        ruleId: 'fallback.compact',
      );

  // Single source of truth for POS category presentation mapping.
  // Keep known POS categories explicit so normal operation never relies on
  // fallback warnings for categories already in active use.
  static final List<PosCategoryPresentationRule> registry =
      <PosCategoryPresentationRule>[
        PosCategoryPresentationRule.exact(
          id: 'pos.set_breakfast',
          label: 'Set Breakfast category',
          mode: ProductCardPresentationMode.visual,
          exactName: 'set breakfast',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.sandwiches',
          label: 'Sandwiches category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'sandwiches',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.lunches',
          label: 'Lunches category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'lunches',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.drink',
          label: 'Drink category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'drink',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.drinks',
          label: 'Drinks category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'drinks',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.healthy_breakfast',
          label: 'Healthy Breakfast category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'healthy breakfast',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.omelettes',
          label: 'Omelettes category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'omelettes',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.burgers',
          label: 'Burgers category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'burgers',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.extras',
          label: 'Extras category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'extras',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.light_breakfast',
          label: 'Light Breakfast category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'light breakfast',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.pancake_breakfast',
          label: 'Pancake Breakfast category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'pancake breakfast',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.brunches',
          label: 'Brunches category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'brunches',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.jacket_potatoes',
          label: 'Jacket Potatoes category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'jacket potatoes',
        ),
        PosCategoryPresentationRule.exact(
          id: 'pos.salad',
          label: 'Salad category',
          mode: ProductCardPresentationMode.compact,
          exactName: 'salad',
        ),
        PosCategoryPresentationRule.exact(
          id: 'seed.breakfast.tr',
          label: 'Seeded breakfast category (TR)',
          mode: ProductCardPresentationMode.visual,
          exactName: 'kahvaltı',
        ),
        PosCategoryPresentationRule.exact(
          id: 'seed.drinks.tr',
          label: 'Seeded drinks category (TR)',
          mode: ProductCardPresentationMode.compact,
          exactName: 'içecekler',
        ),
        PosCategoryPresentationRule.exact(
          id: 'seed.mains.tr',
          label: 'Seeded mains category (TR)',
          mode: ProductCardPresentationMode.compact,
          exactName: 'ana yemekler',
        ),
        PosCategoryPresentationRule.exact(
          id: 'seed.desserts.tr',
          label: 'Seeded desserts category (TR)',
          mode: ProductCardPresentationMode.compact,
          exactName: 'tatlılar',
        ),
        PosCategoryPresentationRule.exact(
          id: 'curated.breakfast_sets.en',
          label: 'Curated breakfast sets category',
          mode: ProductCardPresentationMode.visual,
          exactName: 'breakfast sets',
        ),
        PosCategoryPresentationRule.exact(
          id: 'curated.breakfast_set.en',
          label: 'Curated breakfast set category',
          mode: ProductCardPresentationMode.visual,
          exactName: 'breakfast set',
        ),
        PosCategoryPresentationRule.exact(
          id: 'curated.breakfast.en',
          label: 'Curated breakfast category',
          mode: ProductCardPresentationMode.visual,
          exactName: 'breakfast',
        ),
        PosCategoryPresentationRule.alias(
          id: 'alias.breakfast_combo',
          label: 'Breakfast combo alias',
          mode: ProductCardPresentationMode.visual,
          requiredTokenGroups: <List<String>>[
            <String>['breakfast', 'combo'],
          ],
        ),
        PosCategoryPresentationRule.alias(
          id: 'alias.breakfast_set',
          label: 'Breakfast set alias',
          mode: ProductCardPresentationMode.visual,
          requiredTokenGroups: <List<String>>[
            <String>['breakfast', 'set'],
          ],
        ),
        PosCategoryPresentationRule.alias(
          id: 'alias.meal_deal',
          label: 'Meal deal alias',
          mode: ProductCardPresentationMode.visual,
          requiredTokenGroups: <List<String>>[
            <String>['meal', 'deal'],
          ],
        ),
      ];

  static PosProductPresentationDecision resolveForSelection({
    required List<Category> categories,
    required int? selectedCategoryId,
  }) {
    final Category? selectedCategory = findSelectedCategory(
      categories: categories,
      selectedCategoryId: selectedCategoryId,
    );
    return resolveDecisionForCategory(selectedCategory);
  }

  static ProductCardPresentationMode resolveForCategory(Category? category) {
    return resolveDecisionForCategory(category).mode;
  }

  static PosProductPresentationDecision resolveDecisionForCategory(
    Category? category,
  ) {
    if (category == null) {
      return fallbackDecision;
    }

    final String normalizedName = _normalize(category.name);
    final Set<String> tokens = _tokenize(normalizedName);
    for (final PosCategoryPresentationRule rule in registry) {
      if (!rule.matches(normalizedName: normalizedName, tokens: tokens)) {
        continue;
      }
      return PosProductPresentationDecision(
        mode: rule.mode,
        source: rule.source,
        ruleId: rule.id,
        categoryName: category.name,
      );
    }

    _reportFallback(category.name);
    return PosProductPresentationDecision(
      mode: fallbackDecision.mode,
      source: fallbackDecision.source,
      ruleId: fallbackDecision.ruleId,
      categoryName: category.name,
    );
  }

  static Category? findSelectedCategory({
    required List<Category> categories,
    required int? selectedCategoryId,
  }) {
    if (selectedCategoryId == null) {
      return null;
    }

    for (final Category category in categories) {
      if (category.id == selectedCategoryId) {
        return category;
      }
    }

    return null;
  }

  static void _reportFallback(String categoryName) {
    assert(() {
      debugPrint(
        '[PosProductPresentationPolicy] Unmapped category '
        '"$categoryName" fell back to ${defaultMode.name}. '
        'Audit registry in pos_product_presentation_policy.dart.',
      );
      return true;
    }());
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  static Set<String> _tokenize(String value) {
    return value
        .split(RegExp(r'[^\p{L}0-9]+', unicode: true))
        .where((String token) => token.isNotEmpty)
        .toSet();
  }
}
