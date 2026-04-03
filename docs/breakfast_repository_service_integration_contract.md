# Breakfast Repository And Service Integration Contract

## Authority Note

This document must be interpreted under `SYSTEM_OF_TRUTH.md`.

Authority order for this phase:

1. `SYSTEM_OF_TRUTH.md`
2. live schema and migrations for physical schema truth
3. earlier breakfast/menu-engine contract docs, especially:
   - `docs/menu_product_role_contract.md`
   - `docs/set_breakfast_configuration_contract.md`
   - `docs/choice_group_mapping_contract.md`
   - `docs/menu_eligibility_enforcement_contract.md`
   - `docs/breakfast_domain_engine_contract.md`
4. `docs/breakfast_persistence_schema_hardening_contract.md`
5. this document
6. `CLAUDE.md`
7. `schema.md`

This document is authoritative for:

- breakfast edit orchestration
- rebuild-from-scratch persistence flow
- service/repository responsibility boundary

This document must not override the pure rebuild semantics owned by
`docs/breakfast_domain_engine_contract.md`.

Later docs, implementation notes, or integration details must not weaken or override the orchestration boundary defined here.

## Goal

Integrate the Phase 3 breakfast rebuild engine into editable draft order flows without breaking deterministic rebuild behavior.

This phase defines orchestration, persistence boundaries, line split rules, and the integration test surface.

This phase does not define:

- popup UI
- POS interaction design
- receipt or kitchen formatting
- analytics output

## Integration Plan

### Service boundary

`OrderService` is the orchestration entry point.

Responsibility:

1. validate edit eligibility
2. load current draft snapshot
3. load breakfast configuration snapshot
4. build the requested edit state
5. call the pure breakfast rebuild engine
6. reject invalid edits with structured domain errors
7. persist the rebuilt snapshot atomically
8. recompute transaction totals after successful persistence

The breakfast rebuild engine remains pure and stateless.

It must:

- accept only in-memory input
- return only in-memory classified output
- never read Drift
- never write Drift

### Repository boundary

Repositories must only:

- read current order snapshot
- delete/rewrite persisted breakfast snapshot rows
- write transaction line snapshot fields
- write order modifier snapshot fields
- recompute transaction totals from persisted rows

Repositories must not:

- decide `free_swap` vs `paid_swap`
- infer `included_choice`
- infer `extra_add`
- infer swap eligibility
- consume replacement pools
- weaken or reinterpret rebuild-engine classification semantics during persistence

Classification logic belongs only to the rebuild engine.

Repositories must treat classification fields as immutable output from the rebuild engine.

Any attempt to derive, adjust, or reinterpret:

- `charge_reason`
- swap classification
- choice classification

is a violation of this contract.

### Transaction boundary

Every successful breakfast edit must run inside one DB transaction.

Atomic unit:

1. verify line is editable
2. read current line + modifiers
3. rebuild from current requested state
4. replace persisted snapshot rows for the affected line or split lines
5. recalculate order totals
6. update transaction timestamp

If any step fails:

- no partial rows remain persisted
- no partially updated totals remain

### Total recomputation rule

- totals must be recomputed from persisted snapshot rows, not from incremental deltas
- repository must not reuse stale `modifier_total` values
- transaction total must reflect the exact rebuilt snapshot state

## Draft Edit Behavior Contract

### Editable states

Breakfast line edits are allowed only when the owning transaction is editable under the current live transaction status model.

Current contract:

- `draft` lines are editable
- `sent`, `paid`, and `cancelled` lines are not editable

Service must reject non-editable line mutations with structured error types, for example:

- `breakfast_line_not_editable`
- `breakfast_line_already_paid`
- `breakfast_line_cancelled`

### Rebuild rule

No incremental patching of previously classified modifier rows is allowed.

For every edit:

1. read current requested state
2. apply the new requested change in memory
3. rebuild the entire affected breakfast line from scratch
4. replace persisted snapshot rows with the rebuild result

If requested state is not explicitly persisted:

- it must be reconstructed using a deterministic reverse-mapping defined by a separate contract
- direct inference from classified modifier rows is not allowed unless explicitly defined

The rebuild engine must always operate on a valid requested state model, not raw persisted snapshot rows.

### Requested state transformation rule

- `currentRequestedState.apply(request)` must be deterministic
- it must not depend on previously classified modifier rows
- it must not infer swap, extra, or choice classification
- it must only represent user intent (`remove` / `add` / `choose`)

Any classification leakage into requested state is a violation of this contract.

Allowed service operations later may include:

- remove set component units
- restore removed set component units
- choose hot drink
- choose toast or bread
- add extra breakfast product
- change extra quantity
- clear choice

Each of these must still follow full rebuild semantics.

### Invalid edit handling

Invalid edits must fail before persistence commit.

Examples:

- remove quantity exceeds default set quantity
- mixed toast/bread request
- choice member not in group
- attempt to classify a choice product as swap
- edit against non-draft line

Service output should use structured errors, not UI strings.

## Persistence Snapshot Contract

Persistence stores the rebuild result, not the user intent delta.

### Persisted transaction line snapshot

For each persisted breakfast transaction line:

- `pricing_mode`
- `product_id`
- `product_name`
- `unit_price_minor`
- `quantity`
- `removal_discount_total_minor`
- `line_total_minor`

The line row must represent the rebuilt state after the edit.

### Persisted modifier snapshot

Every persisted `order_modifiers` row for a breakfast line must preserve:

- `action`
- `charge_reason`
- `item_product_id`
- `quantity`
- `unit_price_minor`
- `price_effect_minor`
- display label / name

Current repo note:

- existing tables already preserve `action`, `charge_reason`, `item_product_id`, and `quantity`
- the old model still uses `extra_price_minor`
- future implementation must map snapshot price semantics cleanly so repository math does not invent business classification
- breakfast persistence must continue to follow the active rebuild-engine classification subset rather than infer new meanings from broader schema compatibility

### Persistence rule

Persisted modifier rows are a full snapshot of classified output for that line.

That means:

- delete obsolete rows for the affected breakfast line
- insert the rebuilt rows
- do not patch prior rows in place based on inferred diff logic

### Persistence scope rule

- snapshot replacement must be scoped strictly to the affected transaction line
- repositories must not delete or rewrite modifier rows belonging to other lines
- line identity must be preserved during replace operations

### Snapshot replacement execution rule

- replacement must be performed as:
  1. delete existing rows for the target line
  2. insert rebuilt rows
- both operations must occur inside the same transaction
- no intermediate visible state is allowed
- ordering (`sort_key`) must be preserved exactly as produced by the rebuild engine

## Line Split Rules

Different breakfast configurations must split into separate transaction lines.

### Core rule

Two breakfast items may share one transaction line only if their rebuilt breakfast snapshot is identical in business terms.

If configuration diverges, they must split.

### Split-triggering differences

Any of the following differences require separate transaction lines:

1. different set-root product
2. different removed set-item state
3. different included-choice selection
4. different choice overflow quantity
5. different direct extras
6. different swap classification outcome
7. different `charge_reason` composition
8. different price effect totals

Example:

- one `Set 4` with tea and no extras
- one `Set 4` with coffee and paid swap bacon->black pudding

These must persist as two separate transaction lines.

### Merge rule

Future implementation may merge only when the full rebuilt line identity matches:

- root product
- rebuilt modifier snapshot
- unit price semantics
- line total semantics

Until that equality check exists, safest behavior is:

- split on any breakfast customization

### Line identity invariant

Two lines are identical ONLY if all of the following match:

- root product id
- `pricing_mode`
- full classified modifier snapshot:
  - `action`
  - `charge_reason`
  - `item_product_id`
  - `quantity`
  - `unit_price_minor`
  - `price_effect_minor`
- `final line_total_minor`

Any difference requires line separation.

## Suggested Orchestration Shape

Note: pseudo-code uses illustrative syntax and does not enforce language-level immutability rules.

```text
OrderService.editBreakfastLine(request) {
  return transactionRepository.runInTransaction(() async {
    final editableLine = await breakfastSnapshotRepository.requireEditableDraftLine(
      request.transactionLineId,
    );

    final config = await breakfastConfigRepository.loadConfigForRoot(
      editableLine.productId,
    );

    final currentRequestedState =
        await breakfastSnapshotRepository.loadRequestedStateForLine(
          editableLine.id,
        );

    final nextRequestedState = currentRequestedState.apply(request);

    final rebuildResult = breakfastRebuildEngine.rebuild(
      BreakfastRebuildInput(
        transactionLine: editableLine.asBreakfastInput(),
        setConfiguration: config,
        requestedState: nextRequestedState,
      ),
    );

    if (rebuildResult.validationErrors.isNotEmpty) {
      throw BreakfastEditRejected(rebuildResult.validationErrors);
    }

    await breakfastSnapshotRepository.replaceBreakfastLineSnapshot(
      lineId: editableLine.id,
      rebuildResult: rebuildResult,
      requestedState: nextRequestedState,
    );

    await transactionRepository.recalculateTotals(editableLine.transactionId);
  });
}
```

## Integration Test Matrix

| Test name | Scenario | Expected result |
|---|---|---|
| `draft_breakfast_edit_rebuilds_from_scratch` | edit existing breakfast draft twice | second result depends only on current requested state |
| `repository_does_not_classify_modifiers` | repository write path invoked with classified output | persisted rows match input snapshot exactly |
| `invalid_breakfast_edit_is_atomic` | invalid edit during rebuild | no partial row changes, no total changes |
| `paid_line_is_not_editable` | edit on paid breakfast line | structured rejection |
| `cancelled_line_is_not_editable` | edit on cancelled breakfast line | structured rejection |
| `successful_edit_recalculates_transaction_totals` | valid breakfast edit | transaction totals updated after persistence |
| `remove_only_snapshot_persists_zero_price_effect_rows` | remove item with no replacement | `remove` rows preserved and totals unchanged except configured discounts |
| `choice_overflow_persists_as_two_rows` | toast qty `4` | one `included_choice` row and one `extra_add` row |
| `choice_product_never_persists_as_swap` | remove component then add tea | tea persisted as `extra_add`, not `free_swap` or `paid_swap` |
| `third_replacement_persists_as_paid_swap` | three replacement units | third unit persisted with `paid_swap` semantics |
| `different_breakfast_configs_split_lines` | two same root products with different choices/modifiers | separate transaction lines |
| `identical_breakfast_snapshots_may_share_line_only_if_full_identity_matches` | two equal rebuilt snapshots | merge allowed only if full identity comparator passes |
| `failed_persistence_rolls_back_totals_and_rows` | write failure after delete-before-insert | original rows and totals remain |
| `structured_error_surface_is_stable` | known invalid edit shapes | service returns typed errors, not plain text |

## Acceptance Criteria

1. `OrderService` orchestrates breakfast edit + rebuild + persistence.
2. The rebuild engine remains pure and owns classification logic.
3. Repositories only read/write snapshot state and totals.
4. No incremental patching of previously classified modifier rows occurs.
5. Every successful edit rebuilds from the current requested state from scratch.
6. Invalid edits never leave partial persisted state.
7. Non-editable lines (`paid`, `cancelled`, and any other non-draft state) are rejected.
8. Transaction totals are recomputed after each successful breakfast line edit.
9. Persistence preserves `charge_reason`, `item_product_id`, `quantity`, and price semantics from the rebuild result.
10. Different breakfast configurations persist as separate transaction lines.
11. Requested state transformation must remain pure and classification-free.
12. Snapshot replacement must not expose partial intermediate states.
13. Line identity must be strictly enforced before any merge operation.

## Implementation Notes

Current repo reality that later implementation must account for:

1. `OrderService` already orchestrates order mutations and total recalculation.
2. `TransactionRepository` still owns legacy add-line/add-modifier writes and legacy modifier-total math.
3. Existing domain models for `OrderModifier` and `TransactionLine` do not yet expose the full breakfast snapshot fields needed by this contract.

This phase intentionally documents the target integration boundary before changing those runtime models.
