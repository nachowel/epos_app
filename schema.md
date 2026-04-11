# EPOS Veritabanı Şeması — Human-Readable Summary (Authority Aligned)

---

## Authority Note

This document is a **human-readable schema summary** and **legacy/current reference baseline**.

It is NOT the highest authority.

### 🔴 Always follow:

1. `SYSTEM_OF_TRUTH.md`
2. `lib/data/database/app_database.dart`
3. embedded migration logic in `lib/data/database/app_database.dart`
4. relevant feature contract docs, including:
   * `docs/pos_category_entry_flow_contract.md`
   * `docs/menu_product_role_contract.md`
   * `docs/set_breakfast_configuration_contract.md`
   * `docs/choice_group_mapping_contract.md`
   * `docs/menu_eligibility_enforcement_contract.md`
   * `docs/breakfast_domain_engine_contract.md`
   * `docs/breakfast_persistence_schema_hardening_contract.md`
   * `docs/breakfast_repository_service_integration_contract.md`
5. `CLAUDE.md`
6. `schema.md`

### Critical rule:

If this file conflicts with:

* live schema
* migration files
* feature contract docs

👉 **THIS FILE IS WRONG → update it later**

---

## 📌 Purpose of this file

This document exists to:

* explain the database structure in plain language
* give quick reference for tables and relationships
* help developers understand the system

It does NOT:

* define final business rules
* override domain contracts
* guarantee full alignment with live schema without checking higher authority

---

## 🧠 SYSTEM MODEL OVERVIEW

### Core design:

* Local Drift/SQLite database = **operational source of truth for live EPOS data**
* Supabase = **mirror/reporting only**
* Business logic = **domain layer**
* UI = **representation only**

---

## ⚠️ LEGACY vs CURRENT MODEL

### Legacy baseline (historical only)

* flat `product_modifiers`
* `included / extra`
* simple remove/add interpretation
* older transaction language such as `open`

### Current system (active live direction)

* set engine
* `set_items`
* `modifier_groups`
* semantic `order_modifiers`
* choice / swap / extra separation
* transaction statuses `draft / sent / paid / cancelled`

👉 Legacy baseline sections below are historical context only
👉 Only the current live model should be used for implementation

---

# 🗄 TABLE SUMMARY (CURRENT LIVE SCHEMA WITH LEGACY BASELINE NOTES)

## Core operational tables

---

### 1. users

Stores system users.

```text id="p3b4rm"
id
name
pin
password
role (admin | cashier)
is_active
created_at
```

---

### 2. categories

Product grouping plus removal-discount configuration.

```text id="f87hiy"
id
name
image_url
sort_order
is_active
removal_discount_1_minor
removal_discount_2_minor
```

Notes:

* `categories.sort_order` is the single persisted source of truth for category display order
* the Category Entry screen and the POS category sidebar must use the same `sort_order`
* the live schema does not define a separate featured-category field
* the live schema does not define a separate popularity-order field

---

### 3. products

Sellable catalog items.

```text id="mz3v3y"
id
category_id
name
price_minor
image_url
has_modifiers
is_active
is_visible_on_pos
sort_order
```

---

### 4. product_modifiers

Legacy baseline (historical interpretation only):

```text id="zwr2hz"
included
extra
```

### Current live schema:

```text id="yz8r4g"
product_id
group_id (nullable)
item_product_id (nullable for non-choice, required for choice)
name
type (included | extra | choice)
extra_price_minor
price_behavior (nullable: free | paid)
ui_section (nullable: toppings | sauces | add_ins)
is_active
```

Notes:

* `type = 'choice'` members must reference real catalog products through `item_product_id`
* breakfast choice members are owned through `modifier_groups`, not duplicated products
* structured burger-style flat modifiers keep `type = 'extra'`; `price_behavior` and `ui_section` only add pricing/render metadata
* legacy flat interpretation is baseline only; the current live table shape is authoritative here

---

### 5. shifts

```text id="l7b03n"
id
opened_by
opened_at
closed_by
closed_at
cashier_previewed_by
cashier_previewed_at
status (open | closed)
```

---

### 6. transactions

```text id="48cd3v"
id
uuid
shift_id
user_id
table_number
status (draft | sent | paid | cancelled)
subtotal_minor
modifier_total_minor
total_amount_minor
created_at
paid_at
updated_at
cancelled_at
cancelled_by
idempotency_key
kitchen_printed
receipt_printed
```

Notes:

* a transaction is created only when the first product is successfully added to cart on the POS screen
* before first product add, the system is in a pre-order state with no transaction row, no cart as either persisted state or in-memory structured order, and no allocated `transaction_id`
* no action other than successful first-product add may exit pre-order state
* first product add creates the cart together with the transaction, and that cart is always tied to `transaction_id`
* first product add must atomically create the transaction, set `status = 'draft'`, insert the first `transaction_line`, compute totals, and set `updated_at`
* login, Category Entry navigation, and category selection do not create transactions
* after payment, the cart is fully destroyed, selected category is cleared, transaction context is closed, and the system returns to a clean pre-order state
* parallel in-memory carts before transaction creation and simulated cart behavior without a real transaction are forbidden

### Current live status contract

```text id="c2r5sk"
draft / sent / paid / cancelled
```

Operational meaning:

* `draft` = persisted order exists and remains editable
* `sent` = draft order has been submitted and is awaiting payment or cancellation
* `paid` = payment completed; terminal
* `cancelled` = sent order cancelled without payment; terminal

Allowed transitions:

* pre-order -> no persisted row
* first successful product add -> `draft`
* `draft -> sent`
* `sent -> paid`
* `sent -> cancelled`

Forbidden transitions:

* pre-order -> any persisted transaction without first product add
* `draft -> paid`
* `draft -> cancelled`
* `paid -> *`
* `cancelled -> *`

Lifecycle notes:

* only `draft` transactions are editable
* only `sent` transactions are payable
* only `sent` transactions are cancellable
* discarding a `draft` deletes it; discard is not a persisted status transition
* active/open-order lists are the combined set `draft + sent`
* `open` may remain as a legacy umbrella label for active orders, but it is not a stored `transactions.status`
* migration compatibility may still encounter older `open` language, but canonical persisted status truth is `draft / sent / paid / cancelled`
* remote mirror sync accepts terminal states only: `paid` and `cancelled`

---

### 7. transaction_lines

```text id="2u7q2g"
id
uuid
transaction_id
product_id
product_name
unit_price_minor
quantity
line_total_minor
pricing_mode (standard | set)
removal_discount_total_minor
```

---

### 8. order_modifiers (CRITICAL TABLE)

Legacy baseline (historical interpretation only):

```text id="o9d6il"
action (remove | add)
item_name
extra_price_minor
```

### Current live schema:

```text id="svffhu"
action (remove | add | choice)
charge_reason (
  null |
  extra_add |
  free_swap |
  paid_swap |
  included_choice |
  removal_discount
)
item_product_id
source_group_id
quantity
extra_price_minor
unit_price_minor
price_effect_minor
sort_key
price_behavior (nullable: free | paid)
ui_section (nullable: toppings | sauces | add_ins)
```

Notes:

* `action = 'choice'` requires `charge_reason = 'included_choice'`
* this table is semantic snapshot persistence, not cosmetic modifier text
* structured burger selections persist as `action = 'add'` rows and carry nullable `price_behavior` / `ui_section` context for mirror analytics
* breakfast contract semantics use the contract-defined subset; `removal_discount` remains live-schema-compatible

---

### 9. payments

```text id="8jljj9"
id
uuid
transaction_id (UNIQUE)
method (cash | card)
amount_minor
paid_at
```

---

### 10. payment_adjustments

```text id="pm8j21"
id
uuid
payment_id (UNIQUE)
transaction_id
type (refund | reversal)
status (completed)
amount_minor
reason
created_by
created_at
```

---

### 11. shift_reconciliations

```text id="sr7f0m"
id
uuid
shift_id
kind (final_close)
expected_cash_minor
counted_cash_minor
variance_minor
counted_cash_source
counted_by
counted_at
```

---

### 12. cash_movements

```text id="cm1d5n"
id
shift_id
type (income | expense)
category
amount_minor
payment_method (cash | card | other)
note
created_by_user_id
created_at
```

---

### 13. audit_logs

```text id="al4t2v"
id
actor_user_id
action
entity_type
entity_id
metadata_json
created_at
```

---

### 14. print_jobs

```text id="pj6w8q"
id
transaction_id
target (kitchen | receipt)
status (pending | printing | printed | failed)
created_at
updated_at
attempt_count
last_attempt_at
completed_at
last_error
```

---

### 15. report_settings

```text id="kqgm3g"
id
cashier_report_mode
visibility_ratio
max_visible_total_minor
business_name
business_address
updated_by
updated_at
```

---

### 16. printer_settings

```text id="p4qntj"
id
device_name
device_address
paper_width
is_active
```

---

### 17. sync_queue

```text id="b2qrrc"
id
table_name
record_uuid
operation
created_at
status
attempt_count
last_attempt_at
synced_at
error_message
```

---

# 🧩 MENU ENGINE EXTENSIONS (CURRENT LIVE TABLES)

These are current live schema concepts. Their business meaning follows the breakfast/menu-engine contract chain above.

---

## 1. set_items

Defines removable default set contents.

```text id="8q9d4c"
product_id (set root)
item_product_id (real component product)
default_quantity
is_removable
sort_order
```

Notes:

* only set-root products should own `set_items`
* `set_items` represent removable components
* choice-capable products must not be modeled here

---

## 2. modifier_groups

Defines included choice groups for a set root.

```text id="g9u5r0"
product_id
name
min_select
max_select
included_quantity
sort_order
```

Notes:

* only set-root products should own breakfast `modifier_groups`
* breakfast contracts require the `Tea or Coffee` and `Toast or Bread` group pattern for breakfast set roots
* current breakfast defaults treat both groups as required single selections with `min_select = max_select = included_quantity = 1`
* those group names are contract-level configuration examples, not a replacement for live menu data

---

## 3. menu_settings

```text id="7m8dcv"
free_swap_limit
max_swaps
updated_by
updated_at
```

Note:

* `max_swaps` exists in the schema but is NOT part of the active breakfast domain rule set
* it must NOT be used in pricing or classification logic
* current rule:
  - first `free_swap_limit` replacements → `free_swap`
  - all subsequent replacements → `paid_swap`
* introducing a hard swap cap requires a new explicit contract and must not be inferred from schema residue

---

# 🍳 MENU ENGINE BEHAVIOR SUMMARY

### Role summary

* set-root products are normal sellable products that may own `set_items` and `modifier_groups`
* set component products are removable and swap-eligible
* choice-capable products are real products referenced through `product_modifiers(type = 'choice')`
* choice-capable products may become `extra_add` but never swap replacements

---

### Modifier classification

| Type            | Description                              |
| --------------- | ---------------------------------------- |
| remove          | removing default set item                |
| included_choice | included choice within group allowance   |
| free_swap       | matched replacement within free limit    |
| paid_swap       | matched replacement after free limit     |
| extra_add       | direct extra outside swap replacement    |

Live schema compatibility note:

* `removal_discount` exists in the schema for future or category-based discount features
* it is NOT part of the active breakfast domain-engine pricing flow
* do not classify breakfast modifiers using `removal_discount` unless explicitly defined by a future contract

---

### Swap logic

```text id="u1g8is"
removed set-item units + eligible direct add units = swap matching
```

Rules:

* pending replacement units come only from removed `set_items`
* only eligible direct non-choice additions may consume that pool
* first `free_swap_limit` matched units → `free_swap`
* later matched units → `paid_swap`
* choice-capable products never consume the swap pool

Critical invariant:

* choice-capable products MUST NEVER consume pending replacement units
* violating this rule breaks swap accounting and pricing determinism

---

### Choice logic

* choice groups are defined by `modifier_groups`
* choice members are defined by `product_modifiers(type = 'choice')`
* `item_product_id` is the real product identity
* choice does NOT consume swap pool
* supported breakfast default groups are single-selection only

---

### Extra logic

* direct add with no eligible pending replacement → `extra_add`

---

# 💰 MONEY RULE (CRITICAL)

All money stored as INTEGER (minor units):

```text id="3zhlxg"
£12.50 → 1250
```

NEVER use float/double.

---

# 🔁 SYNC MODEL

### Phase 1 synced tables:

```text id="vsz70r"
transactions
transaction_lines
order_modifiers
payments
```

### Current local-only tables in this phase:

* users
* categories
* products
* menu_settings
* set_items
* modifier_groups
* product_modifiers
* shifts
* payment_adjustments
* shift_reconciliations
* cash_movements
* audit_logs
* print_jobs
* report_settings
* printer_settings
* sync_queue

---

### Rules:

* Supabase receives mirror snapshots only
* local Drift/SQLite remains the operational authority
* only terminal transaction states sync: `paid`, `cancelled`
* local editable states such as `draft` and `sent` stay local
* local DB is never overwritten by mirror sync
* `sync_queue_root_graph_snapshots` is a local checksum helper, not a remote authority

---

# ⚠️ IMPORTANT LIMITATIONS

This file does NOT define:

* pricing engine logic
* swap algorithm details beyond summary
* rebuild algorithm implementation
* UI behavior

👉 Those belong to higher-authority contract docs

---

# 🧠 FINAL MENTAL MODEL

* Tables store facts
* Domain decides meaning
* Contracts define breakfast/menu-engine rules
* UI displays result

---

## ✅ SUMMARY

This file is:

✔ readable
✔ structured
✔ useful

But NOT:

❌ final authority
❌ complete truth
❌ safe alone for implementation

---

## 🔴 FINAL RULE

If unsure:

```text id="6t3j9u"
Follow SYSTEM_OF_TRUTH.md
```

---

**End of file**
