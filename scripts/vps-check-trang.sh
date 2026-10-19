#!/bin/sh
# Trang 이 11:24 에 들어와서 무엇을 했는지 본다 (2026-10-19)
PSQL="docker exec massa-db psql -U postgres -d postgres"
M='letrangquynhon@gmail.com'

echo '=== 1. Trang 은 누구인가 ==='
$PSQL -c "
select p.display_name, p.kind, p.application_status as 상태, p.is_active as 영업중,
       p.city_code, p.created_at::date as 등록일
from providers p join auth.users u on u.id = coalesce(p.profile_id, p.owner_id)
where u.email='$M';"

echo '=== 2. Trang 이 마사지사로 받은 예약 ==='
$PSQL -c "
select b.booking_no, b.status, b.amount_vnd,
       to_char(b.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 신청,
       to_char(b.completed_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 완료
from bookings b
join providers p on p.id = b.provider_id
join auth.users u on u.id = coalesce(p.profile_id, p.owner_id)
where u.email='$M';"

echo '=== 3. Trang 이 손님으로 한 예약 ==='
$PSQL -c "
select b.booking_no, b.status from bookings b
join auth.users u on u.id = b.customer_id where u.email='$M';"

echo '=== 4. 전체 예약은 몇 건인가 (지금까지 통틀어) ==='
$PSQL -c "select status, count(*) from bookings group by 1 order by 2 desc;"

echo '=== 5. Trang 의 앱 사용 기록 (최근 10건) ==='
$PSQL -c "
select to_char(v.created_at at time zone 'Asia/Ho_Chi_Minh','MM-DD HH24:MI') as 시각,
       coalesce(v.path,'-') as 화면, coalesce(v.platform,'-') as 기기
from app_visit v join auth.users u on u.id = v.user_id
where u.email='$M' order by v.created_at desc limit 10;"
echo '=== DONE ==='
