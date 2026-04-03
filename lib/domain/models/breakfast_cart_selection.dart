import 'breakfast_rebuild.dart';

class BreakfastCartSelection {
  const BreakfastCartSelection({
    required this.requestedState,
    required this.rebuildResult,
  });

  final BreakfastRequestedState requestedState;
  final BreakfastRebuildResult rebuildResult;

  int get modifierTotalMinor => rebuildResult.lineSnapshot.modifierTotalMinor;
  int get lineTotalMinor => rebuildResult.lineSnapshot.lineTotalMinor;

  BreakfastCartSelection copyWith({
    BreakfastRequestedState? requestedState,
    BreakfastRebuildResult? rebuildResult,
  }) {
    return BreakfastCartSelection(
      requestedState: requestedState ?? this.requestedState,
      rebuildResult: rebuildResult ?? this.rebuildResult,
    );
  }
}
