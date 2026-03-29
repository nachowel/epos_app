-- Phase 1 - EPOS Supabase sales sync foundation
-- Local Drift/SQLite stays primary. These tables are a remote sync sink only.
-- UUID text columns are the cross-system identifiers for upsert.

begin;

create table if not exists public.transactions (
  uuid text primary key,
  shift_local_id bigint not null,
  user_local_id bigint not null,
  table_number integer null,
  status text not null check (status in ('draft', 'sent', 'paid', 'cancelled')),
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
  transaction_uuid text not null references public.transactions (uuid) on delete restrict,
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
  transaction_line_uuid text not null references public.transaction_lines (uuid) on delete restrict,
  action text not null check (action in ('remove', 'add')),
  item_name text not null,
  extra_price_minor integer not null default 0 check (extra_price_minor >= 0),
  inserted_at timestamptz not null default timezone('utc', now()),
  last_received_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.payments (
  uuid text primary key,
  transaction_uuid text not null unique references public.transactions (uuid) on delete restrict,
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

create index if not exists idx_transaction_lines_transaction_uuid
  on public.transaction_lines (transaction_uuid);

create index if not exists idx_order_modifiers_transaction_line_uuid
  on public.order_modifiers (transaction_line_uuid);

create index if not exists idx_payments_transaction_uuid
  on public.payments (transaction_uuid);

commit;
