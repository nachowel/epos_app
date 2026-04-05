import 'breakfast_rebuild.dart';
import '../services/breakfast_requested_state_transformer.dart';

enum BreakfastLineEditType {
  setRemovedQuantity,
  setAddedQuantity,
  chooseGroup,
  clearGroup,
  setCookingInstruction,
}

class BreakfastLineEdit {
  const BreakfastLineEdit._({
    required this.type,
    this.itemProductId,
    this.quantity,
    this.groupId,
    this.selectedItemProductId,
    this.instructionCode,
    this.instructionLabel,
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
    required int? selectedItemProductId,
    required int quantity,
  }) : this._(
         type: BreakfastLineEditType.chooseGroup,
         groupId: groupId,
         selectedItemProductId: selectedItemProductId,
         quantity: quantity,
       );

  const BreakfastLineEdit.clearGroup({required int groupId})
    : this._(type: BreakfastLineEditType.clearGroup, groupId: groupId);

  const BreakfastLineEdit.setCookingInstruction({
    required int itemProductId,
    required String? instructionCode,
    required String? instructionLabel,
  }) : this._(
         type: BreakfastLineEditType.setCookingInstruction,
         itemProductId: itemProductId,
         instructionCode: instructionCode,
         instructionLabel: instructionLabel,
       );

  final BreakfastLineEditType type;
  final int? itemProductId;
  final int? quantity;
  final int? groupId;
  final int? selectedItemProductId;
  final String? instructionCode;
  final String? instructionLabel;

  BreakfastRequestedState applyTo(BreakfastRequestedState state) {
    switch (type) {
      case BreakfastLineEditType.setRemovedQuantity:
        return BreakfastRequestedStateTransformer.setRemovedQuantity(
          currentState: state,
          itemProductId: itemProductId!,
          quantity: quantity!,
        );
      case BreakfastLineEditType.setAddedQuantity:
        return BreakfastRequestedStateTransformer.setAddedQuantity(
          currentState: state,
          itemProductId: itemProductId!,
          quantity: quantity!,
        );
      case BreakfastLineEditType.chooseGroup:
        return BreakfastRequestedStateTransformer.chooseGroup(
          currentState: state,
          groupId: groupId!,
          selectedItemProductId: selectedItemProductId,
          requestedQuantity: quantity!,
        );
      case BreakfastLineEditType.clearGroup:
        return BreakfastRequestedStateTransformer.clearGroup(
          currentState: state,
          groupId: groupId!,
        );
      case BreakfastLineEditType.setCookingInstruction:
        return BreakfastRequestedStateTransformer.setCookingInstruction(
          currentState: state,
          itemProductId: itemProductId!,
          instructionCode: instructionCode,
          instructionLabel: instructionLabel,
        );
    }
  }
}
