# Breakfast Persistence Schema Hardening Contract

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
4. this document
5. `docs/breakfast_repository_service_integration_contract.md`
6. `CLAUDE.md`
7. `schema.md`

This document is authoritative for:

- semantic breakfast persistence requirements on `order_modifiers`
- field-level persistence meaning
- migration/hardening direction for breakfast snapshot fidelity

This document must not override pure breakfast classification semantics owned by
`docs/breakfast_domain_engine_contract.md`.

Later integration docs and implementation details must not weaken the field-level persistence meaning defined here.

## Goal

Harden `order_modifiers` persistence so the breakfast rebuild engine can store semantic snapshot rows without losing business meaning.

This document is a migration and schema contract. It does not implement runtime service logic, popup UI, analytics, or requested-state redesign.

## Current Repo Reality

The current repo is not starting from the original flat legacy shape.

Already present in schema:

- `action` supports `remove`, `add`, `choice`
- `charge_reason` exists
- `item_product_id` exists
- `quantity` exists
- `extra_price_minor` exists

Missing for breakfast snapshot semantics:

- `unit_price_minor`
- `price_effect_minor`
- optional `sort_key`

Important implication:

- Phase 4A is now mostly a follow-up hardening migration, not a first introduction of breakfast semantics.

## Semantic Interpretation Layers

Use this split throughout this document:

- active breakfast semantic meaning:
  - the field meanings and runtime write expectations required by the current breakfast domain contracts
- legacy compatibility behavior:
  - temporary compatibility residues preserved so older rows and older repository paths do not break immediately
- live schema compatibility:
  - broader schema allowance that may exist physically but must not automatically become active breakfast runtime behavior

## Proposed Migration Version

Recommended next schema step:

- `v19`

Reason:

- `v16`, `v17`, and `v18` already cover menu-engine expansion, menu-settings stabilization, and choice-member real-product references
- this change is specifically about persistence fidelity for rebuilt breakfast modifier snapshots

## Migration Spec

### Target table shape

`order_modifiers` should support these persisted business fields:

- `action`
- `charge_reason`
- `item_product_id`
- `quantity`
- `unit_price_minor`
- `price_effect_minor`
- display label via existing `item_name`
- optional `sort_key`
- temporary backward-compatible `extra_price_minor`

Active breakfast semantic fields in this phase:

- `action`
- `charge_reason`
- `item_product_id`
- `quantity`
- `unit_price_minor`
- `price_effect_minor`
- `sort_key`

Compatibility residue in this phase:

- `extra_price_minor`

### Required schema state

1. `action` must support:
   - `remove`
   - `add`
   - `choice`
2. `charge_reason` runtime breakfast subset:
   - `included_choice`
   - `free_swap`
   - `paid_swap`
   - `extra_add`
3. `item_product_id` remains nullable FK-like reference to `products.id`
4. `quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0)`
5. `unit_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (unit_price_minor >= 0)`
6. `price_effect_minor INTEGER NOT NULL DEFAULT 0 CHECK (price_effect_minor >= 0)`
7. `sort_key INTEGER NOT NULL DEFAULT 0`
8. `extra_price_minor` remains during compatibility window

Field-level meaning:

- `unit_price_minor` = semantic per-unit catalog price for the persisted breakfast snapshot row
- `price_effect_minor` = actual persisted economic effect of the classified row
- `sort_key` = persisted rebuild-engine ordering key and must preserve rebuild output order
- `extra_price_minor` = compatibility residue only and must not define active breakfast classification semantics

### Charge reason note

Current schema already allows:

- `removal_discount`

Schema compatibility meaning:

- `removal_discount` is a broader live-schema-compatible allowance
- it is not part of the active breakfast pricing flow in the current contract set
- it must not become active breakfast runtime behavior unless a future explicit contract activates it

Safest Phase 4A approach:

- do not narrow the DB enum in this migration
- treat breakfast runtime writes as the stricter subset:
  - `included_choice`
  - `free_swap`
  - `paid_swap`
  - `extra_add`

Reason:

- narrowing the enum now risks backward incompatibility and is not required to support breakfast rebuild persistence
- broader schema compatibility must not be misread as active breakfast runtime permission

## SQL Migration Draft

SQLite-safe approach: recreate `order_modifiers`.

### Proposed DDL

```sql
PRAGMA foreign_keys = OFF;

DROP INDEX IF EXISTS idx_order_modifiers_line;
DROP INDEX IF EXISTS idx_order_modifiers_item_product;
DROP INDEX IF EXISTS idx_order_modifiers_item_product_semantics;

ALTER TABLE order_modifiers RENAME TO order_modifiers_legacy_v19;

CREATE TABLE order_modifiers (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  uuid TEXT NOT NULL UNIQUE,
  transaction_line_id INTEGER NOT NULL,
  action TEXT NOT NULL
    CHECK (action IN ('remove','add','choice')),
  item_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1
    CHECK (quantity > 0),
  item_product_id INTEGER NULL,
  extra_price_minor INTEGER NOT NULL DEFAULT 0
    CHECK (extra_price_minor >= 0),
  charge_reason TEXT NULL
    CHECK (
      charge_reason IS NULL OR
      charge_reason IN (
        'extra_add',
        'free_swap',
        'paid_swap',
        'included_choice',
        'removal_discount'
      )
    ),
  unit_price_minor INTEGER NOT NULL DEFAULT 0
    CHECK (unit_price_minor >= 0),
  price_effect_minor INTEGER NOT NULL DEFAULT 0
    CHECK (price_effect_minor >= 0),
  sort_key INTEGER NOT NULL DEFAULT 0,
  CHECK (action != 'choice' OR charge_reason = 'included_choice')
);

INSERT INTO order_modifiers (
  id,
  uuid,
  transaction_line_id,
  action,
  item_name,
  quantity,
  item_product_id,
  extra_price_minor,
  charge_reason,
  unit_price_minor,
  price_effect_minor,
  sort_key
)
SELECT
  id,
  uuid,
  transaction_line_id,
  action,
  item_name,
  quantity,
  item_product_id,
  extra_price_minor,
  charge_reason,
  extra_price_minor,
  extra_price_minor,
  0
FROM order_modifiers_legacy_v19;

DROP TABLE order_modifiers_legacy_v19;

CREATE INDEX IF NOT EXISTS idx_order_modifiers_line
  ON order_modifiers(transaction_line_id);

CREATE INDEX IF NOT EXISTS idx_order_modifiers_item_product
  ON order_modifiers(item_product_id, charge_reason);

CREATE INDEX IF NOT EXISTS idx_order_modifiers_item_product_semantics
  ON order_modifiers(item_product_id, action, charge_reason, sort_key);

PRAGMA foreign_keys = ON;
```

## Legacy Row Compatibility Mapping

Legacy rows must not be reinterpreted semantically.

Required migration mapping:

- `charge_reason = existing value`
  - or `NULL` if legacy row predates breakfast semantics
- `item_product_id = existing value`
  - or `NULL` if legacy row predates breakfast semantics
- `quantity = existing value`
  - or `1` if legacy row predates quantity support
- `unit_price_minor = extra_price_minor`
- `price_effect_minor = extra_price_minor`
- `sort_key = 0`

Important interpretation:

- this does not claim old rows were true breakfast semantic rows
- it preserves old economic meaning as safely as possible
- new runtime breakfast writes must explicitly write `unit_price_minor`, `price_effect_minor`, and `sort_key`
- legacy rows remain preserved for compatibility without being reinterpreted as fully semantic breakfast rows

## Drift Table Update Draft

### Proposed `OrderModifiers` additions

```dart
class OrderModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionLineId => integer().customConstraint(
    'NOT NULL REFERENCES "transaction_lines" ("id")',
  )();

  TextColumn get action => text()();

  TextColumn get itemName => text()();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  IntColumn get itemProductId =>
      integer().nullable().customConstraint('REFERENCES "products" ("id")')();

  IntColumn get extraPriceMinor => integer().withDefault(const Constant(0))();

  TextColumn get chargeReason => text().nullable()();

  IntColumn get unitPriceMinor => integer().withDefault(const Constant(0))();

  IntColumn get priceEffectMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get sortKey => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (\"action\" IN ('remove','add','choice'))",
    'CHECK (quantity > 0)',
    'CHECK (extra_price_minor >= 0)',
    'CHECK (unit_price_minor >= 0)',
    'CHECK (price_effect_minor >= 0)',
    "CHECK (charge_reason IS NULL OR charge_reason IN ('extra_add','free_swap','paid_swap','included_choice','removal_discount'))",
    "CHECK (\"action\" != 'choice' OR charge_reason = 'included_choice')",
  ];
}
```

### Index draft

Keep:

- `idx_order_modifiers_line`
- `idx_order_modifiers_item_product`

Add:

- `idx_order_modifiers_item_product_semantics`
  - `(item_product_id, action, charge_reason, sort_key)`

## Compatibility Notes

1. `extra_price_minor` remains temporarily to avoid breaking legacy repository math and old domain models.
2. New breakfast runtime code should treat:
   - `unit_price_minor` as per-unit catalog price
   - `price_effect_minor` as actual persisted economic impact
3. Old code paths may continue reading `extra_price_minor` until service/repository integration is upgraded.
4. Repositories must not invent semantic meaning from `extra_price_minor`.
5. New breakfast runtime writes must explicitly write all semantic fields and must not derive them later from `extra_price_minor`.
6. Existing rows remain readable after migration because defaults and copy rules preserve the prior shape.
7. Broader schema allowances such as `removal_discount` remain schema-compatible only and do not become active breakfast behavior automatically.
8. If live schema contains stale or broader residues outside the active breakfast semantic set, they remain inactive unless a future explicit contract activates them.

## Risks

1. Current repository math still sums `extra_price_minor`; after this migration it will not yet understand `price_effect_minor`.
2. Existing domain models such as `OrderModifier` do not yet expose `charge_reason`, `item_product_id`, `quantity`, `unit_price_minor`, `price_effect_minor`, or `sort_key`.
3. If runtime code starts writing semantic breakfast rows before repository math is upgraded, totals may drift.
4. Keeping both `extra_price_minor` and `price_effect_minor` creates a temporary dual-source risk until runtime code is consolidated.
5. Treating broader schema-compatible values as active breakfast runtime semantics would create classification drift and persistence ambiguity.

## Rollback Notes

1. Safest rollback point is before app release with `v19`.
2. If rollback is required, reverse migration would need another table rebuild dropping:
   - `unit_price_minor`
   - `price_effect_minor`
   - `sort_key`
3. Reverse migration would preserve old behavior by mapping:
   - `extra_price_minor = price_effect_minor`
4. Do not attempt rollback after new runtime code depends on semantic fields unless the downgrade path is tested explicitly.

## What This Phase Does Not Do

- implement breakfast runtime writes
- redesign requested-state storage
- change popup flow
- change analytics
- change receipt formatting
