-- UMKM Manager: fondasi multi-bisnis, otorisasi, dan data keuangan berbasis Rupiah.
-- Jalankan melalui Supabase CLI: supabase db push

create extension if not exists pgcrypto;

create type public.member_role as enum ('OWNER', 'ADMIN', 'CASHIER');
create type public.payment_method as enum ('CASH', 'TRANSFER', 'QRIS', 'DEBT');
create type public.payment_status as enum ('PAID', 'PARTIAL', 'UNPAID');
create type public.debt_status as enum ('UNPAID', 'PARTIAL', 'PAID');
create type public.discount_type as enum ('PERCENTAGE', 'FIXED');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  name text not null check (char_length(trim(name)) > 0),
  address text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.member_role not null default 'CASHIER',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (business_id, user_id)
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null check (char_length(trim(name)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, name)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category_id uuid references public.categories(id) on delete set null,
  name text not null check (char_length(trim(name)) > 0),
  sku text not null,
  barcode text,
  purchase_price bigint not null check (purchase_price >= 0),
  selling_price bigint not null check (selling_price >= 0),
  stock integer not null default 0 check (stock >= 0),
  minimum_stock integer not null default 0 check (minimum_stock >= 0),
  unit text not null default 'pcs',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, sku),
  unique nulls not distinct (business_id, barcode)
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null check (char_length(trim(name)) > 0),
  phone text,
  address text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.discounts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  type public.discount_type not null,
  value numeric(12, 2) not null check (value >= 0),
  minimum_purchase bigint not null default 0 check (minimum_purchase >= 0),
  start_date date not null default current_date,
  end_date date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_date is null or end_date >= start_date),
  check (type <> 'PERCENTAGE' or value <= 100)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  invoice_number text not null,
  cashier_id uuid not null references public.profiles(id),
  customer_id uuid references public.customers(id) on delete set null,
  subtotal bigint not null check (subtotal >= 0),
  discount_amount bigint not null default 0 check (discount_amount >= 0),
  total bigint not null check (total >= 0),
  amount_paid bigint not null default 0 check (amount_paid >= 0),
  change_amount bigint not null default 0 check (change_amount >= 0),
  payment_method public.payment_method not null,
  payment_status public.payment_status not null,
  created_at timestamptz not null default now(),
  check (discount_amount <= subtotal),
  check (total = subtotal - discount_amount),
  unique (business_id, invoice_number)
);

create table public.transaction_items (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict,
  quantity integer not null check (quantity > 0),
  purchase_price_snapshot bigint not null check (purchase_price_snapshot >= 0),
  selling_price_snapshot bigint not null check (selling_price_snapshot >= 0),
  discount_amount bigint not null default 0 check (discount_amount >= 0),
  subtotal bigint not null check (subtotal >= 0)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  category text not null,
  description text not null,
  amount bigint not null check (amount > 0),
  expense_date date not null default current_date,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.debts (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete restrict,
  transaction_id uuid not null unique references public.transactions(id) on delete restrict,
  original_amount bigint not null check (original_amount > 0),
  paid_amount bigint not null default 0 check (paid_amount >= 0),
  remaining_amount bigint not null check (remaining_amount >= 0),
  status public.debt_status not null default 'UNPAID',
  due_date date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (paid_amount <= original_amount),
  check (remaining_amount = original_amount - paid_amount)
);

create table public.debt_payments (
  id uuid primary key default gen_random_uuid(),
  debt_id uuid not null references public.debts(id) on delete cascade,
  amount bigint not null check (amount > 0),
  payment_date date not null default current_date,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now()
);

create index business_members_user_business_idx on public.business_members (user_id, business_id) where is_active;
create index categories_business_idx on public.categories (business_id);
create index products_business_active_idx on public.products (business_id, is_active);
create index customers_business_idx on public.customers (business_id);
create index transactions_business_created_idx on public.transactions (business_id, created_at desc);
create index transactions_customer_idx on public.transactions (customer_id, created_at desc);
create index transaction_items_product_idx on public.transaction_items (product_id);
create index expenses_business_date_idx on public.expenses (business_id, expense_date desc);
create index debts_business_customer_idx on public.debts (business_id, customer_id) where status <> 'PAID';
create index debt_payments_debt_idx on public.debt_payments (debt_id, payment_date desc);

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger businesses_updated_at before update on public.businesses for each row execute function public.set_updated_at();
create trigger categories_updated_at before update on public.categories for each row execute function public.set_updated_at();
create trigger products_updated_at before update on public.products for each row execute function public.set_updated_at();
create trigger customers_updated_at before update on public.customers for each row execute function public.set_updated_at();
create trigger discounts_updated_at before update on public.discounts for each row execute function public.set_updated_at();
create trigger expenses_updated_at before update on public.expenses for each row execute function public.set_updated_at();
create trigger debts_updated_at before update on public.debts for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

create or replace function public.is_business_member(target_business_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.business_members
    where business_id = target_business_id and user_id = auth.uid() and is_active
  );
$$;

create or replace function public.has_business_role(target_business_id uuid, allowed_roles public.member_role[])
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.business_members
    where business_id = target_business_id
      and user_id = auth.uid()
      and is_active
      and role = any(allowed_roles)
  );
$$;

create or replace function public.create_business_with_owner(
  business_name text,
  business_address text default null,
  business_phone text default null
)
returns public.businesses language plpgsql security definer set search_path = public as $$
declare
  created_business public.businesses;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if char_length(trim(business_name)) = 0 then raise exception 'Nama bisnis wajib diisi'; end if;

  insert into public.profiles (id) values (auth.uid()) on conflict (id) do nothing;
  insert into public.businesses (owner_id, name, address, phone)
  values (auth.uid(), trim(business_name), nullif(trim(business_address), ''), nullif(trim(business_phone), ''))
  returning * into created_business;
  insert into public.business_members (business_id, user_id, role)
  values (created_business.id, auth.uid(), 'OWNER');
  return created_business;
end;
$$;

alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.discounts enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_items enable row level security;
alter table public.expenses enable row level security;
alter table public.debts enable row level security;
alter table public.debt_payments enable row level security;

create policy "profiles own data" on public.profiles for all using (id = auth.uid()) with check (id = auth.uid());
create policy "business member reads business" on public.businesses for select using (public.is_business_member(id));
create policy "owner creates business" on public.businesses for insert with check (owner_id = auth.uid());
create policy "owner updates business" on public.businesses for update using (public.has_business_role(id, array['OWNER']::public.member_role[]));
create policy "member reads members" on public.business_members for select using (public.is_business_member(business_id));
create policy "owner manages members" on public.business_members for all using (public.has_business_role(business_id, array['OWNER']::public.member_role[])) with check (public.has_business_role(business_id, array['OWNER']::public.member_role[]));

create policy "member reads categories" on public.categories for select using (public.is_business_member(business_id));
create policy "owner admin manages categories" on public.categories for all using (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[])) with check (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[]));
create policy "member reads products" on public.products for select using (public.is_business_member(business_id));
create policy "owner admin manages products" on public.products for all using (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[])) with check (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[]));
create policy "member reads customers" on public.customers for select using (public.is_business_member(business_id));
create policy "staff manages customers" on public.customers for all using (public.has_business_role(business_id, array['OWNER','ADMIN','CASHIER']::public.member_role[])) with check (public.has_business_role(business_id, array['OWNER','ADMIN','CASHIER']::public.member_role[]));
create policy "member reads discounts" on public.discounts for select using (public.is_business_member(business_id));
create policy "owner admin manages discounts" on public.discounts for all using (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[])) with check (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[]));
create policy "member reads transactions" on public.transactions for select using (public.is_business_member(business_id));
create policy "staff inserts transactions" on public.transactions for insert with check (cashier_id = auth.uid() and public.has_business_role(business_id, array['OWNER','ADMIN','CASHIER']::public.member_role[]));
create policy "member reads transaction items" on public.transaction_items for select using (exists (select 1 from public.transactions t where t.id = transaction_id and public.is_business_member(t.business_id)));
create policy "member reads expenses" on public.expenses for select using (public.is_business_member(business_id));
create policy "owner admin manages expenses" on public.expenses for all using (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[])) with check (public.has_business_role(business_id, array['OWNER','ADMIN']::public.member_role[]));
create policy "member reads debts" on public.debts for select using (public.is_business_member(business_id));
create policy "member reads debt payments" on public.debt_payments for select using (exists (select 1 from public.debts d where d.id = debt_id and public.is_business_member(d.business_id)));

grant execute on function public.create_business_with_owner(text, text, text) to authenticated;
