# SYSTEM OF TRUTH — EPOS Authority File

This file defines the authority order for all EPOS project decisions.

Its purpose is to prevent conflicting interpretations across:
- `CLAUDE.md`
- `schema.md`
- migration files
- runtime code
- feature contract docs
- Supabase notes

If two sources disagree, follow the hierarchy below.

---

## 1. Authority Hierarchy

Use this authority chain in this exact order:

1. `SYSTEM_OF_TRUTH.md`
2. `lib/data/database/app_database.dart`
3. embedded migration functions and raw SQL defined in `lib/data/database/app_database.dart`
4. relevant feature contract docs
5. `CLAUDE.md`
6. `schema.md`

Interpretation:
- `SYSTEM_OF_TRUTH.md` defines which source governs each subject area
- live schema and embedded migrations define current persisted table shape and constraints
- feature contract docs define approved feature behavior where schema alone is insufficient
- `CLAUDE.md` provides coding and architecture guardrails
- `schema.md` is human-readable support documentation only

If lower-authority markdown disagrees with higher-authority sources, the lower-authority markdown must be updated.

---

## 2. Feature contract truth

For POS entry flow, pre-order semantics, persisted transaction status
semantics, order lifecycle timing, category ordering, and admin category
reorder behavior, the authoritative contract is:

1. `docs/pos_category_entry_flow_contract.md`

Interpretation:
- login-to-selling navigation flow
- post-payment return flow
- canonical persisted transaction status model
- persisted transaction lifecycle transitions
- active-order terminology boundaries
- transaction creation trigger
- category order source of truth
- category entry vs POS screen responsibility split
- admin category reorder persistence contract

If UI behavior, older notes, or implementation shortcuts conflict with this
contract, the contract wins and the implementation must be updated later.

For breakfast, set logic, swap logic, choice logic, persistence semantics, and edit orchestration, the authoritative contract chain is:

1. `docs/menu_product_role_contract.md`
2. `docs/set_breakfast_configuration_contract.md`
3. `docs/choice_group_mapping_contract.md`
4. `docs/menu_eligibility_enforcement_contract.md`
5. `docs/breakfast_domain_engine_contract.md`
6. `docs/breakfast_persistence_schema_hardening_contract.md`
7. `docs/breakfast_repository_service_integration_contract.md`

Interpretation:
- product role meaning
- set root vs set item vs choice-capable meaning
- choice mapping
- breakfast rebuild logic
- modifier classification
- persistence semantics
- service/repository responsibility split

must follow this contract chain.

If `CLAUDE.md` or `schema.md` conflicts with these docs, the contract docs win.

For standard products outside breakfast, the authoritative meal-adjustment
foundation contract is:

1. `docs/meal_adjustment_engine_contract.md`

Interpretation:

- profile-based standard meal customization
- standard engine semantic core boundaries
- future request/resolved snapshot contract

Breakfast contracts remain separate and must not be collapsed into the standard
meal-adjustment contract.

---

## 2A. Canonical Transaction Lifecycle Authority

Until a dedicated lifecycle-only contract doc exists, the authority for the
persisted transaction lifecycle is this section together with
`docs/pos_category_entry_flow_contract.md`.

Canonical persisted status chain:

- `draft -> sent -> paid`
- `draft -> sent -> cancelled`

Status meaning:

- `draft` = transaction exists, order is still editable, and no submit/send action has completed yet
- `sent` = an explicit submit/send-order action completed successfully; editable order-building is closed, the order snapshot is frozen for payment/cancellation, and kitchen-print side effects become eligible
- `paid` = payment completed successfully; terminal
- `cancelled` = a previously sent order was cancelled without payment; terminal

Persisted draft creation:

- a persisted `draft` is created only on the first successful product add
- minimum creation condition is: transaction row + first line insert + totals computed in the same successful atomic flow
- empty-cart or navigation-only transaction creation is forbidden
- a transaction must never be persisted without at least one successfully added line

Transition triggers:

- pre-order -> `draft` only on the first successful product add
- `draft -> sent` only on the explicit send/submit-order event
- `sent -> paid` only on a successful payment completion event
- `sent -> cancelled` only on an explicit cancel event against an unpaid sent transaction

Sent-state rules:

- `sent` is not editable because order-building must stop before payment/cancellation and before kitchen execution is treated as actionable
- line, modifier, and discount mutation are forbidden in `sent`
- entering `sent` must atomically persist the final pre-payment transaction snapshot and queue the kitchen print job exactly once
- kitchen print retry/failure handling may occur after `sent`, but retry logic must not create a second `draft -> sent` transition

Payment entry rule:

- payment may start only if the persisted current status is exactly `sent`
- payment attempt must re-check the persisted transaction status immediately before inserting the payment row or finalizing payment state
- if current status is not `sent`, payment must be rejected and must not create payment-side effects

Draft handling:

- `draft` may be discarded/deleted before send
- draft cleanup is a discard flow, not a `cancelled` transition
- a draft must never transition directly to `paid` or `cancelled`
- abandoned draft cleanup is manual discard/delete in the current authority model
- automatic abandoned-draft cleanup is future scope and must not be inferred without a new contract
- `draft` is local operational state only and must not sync to the remote mirror

Mutability matrix:

| State       | lines | modifiers | discounts | table_number | notes / metadata |
| ----------- | ----- | --------- | --------- | ------------ | ---------------- |
| `draft`     | mutable | mutable | mutable | mutable | mutable |
| `sent`      | immutable | immutable | immutable | immutable | immutable |
| `paid`      | immutable | immutable | immutable | immutable | immutable |
| `cancelled` | immutable | immutable | immutable | immutable | immutable |

Print relation:

- kitchen print attempt happens only after the successful `draft -> sent` transition
- `sent` does not require kitchen print success; `sent` is the frozen commercial snapshot before payment
- kitchen print must never be triggered from pre-order or `draft` alone
- receipt print attempt happens only after the successful `sent -> paid` transition
- print failure does not alter lifecycle truth and must not trigger state rollback
- receipt/kitchen print flags are operational state only; they are not lifecycle state
- print retry must not create duplicate payment or lifecycle transitions

Hard lifecycle rules:

- each transition has exactly one allowed source state
- the same user action must not resolve to multiple target states
- duplicate send/payment/cancel requests must be guarded by persisted state checks and must not create duplicate side effects
- terminal states `paid` and `cancelled` must reject further lifecycle transitions

---

## 2B. Approved Phase-1 Discount Authority

Until a dedicated discount contract doc exists, the authority for phase-1
transaction discount behavior is this section. This is the approved target
contract for the next schema/application change; live schema remains the
current physical truth until migration lands.

Phase-1 scope:

- discount is transaction-level only
- line-item discount is out of scope
- tax, VAT, and service charge remain out of scope
- `payment` table does not gain discount fields
- discount logic must not be embedded into `transaction_lines` or `order_modifiers`

Approved phase-1 transaction columns:

- `discount_type` -> nullable text enum: `amount | percent`
- `discount_value_minor` -> integer default `0`
- `discount_amount_minor` -> integer default `0`
- `discount_reason` -> nullable text
- `discount_applied_by` -> nullable integer FK -> `users.id`

Meaning:

- `discount_value_minor` is the raw entered value
- `discount_amount_minor` is the computed monetary reduction actually deducted from the transaction total
- for `discount_type = 'amount'`, `discount_value_minor` is currency minor units
- for `discount_type = 'percent'`, `discount_value_minor` is whole-number percent integer `0..100` where `10 = 10%`
- percentage is not stored as float, decimal, or basis points in phase 1
- this single integer raw-value field is used to keep one typed input slot; `discount_amount_minor` remains the canonical money result

Calculation contract:

- `pre_discount_total_minor = subtotal_minor + modifier_total_minor`
- `discount_amount_minor` must be derived from `discount_type`, `discount_value_minor`, and `pre_discount_total_minor`
- for amount discount, `discount_amount_minor = discount_value_minor` after validating that the raw value does not exceed `pre_discount_total_minor`
- for percent discount, `discount_amount_minor = round_half_up(pre_discount_total_minor * discount_value_minor / 100)` using integer arithmetic only
- `total_amount_minor = max(0, pre_discount_total_minor - discount_amount_minor)`
- fixed-amount discount must not exceed `pre_discount_total_minor`
- percent discount must clamp to integer `0..100`
- final total must never be negative
- all monetary values remain integer minor units; float/double is forbidden

Lifecycle and authority rules:

- discount may be added, changed, or removed only while a transaction is in `draft`
- for discount mutability, `draft` is the only editable persisted transaction state in the canonical status model
- once a transaction becomes `sent`, `paid`, or `cancelled`, discount is frozen
- `paid` and `cancelled` remain terminal states
- discount must be finalized before checkout/payment begins
- removing discount resets `discount_type = null`, `discount_value_minor = 0`, `discount_amount_minor = 0`, `discount_reason = null`, and `discount_applied_by = null`
- synced transaction snapshots must include the discount fields
- receipt output must show discount as a separate line item
- phase-1 reports must reconcile correctly from net totals; discount analytics remains future scope

Payment invariant:

- `payments.amount_minor` must remain exactly equal to `transactions.total_amount_minor`
- payment amount is always based on the final post-discount transaction total

Role decision for phase 1:

- both `cashier` and `admin` may apply, change, or remove transaction discount while the transaction is still `draft`
- no role-based discount cap or admin override workflow exists in phase 1
- stricter approval/limit policy is future scope

---

## 3. Supabase sync truth

For sync and remote mirror architecture, the authoritative docs are:

1. `docs/supabase_phase1_note.md`
2. `docs/supabase_phase2_setup.md`

Interpretation:
- Drift/SQLite is the only operational source of truth
- Supabase is mirror/reporting only
- remote writes must follow trusted function architecture when hardening is applied
- markdown docs may lag behind live code and migration history

If other docs imply Supabase is operational authority, those docs are wrong.

---

## 4. Workspace authority

Authoritative Flutter app root:

- `C:\Users\nacho\Desktop\EPOS\epos_app`

The parent workspace root is non-authoritative for app changes.

See:
- `docs/workspace_root_guard.md`

All code changes, tests, analysis, migrations, and schema work must target `epos_app` only unless explicitly approved otherwise.

---

## 5. Role of `CLAUDE.md`

`CLAUDE.md` is a coding and workflow guidance file.

It is authoritative for:
- architecture guardrails
- layer boundaries
- coding discipline
- anti-pattern bans
- implementation workflow rules

It is **not** the final authority for:
- current live schema shape
- migration truth
- feature contract details when those are documented in dedicated contract files

If `CLAUDE.md` conflicts with live schema or contract docs, update `CLAUDE.md` later, but do not follow the stale section.

---

## 6. Role of `schema.md`

`schema.md` is a human-readable schema summary.

It is useful for:
- quick table overview
- concept explanation
- implementation notes
- migration direction summary

It is **not** the top authority when it conflicts with:
- `app_database.dart`
- migration files
- feature contract docs

If `schema.md` conflicts with live schema, live schema wins and `schema.md` must be updated afterward.

---

## 7. Conflict Resolution Rules

### Rule A
If live code and markdown docs conflict:
- follow live code
- update markdown afterward

### Rule B
If feature contract docs and older general docs conflict:
- follow the relevant feature contract docs
- update general docs afterward

### Rule C
If `CLAUDE.md` and `schema.md` conflict with each other:
- follow live schema first
- then domain contracts
- then sync docs
- then use `CLAUDE.md` only for workflow and architecture guidance

### Rule D
Do not invent business rules from UI behavior.
Business rules must come from:
- live implementation
- explicit contract docs
- approved migration direction

---

## 8. Current Known Reality Mismatches

These mismatches are already known and must not be ignored:

1. Markdown docs may lag behind `app_database.dart`
2. Canonical persisted transaction status model is `draft / sent / paid / cancelled`; any older `open` wording is legacy terminology only
3. Older flat modifier descriptions do not fully represent the newer breakfast/menu-engine direction
4. `CLAUDE.md` and `schema.md` may contain legacy baseline sections that are useful for history but not authoritative for current breakfast behavior
5. POS/category-entry behavior must come from `docs/pos_category_entry_flow_contract.md`, not from older direct-to-POS navigation assumptions
6. Pre-order is a non-persisted navigation/browsing state and must not be confused with any persisted `transactions.status` value
7. The raw SQL schema and migrations define transaction default/status truth; any stale code residue such as a Dart-side `open` default must not be treated as canonical persisted status truth
8. `open orders` may remain as a UI/report label for the active set `draft + sent`, but it must never be documented as a stored `transactions.status` value
9. Phase-1 discount behavior is now approved at authority/spec level, but current live schema may not yet contain the transaction discount columns until the corresponding migration is implemented

---

## 9. Implementation Rule for AI-Assisted Development

When using Codex, Claude, Cursor, or other AI tools:

Always instruct the model to follow this order:

1. `SYSTEM_OF_TRUTH.md`
2. live schema and embedded migrations in `app_database.dart`
3. relevant feature contract docs
4. `CLAUDE.md`
5. `schema.md`

Never rely on `CLAUDE.md` or `schema.md` alone for feature work where a dedicated contract exists.

---

## 10. Practical Summary

Use this mental model:

- **What is physically true now?**
  - `app_database.dart` + migrations

- **What is semantically true for breakfast/menu engine?**
  - contract docs

- **What is semantically true for POS entry flow, transaction lifecycle semantics, and category ordering?**
  - `docs/pos_category_entry_flow_contract.md`

- **What is operational/coding discipline?**
  - `CLAUDE.md`

- **What is human-readable summary?**
  - `schema.md`

That is the project truth model.
