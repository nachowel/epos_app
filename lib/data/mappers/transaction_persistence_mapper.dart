import 'package:drift/drift.dart' show Value;

import '../../core/errors/exceptions.dart';
import '../../domain/models/order_modifier.dart';
import '../../domain/models/transaction_line.dart';
import '../database/app_database.dart' as db;

class TransactionPersistenceMapper {
  const TransactionPersistenceMapper();

  db.TransactionLinesCompanion transactionLineToCompanion(
    TransactionLine line, {
    bool includeId = false,
  }) {
    return db.TransactionLinesCompanion(
      id: includeId ? Value<int>(line.id) : const Value<int>.absent(),
      uuid: Value<String>(line.uuid),
      transactionId: Value<int>(line.transactionId),
      productId: Value<int>(line.productId),
      productName: Value<String>(line.productName),
      unitPriceMinor: Value<int>(line.unitPriceMinor),
      quantity: Value<int>(line.quantity),
      lineTotalMinor: Value<int>(line.lineTotalMinor),
      pricingMode: Value<String>(_pricingModeToDb(line.pricingMode)),
      removalDiscountTotalMinor: Value<int>(line.removalDiscountTotalMinor),
    );
  }

  TransactionLine transactionLineFromRow(db.TransactionLine row) {
    return TransactionLine(
      id: row.id,
      uuid: row.uuid,
      transactionId: row.transactionId,
      productId: row.productId,
      productName: row.productName,
      unitPriceMinor: row.unitPriceMinor,
      quantity: row.quantity,
      lineTotalMinor: row.lineTotalMinor,
      pricingMode: _pricingModeFromDb(row.pricingMode),
      removalDiscountTotalMinor: row.removalDiscountTotalMinor,
    );
  }

  db.OrderModifiersCompanion orderModifierToCompanion(
    OrderModifier modifier, {
    bool includeId = false,
  }) {
    return db.OrderModifiersCompanion(
      id: includeId ? Value<int>(modifier.id) : const Value<int>.absent(),
      uuid: Value<String>(modifier.uuid),
      transactionLineId: Value<int>(modifier.transactionLineId),
      action: Value<String>(_modifierActionToDb(modifier.action)),
      itemName: Value<String>(modifier.itemName),
      quantity: Value<int>(modifier.quantity),
      itemProductId: Value<int?>(modifier.itemProductId),
      sourceGroupId: Value<int?>(modifier.sourceGroupId),
      extraPriceMinor: Value<int>(modifier.extraPriceMinor),
      chargeReason: Value<String?>(
        _modifierChargeReasonToDb(modifier.chargeReason),
      ),
      unitPriceMinor: Value<int>(modifier.unitPriceMinor),
      priceEffectMinor: Value<int>(modifier.priceEffectMinor),
      sortKey: Value<int>(modifier.sortKey),
    );
  }

  OrderModifier orderModifierFromRow(db.OrderModifier row) {
    return OrderModifier(
      id: row.id,
      uuid: row.uuid,
      transactionLineId: row.transactionLineId,
      action: _modifierActionFromDb(row.action),
      itemName: row.itemName,
      extraPriceMinor: row.extraPriceMinor,
      chargeReason: _modifierChargeReasonFromDb(row.chargeReason),
      itemProductId: row.itemProductId,
      sourceGroupId: row.sourceGroupId,
      quantity: row.quantity,
      unitPriceMinor: row.unitPriceMinor,
      priceEffectMinor: row.priceEffectMinor,
      sortKey: row.sortKey,
    );
  }

  ModifierAction modifierActionFromDb(String value) =>
      _modifierActionFromDb(value);

  String modifierActionToDb(ModifierAction value) => _modifierActionToDb(value);

  ModifierChargeReason? modifierChargeReasonFromDb(String? value) =>
      _modifierChargeReasonFromDb(value);

  String? modifierChargeReasonToDb(ModifierChargeReason? value) =>
      _modifierChargeReasonToDb(value);

  TransactionLinePricingMode pricingModeFromDb(String value) =>
      _pricingModeFromDb(value);

  String pricingModeToDb(TransactionLinePricingMode value) =>
      _pricingModeToDb(value);

  ModifierAction _modifierActionFromDb(String value) {
    switch (value) {
      case 'remove':
        return ModifierAction.remove;
      case 'add':
        return ModifierAction.add;
      case 'choice':
        return ModifierAction.choice;
      default:
        throw DatabaseException('Unknown modifier action: $value');
    }
  }

  String _modifierActionToDb(ModifierAction value) {
    switch (value) {
      case ModifierAction.remove:
        return 'remove';
      case ModifierAction.add:
        return 'add';
      case ModifierAction.choice:
        return 'choice';
    }
  }

  ModifierChargeReason? _modifierChargeReasonFromDb(String? value) {
    switch (value) {
      case null:
        return null;
      case 'included_choice':
        return ModifierChargeReason.includedChoice;
      case 'free_swap':
        return ModifierChargeReason.freeSwap;
      case 'paid_swap':
        return ModifierChargeReason.paidSwap;
      case 'extra_add':
        return ModifierChargeReason.extraAdd;
      case 'removal_discount':
        return ModifierChargeReason.removalDiscount;
      case 'combo_discount':
        return ModifierChargeReason.comboDiscount;
      default:
        throw DatabaseException('Unknown modifier charge reason: $value');
    }
  }

  String? _modifierChargeReasonToDb(ModifierChargeReason? value) {
    switch (value) {
      case null:
        return null;
      case ModifierChargeReason.includedChoice:
        return 'included_choice';
      case ModifierChargeReason.freeSwap:
        return 'free_swap';
      case ModifierChargeReason.paidSwap:
        return 'paid_swap';
      case ModifierChargeReason.extraAdd:
        return 'extra_add';
      case ModifierChargeReason.removalDiscount:
        return 'removal_discount';
      case ModifierChargeReason.comboDiscount:
        return 'combo_discount';
    }
  }

  TransactionLinePricingMode _pricingModeFromDb(String value) {
    switch (value) {
      case 'standard':
        return TransactionLinePricingMode.standard;
      case 'set':
        return TransactionLinePricingMode.set;
      default:
        throw DatabaseException('Unknown line pricing mode: $value');
    }
  }

  String _pricingModeToDb(TransactionLinePricingMode value) {
    switch (value) {
      case TransactionLinePricingMode.standard:
        return 'standard';
      case TransactionLinePricingMode.set:
        return 'set';
    }
  }
}
