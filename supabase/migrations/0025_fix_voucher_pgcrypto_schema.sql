-- Production installs pgcrypto in the `extensions` schema while the voucher
-- RPCs deliberately run with `search_path = public`. Qualify digest directly
-- instead of broadening a SECURITY DEFINER function's search path. This keeps
-- the SHA-256 hex hash format and every existing function contract unchanged.

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
  where code_hash = encode(extensions.digest(upper(btrim(p_code)), 'sha256'), 'hex');
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
  where code_hash = encode(extensions.digest(upper(btrim(p_code)), 'sha256'), 'hex')
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

create or replace function public.admin_create_voucher(
  p_code text, p_label text, p_duration_days integer default null,
  p_ai_quota integer default null, p_max_redemptions integer default 1,
  p_starts_at timestamptz default null, p_expires_at timestamptz default null,
  p_plan_key text default 'voucher'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare new_id uuid; resolved_plan uuid;
begin
  perform public.require_admin();
  if p_code is null or upper(btrim(p_code)) !~ '^[A-Z0-9_-]{4,64}$' then raise exception 'Format kode voucher tidak valid'; end if;
  if p_duration_days is null and p_expires_at is null then raise exception 'Voucher membutuhkan durasi atau tanggal berakhir'; end if;
  select id into resolved_plan from public.subscription_plans where key = coalesce(p_plan_key, 'voucher');
  if resolved_plan is null then raise exception 'Paket tidak ditemukan'; end if;
  insert into public.vouchers (code_hash, label, plan_id, duration_days, ai_quota, max_redemptions, starts_at, expires_at, created_by)
  values (encode(extensions.digest(upper(btrim(p_code)), 'sha256'), 'hex'), btrim(p_label), resolved_plan, p_duration_days, p_ai_quota, p_max_redemptions, p_starts_at, p_expires_at, auth.uid())
  returning id into new_id;
  perform public.write_admin_audit('CREATE_VOUCHER', 'voucher', new_id::text);
  return new_id;
end;
$$;
