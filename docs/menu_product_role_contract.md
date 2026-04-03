# Menu Product Role Contract

## Authority Note

This document must be interpreted under `SYSTEM_OF_TRUTH.md`.

Authority order for this phase:

1. `SYSTEM_OF_TRUTH.md`
2. live schema and migrations for physical schema truth
3. this document
4. `docs/choice_group_mapping_contract.md`
5. `docs/menu_eligibility_enforcement_contract.md`
6. `docs/breakfast_domain_engine_contract.md`
7. `docs/breakfast_persistence_schema_hardening_contract.md`
8. `docs/breakfast_repository_service_integration_contract.md`
9. `CLAUDE.md`
10. `schema.md`

This document is authoritative for:

- product role categories in breakfast/menu-engine setup
- which products may act as:
  - set-root
  - set component
  - choice-capable product
  - extra-capable product where allowed by the current contract set
- which role assignments are configuration-valid versus runtime-classified later

This document defines role eligibility and valid role assignment.

Choice mapping details belong to `docs/choice_group_mapping_contract.md`.
Runtime classification belongs to `docs/breakfast_domain_engine_contract.md`.
Persistence meaning belongs to `docs/breakfast_persistence_schema_hardening_contract.md`.
Repositories must not reinterpret role meaning.

Phase 2A finalizes the product-role model for set breakfasts. This is a contract for admin configuration, repositories, and future validation. It does not implement pricing, POS flow, or UI.

## Core Rule

All menu parts are real `products` rows. Roles are contextual and come from menu configuration, not from duplicated products.

- A set breakfast root is a normal sold product.
- A set component is a real product referenced by `set_items`.
- A choice-capable product is a real product referenced by `modifier_groups` / `product_modifiers(type = 'choice')`.
- A product may be sold directly and still appear inside a set.

Critical invariant:

- Choice can become `extra_add`.
- Choice can never become swap replacement.
- Choice-capable products must never consume pending replacement units.

Role-layer note:

- role assignment determines whether a product is eligible for a breakfast role
- role assignment does not by itself define pricing behavior
- runtime classification still belongs to the breakfast domain engine

## Role Scope

Use this split throughout this document:

- configuration-valid:
  - whether a product may be assigned to a breakfast role in setup data
- runtime-valid:
  - whether a live order action may classify that product in a given way under domain-engine rules

This document defines configuration-valid role assignment.
It does not bypass runtime validation or runtime classification.

## Representative Product Groups

The examples below are representative only.
They are not hardcoded final production truth.

### Set breakfast roots

- `Set 4`
- `Set 9`

Contract:

- Must exist as normal sellable products.
- Must live under the `Set Breakfast` category.
- May own `set_items`.
- May own `modifier_groups`.
- Must never be used as a set component, included choice, extra add target, or swap replacement target.
- Must never be treated as choice-capable products.

### Set component products

- `egg`
- `bacon`
- `sausage`
- `chips`
- `beans`
- `tomato`
- `black pudding`

Contract:

- These are real products.
- They may be referenced by `set_items`.
- They may be removed from a set.
- They may be added as `extra_add`.
- They may be selected as `free_swap` / `paid_swap` replacements.
- This Phase 2A contract does not require them to be sold directly, but also does not forbid it.

Role note:

- under the current contract set, set component products are extra-capable
- that role eligibility does not define pricing rules by itself

### Choice-capable products

- `tea`
- `coffee`
- `toast`
- `bread`

Contract:

- These are real products sold directly in their own categories.
- `tea` / `coffee` belong to `Hot Drink`.
- `toast` / `bread` belong to `Breakfast Extras`.
- They may be included in sets via `modifier_groups`.
- They may become `extra_add` when allowance is exceeded or when sold directly.
- They must never participate in swap replacement logic.
- They must never be modeled as removable `set_items` for replacement matching.
- They must never consume pending replacement units.

## Role Matrix

| Product / Group | Sold Directly | Set Product | Set Item | Included Choice | Extra Add | Swap Replacement |
|---|---|---:|---:|---:|---:|---:|
| `Set 4` | Yes | Yes | No | No | No | No |
| `Set 9` | Yes | Yes | No | No | No | No |
| `egg` | Not required by this contract | No | Yes | No | Yes | Yes |
| `bacon` | Not required by this contract | No | Yes | No | Yes | Yes |
| `sausage` | Not required by this contract | No | Yes | No | Yes | Yes |
| `chips` | Not required by this contract | No | Yes | No | Yes | Yes |
| `beans` | Not required by this contract | No | Yes | No | Yes | Yes |
| `tomato` | Not required by this contract | No | Yes | No | Yes | Yes |
| `black pudding` | Not required by this contract | No | Yes | No | Yes | Yes |
| `tea` | Yes | No | No | Yes | Yes | No |
| `coffee` | Yes | No | No | Yes | Yes | No |
| `toast` | Yes | No | No | Yes | Yes | No |
| `bread` | Yes | No | No | Yes | Yes | No |

Interpretation note:

- this matrix defines role eligibility only
- it must not be read as a pricing table
- final runtime classification still depends on the breakfast domain engine

## Repository / Admin Contract

Future repository validation and dashboard configuration must enforce these guardrails:

1. Only set-root products may own `set_items` or `modifier_groups`.
2. `Set 4` and `Set 9` are valid set-root products. Non-set products must not be treated as set roots unless the product-role contract is expanded.
3. Choice-capable products must be configured through `modifier_groups` plus `product_modifiers(type = 'choice')`, not through removable `set_items`.
4. Products in the choice-capable list must be rejected as swap-replacement candidates.
5. Products in the choice-capable list must never be matched against pending set-item removals.
6. Set-root products must never appear inside their own `set_items`, inside another root's `set_items`, or as replacement candidates.
7. If a product is configured as an included choice for a set, that does not block it from also being sold directly or charged later as `extra_add`.
8. Admin configuration must avoid cloned products such as "Tea for set" or "Toast choice". The same real product row must be reused.
9. When a dashboard allows editing set composition, it must separate three lists clearly:
   - set components
   - included choices
   - extra-capable products
10. Any future import / seed / sync validation should fail fast if a choice-capable product is attached as a removable set item.

## Anti-Misinterpretation Rules

- DO NOT duplicate products just to create breakfast-only variants.
- DO NOT treat choice-capable products as removable `set_items`.
- DO NOT treat set-root products as replacement targets.
- DO NOT infer pricing behavior from role assignment alone.
- DO NOT let role assignment bypass domain-engine rules.
- DO NOT treat choice-capable products as virtual labels.
- DO NOT fall back to flat modifier logic when assigning breakfast roles.

## Non-Goals

This contract does not define:

- pricing formulas
- allowance calculations
- runtime classification logic
- persistence field semantics
- POS interaction flow
- removal discount calculation
- repository methods or UI screens

Phase 2B set-breakfast configuration structure is documented in
`docs/set_breakfast_configuration_contract.md`.

Phase 2C choice-member data mapping is documented in
`docs/choice_group_mapping_contract.md`.

Phase 2D eligibility and enforcement boundaries are documented in
`docs/menu_eligibility_enforcement_contract.md`.
