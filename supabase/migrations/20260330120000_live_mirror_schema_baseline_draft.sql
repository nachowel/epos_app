-- Draft only. Do not apply blindly.
--
-- Purpose:
-- Align an older repo-created mirror schema to the current live mirror schema
-- baseline defined in ../phase1_sales_sync_foundation.sql.
--
-- This is not a security migration.
-- This does not close direct writes.
-- Review current remote data, constraints, and policies before any manual apply.

begin;

-- Drop FK constraints before UUID type conversion.
alter table if exists public.transaction_lines
  drop constraint if exists transaction_lines_transaction_uuid_fkey;
alter table if exists public.order_modifiers
  drop constraint if exists order_modifiers_transaction_line_uuid_fkey;
alter table if exists public.payments
  drop constraint if exists payments_transaction_uuid_fkey;

-- Convert text identifiers to UUID.
-- These casts require every existing value to already be a valid UUID string.
alter table if exists public.transactions
  alter column uuid type uuid using uuid::uuid;
alter table if exists public.transaction_lines
  alter column uuid type uuid using uuid::uuid,
  alter column transaction_uuid type uuid using transaction_uuid::uuid;
alter table if exists public.order_modifiers
  alter column uuid type uuid using uuid::uuid,
  alter column transaction_line_uuid type uuid using transaction_line_uuid::uuid;
alter table if exists public.payments
  alter column uuid type uuid using uuid::uuid,
  alter column transaction_uuid type uuid using transaction_uuid::uuid;

-- Replace legacy receive timestamps with the live synced_at marker.
alter table if exists public.transactions
  add column if not exists synced_at timestamptz;

update public.transactions
set synced_at = coalesce(
  synced_at,
  last_received_at,
  inserted_at,
  timezone('utc', now())
)
where synced_at is null;

alter table if exists public.transactions
  alter column synced_at set default timezone('utc', now()),
  alter column synced_at set not null;

-- Live mirror accepts finalized statuses only.
alter table if exists public.transactions
  drop constraint if exists transactions_status_check;
alter table if exists public.transactions
  add constraint transactions_status_check
    check (status in ('paid', 'cancelled'));

-- Remove stale trigger/function/index artifacts from the old baseline.
drop trigger if exists trg_transactions_set_last_received_at on public.transactions;
drop trigger if exists trg_transaction_lines_set_last_received_at on public.transaction_lines;
drop trigger if exists trg_order_modifiers_set_last_received_at on public.order_modifiers;
drop trigger if exists trg_payments_set_last_received_at on public.payments;
drop function if exists public.set_epos_last_received_at();

drop index if exists public.idx_transactions_last_received_at;
drop index if exists public.idx_transaction_lines_last_received_at;
drop index if exists public.idx_order_modifiers_last_received_at;
drop index if exists public.idx_payments_last_received_at;

-- Remove legacy columns that are not present in the live physical schema.
alter table if exists public.transactions
  drop column if exists inserted_at,
  drop column if exists last_received_at;
alter table if exists public.transaction_lines
  drop column if exists inserted_at,
  drop column if exists last_received_at;
alter table if exists public.order_modifiers
  drop column if exists inserted_at,
  drop column if exists last_received_at;
alter table if exists public.payments
  drop column if exists inserted_at,
  drop column if exists last_received_at;

-- Transaction line semantic snapshot fields are part of the live payload.
alter table if exists public.transaction_lines
  add column if not exists pricing_mode text,
  add column if not exists removal_discount_total_minor integer;

update public.transaction_lines
set pricing_mode = coalesce(pricing_mode, 'standard')
where pricing_mode is null;

update public.transaction_lines
set removal_discount_total_minor = coalesce(removal_discount_total_minor, 0)
where removal_discount_total_minor is null;

alter table if exists public.transaction_lines
  alter column pricing_mode set default 'standard',
  alter column pricing_mode set not null,
  alter column removal_discount_total_minor set default 0,
  alter column removal_discount_total_minor set not null;

alter table if exists public.transaction_lines
  drop constraint if exists transaction_lines_pricing_mode_check;
alter table if exists public.transaction_lines
  add constraint transaction_lines_pricing_mode_check
    check (pricing_mode in ('standard', 'set'));

alter table if exists public.transaction_lines
  drop constraint if exists transaction_lines_removal_discount_total_minor_check;
alter table if exists public.transaction_lines
  add constraint transaction_lines_removal_discount_total_minor_check
    check (removal_discount_total_minor >= 0);

-- Burger structured modifier context is additive and nullable.
alter table if exists public.order_modifiers
  add column if not exists quantity integer,
  add column if not exists item_product_id bigint,
  add column if not exists charge_reason text,
  add column if not exists unit_price_minor integer,
  add column if not exists price_effect_minor integer,
  add column if not exists sort_key integer,
  add column if not exists price_behavior text,
  add column if not exists ui_section text;

update public.order_modifiers
set quantity = coalesce(quantity, 1)
where quantity is null;

update public.order_modifiers
set unit_price_minor = coalesce(unit_price_minor, 0)
where unit_price_minor is null;

update public.order_modifiers
set price_effect_minor = coalesce(price_effect_minor, 0)
where price_effect_minor is null;

update public.order_modifiers
set sort_key = coalesce(sort_key, 0)
where sort_key is null;

alter table if exists public.order_modifiers
  alter column quantity set default 1,
  alter column quantity set not null,
  alter column unit_price_minor set default 0,
  alter column unit_price_minor set not null,
  alter column price_effect_minor set default 0,
  alter column price_effect_minor set not null,
  alter column sort_key set default 0,
  alter column sort_key set not null;

alter table if exists public.order_modifiers
  drop constraint if exists order_modifiers_action_check;
alter table if exists public.order_modifiers
  add constraint order_modifiers_action_check
    check (action in ('remove', 'add', 'choice'));

alter table if exists public.order_modifiers
  drop constraint if exists order_modifiers_quantity_check;
alter table if exists public.order_modifiers
  add constraint order_modifiers_quantity_check
    check (quantity > 0);

alter table if exists public.order_modifiers
  drop constraint if exists order_modifiers_unit_price_minor_check;
alter table if exists public.order_modifiers
  add constraint order_modifiers_unit_price_minor_check
    check (unit_price_minor >= 0);

alter table if exists public.order_modifiers
  drop constraint if exists order_modifiers_price_behavior_check;
alter table if exists public.order_modifiers
  add constraint order_modifiers_price_behavior_check
    check (price_behavior is null or price_behavior in ('free', 'paid'));

alter table if exists public.order_modifiers
  drop constraint if exists order_modifiers_ui_section_check;
alter table if exists public.order_modifiers
  add constraint order_modifiers_ui_section_check
    check (
      ui_section is null or
      ui_section in ('toppings', 'sauces', 'add_ins')
    );

alter table if exists public.order_modifiers
  drop constraint if exists order_modifiers_charge_reason_check;
alter table if exists public.order_modifiers
  add constraint order_modifiers_charge_reason_check
    check (
      charge_reason is null or
      charge_reason in (
        'extra_add',
        'free_swap',
        'paid_swap',
        'included_choice',
        'removal_discount',
        'combo_discount'
      )
    );

alter table if exists public.order_modifiers
  drop constraint if exists order_modifiers_choice_charge_reason_check;
alter table if exists public.order_modifiers
  add constraint order_modifiers_choice_charge_reason_check
    check (action != 'choice' or charge_reason = 'included_choice');

-- Recreate FK constraints after type conversion.
alter table if exists public.transaction_lines
  add constraint transaction_lines_transaction_uuid_fkey
    foreign key (transaction_uuid)
    references public.transactions (uuid)
    on delete restrict;
alter table if exists public.order_modifiers
  add constraint order_modifiers_transaction_line_uuid_fkey
    foreign key (transaction_line_uuid)
    references public.transaction_lines (uuid)
    on delete restrict;
alter table if exists public.payments
  add constraint payments_transaction_uuid_fkey
    foreign key (transaction_uuid)
    references public.transactions (uuid)
    on delete restrict;

-- Recreate the live-style transaction trigger.
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

drop trigger if exists trg_transactions_sync_guardrails on public.transactions;
create trigger trg_transactions_sync_guardrails
before insert or update on public.transactions
for each row
execute function public.apply_epos_transaction_sync_guardrails();

-- Recreate indexes that are part of the current live baseline.
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

commit;
