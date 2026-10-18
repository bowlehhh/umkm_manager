-- PostgreSQL privileges are checked before RLS. Grant only operations used by
-- the application; policies remain the per-row authority.

grant select,insert,update on public.businesses to authenticated;
grant select,insert,update,delete on public.business_members to authenticated;
grant select,insert,update,delete on public.categories to authenticated;
grant select,insert,update on public.products to authenticated;
grant select,insert,update on public.customers to authenticated;
grant select,insert,update,delete on public.discounts to authenticated;
grant select on public.transactions,public.transaction_items to authenticated;
grant select,insert,update,delete on public.expenses to authenticated;
grant select on public.debts,public.debt_payments to authenticated;
grant select,insert,update on public.business_configurations to authenticated;
grant select,insert,update,delete on public.custom_feature_records to authenticated;
grant select on public.stock_movements,public.business_audit_logs to authenticated;
grant select on public.subscription_plans,public.billing_instructions to authenticated;

-- Sequence usage is not required for checkout/invoices (SECURITY DEFINER RPCs
-- own those writes), so sequences are intentionally not granted to clients.
