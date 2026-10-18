#!/bin/sh
# safety_alerts 내용을 사람·예약과 함께 본다
docker exec -i massa-db psql -U postgres -d postgres -c "
select s.id,
       s.kind,
       s.status,
       to_char(s.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 하노이,
       coalesce(u.email,'(없음)') as 계정,
       coalesce(p.display_name,'-') as 마사지사,
       coalesce(s.booking_id::text,'-') as 예약,
       coalesce(nullif(s.note,''),'-') as 메모,
       case when s.lat is null then '-' else round(s.lat::numeric,4)||','||round(s.lng::numeric,4) end as 위치
from safety_alerts s
left join auth.users u on u.id = s.user_id
left join providers p on p.profile_id = s.user_id
order by s.created_at desc;"

echo '=== 이 계정들이 실제 사용자인가 ==='
docker exec -i massa-db psql -U postgres -d postgres -c "
select u.email, u.created_at::date as 가입일,
       (select count(*) from providers p where p.profile_id=u.id) as 마사지사등록,
       (select count(*) from bookings b where b.customer_id=u.id) as 예약수
from auth.users u
where u.id in (select user_id from safety_alerts);"
