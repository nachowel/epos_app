-- Trusted-only mirror writes hardening migration.
-- Apply deliberately after verifying the live mirror schema baseline is in
-- place and the mirror-transaction-graph Edge Function is healthy.
--
-- Purpose:
-- - close anon/authenticated direct table writes on mirror tables
-- - retain the trusted Edge Function path that writes with service_role
-- - keep RLS enabled with no new permissive client write policies
--
-- This migration is intentionally idempotent and non-destructive to data.

begin;

-- Keep RLS enabled on the mirror tables. We do not introduce new client
-- policies here; the trusted service_role path remains the only write path.
alter table if exists public.transactions enable row level security;
alter table if exists public.transaction_lines enable row level security;
alter table if exists public.order_modifiers enable row level security;
alter table if exists public.payments enable row level security;

-- Remove permissive client write policies observed in the live audit.
drop policy if exists transactions_insert_sync on public.transactions;
drop policy if exists transactions_update_sync on public.transactions;
drop policy if exists transaction_lines_insert_sync on public.transaction_lines;
drop policy if exists transaction_lines_update_sync on public.transaction_lines;
drop policy if exists order_modifiers_insert_sync on public.order_modifiers;
drop policy if exists order_modifiers_update_sync on public.order_modifiers;
drop policy if exists payments_insert_sync on public.payments;
drop policy if exists payments_update_sync on public.payments;

-- Direct client writes are phased out. Revoke all direct table privileges from
-- anon/authenticated; service_role-backed Edge Functions continue to write.
revoke all privileges on public.transactions from anon, authenticated;
revoke all privileges on public.transaction_lines from anon, authenticated;
revoke all privileges on public.order_modifiers from anon, authenticated;
revoke all privileges on public.payments from anon, authenticated;

comment on table public.transactions is
  'Remote mirror of finalized local transaction snapshots. Client direct writes are closed by the trusted-only hardening migration.';
comment on table public.transaction_lines is
  'Remote mirror of local transaction line snapshots. Client direct writes are closed; trusted function path retained.';
comment on table public.order_modifiers is
  'Remote mirror of local order modifier snapshots. Client direct writes are closed; trusted function path retained.';
comment on table public.payments is
  'Remote mirror of local payment snapshots. Client direct writes are closed; trusted function path retained.';

commit;
