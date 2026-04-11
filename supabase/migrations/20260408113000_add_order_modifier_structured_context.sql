begin;

alter table if exists public.order_modifiers
  add column if not exists price_behavior text,
  add column if not exists ui_section text;

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

comment on column public.order_modifiers.price_behavior is
  'Nullable structured burger modifier pricing behavior mirrored from local Drift snapshots.';
comment on column public.order_modifiers.ui_section is
  'Nullable structured burger modifier UI grouping mirrored from local Drift snapshots.';

commit;
