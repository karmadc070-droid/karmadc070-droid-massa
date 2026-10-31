-- 하노이 00시에 약속 시각이 지난 '신청(requested)' 예약은 자동 취소(손님 제재·알림 제외)하고, 수락된 예약은 자동 완료한다 (2026-10-31)
-- 적용: docker exec -i massa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -1 < sql/auto_expire_bookings.sql
-- 크론: scripts/massa_expire.sh (0 2 * * * 서버 KST = 하노이 00:00)
-- 수락(confirmed·on_the_way·in_progress) → 자동 완료도 한다(사용자 결정 10/31 12:50: 마사지사가 수락했으면 완료로 본다).
-- 완료 트리거가 초대 보상 쿠폰·마사지사 적립·파트너 수수료·후기 요청 알림을 그대로 만든다(사용자가 알고 승인).

-- 1) 자동 취소는 손님 '임박 취소'로 세지 않는다. 운영의 현재 정의에서 두 군데만 바꿔 다시 만든다.
do $$
declare
  d text := pg_get_functiondef('public.refresh_customer_penalty'::regproc);
  a1 text := '(select no_show_at, cancelled_at, scheduled_at' || chr(10);
  b1 text := '(select no_show_at, cancelled_at, scheduled_at, cancelled_by' || chr(10);
  a2 text := 'or (cancelled_at is not null and scheduled_at - cancelled_at < interval ''1 hour'')),';
  b2 text := 'or (cancelled_at is not null and coalesce(cancelled_by, '''') <> ''expired'' and scheduled_at - cancelled_at < interval ''1 hour'')),';
begin
  if position('''expired''' in d) > 0 then
    raise notice 'refresh_customer_penalty: 이미 반영됨';
    return;
  end if;
  if position(a1 in d) = 0 or position(a2 in d) = 0 then
    raise exception 'refresh_customer_penalty 정의가 예상과 달라 고치지 않았습니다';
  end if;
  execute replace(replace(d, a1, b1), a2, b2);
end $$;

-- 2) 자동 취소는 알림을 만들지 않는다(이미 지난 약속, 팬아웃 행마다 자정 푸시가 가는 것을 막음).
do $$
declare
  d text := pg_get_functiondef('public.notify_booking_event'::regproc);
  a text := '  elsif new.status = ''cancelled'' and coalesce(new.cancelled_by, '''') = ''system'' then';
  b text := '  elsif new.status = ''cancelled'' and new.cancelled_by = ''expired'' then' || chr(10)
         || '    return new;  -- 시간 경과 자동 취소는 알리지 않는다 (2026-10-31)' || chr(10) || a;
begin
  if position('''expired''' in d) > 0 then
    raise notice 'notify_booking_event: 이미 반영됨';
    return;
  end if;
  if position(a in d) = 0 then
    raise exception 'notify_booking_event 정의가 예상과 달라 고치지 않았습니다';
  end if;
  execute replace(d, a, b);
end $$;

-- 3) 자동 취소 함수. 하노이 '오늘 00:00' 이전 약속 중 아직 신청 상태인 것을 취소하고 건수를 돌려준다.
create or replace function public.expire_stale_bookings()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  cut timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  n   integer;
begin
  update bookings
     set status = 'cancelled',
         cancelled_at = now(),
         cancelled_by = 'expired',
         cancel_reason = '시간 경과 자동 취소'
   where status = 'requested'
     and scheduled_at < cut;
  get diagnostics n = row_count;
  return n;
end $$;

-- 크론(postgres)만 부른다. 앱 사용자는 부를 수 없다.
revoke all on function public.expire_stale_bookings() from public, anon, authenticated;

-- 4) 자동 완료 함수. 마사지사가 수락한 예약 중 '약속 시각 + 서비스 시간'이 하노이 오늘 00:00 이전인 것을 완료로 바꾸고 건수를 돌려준다.
--    앱의 완료 처리와 같이 status='completed', completed_at=now() 만 바꿔 기존 완료 트리거가 그대로 돈다.
create or replace function public.complete_stale_bookings()
returns integer
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  cut timestamptz := date_trunc('day', now() at time zone 'Asia/Ho_Chi_Minh') at time zone 'Asia/Ho_Chi_Minh';
  n   integer;
begin
  update bookings b
     set status = 'completed',
         completed_at = now()
    from services s
   where s.id = b.service_id
     and b.status in ('confirmed', 'on_the_way', 'in_progress')
     and b.scheduled_at + make_interval(mins => coalesce(s.duration_min, 0)) < cut;
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.complete_stale_bookings() from public, anon, authenticated;
