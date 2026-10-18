-- Admin queue for manual payment verification. Detail intentionally excludes
-- cross-business financial data and exposes only billing metadata.
create or replace function public.admin_list_payment_submissions(
  p_status text default 'PENDING',p_limit integer default 100,p_offset integer default 0
) returns table(
  id uuid,invoice_id uuid,invoice_number text,user_id uuid,user_name text,user_email text,
  plan_label text,amount bigint,quota integer,payer_name text,payment_reference text,
  status text,submitted_at timestamptz
) language sql stable security definer set search_path=public as $$
  select ps.id,i.id,i.invoice_number,ps.user_id,
    coalesce(nullif(p.display_name,''),nullif(p.full_name,''),'Tanpa nama'),u.email,
    i.plan_label_snapshot,i.price_snapshot,i.quota_snapshot,ps.payer_name,
    ps.payment_reference,ps.status,ps.submitted_at
  from public.payment_submissions ps
  join public.subscription_invoices i on i.id=ps.invoice_id
  join public.profiles p on p.id=ps.user_id join auth.users u on u.id=ps.user_id
  cross join(select public.require_admin() checked) guard
  where p_status is null or ps.status=p_status
  order by ps.submitted_at asc
  limit greatest(1,least(p_limit,100)) offset greatest(p_offset,0);
$$;
grant execute on function public.admin_list_payment_submissions(text,integer,integer) to authenticated;
