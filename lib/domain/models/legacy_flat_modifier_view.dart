import 'product_modifier.dart';

class LegacyFlatModifierView {
  const LegacyFlatModifierView({
    required this.included,
    required this.extras,
    required this.omittedSemanticModifiers,
  });

  factory LegacyFlatModifierView.fromModifiers(
    Iterable<ProductModifier> modifiers,
  ) {
    final List<ProductModifier> included = <ProductModifier>[];
    final List<ProductModifier> extras = <ProductModifier>[];
    final List<ProductModifier> omittedSemanticModifiers = <ProductModifier>[];

    for (final ProductModifier modifier in modifiers) {
      switch (modifier.type) {
        case ModifierType.included:
          included.add(modifier);
          break;
        case ModifierType.extra:
          extras.add(modifier);
          break;
        case ModifierType.choice:
          omittedSemanticModifiers.add(modifier);
          break;
      }
    }

    return LegacyFlatModifierView(
      included: List<ProductModifier>.unmodifiable(included),
      extras: List<ProductModifier>.unmodifiable(extras),
      omittedSemanticModifiers: List<ProductModifier>.unmodifiable(
        omittedSemanticModifiers,
      ),
    );
  }

  final List<ProductModifier> included;
  final List<ProductModifier> extras;
  final List<ProductModifier> omittedSemanticModifiers;

  bool get isEmpty => included.isEmpty && extras.isEmpty;
}
