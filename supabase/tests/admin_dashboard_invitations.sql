begin;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
('00000000-0000-0000-0000-000000000000','12000000-0000-0000-0000-000000000001','authenticated','authenticated','admin@example.test','',now(),'{}','{}',now(),now()),
('00000000-0000-0000-0000-000000000000','12000000-0000-0000-0000-000000000002','authenticated','authenticated','user@example.test','',now(),'{}','{}',now(),now());
update public.profiles set role='admin' where id='12000000-0000-0000-0000-000000000001';

select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000002',true);
select set_config('request.jwt.claim.role','authenticated',true);
do $$ begin
  begin perform public.admin_dashboard_metrics();
    raise exception 'non-admin could read dashboard';
  exception when insufficient_privilege then null;
  end;
end $$;

select set_config('request.jwt.claim.sub','12000000-0000-0000-0000-000000000001',true);
do $$
declare created record; listed record; metrics jsonb;
begin
  select * into created from public.admin_create_invitation(
    'APP_ACCESS',now()+interval '1 day','user@example.test',null,null,null,null,null
  );
  if created.token is null or length(created.token)<32 then raise exception 'raw token missing'; end if;
  if exists(select 1 from public.invitations where token_hash=created.token) then
    raise exception 'raw invitation token was stored';
  end if;
  select * into listed from public.admin_list_invitations('ACTIVE',null,'user@',10,0);
  if listed.id<>created.invitation_id or listed.status<>'ACTIVE' then
    raise exception 'invitation list/status/filter failed';
  end if;
  perform public.admin_revoke_invitation(created.invitation_id);
  select * into listed from public.admin_list_invitations('REVOKED',null,null,10,0);
  if listed.id<>created.invitation_id then raise exception 'revoked status unavailable'; end if;
  metrics:=public.admin_dashboard_metrics();
  if not metrics ?& array['total_users','total_businesses','active_subscriptions',
    'scheduled_subscriptions','expired_subscriptions','unpaid_invoices',
    'ai_quota_allocated','ai_quota_used','active_promotions','active_invitations'] then
    raise exception 'dashboard metrics contract incomplete: %',metrics;
  end if;
  if (select count(*) from public.admin_list_activity_audit('PLATFORM','CREATE_INVITATION',null,10,0))<>1 then
    raise exception 'audit source/action filtering failed';
  end if;
end $$;

rollback;
