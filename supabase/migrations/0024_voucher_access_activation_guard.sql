-- Voucher activation must never re-enable a user account that an admin has
-- explicitly disabled. The existing redeem_voucher RPC remains atomic: this
-- trigger raises before redemption is committed, rolling back its subscription
-- upsert and voucher counter update in the same transaction.

create or replace function public.require_voucher_redemption_access_enabled()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (
    select 1 from public.profiles
    where id = new.user_id and access_enabled
  ) then
    raise exception 'Account access is disabled' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists voucher_redemptions_access_enabled on public.voucher_redemptions;
create trigger voucher_redemptions_access_enabled
  before insert on public.voucher_redemptions
  for each row execute function public.require_voucher_redemption_access_enabled();

revoke all on function public.require_voucher_redemption_access_enabled() from public;
