-- Phase 2 - EPOS Supabase mirror foundation
-- This file now reflects the current live mirror schema baseline.
-- Security tightening, policy changes, and trusted-only write enforcement are
-- separate follow-up work and are intentionally not declared here.
-- Apply trusted-only client write closure via a dedicated hardening migration,
-- not by editing this baseline in place.
--
-- Local Drift/SQLite remains the only operational authority.
-- Supabase stores synchronized mirror/reporting snapshots only.
-- No remote business authority is introduced here.
-- Cross-system identity is always the client-generated UUID value.
--
-- Important status/domain note:
-- - local transactions.status still includes in-progress values such as
--   draft/sent/open
-- - the current live mirror schema accepts finalized statuses only:
--   ('paid', 'cancelled')
-- The sync worker remains responsible for sending finalized graphs only.
--
-- Baseline usage note:
-- - this file is the repo truth for the current live mirror shape
-- - do not treat it as a blind in-place migration for drifted environments
-- - client direct write closure arrives through a separate hardening migration

begin;

create table if not exists public.transactions (
  uuid uuid primary key,
  shift_local_id bigint not null,
  user_local_id bigint not null,
  table_number integer null,
  status text not null check (status in ('paid', 'cancelled')),
  subtotal_minor integer not null check (subtotal_minor >= 0),
  modifier_total_minor integer not null check (modifier_total_minor >= 0),
  total_amount_minor integer not null check (total_amount_minor >= 0),
  created_at timestamptz not null,
  paid_at timestamptz null,
  updated_at timestamptz not null,
  cancelled_at timestamptz null,
  cancelled_by_local_id bigint null,
  kitchen_printed boolean not null default false,
  receipt_printed boolean not null default false,
  synced_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.transaction_lines (
  uuid uuid primary key,
  transaction_uuid uuid not null
    references public.transactions (uuid) on delete restrict,
  product_local_id bigint not null,
  product_name text not null,
  unit_price_minor integer not null check (unit_price_minor >= 0),
  quantity integer not null check (quantity > 0),
  line_total_minor integer not null check (line_total_minor >= 0)
);

create table if not exists public.order_modifiers (
  uuid uuid primary key,
  transaction_line_uuid uuid not null
    references public.transaction_lines (uuid) on delete restrict,
  action text not null check (action in ('remove', 'add')),
  item_name text not null,
  extra_price_minor integer not null default 0 check (extra_price_minor >= 0)
);

create table if not exists public.payments (
  uuid uuid primary key,
  transaction_uuid uuid not null unique
    references public.transactions (uuid) on delete restrict,
  method text not null check (method in ('cash', 'card')),
  amount_minor integer not null check (amount_minor > 0),
  paid_at timestamptz not null
);

create index if not exists idx_transactions_status_updated_at
  on public.transactions (status, updated_at desc);

create index if not exists idx_transactions_paid_at
  on public.transactions (paid_at desc nulls last);

create index if not exists idx_transactions_synced_at
  on public.transactions (synced_at desc);

create index if not exists idx_transaction_lines_transaction_uuid
  on public.transaction_lines (transaction_uuid);

create index if not exists idx_order_modifiers_transaction_line_uuid
  on public.order_modifiers (transaction_line_uuid);

create index if not exists idx_payments_transaction_uuid
  on public.payments (transaction_uuid);

create index if not exists idx_payments_paid_at
  on public.payments (paid_at desc);

create or replace function public.apply_epos_transaction_sync_guardrails()
returns trigger
language plpgsql
as $$
begin
  if new.status not in ('paid', 'cancelled') then
    raise exception 'transactions.status must be paid or cancelled in the mirror';
  end if;

  new.synced_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_transactions_set_last_received_at on public.transactions;
drop trigger if exists trg_transaction_lines_set_last_received_at on public.transaction_lines;
drop trigger if exists trg_order_modifiers_set_last_received_at on public.order_modifiers;
drop trigger if exists trg_payments_set_last_received_at on public.payments;
drop function if exists public.set_epos_last_received_at();

drop trigger if exists trg_transactions_sync_guardrails on public.transactions;
create trigger trg_transactions_sync_guardrails
before insert or update on public.transactions
for each row
execute function public.apply_epos_transaction_sync_guardrails();

comment on table public.transactions is
  'Remote mirror of finalized local transaction snapshots. This baseline matches the current live mirror schema.';
comment on table public.transaction_lines is
  'Remote mirror of local transaction line snapshots. Not a business write authority.';
comment on table public.order_modifiers is
  'Remote mirror of local order modifier snapshots. Not a business write authority.';
comment on table public.payments is
  'Remote mirror of local payment snapshots. Not a business write authority.';

comment on function public.apply_epos_transaction_sync_guardrails() is
  'Current live-style transaction mirror trigger. Trusted-only direct-write enforcement arrives through a separate hardening migration.';

commit;
