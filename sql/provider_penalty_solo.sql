-- 마사지사 거절 제재를 실제로 켠다 (2026-11-19, 사용자 결정): 혼자 받은 신청의 거절 + 수락 후 취소만 센다
-- 적용: docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -1 < sql/provider_penalty_solo.sql
-- provider_cancel_penalty.sql 다음에 적용. 두 번 돌려도 '이미 반영됨'으로 끝난다.

-- 1) 여러 마사지사에게 같이 간 신청(같은 group_id 가 2건 이상)을 거절한 건 세지 않는다
do $$
declare
  d text := pg_get_functiondef('public.apply_provider_penalty'::regproc);
  a text := '     and (rejected_at >= now() - interval ''30 days''' || chr(10);
  b text := '     and ((rejected_at >= now() - interval ''30 days''' || chr(10)
    || '           -- 여러 마사지사에게 같이 간 신청을 거절한 건 세지 않는다 (2026-11-19)' || chr(10)
    || '           and not exists (select 1 from bookings o where o.group_id = bookings.group_id and o.id <> bookings.id))' || chr(10);
begin
  if position('o.group_id' in d) > 0 then
    raise notice 'apply_provider_penalty: 이미 반영됨';
    return;
  end if;
  if position(a in d) = 0 then
    raise exception 'apply_provider_penalty 정의가 예상과 달라 고치지 않았습니다';
  end if;
  execute replace(d, a, b);
end $$;

-- 2) 매일 재계산은 모든 마사지사를 돈다. 전에는 이미 횟수가 있는 사람만 돌아서 처음 0인 사람은 영원히 0이었다
do $$
declare
  d text := pg_get_functiondef('public.refresh_all_provider_penalties'::regproc);
  a text := 'for r in select id from providers where coalesce(penalty_level, 0) > 0 or coalesce(reject_count, 0) > 0 loop';
  b text := 'for r in select id from providers loop';
begin
  if position(b in d) > 0 then
    raise notice 'refresh_all_provider_penalties: 이미 반영됨';
    return;
  end if;
  if position(a in d) = 0 then
    raise exception 'refresh_all_provider_penalties 정의가 예상과 달라 고치지 않았습니다';
  end if;
  execute replace(d, a, b);
end $$;
