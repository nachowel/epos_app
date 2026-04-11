import '../../core/errors/exceptions.dart';
import '../models/meal_customization.dart';
import '../models/order_modifier.dart';
import '../models/product_modifier.dart';

class MealCustomizationPersistenceProjection {
  const MealCustomizationPersistenceProjection({
    required this.productId,
    required this.profileId,
    required this.modifierTotalMinor,
    this.modifiers = const <OrderModifier>[],
    this.appliedRuleIds = const <int>[],
  });

  final int productId;
  final int profileId;
  final int modifierTotalMinor;
  final List<OrderModifier> modifiers;
  final List<int> appliedRuleIds;
}

class MealCustomizationPersistenceMapper {
  const MealCustomizationPersistenceMapper();

  MealCustomizationPersistenceProjection mapSnapshot({
    required int transactionLineId,
    required MealCustomizationResolvedSnapshot snapshot,
    required Map<int, String> productNamesById,
    required String Function() createUuid,
  }) {
    final List<OrderModifier> modifiers = <OrderModifier>[];
    int sortKey = 10;
    final int sandwichBreadPriceDeltaMinor = snapshot.sandwichSelection == null
        ? 0
        : snapshot.totalAdjustmentMinor -
              snapshot.resolvedExtraActions.fold<int>(
                0,
                (int total, MealCustomizationSemanticAction action) =>
                    total + action.priceDeltaMinor,
              );

    final SandwichCustomizationSelection? sandwichSelection =
        snapshot.sandwichSelection;
    if (sandwichSelection != null) {
      final SandwichBreadType? breadType = sandwichSelection.breadType;
      if (breadType != null) {
        modifiers.add(
          OrderModifier(
            id: 0,
            uuid: createUuid(),
            transactionLineId: transactionLineId,
            action: ModifierAction.choice,
            itemName: sandwichBreadLabel(breadType),
            extraPriceMinor: sandwichBreadPriceDeltaMinor,
            chargeReason: ModifierChargeReason.includedChoice,
            quantity: 1,
            unitPriceMinor: sandwichBreadPriceDeltaMinor,
            priceEffectMinor: sandwichBreadPriceDeltaMinor,
            sortKey: sortKey,
          ),
        );
        sortKey += 10;
      }
      for (final int sauceProductId in sandwichSelection.sauceProductIds) {
        modifiers.add(
          OrderModifier(
            id: 0,
            uuid: createUuid(),
            transactionLineId: transactionLineId,
            action: ModifierAction.choice,
            itemName: _requireProductName(sauceProductId, productNamesById),
            extraPriceMinor: 0,
            chargeReason: ModifierChargeReason.includedChoice,
            itemProductId: sauceProductId,
            priceBehavior: ModifierPriceBehavior.free,
            uiSection: ModifierUiSection.sauces,
            quantity: 1,
            unitPriceMinor: 0,
            priceEffectMinor: 0,
            sortKey: sortKey,
          ),
        );
        sortKey += 10;
      }
      if (sandwichSelection.toastOption != null) {
        modifiers.add(
          OrderModifier(
            id: 0,
            uuid: createUuid(),
            transactionLineId: transactionLineId,
            action: ModifierAction.choice,
            itemName: sandwichToastLabel(sandwichSelection.toastOption!),
            extraPriceMinor: 0,
            chargeReason: ModifierChargeReason.includedChoice,
            quantity: 1,
            unitPriceMinor: 0,
            priceEffectMinor: 0,
            sortKey: sortKey,
          ),
        );
        sortKey += 10;
      }
    }

    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedComponentActions) {
      switch (action.action) {
        case MealCustomizationAction.remove:
          final int itemProductId = _requireProductId(
            action.itemProductId,
            action: action,
          );
          modifiers.add(
            OrderModifier(
              id: 0,
              uuid: createUuid(),
              transactionLineId: transactionLineId,
              action: ModifierAction.remove,
              itemName: _requireProductName(itemProductId, productNamesById),
              extraPriceMinor: 0,
              itemProductId: itemProductId,
              quantity: action.quantity,
              unitPriceMinor: 0,
              priceEffectMinor: 0,
              sortKey: sortKey,
            ),
          );
          sortKey += 10;
          break;
        case MealCustomizationAction.swap:
          final int sourceItemProductId = _requireProductId(
            action.sourceItemProductId,
            action: action,
          );
          final int targetItemProductId = _requireProductId(
            action.itemProductId,
            action: action,
          );
          modifiers.add(
            OrderModifier(
              id: 0,
              uuid: createUuid(),
              transactionLineId: transactionLineId,
              action: ModifierAction.remove,
              itemName: _requireProductName(
                sourceItemProductId,
                productNamesById,
              ),
              extraPriceMinor: 0,
              itemProductId: sourceItemProductId,
              quantity: action.quantity,
              unitPriceMinor: 0,
              priceEffectMinor: 0,
              sortKey: sortKey,
            ),
          );
          sortKey += 10;
          modifiers.add(
            OrderModifier(
              id: 0,
              uuid: createUuid(),
              transactionLineId: transactionLineId,
              action: ModifierAction.add,
              itemName: _requireProductName(
                targetItemProductId,
                productNamesById,
              ),
              extraPriceMinor: action.priceDeltaMinor < 0
                  ? 0
                  : action.priceDeltaMinor,
              chargeReason: _mapChargeReason(action.chargeReason),
              itemProductId: targetItemProductId,
              quantity: action.quantity,
              unitPriceMinor: _deriveUnitPriceMinor(action),
              priceEffectMinor: action.priceDeltaMinor,
              sortKey: sortKey,
            ),
          );
          sortKey += 10;
          break;
        case MealCustomizationAction.extra:
          final int itemProductId = _requireProductId(
            action.itemProductId,
            action: action,
          );
          modifiers.add(
            OrderModifier(
              id: 0,
              uuid: createUuid(),
              transactionLineId: transactionLineId,
              action: ModifierAction.add,
              itemName: _requireProductName(itemProductId, productNamesById),
              extraPriceMinor: action.priceDeltaMinor < 0
                  ? 0
                  : action.priceDeltaMinor,
              chargeReason: _mapChargeReason(action.chargeReason),
              itemProductId: itemProductId,
              quantity: action.quantity,
              unitPriceMinor: _deriveUnitPriceMinor(action),
              priceEffectMinor: action.priceDeltaMinor,
              sortKey: sortKey,
            ),
          );
          sortKey += 10;
          break;
        case MealCustomizationAction.discount:
          throw DatabaseException(
            'Discount actions must be persisted from triggeredDiscounts, not component actions.',
          );
      }
    }

    for (final MealCustomizationSemanticAction action
        in snapshot.resolvedExtraActions) {
      if (action.action != MealCustomizationAction.extra) {
        throw DatabaseException(
          'Extra persistence path received a non-extra action: ${action.action.name}.',
        );
      }
      final int itemProductId = _requireProductId(
        action.itemProductId,
        action: action,
      );
      modifiers.add(
        OrderModifier(
          id: 0,
          uuid: createUuid(),
          transactionLineId: transactionLineId,
          action: ModifierAction.add,
          itemName: _requireProductName(itemProductId, productNamesById),
          extraPriceMinor: action.priceDeltaMinor < 0
              ? 0
              : action.priceDeltaMinor,
          chargeReason: _mapChargeReason(action.chargeReason),
          itemProductId: itemProductId,
          quantity: action.quantity,
          unitPriceMinor: _deriveUnitPriceMinor(action),
          priceEffectMinor: action.priceDeltaMinor,
          sortKey: sortKey,
        ),
      );
      sortKey += 10;
    }

    for (final MealCustomizationSemanticAction action
        in snapshot.triggeredDiscounts) {
      modifiers.add(
        OrderModifier(
          id: 0,
          uuid: createUuid(),
          transactionLineId: transactionLineId,
          action: ModifierAction.add,
          itemName: _discountLabel(action.chargeReason),
          extraPriceMinor: 0,
          chargeReason: _mapChargeReason(action.chargeReason),
          quantity: 1,
          unitPriceMinor: 0,
          priceEffectMinor: action.priceDeltaMinor,
          sortKey: sortKey,
        ),
      );
      sortKey += 10;
    }

    final int modifierTotalMinor = modifiers.fold<int>(
      0,
      (int total, OrderModifier modifier) => total + modifier.priceEffectMinor,
    );

    return MealCustomizationPersistenceProjection(
      productId: snapshot.productId,
      profileId: snapshot.profileId,
      modifierTotalMinor: modifierTotalMinor,
      modifiers: List<OrderModifier>.unmodifiable(modifiers),
      appliedRuleIds: List<int>.unmodifiable(snapshot.appliedRuleIds),
    );
  }

  int _requireProductId(
    int? productId, {
    required MealCustomizationSemanticAction action,
  }) {
    if (productId != null) {
      return productId;
    }
    throw DatabaseException(
      'Meal customization action ${action.action.name} is missing item_product_id.',
    );
  }

  String _requireProductName(int productId, Map<int, String> productNamesById) {
    final String? productName = productNamesById[productId];
    if (productName != null && productName.trim().isNotEmpty) {
      return productName;
    }
    throw DatabaseException(
      'Meal customization persistence is missing a product name for item $productId.',
    );
  }

  int _deriveUnitPriceMinor(MealCustomizationSemanticAction action) {
    if (action.priceDeltaMinor <= 0) {
      return 0;
    }
    if (action.quantity <= 1) {
      return action.priceDeltaMinor;
    }
    final int remainder = action.priceDeltaMinor % action.quantity;
    if (remainder != 0) {
      return action.priceDeltaMinor;
    }
    return action.priceDeltaMinor ~/ action.quantity;
  }

  ModifierChargeReason? _mapChargeReason(
    MealCustomizationChargeReason? chargeReason,
  ) {
    switch (chargeReason) {
      case null:
        return null;
      case MealCustomizationChargeReason.freeSwap:
        return ModifierChargeReason.freeSwap;
      case MealCustomizationChargeReason.paidSwap:
        return ModifierChargeReason.paidSwap;
      case MealCustomizationChargeReason.extraAdd:
        return ModifierChargeReason.extraAdd;
      case MealCustomizationChargeReason.removalDiscount:
        return ModifierChargeReason.removalDiscount;
      case MealCustomizationChargeReason.comboDiscount:
        return ModifierChargeReason.comboDiscount;
    }
  }

  String _discountLabel(MealCustomizationChargeReason? chargeReason) {
    switch (chargeReason) {
      case MealCustomizationChargeReason.removalDiscount:
        return 'Meal removal discount';
      case MealCustomizationChargeReason.comboDiscount:
        return 'Meal combo discount';
      case MealCustomizationChargeReason.freeSwap:
      case MealCustomizationChargeReason.paidSwap:
      case MealCustomizationChargeReason.extraAdd:
      case null:
        throw DatabaseException(
          'Invalid meal customization discount charge reason: ${chargeReason?.name ?? 'null'}.',
        );
    }
  }
}
