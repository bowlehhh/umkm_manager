-- Onboarding harus atomik: usaha dan konfigurasi dibuat bersama agar pengguna
-- tidak tertahan pada halaman rekomendasi atau membuat usaha duplikat saat retry.
create or replace function public.create_business_with_owner_and_configuration(
  business_name text,
  business_configuration jsonb,
  business_address text default null,
  business_phone text default null,
  business_type text default 'RETAIL'
)
returns public.businesses
language plpgsql
security definer
set search_path = public
as $$
declare
  created_business public.businesses;
  normalized_type text := upper(trim(coalesce(business_type, 'RETAIL')));
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  if char_length(trim(business_name)) = 0 then
    raise exception 'Nama bisnis wajib diisi';
  end if;
  if business_configuration is null or jsonb_typeof(business_configuration) <> 'object' then
    raise exception 'Konfigurasi bisnis tidak valid';
  end if;
  if normalized_type not in ('RETAIL', 'CULINARY', 'SERVICE', 'FASHION', 'OTHER') then
    raise exception 'Jenis usaha tidak valid';
  end if;

  insert into public.profiles (id)
  values (auth.uid())
  on conflict (id) do nothing;

  insert into public.businesses (owner_id, name, address, phone, business_type)
  values (
    auth.uid(),
    trim(business_name),
    nullif(trim(business_address), ''),
    nullif(trim(business_phone), ''),
    normalized_type
  )
  returning * into created_business;

  insert into public.business_members (business_id, user_id, role, is_active)
  values (created_business.id, auth.uid(), 'OWNER', false);

  insert into public.business_configurations (business_id, configuration)
  values (created_business.id, business_configuration);

  perform public.set_active_business(created_business.id);
  return created_business;
end;
$$;

grant execute on function public.create_business_with_owner_and_configuration(
  text,
  jsonb,
  text,
  text,
  text
) to authenticated;
