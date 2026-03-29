# Supabase Phase 1 Note

## Phase 1 syncable local tables

The phase-one remote sync foundation is scoped to these local Drift tables only:

- `transactions`
- `transaction_lines`
- `order_modifiers`
- `payments`

These remain UUID-based for cross-system identity. Local integer primary keys stay local and are used only as helper metadata where already present in payload snapshots.

## Local-only tables in phase 1

These stay local-only in this phase and are not part of the Supabase remote schema:

- `users`
- `categories`
- `products`
- `product_modifiers`
- `shifts`
- `payment_adjustments`
- `shift_reconciliations`
- `cash_movements`
- `audit_logs`
- `print_jobs`
- `report_settings`
- `printer_settings`
- `sync_queue`

## Current local source of truth

`lib/data/database/app_database.dart` is the implementation baseline.

- Current table inventory: `17` tables
- Current schema version: `14`
- Current sync queue target tables:
  - `transactions`
  - `transaction_lines`
  - `order_modifiers`
  - `payments`

## Mismatches that matter

### 1. Local table inventory is ahead of the markdown docs

`app_database.dart` includes operational tables that the markdown docs do not fully reflect:

- `payment_adjustments`
- `shift_reconciliations`
- `cash_movements`
- `audit_logs`
- `print_jobs`

These are intentionally left local-only in phase 1.

### 2. Transaction status semantics differ between code and markdown

`app_database.dart`:

- `transactions.status` check is `('draft','sent','paid','cancelled')`

`schema.md` and `CLAUDE.md` still describe older status sets such as:

- `('open','paid','cancelled')`

Important phase-one decision:

- Follow `app_database.dart`
- The existing sync worker still syncs terminal transactions only (`paid`, `cancelled`)
- No status behavior is changed in this phase

### 3. Shift default in code does not match docs

`app_database.dart` currently defines:

- `shifts.status` default = `'draft'`
- `CHECK (status IN ('open','closed'))`

`schema.md` / `CLAUDE.md` describe:

- default `'open'`

This mismatch is documented only. It is not changed in this phase because shifts are local-only and changing it would alter business behavior.

### 4. Report settings schema differs materially

`schema.md` and `CLAUDE.md` describe a larger `report_settings` table with fields beyond the current live Drift table.

This is out of scope for phase-one Supabase work and remains untouched.

### 5. Markdown docs are behind the Dart schema

For Supabase phase-one work, `lib/data/database/app_database.dart` must be treated as the source of truth over `schema.md` and `CLAUDE.md`.
