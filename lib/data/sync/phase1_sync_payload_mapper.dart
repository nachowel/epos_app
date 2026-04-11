import '../database/app_database.dart' as db;
import 'phase1_sync_contract.dart';

class Phase1SyncPayloadMapper {
  const Phase1SyncPayloadMapper();

  Map<String, Object?> transactionPayload(db.Transaction row) {
    return <String, Object?>{
      'uuid': row.uuid,
      'shift_local_id': row.shiftId,
      'user_local_id': row.userId,
      'table_number': row.tableNumber,
      // The live mirror schema accepts finalized rows only. Sync graph
      // construction rejects draft/sent rows before this mapper runs.
      'status': Phase1SyncContract.mapLocalTransactionStatusToRemote(
        row.status,
      ),
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
      'pricing_mode': row.pricingMode,
      'removal_discount_total_minor': row.removalDiscountTotalMinor,
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
      'quantity': row.quantity,
      'item_product_id': row.itemProductId,
      'extra_price_minor': row.extraPriceMinor,
      'charge_reason': row.chargeReason,
      'unit_price_minor': row.unitPriceMinor,
      'price_effect_minor': row.priceEffectMinor,
      'sort_key': row.sortKey,
      'price_behavior': row.priceBehavior,
      'ui_section': row.uiSection,
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
