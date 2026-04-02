import 'breakfast_rebuild.dart';

enum BreakfastLineEditType {
  setRemovedQuantity,
  setAddedQuantity,
  chooseGroup,
  clearGroup,
}

class BreakfastLineEdit {
  const BreakfastLineEdit._({
    required this.type,
    this.itemProductId,
    this.quantity,
    this.groupId,
    this.selectedItemProductId,
  });

  const BreakfastLineEdit.setRemovedQuantity({
    required int itemProductId,
    required int quantity,
  }) : this._(
         type: BreakfastLineEditType.setRemovedQuantity,
         itemProductId: itemProductId,
         quantity: quantity,
       );

  const BreakfastLineEdit.setAddedQuantity({
    required int itemProductId,
    required int quantity,
  }) : this._(
         type: BreakfastLineEditType.setAddedQuantity,
         itemProductId: itemProductId,
         quantity: quantity,
       );

  const BreakfastLineEdit.chooseGroup({
    required int groupId,
    required int selectedItemProductId,
    required int quantity,
  }) : this._(
         type: BreakfastLineEditType.chooseGroup,
         groupId: groupId,
         selectedItemProductId: selectedItemProductId,
         quantity: quantity,
       );

  const BreakfastLineEdit.clearGroup({required int groupId})
    : this._(type: BreakfastLineEditType.clearGroup, groupId: groupId);

  final BreakfastLineEditType type;
  final int? itemProductId;
  final int? quantity;
  final int? groupId;
  final int? selectedItemProductId;

  BreakfastRequestedState applyTo(BreakfastRequestedState state) {
    switch (type) {
      case BreakfastLineEditType.setRemovedQuantity:
        return state.copyWith(
          removedSetItems: _replaceRemovedQuantity(
            state.removedSetItems,
            itemProductId: itemProductId!,
            quantity: quantity!,
          ),
        );
      case BreakfastLineEditType.setAddedQuantity:
        return state.copyWith(
          addedProducts: _replaceAddedQuantity(
            state.addedProducts,
            itemProductId: itemProductId!,
            quantity: quantity!,
          ),
        );
      case BreakfastLineEditType.chooseGroup:
        return state.copyWith(
          chosenGroups: _replaceGroupChoice(
            state.chosenGroups,
            groupId: groupId!,
            selectedItemProductId: selectedItemProductId,
            quantity: quantity!,
          ),
        );
      case BreakfastLineEditType.clearGroup:
        return state.copyWith(
          chosenGroups: _replaceGroupChoice(
            state.chosenGroups,
            groupId: groupId!,
            selectedItemProductId: null,
            quantity: 0,
          ),
        );
    }
  }

  List<BreakfastRemovedSetItemRequest> _replaceRemovedQuantity(
    List<BreakfastRemovedSetItemRequest> items, {
    required int itemProductId,
    required int quantity,
  }) {
    final List<BreakfastRemovedSetItemRequest> next =
        items
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
      (
        BreakfastRemovedSetItemRequest a,
        BreakfastRemovedSetItemRequest b,
      ) => a.itemProductId.compareTo(b.itemProductId),
    );
    return next;
  }

  List<BreakfastAddedProductRequest> _replaceAddedQuantity(
    List<BreakfastAddedProductRequest> items, {
    required int itemProductId,
    required int quantity,
  }) {
    int existingOrderHint = 0;
    for (final BreakfastAddedProductRequest item in items) {
      if (item.orderHint >= existingOrderHint) {
        existingOrderHint = item.orderHint + 1;
      }
    }
    final List<BreakfastAddedProductRequest> next = <BreakfastAddedProductRequest>[];
    for (final BreakfastAddedProductRequest item in items) {
      if (item.itemProductId == itemProductId) {
        existingOrderHint = item.orderHint;
        continue;
      }
      next.add(item);
    }
    if (quantity > 0) {
      next.add(
        BreakfastAddedProductRequest(
          itemProductId: itemProductId,
          quantity: quantity,
          orderHint: existingOrderHint,
        ),
      );
    }
    next.sort(
      (BreakfastAddedProductRequest a, BreakfastAddedProductRequest b) {
        final int orderHintCompare = a.orderHint.compareTo(b.orderHint);
        if (orderHintCompare != 0) {
          return orderHintCompare;
        }
        return a.itemProductId.compareTo(b.itemProductId);
      },
    );
    return next;
  }

  List<BreakfastChosenGroupRequest> _replaceGroupChoice(
    List<BreakfastChosenGroupRequest> groups, {
    required int groupId,
    required int? selectedItemProductId,
    required int quantity,
  }) {
    final List<BreakfastChosenGroupRequest> next =
        groups
            .where((BreakfastChosenGroupRequest group) => group.groupId != groupId)
            .toList(growable: true);
    next.add(
      BreakfastChosenGroupRequest(
        groupId: groupId,
        selectedItemProductId: selectedItemProductId,
        requestedQuantity: quantity,
      ),
    );
    next.sort(
      (BreakfastChosenGroupRequest a, BreakfastChosenGroupRequest b) =>
          a.groupId.compareTo(b.groupId),
    );
    return next;
  }
}
