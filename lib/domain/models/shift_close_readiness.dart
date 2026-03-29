enum ShiftCloseBlockReason {
  sentOrdersPending,
  freshDraftsPending,
  staleDraftsPendingCleanup,
}

enum ShiftCloseSuggestedAction {
  completeOrCancelActiveOrders,
  sendOrDiscardFreshDrafts,
  discardStaleDrafts,
}

class ShiftCloseReadiness {
  const ShiftCloseReadiness({
    required this.sentOrderCount,
    required this.freshDraftCount,
    required this.staleDraftCount,
  });

  final int sentOrderCount;
  final int freshDraftCount;
  final int staleDraftCount;

  bool get canFinalClose =>
      sentOrderCount == 0 && freshDraftCount == 0 && staleDraftCount == 0;

  bool get hasStaleDrafts => staleDraftCount > 0;

  ShiftCloseBlockReason? get blockingReason {
    if (sentOrderCount > 0) {
      return ShiftCloseBlockReason.sentOrdersPending;
    }
    if (freshDraftCount > 0) {
      return ShiftCloseBlockReason.freshDraftsPending;
    }
    if (staleDraftCount > 0) {
      return ShiftCloseBlockReason.staleDraftsPendingCleanup;
    }
    return null;
  }

  ShiftCloseSuggestedAction? get suggestedAction {
    switch (blockingReason) {
      case ShiftCloseBlockReason.sentOrdersPending:
        return ShiftCloseSuggestedAction.completeOrCancelActiveOrders;
      case ShiftCloseBlockReason.freshDraftsPending:
        return ShiftCloseSuggestedAction.sendOrDiscardFreshDrafts;
      case ShiftCloseBlockReason.staleDraftsPendingCleanup:
        return ShiftCloseSuggestedAction.discardStaleDrafts;
      case null:
        return null;
    }
  }

  int get blockingCount {
    switch (blockingReason) {
      case ShiftCloseBlockReason.sentOrdersPending:
        return sentOrderCount;
      case ShiftCloseBlockReason.freshDraftsPending:
        return freshDraftCount;
      case ShiftCloseBlockReason.staleDraftsPendingCleanup:
        return staleDraftCount;
      case null:
        return 0;
    }
  }
}
