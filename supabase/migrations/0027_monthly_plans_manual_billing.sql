-- Monthly AI plans and manual payment workflow. Application/business data
-- access remains independent from AI subscription status.

alter table public.subscription_plans
  add column if not exists monthly_price bigint,
  add column if not exists ai_quota integer,
  add column if not exists is_public boolean not null default false,
  add column if not exists is_active boolean not null default true;
update public.subscription_plans set monthly_price = 0, ai_quota = null where key in ('legacy','voucher');
insert into public.subscription_plans (key, label, monthly_price, ai_quota, is_public)
values
  ('dasar','Dasar',35000,3,true),
  ('plus','Plus',45000,5,true),
  ('pro','Pro',60000,8,true)
on conflict (key) do update set
  label=excluded.label, monthly_price=excluded.monthly_price,
  ai_quota=excluded.ai_quota, is_public=true, is_active=true;
alter table public.subscription_plans
  add constraint subscription_plans_price_check check (monthly_price is null or monthly_price >= 0),
  add constraint subscription_plans_quota_check check (ai_quota is null or ai_quota between 1 and 10000);

create table public.billing_instructions (
  id boolean primary key default true check (id),
  instructions text not null default 'Hubungi admin untuk instruksi pembayaran.',
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
insert into public.billing_instructions (id) values (true) on conflict do nothing;
alter table public.billing_instructions enable row level security;
create policy "authenticated reads billing instructions" on public.billing_instructions
  for select to authenticated using (true);

create table public.subscription_invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number text not null unique,
  user_id uuid not null references auth.users(id) on delete restrict,
  plan_id uuid not null references public.subscription_plans(id) on delete restrict,
  plan_key_snapshot text not null,
  plan_label_snapshot text not null,
  price_snapshot bigint not null check (price_snapshot > 0),
  quota_snapshot integer not null check (quota_snapshot > 0),
  status text not null default 'UNPAID' check (status in ('UNPAID','AWAITING_VERIFICATION','PAID','REJECTED','CANCELLED','EXPIRED')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '3 days',
  paid_at timestamptz,
  check (expires_at > created_at)
);
create index subscription_invoices_user_created_idx on public.subscription_invoices(user_id, created_at desc);

create table public.payment_submissions (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null unique references public.subscription_invoices(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  status text not null default 'PENDING' check (status in ('PENDING','APPROVED','REJECTED')),
  payer_name text not null check (char_length(btrim(payer_name)) between 2 and 100),
  payment_reference text check (char_length(payment_reference) <= 100),
  proof_path text,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete restrict,
  rejection_reason text,
  correlation_id uuid not null unique
);

create table public.subscription_periods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  plan_id uuid references public.subscription_plans(id) on delete restrict,
  invoice_id uuid unique references public.subscription_invoices(id) on delete restrict,
  source text not null check (source in ('MANUAL_PAYMENT','PROMOTION','LEGACY','VOUCHER')),
  plan_key_snapshot text not null,
  price_snapshot bigint not null check (price_snapshot >= 0),
  quota_snapshot integer not null check (quota_snapshot >= 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status text not null default 'SCHEDULED' check (status in ('SCHEDULED','ACTIVE','EXPIRED','REVOKED')),
  reason text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  check (ends_at > starts_at)
);
create index subscription_periods_user_window_idx on public.subscription_periods(user_id, starts_at, ends_at);

-- Preserve existing paid/voucher windows as historical periods. Legacy rows
-- keep application access but intentionally receive no implicit paid AI quota.
insert into public.subscription_periods(
  user_id,plan_id,source,plan_key_snapshot,price_snapshot,quota_snapshot,
  starts_at,ends_at,status,reason
)
select s.user_id,s.plan_id,
  case when s.source='voucher' then 'VOUCHER' else 'LEGACY' end,
  coalesce(sp.key,'legacy'),0,coalesce(s.ai_quota,0),s.started_at,s.expires_at,
  case when s.status='active' and s.expires_at>now() then 'ACTIVE' else 'EXPIRED' end,
  'Backfill langganan sebelum migration paket bulanan'
from public.subscriptions s left join public.subscription_plans sp on sp.id=s.plan_id
where not exists(select 1 from public.subscription_periods p where p.user_id=s.user_id and p.starts_at=s.started_at and p.ends_at=s.expires_at);

create table public.promotional_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  period_id uuid not null unique references public.subscription_periods(id) on delete restrict,
  reason text not null check (char_length(btrim(reason)) between 3 and 500),
  created_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now()
);

alter table public.subscription_invoices enable row level security;
alter table public.payment_submissions enable row level security;
alter table public.subscription_periods enable row level security;
alter table public.promotional_entitlements enable row level security;
create policy "users read own invoices" on public.subscription_invoices for select using (user_id=auth.uid());
create policy "users read own payments" on public.payment_submissions for select using (user_id=auth.uid());
create policy "users read own periods" on public.subscription_periods for select using (user_id=auth.uid());
create policy "users read own promotions" on public.promotional_entitlements for select using (user_id=auth.uid());

create sequence if not exists public.subscription_invoice_number_seq;

create or replace function public.create_subscription_invoice(p_plan_key text)
returns public.subscription_invoices language plpgsql security definer set search_path=public as $$
declare plan_row public.subscription_plans; result public.subscription_invoices;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode='28000'; end if;
  select * into plan_row from public.subscription_plans where key=p_plan_key and is_public and is_active for share;
  if not found or plan_row.monthly_price is null or plan_row.ai_quota is null then raise exception 'Paket tidak tersedia' using errcode='22023'; end if;
  if exists (select 1 from public.subscription_invoices where user_id=auth.uid() and status in ('UNPAID','AWAITING_VERIFICATION') and expires_at>now()) then
    raise exception 'Selesaikan tagihan yang masih aktif terlebih dahulu' using errcode='23505';
  end if;
  insert into public.subscription_invoices(invoice_number,user_id,plan_id,plan_key_snapshot,plan_label_snapshot,price_snapshot,quota_snapshot)
  values ('AI-'||to_char(now() at time zone 'Asia/Makassar','YYYYMMDD')||'-'||lpad(nextval('public.subscription_invoice_number_seq')::text,6,'0'),auth.uid(),plan_row.id,plan_row.key,plan_row.label,plan_row.monthly_price,plan_row.ai_quota)
  returning * into result;
  return result;
end; $$;

create or replace function public.submit_manual_payment(p_invoice_id uuid,p_payer_name text,p_payment_reference text,p_correlation_id uuid)
returns public.payment_submissions language plpgsql security definer set search_path=public as $$
declare invoice_row public.subscription_invoices; result public.payment_submissions;
begin
  if auth.uid() is null then raise exception 'Not authenticated' using errcode='28000'; end if;
  select * into result from public.payment_submissions where correlation_id=p_correlation_id and user_id=auth.uid();
  if found then return result; end if;
  select * into invoice_row from public.subscription_invoices where id=p_invoice_id and user_id=auth.uid() for update;
  if not found or invoice_row.status not in ('UNPAID','REJECTED') or invoice_row.expires_at<=now() then raise exception 'Tagihan tidak dapat diajukan' using errcode='22023'; end if;
  insert into public.payment_submissions(invoice_id,user_id,payer_name,payment_reference,correlation_id)
  values(p_invoice_id,auth.uid(),btrim(p_payer_name),nullif(btrim(p_payment_reference),''),p_correlation_id)
  on conflict(invoice_id) do update set status='PENDING',payer_name=excluded.payer_name,payment_reference=excluded.payment_reference,submitted_at=now(),reviewed_at=null,reviewed_by=null,rejection_reason=null,correlation_id=excluded.correlation_id
  returning * into result;
  update public.subscription_invoices set status='AWAITING_VERIFICATION' where id=p_invoice_id;
  return result;
end; $$;

create or replace function public.admin_review_manual_payment(p_submission_id uuid,p_approve boolean,p_reason text default null)
returns public.subscription_periods language plpgsql security definer set search_path=public as $$
declare submission_row public.payment_submissions; invoice_row public.subscription_invoices; result public.subscription_periods; start_value timestamptz; end_value timestamptz;
begin
  perform public.require_admin();
  select * into submission_row from public.payment_submissions where id=p_submission_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan' using errcode='P0002'; end if;
  select * into result from public.subscription_periods where invoice_id=submission_row.invoice_id;
  if found then return result; end if;
  if submission_row.status<>'PENDING' then raise exception 'Pengajuan sudah ditinjau' using errcode='22023'; end if;
  select * into invoice_row from public.subscription_invoices where id=submission_row.invoice_id for update;
  if not p_approve then
    update public.payment_submissions set status='REJECTED',reviewed_at=now(),reviewed_by=auth.uid(),rejection_reason=left(btrim(coalesce(p_reason,'Tidak disetujui')),500) where id=p_submission_id;
    update public.subscription_invoices set status='REJECTED' where id=invoice_row.id;
    perform public.write_admin_audit('REJECT_PAYMENT','payment_submission',p_submission_id::text,jsonb_build_object('invoice_id',invoice_row.id));
    return null;
  end if;
  select greatest(now(),coalesce(max(ends_at),now())) into start_value from public.subscription_periods where user_id=invoice_row.user_id and status in ('ACTIVE','SCHEDULED') and ends_at>now();
  -- Calendar month with PostgreSQL end-of-month clamping (e.g. Jan 31 + 1 month -> Feb 28/29).
  end_value := start_value + interval '1 month';
  insert into public.subscription_periods(user_id,plan_id,invoice_id,source,plan_key_snapshot,price_snapshot,quota_snapshot,starts_at,ends_at,status,created_by)
  values(invoice_row.user_id,invoice_row.plan_id,invoice_row.id,'MANUAL_PAYMENT',invoice_row.plan_key_snapshot,invoice_row.price_snapshot,invoice_row.quota_snapshot,start_value,end_value,case when start_value<=now() then 'ACTIVE' else 'SCHEDULED' end,auth.uid()) returning * into result;
  update public.payment_submissions set status='APPROVED',reviewed_at=now(),reviewed_by=auth.uid(),rejection_reason=null where id=p_submission_id;
  update public.subscription_invoices set status='PAID',paid_at=now() where id=invoice_row.id;
  perform public.write_admin_audit('APPROVE_PAYMENT','payment_submission',p_submission_id::text,jsonb_build_object('invoice_id',invoice_row.id,'period_id',result.id));
  return result;
end; $$;

create or replace function public.admin_grant_promotion(p_user_id uuid,p_ends_at timestamptz,p_quota integer,p_reason text)
returns public.subscription_periods language plpgsql security definer set search_path=public as $$
declare result public.subscription_periods;
begin
  perform public.require_admin();
  if p_ends_at<=now() or p_quota<1 or p_quota>10000 or char_length(btrim(p_reason))<3 then raise exception 'Promosi tidak valid' using errcode='22023'; end if;
  insert into public.subscription_periods(user_id,source,plan_key_snapshot,price_snapshot,quota_snapshot,starts_at,ends_at,status,reason,created_by)
  values(p_user_id,'PROMOTION','promotion',0,p_quota,now(),p_ends_at,'ACTIVE',btrim(p_reason),auth.uid()) returning * into result;
  insert into public.promotional_entitlements(user_id,period_id,reason,created_by) values(p_user_id,result.id,btrim(p_reason),auth.uid());
  perform public.write_admin_audit('GRANT_PROMOTION','subscription_period',result.id::text,jsonb_build_object('user_id',p_user_id,'ends_at',p_ends_at,'quota',p_quota));
  return result;
end; $$;

-- Subscription expiry only blocks AI. It must never hide business data.
drop function if exists public.get_current_access();
create or replace function public.get_current_access()
returns table(role text,access_enabled boolean,subscription_active boolean,subscription_expires_at timestamptz,plan_key text,source text,ai_quota integer,ai_used bigint)
language sql stable security definer set search_path=public as $$
  select p.role,p.access_enabled,(period.id is not null),period.ends_at,period.plan_key_snapshot,period.source,period.quota_snapshot,
    coalesce((select count(*) from public.ai_quota_reservations r where r.user_id=p.id and r.status='completed' and r.created_at>=period.starts_at and r.created_at<period.ends_at),0)
  from public.profiles p
  left join lateral (select sp.* from public.subscription_periods sp where sp.user_id=p.id and sp.status in ('ACTIVE','SCHEDULED') and sp.starts_at<=now() and sp.ends_at>now() order by sp.starts_at desc limit 1) period on true
  where p.id=auth.uid();
$$;

-- The Edge Function invokes this with service-role credentials. Quota comes
-- only from the account's active period and is shared across all businesses.
-- A failed/released reservation does not consume quota; a live reservation is
-- counted while in flight to prevent parallel requests exceeding the limit.
create or replace function public.reserve_ai_quota(p_user_id uuid,p_daily_limit integer,p_rate_limit_per_minute integer)
returns table(allowed boolean,reservation_id uuid,denial_reason text)
language plpgsql security definer set search_path=public as $$
declare period_row public.subscription_periods; used_count integer; rate_count integer; new_id uuid;
begin
  select * into period_row from public.subscription_periods
  where user_id=p_user_id and status='ACTIVE' and starts_at<=now() and ends_at>now()
  order by starts_at desc limit 1;
  if not found or period_row.quota_snapshot<=0 then return query select false,null::uuid,'subscription'; return; end if;
  perform pg_advisory_xact_lock(hashtextextended('ai-period:'||period_row.id::text,0));
  update public.ai_quota_reservations set status='released'
  where user_id=p_user_id and status='reserved' and expires_at<=now();
  select count(*) into used_count from public.ai_quota_reservations
  where user_id=p_user_id and created_at>=period_row.starts_at and created_at<period_row.ends_at
    and(status='completed' or(status='reserved' and expires_at>now()));
  if used_count>=least(period_row.quota_snapshot,p_daily_limit) then return query select false,null::uuid,'quota'; return; end if;
  select count(*) into rate_count from public.ai_quota_reservations where user_id=p_user_id and created_at>=now()-interval '1 minute' and(status='completed' or(status='reserved' and expires_at>now()));
  if rate_count>=p_rate_limit_per_minute then return query select false,null::uuid,'rate_limit'; return; end if;
  insert into public.ai_quota_reservations(user_id,expires_at) values(p_user_id,now()+interval '2 minutes') returning id into new_id;
  return query select true,new_id,null::text;
end; $$;

alter table public.admin_audit_logs drop constraint if exists admin_audit_logs_action_check;
alter table public.admin_audit_logs add constraint admin_audit_logs_action_check check(action in('CREATE_VOUCHER','UPDATE_VOUCHER','REVOKE_VOUCHER','DISABLE_USER','ENABLE_USER','CHANGE_ROLE','EXTEND_SUBSCRIPTION','CANCEL_SUBSCRIPTION','UPDATE_AI_CONFIG','ACTIVATE_SUBSCRIPTION','REVOKE_SUBSCRIPTION','RESOLVE_ERROR','REJECT_PAYMENT','APPROVE_PAYMENT','GRANT_PROMOTION'));

revoke all on public.subscription_invoices,public.payment_submissions,public.subscription_periods,public.promotional_entitlements from anon,authenticated;
grant select on public.subscription_invoices,public.payment_submissions,public.subscription_periods,public.promotional_entitlements to authenticated;
grant execute on function public.create_subscription_invoice(text),public.submit_manual_payment(uuid,text,text,uuid),public.get_current_access() to authenticated;
grant execute on function public.admin_review_manual_payment(uuid,boolean,text),public.admin_grant_promotion(uuid,timestamptz,integer,text) to authenticated;

