-- 새 예약 알림이 울리는 시간을 5분에서 10분으로 늘린다 (2026-10-20)
--
-- 마사지사는 손에 폰을 들고 있지 않다. 시술 중이거나 이동 중이다.
-- 5분은 짧다는 판단이라 30초 간격은 그대로 두고 횟수만 10회 → 20회로 올린다.
-- 창도 10분 → 11분으로 둔다. 20번째 울림이 9분 30초에 떨어지는데,
-- 크론이 30초 격자로 움직여서 딱 10분이면 마지막 한 번이 잘릴 수 있다.
--
-- 같이 막는 것: booking_id 가 없는 booking_new 는 재발송하지 않는다.
-- 예약이 없으면 수락될 방법이 없어 상한까지 혼자 울린다. 2026-10-19 밤에
-- 테스트 알림 13건이 동시에 반복해서 사장님 폰이 계속 울렸다.
-- 횟수를 20회로 올리면 그 고통이 두 배가 되므로 이번에 함께 닫는다.

create or replace function public.claim_unpushed_notifications()
returns setof notifications
language sql
security definer
set search_path to 'public'
as $function$
  update public.notifications n
     set pushed_at    = now(),
         push_tries   = n.push_tries + 1,
         next_push_at = case
           -- 새 예약: 수락할 때까지 30초마다 (최대 20회 = 약 10분)
           when n.kind = 'booking_new' and n.booking_id is not null
                and n.push_tries + 1 < 20
             then now() + interval '30 seconds'
           -- 운영·공지: 받을 기기가 아직 없으면 10분 뒤 다시 (3일까지)
           when n.kind in ('notice', 'info', 'approved')
                and n.created_at > now() - interval '3 days'
                and not exists (select 1 from push_tokens t where t.user_id = n.user_id)
             then now() + interval '10 minutes'
         end
   where n.user_id is not null
     and (
           -- (a) 아직 한 번도 안 보낸 것
           (n.pushed_at is null and n.created_at > now() - interval '1 hour')

           -- (b) 수락 없이 다시 울려야 하는 새 예약
           or (n.kind = 'booking_new'
               and n.booking_id is not null
               and n.next_push_at is not null and n.next_push_at <= now()
               and n.push_tries < 20
               and n.is_read = false
               and n.created_at > now() - interval '11 minutes'
               and exists (select 1 from bookings b
                            where b.id = n.booking_id and b.status = 'requested'))

           -- (c) 기기가 생기기를 기다리는 운영·공지
           or (n.kind in ('notice', 'info', 'approved')
               and n.next_push_at is not null and n.next_push_at <= now()
               and n.is_read = false
               and n.created_at > now() - interval '3 days'
               and exists (select 1 from push_tokens t where t.user_id = n.user_id))
         )
  returning n.*;
$function$;
