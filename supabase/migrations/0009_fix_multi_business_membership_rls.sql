-- Membership adalah relasi many-to-many. Status usaha aktif hanya preferensi
-- tampilan per pengguna, bukan syarat otorisasi untuk membaca membership lain.
-- Dengan ini pemilik/admin/kasir dapat melihat seluruh usaha yang memang
-- menjadi membership-nya, lalu aplikasi menentukan satu usaha aktif.

create or replace function public.is_business_member(target_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members
    where business_id = target_business_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.has_business_role(
  target_business_id uuid,
  allowed_roles public.member_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.business_members
    where business_id = target_business_id
      and user_id = auth.uid()
      and role = any(allowed_roles)
  );
$$;
