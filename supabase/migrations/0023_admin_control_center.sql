-- Admin control-center additions. This migration is deliberately additive to
-- 0022 and must be reviewed/applied manually with the normal Supabase flow.

alter table public.admin_audit_logs
  drop constraint if exists admin_audit_logs_action_check;
alter table public.admin_audit_logs
  add constraint admin_audit_logs_action_check check (action in (
    'CREATE_VOUCHER', 'UPDATE_VOUCHER', 'REVOKE_VOUCHER',
    'DISABLE_USER', 'ENABLE_USER', 'CHANGE_ROLE',
    'ACTIVATE_SUBSCRIPTION', 'EXTEND_SUBSCRIPTION',
    'CANCEL_SUBSCRIPTION', 'REVOKE_SUBSCRIPTION', 'UPDATE_AI_CONFIG'
  ));

create table public.app_error_logs (
  id uuid primary key default gen_random_uuid(),
  source text not null check (source in ('flutter', 'edge_function', 'rpc')),
  error_code text not null check (error_code ~ '^[A-Z0-9_.-]{1,96}$'),
  safe_message text not null check (char_length(safe_message) between 1 and 500),
  feature text not null check (char_length(feature) between 1 and 96),
  user_id uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  resolved boolean not null default false,
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id) on delete set null,
  check ((not resolved and resolved_at is null and resolved_by is null) or resolved)
);
create index app_error_logs_admin_idx on public.app_error_logs (resolved, created_at desc);
create index app_error_logs_feature_idx on public.app_error_logs (feature, created_at desc);
alter table public.app_error_logs enable row level security;

create or replace function public.admin_dashboard_metrics()
returns jsonb
language sql stable security definer set search_path = public as $$
  with _admin as (select public.require_admin() as checked), ai as (
    select count(*) filter (where created_at >= current_date) as today_requests,
      count(*) filter (where created_at >= date_trunc('month', now())) as month_requests,
      count(*) filter (where status = 'success' and created_at >= date_trunc('month', now())) as success,
      count(*) filter (where status = 'error' and created_at >= date_trunc('month', now())) as errors,
      coalesce(sum(input_tokens) filter (where created_at >= date_trunc('month', now())), 0) as input_tokens,
      coalesce(sum(cached_tokens) filter (where created_at >= date_trunc('month', now())), 0) as cached_tokens,
      coalesce(sum(output_tokens) filter (where created_at >= date_trunc('month', now())), 0) as output_tokens,
      coalesce(sum(total_tokens) filter (where created_at >= date_trunc('month', now())), 0) as total_tokens,
      coalesce(sum(estimated_cost_usd) filter (where created_at >= date_trunc('month', now())), 0) as cost_usd
    from public.ai_usage_logs
  )
  select jsonb_build_object(
    'total_users', (select count(*) from public.profiles),
    'active_users', (select count(*) from public.profiles p join public.subscriptions s on s.user_id = p.id where p.access_enabled and s.status = 'active' and s.expires_at > now()),
    'disabled_users', (select count(*) from public.profiles where not access_enabled),
    'users_without_access', (select count(*) from public.profiles p left join public.subscriptions s on s.user_id = p.id where p.access_enabled and (s.id is null or s.status <> 'active' or s.expires_at <= now())),
    'new_users_today', (select count(*) from public.profiles where created_at >= current_date),
    'new_users_month', (select count(*) from public.profiles where created_at >= date_trunc('month', now())),
    'total_businesses', (select count(*) from public.businesses),
    'new_businesses_today', (select count(*) from public.businesses where created_at >= current_date),
    'active_subscriptions', (select count(*) from public.subscriptions where status = 'active' and expires_at > now()),
    'expired_subscriptions', (select count(*) from public.subscriptions where status <> 'active' or expires_at <= now()),
    'pending_subscriptions', 0,
    'cancelled_subscriptions', (select count(*) from public.subscriptions where status = 'cancelled'),
    'voucher_subscriptions', (select count(*) from public.subscriptions where source = 'voucher'),
    'admin_subscriptions', (select count(*) from public.subscriptions where source = 'admin'),
    'total_vouchers', (select count(*) from public.vouchers),
    'active_vouchers', (select count(*) from public.vouchers where status = 'active' and (starts_at is null or starts_at <= now()) and (expires_at is null or expires_at > now())),
    'inactive_vouchers', (select count(*) from public.vouchers where status = 'inactive'),
    'expired_vouchers', (select count(*) from public.vouchers where status = 'expired' or (status = 'active' and expires_at is not null and expires_at <= now())),
    'revoked_vouchers', (select count(*) from public.vouchers where status = 'revoked'),
    'redeemed_vouchers', (select count(*) from public.voucher_redemptions),
    'redemptions_today', (select count(*) from public.voucher_redemptions where redeemed_at >= current_date),
    'remaining_redemptions', (select coalesce(sum(max_redemptions - redemption_count), 0) from public.vouchers where status = 'active'),
    'provider', (select provider from public.ai_system_config where id),
    'model', (select default_model from public.ai_system_config where id),
    'daily_ai_limit', (select daily_ai_limit from public.ai_system_config where id),
    'rate_limit_per_minute', (select ai_rate_limit_per_minute from public.ai_system_config where id),
    'ai', jsonb_build_object('today_requests', ai.today_requests, 'month_requests', ai.month_requests,
      'success', ai.success, 'errors', ai.errors, 'fallback', 0,
      'quota_exhausted', (select count(*) from public.ai_quota_reservations where request_day = current_date and status in ('reserved', 'completed')),
      'input_tokens', ai.input_tokens, 'cached_tokens', ai.cached_tokens, 'output_tokens', ai.output_tokens,
      'total_tokens', ai.total_tokens, 'estimated_cost_usd', ai.cost_usd)
  ) from ai cross join _admin;
$$;

-- The client may report a bounded, deliberately safe technical event. Tokens,
-- credentials and raw exception payloads are rejected rather than persisted.
create or replace function public.report_app_error(
  p_source text, p_error_code text, p_safe_message text, p_feature text
)
returns void
language plpgsql security definer set search_path = public as $$
declare
  message_value text := left(btrim(coalesce(p_safe_message, '')), 500);
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;
  if p_source not in ('flutter', 'edge_function', 'rpc')
    or coalesce(p_error_code, '') !~ '^[A-Z0-9_.-]{1,96}$'
    or char_length(coalesce(p_feature, '')) not between 1 and 96
    or message_value = '' then
    raise exception 'Invalid error report' using errcode = '22023';
  end if;
  if message_value ~* '(authorization|bearer[[:space:]]|refresh[[:space:]_-]?token|service[_-]?role|api[_-]?key|password|secret|card[_ -]?(number|token))' then
    raise exception 'Sensitive error report rejected' using errcode = '22023';
  end if;
  insert into public.app_error_logs (source, error_code, safe_message, feature, user_id)
  values (p_source, p_error_code, message_value, btrim(p_feature), auth.uid());
end;
$$;

create or replace function public.admin_list_users_v2(
  p_search text default null, p_status text default null, p_role text default null,
  p_limit integer default 30, p_offset integer default 0
)
returns table (
  id uuid, name text, email text, role text, access_enabled boolean,
  created_at timestamptz, access_status text, plan_key text, source text,
  started_at timestamptz, expires_at timestamptz, remaining_days integer,
  voucher_label text, business_count bigint, ai_request_count bigint,
  ai_cost_usd numeric, last_activity timestamptz
)
language sql stable security definer set search_path = public as $$
  with rows as (
    select p.id,
      coalesce(nullif(p.display_name, ''), nullif(p.full_name, ''), 'Tanpa nama') as name,
      u.email, p.role, p.access_enabled, p.created_at,
      case
        when not p.access_enabled then 'DISABLED'
        when s.status = 'active' and s.expires_at > now() then 'ACTIVE'
        when s.id is not null then 'EXPIRED'
        else 'NO_ACCESS'
      end as access_status,
      sp.key as plan_key, s.source, s.started_at, s.expires_at,
      case when s.status = 'active' and s.expires_at > now()
        then greatest(0, ceil(extract(epoch from (s.expires_at - now())) / 86400.0)::integer)
      end as remaining_days,
      v.label as voucher_label,
      (select count(*) from public.business_members bm where bm.user_id = p.id) as business_count,
      (select count(*) from public.ai_usage_logs l where l.user_id = p.id) as ai_request_count,
      (select coalesce(sum(l.estimated_cost_usd), 0) from public.ai_usage_logs l where l.user_id = p.id) as ai_cost_usd,
      greatest(p.updated_at, s.updated_at, (select max(l.created_at) from public.ai_usage_logs l where l.user_id = p.id)) as last_activity
    from public.profiles p
    join auth.users u on u.id = p.id
    left join public.subscriptions s on s.user_id = p.id
    left join public.subscription_plans sp on sp.id = s.plan_id
    left join public.vouchers v on v.id = s.voucher_id
  )
  select rows.* from rows cross join (select public.require_admin() as checked) _admin
  where (p_search is null or name ilike '%' || btrim(p_search) || '%' or email ilike '%' || btrim(p_search) || '%')
    and (p_role is null or role = p_role)
    and (p_status is null or access_status = p_status)
  order by created_at desc
  limit greatest(1, least(p_limit, 100)) offset greatest(p_offset, 0);
$$;

create or replace function public.admin_list_subscriptions(
  p_status text default null, p_limit integer default 50, p_offset integer default 0
)
returns table (
  id uuid, user_id uuid, name text, email text, plan_key text, source text,
  status text, started_at timestamptz, expires_at timestamptz,
  remaining_days integer, voucher_label text
)
language sql stable security definer set search_path = public as $$
  select s.id, s.user_id,
    coalesce(nullif(p.display_name, ''), nullif(p.full_name, ''), 'Tanpa nama'), u.email,
    sp.key, s.source, s.status, s.started_at, s.expires_at,
    case when s.status = 'active' and s.expires_at > now()
      then greatest(0, ceil(extract(epoch from (s.expires_at - now())) / 86400.0)::integer) end,
    v.label
  from public.subscriptions s
  join public.profiles p on p.id = s.user_id
  join auth.users u on u.id = s.user_id
  left join public.subscription_plans sp on sp.id = s.plan_id
  left join public.vouchers v on v.id = s.voucher_id
  cross join (select public.require_admin() as checked) _admin
  where p_status is null or s.status = p_status
  order by s.updated_at desc
  limit greatest(1, least(p_limit, 100)) offset greatest(p_offset, 0);
$$;

create or replace function public.admin_user_detail(p_user_id uuid)
returns jsonb
language sql stable security definer set search_path = public as $$
  with _admin as (select public.require_admin() as checked), profile_row as (
    select p.id, coalesce(nullif(p.display_name, ''), nullif(p.full_name, ''), 'Tanpa nama') as name,
      u.email, p.role, p.access_enabled, p.created_at
    from public.profiles p join auth.users u on u.id = p.id where p.id = p_user_id
  )
  select jsonb_build_object(
    'profile', (select to_jsonb(profile_row) from profile_row),
    'subscription', (select to_jsonb(s) from (
      select sp.key as plan_key, s.source, s.status, s.started_at, s.expires_at, s.ai_quota, v.label as voucher_label
      from public.subscriptions s left join public.subscription_plans sp on sp.id = s.plan_id
      left join public.vouchers v on v.id = s.voucher_id where s.user_id = p_user_id
    ) s),
    'voucher_history', coalesce((select jsonb_agg(x order by x.redeemed_at desc) from (
      select v.label, r.redeemed_at, r.expires_at from public.voucher_redemptions r
      join public.vouchers v on v.id = r.voucher_id where r.user_id = p_user_id
    ) x), '[]'::jsonb),
    'ai_usage', (select jsonb_build_object('request_count', count(*), 'estimated_cost_usd', coalesce(sum(estimated_cost_usd), 0),
      'last_request', max(created_at)) from public.ai_usage_logs where user_id = p_user_id),
    'businesses', coalesce((select jsonb_agg(x order by x.created_at desc) from (
      select b.id, b.name, bm.role, b.created_at from public.business_members bm join public.businesses b on b.id = bm.business_id
      where bm.user_id = p_user_id
    ) x), '[]'::jsonb)
  ) from _admin;
$$;

create or replace function public.admin_activate_subscription(
  p_user_id uuid, p_plan_key text default 'voucher', p_duration_days integer default 30,
  p_ai_quota integer default null
)
returns void
language plpgsql security definer set search_path = public as $$
declare resolved_plan uuid;
begin
  perform public.require_admin();
  if p_duration_days not between 1 and 3660 then raise exception 'Durasi tidak valid' using errcode = '22023'; end if;
  select id into resolved_plan from public.subscription_plans where key = p_plan_key;
  if resolved_plan is null then raise exception 'Paket tidak ditemukan' using errcode = '22023'; end if;
  if not exists (select 1 from public.profiles where id = p_user_id) then raise exception 'User tidak ditemukan' using errcode = '22023'; end if;
  insert into public.subscriptions (user_id, plan_id, source, status, started_at, expires_at, ai_quota)
  values (p_user_id, resolved_plan, 'admin', 'active', now(), now() + make_interval(days => p_duration_days), p_ai_quota)
  on conflict (user_id) do update set plan_id = excluded.plan_id, source = 'admin', status = 'active',
    started_at = now(), expires_at = excluded.expires_at, ai_quota = excluded.ai_quota, voucher_id = null, updated_at = now();
  perform public.write_admin_audit('ACTIVATE_SUBSCRIPTION', 'subscription', p_user_id::text,
    jsonb_build_object('duration_days', p_duration_days, 'plan_key', p_plan_key));
end;
$$;

create or replace function public.admin_extend_subscription(p_user_id uuid, p_duration_days integer)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  if p_duration_days not between 1 and 3660 then raise exception 'Durasi tidak valid' using errcode = '22023'; end if;
  update public.subscriptions
  set status = 'active', source = 'admin',
      started_at = least(started_at, now()),
      expires_at = greatest(expires_at, now()) + make_interval(days => p_duration_days), updated_at = now()
  where user_id = p_user_id;
  if not found then raise exception 'Subscription tidak ditemukan; gunakan aktivasi manual' using errcode = '22023'; end if;
  perform public.write_admin_audit('EXTEND_SUBSCRIPTION', 'subscription', p_user_id::text,
    jsonb_build_object('duration_days', p_duration_days));
end;
$$;

create or replace function public.admin_set_subscription_status(p_user_id uuid, p_status text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  if p_status not in ('cancelled', 'revoked') then raise exception 'Status tidak valid' using errcode = '22023'; end if;
  update public.subscriptions set status = p_status, updated_at = now() where user_id = p_user_id;
  if not found then raise exception 'Subscription tidak ditemukan' using errcode = '22023'; end if;
  perform public.write_admin_audit(case when p_status = 'cancelled' then 'CANCEL_SUBSCRIPTION' else 'REVOKE_SUBSCRIPTION' end,
    'subscription', p_user_id::text);
end;
$$;

create or replace function public.admin_list_voucher_redemptions(p_voucher_id uuid, p_limit integer default 50, p_offset integer default 0)
returns table (id uuid, user_id uuid, name text, email text, redeemed_at timestamptz, expires_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.id, r.user_id, coalesce(nullif(p.display_name, ''), nullif(p.full_name, ''), 'Tanpa nama'),
    u.email, r.redeemed_at, r.expires_at
  from public.voucher_redemptions r join public.profiles p on p.id = r.user_id join auth.users u on u.id = r.user_id
  cross join (select public.require_admin() as checked) _admin
  where r.voucher_id = p_voucher_id order by r.redeemed_at desc
  limit greatest(1, least(p_limit, 100)) offset greatest(p_offset, 0);
$$;

create or replace function public.admin_list_ai_usage_users(
  p_from timestamptz default date_trunc('month', now()), p_to timestamptz default now(),
  p_limit integer default 50, p_offset integer default 0
)
returns table (user_id uuid, name text, email text, request_count bigint, last_request timestamptz,
  input_tokens bigint, cached_tokens bigint, output_tokens bigint, total_tokens bigint,
  estimated_cost_usd numeric, success_count bigint, error_count bigint)
language sql stable security definer set search_path = public as $$
  select l.user_id, coalesce(nullif(p.display_name, ''), nullif(p.full_name, ''), 'Tanpa nama'), u.email,
    count(*), max(l.created_at), coalesce(sum(l.input_tokens), 0), coalesce(sum(l.cached_tokens), 0),
    coalesce(sum(l.output_tokens), 0), coalesce(sum(l.total_tokens), 0), coalesce(sum(l.estimated_cost_usd), 0),
    count(*) filter (where l.status = 'success'), count(*) filter (where l.status = 'error')
  from public.ai_usage_logs l join public.profiles p on p.id = l.user_id join auth.users u on u.id = l.user_id
  cross join (select public.require_admin() as checked) _admin
  where l.created_at >= p_from and l.created_at < p_to
  group by l.user_id, p.display_name, p.full_name, u.email
  order by max(l.created_at) desc nulls last
  limit greatest(1, least(p_limit, 100)) offset greatest(p_offset, 0);
$$;

create or replace function public.admin_list_businesses(p_limit integer default 50, p_offset integer default 0)
returns table (id uuid, name text, owner_name text, owner_email text, created_at timestamptz,
  member_count bigint, product_count bigint, transaction_count bigint, active_features jsonb)
language sql stable security definer set search_path = public as $$
  select b.id, b.name, coalesce(nullif(p.display_name, ''), nullif(p.full_name, ''), 'Tanpa nama'), u.email, b.created_at,
    (select count(*) from public.business_members bm where bm.business_id = b.id),
    (select count(*) from public.products pr where pr.business_id = b.id),
    (select count(*) from public.transactions t where t.business_id = b.id),
    coalesce((
      select jsonb_agg(feature ->> 'key' order by feature ->> 'key')
      from public.business_configurations bc,
        lateral jsonb_array_elements(coalesce(
          bc.configuration -> 'recommendedFeatures', bc.configuration -> 'features', '[]'::jsonb
        )) feature
      where bc.business_id = b.id and coalesce((feature ->> 'enabled')::boolean, false)
    ), '[]'::jsonb)
  from public.businesses b join public.profiles p on p.id = b.owner_id join auth.users u on u.id = b.owner_id
  cross join (select public.require_admin() as checked) _admin
  order by b.created_at desc limit greatest(1, least(p_limit, 100)) offset greatest(p_offset, 0);
$$;

create or replace function public.admin_list_error_logs(
  p_resolved boolean default null, p_limit integer default 50, p_offset integer default 0
)
returns table (id uuid, source text, error_code text, safe_message text, feature text,
  user_id uuid, created_at timestamptz, resolved boolean, occurrences bigint)
language sql stable security definer set search_path = public as $$
  select e.id, e.source, e.error_code, e.safe_message, e.feature, e.user_id, e.created_at, e.resolved,
    count(*) over (partition by e.source, e.error_code, e.safe_message, e.feature, e.resolved) as occurrences
  from public.app_error_logs e cross join (select public.require_admin() as checked) _admin
  where p_resolved is null or e.resolved = p_resolved
  order by e.created_at desc limit greatest(1, least(p_limit, 100)) offset greatest(p_offset, 0);
$$;

create or replace function public.admin_set_error_resolved(p_error_id uuid, p_resolved boolean)
returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.require_admin();
  update public.app_error_logs set resolved = p_resolved,
    resolved_at = case when p_resolved then now() else null end,
    resolved_by = case when p_resolved then auth.uid() else null end
  where id = p_error_id;
  if not found then raise exception 'Error tidak ditemukan' using errcode = '22023'; end if;
end;
$$;

create or replace function public.admin_list_audit_logs(p_limit integer default 50, p_offset integer default 0)
returns table (id uuid, admin_user_id uuid, admin_name text, action text, target_type text, target_id text, metadata jsonb, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select a.id, a.admin_user_id, coalesce(nullif(p.display_name, ''), nullif(p.full_name, ''), 'Admin'),
    a.action, a.target_type, a.target_id, a.metadata, a.created_at
  from public.admin_audit_logs a join public.profiles p on p.id = a.admin_user_id
  cross join (select public.require_admin() as checked) _admin
  order by a.created_at desc limit greatest(1, least(p_limit, 100)) offset greatest(p_offset, 0);
$$;

revoke all on table public.app_error_logs from anon, authenticated;
revoke all on function public.report_app_error(text, text, text, text),
  public.admin_list_users_v2(text, text, text, integer, integer),
  public.admin_list_subscriptions(text, integer, integer),
  public.admin_user_detail(uuid),
  public.admin_activate_subscription(uuid, text, integer, integer), public.admin_extend_subscription(uuid, integer),
  public.admin_set_subscription_status(uuid, text), public.admin_list_voucher_redemptions(uuid, integer, integer),
  public.admin_list_ai_usage_users(timestamptz, timestamptz, integer, integer),
  public.admin_list_businesses(integer, integer), public.admin_list_error_logs(boolean, integer, integer),
  public.admin_set_error_resolved(uuid, boolean), public.admin_list_audit_logs(integer, integer) from public;
grant execute on function public.report_app_error(text, text, text, text) to authenticated;
grant execute on function public.admin_list_users_v2(text, text, text, integer, integer),
  public.admin_list_subscriptions(text, integer, integer),
  public.admin_user_detail(uuid),
  public.admin_activate_subscription(uuid, text, integer, integer), public.admin_extend_subscription(uuid, integer),
  public.admin_set_subscription_status(uuid, text), public.admin_list_voucher_redemptions(uuid, integer, integer),
  public.admin_list_ai_usage_users(timestamptz, timestamptz, integer, integer),
  public.admin_list_businesses(integer, integer), public.admin_list_error_logs(boolean, integer, integer),
  public.admin_set_error_resolved(uuid, boolean), public.admin_list_audit_logs(integer, integer) to authenticated;
