# Breakfast Implementation Debt

Follow `SYSTEM_OF_TRUTH.md` first.

This note records intentional, contract-aligned debt that is being left in
place during stabilization. It is not a backlog for new business rules.

## Current Debt

1. `OrderService.editBreakfastLine` still accepts a nullable
   `expectedTransactionUpdatedAt` for non-UI callers.
   Runtime UI paths now pass the token, but tightening the service contract
   for every caller would be a breaking change and is deferred.

2. There is no active breakfast line merge comparator yet.
   Current runtime behavior stays on the safe side by splitting customized
   breakfast lines instead of attempting semantic merges.

3. `extra_price_minor` remains compatibility residue in persisted rows.
   Active breakfast semantics use `price_effect_minor`; compatibility residue is
   kept only for legacy row readability, sync payload continuity, and migration
   safety.

4. Compatibility fallback request-state reconstruction remains limited to
   explicitly allowed non-runtime paths such as reporting/analytics.
   Runtime breakfast edits continue to fail fast instead of using that
   fallback.

5. Legacy row backfill is intentionally deferred.
   The runtime stack is hardened for new strict breakfast snapshots, but it
   does not rewrite or normalize pre-existing legacy rows unless a dedicated
   migration/backfill phase is approved.
