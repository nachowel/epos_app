# Meal Adjustment Engine Contract

## Authority Note

This document must be interpreted under `SYSTEM_OF_TRUTH.md`.

Authority order for the standard meal-adjustment path:

1. `SYSTEM_OF_TRUTH.md`
2. live schema and migrations for physical schema truth
3. this document
4. later standard-meal integration docs that must not weaken this contract
5. `CLAUDE.md`
6. `schema.md`

Breakfast remains governed by:

- `docs/menu_product_role_contract.md`
- `docs/set_breakfast_configuration_contract.md`
- `docs/choice_group_mapping_contract.md`
- `docs/menu_eligibility_enforcement_contract.md`
- `docs/breakfast_domain_engine_contract.md`
- `docs/breakfast_repository_service_integration_contract.md`

The breakfast engine is separate and must not be collapsed into this contract.

## Goal

Define the authoritative Phase 3 contract for the shared meal customization
engine for standard products outside the breakfast engine.

This phase hardens:

- profile-based admin configuration
- forbidden configuration rules
- deterministic evaluation order
- exact rule matching and tie-break rules
- config health reporting
- runtime lifecycle guardrails
- resolved snapshot to persistence mapping
- standard-product order-service integration
- minimal admin assignment/health/preview UI

Phase 4 extends this contract with:

- identical customization grouping for standard meal lines
- POS dialog integration for standard meal customization
- reporting and revenue hardening for grouped semantic lines
- open-order rehydration groundwork for future edit flows
- minimal admin-side visibility for assigned profile health and preview

Phase 5 extends this contract with:

- grouped open-order edit for standard meal lines
- explicit legacy snapshot fallback behavior
- first-class semantic meal analytics and applied-rule reporting
- post-edit identity recompute and merge correctness

This contract still does not cover:

- breakfast runtime behavior changes
- breakfast refactor
- legacy flat modifier refactor

## Core Decisions

1. The new system applies to breakfast-external standard products.
2. The system is profile-based, not category-based.
3. Product binding to a profile is optional.
4. Breakfast remains a separate system.
5. The standard engine may reuse a semantic core later, but it must not inherit
   breakfast-specific choice or UI semantics.
6. All money fields use INTEGER minor units.
7. Evaluation must remain deterministic.
8. Invalid config must not be saved through the admin/backend service path.

## Profile Model

`meal_adjustment_profiles` is the top-level source of truth.

Each profile owns:

- components
- swap options
- profile-level extras
- pricing rules

Products may bind to a profile through nullable
`products.meal_adjustment_profile_id`.

Interpretation:

- a standard product with no profile binding behaves exactly as it does today
- a standard product with a profile binding opts into the future meal engine
- breakfast products are not forced into this model and must stay on the
  breakfast path

### Component concept

A component is a stable semantic slot inside a profile, for example:

- `main`
- `side`
- `bread`

`component_key` is a stable semantic key, not a display string.

Each component declares:

- default item product
- quantity
- remove eligibility
- sort order

## Semantic Split

The standard engine keeps these concepts separate:

### Remove

- user intent to remove a default component
- component-based, not flat-modifier based

### Swap

- user intent to replace a component with an allowed target
- free vs paid is an engine classification, not a UI label

### Extra

- additive item outside the default component slots
- modeled at profile level

### Pricing rule

- deterministic rule layer mapping resolved semantic state to signed deltas
- distinct from raw request intent

## Extras Modeling Decision

Extras are modeled as `meal_adjustment_profile_extras`, not as component-bound
options.

Reason:

- extras are additive intent, not replacement intent
- forcing extras under a component weakens the semantic split between swap and
  add
- profile-level extras match the future request shape of `item + quantity`
  without artificial ownership

`meal_adjustment_component_options` remains a swap-only table even though the
table name is generic. Repository and domain naming must treat it as swap-only
behavior unless a later migration explicitly expands it.

## Free Swap Limit

`free_swap_limit` belongs to the profile.

Interpretation:

- free swap allowance is defined by profile, not category
- allowance is consumed deterministically in profile component order
- current Phase 2 implementation treats allowance at swap-selection level

## Forbidden Configurations

The following configurations are invalid and must be hard-blocked by validation
or assignment flows:

1. A breakfast semantic product and a meal-adjustment profile cannot both be
   active on the same product.
2. An active profile cannot reference missing products.
3. An active profile cannot reference inactive products.
4. A swap target cannot equal the component default item.
5. Duplicate component keys are invalid.
6. Duplicate swap targets on the same component are invalid.
7. Duplicate profile-level extras are invalid.
8. Duplicate semantic pricing rules are invalid.
9. Same semantic meaning duplicated by different rule rows is invalid even if
   price or priority differs.
10. Broken profile references are admin-visible invalid state. They must not be
    silently ignored.

## Signed `price_delta_minor` Semantics

`price_delta_minor` is signed on pricing rules.

Business validation by rule type:

- `remove_only`
  - usually `0` or negative
  - positive is invalid
- `combo`
  - signed values allowed
- `swap`
  - signed values allowed
- `extra`
  - usually `0` or positive
  - negative is invalid

Profile extra fixed prices and swap-option fixed deltas remain non-negative in
schema.

## Deterministic Evaluation Contract

### Resolution order

The engine resolves in this exact order:

1. request validation
2. swap eligibility classification
3. free swap allowance application
4. exact combo rule evaluation
5. exact swap rule evaluation
6. exact extra rule evaluation
7. additive remove-only rule evaluation, only when exact combo did not match
8. fixed extra price additions and swap fixed-delta fallback
9. deterministic semantic snapshot emission

### Fallback behavior

- swap selections classify to `free_swap` or `paid_swap` first
- exact swap rule overrides default swap pricing
- if no exact swap rule exists, swap falls back to swap-option fixed delta
- if neither exists, swap price delta is `0`
- exact extra rule overrides fixed extra pricing
- if no exact extra rule exists, extra uses fixed extra price delta times
  quantity
- exact combo can coexist with swap and extra pricing, but it suppresses
  additive `remove_only` rules
- `remove_only` rules are additive subset matches on removed components only

### Tie-break contract

When more than one exact rule matches:

1. higher specificity wins
2. then higher priority wins
3. then lower persisted rule id wins
4. if ids are not yet persisted in draft preview, original draft insertion order
   wins

Specificity is computed from rule condition count first, then total condition
quantity.

## Rule Semantics

Current rule types:

- `remove_only`
- `combo`
- `swap`
- `extra`

Current condition types:

- `removed_component`
- `swap_to_item`
- `extra_item`

Interpretation:

- `combo` matches an exact semantic state across removes, swaps, and extras
- `swap` matches an exact swap semantic
- `extra` matches an exact extra semantic
- `remove_only` matches removed-component subsets and stacks additively unless a
  combo rule already matched

## Domain Contract

Phase 2 defines these target concepts:

- `MealCustomizationRequest`
- `MealCustomizationResolvedSnapshot`
- `MealCustomizationPersistencePreview`
- `MealCustomizationReportingSummary`

Request carries user intent only:

- removed component keys
- swap selections (`component_key -> target_item_product_id`)
- extra selections (`item_product_id + quantity`)

Resolved snapshot is deterministic engine output and includes:

- resolved component actions
- resolved extra actions
- triggered discounts
- applied rules
- total adjustment minor
- free swap count used
- paid swap count used

Semantic actions:

- `remove`
- `swap`
- `extra`
- `discount`

Charge reasons:

- `free_swap`
- `paid_swap`
- `extra_add`
- `removal_discount`
- `combo_discount`

## Config Health / Admin Contract

Admin/backend flows must expose health, not just raw rows.

Required health outputs:

- `health_status`
- `broken_references`
- `conflicting_rules`
- `inactive_items`
- `affected_products`
- presentation-ready headline/body text

Expected admin/backend flow:

1. load profile draft
2. validate profile draft
3. compute health summary
4. preview evaluation for a sample request
5. save profile draft
6. assign or unassign profile to product
7. list products using a profile

Repository responsibilities stay read/write only. Validation, health, and
engine logic belong above the repository layer.

## Product Lifecycle Expectations

If a referenced product is archived or deleted:

- the profile becomes invalid
- config health must surface the broken reference
- affected products must be discoverable in admin/backend flows

Phase 2 uses service-level health computation. No stored health column is
required yet.

Future phases should add stronger lifecycle guardrails around product archive
and delete flows so references fail fast before damage spreads.

Phase 3 now enforces:

- active meal-adjustment references block product archive
- meal-adjustment references block hard delete
- runtime order creation fails fast when assigned profile is missing, inactive,
  structurally invalid, or references inactive/missing products
- breakfast semantic products with a meal-adjustment profile are runtime-invalid
  and must throw instead of falling back

## Persistence / Reporting Contract

Phase 3 and Phase 4 persist the resolved semantic snapshot, not the raw
request.

### Persistence shape

`MealCustomizationResolvedSnapshot` maps to `order_modifiers` semantic rows.

Phase 4 grouping adds a line-level semantic snapshot record in
`meal_customization_line_snapshots`.

Authoritative grouping identity is the deterministic hash of the resolved
semantic snapshot:

- `product_id`
- normalized resolved component actions
- normalized resolved extra actions
- normalized triggered discounts
- applied rule ids
- net total adjustment minor

Raw request hashes are forbidden for grouping.

Swap persistence uses Option A:

- one `remove` row for the default item being replaced
- one `add` row for the swap target
- swap charge reason lives on the add row as `free_swap` or `paid_swap`

Resolved semantic mapping:

- `remove`
  - `action = 'remove'`
  - `item_product_id = removed default item`
  - no charge reason
- `swap`
  - remove row for source default item
  - add row for target item
  - add row carries `free_swap` or `paid_swap`
- `extra`
  - `action = 'add'`
  - `item_product_id = extra item`
  - `charge_reason = 'extra_add'`
- `discount`
  - separate row
  - `action = 'add'`
  - `item_product_id = NULL`
  - `charge_reason = 'removal_discount'` or `combo_discount`
  - `price_effect_minor` is signed and may be negative

### Financial contract

For standard meal-adjustment lines:

- base product price comes from `transaction_lines.unit_price_minor`
- semantic modifier rows contribute via signed `order_modifiers.price_effect_minor`
- standard meal semantic modifier rows are persisted once per grouped line, not
  duplicated per unit
- grouped quantity lives on `transaction_lines.quantity`
- grouped line totals and transaction modifier totals must multiply semantic
  snapshot adjustments by line quantity
- `transaction_lines.line_total_minor` is recomputed in persistence
- `transactions.total_amount_minor` is recomputed from persisted rows, not UI

Expected line formula:

- base product price
- plus extras
- plus paid or explicit swap charges
- minus triggered discounts

### Reporting contract

Reporting-facing outputs must preserve:

- removed component keys
- swapped item product ids
- extra item product ids
- applied rule ids
- total adjustment minor
- total discount minor
- free swap count used
- paid swap count used

Applied rule ids must travel with the resolved snapshot even when current Phase
3 persistence stores only semantic rows, so future analytics can join back to
rule authorship without re-evaluating the request.

Phase 4 revenue semantics are:

- base product revenue = root line base price times quantity
- extra revenue = positive `extra_add` contribution
- paid swap revenue = positive `paid_swap` contribution
- free swap revenue = `0`
- removal and combo discounts = negative contribution
- remove rows alone do not carry revenue
- net line total = base plus positive adjustments minus discounts
- net transaction total = sum of persisted line totals

## Order Flow Contract

Standard product add-to-order flow is now:

1. if breakfast semantic product: use existing breakfast flow only
2. else if `products.meal_adjustment_profile_id IS NOT NULL`: use meal
   customization runtime validation, deterministic evaluation, and semantic
   snapshot persistence
3. else: use existing standard product flow

Flat modifiers must not be combined with meal customization on the same line.

For profile-bound standard products:

- the engine may run on an explicit request or an empty request
- runtime must validate the persisted profile before line creation
- invalid runtime config must throw and abort the order mutation
- no fallback to flat modifiers or silent ignore is allowed
- identical resolved semantic snapshots must merge into one line and increment
  quantity
- different resolved semantic snapshots must stay on separate lines

### Open-order groundwork

Phase 4 groundwork and Phase 5 edit flow require:

- persisted snapshot -> editor-state rehydration without re-evaluating raw
  request text
- grouped quantity to remain separate from editor semantic state
- grouped meal edit operates on the full line quantity, not a single split unit
- edit save flow must:
  - rebuild a new request from editor state
  - re-evaluate through the deterministic engine
  - persist a new resolved snapshot
  - recompute semantic identity from the new snapshot
  - merge into an existing grouped line when the new identity already exists
- decrement contract for grouped lines:
  - remove once from a grouped line -> decrement quantity
  - remove the final unit -> delete the line and its snapshot

### Legacy fallback

Legacy standard meal line means:

- `transaction_lines.pricing_mode = 'standard'`
- semantic standard-meal modifier rows exist
- no `meal_customization_line_snapshots` row exists

Legacy behavior is explicit:

- legacy standard meal lines remain sale and reporting data
- legacy standard meal lines are not editable
- UI must say the line was created before snapshot persistence and cannot be
  edited
- silent best-effort reconstruction is forbidden

### First-class semantic analytics

Phase 5 reporting must expose, for grouped standard meal lines:

- base revenue
- extra revenue
- paid swap revenue
- free swap count
- discount total
- net revenue
- applied rule analytics by `rule_id`

Grouped quantity must multiply all semantic contributions.

Legacy standard meal lines still contribute to root product revenue totals, but
Phase 5 may emit explicit data-quality notes when meal semantic breakdown and
applied-rule analytics cannot be reconstructed because the persisted snapshot is
missing.

## Minimal Admin UI Contract

Phase 3 exposes a minimal admin surface on product management:

- assign or unassign a meal-adjustment profile to a standard product
- show profile health summary for the selected profile
- preview deterministic evaluation for a sample request

This UI is intentionally narrow:

- no POS editor
- no full meal-profile CRUD screen in this phase
- no breakfast UI convergence

## Boundary Summary

- breakfast stays separate
- standard products use profile-based meal adjustment
- deterministic evaluation is required
- invalid config must be blocked before save or assignment
- broken references must surface in admin health
- runtime invalid config must fail fast during order creation
- resolved semantic snapshot is the persistence source of truth
- no breakfast flow changes are allowed in this phase

## Cross-Links

- Breakfast product-role constraints:
  `docs/menu_product_role_contract.md`
- Breakfast eligibility and enforcement:
  `docs/menu_eligibility_enforcement_contract.md`
- Breakfast rebuild semantics:
  `docs/breakfast_domain_engine_contract.md`
- Project authority chain:
  `SYSTEM_OF_TRUTH.md`
