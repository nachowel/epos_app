class BreakfastCookingInstructionRequest {
  const BreakfastCookingInstructionRequest({
    required this.itemProductId,
    required this.instructionCode,
    required this.instructionLabel,
  });

  final int itemProductId;
  final String instructionCode;
  final String instructionLabel;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BreakfastCookingInstructionRequest &&
        other.itemProductId == itemProductId &&
        other.instructionCode == instructionCode &&
        other.instructionLabel == instructionLabel;
  }

  @override
  int get hashCode =>
      Object.hash(itemProductId, instructionCode, instructionLabel);
}

class BreakfastCookingInstructionOption {
  const BreakfastCookingInstructionOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

class BreakfastCookingInstructionTarget {
  const BreakfastCookingInstructionTarget({
    required this.itemProductId,
    required this.itemName,
    required this.quantity,
    required this.sortKey,
    required this.options,
    this.selectedInstructionCode,
    this.selectedInstructionLabel,
  });

  final int itemProductId;
  final String itemName;
  final int quantity;
  final int sortKey;
  final List<BreakfastCookingInstructionOption> options;
  final String? selectedInstructionCode;
  final String? selectedInstructionLabel;

  bool get hasSelection => selectedInstructionCode != null;
}

class BreakfastCookingInstructionRecord {
  const BreakfastCookingInstructionRecord({
    required this.id,
    required this.uuid,
    required this.transactionLineId,
    required this.itemProductId,
    required this.itemName,
    required this.instructionCode,
    required this.instructionLabel,
    required this.appliedQuantity,
    required this.sortKey,
  });

  final int id;
  final String uuid;
  final int transactionLineId;
  final int itemProductId;
  final String itemName;
  final String instructionCode;
  final String instructionLabel;
  final int appliedQuantity;
  final int sortKey;

  String get kitchenLabel {
    final String quantitySuffix = appliedQuantity > 1
        ? ' x$appliedQuantity'
        : ' x1';
    return '$itemName$quantitySuffix - ${instructionLabel.toUpperCase()}';
  }
}

class BreakfastCookingInstructionDisplayLine {
  const BreakfastCookingInstructionDisplayLine({
    required this.itemName,
    required this.instructionLabel,
  });

  final String itemName;
  final String instructionLabel;

  String get cartLabel => '$itemName: $instructionLabel';
}
