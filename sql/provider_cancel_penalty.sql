-- 마사지사 제재에 '수락 후 취소(갈 수 없어요)'도 센다 (2026-11-19, 사용자 승인). 고객 노쇼 처리(no_show_at)는 제외
-- 적용: docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -1 < sql/provider_cancel_penalty.sql
-- provider_cancel.sql 다음에 적용. 두 번 돌려도 '이미 반영됨'으로 끝난다.

-- 1) 최근 30일 거절 + 수락 후 취소를 같은 규칙(5 경고 · 8 노출저하 · 12 정지)으로 센다
do $$
declare
  d text := pg_get_functiondef('public.apply_provider_penalty'::regproc);
  a text := '   where provider_id = p_provider and rejected_at >= now() - interval ''30 days'';';
  b text := '   where provider_id = p_provider' || chr(10)
    || '     and (rejected_at >= now() - interval ''30 days''' || chr(10)
    || '          -- 수락 후 ''갈 수 없어요'' 도 센다 (2026-11-19). 고객 노쇼 처리는 제외' || chr(10)
    || '          or (cancelled_by = ''provider'' and no_show_at is null and cancelled_at >= now() - interval ''30 days''));';
begin
  if position('''provider''' in d) > 0 then
    raise notice 'apply_provider_penalty: 이미 반영됨';
    return;
  end if;
  if position(a in d) = 0 then
    raise exception 'apply_provider_penalty 정의가 예상과 달라 고치지 않았습니다';
  end if;
  execute replace(d, a, b);
end $$;

-- 2) 알림: 노쇼 처리는 '갈 수 없어요' 알림에서 빼고, 취소 즉시 마사지사 제재를 다시 계산한다
do $$
declare
  d text := pg_get_functiondef('public.notify_booking_event'::regproc);
  a text := '  elsif new.status = ''cancelled'' and new.cancelled_by = ''provider'' then' || chr(10);
  b text := '  elsif new.status = ''cancelled'' and new.cancelled_by = ''provider'' and new.no_show_at is null then' || chr(10)
    || '    perform public.apply_provider_penalty(new.provider_id, false);  -- 마사지사 제재 즉시 반영' || chr(10);
begin
  if position('apply_provider_penalty' in d) > 0 then
    raise notice 'notify_booking_event: 이미 반영됨';
    return;
  end if;
  if position(a in d) = 0 then
    raise exception 'notify_booking_event 정의가 예상과 달라 고치지 않았습니다';
  end if;
  execute replace(d, a, b);
end $$;
