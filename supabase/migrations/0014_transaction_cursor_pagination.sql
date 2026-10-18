-- Keep transaction history pagination stable when multiple records share a
-- timestamp; existing RLS remains unchanged.
create index if not exists transactions_business_created_id_idx
  on public.transactions (business_id, created_at desc, id desc);
