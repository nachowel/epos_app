import '../models/breakfast_cooking_instruction.dart';
import '../models/breakfast_rebuild.dart';

/// Applies intent-only breakfast requests to an existing requested state.
///
/// This layer must remain deterministic and classification-free:
/// it may only transform remove/add/choose intent fields.
class BreakfastRequestedStateTransformer {
  const BreakfastRequestedStateTransformer._();

  static BreakfastRequestedState assertInvariant(
    BreakfastRequestedState state, {
    required String source,
  }) {
    return _assertInvariant(state, source: source);
  }

  static BreakfastRequestedState setRemovedQuantity({
    required BreakfastRequestedState currentState,
    required int itemProductId,
    required int quantity,
  }) {
    final List<BreakfastRemovedSetItemRequest> next = currentState
        .removedSetItems
        .where(
          (BreakfastRemovedSetItemRequest item) =>
              item.itemProductId != itemProductId,
        )
        .toList(growable: true);
    if (quantity > 0) {
      next.add(
        BreakfastRemovedSetItemRequest(
          itemProductId: itemProductId,
          quantity: quantity,
        ),
      );
    }
    next.sort(
      (BreakfastRemovedSetItemRequest a, BreakfastRemovedSetItemRequest b) =>
          a.itemProductId.compareTo(b.itemProductId),
    );
    return _assertInvariant(
      currentState.copyWith(removedSetItems: next),
      source: 'setRemovedQuantity',
    );
  }

  static BreakfastRequestedState setAddedQuantity({
    required BreakfastRequestedState currentState,
    required int itemProductId,
    required int quantity,
  }) {
    int nextOrderHint = 0;
    for (final BreakfastAddedProductRequest item
        in currentState.addedProducts) {
      if (item.orderHint >= nextOrderHint) {
        nextOrderHint = item.orderHint + 1;
      }
    }

    final List<BreakfastAddedProductRequest> next =
        <BreakfastAddedProductRequest>[];
    for (final BreakfastAddedProductRequest item
        in currentState.addedProducts) {
      if (item.itemProductId == itemProductId) {
        nextOrderHint = item.orderHint;
        continue;
      }
      next.add(item);
    }

    if (quantity > 0) {
      next.add(
        BreakfastAddedProductRequest(
          itemProductId: itemProductId,
          quantity: quantity,
          orderHint: nextOrderHint,
        ),
      );
    }

    next.sort((BreakfastAddedProductRequest a, BreakfastAddedProductRequest b) {
      final int orderHintCompare = a.orderHint.compareTo(b.orderHint);
      if (orderHintCompare != 0) {
        return orderHintCompare;
      }
      return a.itemProductId.compareTo(b.itemProductId);
    });
    return _assertInvariant(
      currentState.copyWith(addedProducts: next),
      source: 'setAddedQuantity',
    );
  }

  static BreakfastRequestedState chooseGroup({
    required BreakfastRequestedState currentState,
    required int groupId,
    required int? selectedItemProductId,
    required int requestedQuantity,
  }) {
    final List<BreakfastChosenGroupRequest> next = currentState.chosenGroups
        .where((BreakfastChosenGroupRequest group) => group.groupId != groupId)
        .toList(growable: true);
    next.add(
      BreakfastChosenGroupRequest(
        groupId: groupId,
        selectedItemProductId: selectedItemProductId,
        requestedQuantity: requestedQuantity,
      ),
    );
    next.sort(
      (BreakfastChosenGroupRequest a, BreakfastChosenGroupRequest b) =>
          a.groupId.compareTo(b.groupId),
    );
    return _assertInvariant(
      currentState.copyWith(chosenGroups: next),
      source: 'chooseGroup',
    );
  }

  static BreakfastRequestedState clearGroup({
    required BreakfastRequestedState currentState,
    required int groupId,
  }) {
    return chooseGroup(
      currentState: currentState,
      groupId: groupId,
      selectedItemProductId: null,
      requestedQuantity: 0,
    );
  }

  static BreakfastRequestedState setCookingInstruction({
    required BreakfastRequestedState currentState,
    required int itemProductId,
    required String? instructionCode,
    required String? instructionLabel,
  }) {
    final List<BreakfastCookingInstructionRequest> next = currentState
        .cookingInstructions
        .where(
          (BreakfastCookingInstructionRequest item) =>
              item.itemProductId != itemProductId,
        )
        .toList(growable: true);
    if (instructionCode != null &&
        instructionCode.isNotEmpty &&
        instructionLabel != null &&
        instructionLabel.isNotEmpty) {
      next.add(
        BreakfastCookingInstructionRequest(
          itemProductId: itemProductId,
          instructionCode: instructionCode,
          instructionLabel: instructionLabel,
        ),
      );
    }
    next.sort(
      (
        BreakfastCookingInstructionRequest a,
        BreakfastCookingInstructionRequest b,
      ) => a.itemProductId.compareTo(b.itemProductId),
    );
    return _assertInvariant(
      currentState.copyWith(cookingInstructions: next),
      source: 'setCookingInstruction',
    );
  }

  static BreakfastRequestedState _assertInvariant(
    BreakfastRequestedState state, {
    required String source,
  }) {
    _assertStrictAscending(
      values: state.removedSetItems
          .map((BreakfastRemovedSetItemRequest item) => item.itemProductId)
          .toList(growable: false),
      label: 'removedSetItems.itemProductId',
      source: source,
    );
    _assertStrictAscending(
      values: state.chosenGroups
          .map((BreakfastChosenGroupRequest group) => group.groupId)
          .toList(growable: false),
      label: 'chosenGroups.groupId',
      source: source,
    );
    _assertStrictAscending(
      values: state.cookingInstructions
          .map(
            (BreakfastCookingInstructionRequest instruction) =>
                instruction.itemProductId,
          )
          .toList(growable: false),
      label: 'cookingInstructions.itemProductId',
      source: source,
    );
    _assertUniquePairs(
      values: state.addedProducts
          .map(
            (BreakfastAddedProductRequest add) =>
                (add.orderHint, add.itemProductId),
          )
          .toList(growable: false),
      label: 'addedProducts.(orderHint,itemProductId)',
      source: source,
    );

    for (final BreakfastRemovedSetItemRequest item in state.removedSetItems) {
      if (item.quantity < 0) {
        throw StateError(
          'Breakfast requested-state invariant failed in $source: removedSetItems contains negative quantity for product ${item.itemProductId}.',
        );
      }
    }
    for (final BreakfastAddedProductRequest add in state.addedProducts) {
      if (add.quantity < 0) {
        throw StateError(
          'Breakfast requested-state invariant failed in $source: addedProducts contains negative quantity for product ${add.itemProductId}.',
        );
      }
    }
    for (final BreakfastChosenGroupRequest group in state.chosenGroups) {
      if (group.requestedQuantity < 0) {
        throw StateError(
          'Breakfast requested-state invariant failed in $source: chosenGroups contains negative quantity for group ${group.groupId}.',
        );
      }
    }
    return state;
  }

  static void _assertStrictAscending({
    required List<int> values,
    required String label,
    required String source,
  }) {
    for (int index = 1; index < values.length; index += 1) {
      if (values[index - 1].compareTo(values[index]) >= 0) {
        throw StateError(
          'Breakfast requested-state invariant failed in $source: $label must remain strictly ascending.',
        );
      }
    }
  }

  static void _assertUniquePairs({
    required List<(int, int)> values,
    required String label,
    required String source,
  }) {
    final Set<(int, int)> seen = <(int, int)>{};
    for (final (int, int) value in values) {
      if (!seen.add(value)) {
        throw StateError(
          'Breakfast requested-state invariant failed in $source: duplicate $label value ($value).',
        );
      }
    }
  }
}
