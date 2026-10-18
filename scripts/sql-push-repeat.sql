-- 새 예약 알림을 수락할 때까지 반복해서 울린다 (2026-10-18)
--
-- 왜 — 푸시는 한 번 울리고 끝이라 마사지사가 그 순간 폰을 못 보면 놓친다.
-- 사장님이 실제 테스트에서 확인한 문제다. 예약은 시간이 걸린 일이라 한 번으로는 부족하다.
--
-- 어떻게 — sw.js 가 tag:'massa-booking' + renotify:true 로 돼 있어서
-- 같은 알림을 다시 보내면 쌓이지 않고 덮어쓰면서 소리를 다시 낸다.
-- 그래서 서버가 같은 알림을 30초마다 다시 보내기만 하면 된다.
--
-- 멈추는 조건 — 셋 중 하나라도 걸리면 멈춘다.
--   1) 마사지사가 읽음 (앱을 열었다)
--   2) 예약이 requested 를 벗어남 (누군가 수락·취소했다)
--   3) 10회 (= 약 5분) 다 썼다
-- 반복은 booking_new 만 한다. 승인·공지 같은 건 한 번이면 된다.

alter table public.notifications
  add column if not exists push_tries   int not null default 0,
  add column if not exists next_push_at timestamptz;

-- 재시도 대상을 매번 훑으므로 인덱스를 둔다
create index if not exists notifications_repeat_idx
  on public.notifications (next_push_at)
  where next_push_at is not null;

create or replace function public.claim_unpushed_notifications()
returns setof public.notifications
language sql
security definer
set search_path = public
as $fn$
  update public.notifications n
     set pushed_at    = now(),
         push_tries   = n.push_tries + 1,
         -- booking_new 만 다음 발송을 예약한다. 나머지는 null 이라 두 번 가지 않는다.
         next_push_at = case when n.kind = 'booking_new' and n.push_tries + 1 < 10
                             then now() + interval '30 seconds' end
   where n.user_id is not null
     and (
           -- (a) 아직 한 번도 안 보낸 것
           (n.pushed_at is null and n.created_at > now() - interval '1 hour')
           -- (b) 반복할 차례가 된 새 예약 알림
           or (n.kind = 'booking_new'
               and n.next_push_at is not null
               and n.next_push_at <= now()
               and n.push_tries < 10
               and n.is_read = false
               and n.created_at > now() - interval '10 minutes'
               and (n.booking_id is null
                    or exists (select 1 from bookings b
                                where b.id = n.booking_id and b.status = 'requested')))
         )
  returning n.*;
$fn$;

select 'push repeat ok' as result;
