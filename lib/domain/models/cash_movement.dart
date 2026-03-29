enum CashMovementType { income, expense }

enum CashMovementPaymentMethod { cash, card, other }

class CashMovement {
  const CashMovement({
    required this.id,
    required this.shiftId,
    required this.type,
    required this.category,
    required this.amountMinor,
    required this.paymentMethod,
    required this.note,
    required this.createdByUserId,
    required this.createdAt,
  });

  final int id;
  final int shiftId;
  final CashMovementType type;
  final String category;
  final int amountMinor;
  final CashMovementPaymentMethod paymentMethod;
  final String? note;
  final int createdByUserId;
  final DateTime createdAt;

  CashMovement copyWith({
    int? id,
    int? shiftId,
    CashMovementType? type,
    String? category,
    int? amountMinor,
    CashMovementPaymentMethod? paymentMethod,
    Object? note = _unset,
    int? createdByUserId,
    DateTime? createdAt,
  }) {
    return CashMovement(
      id: id ?? this.id,
      shiftId: shiftId ?? this.shiftId,
      type: type ?? this.type,
      category: category ?? this.category,
      amountMinor: amountMinor ?? this.amountMinor,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note == _unset ? this.note : note as String?,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CashMovement &&
        other.id == id &&
        other.shiftId == shiftId &&
        other.type == type &&
        other.category == category &&
        other.amountMinor == amountMinor &&
        other.paymentMethod == paymentMethod &&
        other.note == note &&
        other.createdByUserId == createdByUserId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    shiftId,
    type,
    category,
    amountMinor,
    paymentMethod,
    note,
    createdByUserId,
    createdAt,
  );
}

const Object _unset = Object();
