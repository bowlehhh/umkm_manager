-- Konfigurasi capability bersifat data, bukan kode. Hanya owner/admin dapat mengubahnya.
create table public.business_configurations (
  business_id uuid primary key references public.businesses(id) on delete cascade,
  configuration jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(configuration) = 'object')
);

create trigger business_configurations_updated_at
before update on public.business_configurations
for each row execute function public.set_updated_at();

alter table public.business_configurations enable row level security;

create policy "member reads business configuration"
on public.business_configurations for select
using (public.is_business_member(business_id));

create policy "owner admin manages business configuration"
on public.business_configurations for all
using (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[]))
with check (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[]));
