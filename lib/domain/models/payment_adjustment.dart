enum PaymentAdjustmentType { refund, reversal }

enum PaymentAdjustmentStatus { completed }

class PaymentAdjustment {
  const PaymentAdjustment({
    required this.id,
    required this.uuid,
    required this.paymentId,
    required this.transactionId,
    required this.type,
    required this.status,
    required this.amountMinor,
    required this.reason,
    required this.createdBy,
    required this.createdAt,
  });

  final int id;
  final String uuid;
  final int paymentId;
  final int transactionId;
  final PaymentAdjustmentType type;
  final PaymentAdjustmentStatus status;
  final int amountMinor;
  final String reason;
  final int createdBy;
  final DateTime createdAt;

  bool get isCompleted => status == PaymentAdjustmentStatus.completed;

  PaymentAdjustment copyWith({
    int? id,
    String? uuid,
    int? paymentId,
    int? transactionId,
    PaymentAdjustmentType? type,
    PaymentAdjustmentStatus? status,
    int? amountMinor,
    String? reason,
    int? createdBy,
    DateTime? createdAt,
  }) {
    return PaymentAdjustment(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      paymentId: paymentId ?? this.paymentId,
      transactionId: transactionId ?? this.transactionId,
      type: type ?? this.type,
      status: status ?? this.status,
      amountMinor: amountMinor ?? this.amountMinor,
      reason: reason ?? this.reason,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PaymentAdjustment &&
        other.id == id &&
        other.uuid == uuid &&
        other.paymentId == paymentId &&
        other.transactionId == transactionId &&
        other.type == type &&
        other.status == status &&
        other.amountMinor == amountMinor &&
        other.reason == reason &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    paymentId,
    transactionId,
    type,
    status,
    amountMinor,
    reason,
    createdBy,
    createdAt,
  );
}
