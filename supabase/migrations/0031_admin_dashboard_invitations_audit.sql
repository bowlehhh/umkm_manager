-- Complete platform-admin invitation and dashboard contracts. All functions
-- authorize through server-owned profiles.role and never expose token hashes.

create or replace function public.admin_list_invitations(
  p_status text default null,p_purpose text default null,p_search text default null,
  p_limit integer default 50,p_offset integer default 0
) returns table(
  id uuid,purpose text,business_id uuid,business_name text,business_role public.member_role,
  email text,status text,expires_at timestamptz,used_at timestamptz,used_by uuid,
  promotion_ends_at timestamptz,promotion_quota integer,reason text,created_at timestamptz,
  created_by uuid,created_by_name text
) language sql stable security definer set search_path=public as $$
  with rows as (
    select i.id,i.purpose,i.business_id,b.name business_name,i.business_role,
      i.email_normalized email,
      case when i.revoked_at is not null then 'REVOKED'
        when i.used_at is not null then 'USED'
        when i.expires_at<=now() then 'EXPIRED' else 'ACTIVE' end status,
      i.expires_at,i.used_at,i.used_by,i.promotion_ends_at,i.promotion_quota,
      i.reason,i.created_at,i.created_by,
      coalesce(nullif(p.display_name,''),nullif(p.full_name,''),'Admin') created_by_name
    from public.invitations i
    left join public.businesses b on b.id=i.business_id
    join public.profiles p on p.id=i.created_by
  )
  select rows.* from rows cross join(select public.require_admin() checked) guard
  where(p_status is null or status=p_status)
    and(p_purpose is null or purpose=p_purpose)
    and(p_search is null or email ilike '%'||btrim(p_search)||'%' or business_name ilike '%'||btrim(p_search)||'%')
  order by created_at desc,id desc
  limit greatest(1,least(p_limit,100)) offset greatest(p_offset,0);
$$;

create or replace function public.admin_dashboard_metrics()
returns jsonb language sql stable security definer set search_path=public as $$
  with guard as(select public.require_admin() checked),
  activity as(
    select distinct actor_id user_id from public.business_audit_logs
      where actor_id is not null and created_at>=now()-interval '30 days'
    union select distinct user_id from public.ai_usage_logs
      where created_at>=now()-interval '30 days'
    union select id from public.profiles where updated_at>=now()-interval '30 days'
  ), ai as(
    select count(*) filter(where created_at>=current_date) today_requests,
      count(*) filter(where created_at>=date_trunc('month',now())) month_requests,
      count(*) filter(where status='success' and created_at>=date_trunc('month',now())) success,
      count(*) filter(where status='error' and created_at>=date_trunc('month',now())) errors,
      coalesce(sum(total_tokens) filter(where created_at>=date_trunc('month',now())),0) total_tokens,
      coalesce(sum(estimated_cost_usd) filter(where created_at>=date_trunc('month',now())),0) cost_usd
    from public.ai_usage_logs
  )
  select jsonb_build_object(
    'active_users_definition','Aktivitas profil, usaha, atau AI dalam 30 hari terakhir',
    'total_users',(select count(*) from public.profiles),
    'active_users_30d',(select count(*) from activity),
    'disabled_users',(select count(*) from public.profiles where not access_enabled),
    'total_businesses',(select count(*) from public.businesses),
    'active_subscriptions',(select count(*) from public.subscription_periods where status='ACTIVE' and starts_at<=now() and ends_at>now() and source<>'PROMOTION'),
    'scheduled_subscriptions',(select count(*) from public.subscription_periods where status='SCHEDULED' and starts_at>now()),
    'expired_subscriptions',(select count(*) from public.subscription_periods where status='EXPIRED' or ends_at<=now()),
    'active_promotions',(select count(*) from public.subscription_periods where source='PROMOTION' and status='ACTIVE' and ends_at>now()),
    'unpaid_invoices',(select count(*) from public.subscription_invoices where status='UNPAID' and expires_at>now()),
    'pending_payments',(select count(*) from public.payment_submissions where status='PENDING'),
    'ai_quota_allocated',(select coalesce(sum(quota_snapshot),0) from public.subscription_periods where status='ACTIVE' and starts_at<=now() and ends_at>now()),
    'ai_quota_used',(select count(*) from public.ai_quota_reservations r join public.subscription_periods p on p.user_id=r.user_id and r.created_at>=p.starts_at and r.created_at<p.ends_at where p.status='ACTIVE' and p.starts_at<=now() and p.ends_at>now() and r.status='completed'),
    'active_invitations',(select count(*) from public.invitations where revoked_at is null and used_at is null and expires_at>now()),
    'used_invitations',(select count(*) from public.invitations where used_at is not null),
    'revoked_invitations',(select count(*) from public.invitations where revoked_at is not null),
    'expired_invitations',(select count(*) from public.invitations where revoked_at is null and used_at is null and expires_at<=now()),
    'provider',(select provider from public.ai_system_config where id),
    'model',(select default_model from public.ai_system_config where id),
    'rate_limit_per_minute',(select ai_rate_limit_per_minute from public.ai_system_config where id),
    'ai',jsonb_build_object('today_requests',ai.today_requests,'month_requests',ai.month_requests,'success',ai.success,'errors',ai.errors,'total_tokens',ai.total_tokens,'estimated_cost_usd',ai.cost_usd)
  ) from ai cross join guard;
$$;

create or replace function public.admin_list_activity_audit(
  p_source text default null,p_action text default null,p_search text default null,
  p_limit integer default 50,p_offset integer default 0
) returns table(
  id uuid,source text,actor_id uuid,actor_name text,business_id uuid,action text,
  resource_type text,resource_id text,result text,correlation_id uuid,metadata jsonb,
  created_at timestamptz
) language sql stable security definer set search_path=public as $$
  with combined as(
    select a.id,'PLATFORM'::text source,a.admin_user_id actor_id,
      coalesce(nullif(p.display_name,''),nullif(p.full_name,''),'Admin') actor_name,
      null::uuid business_id,a.action,a.target_type resource_type,a.target_id resource_id,
      'SUCCESS'::text result,null::uuid correlation_id,a.metadata,a.created_at
    from public.admin_audit_logs a join public.profiles p on p.id=a.admin_user_id
    union all
    select a.id,'BUSINESS',a.actor_id,
      coalesce(nullif(p.display_name,''),nullif(p.full_name,''),'Sistem'),
      a.business_id,a.action,a.resource_type,a.resource_id,a.result,a.correlation_id,
      a.metadata,a.created_at
    from public.business_audit_logs a left join public.profiles p on p.id=a.actor_id
  )
  select combined.* from combined cross join(select public.require_admin() checked) guard
  where(p_source is null or source=p_source)
    and(p_action is null or action=p_action)
    and(p_search is null or actor_name ilike '%'||btrim(p_search)||'%' or action ilike '%'||btrim(p_search)||'%' or coalesce(resource_id,'') ilike '%'||btrim(p_search)||'%')
  order by created_at desc,id desc
  limit greatest(1,least(p_limit,100)) offset greatest(p_offset,0);
$$;

revoke all on function public.admin_list_invitations(text,text,text,integer,integer),
  public.admin_list_activity_audit(text,text,text,integer,integer) from public;
grant execute on function public.admin_list_invitations(text,text,text,integer,integer),
  public.admin_list_activity_audit(text,text,text,integer,integer) to authenticated;
