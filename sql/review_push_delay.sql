-- 후기 요청('평가를 남겨주세요') 푸시를 손님이 예약한 시각 + 3시간 뒤에 보내도록 미루는 변경 (2026-10-31)
--
-- 방식: 알림 행은 완료 때 그대로 만들고(앱 알림함에는 바로 보임), 기존 notifications.next_push_at 에
--       greatest(now(), scheduled_at + 3h) 를 넣는다. 1분 크론 massa_push.sh → send-push 가 부르는
--       claim_unpushed_notifications() 가 그 시각이 된 것만 집어 보낸다. 새 크론·새 컬럼은 없다.
-- 발송은 베트남 시간(Asia/Ho_Chi_Minh) 08:00~22:00 사이에만. 그 밖에 시각이 되면 다음 08:00 이후 첫 실행 때 나간다.
-- 이미 후기를 쓴 예약은 보내지 않는다. 적용 전에 만들어진 완료 알림은 모두 pushed_at 이 있어 다시 나가지 않는다.
-- 적용 직전에 운영 정의와 이 파일의 두 함수 본문을 비교해, 이 변경 외에 달라진 곳이 없는지 확인할 것.


-- 후기 요청 푸시를 보내도 되는 시간인지 (베트남 시간 08:00 이상 22:00 미만)
create or replace function public.review_push_window_open(ts timestamptz)
 returns boolean
 language sql
 immutable
as $function$
  select (ts at time zone 'Asia/Ho_Chi_Minh')::time >= time '08:00'
     and (ts at time zone 'Asia/Ho_Chi_Minh')::time <  time '22:00'
$function$;
revoke all on function public.review_push_window_open(timestamptz) from public, anon, authenticated;

create or replace function public.notify_booking_event()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_body text := new.booking_no || ' · ' || to_char(new.scheduled_at at time zone 'Asia/Ho_Chi_Minh', 'MM/DD HH24:MI');
  v_kind text; v_title text;
begin
  if tg_op = 'INSERT' then
    insert into notifications (user_id, title, body, kind, booking_id)
    select u, '새 신청이 들어왔습니다 — 수락해 주세요', v_body, 'booking_new', new.id
    from (select owner_id as u from providers where id = new.provider_id
          union select profile_id from providers where id = new.provider_id
          union select id from profiles where role = 'admin') r
    where u is not null;
    return new;
  end if;

  if new.status is not distinct from old.status then return new; end if;

  if new.status = 'confirmed' then
    v_kind := 'booking_confirmed';  v_title := '예약이 확정되었습니다';
  elsif new.status = 'on_the_way' then
    v_kind := 'booking_on_the_way'; v_title := '테라피스트가 출발했습니다';
  elsif new.status = 'completed' then
    -- 후기 요청 푸시는 예약 시각 + 3시간 뒤에 (2026-10-31)
    insert into notifications (user_id, title, body, kind, booking_id, next_push_at)
    values (new.customer_id, '서비스가 완료되었습니다. 평가를 남겨주세요', v_body, 'booking_completed', new.id,
            greatest(now(), new.scheduled_at + interval '3 hours'));
    return new;
  elsif new.status = 'cancelled' and new.cancelled_by = 'expired' then
    return new;  -- 시간 경과 자동 취소는 알리지 않는다 (2026-10-31)
  elsif new.status = 'cancelled' and coalesce(new.cancelled_by, '') = 'system' then
    insert into notifications (user_id, title, body, kind, booking_id)
    select u, '다른 테라피스트가 먼저 수락했습니다', v_body, 'booking_taken', new.id
    from (select owner_id as u from providers where id = new.provider_id
          union select profile_id from providers where id = new.provider_id) r
    where u is not null;
    return new;
  elsif new.status = 'cancelled' and coalesce(new.cancelled_by, '') <> 'customer' then
    v_kind := 'booking_cancelled';  v_title := '신청이 취소되었습니다.';
  elsif new.status = 'cancelled' then
    insert into notifications (user_id, title, body, kind, booking_id)
    select u, '손님이 신청을 취소했습니다', v_body, 'booking_cancelled_by_customer', new.id
    from (select owner_id as u from providers where id = new.provider_id
          union select profile_id from providers where id = new.provider_id) r
    where u is not null;
    return new;
  else
    return new;
  end if;

  insert into notifications (user_id, title, body, kind, booking_id)
  values (new.customer_id, v_title, v_body, v_kind, new.id);
  return new;
end
$function$;

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
           -- (a) 아직 한 번도 안 보낸 것 (보낼 시각이 정해진 것은 (d) 에서)
           (n.pushed_at is null and n.created_at > now() - interval '1 hour'
            and n.next_push_at is null)

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

           -- (d) 후기 요청: 예약 시각 + 3시간이 된 것, 아직 후기를 안 쓴 예약만 (2026-10-31)
           --     베트남 시간 08:00~22:00 사이에만 보낸다. 밖이면 다음 08:00 이후 첫 실행 때 나간다.
           or (n.kind = 'booking_completed'
               and n.pushed_at is null
               and n.next_push_at is not null and n.next_push_at <= now()
               and public.review_push_window_open(now())
               and n.created_at > now() - interval '3 days'
               and not exists (select 1 from reviews r where r.booking_id = n.booking_id))
         )
  returning n.*;
$function$;

