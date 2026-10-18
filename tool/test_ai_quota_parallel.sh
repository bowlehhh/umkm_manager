#!/usr/bin/env bash
set -euo pipefail

database_url="${DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"
user_id="13000000-0000-0000-0000-000000000001"
request_id="parallel-request-0001"
result_dir="$(mktemp -d)"

cleanup() {
  local status=$?
  psql "$database_url" -v ON_ERROR_STOP=1 -qAtc \
    "delete from public.ai_configuration_drafts where user_id='$user_id';
     delete from public.ai_quota_reservations where user_id='$user_id';
     delete from public.subscription_periods where user_id='$user_id';
     delete from auth.users where id='$user_id';" >/dev/null || true
  rm -rf -- "$result_dir"
  exit "$status"
}
trap cleanup EXIT

psql "$database_url" -v ON_ERROR_STOP=1 -q <<SQL
insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values(
  '00000000-0000-0000-0000-000000000000','$user_id','authenticated',
  'authenticated','parallel@example.test','',now(),'{}','{}',now(),now()
);
insert into public.subscription_periods(
  user_id,source,plan_key_snapshot,price_snapshot,quota_snapshot,
  starts_at,ends_at,status,reason
) values(
  '$user_id','PROMOTION','parallel-test',0,1,now()-interval '1 hour',
  now()+interval '1 hour','ACTIVE','Parallel automated test'
);
SQL

export database_url user_id request_id result_dir
seq 1 16 | xargs -P 16 -I '{}' bash -c '
  psql "$database_url" -v ON_ERROR_STOP=1 -qAtc \
    "select state from public.reserve_ai_quota_v2('"'"'$user_id'"'"','"'"'$request_id'"'"',repeat('"'"'a'"'"',64),1,100);" \
    >"$result_dir/{}.txt"
'

reservation_count="$(psql "$database_url" -qAtc \
  "select count(*) from public.ai_quota_reservations where user_id='$user_id' and request_id='$request_id';")"
granted_count="$(grep -h '^granted$' "$result_dir"/*.txt | wc -l)"
unexpected_count="$(
  { grep -hvE '^(granted|in_progress)$' "$result_dir"/*.txt || true; } | wc -l
)"

test "$reservation_count" = "1"
test "$granted_count" = "1"
test "$unexpected_count" = "0"
printf 'PASS: 16 parallel requests -> 1 granted, 15 in_progress, 1 reservation\n'
