begin;
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
('00000000-0000-0000-0000-000000000000','11000000-0000-0000-0000-000000000001','authenticated','authenticated','a@example.test','',now(),'{}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','11000000-0000-0000-0000-000000000002','authenticated','authenticated','b@example.test','',now(),'{}','{}',now(),now());
insert into public.businesses(id,owner_id,name,business_type) values
('21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','Usaha A','RETAIL'),
('21000000-0000-0000-0000-000000000002','11000000-0000-0000-0000-000000000002','Usaha B','RETAIL');
insert into public.business_members(business_id,user_id,role) values
('21000000-0000-0000-0000-000000000001','11000000-0000-0000-0000-000000000001','OWNER'),
('21000000-0000-0000-0000-000000000002','11000000-0000-0000-0000-000000000002','OWNER');
insert into public.products(id,business_id,name,sku,purchase_price,selling_price,stock) values
('31000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001','Rahasia A','A',1,2,0),
('31000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000002','Produk B','B',1,2,0);

set local role authenticated;
select set_config('request.jwt.claim.sub','11000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claim.role','authenticated',true);
do $$ declare visible_count integer;
begin
  select count(*) into visible_count from public.products where business_id='21000000-0000-0000-0000-000000000001';
  if visible_count<>0 then raise exception 'RLS leaked business A to account B'; end if;
  update public.products set name='Disusupi' where id='31000000-0000-0000-0000-000000000001';
  if found then raise exception 'RLS allowed account B to update business A'; end if;
  begin
    perform public.adjust_stock('21000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-000000000001',9,'Serangan silang usaha','41000000-0000-0000-0000-000000000001');
    raise exception 'adjust_stock allowed cross-business actor';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
rollback;
