-- Server-only infrastructure for AI configuration, quota, cache coordination,
-- and observability. There are intentionally no client-facing RLS policies.

create table public.ai_system_config (
  id boolean primary key default true check (id),
  prompt_caching_enabled boolean not null default true,
  prompt_cache_ttl_seconds integer not null default 3600 check (prompt_cache_ttl_seconds between 300 and 86400),
  default_model text not null default 'gemini-3.6-flash' check (char_length(trim(default_model)) > 0),
  max_output_tokens integer not null default 800 check (max_output_tokens between 64 and 8192),
  daily_ai_limit integer not null default 20 check (daily_ai_limit between 1 and 10000),
  ai_rate_limit_per_minute integer not null default 6 check (ai_rate_limit_per_minute between 1 and 120),
  updated_at timestamptz not null default now()
);

insert into public.ai_system_config (id) values (true) on conflict (id) do nothing;

create table public.ai_model_pricing (
  model text primary key,
  input_per_million_usd numeric(12, 6),
  cached_input_per_million_usd numeric(12, 6),
  output_per_million_usd numeric(12, 6),
  updated_at timestamptz not null default now(),
  check (input_per_million_usd is null or input_per_million_usd >= 0),
  check (cached_input_per_million_usd is null or cached_input_per_million_usd >= 0),
  check (output_per_million_usd is null or output_per_million_usd >= 0)
);

create table public.ai_prompt_caches (
  cache_key text primary key,
  cache_name text,
  model text not null,
  cache_status text not null check (cache_status in ('creating', 'ready', 'unavailable')),
  expires_at timestamptz,
  lock_expires_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.ai_quota_reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  request_day date not null default current_date,
  status text not null default 'reserved' check (status in ('reserved', 'completed', 'released')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index ai_quota_reservations_active_idx on public.ai_quota_reservations (user_id, request_day, expires_at) where status = 'reserved';
create index ai_quota_reservations_user_day_status_idx on public.ai_quota_reservations (user_id, request_day, status);
create index ai_quota_reservations_user_created_idx on public.ai_quota_reservations (user_id, created_at desc) where status in ('reserved', 'completed');

create table public.ai_usage_logs (
  id uuid primary key default gen_random_uuid(),
  reservation_id uuid unique references public.ai_quota_reservations(id) on delete set null,
  user_id uuid not null references auth.users(id) on delete cascade,
  business_id uuid references public.businesses(id) on delete set null,
  feature text not null,
  model text not null,
  prompt_version integer not null,
  schema_version integer not null,
  cache_used boolean not null default false,
  cache_status text not null,
  input_tokens integer,
  cached_tokens integer,
  output_tokens integer,
  total_tokens integer,
  estimated_cost_usd numeric(16, 8),
  status text not null check (status in ('success', 'error')),
  latency_ms integer not null check (latency_ms >= 0),
  created_at timestamptz not null default now(),
  check (input_tokens is null or input_tokens >= 0),
  check (cached_tokens is null or cached_tokens >= 0),
  check (output_tokens is null or output_tokens >= 0),
  check (total_tokens is null or total_tokens >= 0),
  check (estimated_cost_usd is null or estimated_cost_usd >= 0)
);
create index ai_usage_logs_user_created_idx on public.ai_usage_logs (user_id, created_at desc);
create index ai_usage_logs_feature_created_idx on public.ai_usage_logs (feature, created_at desc);

alter table public.ai_system_config enable row level security;
alter table public.ai_model_pricing enable row level security;
alter table public.ai_prompt_caches enable row level security;
alter table public.ai_quota_reservations enable row level security;
alter table public.ai_usage_logs enable row level security;

create trigger ai_system_config_updated_at before update on public.ai_system_config for each row execute function public.set_updated_at();
create trigger ai_model_pricing_updated_at before update on public.ai_model_pricing for each row execute function public.set_updated_at();
create trigger ai_prompt_caches_updated_at before update on public.ai_prompt_caches for each row execute function public.set_updated_at();

create or replace function public.reserve_ai_quota(p_user_id uuid, p_daily_limit integer, p_rate_limit_per_minute integer)
returns table (allowed boolean, reservation_id uuid, denial_reason text)
language plpgsql security definer set search_path = public as $$
declare
  used_count integer;
  rate_count integer;
  new_reservation uuid;
begin
  perform pg_advisory_xact_lock(hashtextextended('ai-quota:' || p_user_id::text || ':' || current_date::text, 0));
  update public.ai_quota_reservations
  set status = 'released'
  where user_id = p_user_id and request_day = current_date and status = 'reserved' and expires_at <= now();

  select count(*) from public.ai_quota_reservations
  where user_id = p_user_id and request_day = current_date
    and (status = 'completed' or (status = 'reserved' and expires_at > now()))
  into used_count;
  if used_count >= p_daily_limit then return query select false, null::uuid, 'quota'; return; end if;
  select count(*) from public.ai_quota_reservations
  where user_id = p_user_id and created_at >= now() - interval '1 minute'
    and (status = 'completed' or (status = 'reserved' and expires_at > now()))
  into rate_count;
  if rate_count >= p_rate_limit_per_minute then return query select false, null::uuid, 'rate_limit'; return; end if;

  insert into public.ai_quota_reservations (user_id, expires_at)
  values (p_user_id, now() + interval '2 minutes') returning id into new_reservation;
  return query select true, new_reservation, null::text;
end;
$$;

create or replace function public.finish_ai_quota_reservation(p_reservation_id uuid, p_success boolean)
returns void language sql security definer set search_path = public as $$
  update public.ai_quota_reservations
  set status = case when p_success then 'completed' else 'released' end
  where id = p_reservation_id and status = 'reserved';
$$;

create or replace function public.claim_ai_prompt_cache(p_cache_key text, p_model text, p_force boolean default false)
returns table (state text, cache_name text, expires_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare
  cache_row public.ai_prompt_caches%rowtype;
  inserted_rows integer;
begin
  insert into public.ai_prompt_caches (cache_key, model, cache_status, lock_expires_at)
  values (p_cache_key, p_model, 'creating', now() + interval '45 seconds')
  on conflict (cache_key) do nothing;
  get diagnostics inserted_rows = row_count;
  if inserted_rows > 0 then
    return query select 'creator', null::text, null::timestamptz; return;
  end if;
  select * into cache_row from public.ai_prompt_caches where cache_key = p_cache_key for update;

  if cache_row.cache_status = 'creating' and cache_row.lock_expires_at > now() then
    return query select 'waiting', null::text, cache_row.lock_expires_at; return;
  end if;
  if not p_force and cache_row.cache_status = 'ready' and cache_row.model = p_model and cache_row.expires_at > now() then
    return query select 'ready', cache_row.cache_name, cache_row.expires_at; return;
  end if;
  if not p_force and cache_row.cache_status = 'unavailable' and cache_row.lock_expires_at > now() then
    return query select 'unavailable', null::text, cache_row.lock_expires_at; return;
  end if;
  update public.ai_prompt_caches
  set model = p_model, cache_status = 'creating', cache_name = null, expires_at = null, lock_expires_at = now() + interval '45 seconds'
  where cache_key = p_cache_key;
  return query select 'creator', null::text, null::timestamptz;
end;
$$;

revoke all on function public.reserve_ai_quota(uuid, integer, integer) from public;
revoke all on function public.finish_ai_quota_reservation(uuid, boolean) from public;
revoke all on function public.claim_ai_prompt_cache(text, text, boolean) from public;
grant execute on function public.reserve_ai_quota(uuid, integer, integer) to service_role;
grant execute on function public.finish_ai_quota_reservation(uuid, boolean) to service_role;
grant execute on function public.claim_ai_prompt_cache(text, text, boolean) to service_role;
