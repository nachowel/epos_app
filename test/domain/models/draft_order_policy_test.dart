import 'package:epos_app/domain/models/draft_order_policy.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DraftOrderPolicy', () {
    test('stale threshold is deterministic at 45 minutes', () {
      final DateTime now = DateTime(2026, 1, 1, 12, 0, 0);
      final Transaction freshDraft = _draft(
        updatedAt: now.subtract(const Duration(minutes: 44, seconds: 59)),
      );
      final Transaction staleDraft = _draft(
        updatedAt: now.subtract(DraftOrderPolicy.staleThreshold),
      );

      expect(DraftOrderPolicy.isStale(freshDraft, now: now), isFalse);
      expect(DraftOrderPolicy.isStale(staleDraft, now: now), isTrue);
    });
  });
}

Transaction _draft({required DateTime updatedAt}) {
  return Transaction(
    id: 1,
    uuid: 'draft',
    shiftId: 1,
    userId: 1,
    tableNumber: null,
    status: TransactionStatus.draft,
    subtotalMinor: 0,
    modifierTotalMinor: 0,
    totalAmountMinor: 0,
    createdAt: updatedAt,
    paidAt: null,
    updatedAt: updatedAt,
    cancelledAt: null,
    cancelledBy: null,
    idempotencyKey: 'idem-draft',
    kitchenPrinted: false,
    receiptPrinted: false,
  );
}
