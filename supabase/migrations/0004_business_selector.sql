-- Satu pengguna dapat terhubung ke beberapa usaha, tetapi hanya satu yang
-- aktif pada satu waktu. Pilihan ini menentukan data yang tampil di aplikasi.

with ranked_members as (
  select
    id,
    row_number() over (
      partition by user_id
      order by created_at desc, id desc
    ) as position
  from public.business_members
  where is_active
)
update public.business_members
set is_active = false
where id in (
  select id from ranked_members where position > 1
);

create unique index if not exists business_members_one_active_per_user_idx
  on public.business_members (user_id)
  where is_active;

create or replace function public.set_active_business(target_business_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.business_members
    where business_id = target_business_id
      and user_id = auth.uid()
  ) then
    raise exception 'Anda tidak memiliki akses ke usaha ini';
  end if;

  update public.business_members
  set is_active = false
  where user_id = auth.uid()
    and is_active;

  update public.business_members
  set is_active = true
  where business_id = target_business_id
    and user_id = auth.uid();
end;
$$;

-- Usaha baru langsung menjadi usaha aktif, sehingga setelah dibuat pengguna
-- dapat langsung melanjutkan ke dashboard usaha tersebut.
create or replace function public.create_business_with_owner(
  business_name text,
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
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if char_length(trim(business_name)) = 0 then
    raise exception 'Nama usaha wajib diisi';
  end if;
  if normalized_type not in ('RETAIL', 'CULINARY', 'SERVICE', 'FASHION', 'OTHER') then
    raise exception 'Jenis usaha tidak valid';
  end if;

  insert into public.profiles (id) values (auth.uid()) on conflict (id) do nothing;
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

  perform public.set_active_business(created_business.id);
  return created_business;
end;
$$;

grant execute on function public.set_active_business(uuid) to authenticated;
grant execute on function public.create_business_with_owner(text, text, text, text)
  to authenticated;
