enum TransactionStatus { draft, sent, paid, cancelled }

class Transaction {
  const Transaction({
    required this.id,
    required this.uuid,
    required this.shiftId,
    required this.userId,
    required this.tableNumber,
    required this.status,
    required this.subtotalMinor,
    required this.modifierTotalMinor,
    required this.totalAmountMinor,
    required this.createdAt,
    required this.paidAt,
    required this.updatedAt,
    required this.cancelledAt,
    required this.cancelledBy,
    required this.idempotencyKey,
    required this.kitchenPrinted,
    required this.receiptPrinted,
  });

  final int id;
  final String uuid;
  final int shiftId;
  final int userId;
  final int? tableNumber;
  final TransactionStatus status;
  final int subtotalMinor;
  final int modifierTotalMinor;
  final int totalAmountMinor;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime updatedAt;
  final DateTime? cancelledAt;
  final int? cancelledBy;
  final String idempotencyKey;
  final bool kitchenPrinted;
  final bool receiptPrinted;

  bool get isDraft => status == TransactionStatus.draft;

  bool get isSent => status == TransactionStatus.sent;

  bool get isPaid => status == TransactionStatus.paid;

  bool get isCancelled => status == TransactionStatus.cancelled;

  Transaction copyWith({
    int? id,
    String? uuid,
    int? shiftId,
    int? userId,
    Object? tableNumber = _unset,
    TransactionStatus? status,
    int? subtotalMinor,
    int? modifierTotalMinor,
    int? totalAmountMinor,
    DateTime? createdAt,
    Object? paidAt = _unset,
    DateTime? updatedAt,
    Object? cancelledAt = _unset,
    Object? cancelledBy = _unset,
    String? idempotencyKey,
    bool? kitchenPrinted,
    bool? receiptPrinted,
  }) {
    return Transaction(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      shiftId: shiftId ?? this.shiftId,
      userId: userId ?? this.userId,
      tableNumber: tableNumber == _unset
          ? this.tableNumber
          : tableNumber as int?,
      status: status ?? this.status,
      subtotalMinor: subtotalMinor ?? this.subtotalMinor,
      modifierTotalMinor: modifierTotalMinor ?? this.modifierTotalMinor,
      totalAmountMinor: totalAmountMinor ?? this.totalAmountMinor,
      createdAt: createdAt ?? this.createdAt,
      paidAt: paidAt == _unset ? this.paidAt : paidAt as DateTime?,
      updatedAt: updatedAt ?? this.updatedAt,
      cancelledAt: cancelledAt == _unset
          ? this.cancelledAt
          : cancelledAt as DateTime?,
      cancelledBy: cancelledBy == _unset
          ? this.cancelledBy
          : cancelledBy as int?,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      kitchenPrinted: kitchenPrinted ?? this.kitchenPrinted,
      receiptPrinted: receiptPrinted ?? this.receiptPrinted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Transaction &&
        other.id == id &&
        other.uuid == uuid &&
        other.shiftId == shiftId &&
        other.userId == userId &&
        other.tableNumber == tableNumber &&
        other.status == status &&
        other.subtotalMinor == subtotalMinor &&
        other.modifierTotalMinor == modifierTotalMinor &&
        other.totalAmountMinor == totalAmountMinor &&
        other.createdAt == createdAt &&
        other.paidAt == paidAt &&
        other.updatedAt == updatedAt &&
        other.cancelledAt == cancelledAt &&
        other.cancelledBy == cancelledBy &&
        other.idempotencyKey == idempotencyKey &&
        other.kitchenPrinted == kitchenPrinted &&
        other.receiptPrinted == receiptPrinted;
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    shiftId,
    userId,
    tableNumber,
    status,
    subtotalMinor,
    modifierTotalMinor,
    totalAmountMinor,
    createdAt,
    paidAt,
    updatedAt,
    cancelledAt,
    cancelledBy,
    idempotencyKey,
    kitchenPrinted,
    receiptPrinted,
  );
}

const Object _unset = Object();
