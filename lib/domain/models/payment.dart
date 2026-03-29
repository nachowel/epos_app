enum PaymentMethod { cash, card }

class Payment {
  const Payment({
    required this.id,
    required this.uuid,
    required this.transactionId,
    required this.method,
    required this.amountMinor,
    required this.paidAt,
  });

  final int id;
  final String uuid;
  final int transactionId;
  final PaymentMethod method;
  final int amountMinor;
  final DateTime paidAt;

  Payment copyWith({
    int? id,
    String? uuid,
    int? transactionId,
    PaymentMethod? method,
    int? amountMinor,
    DateTime? paidAt,
  }) {
    return Payment(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionId: transactionId ?? this.transactionId,
      method: method ?? this.method,
      amountMinor: amountMinor ?? this.amountMinor,
      paidAt: paidAt ?? this.paidAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Payment &&
        other.id == id &&
        other.uuid == uuid &&
        other.transactionId == transactionId &&
        other.method == method &&
        other.amountMinor == amountMinor &&
        other.paidAt == paidAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, uuid, transactionId, method, amountMinor, paidAt);
}
