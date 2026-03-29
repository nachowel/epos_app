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
  });

  final int id;
  final String uuid;
  final int transactionId;
  final int productId;
  final String productName;
  final int unitPriceMinor;
  final int quantity;
  final int lineTotalMinor;

  TransactionLine copyWith({
    int? id,
    String? uuid,
    int? transactionId,
    int? productId,
    String? productName,
    int? unitPriceMinor,
    int? quantity,
    int? lineTotalMinor,
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
        other.lineTotalMinor == lineTotalMinor;
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
  );
}
