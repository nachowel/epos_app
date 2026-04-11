class PricingExplanationLine {
  const PricingExplanationLine({
    required this.label,
    required this.priceEffectMinor,
    required this.type,
  });

  final String label;
  final int priceEffectMinor;
  final String type;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PricingExplanationLine &&
        other.label == label &&
        other.priceEffectMinor == priceEffectMinor &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(label, priceEffectMinor, type);
}
