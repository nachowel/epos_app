class PaymentSplitSummary {
  const PaymentSplitSummary({
    required this.cashRevenueMinor,
    required this.cardRevenueMinor,
    required this.totalRevenueMinor,
    required this.cashOrderCount,
    required this.cardOrderCount,
  });

  const PaymentSplitSummary.empty()
    : cashRevenueMinor = 0,
      cardRevenueMinor = 0,
      totalRevenueMinor = 0,
      cashOrderCount = 0,
      cardOrderCount = 0;

  final int cashRevenueMinor;
  final int cardRevenueMinor;
  final int totalRevenueMinor;
  final int cashOrderCount;
  final int cardOrderCount;

  double? get cashRevenueShare {
    if (totalRevenueMinor <= 0) {
      return null;
    }
    return cashRevenueMinor / totalRevenueMinor;
  }

  double? get cardRevenueShare {
    if (totalRevenueMinor <= 0) {
      return null;
    }
    return cardRevenueMinor / totalRevenueMinor;
  }

  PaymentSplitSummary copyWith({
    int? cashRevenueMinor,
    int? cardRevenueMinor,
    int? totalRevenueMinor,
    int? cashOrderCount,
    int? cardOrderCount,
  }) {
    return PaymentSplitSummary(
      cashRevenueMinor: cashRevenueMinor ?? this.cashRevenueMinor,
      cardRevenueMinor: cardRevenueMinor ?? this.cardRevenueMinor,
      totalRevenueMinor: totalRevenueMinor ?? this.totalRevenueMinor,
      cashOrderCount: cashOrderCount ?? this.cashOrderCount,
      cardOrderCount: cardOrderCount ?? this.cardOrderCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PaymentSplitSummary &&
        other.cashRevenueMinor == cashRevenueMinor &&
        other.cardRevenueMinor == cardRevenueMinor &&
        other.totalRevenueMinor == totalRevenueMinor &&
        other.cashOrderCount == cashOrderCount &&
        other.cardOrderCount == cardOrderCount;
  }

  @override
  int get hashCode => Object.hash(
    cashRevenueMinor,
    cardRevenueMinor,
    totalRevenueMinor,
    cashOrderCount,
    cardOrderCount,
  );
}
