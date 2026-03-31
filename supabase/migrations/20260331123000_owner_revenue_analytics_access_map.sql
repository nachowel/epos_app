begin;

create table if not exists public.analytics_access_map (
  supabase_auth_id uuid primary key references auth.users(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.analytics_access_map enable row level security;

revoke all privileges on public.analytics_access_map from anon, authenticated;
grant select on public.analytics_access_map to service_role;

comment on table public.analytics_access_map is
  'Explicit allow-list of Supabase Auth users who may access owner revenue analytics. Rows are admin-authorized analytics access only.';

commit;
