begin;

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

comment on column public.transaction_lines.pricing_mode is
  'Mirrored local line pricing mode from Drift snapshots.';
comment on column public.transaction_lines.removal_discount_total_minor is
  'Mirrored local removal discount total for semantic breakfast/set lines.';

commit;
