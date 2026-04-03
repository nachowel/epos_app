import '../models/breakfast_rebuild.dart';
import '../models/order_modifier.dart';

class BreakfastRequestedStateMapper {
  const BreakfastRequestedStateMapper._();

  static BreakfastRequestedState reconstruct({
    required List<OrderModifier> modifiers,
    required BreakfastSetConfiguration configuration,
  }) {
    return _reconstruct(
      modifiers: modifiers,
      resolveGroupId: (OrderModifier modifier) {
        final int? itemProductId = modifier.itemProductId;
        return modifier.sourceGroupId ??
            (itemProductId == null
                ? null
                : configuration
                      .findGroupByMemberProductId(itemProductId)
                      ?.groupId);
      },
    );
  }

  static BreakfastRequestedState reconstructWithoutConfiguration({
    required List<OrderModifier> modifiers,
  }) {
    return _reconstruct(
      modifiers: modifiers,
      resolveGroupId: (OrderModifier modifier) => modifier.sourceGroupId,
    );
  }

  static BreakfastRequestedState _reconstruct({
    required List<OrderModifier> modifiers,
    required int? Function(OrderModifier modifier) resolveGroupId,
  }) {
    final Map<int, int> removedByProductId = <int, int>{};
    final Map<int, _ChoiceSelectionAccumulator> choiceSelections =
        <int, _ChoiceSelectionAccumulator>{};
    final Set<int> overflowModifierIds = <int>{};

    for (final OrderModifier modifier in modifiers) {
      if (modifier.action == ModifierAction.remove &&
          modifier.itemProductId != null) {
        removedByProductId.update(
          modifier.itemProductId!,
          (int quantity) => quantity + modifier.quantity,
          ifAbsent: () => modifier.quantity,
        );
      }
    }

    for (final OrderModifier modifier in modifiers) {
      if (modifier.action != ModifierAction.choice ||
          modifier.chargeReason != ModifierChargeReason.includedChoice ||
          modifier.itemProductId == null) {
        continue;
      }
      final int? resolvedGroupId = resolveGroupId(modifier);
      if (resolvedGroupId == null) {
        continue;
      }
      int overflowQuantity = 0;
      for (final OrderModifier candidate in modifiers) {
        if (candidate.id == modifier.id ||
            candidate.action != ModifierAction.add ||
            candidate.chargeReason != ModifierChargeReason.extraAdd ||
            candidate.itemProductId == null ||
            candidate.itemProductId != modifier.itemProductId) {
          continue;
        }
        final int? candidateGroupId = resolveGroupId(candidate);
        if (candidateGroupId == resolvedGroupId) {
          overflowQuantity += candidate.quantity;
          overflowModifierIds.add(candidate.id);
        }
      }
      choiceSelections[resolvedGroupId] = _ChoiceSelectionAccumulator(
        groupId: resolvedGroupId,
        selectedItemProductId: modifier.itemProductId,
        requestedQuantity: modifier.quantity + overflowQuantity,
      );
    }

    final List<BreakfastAddedProductRequest> addedProducts =
        modifiers
            .where(
              (OrderModifier modifier) =>
                  modifier.action == ModifierAction.add &&
                  !overflowModifierIds.contains(modifier.id) &&
                  modifier.itemProductId != null,
            )
            .map(
              (OrderModifier modifier) => BreakfastAddedProductRequest(
                itemProductId: modifier.itemProductId!,
                quantity: modifier.quantity,
                orderHint: modifier.sortKey,
              ),
            )
            .toList(growable: true)
          ..sort((
            BreakfastAddedProductRequest a,
            BreakfastAddedProductRequest b,
          ) {
            final int orderCompare = a.orderHint.compareTo(b.orderHint);
            if (orderCompare != 0) {
              return orderCompare;
            }
            return a.itemProductId.compareTo(b.itemProductId);
          });

    return BreakfastRequestedState(
      removedSetItems: removedByProductId.entries
          .map(
            (MapEntry<int, int> entry) => BreakfastRemovedSetItemRequest(
              itemProductId: entry.key,
              quantity: entry.value,
            ),
          )
          .toList(growable: false),
      addedProducts: addedProducts,
      chosenGroups:
          choiceSelections.values
              .map(
                (_ChoiceSelectionAccumulator selection) =>
                    BreakfastChosenGroupRequest(
                      groupId: selection.groupId,
                      selectedItemProductId: selection.selectedItemProductId,
                      requestedQuantity: selection.requestedQuantity,
                    ),
              )
              .toList(growable: false)
            ..sort(
              (BreakfastChosenGroupRequest a, BreakfastChosenGroupRequest b) =>
                  a.groupId.compareTo(b.groupId),
            ),
    );
  }
}

class _ChoiceSelectionAccumulator {
  const _ChoiceSelectionAccumulator({
    required this.groupId,
    required this.selectedItemProductId,
    required this.requestedQuantity,
  });

  final int groupId;
  final int? selectedItemProductId;
  final int requestedQuantity;
}
