-- Email-first beta compatibility. Keep the phone foundation from 0016, but
-- read an optional contact phone from metadata when auth.users.phone is null.
-- Existing profiles are intentionally not changed.

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (
    id, full_name, display_name, phone_e164, phone_verified, contact_email
  ) values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.phone, nullif(new.raw_user_meta_data ->> 'phone_e164', '')),
    case when new.phone is null then false else new.phone_confirmed_at is not null end,
    coalesce(
      nullif(lower(new.raw_user_meta_data ->> 'contact_email'), ''),
      nullif(lower(new.email), '')
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;
