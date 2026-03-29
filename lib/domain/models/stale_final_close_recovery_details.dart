class StaleFinalCloseRecoveryDetails {
  const StaleFinalCloseRecoveryDetails({
    required this.shiftId,
    required this.reconciliationId,
    required this.expectedCashMinor,
    required this.countedCashMinor,
    required this.varianceMinor,
    required this.countedAt,
    required this.countedByUserId,
    this.countedByName,
  });

  final int shiftId;
  final int reconciliationId;
  final int expectedCashMinor;
  final int countedCashMinor;
  final int varianceMinor;
  final DateTime countedAt;
  final int countedByUserId;
  final String? countedByName;

  StaleFinalCloseRecoveryDetails copyWith({
    int? shiftId,
    int? reconciliationId,
    int? expectedCashMinor,
    int? countedCashMinor,
    int? varianceMinor,
    DateTime? countedAt,
    int? countedByUserId,
    Object? countedByName = _unset,
  }) {
    return StaleFinalCloseRecoveryDetails(
      shiftId: shiftId ?? this.shiftId,
      reconciliationId: reconciliationId ?? this.reconciliationId,
      expectedCashMinor: expectedCashMinor ?? this.expectedCashMinor,
      countedCashMinor: countedCashMinor ?? this.countedCashMinor,
      varianceMinor: varianceMinor ?? this.varianceMinor,
      countedAt: countedAt ?? this.countedAt,
      countedByUserId: countedByUserId ?? this.countedByUserId,
      countedByName: countedByName == _unset
          ? this.countedByName
          : countedByName as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is StaleFinalCloseRecoveryDetails &&
        other.shiftId == shiftId &&
        other.reconciliationId == reconciliationId &&
        other.expectedCashMinor == expectedCashMinor &&
        other.countedCashMinor == countedCashMinor &&
        other.varianceMinor == varianceMinor &&
        other.countedAt == countedAt &&
        other.countedByUserId == countedByUserId &&
        other.countedByName == countedByName;
  }

  @override
  int get hashCode => Object.hash(
    shiftId,
    reconciliationId,
    expectedCashMinor,
    countedCashMinor,
    varianceMinor,
    countedAt,
    countedByUserId,
    countedByName,
  );
}

const Object _unset = Object();
