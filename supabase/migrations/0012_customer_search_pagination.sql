-- Customer lists use a stable created_at + id cursor. search_text keeps the
-- client query small while the trigram index avoids scanning a large business.
create extension if not exists pg_trgm;

alter table public.customers
  add column if not exists search_text text generated always as (
    lower(name || ' ' || coalesce(phone, '') || ' ' || coalesce(email, ''))
  ) stored;

create index if not exists customers_business_active_created_id_idx
  on public.customers (business_id, is_active, created_at desc, id desc);

create index if not exists customers_search_text_trgm_idx
  on public.customers using gin (search_text gin_trgm_ops)
  where is_active;
