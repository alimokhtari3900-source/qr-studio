create extension if not exists pgcrypto with schema extensions;
create table if not exists public.admin_users(user_id uuid primary key references auth.users(id) on delete cascade);
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.admin_users where user_id=auth.uid()); $$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;
create table if not exists public.products(
 id uuid primary key default gen_random_uuid(), name text not null, code text unique, brand text, category text, description text,
 images jsonb not null default '[]', attachments jsonb not null default '[]', specifications jsonb not null default '{}',
 custom_fields jsonb not null default '{}', translations jsonb not null default '{}', contact jsonb not null default '{}',
 is_published boolean not null default false, is_active boolean not null default true, scan_count bigint not null default 0,
 created_by uuid references auth.users(id) default auth.uid(), created_at timestamptz default now(), updated_at timestamptz default now()
);
alter table public.admin_users enable row level security;
alter table public.products enable row level security;
drop policy if exists "admin read admins" on public.admin_users;
create policy "admin read admins" on public.admin_users for select to authenticated using (public.is_admin());
drop policy if exists "public published read" on public.products;
create policy "public published read" on public.products for select to anon, authenticated using (is_active and is_published);
drop policy if exists "admin products all" on public.products;
create policy "admin products all" on public.products for all to authenticated using (public.is_admin()) with check (public.is_admin());
revoke all on public.admin_users from anon,authenticated;
grant select on public.admin_users to authenticated;
revoke all on public.products from anon,authenticated;
grant select,insert,update,delete on public.products to authenticated;
