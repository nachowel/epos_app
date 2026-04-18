enum TransactionLinePricingMode { standard, set }

class TransactionLine {
  const TransactionLine({
    required this.id,
    required this.uuid,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.unitPriceMinor,
    required this.quantity,
    required this.lineTotalMinor,
    this.pricingMode = TransactionLinePricingMode.standard,
    this.removalDiscountTotalMinor = 0,
    this.customNote,
    this.createdByUserId,
    this.adminOverrideUserId,
  });

  final int id;
  final String uuid;
  final int transactionId;
  final int productId;
  final String productName;
  final int unitPriceMinor;
  final int quantity;
  final int lineTotalMinor;
  final TransactionLinePricingMode pricingMode;
  final int removalDiscountTotalMinor;
  // Reserved for Custom Sale line persistence in Phase 1. Standard product
  // flows are expected to leave this null unless a later feature expands its
  // use explicitly.
  final String? customNote;
  final int? createdByUserId;
  final int? adminOverrideUserId;

  TransactionLine copyWith({
    int? id,
    String? uuid,
    int? transactionId,
    int? productId,
    String? productName,
    int? unitPriceMinor,
    int? quantity,
    int? lineTotalMinor,
    TransactionLinePricingMode? pricingMode,
    int? removalDiscountTotalMinor,
    Object? customNote = _unset,
    Object? createdByUserId = _unset,
    Object? adminOverrideUserId = _unset,
  }) {
    return TransactionLine(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      transactionId: transactionId ?? this.transactionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
      quantity: quantity ?? this.quantity,
      lineTotalMinor: lineTotalMinor ?? this.lineTotalMinor,
      pricingMode: pricingMode ?? this.pricingMode,
      removalDiscountTotalMinor:
          removalDiscountTotalMinor ?? this.removalDiscountTotalMinor,
      customNote: customNote == _unset
          ? this.customNote
          : customNote as String?,
      createdByUserId: createdByUserId == _unset
          ? this.createdByUserId
          : createdByUserId as int?,
      adminOverrideUserId: adminOverrideUserId == _unset
          ? this.adminOverrideUserId
          : adminOverrideUserId as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TransactionLine &&
        other.id == id &&
        other.uuid == uuid &&
        other.transactionId == transactionId &&
        other.productId == productId &&
        other.productName == productName &&
        other.unitPriceMinor == unitPriceMinor &&
        other.quantity == quantity &&
        other.lineTotalMinor == lineTotalMinor &&
        other.pricingMode == pricingMode &&
        other.removalDiscountTotalMinor == removalDiscountTotalMinor &&
        other.customNote == customNote &&
        other.createdByUserId == createdByUserId &&
        other.adminOverrideUserId == adminOverrideUserId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    transactionId,
    productId,
    productName,
    unitPriceMinor,
    quantity,
    lineTotalMinor,
    pricingMode,
    removalDiscountTotalMinor,
    customNote,
    createdByUserId,
    adminOverrideUserId,
  );
}

const Object _unset = Object();
