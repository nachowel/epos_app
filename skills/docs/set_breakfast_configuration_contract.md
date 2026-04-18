# Set Breakfast Configuration Contract

Phase 2B defines how any `Set Breakfast` product should be configured in local Drift. This is a configuration contract for admin flows, repositories, validation, and future pricing work. It does not implement pricing logic or POS UI.

`Set 4` and `Set 9` in this document are representative example products only. They validate the model shape. They are not locked-in production menu entries.

## Scope

This contract defines three separate layers:

1. Reusable configuration structure
2. Temporary example data used to validate the structure
3. Future real menu entries that will be created later by the user

These layers must not be merged conceptually.

## Reusable Configuration Structure

Any product treated as a set breakfast root must follow this structure.

### Set root requirements

- The product is a normal `products` row.
- The product belongs to the `Set Breakfast` category.
- The product may own `set_items`.
- The product may own `modifier_groups`.
- The product must not itself appear as a `set_item`.
- The product must not be used as an included choice member.
- The product must not be used as an extra-add or swap-replacement target.

### Set component requirements

Set components are configured through `set_items`.

Contract per `set_items` row:

- `product_id` = set breakfast root product
- `item_product_id` = real component product
- `is_removable = true`
- `default_quantity >= 1`
- `sort_order` follows the configured serving/display order

Rules:

- Only real component products belong in `set_items`.
- `set_items` represent removable set contents.
- Choice-capable products must not be modeled through `set_items`.

### Included choice requirements

Included choices are configured through:

- `modifier_groups`
- `product_modifiers` with `type = 'choice'`

Choice rules:

- Choice can become `extra_add`.
- Choice can never participate in swap replacement logic.
- Choice products must never be used to satisfy pending replacement from removed `set_items`.

### Mandatory modifier group pattern for all Set Breakfast products

Every product under the `Set Breakfast` category must expose these two groups.

#### Group 1: Tea or Coffee

- `name = 'Tea or Coffee'`
- `min_select = 1`
- `max_select = 1`
- `included_quantity = 1`
- `sort_order = 1`

Allowed members:

- `tea`
- `coffee`

#### Group 2: Toast or Bread

- `name = 'Toast or Bread'`
- `min_select = 1`
- `max_select = 1`
- `included_quantity = 1`
- `sort_order = 2`

Allowed members:

- `toast`
- `bread`

Interpretation:

- Customer must choose exactly one member from each required group.
- `Toast or Bread` means one included bread-path selection, not a two-unit allowance.
- Required groups do not support `None`.
- Mixed split such as `1 toast + 1 bread` is not supported by this contract.

## Generic Structure Template

For any future set breakfast root:

```text
products
  - root set product in category "Set Breakfast"

set_items
  - one row per removable component product
  - quantity captured in default_quantity
  - serving order captured in sort_order

modifier_groups
  - Tea or Coffee
  - Toast or Bread

product_modifiers
  - choice members linked to Tea or Coffee group
  - choice members linked to Toast or Bread group
```

Admin/repository interpretation:

- `set_items` define removable components.
- `modifier_groups` define included choices.
- `product_modifiers(type = 'choice')` define the allowed members of each choice group.
- Extras are configured separately through `product_modifiers(type = 'extra')`.
- Swap behavior remains a runtime pricing/classification concern, not a separate menu structure.

## Temporary Example Data

These are example mappings only. They exist to validate the structure and must not be treated as permanent production menu.

### Example set root: `Set 4`

Representative `set_items`:

| sort_order | item_product_id | default_quantity | is_removable |
|---|---|---:|---:|
| 1 | `egg` | 1 | true |
| 2 | `bacon` | 1 | true |
| 3 | `sausage` | 1 | true |
| 4 | `chips` | 1 | true |
| 5 | `beans` | 1 | true |

Required choice groups:

- `Tea or Coffee`
- `Toast or Bread`

Choice members:

- `Tea or Coffee` -> `tea`, `coffee`
- `Toast or Bread` -> `toast`, `bread`

### Example set root: `Set 9`

Representative `set_items`:

| sort_order | item_product_id | default_quantity | is_removable |
|---|---|---:|---:|
| 1 | `egg` | 2 | true |
| 2 | `bacon` | 1 | true |
| 3 | `sausage` | 2 | true |
| 4 | `chips` | 1 | true |
| 5 | `beans` | 1 | true |
| 6 | `tomato` | 1 | true |
| 7 | `black pudding` | 1 | true |

Required choice groups:

- `Tea or Coffee`
- `Toast or Bread`

Choice members:

- `Tea or Coffee` -> `tea`, `coffee`
- `Toast or Bread` -> `toast`, `bread`

## Future Real Menu Entries

Future production menu entries will be created later by the user through dashboard/admin flows.

This contract therefore requires:

- no permanent hardcoding around `Set 4` or `Set 9`
- no assumption that only two breakfast sets will exist
- no assumption that current example component counts are final
- no assumption that example names are stable production names

What must remain stable is the structure:

- set-root product in `Set Breakfast`
- removable components in `set_items`
- mandatory drink choice group
- mandatory toast/bread choice group
- choice members modeled through `modifier_groups` + `product_modifiers(type = 'choice')`

## Admin Guardrails

Future admin/dashboard configuration must reject or warn on these invalid setups.

1. A `Set Breakfast` root without both required modifier groups is invalid.
2. A non-`Set Breakfast` product must not be configured with the breakfast mandatory groups unless the contract is explicitly expanded.
3. A choice-capable product (`tea`, `coffee`, `toast`, `bread`) must not be inserted into `set_items`.
4. A choice group member must map only through `product_modifiers(type = 'choice')`.
5. A `product_modifiers` row with `group_id` set must always use `type = 'choice'`.
6. The `Tea or Coffee` group must contain exactly `tea` and `coffee`, with no component products mixed in.
7. The `Toast or Bread` group must contain exactly `toast` and `bread`, with no component products mixed in.
8. Mixed split configuration for the bread group must be blocked in future admin UX and validation.
9. Duplicate component rows for the same `(product_id, item_product_id)` must remain invalid.
10. A set root must not reference itself as a component.
11. A set root must not be configured as a member of another set root's choice group.
12. Dashboard editing must clearly separate:
    - removable set components
    - included choice groups
    - choice group members
13. Dashboard editing must label example data as temporary or placeholder when seeded for demo/testing.
14. Future validation must preserve the core invariant:
    - required breakfast choice groups remain one-of-one selections
    - choice may never become swap replacement

## Non-Goals

This phase does not define:

- price calculation
- free vs paid swap counting
- extra pricing
- POS interaction flow
- receipt or reporting behavior
- permanent seeded breakfast products

Phase 2C choice-member data mapping is documented in
`docs/choice_group_mapping_contract.md`.

Phase 2D eligibility and enforcement boundaries are documented in
`docs/menu_eligibility_enforcement_contract.md`.
