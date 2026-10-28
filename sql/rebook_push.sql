-- 마지막 완료 예약 14일 뒤 손님에게 '지난번 테라피스트 다시 부르기' 푸시를 한 번 보낸다 (2026-10-29)
-- 대상 예약: 완료 14~21일 전(크론을 며칠 놓쳐도 따라잡고, 오래된 예약은 보내지 않는다),
--   그 손님의 가장 최근 완료이고, 완료 뒤 새로 만든 예약이 없고, 진행 중·다가오는 예약도 없을 것.
-- 손님: 알림 기기가 있고, 승인된 마사지사 계정이 아니고, 최근 14일 안에 이 푸시를 받은 적이 없을 것.
-- 테라피스트가 승인·정지 아님·[TEST] 아님이면 이름(+사진)과 kind=rebook·provider_id(누르면 프로필), 아니면 사진 없는 일반 문구.
-- 예약당 한 번은 rebook_push_log(booking_id 기본키)가 지킨다. 같은 날 여러 번 불러도 두 번 나가지 않는다.
-- 동의 항목: 수신 거부 칸은 없다. marketing_agreed_at 은 동의 시각(125명 중 2명)이고 데일리 푸시도 쓰지 않는다(10-28 사용자 결정).
-- VPS 크론(서버 시계 KST): 0 13 * * * = 하노이 11:00

create table if not exists public.rebook_push_log (
  booking_id uuid primary key references public.bookings(id) on delete cascade,
  user_id uuid not null,
  provider_id uuid,
  sent_at timestamptz not null default now()
);
alter table public.rebook_push_log enable row level security;
revoke all on public.rebook_push_log from anon, authenticated;
create index if not exists rebook_push_log_user on public.rebook_push_log (user_id, sent_at);

create or replace function public.send_rebook_push()
returns integer language sql security definer set search_path = '' as $$
  with b as (
    select distinct on (b.customer_id) b.id, b.customer_id, b.provider_id, b.completed_at
    from public.bookings b
    where b.status = 'completed'
      and b.completed_at <= now() - interval '14 days'
      and b.completed_at >  now() - interval '21 days'
      and b.customer_id is not null
    order by b.customer_id, b.completed_at desc
  ), t as (
    select b.*
    from b
    where not exists (select 1 from public.bookings x                    -- 더 최근 완료가 있거나 완료 뒤 새 예약
                       where x.customer_id = b.customer_id and x.id <> b.id
                         and (x.created_at > b.completed_at
                              or (x.status = 'completed' and x.completed_at > b.completed_at)))
      and not exists (select 1 from public.bookings x                    -- 진행 중·다가오는 예약
                       where x.customer_id = b.customer_id
                         and x.status in ('requested','confirmed','on_the_way','in_progress'))
      and not exists (select 1 from public.rebook_push_log l where l.booking_id = b.id)
      and not exists (select 1 from public.rebook_push_log l
                       where l.user_id = b.customer_id and l.sent_at > now() - interval '14 days')
      and not exists (select 1 from public.providers a
                       where (a.profile_id = b.customer_id or a.owner_id = b.customer_id) and a.application_status = 'approved')
  ), u as ( -- 가장 최근 기기의 언어, 모르는 언어는 en. 기기가 없으면 보내지 않는다
    select distinct on (t.id) t.id, t.customer_id,
           case when k.lang in ('ko','vi','en','zh','ja') then k.lang else 'en' end as lang,
           p.id as pid, p.display_name as pname,
           case when coalesce(p.photo_url, '') <> ''
                then replace(p.photo_url, '/storage/v1/object/public/', '/storage/v1/render/image/public/') || '?width=540&quality=60' end as img
    from t
    join public.push_tokens k on k.user_id = t.customer_id
    left join public.providers p on p.id = t.provider_id
         and p.application_status = 'approved'
         and p.display_name not like '[TEST]%'
         and (p.suspended_until is null or p.suspended_until < now())
    order by t.id, k.updated_at desc nulls last
  ), lg as (
    insert into public.rebook_push_log (booking_id, user_id, provider_id)
    select u.id, u.customer_id, u.pid from u
    on conflict (booking_id) do nothing
    returning booking_id
  ), ins as (
    insert into public.notifications (user_id, kind, title, body, image_url, provider_id)
    select u.customer_id, 'rebook',
           case when u.pid is not null then
             replace('{"ko":"지난번 {n} 테라피스트, 다시 불러 볼까요?","vi":"Gọi lại kỹ thuật viên {n} lần trước nhé?","en":"Book {n} again?","zh":"再约上次的理疗师{n}吗？","ja":"前回のセラピスト{n}さん、また呼びませんか？"}'::jsonb ->> u.lang, '{n}', u.pname)
           else '{"ko":"다시 예약해 보세요","vi":"Đặt lịch lại nhé","en":"Time to book again","zh":"再次预约吧","ja":"また予約しませんか"}'::jsonb ->> u.lang end,
           case when u.pid is not null then
             '{"ko":"지난번 마사지가 마음에 드셨다면 같은 테라피스트로 다시 예약해 보세요.","vi":"Nếu bạn hài lòng lần trước, hãy đặt lại cùng kỹ thuật viên nhé.","en":"Enjoyed your last massage? Book the same therapist again.","zh":"如果上次满意，可以再次预约同一位理疗师。","ja":"前回のマッサージが気に入ったら、同じセラピストをまた予約しましょう。"}'::jsonb ->> u.lang
           else '{"ko":"지난번 마사지 뒤 2주가 지났어요. 집이나 호텔에서 다시 편하게 쉬어 보세요.","vi":"Đã 2 tuần kể từ lần massage trước. Hãy thư giãn tại nhà hoặc khách sạn nhé.","en":"It has been two weeks since your last massage. Relax at home or your hotel.","zh":"距上次按摩已过两周，在家或酒店再放松一下吧。","ja":"前回のマッサージから2週間。自宅やホテルでまたゆっくり休みましょう。"}'::jsonb ->> u.lang end,
           u.img, u.pid
    from u join lg on lg.booking_id = u.id
    returning 1
  )
  select count(*)::int from ins;
$$;
revoke all on function public.send_rebook_push() from public, anon, authenticated;
