begin;

alter table if exists public.order_modifiers
  add column if not exists quantity integer,
  add column if not exists item_product_id bigint,
  add column if not exists charge_reason text,
  add column if not exists unit_price_minor integer,
  add column if not exists price_effect_minor integer,
  add column if not exists sort_key integer;

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

comment on column public.order_modifiers.quantity is
  'Mirrored local modifier quantity from Drift semantic snapshots.';
comment on column public.order_modifiers.item_product_id is
  'Optional mirrored product reference for semantic modifier rows.';
comment on column public.order_modifiers.charge_reason is
  'Semantic pricing reason mirrored from local order modifier snapshots.';
comment on column public.order_modifiers.unit_price_minor is
  'Unit price context mirrored from local order modifier snapshots.';
comment on column public.order_modifiers.price_effect_minor is
  'Signed persisted price effect mirrored from local semantic modifier snapshots.';
comment on column public.order_modifiers.sort_key is
  'Deterministic modifier sort key mirrored from local semantic snapshots.';

commit;
