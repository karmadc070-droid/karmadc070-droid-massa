-- 기기가 없으면 버리지 말고 기다렸다가 전달한다 (2026-10-18)
--
-- 왜 — 마사지사 11명은 알림을 켠 적이 없어서 기기가 0대다.
-- 지금 환영/공지를 보내면 push_result='no_device' 로 영구 실패 처리되고 영영 안 간다.
-- 실제로 아침에 보낸 안내 12건이 전부 그렇게 사라졌다.
-- 앱을 열어 알림을 켜는 순간 전달되게 하면, 안내를 미리 걸어 둘 수 있다.
--
-- 범위
--   notice · info · approved  → 기기가 없으면 3일 동안 10분마다 다시 시도
--   booking_new               → 기기 유무와 무관하게 30초 간격 10회(약 5분).
--     ※ 검증해 보니 기기가 없어도 재시도가 돈다. 처음엔 막으려 했는데 그대로 두기로 했다 —
--       예약을 받은 마사지사가 그 자리에서 앱을 열어 알림을 켜면 5분 안에 그 예약이 도착한다.
--       5분이 지나면 멈추므로 지난 예약을 뒤늦게 알릴 위험도 없다.
--
-- 멈춤 — 전달 성공 / 3일 경과 / 읽음 / 횟수 소진.

create or replace function public.claim_unpushed_notifications()
returns setof public.notifications
language sql
security definer
set search_path = public
as $fn$
  update public.notifications n
     set pushed_at    = now(),
         push_tries   = n.push_tries + 1,
         next_push_at = case
           -- 새 예약: 수락할 때까지 30초마다 (최대 10회 = 약 5분)
           when n.kind = 'booking_new' and n.push_tries + 1 < 10
             then now() + interval '30 seconds'
           -- 환영·공지: 받을 기기가 아직 없으면 10분 뒤 다시 (3일까지)
           when n.kind in ('notice', 'info', 'approved')
                and n.created_at > now() - interval '3 days'
                and not exists (select 1 from push_tokens t where t.user_id = n.user_id)
             then now() + interval '10 minutes'
         end
   where n.user_id is not null
     and (
           -- (a) 아직 한 번도 안 보낸 것
           (n.pushed_at is null and n.created_at > now() - interval '1 hour')

           -- (b) 수락 전이라 다시 울려야 하는 새 예약
           or (n.kind = 'booking_new'
               and n.next_push_at is not null and n.next_push_at <= now()
               and n.push_tries < 10
               and n.is_read = false
               and n.created_at > now() - interval '10 minutes'
               and (n.booking_id is null
                    or exists (select 1 from bookings b
                                where b.id = n.booking_id and b.status = 'requested')))

           -- (c) 기기가 생기기를 기다리는 환영·공지
           or (n.kind in ('notice', 'info', 'approved')
               and n.next_push_at is not null and n.next_push_at <= now()
               and n.is_read = false
               and n.created_at > now() - interval '3 days'
               and exists (select 1 from push_tokens t where t.user_id = n.user_id))
         )
  returning n.*;
$fn$;

-- 기다리는 중임을 화면에서 구분할 수 있게. 기존 'no_device' 는 '영구 실패'로 남겨 둔다.
comment on column public.notifications.next_push_at is
  '다음 발송 예정 시각. booking_new 는 30초 반복, notice/info/approved 는 기기가 생길 때까지 10분마다 (3일)';

select 'push wait-for-device ok' as result;
