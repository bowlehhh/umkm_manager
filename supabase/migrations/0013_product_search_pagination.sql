-- Product list and cashier lookup both use a stable cursor and server-side
-- search, avoiding full product catalog transfers to Flutter.
create extension if not exists pg_trgm;

alter table public.products
  add column if not exists search_text text generated always as (
    lower(name || ' ' || sku || ' ' || coalesce(barcode, ''))
  ) stored;

create index if not exists products_business_active_created_id_idx
  on public.products (business_id, is_active, created_at desc, id desc);

create index if not exists products_search_text_trgm_idx
  on public.products using gin (search_text gin_trgm_ops)
  where is_active;
