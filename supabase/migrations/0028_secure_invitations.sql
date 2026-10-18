-- Purpose-bound invitation codes. Raw tokens are returned exactly once and
-- never stored. These are not Supabase access tokens.

create table public.invitations (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique check(token_hash~'^[a-f0-9]{64}$'),
  purpose text not null check(purpose in('APP_ACCESS','BUSINESS_MEMBERSHIP','PROMOTION')),
  business_id uuid references public.businesses(id) on delete restrict,
  business_role public.member_role,
  email_normalized text,
  promotion_ends_at timestamptz,
  promotion_quota integer check(promotion_quota between 1 and 10000),
  reason text,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  used_at timestamptz,
  used_by uuid references auth.users(id) on delete restrict,
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  check(expires_at>created_at),
  check(business_role is null or business_role<>'OWNER'),
  check((purpose='BUSINESS_MEMBERSHIP')=(business_id is not null and business_role is not null)),
  check((purpose='PROMOTION')=(promotion_ends_at is not null and promotion_quota is not null and reason is not null))
);
create index invitations_status_idx on public.invitations(expires_at) where revoked_at is null and used_at is null;
alter table public.invitations enable row level security;

create table public.invitation_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  attempted_at timestamptz not null default now(),
  succeeded boolean not null
);
create index invitation_attempts_rate_idx on public.invitation_attempts(user_id,attempted_at desc);
alter table public.invitation_attempts enable row level security;

create or replace function public.admin_create_invitation(
  p_purpose text,p_expires_at timestamptz,p_email text default null,
  p_business_id uuid default null,p_business_role public.member_role default null,
  p_promotion_ends_at timestamptz default null,p_promotion_quota integer default null,
  p_reason text default null
) returns table(invitation_id uuid,token text)
language plpgsql security definer set search_path=public,extensions as $$
declare raw_token text; new_id uuid;
begin
  perform public.require_admin();
  if p_purpose not in('APP_ACCESS','BUSINESS_MEMBERSHIP','PROMOTION') or p_expires_at<=now() then raise exception 'Undangan tidak valid' using errcode='22023'; end if;
  if p_business_role='OWNER' then raise exception 'Undangan tidak boleh memberikan role owner' using errcode='22023'; end if;
  raw_token := upper(encode(gen_random_bytes(24),'hex'));
  insert into public.invitations(token_hash,purpose,business_id,business_role,email_normalized,promotion_ends_at,promotion_quota,reason,expires_at,created_by)
  values(encode(digest(raw_token,'sha256'),'hex'),p_purpose,p_business_id,p_business_role,nullif(lower(btrim(p_email)),''),p_promotion_ends_at,p_promotion_quota,nullif(btrim(p_reason),''),p_expires_at,auth.uid()) returning id into new_id;
  perform public.write_admin_audit('CREATE_INVITATION','invitation',new_id::text,jsonb_build_object('purpose',p_purpose,'expires_at',p_expires_at));
  return query select new_id,raw_token;
end; $$;

create or replace function public.admin_revoke_invitation(p_invitation_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  perform public.require_admin();
  update public.invitations set revoked_at=now() where id=p_invitation_id and revoked_at is null and used_at is null;
  if not found then raise exception 'Undangan tidak aktif' using errcode='22023'; end if;
  perform public.write_admin_audit('REVOKE_INVITATION','invitation',p_invitation_id::text);
end; $$;

create or replace function public.redeem_invitation(p_token text)
returns table(purpose text,business_id uuid,business_role public.member_role,promotion_ends_at timestamptz)
language plpgsql security definer set search_path=public,extensions as $$
declare row_value public.invitations; user_email text; attempt_count integer; period_value public.subscription_periods;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode='28000'; end if;
  select count(*) into attempt_count from public.invitation_attempts where user_id=auth.uid() and attempted_at>now()-interval '15 minutes';
  if attempt_count>=10 then return query select 'RATE_LIMITED'::text,null::uuid,null::public.member_role,null::timestamptz; return; end if;
  select lower(email) into user_email from auth.users where id=auth.uid();
  select * into row_value from public.invitations where token_hash=encode(digest(upper(btrim(coalesce(p_token,''))),'sha256'),'hex') for update;
  if not found or row_value.revoked_at is not null or row_value.used_at is not null or row_value.expires_at<=now() or(row_value.email_normalized is not null and row_value.email_normalized<>user_email) then
    insert into public.invitation_attempts(user_id,succeeded) values(auth.uid(),false);
    return query select 'INVALID'::text,null::uuid,null::public.member_role,null::timestamptz; return;
  end if;
  if row_value.purpose='BUSINESS_MEMBERSHIP' then
    insert into public.business_members(business_id,user_id,role,is_active) values(row_value.business_id,auth.uid(),row_value.business_role,true)
    on conflict on constraint business_members_business_id_user_id_key
    do update set role=excluded.role,is_active=true;
  elsif row_value.purpose='PROMOTION' then
    insert into public.subscription_periods(user_id,source,plan_key_snapshot,price_snapshot,quota_snapshot,starts_at,ends_at,status,reason,created_by)
    values(auth.uid(),'PROMOTION','promotion',0,row_value.promotion_quota,now(),row_value.promotion_ends_at,'ACTIVE',row_value.reason,row_value.created_by) returning * into period_value;
    insert into public.promotional_entitlements(user_id,period_id,reason,created_by) values(auth.uid(),period_value.id,row_value.reason,row_value.created_by);
  else
    update public.profiles set access_enabled=true where id=auth.uid();
  end if;
  update public.invitations set used_at=now(),used_by=auth.uid() where id=row_value.id;
  insert into public.invitation_attempts(user_id,succeeded) values(auth.uid(),true);
  insert into public.business_audit_logs(business_id,actor_id,action,resource_type,resource_id,result,correlation_id,metadata)
  values(row_value.business_id,auth.uid(),'INVITATION_REDEEMED','invitation',row_value.id::text,'SUCCESS',gen_random_uuid(),jsonb_build_object('purpose',row_value.purpose));
  return query select row_value.purpose,row_value.business_id,row_value.business_role,row_value.promotion_ends_at;
end; $$;

alter table public.admin_audit_logs drop constraint if exists admin_audit_logs_action_check;
alter table public.admin_audit_logs add constraint admin_audit_logs_action_check check(action in('CREATE_VOUCHER','UPDATE_VOUCHER','REVOKE_VOUCHER','DISABLE_USER','ENABLE_USER','CHANGE_ROLE','EXTEND_SUBSCRIPTION','CANCEL_SUBSCRIPTION','UPDATE_AI_CONFIG','ACTIVATE_SUBSCRIPTION','REVOKE_SUBSCRIPTION','RESOLVE_ERROR','REJECT_PAYMENT','APPROVE_PAYMENT','GRANT_PROMOTION','CREATE_INVITATION','REVOKE_INVITATION'));
revoke all on public.invitations,public.invitation_attempts from anon,authenticated;
revoke all on function public.admin_create_invitation(text,timestamptz,text,uuid,public.member_role,timestamptz,integer,text),public.admin_revoke_invitation(uuid) from public;
grant execute on function public.admin_create_invitation(text,timestamptz,text,uuid,public.member_role,timestamptz,integer,text),public.admin_revoke_invitation(uuid),public.redeem_invitation(text) to authenticated;

