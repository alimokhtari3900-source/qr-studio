create table if not exists public.product_scan_events (
  id bigint generated always as identity primary key,
  product_id uuid not null references public.products(id) on delete cascade,
  scanned_at timestamptz not null default now(),
  referrer_domain text,
  constraint product_scan_events_referrer_domain_length
    check (referrer_domain is null or char_length(referrer_domain) <= 120)
);

create index if not exists product_scan_events_product_scanned_at_idx
  on public.product_scan_events (product_id, scanned_at desc);

create index if not exists product_scan_events_scanned_at_idx
  on public.product_scan_events (scanned_at desc);

alter table public.product_scan_events enable row level security;

revoke all on public.product_scan_events from public, anon, authenticated;
grant select on public.product_scan_events to authenticated;
grant insert, select on public.product_scan_events to service_role;

drop policy if exists "admin read product scan events" on public.product_scan_events;
create policy "admin read product scan events"
  on public.product_scan_events
  for select
  to authenticated
  using ((select public.is_admin()));

create or replace function public.record_product_scan(
  p_product_id uuid,
  p_referrer_domain text default null
)
returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_product_id uuid;
  v_domain text;
begin
  update public.products
     set scan_count = scan_count + 1,
         updated_at = pg_catalog.now()
   where id = p_product_id
     and is_active = true
     and is_published = true
  returning id into v_product_id;

  if not found then
    return false;
  end if;

  v_domain := nullif(
    pg_catalog.left(
      pg_catalog.regexp_replace(
        pg_catalog.coalesce(p_referrer_domain, ''),
        '[^A-Za-z0-9.-]',
        '',
        'g'
      ),
      120
    ),
    ''
  );

  insert into public.product_scan_events (product_id, referrer_domain)
  values (v_product_id, v_domain);

  return true;
end;
$$;

revoke all on function public.record_product_scan(uuid, text) from public, anon, authenticated;
grant execute on function public.record_product_scan(uuid, text) to service_role;
