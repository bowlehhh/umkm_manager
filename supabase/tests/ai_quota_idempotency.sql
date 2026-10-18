begin;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values(
  '00000000-0000-0000-0000-000000000000',
  '11000000-0000-0000-0000-000000000001','authenticated','authenticated',
  'quota@example.test','',now(),'{}','{}',now(),now()
);
insert into public.subscription_periods(
  user_id,source,plan_key_snapshot,price_snapshot,quota_snapshot,
  starts_at,ends_at,status,reason
) values(
  '11000000-0000-0000-0000-000000000001','PROMOTION','test',0,2,
  now()-interval '1 hour',now()+interval '1 day','ACTIVE','Automated test'
);

do $$
declare first_row record; replay_row record; mismatch_row record; second_row record;
  denied_row record; finished_row record; late_row record; save_failure_row record;
  stale_row record;
  completed_count integer;
begin
  select * into first_row from public.reserve_ai_quota_v2(
    '11000000-0000-0000-0000-000000000001','request-0001',repeat('a',64),2,20
  );
  if first_row.state<>'granted' or first_row.lease_token is null then
    raise exception 'first reservation was not granted: %',first_row.state;
  end if;

  select * into replay_row from public.reserve_ai_quota_v2(
    '11000000-0000-0000-0000-000000000001','request-0001',repeat('a',64),2,20
  );
  if replay_row.state<>'in_progress' or replay_row.reservation_id<>first_row.reservation_id then
    raise exception 'parallel/retry request was not coalesced';
  end if;

  select * into mismatch_row from public.reserve_ai_quota_v2(
    '11000000-0000-0000-0000-000000000001','request-0001',repeat('b',64),2,20
  );
  if mismatch_row.state<>'rejected' or mismatch_row.denial_reason<>'payload_mismatch' then
    raise exception 'same key accepted a different payload';
  end if;

  select * into second_row from public.reserve_ai_quota_v2(
    '11000000-0000-0000-0000-000000000001','request-0002',repeat('c',64),2,20
  );
  select * into denied_row from public.reserve_ai_quota_v2(
    '11000000-0000-0000-0000-000000000001','request-0003',repeat('d',64),2,20
  );
  if second_row.state<>'granted' or denied_row.state<>'denied' or denied_row.denial_reason<>'quota' then
    raise exception 'period quota was not enforced atomically';
  end if;

  select * into finished_row from public.finalize_ai_quota_v2(
    first_row.reservation_id,first_row.lease_token,true,'business_builder',
    '{"success":true,"configuration":"saved"}'::jsonb,null
  );
  if not finished_row.finalized or finished_row.state<>'completed' then
    raise exception 'successful draft was not finalized atomically';
  end if;
  select * into replay_row from public.reserve_ai_quota_v2(
    '11000000-0000-0000-0000-000000000001','request-0001',repeat('a',64),2,20
  );
  if replay_row.state<>'completed' or replay_row.result_payload->>'configuration'<>'saved' then
    raise exception 'completed result was not replayable';
  end if;

  perform * from public.finalize_ai_quota_v2(
    second_row.reservation_id,second_row.lease_token,false,'business_builder',null,'provider_timeout'
  );
  select * into replay_row from public.reserve_ai_quota_v2(
    '11000000-0000-0000-0000-000000000001','request-0002',repeat('c',64),2,20
  );
  if replay_row.state<>'expired' then
    raise exception 'failed/timeout key could invoke provider again';
  end if;

  select * into stale_row from public.reserve_ai_quota_v2(
    '11000000-0000-0000-0000-000000000001','request-0004',repeat('e',64),2,20
  );
  update public.ai_quota_reservations set expires_at=now()-interval '1 second'
    where id=stale_row.reservation_id;
  select r.*,q.lease_token original_lease into replay_row
    from public.reserve_ai_quota_v2(
      '11000000-0000-0000-0000-000000000001','request-0004',repeat('e',64),2,20
    ) r cross join lateral(
      select lease_token from public.ai_quota_reservations
      where user_id='11000000-0000-0000-0000-000000000001' and request_id='request-0004'
    ) q;
  if replay_row.state<>'expired' then
    raise exception 'stale reservation was reusable: %',replay_row.state;
  end if;
  select * into late_row from public.finalize_ai_quota_v2(
    replay_row.reservation_id,replay_row.original_lease,true,'business_builder','{"success":true}'::jsonb,null
  );
  if late_row.finalized then raise exception 'late response was accepted'; end if;

  select * into save_failure_row from public.reserve_ai_quota_v2(
    '11000000-0000-0000-0000-000000000001','request-0005',repeat('f',64),2,20
  );
  begin
    perform * from public.finalize_ai_quota_v2(
      save_failure_row.reservation_id,save_failure_row.lease_token,true,
      'unsupported_action','{"success":true}'::jsonb,null
    );
    raise exception 'invalid draft unexpectedly saved';
  exception when invalid_parameter_value then null;
  end;
  if (select status from public.ai_quota_reservations where id=save_failure_row.reservation_id)<>'reserved' then
    raise exception 'storage failure consumed quota';
  end if;
  perform * from public.finalize_ai_quota_v2(
    save_failure_row.reservation_id,save_failure_row.lease_token,false,
    'business_builder',null,'draft_save_failed'
  );

  select count(*) into completed_count from public.ai_quota_reservations where status='completed';
  if completed_count<>1 then raise exception 'quota completed more than once: %',completed_count; end if;
  if (select count(*) from public.ai_configuration_drafts)<>1 then
    raise exception 'draft was saved more than once';
  end if;
end $$;

rollback;
