# Menu Eligibility And Enforcement Contract

Phase 2D defines product eligibility classes and the enforcement boundary for menu configuration. This is a contract doc only. It does not implement pricing, POS UI, or admin UI.

Scope note:

- this document covers breakfast/menu-engine eligibility only
- the standard non-breakfast foundation is documented in
  `docs/meal_adjustment_engine_contract.md`

## Purpose

This document answers four questions:

1. Which product classes exist in the menu model
2. What each class is eligible to do
3. What is already enforced by schema
4. What must still be enforced later by admin validation and domain runtime validation

## Product Eligibility Classes

### 1. Set-root products

Definition:

- Normal sellable products under `Set Breakfast`
- Own `set_items`
- Own `modifier_groups`

Representative examples only:

- `Set 4`
- `Set 9`

### 2. Set component products

Definition:

- Real catalog products referenced by `set_items`
- Represent removable set contents

Current confirmed examples:

- `egg`
- `bacon`
- `sausage`
- `chips`
- `beans`
- `tomato`
- `black pudding`

### 3. Choice-capable products

Definition:

- Real catalog products referenced by breakfast `modifier_groups` through `product_modifiers(type = 'choice')`

Current confirmed examples:

- `tea`
- `coffee`
- `toast`
- `bread`

### 4. Future extra-only products

Definition:

- Products that may later be allowed only as `extra_add`
- Not currently required by the confirmed breakfast contract

Status:

- This class is reserved for future menu expansion
- No current breakfast-specific example is finalized in this phase

## Eligibility Matrix

| Eligibility class | Sold directly | Used as `set_item` | Used as `included_choice` | Used as `extra_add` | Used as swap replacement |
|---|---:|---:|---:|---:|---:|
| Set-root products | Yes | No | No | No | No |
| Set component products | Allowed but not required by current contract | Yes | No | Yes | Yes |
| Choice-capable products | Yes | No | Yes | Yes | No |
| Future extra-only products | TBD by future contract | No by default | No by default | Yes if later enabled | No by default |

## Confirmed Business Invariants

These are business truths already agreed for breakfast configuration:

1. Set component products are removable.
2. Set component products are swap-eligible.
3. Set component products are `extra_add` eligible.
4. Choice-capable products are `included_choice` eligible.
5. Choice-capable products are `extra_add` eligible.
6. Choice-capable products are never swap replacements.
7. Choice groups are optional and may be left unanswered.
8. All breakfast-set roots must carry the required breakfast choice pattern:
   - `Tea or Coffee`
   - `Toast or Bread`
9. The `Toast or Bread` pattern supports only `2 toast` or `2 bread`.
10. Mixed split is not supported.

## Already Enforced By Schema

The following points are already enforced by the current Drift/SQLite schema:

1. `set_items` require `default_quantity > 0`.
2. `set_items` reject duplicate `(product_id, item_product_id)` pairs.
3. `modifier_groups` belong to a real `product_id`.
4. `product_modifiers.type` is limited to `included`, `extra`, or `choice`.
5. `product_modifiers.type = 'choice'` requires:
   - `group_id IS NOT NULL`
   - `item_product_id IS NOT NULL`
6. `product_modifiers.type IN ('included','extra')` requires `group_id IS NULL`.
7. `product_modifiers.item_product_id`, when set, references a real product.
8. `order_modifiers.action` is limited to `remove`, `add`, or `choice`.
9. `order_modifiers.charge_reason` is limited to the allowed menu-engine reasons.
10. `order_modifiers.action = 'choice'` requires `charge_reason = 'included_choice'`.

Important limitation:

- The schema can prove structural correctness.
- The schema does not fully prove semantic eligibility such as "tea cannot be a swap replacement".

## Admin Validation Requirements

These rules are only documented now and must later be enforced by admin/dashboard validation:

1. A set-root product cannot be added as its own `set_item`.
2. A set-root product cannot be added as another set root's removable component unless a later contract explicitly allows it.
3. Choice-capable products cannot be configured into swap replacement paths.
4. Invalid products cannot be attached to the `Tea or Coffee` group.
5. Invalid products cannot be attached to the `Toast or Bread` group.
6. Every breakfast set root must carry both required breakfast groups.
7. `Tea or Coffee` must contain only `tea` and `coffee`.
8. `Toast or Bread` must contain only `toast` and `bread`.
9. Choice-capable products must not be inserted into `set_items`.
10. Future extra-only products must not appear in breakfast choice groups unless a later contract explicitly expands eligibility.
11. Example products such as `Set 4` and `Set 9` must be clearly treated as placeholder/demo configuration, not production truth.

## Future Domain Runtime Enforcement Requirements

These rules are only documented now and must later be enforced by domain runtime validation:

1. Pending replacement matching must only consider removable `set_items`.
2. Choice-capable products must never satisfy pending swap/replacement matching.
3. A choice overflow path may become `extra_add`.
4. A choice selection with no customer input must produce no `order_modifiers` choice row.
5. `Toast or Bread` must remain a single-path selection with quantity allowance, not a mixed split.
6. Runtime selection logic must reject impossible states even if malformed data slips past admin setup.

## Enforcement Boundary Summary

Use this split when implementing later phases:

- Schema enforcement:
  structure, nullability, allowed enums, basic FK-like references, and some table-level invariants
- Admin validation:
  whether a product is allowed to be configured into a given breakfast role
- Domain runtime validation:
  whether a live order action is semantically valid at selection time

## Phase Chain

- Phase 2A product role: `docs/menu_product_role_contract.md`
- Phase 2B set structure: `docs/set_breakfast_configuration_contract.md`
- Phase 2C choice mapping: `docs/choice_group_mapping_contract.md`
- Phase 2D eligibility/enforcement: `docs/menu_eligibility_enforcement_contract.md`

## Non-Goals

This phase does not define:

- pricing formulas
- swap charges
- POS interaction flow
- admin screens
- final production menu entries
