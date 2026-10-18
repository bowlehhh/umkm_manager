-- Data untuk fitur generik yang dibuat dari prompt AI. AI hanya menentukan
-- nama/tujuan modul; semua catatan tetap berupa data biasa yang terlindungi RLS.
create table public.custom_feature_records (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  feature_key text not null check (feature_key = 'custom_records'),
  title text not null check (char_length(trim(title)) > 0),
  amount bigint check (amount is null or amount >= 0),
  notes text,
  record_date date not null default current_date,
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index custom_feature_records_business_date_idx
  on public.custom_feature_records (business_id, record_date desc, created_at desc);

create trigger custom_feature_records_updated_at
  before update on public.custom_feature_records
  for each row execute function public.set_updated_at();

alter table public.custom_feature_records enable row level security;

create policy "member reads custom feature records"
  on public.custom_feature_records for select
  using (public.is_business_member(business_id));

create policy "staff manages custom feature records"
  on public.custom_feature_records for all
  using (public.has_business_role(business_id, array['OWNER','ADMIN','CASHIER']::public.member_role[]))
  with check (public.has_business_role(business_id, array['OWNER','ADMIN','CASHIER']::public.member_role[]));
