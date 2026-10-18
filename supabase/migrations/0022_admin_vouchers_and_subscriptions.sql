-- Admin, voucher, and subscription foundation. All sensitive access remains
-- server-side through SECURITY DEFINER RPCs; clients never receive a service key.

alter table public.profiles
  add column if not exists role text not null default 'user'
    check (role in ('user', 'admin')),
  add column if not exists access_enabled boolean not null default true;

create index if not exists profiles_role_idx on public.profiles (role);

-- Replace the legacy "for all" policy so a client cannot create a profile
-- row with role=admin. Column grants below also prevent updates to role and
-- access_enabled from the Flutter client.
drop policy if exists "profiles own data" on public.profiles;
create policy "profiles read own data" on public.profiles
  for select using (id = auth.uid());
create policy "profiles insert own user data" on public.profiles
  for insert with check (id = auth.uid() and role = 'user' and access_enabled);
create policy "profiles update own data" on public.profiles
  for update using (id = auth.uid()) with check (id = auth.uid());
revoke all on public.profiles from anon, authenticated;
grant select, insert on public.profiles to authenticated;
grant update (full_name, phone, avatar_url, display_name, phone_e164, phone_verified, contact_email, preferred_language)
  on public.profiles to authenticated;

create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  key text not null unique check (key ~ '^[a-z0-9_-]{2,64}$'),
  label text not null check (char_length(btrim(label)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.subscription_plans (key, label)
values ('voucher', 'Voucher'), ('legacy', 'Akses existing')
on conflict (key) do nothing;

create table public.vouchers (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique check (code_hash ~ '^[a-f0-9]{64}$'),
  label text not null check (char_length(btrim(label)) > 0),
  plan_id uuid references public.subscription_plans(id) on delete set null,
  duration_days integer check (duration_days between 1 and 3660),
  ai_quota integer check (ai_quota between 1 and 10000),
  max_redemptions integer not null default 1 check (max_redemptions between 1 and 1000000),
  redemption_count integer not null default 0 check (redemption_count >= 0 and redemption_count <= max_redemptions),
  starts_at timestamptz,
  expires_at timestamptz,
  status text not null default 'active'
    check (status in ('active', 'inactive', 'expired', 'revoked')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (duration_days is not null or expires_at is not null),
  check (starts_at is null or expires_at is null or expires_at > starts_at)
);

create index vouchers_status_window_idx on public.vouchers (status, starts_at, expires_at);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  plan_id uuid references public.subscription_plans(id) on delete set null,
  source text not null check (source in ('voucher', 'midtrans', 'google_play', 'admin')),
  status text not null check (status in ('active', 'expired', 'cancelled', 'revoked')),
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  ai_quota integer check (ai_quota between 1 and 10000),
  voucher_id uuid references public.vouchers(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expires_at > started_at)
);

create index subscriptions_status_expiry_idx on public.subscriptions (status, expires_at);

-- The app previously granted all existing accounts access without a
-- subscription record. Preserve that access during this additive migration;
-- accounts created after this migration need a server-side access source.
insert into public.subscriptions (user_id, plan_id, source, status, started_at, expires_at)
select p.id, sp.id, 'admin', 'active', now(), timestamptz '2100-01-01 00:00:00+00'
from public.profiles p
cross join public.subscription_plans sp
where sp.key = 'legacy'
on conflict (user_id) do nothing;

create table public.voucher_redemptions (
  id uuid primary key default gen_random_uuid(),
  voucher_id uuid not null references public.vouchers(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete cascade,
  subscription_id uuid not null references public.subscriptions(id) on delete restrict,
  redeemed_at timestamptz not null default now(),
  expires_at timestamptz not null,
  unique (voucher_id, user_id)
);

create index voucher_redemptions_voucher_idx on public.voucher_redemptions (voucher_id, redeemed_at desc);
create index voucher_redemptions_user_idx on public.voucher_redemptions (user_id, redeemed_at desc);

create table public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references public.profiles(id) on delete restrict,
  action text not null check (action in (
    'CREATE_VOUCHER', 'UPDATE_VOUCHER', 'REVOKE_VOUCHER',
    'DISABLE_USER', 'ENABLE_USER', 'CHANGE_ROLE',
    'EXTEND_SUBSCRIPTION', 'CANCEL_SUBSCRIPTION', 'UPDATE_AI_CONFIG'
  )),
  target_type text not null check (char_length(btrim(target_type)) > 0),
  target_id text not null check (char_length(btrim(target_id)) > 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index admin_audit_logs_created_idx on public.admin_audit_logs (created_at desc);

alter table public.subscription_plans enable row level security;
alter table public.vouchers enable row level security;
alter table public.subscriptions enable row level security;
alter table public.voucher_redemptions enable row level security;
alter table public.admin_audit_logs enable row level security;

create trigger subscription_plans_updated_at before update on public.subscription_plans
  for each row execute function public.set_updated_at();
create trigger vouchers_updated_at before update on public.vouchers
  for each row execute function public.set_updated_at();
create trigger subscriptions_updated_at before update on public.subscriptions
  for each row execute function public.set_updated_at();

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and access_enabled
  );
$$;

create or replace function public.require_admin()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'Admin authorization required' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.write_admin_audit(
  p_action text,
  p_target_type text,
  p_target_id text,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.require_admin();
  insert into public.admin_audit_logs (admin_user_id, action, target_type, target_id, metadata)
  values (auth.uid(), p_action, p_target_type, p_target_id, coalesce(p_metadata, '{}'::jsonb));
end;
$$;

-- Read-only access decision for the signed-in account. Expired rows are never
-- treated as active even if a cleanup job has not run yet.
create or replace function public.get_current_access()
returns table (
  role text,
  access_enabled boolean,
  subscription_active boolean,
  subscription_expires_at timestamptz,
  plan_key text,
  source text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.role,
    p.access_enabled,
    coalesce(s.status = 'active' and s.expires_at > now(), false),
    s.expires_at,
    sp.key,
    s.source
  from public.profiles p
  left join public.subscriptions s on s.user_id = p.id
  left join public.subscription_plans sp on sp.id = s.plan_id
  where p.id = auth.uid();
$$;

-- Public validation intentionally exposes only a generic result and voucher
-- label. It does not expose redemption counts, user data, or code hashes.
create or replace function public.validate_voucher_code(p_code text)
returns table (valid boolean, reason text, label text)
language plpgsql
security definer
set search_path = public
as $$
declare
  voucher_row public.vouchers%rowtype;
begin
  if p_code is null or char_length(btrim(p_code)) < 4 then
    return query select false, 'invalid', null::text; return;
  end if;
  select * into voucher_row
  from public.vouchers
  where code_hash = encode(digest(upper(btrim(p_code)), 'sha256'), 'hex');
  if not found then return query select false, 'invalid', null::text; return; end if;
  if voucher_row.status <> 'active' then return query select false, 'inactive', null::text; return; end if;
  if voucher_row.starts_at is not null and voucher_row.starts_at > now() then
    return query select false, 'not_started', null::text; return;
  end if;
  if voucher_row.expires_at is not null and voucher_row.expires_at <= now() then
    return query select false, 'expired', null::text; return;
  end if;
  if voucher_row.redemption_count >= voucher_row.max_redemptions then
    return query select false, 'exhausted', null::text; return;
  end if;
  return query select true, null::text, voucher_row.label;
end;
$$;

create or replace function public.redeem_voucher(p_code text)
returns table (subscription_expires_at timestamptz, plan_key text, ai_quota integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  voucher_row public.vouchers%rowtype;
  subscription_row public.subscriptions%rowtype;
  resolved_plan_id uuid;
  resolved_plan_key text;
  resolved_expiry timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if p_code is null or char_length(btrim(p_code)) < 4 then
    raise exception 'Voucher tidak valid' using errcode = '22023';
  end if;

  select * into voucher_row
  from public.vouchers
  where code_hash = encode(digest(upper(btrim(p_code)), 'sha256'), 'hex')
  for update;
  if not found then raise exception 'Voucher tidak valid' using errcode = '22023'; end if;
  if voucher_row.status <> 'active' then raise exception 'Voucher tidak aktif' using errcode = '22023'; end if;
  if voucher_row.starts_at is not null and voucher_row.starts_at > now() then
    raise exception 'Voucher belum dapat digunakan' using errcode = '22023';
  end if;
  if voucher_row.expires_at is not null and voucher_row.expires_at <= now() then
    raise exception 'Voucher telah berakhir' using errcode = '22023';
  end if;
  if voucher_row.redemption_count >= voucher_row.max_redemptions then
    raise exception 'Voucher telah habis digunakan' using errcode = '22023';
  end if;
  if exists (
    select 1 from public.voucher_redemptions
    where voucher_id = voucher_row.id and user_id = auth.uid()
  ) then
    raise exception 'Voucher sudah pernah digunakan akun ini' using errcode = '23505';
  end if;

  select id, key into resolved_plan_id, resolved_plan_key
  from public.subscription_plans
  where id = voucher_row.plan_id or (voucher_row.plan_id is null and key = 'voucher')
  order by (id = voucher_row.plan_id) desc
  limit 1;
  if resolved_plan_id is null then raise exception 'Paket voucher tidak tersedia'; end if;

  resolved_expiry := case
    when voucher_row.duration_days is not null then now() + make_interval(days => voucher_row.duration_days)
    else voucher_row.expires_at
  end;

  insert into public.subscriptions (
    user_id, plan_id, source, status, started_at, expires_at, ai_quota, voucher_id
  ) values (
    auth.uid(), resolved_plan_id, 'voucher', 'active', now(), resolved_expiry,
    voucher_row.ai_quota, voucher_row.id
  )
  on conflict (user_id) do update set
    plan_id = excluded.plan_id,
    source = excluded.source,
    status = excluded.status,
    started_at = excluded.started_at,
    expires_at = excluded.expires_at,
    ai_quota = excluded.ai_quota,
    voucher_id = excluded.voucher_id,
    updated_at = now()
  returning * into subscription_row;

  insert into public.voucher_redemptions (voucher_id, user_id, subscription_id, expires_at)
  values (voucher_row.id, auth.uid(), subscription_row.id, resolved_expiry);
  update public.vouchers set redemption_count = redemption_count + 1, updated_at = now()
  where id = voucher_row.id;

  return query select resolved_expiry, resolved_plan_key, voucher_row.ai_quota;
end;
$$;

-- Voucher quota caps the existing reservation mechanism; it never creates a
-- second quota log and cannot raise the global server-side limit.
create or replace function public.reserve_ai_quota(p_user_id uuid, p_daily_limit integer, p_rate_limit_per_minute integer)
returns table (allowed boolean, reservation_id uuid, denial_reason text)
language plpgsql security definer set search_path = public as $$
declare
  used_count integer;
  rate_count integer;
  new_reservation uuid;
  effective_daily_limit integer;
begin
  select least(
    p_daily_limit,
    coalesce((
      select s.ai_quota from public.subscriptions s
      where s.user_id = p_user_id and s.status = 'active' and s.expires_at > now()
      order by s.updated_at desc limit 1
    ), p_daily_limit)
  ) into effective_daily_limit;
  perform pg_advisory_xact_lock(hashtextextended('ai-quota:' || p_user_id::text || ':' || current_date::text, 0));
  update public.ai_quota_reservations set status = 'released'
  where user_id = p_user_id and request_day = current_date and status = 'reserved' and expires_at <= now();
  select count(*) into used_count from public.ai_quota_reservations
  where user_id = p_user_id and request_day = current_date
    and (status = 'completed' or (status = 'reserved' and expires_at > now()));
  if used_count >= effective_daily_limit then return query select false, null::uuid, 'quota'; return; end if;
  select count(*) into rate_count from public.ai_quota_reservations
  where user_id = p_user_id and created_at >= now() - interval '1 minute'
    and (status = 'completed' or (status = 'reserved' and expires_at > now()));
  if rate_count >= p_rate_limit_per_minute then return query select false, null::uuid, 'rate_limit'; return; end if;
  insert into public.ai_quota_reservations (user_id, expires_at)
  values (p_user_id, now() + interval '2 minutes') returning id into new_reservation;
  return query select true, new_reservation, null::text;
end;
$$;

create or replace function public.admin_dashboard_metrics()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with _admin as (select public.require_admin() as checked), ai as (
    select
      count(*) filter (where created_at >= current_date) as today_requests,
      count(*) filter (where created_at >= date_trunc('month', now())) as month_requests,
      coalesce(sum(input_tokens) filter (where created_at >= date_trunc('month', now())), 0) as input_tokens,
      coalesce(sum(cached_tokens) filter (where created_at >= date_trunc('month', now())), 0) as cached_tokens,
      coalesce(sum(output_tokens) filter (where created_at >= date_trunc('month', now())), 0) as output_tokens,
      coalesce(sum(total_tokens) filter (where created_at >= date_trunc('month', now())), 0) as total_tokens,
      coalesce(sum(estimated_cost_usd) filter (where created_at >= date_trunc('month', now())), 0) as cost_usd,
      count(*) filter (where status = 'error' and created_at >= date_trunc('month', now())) as errors
    from public.ai_usage_logs
  )
  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles),
    'active_users', (select count(*) from public.profiles where access_enabled),
    'new_users_today', (select count(*) from public.profiles where created_at >= current_date),
    'new_users_month', (select count(*) from public.profiles where created_at >= date_trunc('month', now())),
    'total_businesses', (select count(*) from public.businesses),
    'active_subscriptions', (select count(*) from public.subscriptions where status = 'active' and expires_at > now()),
    'expired_subscriptions', (select count(*) from public.subscriptions where status <> 'active' or expires_at <= now()),
    'total_vouchers', (select count(*) from public.vouchers),
    'active_vouchers', (select count(*) from public.vouchers where status = 'active' and (starts_at is null or starts_at <= now()) and (expires_at is null or expires_at > now())),
    'redeemed_vouchers', (select count(*) from public.voucher_redemptions),
    'provider', (select provider from public.ai_system_config where id),
    'model', (select default_model from public.ai_system_config where id),
    'daily_ai_limit', (select daily_ai_limit from public.ai_system_config where id),
    'rate_limit_per_minute', (select ai_rate_limit_per_minute from public.ai_system_config where id),
    'ai', (select to_jsonb(ai) from ai)
  ) from ai cross join _admin;
$$;

create or replace function public.admin_list_users(
  p_search text default null,
  p_role text default null,
  p_subscription_status text default null,
  p_limit integer default 30,
  p_offset integer default 0
)
returns table (
  id uuid, name text, email text, phone text, role text, access_enabled boolean,
  created_at timestamptz, business_count bigint, subscription_status text,
  subscription_expires_at timestamptz, ai_request_count bigint, ai_cost_usd numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select rows.* from (
    select p.id,
      coalesce(nullif(p.display_name, ''), nullif(p.full_name, ''), 'Tanpa nama') as name,
      u.email, p.phone_e164 as phone, p.role, p.access_enabled, p.created_at,
      (select count(*) from public.business_members bm where bm.user_id = p.id) as business_count,
      s.status as subscription_status, s.expires_at as subscription_expires_at,
      (select count(*) from public.ai_usage_logs l where l.user_id = p.id) as ai_request_count,
      (select coalesce(sum(l.estimated_cost_usd), 0) from public.ai_usage_logs l where l.user_id = p.id) as ai_cost_usd
    from public.profiles p
    join auth.users u on u.id = p.id
    left join public.subscriptions s on s.user_id = p.id
  ) rows
  cross join (select public.require_admin() as checked) _admin
  where (p_search is null or name ilike '%' || p_search || '%' or email ilike '%' || p_search || '%')
    and (p_role is null or role = p_role)
    and (p_subscription_status is null or subscription_status = p_subscription_status)
  order by created_at desc
  limit greatest(1, least(p_limit, 100)) offset greatest(p_offset, 0);
$$;

create or replace function public.admin_set_user_role(p_user_id uuid, p_role text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  if p_role not in ('user', 'admin') then raise exception 'Role tidak valid'; end if;
  if p_user_id = auth.uid() and p_role <> 'admin' then raise exception 'Admin tidak dapat menurunkan role sendiri'; end if;
  update public.profiles set role = p_role where id = p_user_id;
  if not found then raise exception 'User tidak ditemukan'; end if;
  perform public.write_admin_audit('CHANGE_ROLE', 'profile', p_user_id::text, jsonb_build_object('role', p_role));
end;
$$;

create or replace function public.admin_set_user_access(p_user_id uuid, p_enabled boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  if p_user_id = auth.uid() and not p_enabled then raise exception 'Admin tidak dapat menonaktifkan diri sendiri'; end if;
  update public.profiles set access_enabled = p_enabled where id = p_user_id;
  if not found then raise exception 'User tidak ditemukan'; end if;
  perform public.write_admin_audit(case when p_enabled then 'ENABLE_USER' else 'DISABLE_USER' end, 'profile', p_user_id::text);
end;
$$;

create or replace function public.admin_list_vouchers(p_limit integer default 50, p_offset integer default 0)
returns table (
  id uuid, label text, status text, duration_days integer, ai_quota integer,
  max_redemptions integer, redemption_count integer, starts_at timestamptz,
  expires_at timestamptz, created_at timestamptz, plan_key text
)
language sql stable security definer set search_path = public as $$
  select v.id, v.label,
    case when v.status = 'active' and v.expires_at is not null and v.expires_at <= now() then 'expired' else v.status end,
    v.duration_days, v.ai_quota, v.max_redemptions, v.redemption_count,
    v.starts_at, v.expires_at, v.created_at, sp.key
  from public.vouchers v
  left join public.subscription_plans sp on sp.id = v.plan_id
  cross join (select public.require_admin() as checked) _admin
  order by v.created_at desc
  limit greatest(1, least(p_limit, 100)) offset greatest(p_offset, 0);
$$;

create or replace function public.admin_create_voucher(
  p_code text, p_label text, p_duration_days integer default null,
  p_ai_quota integer default null, p_max_redemptions integer default 1,
  p_starts_at timestamptz default null, p_expires_at timestamptz default null,
  p_plan_key text default 'voucher'
)
returns uuid
language plpgsql security definer set search_path = public as $$
declare new_id uuid; resolved_plan uuid;
begin
  perform public.require_admin();
  if p_code is null or upper(btrim(p_code)) !~ '^[A-Z0-9_-]{4,64}$' then raise exception 'Format kode voucher tidak valid'; end if;
  if p_duration_days is null and p_expires_at is null then raise exception 'Voucher membutuhkan durasi atau tanggal berakhir'; end if;
  select id into resolved_plan from public.subscription_plans where key = coalesce(p_plan_key, 'voucher');
  if resolved_plan is null then raise exception 'Paket tidak ditemukan'; end if;
  insert into public.vouchers (code_hash, label, plan_id, duration_days, ai_quota, max_redemptions, starts_at, expires_at, created_by)
  values (encode(digest(upper(btrim(p_code)), 'sha256'), 'hex'), btrim(p_label), resolved_plan, p_duration_days, p_ai_quota, p_max_redemptions, p_starts_at, p_expires_at, auth.uid())
  returning id into new_id;
  perform public.write_admin_audit('CREATE_VOUCHER', 'voucher', new_id::text);
  return new_id;
end;
$$;

create or replace function public.admin_set_voucher_status(p_voucher_id uuid, p_status text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  if p_status not in ('active', 'inactive', 'revoked') then raise exception 'Status voucher tidak valid'; end if;
  update public.vouchers set status = p_status where id = p_voucher_id;
  if not found then raise exception 'Voucher tidak ditemukan'; end if;
  perform public.write_admin_audit(
    case when p_status = 'revoked' then 'REVOKE_VOUCHER' else 'UPDATE_VOUCHER' end,
    'voucher', p_voucher_id::text, jsonb_build_object('status', p_status)
  );
end;
$$;

create or replace function public.admin_ai_usage_summary()
returns jsonb
language sql stable security definer set search_path = public as $$
  with _admin as (select public.require_admin() as checked)
  select jsonb_build_object(
    'today_requests', count(*) filter (where created_at >= current_date),
    'week_requests', count(*) filter (where created_at >= current_date - interval '6 days'),
    'month_requests', count(*) filter (where created_at >= date_trunc('month', now())),
    'success', count(*) filter (where status = 'success'),
    'errors', count(*) filter (where status = 'error'),
    'input_tokens', coalesce(sum(input_tokens), 0),
    'cached_tokens', coalesce(sum(cached_tokens), 0),
    'output_tokens', coalesce(sum(output_tokens), 0),
    'total_tokens', coalesce(sum(total_tokens), 0),
    'estimated_cost_usd', coalesce(sum(estimated_cost_usd), 0),
    'quota_exhausted', (select count(*) from public.ai_quota_reservations where request_day = current_date and status in ('reserved','completed'))
  ) from public.ai_usage_logs cross join _admin;
$$;

-- No direct table access is granted. RPCs explicitly expose only the required
-- data and verify auth.uid()/role on every sensitive operation.
revoke all on table public.subscription_plans, public.vouchers, public.subscriptions,
  public.voucher_redemptions, public.admin_audit_logs from anon, authenticated;
revoke all on function public.is_admin(), public.require_admin(), public.write_admin_audit(text, text, text, jsonb) from public;
revoke all on function public.get_current_access(), public.redeem_voucher(text),
  public.admin_dashboard_metrics(), public.admin_list_users(text, text, text, integer, integer),
  public.admin_set_user_role(uuid, text), public.admin_set_user_access(uuid, boolean),
  public.admin_list_vouchers(integer, integer), public.admin_create_voucher(text, text, integer, integer, integer, timestamptz, timestamptz, text),
  public.admin_set_voucher_status(uuid, text), public.admin_ai_usage_summary() from public;
grant execute on function public.get_current_access() to authenticated;
grant execute on function public.redeem_voucher(text) to authenticated;
grant execute on function public.validate_voucher_code(text) to anon, authenticated;
grant execute on function public.admin_dashboard_metrics(), public.admin_list_users(text, text, text, integer, integer),
  public.admin_set_user_role(uuid, text), public.admin_set_user_access(uuid, boolean),
  public.admin_list_vouchers(integer, integer), public.admin_create_voucher(text, text, integer, integer, integer, timestamptz, timestamptz, text),
  public.admin_set_voucher_status(uuid, text), public.admin_ai_usage_summary() to authenticated;
