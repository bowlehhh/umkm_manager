-- A compact, RLS-protected dashboard payload. SECURITY INVOKER is deliberate:
-- the caller must already be a member through the existing table policies.
create or replace function public.get_dashboard_summary(p_business_id uuid)
returns jsonb
language sql stable security invoker set search_path = public as $$
  select jsonb_build_object(
    'total_transactions', coalesce((
      select count(*)::bigint
      from public.transactions t
      where t.business_id = p_business_id
        and t.created_at >= current_date
        and t.created_at < current_date + interval '1 day'
    ), 0),
    'gross_revenue', coalesce((
      select sum(t.total)::bigint
      from public.transactions t
      where t.business_id = p_business_id
        and t.created_at >= current_date
        and t.created_at < current_date + interval '1 day'
    ), 0),
    'total_expense', coalesce((
      select sum(e.amount)::bigint
      from public.expenses e
      where e.business_id = p_business_id and e.expense_date = current_date
    ), 0),
    'open_debt_total', coalesce((
      select sum(d.remaining_amount)::bigint
      from public.debts d
      where d.business_id = p_business_id and d.status <> 'PAID'
    ), 0),
    'customer_count', coalesce((
      select count(*)::bigint
      from public.customers c
      where c.business_id = p_business_id and c.is_active
    ), 0),
    'low_stock_count', coalesce((
      select count(*)::bigint
      from public.products p
      where p.business_id = p_business_id
        and p.is_active
        and p.stock <= p.minimum_stock
    ), 0)
  );
$$;

revoke all on function public.get_dashboard_summary(uuid) from public;
grant execute on function public.get_dashboard_summary(uuid) to authenticated;
