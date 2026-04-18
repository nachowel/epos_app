# Choice Group Mapping Contract

## Authority Note

This document must be interpreted under `SYSTEM_OF_TRUTH.md`.

Authority order for this phase:

1. `SYSTEM_OF_TRUTH.md`
2. live schema and migrations for physical schema truth
3. earlier breakfast/menu-engine contract docs, especially:
   - `docs/menu_product_role_contract.md`
   - `docs/set_breakfast_configuration_contract.md`
4. this document
5. `docs/menu_eligibility_enforcement_contract.md`
6. `docs/breakfast_domain_engine_contract.md`
7. `docs/breakfast_persistence_schema_hardening_contract.md`
8. `docs/breakfast_repository_service_integration_contract.md`
9. `CLAUDE.md`
10. `schema.md`

This document is authoritative for:

- mapping between `modifier_groups` and `product_modifiers(type='choice')`
- how real products are referenced through `item_product_id`
- constraints for valid choice-group configuration

This document defines configuration validity only.

Classification belongs to `docs/breakfast_domain_engine_contract.md`.
Persistence meaning belongs to `docs/breakfast_persistence_schema_hardening_contract.md`.
Repository orchestration boundaries belong to `docs/breakfast_repository_service_integration_contract.md`.

Phase 2C defines the exact data-level mapping for set breakfast choice groups. This is a schema and repository-facing contract only. It does not implement pricing logic or POS UI.

`Set 4` and `Set 9` remain representative example set products only. They validate the mapping shape and are not guaranteed production menu entries.

## Purpose

Choice groups must resolve to real catalog products.

Display name alone is not identity.

This phase therefore fixes the mapping rule:

- `modifier_groups` define the choice container
- `product_modifiers` define the choice members
- `product_modifiers.item_product_id` points to the real catalog `products.id`

Critical meaning:

- choice-capable products are real products, not virtual items
- choice groups must not duplicate product definitions
- choice groups define selection rules, not pricing rules

## Data Mapping

### 1. Group owner

`modifier_groups` are always attached to a set-root product.

Contract:

- `modifier_groups.product_id` = set-root product id
- one set-root product may have multiple choice groups
- choice groups are contextual to that set-root product
- choice groups define selection structure only
- choice groups must not be treated as pricing containers

### 2. Group members

`product_modifiers` rows are used as group-member entries for choices.

For choice entries:

- `product_modifiers.product_id` = set-root product id
- `product_modifiers.group_id` = related `modifier_groups.id`
- `product_modifiers.type = 'choice'`
- `product_modifiers.name` = display label only
- `product_modifiers.item_product_id` = real catalog product reference
- `product_modifiers.extra_price_minor = 0`

Note:

- this field is not used for breakfast pricing semantics
- pricing for choice members is determined later by the domain engine
- current breakfast default groups are single-selection only and do not support choice overflow

Interpretation:

- `name` is presentation text only
- `item_product_id` is the real identity
- choice members must be backed by actual catalog products such as `tea`, `coffee`, `toast`, `bread`
- choice members must not duplicate product definitions or act as virtual breakfast-only items
- pricing/classification meaning must not be inferred from the group-member mapping itself

Critical invariant:

Choice-group configuration must remain independent from pricing semantics.

Any attempt to encode pricing behavior inside:

- `modifier_groups`
- `product_modifiers(type='choice')`

is a violation of this contract.

### 3. Example member mapping

Example: `Tea or Coffee` group on a set-root product

```text
modifier_groups
  product_id = <set_root_id>
  name = 'Tea or Coffee'

product_modifiers
  product_id = <set_root_id>
  group_id = <tea_or_coffee_group_id>
  type = 'choice'
  name = 'Tea'
  item_product_id = <tea_product_id>
  extra_price_minor = 0

product_modifiers
  product_id = <set_root_id>
  group_id = <tea_or_coffee_group_id>
  type = 'choice'
  name = 'Coffee'
  item_product_id = <coffee_product_id>
  extra_price_minor = 0
```

The same pattern applies to `Toast or Bread`.

## Configuration-To-Runtime Mapping Boundary

This document defines how valid choice-group configuration maps to real products.

It does not define:

- pricing rules
- swap rules
- classification ownership
- repository-side inference rules

Those belong to later higher-scope breakfast contracts.

The write examples below are configuration-aligned outcome examples only.
They do not transfer classification ownership away from the domain engine.

## Order Write Semantics

Scope clarification:

The examples below illustrate how a valid configuration is expected to appear
after domain-engine classification.

They do NOT define classification logic.

All classification ownership belongs to:
- `docs/breakfast_domain_engine_contract.md`

This section must not be used to implement classification or pricing behavior.

### Included choice

When a valid included choice is selected, write one `order_modifiers` row:

- `action = 'choice'`
- `charge_reason = 'included_choice'`
- `item_product_id = real selected product`
- `quantity = included_quantity for that group`

Examples:

- `Tea or Coffee` -> `tea` selected -> `quantity = 1`
- `Toast or Bread` -> `toast` selected -> `quantity = 1`

### Explicit none for optional groups

If an optional group is explicitly set to `None`, write one `order_modifiers` row:

- `action = 'choice'`
- `charge_reason = 'included_choice'`
- `item_product_id = null`
- `quantity = 1`

This path is only valid when:

- `min_select = 0`
- the runtime intentionally supports a none choice for that group

Required breakfast groups do not support `None`.

Critical invariants:

- choice rows NEVER participate in swap matching
- choice selection does NOT consume replacement pool
- default breakfast required groups persist one `included_choice` row only

## Guardrails

The following rules are mandatory for future admin flows and repository validation:

1. Choice members must reference real products through `product_modifiers.item_product_id`.
2. Display name must never be treated as identity.
3. `product_modifiers.type = 'choice'` requires:
   - `group_id IS NOT NULL`
   - `item_product_id IS NOT NULL`
4. Non-choice `product_modifiers` rows may keep `item_product_id = NULL`.
5. Required breakfast groups must remain one-of-one selections in POS and runtime.
6. Choice products can never become swap replacements.
7. Choice products must never be matched against pending removals from `set_items`.
8. `order_modifiers.item_product_id` must carry the real selected product for `included_choice`, unless the group is explicitly set to optional `None`.
9. If a choice member points at a missing or inactive real product, future admin validation should reject the configuration.
10. The `Toast or Bread` group must still enforce:
    - `min_select = 1`
    - `max_select = 1`
    - `included_quantity = 1`
    - exactly one selected member
    - no `None`
    - no mixed split support
11. `modifier_groups` must satisfy `min_select <= max_select`.
12. `included_quantity` must not exceed `max_select`.
13. Every choice group must have at least one valid member.
14. Every choice member must map to a valid `products.id`.
15. Choice groups must not be used to simulate swap behavior.
16. Choice groups must not attach pricing directly to the group definition.
17. Choice groups must not be treated as flat legacy modifier lists.

## Anti-Misinterpretation Rules

- DO NOT treat choice groups as modifier pricing containers.
- DO NOT attach prices directly to choice group definitions.
- DO NOT allow choice groups to simulate swap behavior.
- DO NOT treat non-product-based labels as valid choice members.
- DO NOT infer choice classification in repositories from raw group mapping alone.

Legacy baseline note:

- older flat-modifier thinking is legacy baseline only
- current choice mapping is product-based and contract-driven
- any wording that implies implicit pricing or non-product choice items is stale and non-authoritative

## Relationship Summary

Note:

The relationship above represents data flow after domain-engine classification.

It must not be interpreted as a direct write path from configuration to persistence.

All runtime writes must pass through the breakfast domain rebuild engine.

```text
set-root product
  -> modifier_groups
    -> product_modifiers(type='choice', item_product_id=<real product>)
      -> order_modifiers(action='choice' or action='add', item_product_id=<real selected product>)
```

## Non-Goals

This contract does not define:

- pricing formulas
- swap counting
- runtime classification logic
- persistence field semantics
- POS interaction flow
- final production menu entries
- remote menu sync

## Phase Chain

- Phase 2A product role: `docs/menu_product_role_contract.md`
- Phase 2B set structure: `docs/set_breakfast_configuration_contract.md`
- Phase 2C choice mapping: `docs/choice_group_mapping_contract.md`
- Phase 2D eligibility/enforcement: `docs/menu_eligibility_enforcement_contract.md`
