enum ShiftReconciliationKind { finalClose }

enum CountedCashSource { entered, compatibilityFallback }

class ShiftReconciliation {
  const ShiftReconciliation({
    required this.id,
    required this.uuid,
    required this.shiftId,
    required this.kind,
    required this.expectedCashMinor,
    required this.countedCashMinor,
    required this.varianceMinor,
    required this.countedCashSource,
    required this.countedBy,
    required this.countedAt,
  });

  final int id;
  final String uuid;
  final int shiftId;
  final ShiftReconciliationKind kind;
  final int expectedCashMinor;
  final int countedCashMinor;
  final int varianceMinor;
  final CountedCashSource countedCashSource;
  final int countedBy;
  final DateTime countedAt;

  bool get wasOperatorEntered => countedCashSource == CountedCashSource.entered;

  ShiftReconciliation copyWith({
    int? id,
    String? uuid,
    int? shiftId,
    ShiftReconciliationKind? kind,
    int? expectedCashMinor,
    int? countedCashMinor,
    int? varianceMinor,
    CountedCashSource? countedCashSource,
    int? countedBy,
    DateTime? countedAt,
  }) {
    return ShiftReconciliation(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      shiftId: shiftId ?? this.shiftId,
      kind: kind ?? this.kind,
      expectedCashMinor: expectedCashMinor ?? this.expectedCashMinor,
      countedCashMinor: countedCashMinor ?? this.countedCashMinor,
      varianceMinor: varianceMinor ?? this.varianceMinor,
      countedCashSource: countedCashSource ?? this.countedCashSource,
      countedBy: countedBy ?? this.countedBy,
      countedAt: countedAt ?? this.countedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShiftReconciliation &&
        other.id == id &&
        other.uuid == uuid &&
        other.shiftId == shiftId &&
        other.kind == kind &&
        other.expectedCashMinor == expectedCashMinor &&
        other.countedCashMinor == countedCashMinor &&
        other.varianceMinor == varianceMinor &&
        other.countedCashSource == countedCashSource &&
        other.countedBy == countedBy &&
        other.countedAt == countedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    shiftId,
    kind,
    expectedCashMinor,
    countedCashMinor,
    varianceMinor,
    countedCashSource,
    countedBy,
    countedAt,
  );
}
