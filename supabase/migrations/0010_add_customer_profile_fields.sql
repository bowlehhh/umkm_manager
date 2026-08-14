-- Customer capability: keep profile data scoped to its business and archive
-- customers instead of deleting records that may be referenced by transactions.
alter table public.customers
  add column if not exists email text,
  add column if not exists is_active boolean not null default true;

create index if not exists customers_business_active_name_idx
  on public.customers (business_id, is_active, name);
