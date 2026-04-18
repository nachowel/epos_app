-- Mirror schema drift fix:
-- transactions payload already emits local discount snapshot fields.
-- Deploy this migration before any app build that relies on those columns.

begin;

alter table if exists public.transactions
  add column if not exists discount_type text,
  add column if not exists discount_value_minor integer,
  add column if not exists discount_amount_minor integer,
  add column if not exists discount_reason text,
  add column if not exists discount_applied_by_local_id bigint;

update public.transactions
set discount_value_minor = coalesce(discount_value_minor, 0)
where discount_value_minor is null;

update public.transactions
set discount_amount_minor = coalesce(discount_amount_minor, 0)
where discount_amount_minor is null;

alter table if exists public.transactions
  alter column discount_value_minor set default 0,
  alter column discount_value_minor set not null,
  alter column discount_amount_minor set default 0,
  alter column discount_amount_minor set not null;

alter table if exists public.transactions
  drop constraint if exists transactions_discount_type_check;
alter table if exists public.transactions
  add constraint transactions_discount_type_check
    check (
      discount_type is null or
      discount_type in ('amount', 'percent')
    );

alter table if exists public.transactions
  drop constraint if exists transactions_discount_value_minor_check;
alter table if exists public.transactions
  add constraint transactions_discount_value_minor_check
    check (discount_value_minor >= 0);

alter table if exists public.transactions
  drop constraint if exists transactions_discount_amount_minor_check;
alter table if exists public.transactions
  add constraint transactions_discount_amount_minor_check
    check (
      discount_amount_minor >= 0 and
      discount_amount_minor <= subtotal_minor + modifier_total_minor
    );

alter table if exists public.transactions
  drop constraint if exists transactions_discount_empty_payload_check;
alter table if exists public.transactions
  add constraint transactions_discount_empty_payload_check
    check (
      discount_type is not null or
      (
        discount_value_minor = 0 and
        discount_amount_minor = 0 and
        discount_reason is null and
        discount_applied_by_local_id is null
      )
    );

alter table if exists public.transactions
  drop constraint if exists transactions_discount_percent_value_check;
alter table if exists public.transactions
  add constraint transactions_discount_percent_value_check
    check (discount_type != 'percent' or discount_value_minor <= 100);

commit;
