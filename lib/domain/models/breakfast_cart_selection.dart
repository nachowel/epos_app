import 'breakfast_cooking_instruction.dart';
import 'breakfast_rebuild.dart';

enum BreakfastCartModifierTone { removed, added }

class BreakfastCartModifierDisplayLine {
  const BreakfastCartModifierDisplayLine({
    required this.prefix,
    required this.itemName,
    required this.tone,
  });

  final String prefix;
  final String itemName;
  final BreakfastCartModifierTone tone;

  String get cartLabel => '$prefix $itemName';
}

class BreakfastCartChoiceDisplayLine {
  const BreakfastCartChoiceDisplayLine({
    required this.groupName,
    required this.selectedLabel,
  });

  final String groupName;
  final String selectedLabel;

  String get cartLabel => '$groupName: $selectedLabel';
}

class BreakfastCartSelection {
  const BreakfastCartSelection({
    required this.requestedState,
    required this.rebuildResult,
    this.modifierDisplayLines = const <BreakfastCartModifierDisplayLine>[],
    this.choiceDisplayLines = const <BreakfastCartChoiceDisplayLine>[],
    this.cookingDisplayLines = const <BreakfastCookingInstructionDisplayLine>[],
  });

  final BreakfastRequestedState requestedState;
  final BreakfastRebuildResult rebuildResult;
  final List<BreakfastCartModifierDisplayLine> modifierDisplayLines;
  final List<BreakfastCartChoiceDisplayLine> choiceDisplayLines;
  final List<BreakfastCookingInstructionDisplayLine> cookingDisplayLines;

  int get modifierTotalMinor => rebuildResult.lineSnapshot.modifierTotalMinor;
  int get lineTotalMinor => rebuildResult.lineSnapshot.lineTotalMinor;

  BreakfastCartSelection copyWith({
    BreakfastRequestedState? requestedState,
    BreakfastRebuildResult? rebuildResult,
    List<BreakfastCartModifierDisplayLine>? modifierDisplayLines,
    List<BreakfastCartChoiceDisplayLine>? choiceDisplayLines,
    List<BreakfastCookingInstructionDisplayLine>? cookingDisplayLines,
  }) {
    return BreakfastCartSelection(
      requestedState: requestedState ?? this.requestedState,
      rebuildResult: rebuildResult ?? this.rebuildResult,
      modifierDisplayLines: modifierDisplayLines ?? this.modifierDisplayLines,
      choiceDisplayLines: choiceDisplayLines ?? this.choiceDisplayLines,
      cookingDisplayLines: cookingDisplayLines ?? this.cookingDisplayLines,
    );
  }
}
