begin;

insert into auth.users (
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '10000000-0000-0000-0000-000000000001','authenticated','authenticated',
  'owner@example.test','',now(),'{}','{"full_name":"Owner Test"}',now(),now()
);
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);

insert into public.businesses(id,owner_id,name,business_type)
values('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','Fixture Toko','RETAIL');
insert into public.business_members(business_id,user_id,role)
values('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','OWNER');

insert into public.products(id,business_id,name,sku,barcode,purchase_price,selling_price,stock)
values
('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Produk A','A',null,6000,10000,0),
('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','Produk B','B',null,6000,10000,0),
('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001','Produk C','C',null,6000,10000,0),
('30000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001','Produk D','D','8990001',6000,10000,0);

do $$ begin
  begin
    insert into public.products(business_id,name,sku,barcode,purchase_price,selling_price,stock)
    values('20000000-0000-0000-0000-000000000001','Duplikat','E','8990001',0,10000,0);
    raise exception 'expected duplicate barcode rejection';
  exception when unique_violation then null;
  end;
end $$;

select public.adjust_stock(
  '20000000-0000-0000-0000-000000000001',
  '30000000-0000-0000-0000-000000000001',10,'Saldo awal fixture',
  '40000000-0000-0000-0000-000000000001'
);

do $$
declare first_id uuid; retry_id uuid; stock_value integer; movement_count bigint;
begin
  select id into first_id from public.process_checkout(
    '20000000-0000-0000-0000-000000000001',
    '[{"product_id":"30000000-0000-0000-0000-000000000001","quantity":1},{"product_id":"30000000-0000-0000-0000-000000000001","quantity":1}]',
    'CASH',50000,null,0,'50000000-0000-0000-0000-000000000001'
  );
  select id into retry_id from public.process_checkout(
    '20000000-0000-0000-0000-000000000001',
    '[{"product_id":"30000000-0000-0000-0000-000000000001","quantity":2}]',
    'CASH',50000,null,0,'50000000-0000-0000-0000-000000000001'
  );
  if first_id<>retry_id then raise exception 'retry returned another transaction'; end if;
  select stock into stock_value from public.products where id='30000000-0000-0000-0000-000000000001';
  if stock_value<>8 then raise exception 'stock expected 8, got %',stock_value; end if;
  select count(*) into movement_count from public.stock_movements where transaction_id=first_id and movement_type='SALE';
  if movement_count<>1 then raise exception 'sale movement expected 1, got %',movement_count; end if;
  if not exists(select 1 from public.transaction_items where transaction_id=first_id and quantity=2 and product_name_snapshot='Produk A' and purchase_price_snapshot=6000 and selling_price_snapshot=10000) then
    raise exception 'transaction snapshot mismatch';
  end if;
end $$;

insert into public.expenses(business_id,category,description,amount,expense_date,created_by)
values('20000000-0000-0000-0000-000000000001','Operasional','Fixture biaya',3000,(now() at time zone 'Asia/Makassar')::date,'10000000-0000-0000-0000-000000000001');

do $$ declare report jsonb;
begin
  report := public.get_business_report('20000000-0000-0000-0000-000000000001',(now() at time zone 'Asia/Makassar')::date,(now() at time zone 'Asia/Makassar')::date);
  if (report->>'net_sales')::bigint<>20000 then raise exception 'net sales mismatch: %',report; end if;
  if (report->>'cogs')::bigint<>12000 then raise exception 'cogs mismatch: %',report; end if;
  if (report->>'operating_expenses')::bigint<>3000 then raise exception 'expense mismatch: %',report; end if;
  if (report->>'net_sales')::bigint-(report->>'cogs')::bigint-(report->>'operating_expenses')::bigint<>5000 then raise exception 'simple result mismatch: %',report; end if;
  if (timestamptz '2025-01-31 08:00:00+08' + interval '1 month')::date<>date '2025-02-28' then raise exception 'month-end clamp mismatch'; end if;
end $$;

rollback;
