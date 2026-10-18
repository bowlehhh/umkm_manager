-- Core commerce integrity: nullable barcode, idempotent checkout, immutable
-- line snapshots, stock ledger, and period reports. This migration is
-- additive and backfills existing data without rewriting financial history.

-- PostgreSQL NULL values must not collide: many products may omit a barcode,
-- while a non-empty barcode remains unique inside one business.
alter table public.products drop constraint if exists products_business_id_barcode_key;
drop index if exists public.products_business_barcode_key;
create unique index if not exists products_business_barcode_unique
  on public.products (business_id, barcode)
  where barcode is not null and btrim(barcode) <> '';

alter table public.transactions
  add column if not exists request_id uuid,
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references public.profiles(id),
  add column if not exists void_reason text;
create unique index if not exists transactions_business_request_unique
  on public.transactions (business_id, request_id) where request_id is not null;

alter table public.transaction_items
  add column if not exists product_name_snapshot text;
update public.transaction_items ti
set product_name_snapshot = p.name
from public.products p
where p.id = ti.product_id and ti.product_name_snapshot is null;
update public.transaction_items
set product_name_snapshot = 'Produk lama'
where product_name_snapshot is null;
alter table public.transaction_items
  alter column product_name_snapshot set not null;

create table if not exists public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete restrict,
  product_id uuid not null references public.products(id) on delete restrict,
  movement_type text not null check (movement_type in ('OPENING','IN','SALE','CORRECTION','REVERSAL')),
  quantity_delta integer not null check (quantity_delta <> 0 or movement_type = 'OPENING'),
  balance_after integer not null check (balance_after >= 0),
  transaction_id uuid references public.transactions(id) on delete restrict,
  reason text,
  actor_id uuid references public.profiles(id) on delete set null,
  correlation_id uuid not null,
  created_at timestamptz not null default now(),
  unique (product_id, correlation_id, movement_type)
);
create index if not exists stock_movements_business_created_idx
  on public.stock_movements (business_id, created_at desc, id desc);
alter table public.stock_movements enable row level security;
drop policy if exists "member reads stock movements" on public.stock_movements;
create policy "member reads stock movements" on public.stock_movements for select
  using (public.is_business_member(business_id));

-- Trace the pre-migration balance once. The deterministic correlation id
-- makes this backfill safe to rerun.
insert into public.stock_movements (
  business_id, product_id, movement_type, quantity_delta, balance_after,
  reason, correlation_id, created_at
)
select p.business_id, p.id, 'OPENING', p.stock, p.stock,
       case when p.stock = 0 then 'Saldo awal migrasi (0)' else 'Saldo awal migrasi' end,
       ('00000000-0000-0000-0000-' || substr(replace(p.id::text, '-', ''), 1, 12))::uuid,
       p.created_at
from public.products p
where not exists (
  select 1 from public.stock_movements sm
  where sm.product_id = p.id and sm.movement_type = 'OPENING'
);

create table if not exists public.business_audit_logs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid references public.businesses(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  resource_type text not null,
  resource_id text,
  result text not null check (result in ('SUCCESS','REJECTED','FAILED')),
  correlation_id uuid not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists business_audit_logs_business_created_idx
  on public.business_audit_logs (business_id, created_at desc, id desc);
alter table public.business_audit_logs enable row level security;
drop policy if exists "owner admin reads business audit" on public.business_audit_logs;
create policy "owner admin reads business audit" on public.business_audit_logs for select
  using (business_id is not null and public.has_business_role(
    business_id, array['OWNER','ADMIN']::public.member_role[]));

create or replace function public.guard_product_stock_write()
returns trigger language plpgsql set search_path=public as $$
begin
  if (tg_op='INSERT' and new.stock<>0) or (tg_op='UPDATE' and new.stock<>old.stock) then
    if current_setting('app.stock_write',true)<>'allowed' then
      raise exception 'Perubahan stok wajib melalui ledger' using errcode='42501';
    end if;
  end if;
  return new;
end; $$;
drop trigger if exists products_stock_ledger_guard on public.products;
create trigger products_stock_ledger_guard before insert or update of stock on public.products
for each row execute function public.guard_product_stock_write();

create or replace function public.adjust_stock(
  p_business_id uuid, p_product_id uuid, p_new_balance integer,
  p_reason text, p_request_id uuid
) returns public.products
language plpgsql security definer set search_path = public as $$
declare
  product_row public.products;
  delta integer;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  if not public.has_business_role(p_business_id, array['OWNER','ADMIN']::public.member_role[]) then
    raise exception 'Anda tidak memiliki izin mengubah stok' using errcode = '42501';
  end if;
  if p_request_id is null or p_new_balance < 0 or char_length(btrim(coalesce(p_reason, ''))) < 3 then
    raise exception 'Permintaan perubahan stok tidak valid' using errcode = '22023';
  end if;
  select * into product_row from public.products
  where id = p_product_id and business_id = p_business_id and is_active for update;
  if not found then raise exception 'Produk tidak ditemukan' using errcode = 'P0002'; end if;
  if exists (select 1 from public.stock_movements where product_id = p_product_id and correlation_id = p_request_id) then
    return product_row;
  end if;
  delta := p_new_balance - product_row.stock;
  if delta = 0 then return product_row; end if;
  perform set_config('app.stock_write','allowed',true);
  update public.products set stock = p_new_balance where id = p_product_id returning * into product_row;
  insert into public.stock_movements (
    business_id, product_id, movement_type, quantity_delta, balance_after,
    reason, actor_id, correlation_id
  ) values (
    p_business_id, p_product_id, 'CORRECTION', delta, p_new_balance,
    btrim(p_reason), auth.uid(), p_request_id
  );
  insert into public.business_audit_logs (
    business_id, actor_id, action, resource_type, resource_id, result, correlation_id,
    metadata
  ) values (
    p_business_id, auth.uid(), 'STOCK_ADJUSTED', 'product', p_product_id::text,
    'SUCCESS', p_request_id, jsonb_build_object('quantity_delta', delta, 'balance_after', p_new_balance)
  );
  return product_row;
end;
$$;

-- New overload. The old signature is revoked below so checkout cannot bypass
-- idempotency. Duplicate product lines are explicitly aggregated.
create or replace function public.process_checkout(
  p_business_id uuid, p_items jsonb, p_payment_method public.payment_method,
  p_amount_paid bigint, p_customer_id uuid, p_discount_amount bigint,
  p_request_id uuid
) returns public.transactions
language plpgsql security definer set search_path = public as $$
declare
  product_row public.products;
  line record;
  created_transaction public.transactions;
  existing_transaction public.transactions;
  subtotal_value bigint := 0;
  total_value bigint;
  change_value bigint := 0;
  status_value public.payment_status;
  invoice_value text;
  uses_inventory boolean;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  if p_request_id is null then raise exception 'Request ID wajib diisi' using errcode = '22023'; end if;
  if not public.has_business_role(p_business_id, array['OWNER','ADMIN','CASHIER']::public.member_role[]) then
    raise exception 'Anda tidak memiliki izin untuk membuat transaksi' using errcode = '42501';
  end if;
  select * into existing_transaction from public.transactions
  where business_id = p_business_id and request_id = p_request_id;
  if found then return existing_transaction; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 or jsonb_array_length(p_items) > 100 then
    raise exception 'Keranjang belanja tidak valid' using errcode = '22023';
  end if;
  if p_amount_paid < 0 or p_discount_amount < 0 then raise exception 'Nilai pembayaran atau diskon tidak valid'; end if;
  if p_payment_method = 'DEBT' and p_customer_id is null then raise exception 'Pelanggan wajib dipilih untuk transaksi bon'; end if;
  if p_customer_id is not null and not exists (
    select 1 from public.customers where id = p_customer_id and business_id = p_business_id and is_active
  ) then raise exception 'Pelanggan tidak ditemukan pada usaha ini'; end if;
  select business_type not in ('SERVICE', 'CULINARY') into uses_inventory
  from public.businesses where id = p_business_id;
  if uses_inventory is null then raise exception 'Usaha tidak ditemukan'; end if;

  -- Lock in UUID order. Aggregating first prevents duplicate-line stock bugs.
  for line in
    select (x->>'product_id')::uuid product_id, sum((x->>'quantity')::integer)::integer quantity
    from jsonb_array_elements(p_items) x
    group by (x->>'product_id')::uuid
    order by (x->>'product_id')::uuid
  loop
    if line.quantity <= 0 then raise exception 'Kuantitas harus lebih dari nol'; end if;
    select * into product_row from public.products
    where id = line.product_id and business_id = p_business_id and is_active for update;
    if not found then raise exception 'Produk tidak ditemukan atau tidak aktif'; end if;
    if uses_inventory and product_row.stock < line.quantity then
      raise exception 'Stok % tidak mencukupi', product_row.name;
    end if;
    subtotal_value := subtotal_value + product_row.selling_price * line.quantity;
  end loop;
  if p_discount_amount > subtotal_value then raise exception 'Diskon tidak boleh melebihi subtotal'; end if;
  total_value := subtotal_value - p_discount_amount;
  if p_payment_method = 'CASH' and p_amount_paid < total_value then raise exception 'Uang tunai kurang dari total transaksi'; end if;
  status_value := (case when p_payment_method = 'DEBT' then 'UNPAID' else 'PAID' end)::public.payment_status;
  if p_payment_method = 'CASH' then change_value := p_amount_paid - total_value; end if;
  invoice_value := 'INV-' || to_char(now() at time zone 'Asia/Makassar', 'YYYYMMDD') || '-' || lpad(nextval('public.invoice_number_seq')::text, 5, '0');
  insert into public.transactions (
    business_id, invoice_number, cashier_id, customer_id, subtotal, discount_amount,
    total, amount_paid, change_amount, payment_method, payment_status, request_id
  ) values (
    p_business_id, invoice_value, auth.uid(), p_customer_id, subtotal_value, p_discount_amount,
    total_value, p_amount_paid, change_value, p_payment_method, status_value, p_request_id
  ) returning * into created_transaction;

  for line in
    select (x->>'product_id')::uuid product_id, sum((x->>'quantity')::integer)::integer quantity
    from jsonb_array_elements(p_items) x
    group by (x->>'product_id')::uuid
    order by (x->>'product_id')::uuid
  loop
    select * into product_row from public.products where id = line.product_id;
    insert into public.transaction_items (
      transaction_id, product_id, product_name_snapshot, quantity,
      purchase_price_snapshot, selling_price_snapshot, discount_amount, subtotal
    ) values (
      created_transaction.id, product_row.id, product_row.name, line.quantity,
      product_row.purchase_price, product_row.selling_price, 0,
      product_row.selling_price * line.quantity
    );
    if uses_inventory then
      perform set_config('app.stock_write','allowed',true);
      update public.products set stock = stock - line.quantity where id = product_row.id
      returning * into product_row;
      insert into public.stock_movements (
        business_id, product_id, movement_type, quantity_delta, balance_after,
        transaction_id, reason, actor_id, correlation_id
      ) values (
        p_business_id, product_row.id, 'SALE', -line.quantity, product_row.stock,
        created_transaction.id, 'Penjualan ' || invoice_value, auth.uid(), p_request_id
      );
    end if;
  end loop;
  if p_payment_method = 'DEBT' then
    insert into public.debts (business_id, customer_id, transaction_id, original_amount, paid_amount, remaining_amount, status)
    values (p_business_id, p_customer_id, created_transaction.id, total_value, 0, total_value, 'UNPAID');
  end if;
  insert into public.business_audit_logs (
    business_id, actor_id, action, resource_type, resource_id, result, correlation_id,
    metadata
  ) values (
    p_business_id, auth.uid(), 'CHECKOUT_COMPLETED', 'transaction', created_transaction.id::text,
    'SUCCESS', p_request_id, jsonb_build_object('total', total_value, 'payment_method', p_payment_method)
  );
  return created_transaction;
exception when unique_violation then
  select * into existing_transaction from public.transactions
  where business_id = p_business_id and request_id = p_request_id;
  if found then return existing_transaction; end if;
  raise;
end;
$$;

-- Reporting uses server aggregation and Makassar calendar boundaries; it does
-- not depend on the paginated transaction list loaded by Flutter.
create or replace function public.get_business_report(
  p_business_id uuid, p_start_date date, p_end_date date
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare start_at timestamptz; end_at timestamptz;
begin
  if not public.is_business_member(p_business_id) then raise exception 'Access denied' using errcode = '42501'; end if;
  if p_start_date is null or p_end_date is null or p_end_date < p_start_date or p_end_date - p_start_date > 366 then
    raise exception 'Periode laporan tidak valid' using errcode = '22023';
  end if;
  start_at := p_start_date::timestamp at time zone 'Asia/Makassar';
  end_at := (p_end_date + 1)::timestamp at time zone 'Asia/Makassar';
  return jsonb_build_object(
    'start_date', p_start_date, 'end_date', p_end_date,
    'transaction_count', (select count(*) from public.transactions t where t.business_id=p_business_id and t.voided_at is null and t.created_at>=start_at and t.created_at<end_at),
    'gross_sales', coalesce((select sum(t.subtotal) from public.transactions t where t.business_id=p_business_id and t.voided_at is null and t.created_at>=start_at and t.created_at<end_at),0),
    'discounts', coalesce((select sum(t.discount_amount) from public.transactions t where t.business_id=p_business_id and t.voided_at is null and t.created_at>=start_at and t.created_at<end_at),0),
    'net_sales', coalesce((select sum(t.total) from public.transactions t where t.business_id=p_business_id and t.voided_at is null and t.created_at>=start_at and t.created_at<end_at),0),
    'cogs', coalesce((select sum(ti.purchase_price_snapshot * ti.quantity) from public.transaction_items ti join public.transactions t on t.id=ti.transaction_id where t.business_id=p_business_id and t.voided_at is null and t.created_at>=start_at and t.created_at<end_at),0),
    'operating_expenses', coalesce((select sum(e.amount) from public.expenses e where e.business_id=p_business_id and e.expense_date between p_start_date and p_end_date),0),
    'items', coalesce((select jsonb_agg(jsonb_build_object('name', q.name, 'quantity', q.quantity, 'sales', q.sales) order by q.sales desc) from (select ti.product_name_snapshot name, sum(ti.quantity)::bigint quantity, sum(ti.subtotal)::bigint sales from public.transaction_items ti join public.transactions t on t.id=ti.transaction_id where t.business_id=p_business_id and t.voided_at is null and t.created_at>=start_at and t.created_at<end_at group by ti.product_name_snapshot) q),'[]'::jsonb)
  );
end;
$$;

-- Force all writes through the validated RPCs. Reads remain governed by RLS.
drop policy if exists "staff inserts transactions" on public.transactions;
revoke insert, update, delete on public.transactions from anon, authenticated;
revoke insert, update, delete on public.transaction_items from anon, authenticated;
revoke insert, update, delete on public.stock_movements from anon, authenticated;
revoke insert, update, delete on public.business_audit_logs from anon, authenticated;
drop function if exists public.process_checkout(uuid, jsonb, public.payment_method, bigint, uuid, bigint);
grant execute on function public.process_checkout(uuid, jsonb, public.payment_method, bigint, uuid, bigint, uuid) to authenticated;
grant execute on function public.adjust_stock(uuid, uuid, integer, text, uuid) to authenticated;
grant execute on function public.get_business_report(uuid, date, date) to authenticated;

