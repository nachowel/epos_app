-- Phase 2 - EPOS Supabase mirror foundation
-- Local Drift/SQLite is the primary operational authority.
-- Supabase stores synchronized mirror/reporting snapshots only.
-- No remote business authority is introduced here.
-- Cross-system identity is always the client-generated UUID text column.
--
-- Important documented mismatch from local Drift:
-- - local transactions.status default is 'open'
-- - local transactions.status CHECK is ('draft','sent','paid','cancelled')
-- The remote mirror uses the reporting status domain only:
--   ('open', 'paid', 'cancelled')
-- In-progress local states such as draft/sent never become remote authority.

begin;

create table if not exists public.transactions (
  uuid text primary key,
  shift_local_id bigint not null,
  user_local_id bigint not null,
  table_number integer null,
  status text not null check (status in ('open', 'paid', 'cancelled')),
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
  inserted_at timestamptz not null default timezone('utc', now()),
  last_received_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.transaction_lines (
  uuid text primary key,
  transaction_uuid text not null
    references public.transactions (uuid) on delete restrict,
  product_local_id bigint not null,
  product_name text not null,
  unit_price_minor integer not null check (unit_price_minor >= 0),
  quantity integer not null check (quantity > 0),
  line_total_minor integer not null check (line_total_minor >= 0),
  inserted_at timestamptz not null default timezone('utc', now()),
  last_received_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.order_modifiers (
  uuid text primary key,
  transaction_line_uuid text not null
    references public.transaction_lines (uuid) on delete restrict,
  action text not null check (action in ('remove', 'add')),
  item_name text not null,
  extra_price_minor integer not null default 0 check (extra_price_minor >= 0),
  inserted_at timestamptz not null default timezone('utc', now()),
  last_received_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.payments (
  uuid text primary key,
  transaction_uuid text not null unique
    references public.transactions (uuid) on delete restrict,
  method text not null check (method in ('cash', 'card')),
  amount_minor integer not null check (amount_minor > 0),
  paid_at timestamptz not null,
  inserted_at timestamptz not null default timezone('utc', now()),
  last_received_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_transactions_status_updated_at
  on public.transactions (status, updated_at desc);

create index if not exists idx_transactions_paid_at
  on public.transactions (paid_at desc nulls last);

create index if not exists idx_transactions_last_received_at
  on public.transactions (last_received_at desc);

create index if not exists idx_transaction_lines_transaction_uuid
  on public.transaction_lines (transaction_uuid);

create index if not exists idx_transaction_lines_last_received_at
  on public.transaction_lines (last_received_at desc);

create index if not exists idx_order_modifiers_transaction_line_uuid
  on public.order_modifiers (transaction_line_uuid);

create index if not exists idx_order_modifiers_last_received_at
  on public.order_modifiers (last_received_at desc);

create index if not exists idx_payments_transaction_uuid
  on public.payments (transaction_uuid);

create index if not exists idx_payments_paid_at
  on public.payments (paid_at desc);

create index if not exists idx_payments_last_received_at
  on public.payments (last_received_at desc);

create or replace function public.set_epos_last_received_at()
returns trigger
language plpgsql
as $$
begin
  new.last_received_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists trg_transactions_set_last_received_at on public.transactions;
create trigger trg_transactions_set_last_received_at
before update on public.transactions
for each row
execute function public.set_epos_last_received_at();

drop trigger if exists trg_transaction_lines_set_last_received_at on public.transaction_lines;
create trigger trg_transaction_lines_set_last_received_at
before update on public.transaction_lines
for each row
execute function public.set_epos_last_received_at();

drop trigger if exists trg_order_modifiers_set_last_received_at on public.order_modifiers;
create trigger trg_order_modifiers_set_last_received_at
before update on public.order_modifiers
for each row
execute function public.set_epos_last_received_at();

drop trigger if exists trg_payments_set_last_received_at on public.payments;
create trigger trg_payments_set_last_received_at
before update on public.payments
for each row
execute function public.set_epos_last_received_at();

alter table public.transactions enable row level security;
alter table public.transaction_lines enable row level security;
alter table public.order_modifiers enable row level security;
alter table public.payments enable row level security;

comment on table public.transactions is
  'Remote mirror of local transaction snapshots. Drift remains authoritative.';
comment on table public.transaction_lines is
  'Remote mirror of local transaction line snapshots. Not a write authority.';
comment on table public.order_modifiers is
  'Remote mirror of local order modifier snapshots. Not a write authority.';
comment on table public.payments is
  'Remote mirror of local payment snapshots. Not a write authority.';

-- Security note:
-- Preferred architecture is a trusted server-side boundary such as the
-- `mirror-transaction-graph` Edge Function. The temporary direct client writer
-- exists only for phased rollout / controlled environments.
-- TODO(next hardening):
-- - remove the temporary direct client writer from the app entirely
-- - keep mirror writes on the trusted server-side boundary only
-- RLS is enabled below with no anon/authenticated policies on purpose.
-- Service-role execution inside Edge Functions remains the only supported
-- mirror write path under this hardened SQL.
grant usage on schema public to anon, authenticated;
revoke all on public.transactions from anon, authenticated;
revoke all on public.transaction_lines from anon, authenticated;
revoke all on public.order_modifiers from anon, authenticated;
revoke all on public.payments from anon, authenticated;

commit;
