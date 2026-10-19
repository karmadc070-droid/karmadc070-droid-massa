-- 수락 없는 예약을 같은 지역 다른 마사지사에게 자동으로 넘긴다 (2026-10-19)
--
-- 왜 — 10/19 첫 실제 예약(MS-261019-3906)이 지정된 한 사람에게만 가고,
-- 그 사람이 알림을 안 켜 둬서 아무도 모른 채 손님이 기다렸다.
-- 손님 화면에 '다른 분께도 보낼까요' 버튼은 있었지만 손님이 누르지 않았다.
-- 사람이 눌러야 돌아가는 장치는 결국 안 돌아간다. 서버가 알아서 넘긴다.
--
-- 이미 있는 것들을 그대로 쓴다 — 새로 만들지 않는다.
--   · group_id       같은 요청을 여러 명에게 보내는 묶음
--   · accept_booking 먼저 수락한 사람이 가져가고 나머지는 자동 취소
--   · notify_booking_event  INSERT 하면 알아서 booking_new 알림을 만든다
--
-- ★ 금액 함정 — freeze_booking_amount 가 INSERT 때 그 마사지사의 개인 가격으로
--   amount_vnd 를 다시 계산한다. 아무에게나 넘기면 손님이 동의한 금액보다
--   비싸질 수 있다. 그래서 '원래 금액 이하인 사람' 에게만 넘긴다.

alter table public.bookings add column if not exists fanout_at timestamptz;
comment on column public.bookings.fanout_at is '수락이 없어 다른 마사지사에게 자동으로 더 보낸 시각';

create or replace function public.fanout_stale_bookings(
  p_wait_min int default 10,   -- 몇 분 기다렸다 넘기는가
  p_max      int default 10    -- 한 건당 최대 몇 명에게 더 보내는가
)
returns table (booking_no text, sent_to int)
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  b    record;
  pr   record;
  cnt  int;
begin
  for b in
    select bk.*, p0.kind as orig_kind
      from bookings bk
      join providers p0 on p0.id = bk.provider_id
     where bk.status = 'requested'
       and bk.group_id is not null
       and bk.fanout_at is null
       and bk.created_at < now() - make_interval(mins => p_wait_min)
       -- 이미 지나간 약속은 넘겨 봐야 소용없다
       and bk.scheduled_at > now()
       -- 묶음 안에서 누가 이미 받았으면 넘기지 않는다
       and not exists (
             select 1 from bookings s
              where s.group_id = bk.group_id
                and s.status in ('confirmed','on_the_way','in_progress','completed'))
       -- 원본만 처리한다 (묶음 안에서 가장 먼저 만들어진 행)
       and bk.created_at = (select min(s.created_at) from bookings s where s.group_id = bk.group_id)
  loop
    cnt := 0;

    for pr in
      select p.id
        from providers p
       where p.application_status = 'approved'
         and p.is_active
         and p.kind = b.orig_kind
         and p.id <> b.provider_id
         and p.city_code = b.city_code
         -- 이미 이 묶음에 들어 있는 사람은 건너뛴다
         and not exists (select 1 from bookings s
                          where s.group_id = b.group_id and s.provider_id = p.id)
         -- ★ 손님이 동의한 금액보다 비싼 사람에게는 넘기지 않는다
         and coalesce(public.effective_price(p.id, b.service_id), b.amount_vnd) <= b.amount_vnd
         -- 알림을 받을 수 있는 사람을 먼저 (기기 있는 사람 우선)
       order by (select count(*) from push_tokens t
                  where t.user_id = coalesce(p.profile_id, p.owner_id)) desc,
                p.rating desc nulls last
       limit p_max
    loop
      begin
        insert into bookings (
          customer_id, provider_id, service_id, scheduled_at,
          location_type, hotel_name, room_number, front_desk_note, address,
          lat, lng, place_id, city_code, ward_code,
          amount_vnd, payment_method, group_id, status)
        values (
          b.customer_id, pr.id, b.service_id, b.scheduled_at,
          b.location_type, b.hotel_name, b.room_number, b.front_desk_note, b.address,
          b.lat, b.lng, b.place_id, b.city_code, b.ward_code,
          b.amount_vnd, b.payment_method, b.group_id, 'requested');
        cnt := cnt + 1;
      exception when others then
        -- 거리 제한 등으로 거절되는 사람은 조용히 건너뛴다.
        -- 한 명 때문에 나머지까지 못 보내면 안 된다.
        null;
      end;
    end loop;

    update bookings set fanout_at = now() where id = b.id;

    -- 손님에게도 알린다. 기다리다 포기하지 않게.
    if cnt > 0 then
      insert into notifications (user_id, title, body, kind, booking_id)
      values (b.customer_id, '다른 테라피스트에게도 요청했습니다',
              b.booking_no || ' · ' || cnt || '명', 'info', b.id);
    end if;

    booking_no := b.booking_no; sent_to := cnt; return next;
  end loop;
end
$$;

revoke execute on function public.fanout_stale_bookings(int, int) from public;
revoke execute on function public.fanout_stale_bookings(int, int) from anon;
revoke execute on function public.fanout_stale_bookings(int, int) from authenticated;
grant  execute on function public.fanout_stale_bookings(int, int) to service_role;
