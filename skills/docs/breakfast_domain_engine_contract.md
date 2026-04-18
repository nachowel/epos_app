# Breakfast Domain Engine Contract

## Authority Note

This document is part of the breakfast/menu-engine contract chain defined by `SYSTEM_OF_TRUTH.md`.

Authority order for interpreting this document:

1. `SYSTEM_OF_TRUTH.md`
2. live schema and migrations for physical schema truth
3. earlier breakfast/menu-engine contract docs:
   - `docs/menu_product_role_contract.md`
   - `docs/set_breakfast_configuration_contract.md`
   - `docs/choice_group_mapping_contract.md`
   - `docs/menu_eligibility_enforcement_contract.md`
4. this document
5. later integration/persistence docs that must not contradict this document's domain rules
6. `CLAUDE.md`
7. `schema.md`

If `CLAUDE.md` or `schema.md` conflicts with this document on breakfast rebuild behavior, this document wins.

This document is authoritative for pure breakfast rebuild semantics and classification logic.

Standard products outside breakfast use a separate Phase 1 foundation contract:
`docs/meal_adjustment_engine_contract.md`. That contract must not inherit
breakfast-specific choice/UI semantics from this document.

## Phase Objective

Define a deterministic domain rebuild engine for set breakfast lines.

This phase covers:

- service pseudo-code
- deterministic rebuild algorithm
- modifier classification rules
- validation rules
- edge cases
- domain test matrix

This phase does not cover:

- repository integration
- persistence
- popup / POS flow
- receipt or kitchen formatting
- analytics output

## Domain Input Model

The rebuild engine should work from a pure in-memory snapshot.

### `BreakfastRebuildInput`

```text
transactionLine
  line_uuid
  root_product_id
  root_product_name
  base_unit_price_minor
  line_quantity
  pricing_mode = 'set'

setConfiguration
  set_root_product_id
  set_items[]
  choice_groups[]
  menu_settings

requestedState
  removed_set_items[]
  added_products[]
  chosen_groups[]
```

### `set_items[]`

Each row represents default removable set content.

```text
set_item_id
item_product_id
item_name
default_quantity
is_removable
sort_order
```

### `choice_groups[]`

```text
group_id
group_name
min_select
max_select
included_quantity
sort_order
members[]
```

### `choice_groups[].members[]`

```text
product_modifier_id
item_product_id
display_name
type = 'choice'
```

### `menu_settings`

```text
free_swap_limit
```

Note:

- live schema may also contain `max_swaps`, but it is not part of the active breakfast domain rule set.
- this engine must not use `max_swaps` for pricing or classification.
- current swap rule remains:
  - first `free_swap_limit` matched replacement units -> `free_swap`
  - all subsequent matched replacement units -> `paid_swap`
- introducing a hard swap cap requires a new explicit contract and must not be inferred from schema residue.
- `create_your_own` is out of scope.

### `requestedState.removed_set_items[]`

Each row is unit-aware.

```text
item_product_id
quantity
```

### `requestedState.added_products[]`

Represents products added outside choice-group included allowance.

```text
item_product_id
quantity
```

### `requestedState.chosen_groups[]`

Represents optional included-choice selections.

```text
group_id
selected_item_product_id
requested_quantity
```

Interpretation:

- `selected_item_product_id = null` with `requested_quantity > 0` means explicit none
- `requested_quantity = 0` means no choice made
- optional groups may use explicit none
- required breakfast groups must use one real selected product
- supported breakfast defaults use `min_select = 1`, `max_select = 1`, `included_quantity = 1`
- quantities above `max_select` are invalid

## Domain Output Model

### `BreakfastRebuildResult`

```text
line_snapshot
classified_modifiers[]
pricing_breakdown
validation_errors[]
rebuild_metadata
```

### `line_snapshot`

```text
pricing_mode = 'set'
base_unit_price_minor
removal_discount_total_minor
modifier_total_minor
line_total_minor
```

### `classified_modifiers[]`

Each output row is reportable and deterministic.

```text
kind
action
charge_reason
item_product_id
display_name
quantity
unit_price_minor
price_effect_minor
source
sort_key
```

`kind` is an internal service classification, for example:

- `set_remove`
- `choice_included`
- `extra_add`
- `free_swap`
- `paid_swap`

### `pricing_breakdown`

```text
base_price_minor
extra_add_total_minor
paid_swap_total_minor
free_swap_total_minor = 0
included_choice_total_minor = 0
remove_total_minor = 0
removal_discount_total_minor
final_line_total_minor
```

### `validation_errors[]`

Pure domain errors. No UI strings.

Examples:

- `root_not_set_product`
- `invalid_choice_group`
- `choice_member_not_allowed`
- `mixed_toast_bread_not_supported`
- `remove_quantity_exceeds_default`
- `swap_candidate_not_swap_eligible`
- `negative_quantity`

## Deterministic Rebuild Steps

The engine must always rebuild from scratch from the current requested state. It must never mutate prior classification incrementally.

### Step 1. Validate root assumptions

1. Ensure `pricing_mode = 'set'`.
2. Ensure root product matches `setConfiguration.set_root_product_id`.
3. Ensure every referenced product/group exists in the config snapshot.

### Step 2. Expand set defaults into unit rows

Convert each `set_item` into removable units.

Example:

- `egg x2` becomes two removable units
- each unit carries:
  - `item_product_id`
  - `unit_index`
  - `sort_order`
  - `is_removed = false`

This matters because swap pricing is unit-based:

- first 2 replacement units are `free_swap`
- 3rd and later replacement units are `paid_swap`

### Step 3. Apply requested removals

For each `removed_set_items[]` entry:

1. Find matching removable default units for that `item_product_id`.
2. Mark up to `quantity` units as removed in deterministic order:
   - lowest `sort_order`
   - then lowest `unit_index`
3. Emit a reportable remove modifier for the removed quantity:
   - `action = 'remove'`
   - `charge_reason = null`
   - `price_effect_minor = 0`

If removal quantity exceeds available removable units, return validation error.

### Step 4. Normalize choice selections

For each `chosen_groups[]` row:

1. If group is optional and omitted, emit no choice row
2. If selected product is null:
   - allow it only as explicit none for optional groups
3. If quantity is 0:
   - emit no choice row
4. Validate selected product is a real member of the group via `item_product_id`
5. Validate group-specific quantity rules

Breakfast-specific contract:

- default `Tea or Coffee`: exactly one selected member
- default `Toast or Bread`: exactly one selected member
- required groups do not allow explicit none
- mixed split is invalid because one group can have only one selected product

### Step 5. Classify included choice rows

For each valid group selection:

1. `included_qty = requested_quantity`
2. If `included_qty > 0`, emit:
   - `action = 'choice'`
   - `charge_reason = 'included_choice'`
   - `item_product_id = selected product`
   - `quantity = included_qty`
   - `price_effect_minor = 0`

Important:

- choice rows never enter swap matching
- supported breakfast default choice groups do not produce overflow rows
- choice-capable products must never consume pending replacement units

### Step 6. Build pending replacement pool

Collect all unmatched removed set-item units.

This pool is the only valid source for swap matching.

Pending replacement unit count:

```text
pending_replacement_units = total removed set-item units
```

Choice rows never contribute to this pool.

Critical invariant:

- choice-capable products must never enter or consume the pending replacement pool
- violating this rule breaks swap accounting and pricing determinism

### Step 7. Expand direct additions into unit rows

Convert each `added_products[]` entry into unit rows.

Each unit is classified independently because free/paid swap thresholds are unit-based.

### Step 8. Classify each added unit

Process added units in deterministic order:

1. stable input order
2. then by `item_product_id`
3. then by unit index

For each added unit:

1. If product is choice-capable:
   - it may still be `extra_add`
   - it must never consume pending replacement
2. Else if there is at least one pending replacement unit:
   - consume one pending replacement unit
   - increment replacement counter
   - if replacement counter `<= free_swap_limit`:
     - classify as `free_swap`
     - price effect = `0`
   - else:
     - classify as `paid_swap`
     - price effect = full real product price
3. Else:
   - classify as `extra_add`
   - price effect = full real product price

### Step 9. Re-aggregate classified rows

Group unit rows into reportable output rows only when all of these match:

- `action`
- `charge_reason`
- `item_product_id`
- `unit_price_minor`

Quantity is summed during this fold.

This keeps quantity as an active business field while preserving deterministic totals.

### Step 10. Compute totals

```text
modifier_total_minor =
  extra_add_total_minor +
  paid_swap_total_minor

line_total_minor =
  base_unit_price_minor * line_quantity +
  modifier_total_minor -
  removal_discount_total_minor
```

Current rule in this phase:

- remove-only events remain reportable with zero price effect
- `free_swap` price effect is `0`
- `paid_swap` price effect is full added-product price
- `included_choice` price effect is `0`

### Step 11. Return ordered output

Output order should be stable:

1. removes
2. included choices
3. free swaps
4. paid swaps
5. extra adds

Tie-breakers:

- group sort order where relevant
- set-item sort order where relevant
- product id

## Service Pseudo-Code

```text
BreakfastRebuildResult rebuild(BreakfastRebuildInput input) {
  validateRoot(input);

  final defaultUnits = expandSetItems(input.setConfiguration.set_items);
  final removalResult = applyRemovals(
    defaultUnits: defaultUnits,
    requestedRemovals: input.requestedState.removed_set_items,
  );

  final choiceResult = classifyChoices(
    groups: input.setConfiguration.choice_groups,
    requestedChoices: input.requestedState.chosen_groups,
    catalogPrices: priceMapFromConfig(input),
  );

  final pendingReplacementUnits = removalResult.removedUnits;

  final addUnits = expandAddedProducts(input.requestedState.added_products);
  var replacementCounter = 0;
  final classifiedAddUnits = <ModifierUnitRow>[];

  for (final addUnit in stableSort(addUnits)) {
    if (isChoiceCapable(addUnit.item_product_id, input.setConfiguration)) {
      classifiedAddUnits.add(extraAdd(addUnit));
      continue;
    }

    if (pendingReplacementUnits.isNotEmpty) {
      pendingReplacementUnits.removeFirst();
      replacementCounter += 1;

      if (replacementCounter <= input.setConfiguration.menu_settings.free_swap_limit) {
        classifiedAddUnits.add(freeSwap(addUnit));
      } else {
        classifiedAddUnits.add(paidSwap(addUnit));
      }
      continue;
    }

    classifiedAddUnits.add(extraAdd(addUnit));
  }

  final allRows = [
    ...removalResult.rows,
    ...choiceResult.rows,
    ...classifiedAddUnits,
  ];

  final foldedRows = foldByBusinessIdentity(allRows);
  final totals = computeTotals(
    baseUnitPriceMinor: input.transactionLine.base_unit_price_minor,
    lineQuantity: input.transactionLine.line_quantity,
    modifierRows: foldedRows,
    removalDiscountTotalMinor: 0,
  );

  return BreakfastRebuildResult(
    line_snapshot: totals.lineSnapshot,
    classified_modifiers: stableOutputSort(foldedRows),
    pricing_breakdown: totals.breakdown,
    validation_errors: [
      ...removalResult.errors,
      ...choiceResult.errors,
    ],
    rebuild_metadata: buildMetadata(replacementCounter, pendingReplacementUnits.length),
  );
}
```

## Classification Matrix

| Input condition | action | charge_reason | Swap-eligible | Price effect |
|---|---|---|---:|---:|
| Removed set-item unit | `remove` | `null` | n/a | `0` |
| Choice selection within allowance | `choice` | `included_choice` | No | `0` |
| Choice quantity above allowance | `add` | `extra_add` | No | full product price x excess qty |
| Direct added unit with pending replacement, replacement unit #1 | `add` | `free_swap` | Yes | `0` |
| Direct added unit with pending replacement, replacement unit #2 | `add` | `free_swap` | Yes | `0` |
| Direct added unit with pending replacement, replacement unit #3+ | `add` | `paid_swap` | Yes | full product price x qty |
| Direct added unit without pending replacement | `add` | `extra_add` | n/a | full product price x qty |
| Added choice-capable product, any time | `add` | `extra_add` | No | full product price x qty |

## Validation Rules

1. Root product must be a set-root configuration.
2. Every `set_item` must have `default_quantity > 0`.
3. Removal quantity cannot exceed default removable quantity.
4. Choice selection must reference a real group member product.
5. Choice selection must use at most one selected product per group.
6. Default `Tea or Coffee` selections use quantity `1`.
7. Default `Toast or Bread` selections use quantity `1`.
8. Required groups reject explicit none.
9. Choice-capable products must never consume pending replacement units.
10. Nonexistent product ids or group ids are invalid.
11. Negative quantity is invalid everywhere.
12. Zero-quantity add/remove requests should be ignored, not classified.
13. Remove-only state is valid and must remain reportable.

## Edge-Case Catalog

1. Remove item and add nothing.
   Expected: remove row only, zero price effect.

2. Add extra item without any remove.
   Expected: `extra_add`.

3. Remove one component and add one non-choice product.
   Expected: `free_swap` for first replacement unit.

4. Remove two component units and add two non-choice products.
   Expected: both `free_swap`.

5. Remove three component units and add three non-choice products.
   Expected: first two `free_swap`, third `paid_swap`.

6. Remove one component and add a choice-capable product.
   Expected: choice product is `extra_add`; pending replacement remains unmatched.

7. Choose tea within allowance.
   Expected: one `included_choice` row, quantity `1`.

8. Choose optional none for an optional group.
   Expected: one zero-price `choice / included_choice / item_product_id = null` row.

9. Choose toast quantity `1`.
   Expected: one `included_choice` row, quantity `1`.

10. Choose toast quantity `2`.
    Expected: validation error because the supported max selection is `1`.

11. Attempt `1 toast + 1 bread`.
    Expected: validation error, no mixed split support.

12. Remove more units than the set contains.
    Expected: validation error.

13. Add multiple products after removals with mixed prices.
    Expected: free/paid threshold determined by replacement unit order, not by price.

14. Repeat rebuild with same input.
    Expected: byte-for-byte equivalent output ordering and totals.

15. Legacy line with only remove rows.
    Expected: valid output, zero modifier total, reportable rows preserved.

## Domain Test Matrix

| Test name | Input shape | Expected result |
|---|---|---|
| `remove_only_is_reportable` | one set-item remove, no adds | one `remove`, total unchanged |
| `first_replacement_is_free_swap` | one remove, one non-choice add | one `free_swap` |
| `second_replacement_is_free_swap` | two removes, two non-choice adds | two `free_swap` |
| `third_replacement_is_paid_swap` | three removes, three non-choice adds | third unit `paid_swap` |
| `paid_swap_uses_full_added_product_price` | third replacement product price known | paid amount equals full added product price |
| `choice_within_allowance_creates_included_choice` | tea selected qty `1` | `choice/included_choice` row |
| `optional_none_creates_explicit_none_row` | optional group explicit none | one zero-price `choice` row with `item_product_id = null` |
| `required_choice_rejects_quantity_above_max` | toast selected qty `2` | validation error |
| `choice_never_consumes_swap_pool` | remove component + add tea | tea becomes `extra_add`, replacement pool unchanged |
| `toast_bread_mixed_split_is_invalid` | toast and bread requested together | validation error |
| `remove_quantity_cannot_exceed_default` | remove qty larger than available | validation error |
| `stable_rebuild_same_input_same_output` | same input run twice | identical rows and totals |
| `zero_quantity_requests_are_ignored` | remove/add qty `0` | no classified row |
| `quantity_fold_preserves_business_identity` | repeated same extra adds | one folded row with summed quantity |
| `free_swap_and_paid_swap_do_not_merge` | same product spans free and paid thresholds | separate rows by charge reason |

## Acceptance Criteria

1. Engine is pure and deterministic.
2. Rebuild always derives outputs from current requested state, not incremental mutation history.
3. Swap matching uses only removed set-item units.
4. First two replacement units are always `free_swap`.
5. Third and later replacement units are always `paid_swap`.
6. `paid_swap` price effect uses the full real added-product price.
7. Choice rows are never classified as swap.
8. Quantity affects classification and totals, not just display.
9. Remove-only rows remain reportable with zero price effect.
10. The contract remains valid without repository integration or UI implementation.
