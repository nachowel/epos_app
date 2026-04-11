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
8. `open orders` may remain as a UI/report umbrella label for active orders, but it must never be documented as a stored `transactions.status` value

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
