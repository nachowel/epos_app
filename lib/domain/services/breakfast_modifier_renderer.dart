import '../../core/utils/currency_formatter.dart';
import '../models/order_modifier.dart';

/// Shared rendering policy for breakfast modifier rows.
///
/// Kitchen, receipt, and UI detail screens all derive labels from this helper
/// so that semantic classification vocabulary stays consistent across outputs.
///
/// Kitchen and receipt may request different wording via [BreakfastRenderTarget],
/// but they always agree on semantic identity (action + charge_reason).
enum BreakfastRenderTarget { kitchen, receipt, detail }

class BreakfastModifierRendered {
  const BreakfastModifierRendered({
    required this.label,
    required this.priceLabel,
    required this.showOnKitchen,
    required this.showOnReceipt,
    required this.sortKey,
    required this.chargeReason,
    required this.action,
    required this.itemProductId,
    required this.quantity,
    required this.priceEffectMinor,
  });

  final String label;

  /// Formatted price string, or empty if zero-effect.
  final String priceLabel;

  final bool showOnKitchen;
  final bool showOnReceipt;
  final int sortKey;
  final ModifierChargeReason? chargeReason;
  final ModifierAction action;
  final int? itemProductId;
  final int quantity;
  final int priceEffectMinor;
}

/// Renders a list of [OrderModifier] rows into presentation-ready objects.
///
/// This is the single source of truth for breakfast modifier display across
/// kitchen tickets, receipts, and the order detail screen. It uses persisted
/// semantic fields (action, chargeReason, itemProductId, quantity,
/// priceEffectMinor, sortKey) and never infers meaning from item_name text.
class BreakfastModifierRenderer {
  const BreakfastModifierRenderer();

  /// Renders all modifiers for a single transaction line.
  ///
  /// Output is sorted by [sortKey], then by semantic group priority
  /// (removes, included choices, free swaps, paid swaps, extra adds).
  List<BreakfastModifierRendered> renderAll(List<OrderModifier> modifiers) {
    final List<BreakfastModifierRendered> result = <BreakfastModifierRendered>[];
    for (final OrderModifier modifier in modifiers) {
      result.add(_renderOne(modifier));
    }
    result.sort((BreakfastModifierRendered a, BreakfastModifierRendered b) {
      final int sortCmp = a.sortKey.compareTo(b.sortKey);
      if (sortCmp != 0) return sortCmp;
      return _groupPriority(a.chargeReason, a.action)
          .compareTo(_groupPriority(b.chargeReason, b.action));
    });
    return result;
  }

  BreakfastModifierRendered _renderOne(OrderModifier modifier) {
    final String quantitySuffix =
        modifier.quantity > 1 ? ' x${modifier.quantity}' : '';

    switch (modifier.chargeReason) {
      case ModifierChargeReason.includedChoice:
        return BreakfastModifierRendered(
          label: '${modifier.itemName}$quantitySuffix',
          priceLabel: '',
          showOnKitchen: true,
          showOnReceipt: true,
          sortKey: modifier.sortKey,
          chargeReason: modifier.chargeReason,
          action: modifier.action,
          itemProductId: modifier.itemProductId,
          quantity: modifier.quantity,
          priceEffectMinor: modifier.priceEffectMinor,
        );

      case ModifierChargeReason.freeSwap:
        return BreakfastModifierRendered(
          label: '+ ${modifier.itemName}$quantitySuffix (swap)',
          priceLabel: '',
          showOnKitchen: true,
          showOnReceipt: true,
          sortKey: modifier.sortKey,
          chargeReason: modifier.chargeReason,
          action: modifier.action,
          itemProductId: modifier.itemProductId,
          quantity: modifier.quantity,
          priceEffectMinor: modifier.priceEffectMinor,
        );

      case ModifierChargeReason.paidSwap:
        final String price =
            '+${CurrencyFormatter.fromMinor(modifier.priceEffectMinor)}';
        return BreakfastModifierRendered(
          label: '+ ${modifier.itemName}$quantitySuffix (swap $price)',
          priceLabel: price,
          showOnKitchen: true,
          showOnReceipt: true,
          sortKey: modifier.sortKey,
          chargeReason: modifier.chargeReason,
          action: modifier.action,
          itemProductId: modifier.itemProductId,
          quantity: modifier.quantity,
          priceEffectMinor: modifier.priceEffectMinor,
        );

      case ModifierChargeReason.extraAdd:
        final String price =
            '+${CurrencyFormatter.fromMinor(modifier.priceEffectMinor)}';
        return BreakfastModifierRendered(
          label: '+ ${modifier.itemName}$quantitySuffix ($price)',
          priceLabel: price,
          showOnKitchen: true,
          showOnReceipt: true,
          sortKey: modifier.sortKey,
          chargeReason: modifier.chargeReason,
          action: modifier.action,
          itemProductId: modifier.itemProductId,
          quantity: modifier.quantity,
          priceEffectMinor: modifier.priceEffectMinor,
        );

      case ModifierChargeReason.removalDiscount:
        return BreakfastModifierRendered(
          label: '${modifier.itemName}$quantitySuffix',
          priceLabel: '',
          showOnKitchen: false,
          showOnReceipt: false,
          sortKey: modifier.sortKey,
          chargeReason: modifier.chargeReason,
          action: modifier.action,
          itemProductId: modifier.itemProductId,
          quantity: modifier.quantity,
          priceEffectMinor: modifier.priceEffectMinor,
        );

      case null:
        // Legacy modifier without semantic charge_reason.
        return _renderLegacy(modifier, quantitySuffix);
    }
  }

  BreakfastModifierRendered _renderLegacy(
    OrderModifier modifier,
    String quantitySuffix,
  ) {
    switch (modifier.action) {
      case ModifierAction.remove:
        return BreakfastModifierRendered(
          label: '- ${modifier.itemName}$quantitySuffix',
          priceLabel: '',
          showOnKitchen: true,
          showOnReceipt: true,
          sortKey: modifier.sortKey,
          chargeReason: null,
          action: modifier.action,
          itemProductId: modifier.itemProductId,
          quantity: modifier.quantity,
          priceEffectMinor: modifier.priceEffectMinor,
        );
      case ModifierAction.choice:
        return BreakfastModifierRendered(
          label: '${modifier.itemName}$quantitySuffix (included)',
          priceLabel: '',
          showOnKitchen: true,
          showOnReceipt: true,
          sortKey: modifier.sortKey,
          chargeReason: null,
          action: modifier.action,
          itemProductId: modifier.itemProductId,
          quantity: modifier.quantity,
          priceEffectMinor: modifier.priceEffectMinor,
        );
      case ModifierAction.add:
        final int amountMinor = modifier.priceEffectMinor > 0
            ? modifier.priceEffectMinor
            : modifier.extraPriceMinor;
        final String priceLabel =
            amountMinor > 0 ? '+${CurrencyFormatter.fromMinor(amountMinor)}' : '';
        final String priceSuffix = priceLabel.isNotEmpty ? ' ($priceLabel)' : '';
        return BreakfastModifierRendered(
          label: '+ ${modifier.itemName}$quantitySuffix$priceSuffix',
          priceLabel: priceLabel,
          showOnKitchen: true,
          showOnReceipt: true,
          sortKey: modifier.sortKey,
          chargeReason: null,
          action: modifier.action,
          itemProductId: modifier.itemProductId,
          quantity: modifier.quantity,
          priceEffectMinor: amountMinor,
        );
    }
  }

  int _groupPriority(ModifierChargeReason? reason, ModifierAction action) {
    switch (reason) {
      case null:
        return action == ModifierAction.remove ? 0 : 5;
      case ModifierChargeReason.removalDiscount:
        return 0;
      case ModifierChargeReason.includedChoice:
        return 1;
      case ModifierChargeReason.freeSwap:
        return 2;
      case ModifierChargeReason.paidSwap:
        return 3;
      case ModifierChargeReason.extraAdd:
        return 4;
    }
  }

  // ── Convenience: target-filtered labels ──

  /// Returns kitchen-appropriate label for a modifier.
  /// Kitchen uses action-oriented wording: "no beans", "tea", "swap → X".
  String kitchenLabel(OrderModifier modifier) {
    final String quantitySuffix =
        modifier.quantity > 1 ? ' x${modifier.quantity}' : '';

    if (modifier.action == ModifierAction.remove) {
      return 'no ${modifier.itemName}$quantitySuffix';
    }

    switch (modifier.chargeReason) {
      case ModifierChargeReason.includedChoice:
        return '${modifier.itemName}$quantitySuffix';
      case ModifierChargeReason.freeSwap:
        return 'swap ${modifier.itemName}$quantitySuffix';
      case ModifierChargeReason.paidSwap:
        return 'swap ${modifier.itemName}$quantitySuffix';
      case ModifierChargeReason.extraAdd:
        return 'extra ${modifier.itemName}$quantitySuffix';
      case ModifierChargeReason.removalDiscount:
        return '${modifier.itemName}$quantitySuffix';
      case null:
        switch (modifier.action) {
          case ModifierAction.remove:
            return 'no ${modifier.itemName}$quantitySuffix';
          case ModifierAction.choice:
            return '${modifier.itemName}$quantitySuffix';
          case ModifierAction.add:
            return 'add ${modifier.itemName}$quantitySuffix';
        }
    }
  }

  /// Returns receipt-appropriate label for a modifier.
  /// Receipt uses financial wording with price where applicable.
  String receiptLabel(OrderModifier modifier) {
    final BreakfastModifierRendered rendered = _renderOne(modifier);
    return rendered.label;
  }
}
