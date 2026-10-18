-- Phone-first profile foundation. This migration is additive: existing email
-- accounts, profile rows, memberships, and business data are left untouched.

alter table public.profiles
  add column if not exists display_name text,
  add column if not exists phone_e164 text,
  add column if not exists phone_verified boolean not null default false,
  add column if not exists contact_email text,
  add column if not exists preferred_language text not null default 'id';

update public.profiles
set display_name = full_name
where (display_name is null or btrim(display_name) = '')
  and btrim(full_name) <> '';

alter table public.profiles
  alter column display_name set default '',
  alter column display_name set not null;

alter table public.profiles
  add constraint profiles_phone_e164_format
  check (phone_e164 is null or phone_e164 ~ '^\+62[0-9]{9,13}$') not valid,
  add constraint profiles_preferred_language_format
  check (preferred_language ~ '^[a-z]{2,12}$') not valid;

create unique index if not exists profiles_phone_e164_unique_idx
  on public.profiles (phone_e164) where phone_e164 is not null;

create index if not exists profiles_contact_email_idx
  on public.profiles (lower(contact_email)) where contact_email is not null;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (
    id, full_name, display_name, phone_e164, phone_verified, contact_email
  ) values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.phone,
    new.phone_confirmed_at is not null,
    nullif(lower(new.raw_user_meta_data ->> 'contact_email'), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

comment on column public.profiles.phone_e164 is
  'Canonical Indonesian account phone in E.164. Authentication remains auth.users.';
comment on column public.profiles.contact_email is
  'Optional contact/recovery email; not an Auth identity for phone-first accounts.';
