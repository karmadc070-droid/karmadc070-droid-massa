-- 미수락 예약 재배정 대상을 바꾼다: 시험 계정 제외, 알림(기기) 켠 마사지사만, 손님 동(ward)을 맡는 사람 먼저 (2026-10-22 사용자 지시)
-- 알림 켠 후보가 한 명도 없을 때만 알림 꺼진 사람에게 넘긴다(이들은 VPS 크론 massa_booking_mail.py 가 메일로 알린다)
CREATE OR REPLACE FUNCTION public.fanout_stale_bookings(p_wait_min integer DEFAULT 10, p_max integer DEFAULT 10)
 RETURNS TABLE(booking_no text, sent_to integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      with cand as (
        select p.id, p.rating,
               exists (select 1 from push_tokens t
                        where t.user_id = coalesce(p.profile_id, p.owner_id)) as has_push,
               coalesce(b.ward_code = any(p.ward_codes), false) as in_ward
          from providers p
         where p.application_status = 'approved'
           and p.is_active
           and p.kind = b.orig_kind
           and p.id <> b.provider_id
           and p.city_code = b.city_code
           -- 시험 계정에는 실제 손님 예약을 넘기지 않는다
           and p.display_name not ilike '[TEST]%'
           -- 이미 이 묶음에 들어 있는 사람은 건너뛴다
           and not exists (select 1 from bookings s
                            where s.group_id = b.group_id and s.provider_id = p.id)
           -- ★ 손님이 동의한 금액보다 비싼 사람에게는 넘기지 않는다
           and coalesce(public.effective_price(p.id, b.service_id), b.amount_vnd) <= b.amount_vnd)
      select c.id from cand c
       -- 알림 켠 사람만. 그런 사람이 아무도 없을 때만 나머지에게
       where c.has_push or not exists (select 1 from cand x where x.has_push)
       order by c.in_ward desc, c.has_push desc, c.rating desc nulls last
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
$function$;
