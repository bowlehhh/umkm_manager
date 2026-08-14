-- Mempertahankan seluruh alur checkout 0005; hanya hasil CASE di-cast
-- secara eksplisit ke enum payment_status untuk menghilangkan warning lint.
create or replace function public.process_checkout(
  p_business_id uuid,
  p_items jsonb,
  p_payment_method public.payment_method,
  p_amount_paid bigint,
  p_customer_id uuid default null,
  p_discount_amount bigint default 0
)
returns public.transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  product_row public.products;
  created_transaction public.transactions;
  item_quantity integer;
  subtotal_value bigint := 0;
  total_value bigint;
  change_value bigint := 0;
  status_value public.payment_status;
  invoice_value text;
  uses_inventory boolean;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;
  if not public.has_business_role(p_business_id, array['OWNER','ADMIN','CASHIER']::public.member_role[]) then
    raise exception 'Anda tidak memiliki izin untuk membuat transaksi';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Keranjang belanja kosong';
  end if;
  if p_amount_paid < 0 or p_discount_amount < 0 then
    raise exception 'Nilai pembayaran atau diskon tidak valid';
  end if;
  if p_payment_method = 'DEBT' and p_customer_id is null then
    raise exception 'Pelanggan wajib dipilih untuk transaksi bon';
  end if;
  if p_customer_id is not null and not exists (
    select 1 from public.customers where id = p_customer_id and business_id = p_business_id
  ) then
    raise exception 'Pelanggan tidak ditemukan pada bisnis ini';
  end if;

  select business_type <> 'SERVICE' into uses_inventory
  from public.businesses
  where id = p_business_id;
  if uses_inventory is null then raise exception 'Usaha tidak ditemukan'; end if;

  for item in select * from jsonb_array_elements(p_items)
  loop
    item_quantity := (item ->> 'quantity')::integer;
    if item_quantity <= 0 then raise exception 'Kuantitas harus lebih dari nol'; end if;
    select * into product_row from public.products
    where id = (item ->> 'product_id')::uuid and business_id = p_business_id and is_active
    for update;
    if not found then raise exception 'Produk tidak ditemukan atau tidak aktif'; end if;
    if uses_inventory and product_row.stock < item_quantity then
      raise exception 'Stok % tidak mencukupi', product_row.name;
    end if;
    subtotal_value := subtotal_value + product_row.selling_price * item_quantity;
  end loop;

  if p_discount_amount > subtotal_value then raise exception 'Diskon tidak boleh melebihi subtotal'; end if;
  total_value := subtotal_value - p_discount_amount;
  if p_payment_method = 'CASH' and p_amount_paid < total_value then
    raise exception 'Uang tunai kurang dari total transaksi';
  end if;
  status_value := (
    case when p_payment_method = 'DEBT' then 'UNPAID' else 'PAID' end
  )::public.payment_status;
  if p_payment_method = 'CASH' then change_value := p_amount_paid - total_value; end if;

  invoice_value := 'INV-' || to_char(now() at time zone 'Asia/Makassar', 'YYYYMMDD') || '-' || lpad(nextval('public.invoice_number_seq')::text, 5, '0');
  insert into public.transactions (
    business_id, invoice_number, cashier_id, customer_id, subtotal, discount_amount,
    total, amount_paid, change_amount, payment_method, payment_status
  ) values (
    p_business_id, invoice_value, auth.uid(), p_customer_id, subtotal_value, p_discount_amount,
    total_value, p_amount_paid, change_value, p_payment_method, status_value
  ) returning * into created_transaction;

  for item in select * from jsonb_array_elements(p_items)
  loop
    item_quantity := (item ->> 'quantity')::integer;
    select * into product_row from public.products
    where id = (item ->> 'product_id')::uuid for update;
    insert into public.transaction_items (
      transaction_id, product_id, quantity, purchase_price_snapshot,
      selling_price_snapshot, discount_amount, subtotal
    ) values (
      created_transaction.id, product_row.id, item_quantity, product_row.purchase_price,
      product_row.selling_price, 0, product_row.selling_price * item_quantity
    );
    if uses_inventory then
      update public.products set stock = stock - item_quantity where id = product_row.id;
    end if;
  end loop;

  if p_payment_method = 'DEBT' then
    insert into public.debts (
      business_id, customer_id, transaction_id, original_amount, paid_amount, remaining_amount, status
    ) values (
      p_business_id, p_customer_id, created_transaction.id, total_value, 0, total_value, 'UNPAID'
    );
  end if;
  return created_transaction;
end;
$$;
