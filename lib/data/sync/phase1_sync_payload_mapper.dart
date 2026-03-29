import '../database/app_database.dart' as db;

class Phase1SyncPayloadMapper {
  const Phase1SyncPayloadMapper();

  Map<String, Object?> transactionPayload(db.Transaction row) {
    return <String, Object?>{
      'uuid': row.uuid,
      'shift_local_id': row.shiftId,
      'user_local_id': row.userId,
      'table_number': row.tableNumber,
      'status': row.status,
      'subtotal_minor': row.subtotalMinor,
      'modifier_total_minor': row.modifierTotalMinor,
      'total_amount_minor': row.totalAmountMinor,
      'created_at': row.createdAt.toUtc().toIso8601String(),
      'paid_at': row.paidAt?.toUtc().toIso8601String(),
      'updated_at': row.updatedAt.toUtc().toIso8601String(),
      'cancelled_at': row.cancelledAt?.toUtc().toIso8601String(),
      'cancelled_by_local_id': row.cancelledBy,
      'kitchen_printed': row.kitchenPrinted,
      'receipt_printed': row.receiptPrinted,
    };
  }

  Map<String, Object?> transactionLinePayload({
    required db.TransactionLine row,
    required String transactionUuid,
  }) {
    return <String, Object?>{
      'uuid': row.uuid,
      'transaction_uuid': transactionUuid,
      'product_local_id': row.productId,
      'product_name': row.productName,
      'unit_price_minor': row.unitPriceMinor,
      'quantity': row.quantity,
      'line_total_minor': row.lineTotalMinor,
    };
  }

  Map<String, Object?> orderModifierPayload({
    required db.OrderModifier row,
    required String transactionLineUuid,
  }) {
    return <String, Object?>{
      'uuid': row.uuid,
      'transaction_line_uuid': transactionLineUuid,
      'action': row.action,
      'item_name': row.itemName,
      'extra_price_minor': row.extraPriceMinor,
    };
  }

  Map<String, Object?> paymentPayload({
    required db.Payment row,
    required String transactionUuid,
  }) {
    return <String, Object?>{
      'uuid': row.uuid,
      'transaction_uuid': transactionUuid,
      'method': row.method,
      'amount_minor': row.amountMinor,
      'paid_at': row.paidAt.toUtc().toIso8601String(),
    };
  }
}
