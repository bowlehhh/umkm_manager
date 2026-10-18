-- Server-side idempotency and lease-safe AI quota finalization. A request key
-- is permanently bound to one payload hash. Completed results are replayed
-- without another provider call; expired/released keys cannot be reused.

alter table public.ai_quota_reservations
  add column if not exists request_id text,
  add column if not exists payload_hash text,
  add column if not exists period_id uuid references public.subscription_periods(id) on delete restrict,
  add column if not exists lease_token uuid,
  add column if not exists result_payload jsonb,
  add column if not exists finalized_at timestamptz,
  add column if not exists failure_reason text;
create unique index if not exists ai_quota_user_request_unique
  on public.ai_quota_reservations(user_id,request_id) where request_id is not null;

create table public.ai_configuration_drafts(
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid not null unique references public.ai_quota_reservations(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id text not null,
  action text not null check(action in('business_builder','feature_request')),
  configuration jsonb not null,
  applied_at timestamptz,
  created_at timestamptz not null default now(),
  unique(user_id,request_id)
);
alter table public.ai_configuration_drafts enable row level security;
create policy "users read own ai drafts" on public.ai_configuration_drafts for select using(user_id=auth.uid());
grant select on public.ai_configuration_drafts to authenticated;

create or replace function public.reserve_ai_quota_v2(
  p_user_id uuid,p_request_id text,p_payload_hash text,
  p_server_limit integer,p_rate_limit_per_minute integer
) returns table(
  state text,reservation_id uuid,lease_token uuid,result_payload jsonb,denial_reason text
) language plpgsql security definer set search_path=public as $$
declare existing public.ai_quota_reservations; period_row public.subscription_periods;
  used_count integer; rate_count integer; new_id uuid; new_lease uuid:=gen_random_uuid();
begin
  if p_user_id is null or p_request_id!~'^[A-Za-z0-9-]{8,100}$' or p_payload_hash!~'^[a-f0-9]{64}$' then
    return query select 'rejected',null::uuid,null::uuid,null::jsonb,'invalid_request'; return;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('ai-request:'||p_user_id::text||':'||p_request_id,0));
  select * into existing from public.ai_quota_reservations where user_id=p_user_id and request_id=p_request_id for update;
  if found then
    if existing.payload_hash<>p_payload_hash then return query select 'rejected',existing.id,null::uuid,null::jsonb,'payload_mismatch'; return; end if;
    if existing.status='completed' then return query select 'completed',existing.id,null::uuid,existing.result_payload,null::text; return; end if;
    if existing.status='reserved' and existing.expires_at>now() then return query select 'in_progress',existing.id,null::uuid,null::jsonb,'in_progress'; return; end if;
    if existing.status='reserved' then
      update public.ai_quota_reservations set status='released',failure_reason='lease_expired',finalized_at=now() where id=existing.id;
    end if;
    return query select 'expired',existing.id,null::uuid,null::jsonb,coalesce(existing.failure_reason,'request_closed'); return;
  end if;
  select * into period_row from public.subscription_periods
    where user_id=p_user_id and status='ACTIVE' and starts_at<=now() and ends_at>now()
    order by starts_at desc limit 1 for share;
  if not found or period_row.quota_snapshot<=0 then return query select 'denied',null::uuid,null::uuid,null::jsonb,'subscription'; return; end if;
  perform pg_advisory_xact_lock(hashtextextended('ai-period:'||period_row.id::text,0));
  update public.ai_quota_reservations set status='released',failure_reason='lease_expired',finalized_at=now()
    where user_id=p_user_id and status='reserved' and expires_at<=now();
  select count(*) into used_count from public.ai_quota_reservations
    where period_id=period_row.id and(status='completed' or(status='reserved' and expires_at>now()));
  if used_count>=least(period_row.quota_snapshot,p_server_limit) then return query select 'denied',null::uuid,null::uuid,null::jsonb,'quota'; return; end if;
  select count(*) into rate_count from public.ai_quota_reservations
    where user_id=p_user_id and created_at>=now()-interval '1 minute'
      and(status='completed' or(status='reserved' and expires_at>now()));
  if rate_count>=p_rate_limit_per_minute then return query select 'denied',null::uuid,null::uuid,null::jsonb,'rate_limit'; return; end if;
  insert into public.ai_quota_reservations(user_id,expires_at,request_id,payload_hash,period_id,lease_token)
    values(p_user_id,now()+interval '2 minutes',p_request_id,p_payload_hash,period_row.id,new_lease)
    returning id into new_id;
  return query select 'granted',new_id,new_lease,null::jsonb,null::text;
end; $$;

create or replace function public.finalize_ai_quota_v2(
  p_reservation_id uuid,p_lease_token uuid,p_success boolean,
  p_action text,p_result_payload jsonb default null,p_failure_reason text default null
) returns table(finalized boolean,state text,draft_id uuid)
language plpgsql security definer set search_path=public as $$
declare row_value public.ai_quota_reservations; new_draft uuid;
begin
  select * into row_value from public.ai_quota_reservations where id=p_reservation_id for update;
  if not found or row_value.status<>'reserved' or row_value.lease_token<>p_lease_token then
    return query select false,coalesce(row_value.status,'missing'),null::uuid; return;
  end if;
  if row_value.expires_at<=now() then
    update public.ai_quota_reservations set status='released',failure_reason='late_response',finalized_at=now() where id=p_reservation_id;
    return query select false,'expired',null::uuid; return;
  end if;
  if not p_success then
    update public.ai_quota_reservations set status='released',failure_reason=left(coalesce(p_failure_reason,'provider_failure'),120),finalized_at=now() where id=p_reservation_id;
    return query select true,'released',null::uuid; return;
  end if;
  if p_action not in('business_builder','feature_request') or p_result_payload is null or jsonb_typeof(p_result_payload)<>'object' then
    raise exception 'Invalid AI result' using errcode='22023';
  end if;
  insert into public.ai_configuration_drafts(reservation_id,user_id,request_id,action,configuration)
    values(row_value.id,row_value.user_id,row_value.request_id,p_action,p_result_payload)
    returning id into new_draft;
  update public.ai_quota_reservations set status='completed',result_payload=p_result_payload,finalized_at=now(),failure_reason=null where id=row_value.id;
  return query select true,'completed',new_draft;
end; $$;

revoke all on function public.reserve_ai_quota_v2(uuid,text,text,integer,integer),
  public.finalize_ai_quota_v2(uuid,uuid,boolean,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.reserve_ai_quota_v2(uuid,text,text,integer,integer),
  public.finalize_ai_quota_v2(uuid,uuid,boolean,text,jsonb,text) to service_role;
