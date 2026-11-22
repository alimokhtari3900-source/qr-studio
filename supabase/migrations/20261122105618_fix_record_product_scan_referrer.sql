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
        coalesce(p_referrer_domain, ''),
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
