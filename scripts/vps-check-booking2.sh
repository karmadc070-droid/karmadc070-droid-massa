#!/bin/sh
# 최근 예약이 성사됐는지 본다
# ★ 앞선 스크립트는 services.name_ko 가 없어서 쿼리가 통째로 깨졌고, 섹션이 비어 보였다.
#   없는 컬럼을 짐작해 쓰지 말고 조인을 줄인다.
PSQL="docker exec massa-db psql -U postgres -d postgres"

echo '=== 최근 예약 10건 ==='
$PSQL -c "
select to_char(b.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 신청,
       b.status as 상태,
       coalesce(p.display_name,'-') as 마사지사,
       coalesce(u.email,'-') as 손님,
       to_char(b.scheduled_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 희망,
       coalesce(to_char(b.accepted_at at time zone 'Asia/Ho_Chi_Minh','HH24:MI'),'-') as 수락,
       coalesce(to_char(b.cancelled_at at time zone 'Asia/Ho_Chi_Minh','HH24:MI'),'-') as 취소,
       b.amount_vnd as 금액,
       b.is_paid as 결제됨
from bookings b
left join providers p on p.id = b.provider_id
left join auth.users u on u.id = b.customer_id
order by b.created_at desc limit 10;"

echo ''
echo '=== 오늘 그 건의 자세한 내용 (08:47 전후) ==='
$PSQL -x -c "
select b.booking_no, b.status, b.location_type, b.hotel_name, b.room_number,
       b.address, b.amount_vnd, b.city_code, b.ward_code,
       to_char(b.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI:SS') as 신청시각,
       coalesce(p.display_name,'-') as 마사지사,
       coalesce(u.email,'-') as 손님
from bookings b
left join providers p on p.id = b.provider_id
left join auth.users u on u.id = b.customer_id
where b.created_at > now() - interval '2 days'
order by b.created_at desc;"
echo '=== DONE ==='
