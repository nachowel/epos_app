import 'shift.dart';
import 'interaction_block_reason.dart';

class ShiftSessionSnapshot {
  const ShiftSessionSnapshot({
    required this.backendOpenShift,
    required this.effectiveShiftStatus,
    required this.cashierPreviewActive,
    required this.salesLocked,
    required this.paymentsLocked,
    required this.lockReason,
  });

  final Shift? backendOpenShift;
  final ShiftStatus effectiveShiftStatus;
  final bool cashierPreviewActive;
  final bool salesLocked;
  final bool paymentsLocked;
  final InteractionBlockReason? lockReason;

  Shift? get visibleShift {
    final Shift? shift = backendOpenShift;
    if (shift == null) {
      return null;
    }
    return shift.copyWith(status: effectiveShiftStatus);
  }
}
