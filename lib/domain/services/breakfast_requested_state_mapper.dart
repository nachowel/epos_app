import '../models/breakfast_rebuild.dart';
import '../models/breakfast_cooking_instruction.dart';
import '../models/order_modifier.dart';
import 'breakfast_requested_state_transformer.dart';

/// Reverse-maps a persisted breakfast snapshot into a classification-free
/// requested state.
///
/// This layer is intentionally isolated from the forward requested-state
/// transform. It may read persisted semantic rows when reconstruction is
/// required, but it must only emit user-intent fields:
/// - removed set items
/// - added products
/// - chosen groups
///
/// It must never expose `free_swap`, `paid_swap`, `included_choice`,
/// `extra_add`, or `charge_reason` in the requested state itself.
class BreakfastRequestedStateMapper {
  const BreakfastRequestedStateMapper._();

  /// Strict reverse mapping that uses only explicit persisted snapshot fields.
  ///
  /// Choice selections are reconstructed only when `sourceGroupId` is already
  /// present on the persisted semantic rows.
  static BreakfastRequestedState fromPersistedSnapshot({
    required List<OrderModifier> modifiers,
    List<BreakfastCookingInstructionRequest> cookingInstructions =
        const <BreakfastCookingInstructionRequest>[],
  }) {
    return _reconstruct(
      modifiers: modifiers,
      cookingInstructions: cookingInstructions,
      resolveGroupId: (OrderModifier modifier) => modifier.sourceGroupId,
      sourceLabel: 'fromPersistedSnapshot',
    );
  }

  /// Compatibility-only reverse mapping for legacy semantic rows that are
  /// missing `sourceGroupId`.
  ///
  /// This fallback is explicitly isolated here so any semantic inference stays
  /// out of the requested-state model and out of the deterministic apply path.
  static BreakfastRequestedState
  fromPersistedSnapshotWithConfigurationFallback({
    required List<OrderModifier> modifiers,
    required BreakfastSetConfiguration configuration,
    List<BreakfastCookingInstructionRequest> cookingInstructions =
        const <BreakfastCookingInstructionRequest>[],
  }) {
    return _reconstruct(
      modifiers: modifiers,
      cookingInstructions: cookingInstructions,
      resolveGroupId: (OrderModifier modifier) {
        final int? itemProductId = modifier.itemProductId;
        return modifier.sourceGroupId ??
            (itemProductId == null
                ? null
                : configuration
                      .findGroupByMemberProductId(itemProductId)
                      ?.groupId);
      },
      sourceLabel: 'fromPersistedSnapshotWithConfigurationFallback',
    );
  }

  static BreakfastRequestedState reconstruct({
    required List<OrderModifier> modifiers,
    required BreakfastSetConfiguration configuration,
    List<BreakfastCookingInstructionRequest> cookingInstructions =
        const <BreakfastCookingInstructionRequest>[],
  }) {
    return fromPersistedSnapshotWithConfigurationFallback(
      modifiers: modifiers,
      configuration: configuration,
      cookingInstructions: cookingInstructions,
    );
  }

  static BreakfastRequestedState reconstructWithoutConfiguration({
    required List<OrderModifier> modifiers,
    List<BreakfastCookingInstructionRequest> cookingInstructions =
        const <BreakfastCookingInstructionRequest>[],
  }) {
    return fromPersistedSnapshot(
      modifiers: modifiers,
      cookingInstructions: cookingInstructions,
    );
  }

  static BreakfastRequestedState _reconstruct({
    required List<OrderModifier> modifiers,
    required List<BreakfastCookingInstructionRequest> cookingInstructions,
    required int? Function(OrderModifier modifier) resolveGroupId,
    required String sourceLabel,
  }) {
    final Map<int, int> removedByProductId = <int, int>{};
    final Map<int, _ChoiceSelectionAccumulator> choiceSelections =
        <int, _ChoiceSelectionAccumulator>{};
    final Set<int> overflowModifierIds = <int>{};
    final Set<int> customModifierIds = <int>{};

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
          modifier.chargeReason != ModifierChargeReason.includedChoice) {
        continue;
      }
      final int? resolvedGroupId = resolveGroupId(modifier);
      if (resolvedGroupId == null) {
        continue;
      }
      if (modifier.itemProductId == null) {
        choiceSelections[resolvedGroupId] = _ChoiceSelectionAccumulator(
          groupId: resolvedGroupId,
          selectedItemProductId: null,
          requestedQuantity: modifier.quantity,
        );
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

    final List<BreakfastCustomModifierRequest> customModifiers =
        <BreakfastCustomModifierRequest>[];
    for (final OrderModifier modifier in modifiers) {
      final BreakfastCustomModifierRequest? customModifier =
          _customModifierFromPersistedRow(modifier);
      if (customModifier == null) {
        continue;
      }
      customModifierIds.add(modifier.id);
      customModifiers.add(customModifier);
    }
    customModifiers.sort((
      BreakfastCustomModifierRequest a,
      BreakfastCustomModifierRequest b,
    ) {
      final int sortCompare = a.sortKey.compareTo(b.sortKey);
      if (sortCompare != 0) {
        return sortCompare;
      }
      final int productCompare = a.itemProductId.compareTo(b.itemProductId);
      if (productCompare != 0) {
        return productCompare;
      }
      return a.itemName.compareTo(b.itemName);
    });

    final List<BreakfastAddedProductRequest> addedProducts =
        modifiers
            .where(
              (OrderModifier modifier) =>
                  modifier.action == ModifierAction.add &&
                  !overflowModifierIds.contains(modifier.id) &&
                  !customModifierIds.contains(modifier.id) &&
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

    return BreakfastRequestedStateTransformer.assertInvariant(
      BreakfastRequestedState(
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
                (
                  BreakfastChosenGroupRequest a,
                  BreakfastChosenGroupRequest b,
                ) => a.groupId.compareTo(b.groupId),
              ),
        cookingInstructions:
            List<BreakfastCookingInstructionRequest>.from(cookingInstructions)
              ..sort(
                (
                  BreakfastCookingInstructionRequest a,
                  BreakfastCookingInstructionRequest b,
                ) => a.itemProductId.compareTo(b.itemProductId),
              ),
        customModifiers: customModifiers,
      ),
      source: sourceLabel,
    );
  }

  static BreakfastCustomModifierRequest? _customModifierFromPersistedRow(
    OrderModifier modifier,
  ) {
    if (modifier.action != ModifierAction.add ||
        modifier.chargeReason != ModifierChargeReason.extraAdd ||
        modifier.itemProductId == null ||
        modifier.quantity != 1 ||
        modifier.extraPriceMinor != 0 ||
        modifier.priceEffectMinor != 0) {
      return null;
    }

    final String itemName = modifier.itemName.trim();
    if (!_isBreakfastCustomModifierName(itemName)) {
      return null;
    }
    return BreakfastCustomModifierRequest(
      itemProductId: modifier.itemProductId!,
      itemName: itemName,
      sortKey: _requestedCustomSortKey(modifier.sortKey),
    );
  }

  static bool _isBreakfastCustomModifierName(String itemName) {
    return itemName.startsWith('Egg:') ||
        itemName.startsWith('Cook:') ||
        itemName.startsWith('Bread:');
  }

  static int _requestedCustomSortKey(int persistedSortKey) {
    if (persistedSortKey > 2500) {
      return persistedSortKey - 2500;
    }
    return persistedSortKey;
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
